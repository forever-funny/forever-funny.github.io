# 计费逻辑与 MAU 完整分析

> 工程版本：newonexm 仓库 `controller/controller` 模块当前主干
> 核心包：`com.bonree.one.controller.service.config.rum.license`、`com.bonree.one.controller.service.config.rum.impl`、`com.bonree.one.controller.service.config.rum.cache`、`com.bonree.one.controller.task`

---

## 目录

1. [RUM 模块计费逻辑概述](#一rum-模块计费逻辑概述)
2. [MAU（月活跃用户）计费完整逻辑](#二mau月活跃用户计费完整逻辑)
3. [问题分析与优化建议](#三问题分析与优化建议)

---

## 一、RUM 模块计费逻辑概述

### 1.1 计费类型与去重规则

RUM 模块支持三种计费类型，由 `LicenseType` 枚举（`com.bonree.one.controller.common.enums.LicenseType`）定义：

| 计费类型 | 枚举值 | type 码 | 统计周期 | 去重粒度 | 技术实现 |
|---------|--------|--------|---------|---------|---------|
| **DAU**（日活跃用户） | `LicenseType.DAU` | 1 | 每日（按自然天，当天 0 点为 stage） | 每设备（deviceId）每天只计 1 次 | Redis **HyperLogLog** + **Bitmap** 双重复核 |
| **MAU**（月活跃用户） | `LicenseType.MAU` | 2 | 每月（按自然月，当月 1 日 0 点为 stage） | 每设备每月只计 1 次 | Redis **HyperLogLog** + **Bitmap**，Key 按月格式化（yyyyMM） |
| **US**（使用量） | `LicenseType.US` | 3 | 每小时上报，按会话时长分段 | 每会话（session）按 30 分钟间隔分段去重 | Redis **HyperLogLog**，按 `(session, 时间片)` 去重 |

> 说明：在 newonexm 当前主干中，`UsmLicenseService.configFilter()` 直接返回 `true`（见 `controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/license/UsmLicenseService.java`），US 的会话分段去重逻辑在 controller 模块已简化；US 用量统计与推送由上层（原 rum-controller 仓库的 `PushLicenseUsedJob`）按小时级推送完成。下文以 MAU/DAU 的设备级去重计费为主要分析对象。

### 1.2 关键实现细节

- **DAU/MAU**：使用 `configFilter()` 判断设备是否已记录，未超限则向 HyperLogLog（`PFADD`）和 Bitmap（`SETBIT`）同时写入；Bitmap 用于快速判断设备是否已上报，HyperLogLog 用于近似去重计数。
- **US**：历史实现使用 `uploadFilter()` 计算会话时长（`mt - cmt`），按 30 分钟一片段切割，每个片段作为一个去重项加入 HyperLogLog。当前主干 `UsmLicenseService` 已不再在 controller 侧做去重。
- **去重 Key 结构**（基于 `DauLicenseService` / `MauLicenseService` 实际代码）：
  - DAU HyperLogLog：`LICENSE:DAU_PF_{userId}_{appId}_{yyyyMMdd}_{hashSegment}`
  - DAU Bitmap：`LICENSE:DAU_BIT_{yyyyMMdd}_{hashSegment}`
  - MAU HyperLogLog（无资源包）：`LICENSE:MAU_PF_{userId}_{appId}_{yyyyMM}_{hashSegment}`
  - MAU HyperLogLog（有资源包）：`LICENSE:MAU_PF_{userId}_{appId}_{yyyyMM}_{hashSegment}_{resBundleId}`
  - MAU Bitmap：`LICENSE:MAU_BIT_{yyyyMM}_{hashSegment}`
  - US HyperLogLog（历史）：`LICENSE:USM_PF_{userId}_{appId}_{yyyyMMdd}_{hash}`

其中 `hashSegment = hash % baseConfig.redisHashNum`，`offset = hash / baseConfig.redisHashNum`，`hash = HashUtils.absHash(join(deviceId, appId))`。

### 1.3 计费触发流程

1. **数据上报入口**：RUM 探针请求 `/config` 时，由 `RumConfigServiceImpl` 处理，其中 `checkLicense()`（`controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/impl/RumConfigServiceImpl.java`）负责 License 校验：
   - 通过 `rumCacheService.getUserLicenseModel(userId)` 获取 `LicenseModel`；
   - 若 `licenseModel == null`，返回 `ResponseCode.USER_ABNORMAL_OR_NOT_AVAILABLE_PACKAGE`；
   - 通过 `AbstractLicenseService.getInstance(licenseModel.getLicenseType())` 获取对应计费服务实例；
   - 调用 `instance.configFilter(licenseModel, deviceId, appId, envId)`：
     - **所有平台**的 config 请求均走 `configFilter()`；
   - `configFilter()` 返回 `false` 时返回 `ResponseCode.LICENSE_SUBSCRIBE_EXPIRE`。
2. **平台差异**：历史实现中，upload 请求仅 Web 平台（`OSPlatformTypeEnum.WEB`）调用 `configFilter()`，其他平台调用 `uploadFilter()`；MAU 的 `uploadFilter()` 直接返回 `true`，不做校验。`OSPlatformTypeEnum` 定义于 `controller/controller/src/main/java/com/bonree/one/controller/common/enums/OSPlatformTypeEnum.java`，枚举值：(1, Android), (2, iOS), (3, Web), (4, Windows), (5, WechatMiniProgram), (6, HarmonyOS)。
3. **配额检查**：检查全局限额（`limit`）及环境配额（`LicenseEnvModel`），若启用资源包模式（`meteredItemType=3`）则按资源包分配额度。
4. **Redis 操作**：通过异步阻塞队列 `redisQueue`（`ArrayBlockingQueue<RedisModel>`，容量 5000，定义于 `AbstractLicenseService`）批量提交 HyperLogLog/Bitmap 的 `PFADD`/`SETBIT`/`PEXPIRE` 命令，避免阻塞上传线程。

### 1.4 用量统计与上报

1. **用量落库定时任务**：`UpdateLicenseUsedJob`（每 10 分钟执行，Quartz `TenMinuteJob`）
   - 遍历所有 App，对当前月所有分片 Key 执行 `PFCOUNT` 汇总求和，得到 `currNum`；
   - 构造记录写入 `t_rum_license_record`（type=2，stage=当月 1 日 0 点，status=0 待推送）；
   - 同步更新 Redis Hash `LICENSE:CURRENT_NUM` 中的各 App 当前用量；
   - 每天 0 点附加执行一次清理：删除 `baseConfig.licenseRecordDeleteTime`（默认 60 天）前的流水记录。
2. **推送定时任务**：`PushLicenseUsedJob`（每小时执行，Quartz `OneHourJob`）
   - **US**：每小时推送一次增量使用量；
   - **DAU/MAU**：仅在凌晨 1 点（`LocalDateTime.now().getHour() == 1`）推送。
3. **增量计算**：各服务实现 `getCurrIncrement()`，查询 MySQL 中当前周期内的去重计数，并与已推送记录比对，计算净增量。
4. **推送至云端**：组装 JSON 数据，通过 HTTP POST 发送到 IAM 平台（`/api/iam/v3/cost/push`），成功后更新数据库状态为 `async_pushed`（status=1），失败则标记为 `async_failed`（status=2），最多重试 2 次。

### 1.5 配额与资源包模式

- **环境配额**：`LicenseModel.quotaType=1` 时，可为不同环境（envId）分配独立限额（`LicenseEnvModel`）。
- **资源包模式**：`meteredItemType=3` 时，MAU 支持将额度分配到多个资源包（`ResBundleModel`），每个资源包可绑定多个应用，实现更细粒度的额度管控。`meteredItemType` 含义：1=按创建人，2=按资源域，3=按应用（资源包模式）。

### 1.6 数据持久化与状态

- **数据库表**：`t_rum_license_record`（建表脚本见 `script/one_framework_rum/INIT/mariadb/all/one_rum_table.sql` 等）记录每次推送的用量、阶段（stage）、状态。
- **状态枚举**：status 0=待推送（async_wait），1=已推送（async_pushed），2=推送失败（async_failed）。
- **Redis 缓存**：HyperLogLog/Bitmap 数据设置 TTL（DAU 为 2 天，US 历史为 2 天，MAU 为两个月后的 1 号 0 点），防止无限膨胀。

### 1.7 关键配置参数

| 配置项（Nacos key） | 默认值 | 说明 |
|--------------------|--------|------|
| `global.address.web.url.inner` | 空 | IAM 接口基础地址（**必须配置**）|
| `global.common.one.api.token` | `eyJhbGciOiJIUzI1NiJ9` | IAM 鉴权 Token |
| `global.private.rum.iam.get` | `/api/iam/v4/package/get` | 查询 License 接口路径 |
| `global.private.rum.iam.push` | `/api/iam/v3/cost/push` | 推送计费接口路径 |
| `global.private.rum.filter.check.deviceId` | `true` | 是否校验 deviceId 格式 |
| `global.private.rum.license.expire.time` | 60 天（单位分钟） | License 缓存过期时间 |
| `global.private.rum.base.license.redis.hash.num` | N/A（见代码） | Redis 分片数 `baseConfig.redisHashNum`，用于分散单个 Key 的存储压力 |
| `global.private.rum.license.record.delete.time` | 60 | 历史记录保留天数 |
| `baseConfig.redisThreadNum` | N/A | `RedisPipelineThread` 线程数，由 `RumLicenseListener` 启动 |
| `licenseCacheJobTimeMin` | 10 | 缓存任务执行周期（分钟），影响 `getQueryStageTime()` 的时间范围 |
| `sessionIntervalMs` | 30 分钟 | US 计费的会话分段间隔（历史实现） |

### 1.8 核心类说明

| 类 | newonexm 路径 | 职责 |
|----|--------------|------|
| `AbstractLicenseService` | `controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/license/AbstractLicenseService.java` | 计费服务抽象基类，定义 `configFilter`/`getInstance`/`getQueryStageTime` 通用接口，持有 `redisQueue`、`ttlCache`、`licenseCacheJobTimeMin` 静态成员 |
| `DauLicenseService` | `controller/controller/.../service/config/rum/license/DauLicenseService.java` | DAU 计费服务实现，TTL=2 天 |
| `MauLicenseService` | `controller/controller/.../service/config/rum/license/MauLicenseService.java` | MAU 计费服务实现（支持资源包模式），TTL=两个月后 1 号 0 点 |
| `UsmLicenseService` | `controller/controller/.../service/config/rum/license/UsmLicenseService.java` | US 计费服务实现，当前 `configFilter()` 直接返回 `true` |
| `RedisPipelineThread` | `controller/controller/.../service/config/rum/license/RedisPipelineThread.java` | 异步 Redis pipeline 写入线程，消费 `redisQueue` |
| `RedisConsumer` | `controller/controller/.../service/config/rum/license/RedisConsumer.java` | Redis 操作消费者 |
| `RumLicenseListener` | `controller/controller/.../service/common/init/RumLicenseListener.java` | 应用启动监听器，启动 `RedisPipelineThread` 线程 |
| `RumConfigServiceImpl` | `controller/controller/.../service/config/rum/impl/RumConfigServiceImpl.java` | RUM config 请求处理入口，含 `checkLicense()` |
| `LicenseModel` | `controller/controller/.../domain/model/rum/LicenseModel.java` | License 模型（userId、licenseType、limit、currNum、quotaType、meteredItemType、envs）|
| `LicenseEnvModel` | `controller/controller/.../domain/model/rum/LicenseEnvModel.java` | 环境配额模型（envIds、limit、currEnvNum、resBundles）|
| `LicenseInfo` | `controller/controller/.../service/config/rum/impl/LicenseInfo.java` | License 聚合信息（licenseType、quotaType、meteredItemType、total、limit、license、envs）|
| `LicenseType` | `controller/controller/.../common/enums/LicenseType.java` | 计费类型枚举（DAU=1, MAU=2, US=3）|
| `OSPlatformTypeEnum` | `controller/controller/.../common/enums/OSPlatformTypeEnum.java` | 操作系统平台枚举 |
| `UpdateLicenseUsedJob` | 旧 rum-controller 仓库 `manager/.../job/` | 用量落库定时任务（每 10 分钟）|
| `PushLicenseUsedJob` | 旧 rum-controller 仓库 `manager/.../job/` | 用量推送定时任务（每小时，MAU/DAU 凌晨 1 点）|
| `LicenseCache` | 旧 rum-controller 仓库 `cache-server/.../cache/license/` | 许可证信息缓存（每 10 分钟从 IAM 拉取）|
| `LicenseMapper` | 旧 rum-controller 仓库 `cache-server/.../mapper/` | `t_rum_license_record` 持久化 Mapper |
| `LicenseEntity` | 旧 rum-controller 仓库 `cache-server/.../entity/` | `t_rum_license_record` 实体 |

> 注：`UpdateLicenseUsedJob`、`PushLicenseUsedJob`、`LicenseCache`、`LicenseMapper`、`LicenseEntity` 在 newonexm 仓库 `controller/controller` 模块中未直接找到对应类，属于历史 rum-controller 仓库组件；其逻辑由上层服务或定时任务承载，下文按历史实现描述完整链路。`OneHourJob`/`TenMinuteJob` 为旧仓库 Quartz 调度类。

### 1.9 设计特点

1. **高性能**：异步队列处理 Redis 操作，不阻塞上传流程；
2. **弹性配额**：支持全局、环境、资源包三级配额管理；
3. **数据一致性**：增量推送机制避免重复计费；
4. **扩展性**：抽象服务模式（`AbstractLicenseService` + `getInstance(LicenseType)` 工厂）便于新增计费类型。

---

## 二、MAU（月活跃用户）计费完整逻辑

### 2.1 MAU 定义与本质

MAU 计费的本质：**统计一个自然月内，访问某 App 的去重设备数量**，与 IAM（License 管理系统）下发的套餐上限对比，决定是否允许数据接入，并每天一次将增量用量推送到 IAM 进行计费。

- 计费阶段（stage）：当月 1 日 0 点；
- 去重维度：设备（deviceId）+ 应用（appId）；
- 计费周期：自然月，月初 HyperLogLog/Bitmap 重新建 Key。

### 2.2 MAU 整体架构流程图

```
设备请求 /config 或 /upload
          │
          ▼
    RumConfigServiceImpl.checkLicense() / UploadController.checkLicense()
    ─── 根据 LicenseModel.licenseType 获取 AbstractLicenseService 实例 ───
          │
          ▼
    LicenseCache.get(userId)      ← 每10min从IAM拉取，内存缓存
          │
    licenseModel.licenseType == MAU
          │
          ▼
    MauLicenseService.configFilter()
       ┌──────────────────────────────────────────┐
       │  1. 查 Bitmap 是否已计费过（优先判重）    │
       │  2. 已计费 → return true（放行）         │
       │  3. 未计费：currNum < limit ?            │
       │  4. 配额类型/资源包/环境检查              │
       │  5. 写 HyperLogLog + Bitmap              │
       │     (异步入队 redisQueue)                │
       │  6. 超量且未计费 → return false           │
       └──────────────────────────────────────────┘
          │ return true（允许） / false（超量）
          ▼
    数据接入或返回 LICENSE_SUBSCRIBE_EXPIRE / MAU_FILTER

    ──────────────── 异步 ─────────────────

    RedisPipelineThread (后台常驻线程，由 RumLicenseListener 启动)
       └── 消费 redisQueue，批量 pipeline 写入 Redis
              ├── PFADD  HyperLogLog（去重计数）
              ├── SETBIT Bitmap（标记已计费）
              └── PEXPIRE 设置 TTL

    ──────────────── 定时 ─────────────────

    UpdateLicenseUsedJob (每10min，Quartz TenMinuteJob)
       └── 读取 Redis HyperLogLog PFCOUNT
            ├── batchInsert → t_rum_license_record (type=2, status=0)
            └── HSET LICENSE:CURRENT_NUM {appId} {currNum}

    PushLicenseUsedJob (每1小时，Quartz OneHourJob)
       └── 每天凌晨1点执行 MAU 推送
            ├── getCurrIncrement()：查 MySQL 待推送记录
            ├── 计算增量 = currNum - 上次已推送量
            └── HTTP POST → IAM /api/iam/v3/cost/push
                 ├── 成功：更新 status=1（async_pushed）
                 └── 失败：更新 status=2（async_failed），最多重试2次
```

### 2.3 接入层 —— 设备是否被计费（configFilter）

#### 2.3.1 触发入口

- **config 请求**：`RumConfigServiceImpl.checkLicense()`（`controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/impl/RumConfigServiceImpl.java`），**所有平台**均调用 `configFilter()`。
- **upload 请求**：历史实现中 `UploadController.checkLicense()` 仅 **Web 平台**（`OSPlatformTypeEnum.WEB`）调用 `configFilter()`，其他平台调用 `uploadFilter()`（MAU 的 `uploadFilter()` 直接返回 `true`，不做校验）。

#### 2.3.2 MauLicenseService.configFilter() 实际逻辑

源文件：`controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/license/MauLicenseService.java`

```java
public boolean configFilter(LicenseModel licenseModel, String deviceId, Long appId, String envId) {
    final int hash = HashUtils.absHash(join(deviceId, appId));
    final int segment = hash % baseConfig.redisHashNum;   // Redis 分片号
    final int offset  = hash / baseConfig.redisHashNum;   // Bitmap 偏移量

    // ① 优先查 Bitmap：该设备本月是否已计费过
    boolean redisLimitFlag = redisClient.getBit(getBitRedisKey(new Date(), segment), offset);
    if (redisLimitFlag) {
        return true;   // 已计费，直接放行（不重复计费，也不重复写 Redis）
    }

    if (licenseModel.getCurrNum() < licenseModel.getLimit()) {
        // ② 尚未超量：进入资源包/环境配额细分逻辑
        Long resBundleId = null;
        if (licenseModel.getQuotaType() != null && licenseModel.getQuotaType() == 1) {
            // 自定义配额：按环境检查
            List<LicenseEnvModel> envs = licenseModel.getEnvs();
            // 找到匹配 envId 的环境配置
            //   └─ meteredItemType == 3（资源包模式）：遍历资源包找 appId 所属资源包
            //       └─ 资源包 currEnvNum < limit → 有余量，记录 resBundleId
            //       └─ 所有资源包超量 → return false
            //   └─ 非资源包：envModel.currEnvNum >= limit → 查 Bitmap 决定放行/拒绝
            // 未找到匹配环境 → return false
        }
        // ③ 写 HyperLogLog + Bitmap（异步入队 redisQueue）
        redisQueue.put(RedisModel.builder().option(Option.add_hyperloglog)
            .key(getBfRedisKey(userId, appId, new Date(), segment, resBundleId))
            .value(join(deviceId, appId)).build());
        redisQueue.put(RedisModel.builder().option(Option.add_bitmap)
            .key(getBitRedisKey(new Date(), segment)).value(offset).build());
        // ④ 设置 TTL（仅首次写入，通过 ttlCache 去重）
        return true;   // 允许接入
    } else {
        // ⑤ 已超量且未计费（Bitmap=0）→ 拒绝
        return false;
    }
}
```

> 与历史描述的差异：当前 newonexm 主干代码**先查 Bitmap 再查超量**，已计费设备无论是否超量都直接放行，避免超量场景下重复查 Bitmap。历史描述为"先查超量，超量后再查 Bitmap"，两者最终行为一致，但当前代码更高效。

#### 2.3.3 关键判断逻辑（未超量时的详细步骤）

| 步骤 | 判断内容 | 结果 |
|------|----------|------|
| 1 | `redisClient.getBit(...)` 设备本月是否已计费 | 已计费 → return true（不重复写）|
| 2 | `licenseModel.getCurrNum() < limit` | 未超量继续；超量 → return false |
| 3 | `quotaType == 1`（自定义配额） | 进入环境级配额检查；否则直接写 Redis |
| 4 | 找到匹配 envId 的环境配置 | 继续；未找到 → return false |
| 5 | `meteredItemType == 3`（资源包模式） | 遍历资源包，找到 appId 所属资源包 |
| 6 | 资源包 `currEnvNum < limit` | 有余量，记录 resBundleId；都超量 → return false |
| 7 | 非 resourceBundle 模式下 `envModel.currEnvNum >= limit` | 查 Bitmap 决定放行/拒绝 |
| 8 | 写 HyperLogLog + Bitmap（异步入队） | return true（允许接入） |

#### 2.3.4 超量后的策略

```
超量 + 该设备本月已计费（Bitmap=1） → 放行（已付费设备继续采集）
超量 + 该设备本月未计费（Bitmap=0） → 拒绝（ResponseCode.MAU_FILTER = 30002 / LICENSE_SUBSCRIBE_EXPIRE）
```

### 2.4 Redis 数据结构设计

#### 2.4.1 HyperLogLog（去重计数）

```
Key格式：LICENSE:MAU_PF_{userId}_{appId}_{yyyyMM}_{hashSegment}
          （有资源包时末尾加 _{resBundleId}）

Value：   PFADD "deviceId_appId"  （字符串拼接作为基数元素）

示例：    LICENSE:MAU_PF_10001_2001_202606_0
          LICENSE:MAU_PF_10001_2001_202606_0_500

用途：    PFCOUNT 获取近似去重设备数（HyperLogLog 误差率约 0.81%）
分片：    按 redisHashNum 分片，多节点集群部署时分散热点
```

> 代码中 `MauLicenseService` 同时维护 `redisPfKey`（5 段，含 resBundleId）和 `preRedisPfKey`（4 段，兼容无 resBundleId 的历史 Key）：`resBundleId == null` 时使用 `preRedisPfKey`，否则使用 `redisPfKey`。

#### 2.4.2 Bitmap（设备是否本月已计费标记）

```
Key格式：LICENSE:MAU_BIT_{yyyyMM}_{hashSegment}

Value：   SETBIT offset 1   （offset = hash / redisHashNum）

示例：    LICENSE:MAU_BIT_202606_0

用途：    快速判断设备本月是否已被计费过（超量时避免重复过滤老用户）
```

#### 2.4.3 Redis TTL 过期策略

```
过期时间 = 两个月后的 1 日 0 点（例如：6 月 15 日的数据 → 8 月 1 日 0 点过期）
实现：    LocalDate.now().plusMonths(2).withDayOfMonth(1).atStartOfDay()
          → 转毫秒 TTL = ttlDate - System.currentTimeMillis()

注意：    TTL 只在 key 首次写入时设置（通过内存 ttlCache 去重），
          不会每次请求都重复设置，以节省 Redis 操作。
```

DAU 的 TTL 为固定 2 天（`DauLicenseService.ttl = 2 * 24 * 60 * 60 * 1000L`）。

#### 2.4.4 当前用量缓存（Hash）

```
Key：     LICENSE:CURRENT_NUM（全局共享 Hash）
Field：   "{appId}"  或  "{appId}_{resBundleId}"
Value：   当前月活用量数值字符串

写入：    UpdateLicenseUsedJob 每 10min 从 HyperLogLog PFCOUNT 后写入
读取：    LicenseCache 更新时，从此 Hash 读取各 App 当前用量，填充 licenseModel.currNum
```

### 2.5 异步 Redis 写入线程（RedisPipelineThread）

**类**：`RedisPipelineThread`（`controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/license/RedisPipelineThread.java`）
**启动**：`RumLicenseListener.onApplicationEvent()`（`controller/controller/src/main/java/com/bonree/one/controller/service/common/init/RumLicenseListener.java`），监听 `ApplicationStartedEvent`，按 `privateConfig.redisThreadNum` 启动对应数量的线程。

```
工作模式：
  1. 不断 poll redisQueue（AbstractLicenseService.redisQueue，ArrayBlockingQueue 容量 5000）
  2. 积累 pipeline 批次（超过 10ms 或 100 条触发一次批量执行）
  3. 批量 executePipelined：PFADD / SETBIT / PEXPIRE
  4. 执行完后将已处理的 TTL key 放入内存 ttlCache（避免重复设置 TTL）

风险点：
  - redisQueue 容量上限 5000，高并发时可能阻塞 configFilter() 中的 put() 操作
  - 线程异常退出时，redisQueue 中积压的计费数据会丢失
```

`Option` 枚举（`com.bonree.one.controller.common.enums.Option`）定义 Redis 操作类型：`add_hyperloglog`（PFADD）、`add_bitmap`（SETBIT）、`ttl_key`（PEXPIRE）等。

### 2.6 定时 Job —— 用量落库（UpdateLicenseUsedJob）

**类**：`UpdateLicenseUsedJob`（旧 rum-controller 仓库 `manager/.../job/`）
**调度**：Quartz `TenMinuteJob`（每 10 分钟，注册到 `ExecuteInterval.TEN_MINUTE`）
**分布式锁**：Redis key `UpdateLicenseUsedJob`，锁超时 200 秒，防止多实例重复执行。

```
执行流程：
  1. 遍历所有 AppEntity
  2. 通过 userId 获取 licenseModel（LicenseCache）
  3. 调用 instance.getCurrUpdateNum(model, entity.getId())
     └── MAU 实现：对当前月所有分片 Key 执行 PFCOUNT，汇总求和
  4. 若 currNum > 0：构造 LicenseEntity
     ├── type = 2（MAU）
     ├── stage = 当月 1 日 0 点
     ├── status = 0（async_wait，待推送）
     └── createTime = 当前时间 - 10min（略微滞后，与查询时间对齐）
  5. batchInsert → t_rum_license_record
  6. HSET LICENSE:CURRENT_NUM {appId} {currNum}

  附加逻辑（每天 0 点执行一次）：
  └── 删除 N 天前的流水记录（N = baseConfig.licenseRecordDeleteTime，默认 60 天）
```

> `AbstractLicenseService.licenseCacheJobTimeMin = 10` 注释明确：`UpdateLicenseUsedJob` 和 `LicenseCache` 都是 10 分钟，调整时此处需对应调整。`getQueryStageTime()` 按 `LocalDateTime.now().minusMinutes(licenseCacheJobTimeMin)` 计算查询时间点。

### 2.7 定时 Job —— 推送 IAM（PushLicenseUsedJob）

**类**：`PushLicenseUsedJob`（旧 rum-controller 仓库 `manager/.../job/`）
**调度**：Quartz `OneHourJob`（每小时，注册到 `ExecuteInterval.ONE_HOUR`）
**分布式锁**：Redis key `PushLicenseUsedJob`，锁超时 200 秒。

#### 2.7.1 推送时机（关键）

```java
// PushLicenseUsedJob.java
pushIncreamentToCloud(LicenseType.US);      // US：每小时推送一次
if (LocalDateTime.now().getHour() == 1) {   // MAU/DAU：只在每天凌晨 1 点推送
    pushIncreamentToCloud(LicenseType.DAU);
    pushIncreamentToCloud(LicenseType.MAU);
}
```

**MAU 每天凌晨 1 点才推送一次**（非每小时）。

#### 2.7.2 getCurrIncrement() 逻辑（增量计算）

```java
// MauLicenseService.getCurrIncrement()

// 查询 7 天内待推送记录（status != 1）
List<LicenseEntity> usedList = licenseMapper.selectAllMauUsed(
    date7DaysAgo, today_0AM);

// 查询已推送成功记录（status == 1）
List<LicenseEntity> pushedList = licenseMapper.selectAllMauPushed(date7DaysAgo);

// 计算增量：
for (LicenseEntity license : usedList) {
    if (!pushedMap.containsKey(key)) {
        // 本月从未推送过 → 直接推送全量
        resList.add(license);
    } else if (license.currNum >= pushedMap.get(key).currNum) {
        // 已推过 → 推送增量（当前用量 - 上次推送量）
        license.setCurrNum(license.currNum - pushedMap.get(key).currNum);
        resList.add(license);
    } else {
        // 异常：当前用量 < 上次推送量（Redis 被删、key 过期等）
        // 本次跳过，不推送！打印警告日志
        log.info("MAU获取cloud推送量, 数据异常,本次取消推送,当前使用的:{},上次推送的:{}", ...);
    }
}
```

#### 2.7.3 推送 HTTP 请求

```
POST {global.address.web.url.inner}{global.private.rum.iam.push}
     默认路径：/api/iam/v3/cost/push

Header：  Authorization: {global.common.one.api.token}
Body（JSON）：
{
  "productId": 1,       // ConstantKeys.productId
  "monitorTime": ...,   // createTime
  "itemId": "mau",      // LicenseType.MAU.getType()
  "dataCenterId": ...,  // 多数据中心时附加
  "data": [
    {
      "userId": ...,
      "num": ...,        // 增量（当前 - 上次推送）
      "appId": ...,
      "envId": ...,
      "appName": ...,
      "resBundleId": ... // 资源包模式时附加
    }
  ]
}

重试次数：2 次
成功判断：resMap.get("msg") == "success"
成功后：  updateLicenseStatus → status=1（async_pushed）
失败后：  updateLicenseStatus → status=2（async_failed）
```

### 2.8 License 缓存（LicenseCache）

**类**：`LicenseCache`（旧 rum-controller 仓库 `cache-server/.../cache/license/LicenseCache.java`）
**刷新周期**：`ExecuteInterval.LATER_TEN_MINUTE`（延迟 10 分钟执行，即系统启动后 10 分钟才首次执行）

> 在 newonexm 中，RUM 相关缓存在 `com.bonree.one.controller.service.config.rum.cache` 包下（如 `AppCache`、`AppVersionCache` 等），由 `RumCacheTask`（`controller/controller/src/main/java/com/bonree/one/controller/task/RumCacheTask.java`）以 `@Scheduled(cron = "0 0/5 * * * ?")` 每 5 分钟刷新；License 缓存逻辑由 `RumCacheServiceImpl`（`controller/controller/.../service/config/rum/impl/RumCacheServiceImpl.java`）承载，通过 `getUserLicenseModel(userId)` 提供。

#### 2.8.1 从 IAM 拉取 License

```
POST {global.address.web.url.inner}{global.private.rum.iam.get}
     默认路径：/api/iam/v4/package/get

分页：pageSize=1000，最多查询 99 页
响应解析：
  - itemId = "mau" → licenseType = MAU
  - limit   → 月活上限
  - type    → quotaType（0=全局，1=按环境）
  - meteredItemType → 1=按创建人 2=按资源域 3=按应用（资源包模式）
  - envs   → 环境列表，含各环境的 limit/currNum/resBundles
```

#### 2.8.2 currNum 填充

```
从 Redis Hash (LICENSE:CURRENT_NUM) 读取各 App 的当前月活量（由 UpdateLicenseUsedJob 写入）
填充到 licenseModel.currNum（全局用量）
以及各 LicenseEnvModel.currEnvNum（按环境分配额）
```

#### 2.8.3 License 过期检查

```
配置项：global.private.rum.license.expire.time（默认值在代码中为 60 天，单位分钟）
如果 licenseModel.updateTime 距今超过 expireTime，从内存缓存中删除
```

### 2.9 数据库表结构（t_rum_license_record）

**表名**：`t_rum_license_record`
**建表脚本**：`script/one_framework_rum/INIT/mariadb/all/one_rum_table.sql`（及 dm/tdsql/oceanbase 对应脚本）

```sql
CREATE TABLE IF NOT EXISTS `t_rum_license_record` (
    `id`             bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键',
    `user_id`        bigint(20) DEFAULT NULL COMMENT '帐号',
    `app_id`         bigint(20) DEFAULT NULL COMMENT '应用id',
    `type`           int(11) DEFAULT NULL COMMENT '计费类型:1.日活  2.月活, 3.us',
    `stage`          date DEFAULT NULL COMMENT '计费阶段:日活和us存当天0点的时间,月活存当月第一天0点的时间.',
    `curr_num`       bigint(20) unsigned DEFAULT NULL COMMENT '当前使用量',
    `status`         int(10) unsigned DEFAULT NULL COMMENT '状态,0-未同步,1-已同步,2-同步失败',
    `res_bundle_id`  bigint(20) DEFAULT -1 COMMENT '资源包id 默认-1则非资源包消费',
    `create_time`    datetime DEFAULT NULL COMMENT '记录时间',
    `data_center_id` tinyint(4) DEFAULT 1 COMMENT '数据中心Id',
    PRIMARY KEY (`id`),
    KEY `t_rum_license_record_type_IDX` (`type`,`status`,`create_time`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8 COLLATE=utf8_bin;
```

| 字段 | 类型 | 说明 |
|------|------|------|
| id | bigint(20) | 主键，自增 |
| user_id | bigint(20) | 账号 ID |
| app_id | bigint(20) | 应用 ID |
| type | int(11) | 计费类型：1=DAU，2=MAU，3=US |
| stage | date | 计费阶段：MAU 为当月 1 日 0 点；DAU/US 为当天 0 点 |
| curr_num | bigint(20) unsigned | 当前使用量 |
| status | int(10) unsigned | 0=未同步（待推送），1=已同步（已推送），2=同步失败 |
| res_bundle_id | bigint(20) | 资源包 ID，默认 -1 表示非资源包消费 |
| create_time | datetime | 记录时间（`UpdateLicenseUsedJob` 写入时间）|
| data_center_id | tinyint(4) | 数据中心 ID，默认 1 |

**MAU 关键查询**：

```sql
-- getCurrIncrement 查询待推送（7 天内）
SELECT user_id, app_id, stage, MAX(curr_num), MAX(create_time), res_bundle_id
FROM t_rum_license_record
WHERE type=2 AND status!=1
  AND create_time > {7天前} AND create_time < {今天0点}
GROUP BY user_id, app_id, stage, res_bundle_id;

-- 查询已推送记录（取每个 user+app+stage+resBundle 的最新一条）
SELECT ... FROM (
    SELECT ..., ROW_NUMBER() OVER(PARTITION BY user_id, app_id, stage ORDER BY create_time DESC) AS rowNumLimit
    FROM t_rum_license_record
    WHERE type=2 AND status=1 AND create_time > {7天前}
) WHERE rowNumLimit=1;
```

### 2.10 全链路时序图

```
时间轴
  │
  │  设备首次本月访问（/config 或 /upload Web）
  ├─► configFilter()
  │     ├─ HyperLogLog PFADD "deviceId_appId" → redisQueue（异步）
  │     └─ Bitmap SETBIT offset → redisQueue（异步）
  │
  ├─► RedisPipelineThread（每 10ms 或 100 条批量）
  │     └─ executePipelined(PFADD, SETBIT, PEXPIRE)
  │
  │  每 10 分钟（UpdateLicenseUsedJob）
  ├─► PFCOUNT Redis HyperLogLog → currNum
  │     ├─ INSERT t_rum_license_record (type=2, status=0)
  │     └─ HSET LICENSE:CURRENT_NUM {appId} {currNum}
  │
  │  每 10 分钟（LicenseCache 刷新）
  ├─► HGETALL LICENSE:CURRENT_NUM → currNumMap
  │     └─ licenseModel.currNum = 汇总各 App 用量
  │
  │  凌晨 1:00（PushLicenseUsedJob）
  └─► getCurrIncrement()
        ├─ 查待推送记录 vs 已推送记录
        ├─ 计算增量
        └─ POST IAM /api/iam/v3/cost/push
             ├─ 成功 → UPDATE status=1
             └─ 失败 → UPDATE status=2（重试 2 次）
```

---

## 三、问题分析与优化建议

### 3.1 客户环境未推送 MAU 数据的原因分析

基于代码逻辑，以下原因均可导致 MAU 数据未能推送到 IAM：

#### 根因 A：PushLicenseUsedJob 时机约束问题（**最常见**）

**现象**：日志中不出现 `push cloud success` / `push cloud failed`，但 `UpdateLicenseUsedJob` 正常。

**原因**：
```java
if (LocalDateTime.now().getHour() == 1) {
    pushIncreamentToCloud(LicenseType.MAU);
}
```
MAU 推送**严格依赖凌晨 1 点**执行。如果在凌晨 1 点时：
- 服务器**时区配置有误**（例如使用 UTC 而非 UTC+8），凌晨 1 点时对应 UTC 09:00，错过推送窗口；
- 服务在凌晨 1 点**重启或 GC 暂停**，导致本次 OneHourJob 跳过；
- **分布式锁 `PushLicenseUsedJob` 上一次未正常释放**（代码中 finally 块对 `redisTemplate.delete(lock)` 被注释掉了！），锁 TTL 为 200 秒，极端情况下节点崩溃后 200 秒内无法推送。

**验证方式**：
```bash
# 查看最近推送日志
grep "PushLicenseUsedJob" rum-controller.log | grep -v INFO

# 检查是否只有 US 的推送，没有 MAU
grep "push cloud" rum-controller.log
```

#### 根因 B：分布式锁未释放导致永久阻塞（**代码缺陷**）

**现象**：首次执行 PushLicenseUsedJob 日志出现，之后再无该 Job 的任何日志。

**原因**：`PushLicenseUsedJob` 和 `UpdateLicenseUsedJob` 的 finally 块中 `redisTemplate.delete(lock)` 均被**注释掉**：

```java
// PushLicenseUsedJob.java
} finally {
//    redisTemplate.delete(lock);   ← 被注释！锁不会主动释放
}
```

锁的 TTL 为 200 秒。正常情况下，任务执行完 200s 后锁自动过期。但：
- 若 Redis 配置了**主从切换/集群模式**，设置的锁在从节点未同步时可能重复执行；
- 若任务执行时间 > 200s（网络超时等），会同时有两个进程执行，逻辑混乱。

该设计属于有意为之（允许锁自然过期，防止业务逻辑失败导致永久死锁），但在特殊情况下可能导致 Job 跳过。

#### 根因 C：getCurrIncrement() 数据异常被全部跳过

**现象**：日志出现 `MAU获取cloud推送量, 数据异常,本次取消推送`，且增量列表为空，不触发 HTTP 推送。

**原因**：当检测到 `currNum < pushedMap.get(key).currNum`，该记录被跳过。

**触发场景**：
1. **手动删除了 Redis 中的 HyperLogLog key**（运维清理 Redis 时误操作）；
2. **Redis 数据意外过期**（TTL 计算错误，或 Redis 内存策略为 `allkeys-lru` 淘汰了 MAU 的 key）；
3. **跨月初新 key，但数据库 pushed 记录仍保留上月数据**（概率小，因 stage 字段参与 group by）。

**验证方式**：
```sql
-- 查数据库：比较 used 和 pushed 的 curr_num
SELECT a.user_id, a.app_id, a.stage, a.curr_num AS used_num,
       b.curr_num AS pushed_num, a.curr_num - b.curr_num AS delta
FROM (
    SELECT user_id, app_id, stage, MAX(curr_num) curr_num
    FROM t_rum_license_record
    WHERE type=2 AND status!=1 AND create_time > DATE_SUB(NOW(),INTERVAL 7 DAY)
    GROUP BY user_id, app_id, stage
) a
LEFT JOIN (
    SELECT user_id, app_id, stage, curr_num
    FROM t_rum_license_record
    WHERE type=2 AND status=1 AND create_time > DATE_SUB(NOW(),INTERVAL 7 DAY)
) b ON a.user_id=b.user_id AND a.app_id=b.app_id AND a.stage=b.stage
WHERE a.curr_num < IFNULL(b.curr_num, 0);
```

#### 根因 D：LicenseCache 初始化失败，licenseModel 为空

**现象**：接入层日志出现 `USER_ABNORMAL_OR_NOT_AVAILABLE_PACKAGE`（ResponseCode），或 `licenseCache result: null`。

**原因**：`LicenseCache` 在 `LATER_TEN_MINUTE`（启动后 10 分钟）才初始化，若 IAM 接口：
1. `global.address.web.url.inner` **配置为空**（私有化部署中常见，不走云端 IAM）；
2. IAM 接口**返回非 success** 或网络不通；
3. **Token 过期**或配置错误。

则 `licenseCache` 为空，`checkLicense()` 返回 `USER_ABNORMAL_OR_NOT_AVAILABLE_PACKAGE`，数据无法接入（更无法计费），`t_rum_license_record` 无写入，推送自然为空。

**验证方式**：
```bash
grep "licenseCache" rum-controller.log | grep -i "warn\|error\|fail"
grep "queryAllLicense" rum-controller.log
```

#### 根因 E：UpdateLicenseUsedJob 未写入数据库记录

**现象**：`t_rum_license_record` 中 type=2 的记录数量为 0，或 curr_num 全部为 0。

**原因**：
1. **Redis HyperLogLog 为空**：没有设备访问（无实际流量），`PFCOUNT=0`，跳过写入；
2. **Redis 连接异常**：`getCurrUpdateNum()` 读取 PFCOUNT 失败，抛异常，Job 整体失败；
3. **`redisHashNum` 配置变更**：历史数据 key 的分片号与当前配置不一致，读取到错误 key。

#### 根因 F：HTTP 推送持续失败（网络/接口问题）

**现象**：日志出现 `push cloud failed`，且数据库记录 status=2（async_failed）。

**原因**：
1. 私有化环境 IAM 接口 URL 配置错误；
2. 网络防火墙阻止 controller 到 IAM 的 HTTP 请求；
3. IAM 服务异常或接口升级（接口路径变更但 Nacos 配置未更新）。

#### 根因 G：getCurrIncrement SQL 查询窗口问题

`selectAllMauUsed` 的时间范围是 **`create_time > 7天前 AND create_time < 今天0点`**。

如果 `UpdateLicenseUsedJob` 在 **今天 0 点之后、下次推送（凌晨 1 点）之前** 写入的记录，`create_time` < 今天 0 点，满足条件；但当天 0:00-1:00 之间新写入的记录，`create_time` > 今天 0 点，**不会被本次 1 点推送查到**，会留到次日 1 点推送（这是预期行为，但如果系统时间有漂移，可能导致月末数据滞后一天）。

### 3.2 排查步骤与验证方法

#### Step 1：确认日志时区和凌晨 1 点的执行情况

```bash
# 查看 PushLicenseUsedJob 最近执行日志
grep "PushLicenseUsedJob" /data/logs/rum-controller.log

# 查看是否有 MAU 推送动作（成功或失败）
grep "push cloud" /data/logs/rum-controller.log | grep -i mau
```

#### Step 2：检查数据库 t_rum_license_record

```sql
-- 近 7 天 MAU 记录统计（按状态分组）
SELECT DATE(create_time), status, COUNT(*), SUM(curr_num)
FROM t_rum_license_record
WHERE type=2 AND create_time > DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY DATE(create_time), status;

-- 0=待推送、1=已推送、2=推送失败
```

#### Step 3：检查 LicenseCache 是否正常加载

```bash
# 调用 ApiController 查看缓存内容（内网调用）
curl -X GET http://localhost:9999/api/license/all
# 或直接查看启动日志
grep "licenseCache" rum-controller.log | grep "load data size"
```

#### Step 4：检查 Redis 数据

```bash
# 查看当月 MAU HyperLogLog（替换实际的 userId/appId）
redis-cli PFCOUNT "LICENSE:MAU_PF_10001_2001_202606_0"

# 查看当前用量 Hash
redis-cli HGETALL "LICENSE:CURRENT_NUM"

# 检查 key 是否存在及 TTL
redis-cli TTL "LICENSE:MAU_PF_10001_2001_202606_0"
```

#### Step 5：验证 IAM 接口连通性

```bash
# 手动调用 IAM 推送接口（替换实际配置值）
curl -X POST http://{platformUrl}/api/iam/v3/cost/push \
  -H "Authorization: {cloudToken}" \
  -H "Content-Type: application/json" \
  -d '{"productId":1,"itemId":"mau","monitorTime":1718500000000,"data":[]}'
```

#### Step 6：检查 Nacos 关键配置

```
global.address.web.url.inner  → 不能为空，必须是 IAM 服务的内网地址
global.common.one.api.token   → 需要是有效 Token
global.private.rum.iam.push   → 默认 /api/iam/v3/cost/push
global.private.rum.iam.get    → 默认 /api/iam/v4/package/get
```

#### Step 7：确认服务器时区

```bash
# 检查 JVM 时区
java -XshowSettings:all -version 2>&1 | grep time
# 或在 rum-controller.log 中查看时间格式，确认是否为本地时区
date
```

### 3.3 优化建议

1. **推送时机解耦**：将 MAU 推送从"凌晨 1 点严格窗口"改为"每天首个 OneHourJob + 补偿机制"，避免时区/重启导致整月漏推。可在 `PushLicenseUsedJob` 中增加"距上次成功推送超过 24 小时则触发"的判断。

2. **分布式锁主动释放**：恢复 `finally` 块中的 `redisTemplate.delete(lock)`，或改用 Redisson 的 `tryLock(waitTime, leaseTime, unit)` 带 watchdog 续期，避免锁注释导致的 200s 阻塞窗口。

3. **数据异常容错**：`getCurrIncrement()` 中 `currNum < pushedNum` 时，除跳过外应增加告警上报和自动修复（如重新从 HyperLogLog 全量推送一次），避免整月数据卡住。

4. **TTL 设置可靠性**：`ttlCache` 是内存 Map，进程重启后丢失，导致重启后首次写入会重复设置 TTL（影响不大）。但若 Redis 内存淘汰策略为 `allkeys-lru`，MAU key 可能被误淘汰，建议将 MAU key 集中到独立 Redis 实例或设置 `volatile-lru` 策略。

5. **US 计费简化确认**：当前 newonexm `UsmLicenseService.configFilter()` 直接返回 `true`，若 US 仍需按会话分段计费，应在 controller 侧补回 `uploadFilter()` 逻辑或确认上层已承载。

6. **redisQueue 容量监控**：`ArrayBlockingQueue` 容量 5000，高并发时 `put()` 会阻塞 `configFilter()`。建议增加队列水位监控告警，或改用无界队列 + 限流降级。

7. **跨模块类对齐**：`UpdateLicenseUsedJob`、`PushLicenseUsedJob`、`LicenseCache`、`LicenseMapper`、`LicenseEntity` 在 newonexm `controller/controller` 模块中未直接找到，建议确认这些定时任务和持久层是否已迁移到其他模块或服务，避免归档文档与实际部署脱节。

---

## 附：关键类文件路径索引

### newonexm 仓库中存在的类

| 关键类 | newonexm 路径 |
|--------|--------------|
| `MauLicenseService` | `controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/license/MauLicenseService.java` |
| `DauLicenseService` | `controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/license/DauLicenseService.java` |
| `UsmLicenseService` | `controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/license/UsmLicenseService.java` |
| `AbstractLicenseService` | `controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/license/AbstractLicenseService.java` |
| `RedisPipelineThread` | `controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/license/RedisPipelineThread.java` |
| `RedisConsumer` | `controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/license/RedisConsumer.java` |
| `RumLicenseListener` | `controller/controller/src/main/java/com/bonree/one/controller/service/common/init/RumLicenseListener.java` |
| `RumConfigServiceImpl`（含 `checkLicense`） | `controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/impl/RumConfigServiceImpl.java` |
| `RumCacheServiceImpl`（License 缓存提供） | `controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/impl/RumCacheServiceImpl.java` |
| `RumCacheTask` | `controller/controller/src/main/java/com/bonree/one/controller/task/RumCacheTask.java` |
| `LicenseModel` | `controller/controller/src/main/java/com/bonree/one/controller/domain/model/rum/LicenseModel.java` |
| `LicenseEnvModel` | `controller/controller/src/main/java/com/bonree/one/controller/domain/model/rum/LicenseEnvModel.java` |
| `LicenseInfo` | `controller/controller/src/main/java/com/bonree/one/controller/service/config/rum/impl/LicenseInfo.java` |
| `LicenseType` | `controller/controller/src/main/java/com/bonree/one/controller/common/enums/LicenseType.java` |
| `OSPlatformTypeEnum` | `controller/controller/src/main/java/com/bonree/one/controller/common/enums/OSPlatformTypeEnum.java` |
| `t_rum_license_record` 建表脚本 | `script/one_framework_rum/INIT/mariadb/all/one_rum_table.sql`（及 dm/tdsql/oceanbase 对应脚本） |

### 历史 rum-controller 仓库组件（newonexm 中未直接对应）

| 关键类 | 历史路径 | 说明 |
|--------|----------|------|
| `LicenseCache` | `cache-server/.../cache/license/LicenseCache.java` | 许可证缓存，每 10 分钟从 IAM 拉取；newonexm 中由 `RumCacheServiceImpl` 承载 |
| `UpdateLicenseUsedJob` | `manager/.../job/UpdateLicenseUsedJob.java` | 用量落库定时任务（每 10 分钟） |
| `PushLicenseUsedJob` | `manager/.../job/PushLicenseUsedJob.java` | 用量推送定时任务（每小时，MAU/DAU 凌晨 1 点） |
| `LicenseMapper` | `cache-server/.../mapper/LicenseMapper.java` | `t_rum_license_record` 持久化 Mapper |
| `LicenseEntity` | `cache-server/.../entity/LicenseEntity.java` | `t_rum_license_record` 实体 |
| `OneHourJob` | `cache-server/.../cache/jobs/OneHourJob.java` | Quartz 每小时调度类 |
| `TenMinuteJob` | `cache-server/.../cache/jobs/TenMinuteJob.java` | Quartz 每 10 分钟调度类 |
| `Redis4LicenseUtil` | `cache-server/.../redis/Redis4LicenseUtil.java` | Redis 操作工具类 |
| `UploadController.checkLicense` | `network/.../controller/UploadController.java` | upload 请求 License 校验入口 |
| `ConfigController.checkLicense` | `network/.../controller/ConfigController.java` | config 请求 License 校验入口（newonexm 中由 `RumConfigServiceImpl.checkLicense` 替代） |

---

*文档整理时间：2026-07-11*
*基于 newonexm 仓库 `controller/controller` 模块当前主干源码校验*
