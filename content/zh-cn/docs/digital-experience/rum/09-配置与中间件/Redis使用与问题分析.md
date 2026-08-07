---
title: Redis 使用与问题分析
---

# Redis 使用与问题分析

> 本文档整合 BPI 与 RUM 模块 Redis Key 使用分析，以及 RUM 首次崩溃判断 Redis 内存问题分析与优化方案，作为完整的独立技术参考。所有路径统一为 newonexm 仓库路径。

---

## 一、BPI 与 RUM 模块 Redis Key 使用分析

### 1.1 背景

分析来源为 Bonree ONE 仪表盘"慢 SQL"查询（过滤条件：`标签=redis` + `标签=framework`）所列出的高延迟 Redis 操作，结合源代码逆向分析整理，涉及服务为 `one-framework`（包含 APM/BPI/RUM/IAM 各插件）。

### 1.2 慢 Redis 操作汇总

| 序号 | 接口 / 调用方 | Redis 操作命令 | 耗时（ms） |
|------|--------------|----------------|-----------|
| 1 | `接口='*'` | `CLIENT` | 30,568 |
| 2 | `IamApiController.pushCostDataV3` | `GET` | 25,145 |
| 3 | `BpiShareResourceCacheTask` | `HMSET` | 3,330 |
| 4 | `BpiShareResourceCacheTask` | `PEXPIRE` | 2,970 |
| 5 | `FiveMinuteJob` | —（RUM 缓存定时任务） | 1,100 |
| 6 | `LinkNodeRelationEntityTask` | `HGET` | 20,710 |
| 7 | `BpiShareResourceCacheTask` | —（`ULL` 疑似 NULL/del 操作） | 18,790 |
| 8 | `AffillingPackageSyncJob` | —（analysis 包同步任务） | 7,027 |

### 1.3 BPI 模块 Redis Key 详细分析

#### 1.3.1 BpiShareResourceCacheTask — 共享资源池缓存刷新任务

**代码位置**：
`framework/plugins/apm/one-apm/src/main/java/com/bonree/one/apm/module/core/links/task/BpiShareResourceCacheTask.java`

**执行周期**：每 5 分钟（`cron = "0 0/5 * * * ?"`）

**使用场景**：定时从数据库查询全量拓扑信息，刷新每个 TOPO（核心链路卡片）下的共享资源池缓存，用于权限过滤——让被分享的用户只能看到自己资源域内的实体数据。

**涉及的 Redis Key**：

| Key 常量 | 实际 Key 格式 | 数据结构 | 使用方式 | TTL（秒） |
|----------|--------------|----------|----------|----------|
| `BPI_SHARE_RESOURCE_EDIT_KEY` | `{APM_PREFIX}BPI_SHARE_RESOURCE_EDIT_KEY` | String | 分布式锁（`SET NX PX`） | 动态配置（默认根据 Nacos 配置 `CORE_LINK_SHARE_RESOURCE_TASK_LOCK_EXPIRE_SECONDS`） |
| `BPI_SHARE_RESOURCE:` | `{APM_PREFIX}BPI_SHARE_RESOURCE:{topoId}` | Hash | 存储预制实体模型资源池，Key=modelKey，Value=instanceId 集合 | **300**（5 min） |
| `BPI_SHARE_CUSTOM_MODEL_RESOURCE:` | `{APM_PREFIX}BPI_SHARE_CUSTOM_MODEL_RESOURCE:{topoId}` | Hash | 存储第三方自定义实体模型资源池 | **300**（5 min） |

> **APM_PREFIX** 由 Nacos 配置项 `global.private.apm.redis.prefix` 决定，默认值为 `_33_`。

**操作流程**：

```
1. 获取分布式锁 → getLock(BPI_SHARE_RESOURCE_EDIT_KEY, UUID, lockExpireSeconds)
2. 从 DB 分批查询 TOPO 信息
3. 对每个 TOPO：
   a. 正常卡片 → 调用 BpiShareResourceManager.addTopoIdToUpdateResource()
      → updateDataToRedis() → HMSET(BPI_SHARE_RESOURCE:{topoId}, modelKey→instanceSet)
      → PEXPIRE(key, 300000ms)  // 对应截图 HMSET + PEXPIRE 操作
   b. 已删除卡片 → RedisUtils.del(key)  // 对应截图 ULL/DEL 操作
4. finally: releaseLock(BPI_SHARE_RESOURCE_EDIT_KEY, UUID)
```

**核心方法调用链**：

```
BpiShareResourceCacheTask.task()
  └── BpiShareResourceManager.addTopoIdToUpdateResource(false, dto)
        └── update(dto, isLimit=true, shareResourceLookup)
              ├── 查 IAM 权限（含限流重试）
              └── updateDataToRedis(dto, model2InstanceSet, isCustomModel)
                    └── RedisUtils.setHashToRedis(key, map, 300L)   // HMSET + PEXPIRE
```

#### 1.3.2 BpiShareInfoManager — 卡片分享信息缓存

**代码位置**：
`framework/plugins/apm/one-apm/src/main/java/com/bonree/one/apm/module/core/links/manager/BpiShareInfoManager.java`

**使用场景**：当卡片分享关系更新时（前端操作触发），将分享人员信息写入 Redis，用于快速查询"当前卡片被哪些用户分享、哪些用户被过滤"。

| Key 常量 | 实际 Key 格式 | 数据类型 | 操作 | TTL（秒） |
|----------|--------------|----------|------|----------|
| `BPI_SHARE_TOPO_TO_USER` | `{APM_PREFIX}BPI_SHARE_TOPO_TO_USER:{topoId}` | String（JSON） | SET/GET/DEL | **480**（8 min） |
| `BPI_SHARE_TOPO_TO_FILTER` | `{APM_PREFIX}BPI_SHARE_TOPO_TO_FILTER:{topoId}` | String（JSON Set） | SET/GET/DEL | **480**（8 min） |

#### 1.3.3 BpiAlertManager — 告警等级聚合缓存

**代码位置**：
`framework/plugins/apm/one-apm/src/main/java/com/bonree/one/apm/module/core/links/manager/BpiAlertManager.java`

**使用场景**：按告警等级、节点分组统计告警数量时使用，避免频繁查询告警数据库。

| Key 常量 | 实际 Key 格式 | 数据类型 | 操作 | TTL（秒） |
|----------|--------------|----------|------|----------|
| `BPI_LEVEL_ALERT_COUNT_CACHE_KEY:` | `{APM_PREFIX}BPI_LEVEL_ALERT_COUNT_CACHE_KEY:{conditionHash}` | String（JSON） | SET/GET | **60**（1 min） |

#### 1.3.4 LinkNodeRelationEntityTask — 链路节点关联实体缓存任务

**代码位置**：
`framework/plugins/apm/one-apm/src/main/java/com/bonree/one/apm/module/core/links/task/LinkNodeRelationEntityTask.java`

**执行周期**：每 30 分钟（`cron = "0 0/30 * * * ?"`）

**使用场景**：维护服务部署架构（纵向架构）与 BPI 链路节点之间的实体关联关系缓存，支持链路视图中实体节点的架构信息展示。

| Key 常量 | 实际 Key 格式 | 数据类型 | 操作 | TTL（秒） |
|----------|--------------|----------|------|----------|
| `LINK_NODE_RELATION_ENTITY_LOCK` | `link_node_relation_entity_lock`（含框架公共前缀） | String | 分布式锁 | **600**（10 min） |
| `BPI_ENTITY_RELATION_MAP` | `bpi_entity_relation_map:{modelKey}:{accountId}:{envId}` | Hash | HMSET/HGET/DEL | **3600**（1 h） |

#### 1.3.5 ArchitectureCacheTask — 服务部署架构缓存任务

**代码位置**：
`framework/plugins/apm/one-apm/src/main/java/com/bonree/one/apm/module/core/links/task/ArchitectureCacheTask.java`

**执行周期**：启动时初始化 + 每 5 分钟增量刷新（`cron = "0 0/5 * * * ?"`）

**使用场景**：缓存纵向架构（服务部署层级）的自定义规则和默认规则，用于实体归属判断。

| Key 常量 | 实际 Key 格式 | 数据类型 | 操作 | TTL（秒） |
|----------|--------------|----------|------|----------|
| `DEPLOY_ARCHITECTURE_LOCK_V1` | `deploy_architecture_lock_v1` | String | 分布式锁 | **90** |
| `DEPLOY_ARCHITECTURE_UPDATE_TIME_V1` | `deploy_architecture_update_time_v1` | String（timestamp） | SET/GET | 永久（TTL=0） |
| `DEPLOY_ARCHITECTURE_CHANGE` | `deploy_architecture_change` | Hash | HMSET/HGETALL/HDEL | **600**（10 min） |
| `DEPLOY_ARCHITECTURE_CUSTOM_CACHE_MAP` | `deploy_architecture_custom_cache_map:{modelKey}:{accountId}:{envId}` | Hash | HMSET/DEL | 永久（TTL=0） |
| `DEPLOY_ARCHITECTURE_DEFAULT_CACHE` | `deploy_architecture_default_cache:{modelKey}:{accountId}:{envId}` | String | SET/GET/DEL | 永久（TTL=0） |

### 1.4 RUM 模块 Redis Key 详细分析

#### 1.4.1 FiveMinuteJob — RUM 5分钟缓存刷新任务

**代码位置**：
`framework/plugins/rum/rum-cache/src/main/java/com/bonree/rum/cache/cache/jobs/FiveMinuteJob.java`

**执行周期**：每 5 分钟（Quartz Job，cron `0 0/5 * * * ?`）

**使用场景**：驱动 `JobFactory` 中注册了 `FIVE_MINUTE` 执行间隔的全部缓存更新任务，包括 `AccountEnvAppCache` 等。

**子缓存：AccountEnvAppCache**

**代码位置**：
`framework/plugins/rum/rum-cache/src/main/java/com/bonree/rum/cache/cache/cacheitems/AccountEnvAppCache.java`

| Key 格式 | 数据类型 | 操作 | TTL（秒） |
|----------|----------|------|----------|
| `:RUM:account_env_app:{accountId}_{envId}` | String（JSON Set<AppId>） | SET/GET/DEL | **86400**（24 h） |
| `:RUM:account_env_app_lock:{accountId}_{envId}` | String | 分布式锁 | **60** |

**说明**：缓存某账号+环境下所有应用的 ID 集合，用于权限过滤时快速判断用户在指定账号/环境下有哪些应用可见。

#### 1.4.2 PermissionUtil / RedisPermissionUtil — RUM 权限缓存

**代码位置**：
- `framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/permission/PermissionUtil.java`
- `framework/plugins/rum/rum-common/src/main/java/com/bonree/rum/common/util/permission/RedisPermissionUtil.java`

**使用场景**：缓存每个用户在指定账号/环境/资源域下有权限访问的 App ID 集合，避免每次请求都远程调用 IAM/CMDB 接口。两级缓存策略：本地内存（Caffeine）→ Redis → 远程 IAM 查询。

**Key 构造规则**：

```
Key = {CACHE_WEB_PREFIX} + :RUM: + Permission: + {accountId}_{envId}_{userId}_{resourceZoneId}_{permissionType}
```

| 参数 | 说明 |
|------|------|
| `CACHE_WEB_PREFIX` | 框架公共缓存前缀 |
| `:RUM:` | RUM 模块标识 |
| `Permission:` | 权限缓存标识 |
| `permissionType` | `resourceIds` / `readIds` / `manageIds` |

| 数据类型 | 操作 | TTL（秒） |
|----------|------|----------|
| String（JSON Set<AppId>） 或 `"allPermission"` 字符串 | SET/GET/SCAN+DEL | 默认 **180**，可通过 Nacos `global.private.rum.permission.redis.expire` 配置（测试环境默认值 300） |

**清理逻辑**：当用户权限变更时，`PermissionUtil.cleanRedisCache()` 使用 `SCAN` 命令按 pattern 批量删除相关 key。

#### 1.4.3 RumEnvJob — 环境清理定时任务

**代码位置**：
`framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/job/RumEnvJob.java`

**执行周期**：每 5 分钟（`cron = "0 0/5 * * * ?"`）

**使用场景**：定时检测已被删除的 IAM 环境，自动清理该环境下的 RUM 应用数据。

| Key 格式 | 数据类型 | 操作 | TTL（秒） |
|----------|----------|------|----------|
| `:RUM:env_delete_app_lock` | String | 分布式锁 | **5** |
| `:RUM:delete_app_job_last_search_time_key` | String（Long timestamp） | GET/SET | **600**（10 min） |

#### 1.4.4 InitAppScoreRuleSync — 评分规则迁移分布式锁

**代码位置**：
`framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/common/config/InitAppScoreRuleSync.java`

**触发时机**：应用启动时（`ApplicationRunner.run()`），仅执行一次评分规则数据迁移。

**使用场景**：利用 Redis 分布式锁确保多实例部署时只有一个节点执行数据迁移逻辑。

| Key 格式 | 数据类型 | 操作 | TTL（秒） |
|----------|----------|------|----------|
| `RUM_APP_SCORE_RULE_SYNC_LOCK` | String | 分布式锁（非阻塞获取） | **3600**（1 h） |

#### 1.4.5 RumConfigWizardService — SDK 向导配置临时缓存

**代码位置**：
`framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/terminal/service/RumConfigWizardService.java`

**使用场景**：SDK 接入向导流程中，将用户填写的配置信息临时存入 Redis，生成唯一 Token，移动端 SDK 通过 Token 查询配置完成自动接入。

| Key 格式 | 数据类型 | 操作 | TTL（秒） |
|----------|----------|------|----------|
| `SDK:WIZARD:CONFIG:{token}` | String（JSON ConfigData） | GET/SET/DEL | 可配置（默认由 Nacos `wizardTokenExpireSeconds` 决定，默认 86400） |
| `SDK:WIZARD:MAPPING:{accountId}_{envId}_{appId}_{sdkType}` | String（token value） | GET/SET | 同上，`wizardTokenExpireSeconds` |

#### 1.4.6 RUM 首次崩溃判断 — NewCrashUtils

**代码位置**：
`controller/ingester/ingester-assemble/src/main/java/com/bonree/one/ingester/assemble/operator/rum/biz/NewCrashUtils.java`

**使用场景**：判断当前崩溃是否为首次崩溃，用于崩溃去重与首次崩溃标记。采用按时间周期 + 哈希分桶的 Set 结构存储崩溃哈希值。

**Key 格式**：`IS_NEW_CRASH:CRASH_SET_{segmentIndex}{segmentIndex}_offset`

示例：`IS_NEW_CRASH:CRASH_SET_5{5}_12345`

其中 `segmentIndex` 为 0-15 的分桶索引（通过 MurmurHash3 对 `appId:crashId` 哈希取模 16 得到），`offset` 为时间周期偏移量（当前天数除以 `limitPeriod` 默认 30 天）。

| Key 形态 | 数据结构 | 操作 | TTL（天） |
|----------|----------|------|----------|
| `preOffsetKey`（前一个周期） | Set | SADD/SISMEMBER/EXPIRE | `lifePeriod`（默认 60） |
| `currOffsetKey`（当前周期） | Set | SADD/SISMEMBER/EXPIRE | `lifePeriod`（默认 60） |

> 该模块存在内存高涨风险，详见本文档第二章分析与优化方案。

### 1.5 IAM 模块涉及 Redis 的操作（截图相关部分）

#### 1.5.1 IamApiController.pushCostDataV3 — 计费数据上报

**代码位置**：
`framework/plugins/iam/src/main/java/com/bonree/one/iam/api/controller/IamApiController.java`

**截图观测**：`pushCostDataV3` 触发了 `GET` 操作，耗时 25,145ms。

根据 `IamService.java` 分析，计费相关 Redis 用途如下：

| Key 格式 | 数据类型 | 操作 | TTL（秒） |
|----------|----------|------|----------|
| `USER_CURR_LICENSE_PACKAGE`（常量） | String（JSON Map） | GET/SET | 永久（-1） |
| `itemRepeatAlertLimitKey`（动态构造） | String（Long） | GET/SET | 按告警限制配置 |

### 1.6 Redis Key 汇总表

| 所属模块 | Key 名称 / 前缀 | 数据结构 | TTL | 用途摘要 |
|----------|----------------|----------|-----|---------|
| **BPI** | `{APM_PREFIX}BPI_SHARE_RESOURCE_EDIT_KEY` | String（锁） | 配置项（默认较长） | 共享资源池刷新任务分布式锁 |
| **BPI** | `{APM_PREFIX}BPI_SHARE_RESOURCE:{topoId}` | Hash | 300s | 预制实体模型共享资源池 |
| **BPI** | `{APM_PREFIX}BPI_SHARE_CUSTOM_MODEL_RESOURCE:{topoId}` | Hash | 300s | 第三方自定义实体共享资源池 |
| **BPI** | `{APM_PREFIX}BPI_SHARE_TOPO_TO_USER:{topoId}` | String/JSON | 480s | 卡片分享人员信息 |
| **BPI** | `{APM_PREFIX}BPI_SHARE_TOPO_TO_FILTER:{topoId}` | String/JSON | 480s | 卡片过滤用户集合 |
| **BPI** | `{APM_PREFIX}BPI_LEVEL_ALERT_COUNT_CACHE_KEY:{hash}` | String | 60s | 告警等级数量聚合缓存 |
| **BPI** | `link_node_relation_entity_lock` | String（锁） | 600s | 链路节点关联实体任务分布式锁 |
| **BPI** | `bpi_entity_relation_map:{model}:{account}:{env}` | Hash | 3600s | 链路节点与实体关联关系缓存 |
| **BPI** | `deploy_architecture_lock_v1` | String（锁） | 90s | 部署架构缓存任务分布式锁 |
| **BPI** | `deploy_architecture_update_time_v1` | String | 永久 | 架构配置最后更新时间戳 |
| **BPI** | `deploy_architecture_change` | Hash | 600s | 架构配置变更标记 |
| **BPI** | `deploy_architecture_custom_cache_map:{model}:{account}:{env}` | Hash | 永久 | 自定义部署架构规则缓存 |
| **BPI** | `deploy_architecture_default_cache:{model}:{account}:{env}` | String | 永久 | 默认部署架构规则缓存 |
| **RUM** | `:RUM:account_env_app:{accountId}_{envId}` | String/Set | 86400s | 账号+环境应用列表缓存 |
| **RUM** | `:RUM:account_env_app_lock:{accountId}_{envId}` | String（锁） | 60s | 应用缓存刷新分布式锁 |
| **RUM** | `:RUM:Permission:{accountId}_{envId}_{userId}_{zone}_{type}` | String/Set | 180s（可配） | 用户权限 App ID 集合缓存 |
| **RUM** | `:RUM:env_delete_app_lock` | String（锁） | 5s | 环境清理任务分布式锁 |
| **RUM** | `:RUM:delete_app_job_last_search_time_key` | String | 600s | 环境清理任务上次执行时间戳 |
| **RUM** | `RUM_APP_SCORE_RULE_SYNC_LOCK` | String（锁） | 3600s | 评分规则迁移启动锁 |
| **RUM** | `SDK:WIZARD:CONFIG:{token}` | String/JSON | 可配置 | SDK 向导配置临时存储 |
| **RUM** | `SDK:WIZARD:MAPPING:{account}_{env}_{app}_{sdk}` | String | 可配置 | SDK 向导 Token 唯一性映射 |
| **RUM** | `IS_NEW_CRASH:CRASH_SET_{seg}{seg}_offset` | Set | 60d（默认） | 首次崩溃判断崩溃哈希集合 |

### 1.7 分布式锁设计说明

项目中 Redis 分布式锁统一通过框架工具类 `RedisUtils.getLock()` / `RedisUtils.releaseLock()` 实现，底层使用 `SET key value NX PX ttl` 原子命令。

| 特性 | 实现说明 |
|------|---------|
| **非阻塞获取** | `getLock` 返回 Boolean，加锁失败立即返回 false，调用方自行决策是否跳过 |
| **Lua 脚本释放** | `releaseLock` 使用 Lua 脚本实现 GET + DEL 原子操作，防止释放非自己的锁 |
| **重试机制** | `BpiShareResourceCacheTask` 在释放锁失败时最多重试 3 次，间隔递增（100/200/300ms） |
| **应用关闭清理** | `BpiShareResourceCacheTask` 通过 `@PreDestroy` 在应用关闭时主动释放持有的锁，防止锁泄漏 |

### 1.8 截图中慢操作原因分析

| 慢操作 | 可能原因 |
|--------|---------|
| `CLIENT`（30s） | Redis 连接检测或 CLIENT LIST 命令，网络抖动或 Redis 实例负载高 |
| `pushCostDataV3` → `GET`（25s） | 读取 `USER_CURR_LICENSE_PACKAGE` 等大 Value，或 Redis 实例响应慢 |
| `LinkNodeRelationEntityTask` → `HGET`（20s） | `bpi_entity_relation_map` Hash 查询，数据量大或 Redis 慢响应 |
| `BpiShareResourceCacheTask` → `HMSET`（3.3s） | 批量写入大量 topoId 对应的资源池，Value 为复杂 Set 结构序列化后写入 |
| `BpiShareResourceCacheTask` → `PEXPIRE`（3s） | 设置 TTL 操作本身耗时低，延迟来自 Redis 服务端或网络 |
| `BpiShareResourceCacheTask` → `ULL`（18.8s） | 删除已废弃 topoId 对应的共享资源 Hash，DEL 大 Key 触发 Redis 主线程阻塞 |

---

## 二、首次崩溃判断 Redis 内存问题分析与优化方案

### 2.1 问题概述

RUM 模块中判断是否首次崩溃的逻辑可能导致 Redis 内存高涨，需要深入分析代码逻辑，找出内存高涨的根本原因，并提供可行的优化方案。

### 2.2 核心代码逻辑分析

#### 2.2.1 关键代码位置

**核心工具类**：`controller/ingester/ingester-assemble/src/main/java/com/bonree/one/ingester/assemble/operator/rum/biz/NewCrashUtils.java`

**调用位置**：
- `CrashDefaultModelConvert.java`（第 210-213 行）
- `SelfCrashModelConvert.java`（第 124-126 行）

#### 2.2.2 核心方法：checkNewCrash()

```java
public static boolean checkNewCrash(Long appId, String crashId, Integer limitPeriod, Integer lifePeriod) {
    Boolean exists = true;
    try {
        if (crashId.startsWith("#")) {
            String crashHash = crashId.substring(1);

            // 计算offset（时间周期偏移量）
            long offset = getOffset(limitPeriod);
            long priOffset = offset - 1;

            // 计算分桶索引（0-15）
            int segmentIndex = getSegmentIndex(appId, crashId);

            // 获取两个key：前一个周期和当前周期
            String preOffsetKey = getKey(priOffset, segmentIndex);
            String currOffsetKey = getKey(offset, segmentIndex);

            // 处理前一个周期的key
            if (RedisUtils.existKey(preOffsetKey)) {
                exists = RedisUtils.hasValueInSet(preOffsetKey, crashHash);
                if (!exists) {
                    RedisUtils.addSet(preOffsetKey, crashHash);
                }
            } else {
                RedisUtils.addSet(preOffsetKey, crashHash);
                RedisUtils.expire(preOffsetKey, lifePeriod, TIME_UNIT);
                exists = false;
            }

            // 处理当前周期的key
            if (RedisUtils.existKey(currOffsetKey)) {
                RedisUtils.addSet(currOffsetKey, crashHash);
            } else {
                RedisUtils.addSet(currOffsetKey, crashHash);
                RedisUtils.expire(currOffsetKey, lifePeriod, TIME_UNIT);
            }
        }
    } catch (Exception e) {
        log.warn("checkNewCrash error! appId:{}, crashId:{},message：{}", appId, crashId, e.getMessage(), e);
    }
    return !exists;
}
```

#### 2.2.3 关键方法说明

**1. `getOffset(limitPeriod)` — 计算时间周期偏移量**

```java
private static long getOffset(int limitPeriod) {
    long days = Math.floorDiv(System.currentTimeMillis(), (1000 * 60 * 60 * 24));
    return Math.floorDiv(days, limitPeriod);
}
```

- 计算从 1970 年 1 月 1 日到当前时间的天数，然后除以周期（默认 30 天）
- 结果：每 30 天一个周期，offset 会递增

**2. `getSegmentIndex(appId, crashId)` — 计算分桶索引**

```java
private static int getSegmentIndex(Long appId, String crashId){
    int crashHash = Hashing.murmur3_32_fixed(MURMUR_SEED)
        .hashString((appId + ":" + crashId), Charsets.UTF_8).asInt();
    int crashOffset = MathUtils.getABSValue(crashHash);
    return crashOffset % NEW_CRASH_SEGMENT_NUM; // NEW_CRASH_SEGMENT_NUM = 16
}
```

- 使用 MurmurHash3 对 `appId+crashId` 进行哈希
- 取模 16，得到 0-15 的分桶索引

**3. `getKey(offset, segmentIndex)` — 生成 Redis Key**

```java
private static String getKey(long offset, long segmentIndex) {
    return IS_NEW_CRASH + KEY_FIRST + "_" + segmentIndex + "{" + segmentIndex + "}_" + offset;
}
```

- Key 格式：`IS_NEW_CRASH:CRASH_SET_{segmentIndex}{segmentIndex}_offset`
- 示例：`IS_NEW_CRASH:CRASH_SET_5{5}_12345`

> 注：Key 中使用 `{segmentIndex}` 大括号是 Redis 集群模式的 hash tag，确保同一分桶的所有数据落在同一个槽位，便于对同一分桶执行跨 key 操作（如 SUNION 等）。

#### 2.2.4 配置参数

**位置**：`controller/ingester/ingester-common/src/main/java/com/bonree/one/ingester/common/config/rum/RumBaseConfig.java`

```java
@BNacosConfigKey(value = "global.private.rum.crash.limit_period:30")
public Integer LIMIT_PERIOD;  // 默认30天

@BNacosConfigKey(value = "global.private.rum.crash.life_period:60")
public Integer LIFE_PERIOD;   // 默认60天
```

这两个参数与 `controller/rum-controller` 的 `BaseConfig` 中 `global.private.rum.crash.limit_period` / `global.private.rum.crash.life_period` 同名同义，在 ingester 侧由 `RumBaseConfig` 加载并驱动 `NewCrashUtils` 的崩溃判断逻辑。

### 2.3 Redis 内存高涨原因分析

#### 2.3.1 核心问题

**问题1：每个崩溃都会写入两个 Redis Set**

- **现象**：每次调用 `checkNewCrash()` 都会向两个 key 写入数据：
  - `preOffsetKey`（前一个周期）
  - `currOffsetKey`（当前周期）
- **影响**：内存占用翻倍

**问题2：分桶数量过少（仅 16 个）**

- **现象**：所有崩溃 ID 通过哈希取模 16，分散到 16 个 Set 中
- **影响**：
  - 如果崩溃量大，每个 Set 会非常大
  - Redis Set 在元素数量大时，内存效率会下降
  - 假设每天有 1000 万个不同的崩溃 ID，平均每个 Set 约 62.5 万个元素

**问题3：Set 结构内存占用大**

- **现象**：Redis Set 使用哈希表或整数集合存储
- **影响**：
  - 每个元素需要存储 hash 值（8 字节）+ 指针（8 字节）+ 实际数据
  - 对于字符串类型的 crashHash，内存占用 = 8 + 8 + 字符串长度
  - 假设 crashHash 平均 20 字节，每个元素约 36 字节
  - 1000 万崩溃 ID × 36 字节 ≈ 360MB（仅数据，不含 Redis 结构开销）

**问题4：过期时间设置不合理**

- **现象**：
  - `preOffsetKey` 和 `currOffsetKey` 都设置 60 天过期
  - 但实际只需要保留到下一个周期即可
- **影响**：
  - 过期时间过长，导致内存占用时间延长
  - 理论上 `preOffsetKey` 只需要保留到当前周期结束（30 天），但设置了 60 天

**问题5：重复写入问题**

- **现象**：
  - 代码第 75-77 行：如果 `preOffsetKey` 存在且 crashHash 不在 Set 中，会写入
  - 代码第 88-96 行：无论 `currOffsetKey` 是否存在，都会写入 crashHash
- **影响**：
  - 对于已存在的 crashHash，仍然会执行 `addSet` 操作（虽然 Redis Set 会自动去重）
  - 但每次都会进行网络 IO 和 Redis 操作，增加开销

**问题6：没有考虑应用维度**

- **现象**：
  - 所有应用的崩溃 ID 都混在一起，只通过分桶分散
  - 不同应用的崩溃 ID 可能相同，但被当作不同的崩溃处理
- **影响**：
  - 如果多个应用有相同的崩溃 ID，会重复存储
  - 实际上应该按 `appId + crashId` 组合来判断

#### 2.3.2 内存占用估算

**假设场景**：
- 每天新增崩溃 ID 数量：1000 万
- 分桶数量：16
- 每个 crashHash 平均长度：20 字节
- 过期时间：60 天

**计算**：
1. 每个周期（30 天）的崩溃 ID 总数：1000 万 × 30 = 3 亿
2. 每个分桶的崩溃 ID 数量：3 亿 ÷ 16 = 1875 万
3. 每个 Set 的内存占用（仅数据）：
   - 1875 万 × 36 字节 ≈ 675MB
4. 16 个分桶总内存：675MB × 16 = 10.8GB
5. 考虑 Redis 结构开销（约 30%）：10.8GB × 1.3 ≈ 14GB
6. 同时存在两个周期（preOffset 和 currOffset）：14GB × 2 = **28GB**

**实际可能更高**：
- Redis Set 的哈希表扩容机制
- 内存碎片
- 其他 Redis 数据结构开销
- 实际崩溃 ID 可能更多

### 2.4 优化方案

#### 2.4.1 方案1：使用 Redis Bitmap 替代 Set（推荐⭐⭐⭐⭐⭐）

**原理**：使用位图存储，每个崩溃 ID 对应一个 bit 位，内存占用极小

**实现**：

```java
public static boolean checkNewCrash(Long appId, String crashId, Integer limitPeriod, Integer lifePeriod) {
    Boolean exists = true;
    try {
        if (crashId.startsWith("#")) {
            String crashHash = crashId.substring(1);

            // 计算offset和分桶
            long offset = getOffset(limitPeriod);
            long priOffset = offset - 1;
            int segmentIndex = getSegmentIndex(appId, crashId);

            // 计算crashHash在bitmap中的位置
            long bitPosition = getBitPosition(appId, crashHash);

            String preOffsetKey = getKey(priOffset, segmentIndex);
            String currOffsetKey = getKey(offset, segmentIndex);

            // 检查前一个周期
            if (RedisUtils.existKey(preOffsetKey)) {
                exists = RedisUtils.getBit(preOffsetKey, bitPosition);
                if (!exists) {
                    RedisUtils.setBit(preOffsetKey, bitPosition, true);
                }
            } else {
                RedisUtils.setBit(preOffsetKey, bitPosition, true);
                RedisUtils.expire(preOffsetKey, lifePeriod, TIME_UNIT);
                exists = false;
            }

            // 写入当前周期
            if (RedisUtils.existKey(currOffsetKey)) {
                RedisUtils.setBit(currOffsetKey, bitPosition, true);
            } else {
                RedisUtils.setBit(currOffsetKey, bitPosition, true);
                RedisUtils.expire(currOffsetKey, lifePeriod, TIME_UNIT);
            }
        }
    } catch (Exception e) {
        log.warn("checkNewCrash error! appId:{}, crashId:{},message：{}", appId, crashId, e.getMessage(), e);
    }
    return !exists;
}

private static long getBitPosition(Long appId, String crashHash) {
    int hash = Hashing.murmur3_32_fixed(MURMUR_SEED)
        .hashString((appId + ":" + crashHash), Charsets.UTF_8).asInt();
    return MathUtils.getABSValue(hash) & 0x7FFFFFFF; // 确保为正数，最大2^31-1
}
```

**优势**：
- 内存占用极小：每个崩溃 ID 只占 1 个 bit，而不是 36+ 字节
- 1000 万崩溃 ID ≈ 1.25MB（vs Set 的 360MB）
- 查询和写入性能优秀

**劣势**：
- 需要将 crashHash 映射到 bit 位置，可能存在哈希冲突（但概率极低）
- **注意**：Redis 工具类已支持 bitmap 操作（`RedisUtils.setBit()` 和 `RedisUtils.getBit()`），可直接使用

**内存节省**：约 99%+

#### 2.4.2 方案2：增加分桶数量（推荐⭐⭐⭐⭐）

**原理**：增加分桶数量，减少每个 Set 的元素数量

**实现**：

```java
// 将分桶数量从16增加到256或1024
private static final int NEW_CRASH_SEGMENT_NUM = 256; // 或1024
```

**优势**：
- 实现简单，只需修改一个常量
- 每个 Set 的元素数量减少，内存占用降低
- 查询性能提升（Set 越小，查询越快）

**劣势**：
- 仍然使用 Set 结构，内存占用仍然较大
- 需要评估合适的分桶数量（太多会导致 key 数量过多）

**内存节省**：约 50-80%（取决于分桶数量）

#### 2.4.3 方案3：优化过期时间策略（推荐⭐⭐⭐）

**原理**：根据实际需求设置合理的过期时间

**实现**：

```java
// preOffsetKey只需要保留到当前周期结束
int preOffsetLifePeriod = limitPeriod; // 30天
RedisUtils.expire(preOffsetKey, preOffsetLifePeriod, TIME_UNIT);

// currOffsetKey保留到下一个周期结束
int currOffsetLifePeriod = limitPeriod * 2; // 60天
RedisUtils.expire(currOffsetKey, currOffsetLifePeriod, TIME_UNIT);
```

**优势**：
- 实现简单
- 减少内存占用时间

**劣势**：
- 内存占用总量不变，只是占用时间缩短

**内存节省**：约 30-50%（通过缩短占用时间）

#### 2.4.4 方案4：合并 preOffset 和 currOffset 逻辑（推荐⭐⭐⭐）

**原理**：只保留当前周期的 key，通过检查当前周期和上一个周期来判断

**实现**：

```java
public static boolean checkNewCrash(Long appId, String crashId, Integer limitPeriod, Integer lifePeriod) {
    Boolean exists = true;
    try {
        if (crashId.startsWith("#")) {
            String crashHash = crashId.substring(1);

            long offset = getOffset(limitPeriod);
            long priOffset = offset - 1;
            int segmentIndex = getSegmentIndex(appId, crashId);

            String currOffsetKey = getKey(offset, segmentIndex);
            String preOffsetKey = getKey(priOffset, segmentIndex);

            // 先检查当前周期
            boolean existsInCurrent = false;
            if (RedisUtils.existKey(currOffsetKey)) {
                existsInCurrent = RedisUtils.hasValueInSet(currOffsetKey, crashHash);
            }

            // 再检查前一个周期
            boolean existsInPrevious = false;
            if (RedisUtils.existKey(preOffsetKey)) {
                existsInPrevious = RedisUtils.hasValueInSet(preOffsetKey, crashHash);
            }

            exists = existsInCurrent || existsInPrevious;

            // 只写入当前周期
            if (!existsInCurrent) {
                if (RedisUtils.existKey(currOffsetKey)) {
                    RedisUtils.addSet(currOffsetKey, crashHash);
                } else {
                    RedisUtils.addSet(currOffsetKey, crashHash);
                    RedisUtils.expire(currOffsetKey, lifePeriod, TIME_UNIT);
                }
            }
        }
    } catch (Exception e) {
        log.warn("checkNewCrash error! appId:{}, crashId:{},message：{}", appId, crashId, e.getMessage(), e);
    }
    return !exists;
}
```

**优势**：
- 每个崩溃只写入一个 Set，内存占用减半
- 逻辑更清晰

**劣势**：
- 仍然需要检查两个 key，但只写入一个

**内存节省**：约 50%

#### 2.4.5 方案5：使用 HyperLogLog（推荐⭐⭐）

**原理**：使用 HyperLogLog 统计基数，判断是否首次出现

**实现**：

```java
public static boolean checkNewCrash(Long appId, String crashId, Integer limitPeriod, Integer lifePeriod) {
    Boolean exists = true;
    try {
        if (crashId.startsWith("#")) {
            String crashHash = crashId.substring(1);

            long offset = getOffset(limitPeriod);
            long priOffset = offset - 1;
            int segmentIndex = getSegmentIndex(appId, crashId);

            String preOffsetKey = getKey(priOffset, segmentIndex);
            String currOffsetKey = getKey(offset, segmentIndex);

            // 使用HyperLogLog判断
            long preCount = RedisUtils.pfCount(preOffsetKey);
            RedisUtils.pfAdd(preOffsetKey, crashHash);
            long preCountAfter = RedisUtils.pfCount(preOffsetKey);

            // 如果基数增加，说明是新元素
            if (preCountAfter > preCount) {
                exists = false;
            } else {
                // 检查当前周期
                long currCount = RedisUtils.pfCount(currOffsetKey);
                RedisUtils.pfAdd(currOffsetKey, crashHash);
                long currCountAfter = RedisUtils.pfCount(currOffsetKey);
                if (currCountAfter > currCount) {
                    exists = false;
                }
            }

            // 设置过期时间
            if (!RedisUtils.existKey(preOffsetKey)) {
                RedisUtils.expire(preOffsetKey, lifePeriod, TIME_UNIT);
            }
            if (!RedisUtils.existKey(currOffsetKey)) {
                RedisUtils.expire(currOffsetKey, lifePeriod, TIME_UNIT);
            }
        }
    } catch (Exception e) {
        log.warn("checkNewCrash error! appId:{}, crashId:{},message：{}", appId, crashId, e.getMessage(), e);
    }
    return !exists;
}
```

**优势**：
- 内存占用极小（每个 HyperLogLog 约 12KB）
- 可以统计基数

**劣势**：
- HyperLogLog 是概率性数据结构，存在误差（约 0.81%）
- 无法精确判断某个元素是否存在，只能判断基数是否变化
- 不适合精确判断首次崩溃的场景

**适用性**：不推荐，因为需要精确判断

#### 2.4.6 方案6：组合优化方案（最佳实践⭐⭐⭐⭐⭐）

**组合使用方案1（Bitmap）+ 方案2（增加分桶）+ 方案3（优化过期时间）**

**完整实现**：

```java
public class NewCrashUtils {

    // 增加分桶数量
    private static final int NEW_CRASH_SEGMENT_NUM = 256;
    private static final int MURMUR_SEED = 1318007700;
    private static final String IS_NEW_CRASH = "IS_NEW_CRASH:";
    private static final String KEY_FIRST = "CRASH_SET";
    private static final TimeUnit TIME_UNIT = TimeUnit.DAYS;

    // Bitmap最大位数（2^31，约21亿）
    // 注意：RedisUtils.getBit/setBit的offset参数是int类型，最大2^31-1
    private static final int MAX_BIT_POSITION = 0x7FFFFFFF;

    public static boolean checkNewCrash(Long appId, String crashId, Integer limitPeriod, Integer lifePeriod) {
        Boolean exists = true;
        try {
            if (crashId.startsWith("#")) {
                String crashHash = crashId.substring(1);

                long offset = getOffset(limitPeriod);
                long priOffset = offset - 1;
                int segmentIndex = getSegmentIndex(appId, crashId);

                // 计算bit位置
                int bitPosition = getBitPosition(appId, crashHash);

                String preOffsetKey = getKey(priOffset, segmentIndex);
                String currOffsetKey = getKey(offset, segmentIndex);

                // 检查前一个周期
                boolean existsInPrevious = false;
                if (RedisUtils.existKey(preOffsetKey)) {
                    existsInPrevious = RedisUtils.getBit(preOffsetKey, bitPosition);
                }

                // 检查当前周期
                boolean existsInCurrent = false;
                if (RedisUtils.existKey(currOffsetKey)) {
                    existsInCurrent = RedisUtils.getBit(currOffsetKey, bitPosition);
                }

                exists = existsInPrevious || existsInCurrent;

                // 只写入当前周期（如果不存在）
                if (!existsInCurrent) {
                    RedisUtils.setBit(currOffsetKey, bitPosition, true);
                    if (!RedisUtils.existKey(currOffsetKey)) {
                        // 设置过期时间：当前周期 + 一个周期（确保覆盖）
                        RedisUtils.expire(currOffsetKey, limitPeriod * 2, TIME_UNIT);
                    }
                }

                // 前一个周期只读，不写入
            }
        } catch (Exception e) {
            log.warn("checkNewCrash error! appId:{}, crashId:{},message：{}",
                appId, crashId, e.getMessage(), e);
        }
        return !exists;
    }

    private static long getOffset(int limitPeriod) {
        long days = Math.floorDiv(System.currentTimeMillis(), (1000 * 60 * 60 * 24));
        return Math.floorDiv(days, limitPeriod);
    }

    private static int getSegmentIndex(Long appId, String crashId) {
        int crashHash = Hashing.murmur3_32_fixed(MURMUR_SEED)
            .hashString((appId + ":" + crashId), Charsets.UTF_8).asInt();
        int crashOffset = MathUtils.getABSValue(crashHash);
        return crashOffset % NEW_CRASH_SEGMENT_NUM;
    }

    private static int getBitPosition(Long appId, String crashHash) {
        int hash = Hashing.murmur3_32_fixed(MURMUR_SEED)
            .hashString((appId + ":" + crashHash), Charsets.UTF_8).asInt();
        return MathUtils.getABSValue(hash) & MAX_BIT_POSITION;
    }

    private static String getKey(long offset, long segmentIndex) {
        return IS_NEW_CRASH + KEY_FIRST + "_" + segmentIndex + "{" + segmentIndex + "}_" + offset;
    }
}
```

**优势**：
- 内存占用极小（Bitmap）
- 查询性能优秀
- 分桶数量增加，进一步分散
- 过期时间优化

**预期效果**：
- 内存占用从 28GB 降低到约 **100-200MB**（节省 99%+）
- 查询性能提升
- 写入性能提升

### 2.5 实施建议

#### 2.5.1 推荐方案

**优先采用方案6（组合优化）**，原因：
1. 内存节省效果最显著（99%+）
2. 性能提升明显
3. 实现复杂度适中
4. 风险可控

#### 2.5.2 实施步骤

1. **第一阶段：增加分桶数量（方案2）**
   - 风险低，实现简单
   - 立即见效，内存节省 50-80%
   - 实施时间：1 天

2. **第二阶段：优化过期时间（方案3）**
   - 风险低，实现简单
   - 进一步优化
   - 实施时间：1 天

3. **第三阶段：改为 Bitmap（方案1）**
   - 需要充分测试
   - 需要修改 Redis 工具类
   - 实施时间：3-5 天
   - 需要灰度发布

#### 2.5.3 注意事项

1. **数据迁移**：如果从 Set 改为 Bitmap，需要考虑历史数据的处理
2. **哈希冲突**：Bitmap 方案需要评估哈希冲突的概率（通常极低）
3. **监控**：实施后需要密切监控 Redis 内存使用情况
4. **回滚方案**：准备回滚方案，以防出现问题
5. **Redis 工具类 Bug**：`RedisUtils.getBit()` 方法中使用了硬编码的 `"ONE:"` 前缀，而 `setBit()` 使用 `redisPrefix` 变量，可能导致不一致。建议修复或统一使用 `redisPrefix`
6. **offset 类型**：`RedisUtils.getBit/setBit` 的 offset 参数是 `int` 类型，最大值为 2^31-1（约 21 亿），足够使用

#### 2.5.4 监控指标

实施后需要监控：
- Redis 内存使用量
- Redis key 数量
- 查询延迟
- 写入延迟
- 错误率

### 2.6 总结

RUM 模块首次崩溃判断逻辑导致 Redis 内存高涨的主要原因：
1. 每个崩溃写入两个 Set
2. 分桶数量过少（16 个）
3. Set 结构内存占用大
4. 过期时间设置不合理

**推荐优化方案**：组合使用 Bitmap + 增加分桶 + 优化过期时间，预期可节省 99%+ 的内存占用。
