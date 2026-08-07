---
title: 接口文档：查询会话列表 sessionList
---

## 1. 接口概览

| 属性 | 说明 |
|------|------|
| **URL** | `/rest/rum/session/search/sessionList` |
| **备用URL** | `/api/rum/session/search/sessionList` |
| **请求方式** | `POST` |
| **Content-Type** | `application/json` |
| **接口描述** | 查询会话列表，用于检索中心和用户会话等场景。根据筛选条件查询会话数据，支持分页、排序、异常/可容忍会话过滤，并返回会话的统计信息（总会话数、异常会话数、可容忍会话数）。 |
| **所属Controller** | `SessionSearchController` |
| **Service实现** | `RumCkSessionService.querySessionList()` |
| **数据源** | ClickHouse（`one_rum_datasource_snapshot.t_rum_session_view`） |

---

## 2. 权限校验

### 2.1 功能权限（@OperatePermissionCheck）

需要以下任一功能权限：

| 权限标识 | 说明 |
|---------|------|
| `one:resource:rumReadResource` | RUM 资源只读权限 |
| `one:resource:rumManageResource` | RUM 资源读写权限 |

### 2.2 IAM 菜单权限（@IamCheckPermission）

以下两个菜单权限为 **OR（满足其一即可）** 关系：

| 权限标识 | 说明 |
|---------|------|
| `one:digital:session` | 用户会话菜单权限 |
| `one:observe:retrieval` | 检索中心菜单权限 |

> **设计说明**：v4.0.0.0 之前默认是 AND 关系，导致仅开通用户会话的用户也必须具备检索中心权限才能访问，与公用接口语义不符，因此改为 OR。

---

## 3. 请求参数

请求体为 JSON，对应 Java 类 `MemberIdCondition`（继承 `RumBaseCondition`）。

### 3.1 MemberIdCondition 自有字段

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `deviceId` | String | 否 | null | 设备ID，用于按设备筛选 |
| `memberId` | String | 否 | null | 会员/用户ID |
| `sessionId` | String | 否 | null | 会话ID，精确查询某个会话 |
| `appId` | Long | 否 | null | 应用ID（MemberIdCondition级别，与基类的 appId 独立） |
| `appIds` | List\<Long\> | 否 | null | 应用ID列表，支持多应用查询 |
| `hasSessionReplay` | Boolean | 否 | null | 是否过滤有会话回放的会话。为 `true` 时会移除 filters 中的 `isExistSessionReplay` 过滤条件 |

> **注意**：`limit` 和 `envId` 字段虽然在 `MemberIdCondition` 中存在，但在 Controller 层会被强制覆盖，前端不需要传递。

### 3.2 RumBaseCondition 基类字段

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `startTime` | Long | 否 | 0 | 开始时间戳（毫秒），0 表示不限制 |
| `endTime` | Long | 否 | 0 | 结束时间戳（毫秒），0 表示不限制 |
| `appId` | Long | 否 | -1 | 应用ID，-1 表示不限制 |
| `appIds` | List\<Long\> | 否 | [] | 应用ID列表 |
| `pageNo` | Integer | 否 | 1 | 页码，从 1 开始 |
| `pageSize` | Integer | 否 | 10 | 每页条数 |
| `sortField` | String | 否 | null | 排序字段（如 `configTime`） |
| `sortOrder` | String | 否 | "desc" | 排序方向：`desc`（降序）/ `asc`（升序） |
| `filters` | List\<FilterOption\> | 否 | [] | 过滤条件列表（核心筛选器） |
| `otherFilters` | List\<FilterOption\> | 否 | [] | 其他过滤条件（如会话状态过滤） |
| `parentFilters` | List\<FilterOption\> | 否 | [] | 父子页面传参 |
| `queryJson` | Map | 否 | {} | 其他过滤对象 JSON |
| `isDownload` | Boolean | 否 | null | 是否为下载请求 |
| `language` | String | 否 | "zh_CN" | 当前语言 |
| `queryKey` | String | 否 | null | 过滤器所属查询范围 |
| `downLoadHeaders` | List\<Map\<String,String\>\> | 否 | null | 下载时的列名配置 |
| `ln` | Long | 否 | null | 前端带回的 limit 数量 |
| `lnFlag` | String | 否 | null | 前端带回的 limit 标识控制 |
| `keyEntityFlag` | Integer | 否 | null | 传 1 查询所有关键实体数据 |

### 3.3 FilterOption 过滤条件结构

`filters` 和 `otherFilters` 中每个元素的结构：

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `keyword` | String | 是 | - | 查询字段名（如 `deviceId`、`appId`、`sessionStatus` 等） |
| `operator` | FilterTypeEnum | 否 | `in` | 操作符类型 |
| `value` | Object | 是 | - | 查询值，类型根据 operator 决定 |

**支持的操作符（FilterTypeEnum）**：

| 操作符 | 说明 | value 类型 |
|--------|------|-----------|
| `equal` | 等于 | 单值 |
| `notEqual` | 不等于 | 单值 |
| `greater` | 大于 | 单值 |
| `greaterEqual` | 大于等于 | 单值 |
| `less` | 小于 | 单值 |
| `lessEqual` | 小于等于 | 单值 |
| `between` | 介于 | [min, max] 数组 |
| `notBetween` | 不介于 | [min, max] 数组 |
| `empty` | 为空 | 不需要 |
| `notEmpty` | 不为空 | 不需要 |
| `contain` | 包含 | String |
| `start` | 起始于 | String |
| `end` | 结束于 | String |
| `in` / `any` / `all` | 包含（IN） | List |

### 3.4 请求示例

```json
{
  "startTime": 1711584000000,
  "endTime": 1711670400000,
  "appId": 12345,
  "pageNo": 1,
  "pageSize": 20,
  "sortField": "configTime",
  "sortOrder": "desc",
  "filters": [
    {
      "keyword": "appVersion",
      "operator": "equal",
      "value": "1.0.0"
    }
  ],
  "otherFilters": [
    {
      "keyword": "sessionStatus",
      "operator": "equal",
      "value": "-1"
    }
  ],
  "deviceId": "abc123",
  "hasSessionReplay": false
}
```

---

## 4. Controller 层处理逻辑

Controller 方法 `SessionSearchController.sessionList()` 执行以下预处理：

```
1. condition.setLimit(Boolean.TRUE)
   → 强制设置 limit=true，走检索中心的 2000 条限制逻辑
2. condition.setAccountId(rumCkSessionSearchService.getAccountId())
   → 从当前登录用户获取主账号ID
3. envId = ResourceUtil.getEnvId(userProvider)
   → 从用户上下文获取环境ID
4. condition.setEnvId(envId)
   → 设置环境ID
5. 调用 rumCkSessionService.querySessionList(condition, envId, locale)
```

> Controller 类级别映射为 `@RequestMapping({"/api/rum/session/search", "/rest/rum/session/search"})`，同时支持 `/api/rum/session/search/sessionList` 与 `/rest/rum/session/search/sessionList` 两条路径。

---

## 5. Service 层核心处理逻辑

### 5.1 总体流程

```
querySessionList(condition, envId, languageType)
│
├─ 1. 初始化响应模型（设置 expireTime、queryCkSessionLimit）
├─ 2. 无筛选条件时优化 startTime
├─ 3. 组装查询条件 → ConcatQueryEntrySessionList()
├─ 4. 分支判断：limit=true → 走检索中心逻辑
│   ├─ 4a. 查询全部 sessionId 列表
│   ├─ 4b. 获取会话满意度配置
│   ├─ 4c. 查询含异常标记的 sessionId 列表
│   ├─ 4d. 统计异常/可容忍会话数
│   ├─ 4e. 根据会话状态过滤确定最终 sessionId 列表
│   ├─ 4f. 内存分页
│   ├─ 4g. 查询会话详情列表 → getSessionListModel()
│   └─ 4h. 设置统计数据
├─ 5. 设置 expireTime 和 queryCkSessionLimit
└─ 6. 返回 RestResponse.success(resModel)
```

### 5.2 步骤详解

#### 5.2.1 初始化响应模型

```java
UserSessionModel resModel = new UserSessionModel();
resModel.setExpireTime(rumConfig.expireTime);           // 会话列表查询最大天数
resModel.setQueryCkSessionLimit(rumConfig.queryCkSessionLimit); // 会话列表查询最大条数
```

#### 5.2.2 无筛选条件时的 startTime 优化

**条件**：`condition.getFilters()` 为空时触发。

**目的**：当没有筛选条件时，全量查询可能非常慢。通过查询前 N（`sessionIdStartTimeLimit`）个会话的最早开始时间来收窄时间范围。

**实现方法** `querySessionStartTimeOfLimit(condition)`：
- 构建过滤条件：deviceId、sessionId、appId、appIds、monitor_time 范围
- 使用 ClickHouse 窗口函数 `sum(...) OVER (ROWS ...)` 累积统计会话数
- 查询表：`t_rum_session_minute_distributed`（集群模式）或 `t_rum_session_minute_local`（POC 模式）
- 找到累积会话数超过 `sessionLimit` 的最早小时时间点
- 将该时间点设为 `condition.startTime`

#### 5.2.3 组装查询条件 — ConcatQueryEntrySessionList()

该方法将 `MemberIdCondition` 转换为 `MetricQueryCondition`：

**过滤条件组装**：
1. 将 `condition.filters` 全部加入 filterOptions
2. 如果 `deviceId` 不为空，添加 `deviceId = ?`
3. 如果 `sessionId` 不为空，添加 `sessionId = ?`
4. 如果 `appId` 不为空，添加 `appId = ?`
5. 如果 `appIds` 不为空，添加 `appId IN (?)`
6. 固定添加 `monitor_time >= 当前时间 - sessionDaysAgo天`（数据保留时间限制）
7. 如果 `startTime != 0`，添加 `monitor_time >= startTime`
8. 如果 `endTime != 0`，添加 `monitor_time < endTime`

**特殊 filter 处理**：
- `appAliasVersion`（应用版本别名）→ 转换 keyword 为 SQL 用的 `appVersion` 字段
- `isExistSessionReplay`（会话回放）→ 操作符改为 `greaterEqual`
- 如果 `hasSessionReplay=true`，移除 filters 中的 `isExistSessionReplay` 条件

**会话状态过滤**（从 `otherFilters` 读取）：
- `sessionStatus = "2"` 或 `"-1"` → 标记 `isError = true`（异常会话）
- `sessionStatus = "-2"` → 标记 `isAcceptable = true`（可容忍会话）

**MetricQueryCondition 设置**：
- `offset = (pageNo - 1) * pageSize`
- `limit = pageSize`
- `hasLimit = true`
- `hasError / hasAcceptable` 设置
- `sessionLimit = rumConfig.queryCkSessionLimit`（最大查询条数）
- HAVING 条件：`sum(eventNum) > 0`（排除无事件的会话）
- 通过 `rumSqlFilterFactory.getSqlFilter()` 最终构建 SQL 过滤条件

#### 5.2.4 查询全部 sessionId 列表（limit=true 分支）

**SQL 查询** `querySessionIdList`：

```sql
SELECT "sessionId", min(minMonitorTime) AS configTime
FROM one_rum_datasource_snapshot.t_rum_session_view
WHERE <条件>
GROUP BY sessionId, deviceId
HAVING sum(eventNum) > 0
ORDER BY configTime DESC
LIMIT ${sessionLimit}   -- 默认 500 或配置值
```

如果返回为空，直接返回空结果。

#### 5.2.5 获取会话满意度配置

通过 `SessionSatisfactionUtils.getSessionSatisfactionSetting(accountId)` 获取：

| 配置项 | 说明 |
|--------|------|
| `exceptionLimit` | 异常事件比例阈值（百分比），超过则会话为异常 |
| `satisfiedLimit` | 满意事件比例阈值（百分比），超过则会话为满意 |
| `isExistCrash` | 是否包含崩溃作为异常条件（0/1） |
| `isExistException` | 是否包含自定义异常作为异常条件（0/1） |
| `isExistPageLoadFail` | 是否包含页面加载失败作为异常条件（0/1） |
| `isExistOperationFail` | 是否包含操作失败作为异常条件（0/1） |

#### 5.2.6 查询含异常标记的 sessionId 列表

**SQL 查询** `querySessionIdErrorList`：

将第一步查到的 sessionId 列表作为 IN 条件，同时扩展时间范围（±`sessionQueryTimeExpansion` 分钟），查询每个会话的：
- 异常/满意/可容忍事件数
- crashFlag、anrFlag、selfCrashFlag、lagFlag、actionErrorFlag、h5ErrorFlag
- 基于阈值计算的 exceptionEventNum、acceptableEventNum

#### 5.2.7 异常/可容忍会话统计

遍历 `querySessionIdErrorList` 的结果，按以下优先级判定每个会话的状态：

```
判定优先级（从高到低）：
1. isExistCrash=1 且 (crashFlag > 0 或 anrFlag > 0)    → 异常会话
2. isExistException=1 且 selfCrashFlag > 0              → 异常会话
3. isExistPageLoadFail=1 且 h5ErrorFlag > 0             → 异常会话
4. isExistOperationFail=1 且 actionErrorFlag > 0        → 异常会话
5. exceptionEventNum > 0 (通过阈值计算)                  → 异常会话
6. acceptableEventNum > 0 (通过阈值计算)                  → 可容忍会话
7. 以上均不满足                                           → 正常/满意会话
```

#### 5.2.8 确定最终 sessionId 列表

根据 `hasError` / `hasAcceptable` 标记决定返回哪些会话：

| 条件 | 使用的 sessionId 列表 |
|------|----------------------|
| `hasError = true` | 仅异常会话的 sessionId |
| `hasAcceptable = true` | 仅可容忍会话的 sessionId |
| 其他 | 全部 sessionId（来自 querySessionIdList） |

#### 5.2.9 内存分页

```java
// 如果总数 > pageSize，则在内存中做分页
pageList = sessionIds.subList(
    (pageNo - 1) * pageSize,
    min(pageNo * pageSize, sessionIds.size())
);
```

将分页后的 sessionId 列表追加到查询条件中（`sessionId IN (pageList)`）。

#### 5.2.10 查询会话详情列表 — getSessionListModel()

**SQL 查询** `querySessionList`：

```sql
SELECT
  sessionId, configTime, isExistSessionReplay, monitorTime,
  exceptionSessionForStatus, satisfiedSessionForStatus,
  acceptableSessionForStatus, sessionSatisfactionEventTotal,
  sessionDuration, eventNum, appId, appVersion, sdkVersion,
  cityCode, netServiceId, accessModelId, dIp, userInfo,
  memberId, fullBrandModel, osName, deviceId, channel,
  dataCenterId, crashFlag, anrFlag, selfCrashFlag, lagFlag,
  actionErrorFlag, h5ErrorFlag, groupId
FROM one_rum_datasource_snapshot.t_rum_session_view
WHERE <条件（含 sessionId IN 分页列表）>
GROUP BY sessionId, appId, appVersion, fullBrandModel,
         clientOsName, deviceId, sdkVersion, channel, dataCenterId
HAVING sum(eventNum) > 0
ORDER BY configTime DESC
LIMIT ${sessionLimit}
```

#### 5.2.11 数据装饰（getSessionListModel 内部处理）

对每条 `SessionModel` 进行数据填充和装饰：

1. **城市信息**：通过 `cmdbSdkUtils.getCityCache(cityCode, languageType)` 获取城市名称、省份、国家
2. **数据中心**：通过 `cmdbSdkUtils.getDictValue()` 获取数据中心名称
3. **运营商**：通过 `cmdbSdkUtils.getNetServiceCache()` 获取运营商名称
4. **接入方式**：通过 `cmdbSdkUtils.getAccessCache()` 获取接入方式名称（默认 WIFI）
5. **会话满意度状态**：
   - 优先判断 crashFlag/anrFlag/selfCrashFlag/h5ErrorFlag/actionErrorFlag → `sessionStatus = -1`（异常）
   - 否则按阈值计算：`calculatedSessionSatisfaction(eventTotal, errorNum, satisfiedNum, setting)`
     - 异常比例 ≥ exceptionLimit → `-1`（异常）
     - 满意比例 ≥ satisfiedLimit → `-3`（满意）
     - 其他 → `-2`（可容忍）
6. **应用信息**：通过 AppCache 获取应用名称、平台类型
7. **memberId 处理**：如果 memberId 为空，使用 deviceId
8. **会话时长**：从毫秒转换为秒 (`sessionDuration / 1000`)
9. **在线状态**：`当前时间 - monitorTime < 60000ms` → 在线
10. **清空 cityCode**：前端不展示国家
11. **用户别名**：通过 `rumAliasService.getAlias()` 查询用户别名
12. **用户分组**：通过 `rumQueryServiceUserGroupMapper.queryUserGroupByInstanceId()` 查询用户分组名称

---

## 6. 响应结果

### 6.1 响应结构

外层包装为 `RestResponse<UserSessionModel>`：

```json
{
  "code": "200",
  "message": "success",
  "data": { /* UserSessionModel */ }
}
```

### 6.2 UserSessionModel 字段（继承 BasePageRsp）

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `results` | List\<SessionModel\> | 会话列表（分页后的数据），继承自 BasePageRsp |
| `sessionNum` | Long | 总会话数（limit 分支下为 `querySessionIdList` 返回列表长度，上限为 `queryCkSessionLimit`，并非全库会话总数） |
| `exceptionSession` | Long | 异常会话数 |
| `acceptableSession` | Long | 可容忍会话数 |
| `expireTime` | Integer | 用户会话列表查询最大天数（配置值） |
| `queryCkSessionLimit` | Integer | 用户会话列表查询最大条数（配置值） |

### 6.3 SessionModel（results 列表中每条数据）

| 字段名 | 类型 | 说明 |
|--------|------|------|
| `sessionId` | String | 会话ID |
| `configTime` | Long | 会话开始时间（毫秒时间戳） |
| `sessionDuration` | Double | 会话时长（秒） |
| `sessionStatus` | Integer | 会话满意度状态：-1 异常，-2 可容忍，-3 满意 |
| `monitorTime` | Long | 最新事件时间（毫秒时间戳） |
| `memberId` | String | 用户/会员ID（为空时用 deviceId 替代） |
| `memberName` | String | 用户别名（有别名时显示别名，否则显示 memberId） |
| `deviceId` | String | 设备ID |
| `eventNum` | Integer | 事件总数 |
| `appId` | Long | 应用ID |
| `appName` | String | 应用名称（优先使用别名） |
| `appVersion` | String | 应用版本 |
| `platform` | Integer | 平台类型：1-Android, 2-iOS, 3-Web, 4-Windows, 5-WechatMiniProgram, 6-Harmony |
| `cityName` | String | 城市名称 |
| `district` | String | 省/地区 |
| `country` | String | 国家 |
| `fullBrandModel` | String | 完整品牌型号 |
| `osName` | String | 操作系统名称 |
| `dNetserviceId` | Integer | 运营商ID |
| `dNetserviceName` | String | 运营商名称 |
| `accessModelId` | Integer | 接入方式ID |
| `accessModelName` | String | 接入方式名称（默认 "WIFI"） |
| `dIp` | String | 客户端IP |
| `channel` | String | 渠道 |
| `isOnLine` | Boolean | 是否在线（最近60秒内有事件） |
| `isExistSessionReplay` | Integer | 是否有会话回放（0 否，1 是） |
| `sdkVersion` | String | SDK 版本 |
| `crashFlag` | Integer | 崩溃标记 |
| `anrFlag` | Integer | ANR 标记 |
| `selfCrashFlag` | Integer | 自定义异常标记 |
| `lagFlag` | Integer | 卡顿标记 |
| `actionErrorFlag` | Integer | 操作异常标记 |
| `h5ErrorFlag` | Integer | H5 错误标记 |
| `groupId` | Long | 用户分组ID |
| `userGroupName` | String | 用户分组名称 |
| `dataCenterId` | Long | 数据中心ID |
| `dataCenter` | String | 数据中心名称 |

### 6.4 响应示例

```json
{
  "code": "200",
  "message": "success",
  "data": {
    "results": [
      {
        "sessionId": "sess_abc123",
        "configTime": 1711584123000,
        "sessionDuration": 125.5,
        "sessionStatus": -3,
        "monitorTime": 1711584248500,
        "memberId": "user_001",
        "memberName": "张三",
        "deviceId": "device_xyz",
        "eventNum": 42,
        "appId": 12345,
        "appName": "测试应用",
        "appVersion": "1.0.0",
        "platform": 1,
        "cityName": "北京",
        "district": "北京市",
        "country": "中国",
        "fullBrandModel": "Huawei Mate 60 Pro",
        "osName": "Android 14",
        "dNetserviceId": 1,
        "dNetserviceName": "中国移动",
        "accessModelId": 1,
        "accessModelName": "WIFI",
        "dIp": "192.168.1.100",
        "channel": "official",
        "isOnLine": false,
        "isExistSessionReplay": 1,
        "sdkVersion": "3.0.0",
        "crashFlag": 0,
        "anrFlag": 0,
        "selfCrashFlag": 0,
        "lagFlag": 0,
        "actionErrorFlag": 0,
        "h5ErrorFlag": 0,
        "groupId": null,
        "userGroupName": null,
        "dataCenterId": 1,
        "dataCenter": "华北数据中心"
      }
    ],
    "sessionNum": 156,
    "exceptionSession": 12,
    "acceptableSession": 8,
    "expireTime": 14,
    "queryCkSessionLimit": 2000
  }
}
```

---

## 7. 异常处理

| 异常场景 | 处理方式 |
|---------|---------|
| 数据库查询异常（`DataAccessException`） | 抛出 `RestException(QUERY_SQL_ERROR)` |
| 用户别名查询失败 | 仅记录日志，不影响主流程，别名保持为 memberId |
| 用户分组查询失败 | 仅记录日志，不影响主流程 |
| querySessionIdList 返回空 | 直接返回空 `resModel`（含 expireTime 和 queryCkSessionLimit） |
| 其他未知异常 | 记录错误日志，向上抛出 |

---

## 8. 关键配置项

以下配置来自 `RUMConfig`（`rumConfig`）：

| 配置项 | 说明 |
|--------|------|
| `expireTime` | 会话列表查询最大天数 |
| `queryCkSessionLimit` | 会话列表最大查询条数（如 2000） |
| `sessionDaysAgo` | ClickHouse 会话数据保留天数（如 14天） |
| `sessionIdStartTimeLimit` | 无筛选条件时的会话数阈值（如 1000） |
| `sessionQueryTimeExpansion` | 查询时间范围扩展分钟数 |
| `deployType` | 部署类型：1-集群，2-POC |

---

## 9. 数据查询 SQL 汇总

### 9.1 querySessionIdStartTimeOfLimit（优化 startTime）

```sql
-- 使用窗口函数累积统计会话数，找到超过阈值的最早时间点
SELECT con, hour_time AS startTime
FROM (
  SELECT sum(numbers) OVER (ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS con, hour_time
  FROM (
    SELECT uniqHLL12(session_id) AS numbers,
           toUnixTimestamp(toStartOfHour(monitor_time)) * 1000 AS hour_time
    FROM one_rum_datasource_snapshot.t_rum_session_minute_distributed
    WHERE <条件>
    GROUP BY hour_time
    ORDER BY hour_time DESC
  )
)
WHERE con > ${sessionLimit}
ORDER BY hour_time DESC
LIMIT 1
```

### 9.2 querySessionIdList（获取全部 sessionId）

```sql
SELECT "sessionId", min(minMonitorTime/configTime) AS configTime
FROM one_rum_datasource_snapshot.t_rum_session_view
WHERE <过滤条件>
GROUP BY sessionId, deviceId
HAVING sum(eventNum) > 0
ORDER BY configTime DESC
LIMIT ${sessionLimit}
```

### 9.3 querySessionIdErrorList（获取含异常标记的 sessionId）

```sql
SELECT sessionId, exceptionSessionForStatus, satisfiedSessionForStatus,
       acceptableSessionForStatus, eventNum, crashFlag, anrFlag,
       selfCrashFlag, lagFlag, actionErrorFlag, h5ErrorFlag, configTime,
       exceptionEventNum, acceptableEventNum
FROM one_rum_datasource_snapshot.t_rum_session_view
WHERE <过滤条件 + sessionId IN (上一步结果)>
GROUP BY sessionId, deviceId
HAVING sum(eventNum) > 0
ORDER BY configTime DESC
LIMIT ${sessionLimit}
```

### 9.4 querySessionList（最终会话详情查询）

```sql
SELECT sessionId, configTime, isExistSessionReplay, monitorTime,
       exceptionSessionForStatus, satisfiedSessionForStatus,
       acceptableSessionForStatus, sessionSatisfactionEventTotal,
       sessionDuration, eventNum, appId, appVersion, sdkVersion,
       cityCode, netServiceId, accessModelId, dIp, userInfo,
       memberId, fullBrandModel, osName, deviceId, channel,
       dataCenterId, crashFlag, anrFlag, selfCrashFlag, lagFlag,
       actionErrorFlag, h5ErrorFlag, groupId
FROM one_rum_datasource_snapshot.t_rum_session_view
WHERE <过滤条件 + sessionId IN (分页后列表)>
GROUP BY sessionId, appId, appVersion, fullBrandModel,
         clientOsName, deviceId, sdkVersion, channel, dataCenterId
HAVING sum(eventNum) > 0
ORDER BY configTime DESC
LIMIT ${sessionLimit}
```

---

## 10. 核心流程图

```
┌─────────────────────────────────────────────────────────────┐
│                    POST /sessionList                         │
│                 @RequestBody MemberIdCondition                │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│  Controller 预处理                                            │
│  ① limit = true                                              │
│  ② accountId = 当前用户主账号ID                                │
│  ③ envId = 当前环境ID                                         │
└──────────────────────┬───────────────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────────────┐
│  Service: querySessionList()                                  │
│                                                               │
│  ┌───────────────────────────────────────────────────────┐   │
│  │ filters 为空？                                         │   │
│  │   YES → querySessionStartTimeOfLimit()                │   │
│  │          收窄 startTime（窗口函数累积统计）              │   │
│  │   NO  → 跳过                                          │   │
│  └───────────────────────────────────────────────────────┘   │
│                       │                                       │
│                       ▼                                       │
│  ┌───────────────────────────────────────────────────────┐   │
│  │ ConcatQueryEntrySessionList()                         │   │
│  │ → 组装 MetricQueryCondition                            │   │
│  │ → 处理 deviceId/sessionId/appId/时间等过滤条件          │   │
│  │ → 解析 otherFilters 中的 sessionStatus                 │   │
│  │ → 设置 hasError / hasAcceptable                       │   │
│  └───────────────────────────────────────────────────────┘   │
│                       │                                       │
│                       ▼                                       │
│  ┌───────────────────────────────────────────────────────┐   │
│  │ limit=true 分支                                        │   │
│  │                                                        │   │
│  │ ① querySessionIdList() → 全部 sessionId 列表           │   │
│  │ ② getSessionSatisfactionSetting() → 满意度配置         │   │
│  │ ③ querySessionIdErrorList() → 含异常标记的 sessionId    │   │
│  │ ④ 遍历统计异常/可容忍会话数                              │   │
│  │ ⑤ 根据 hasError/hasAcceptable 过滤 sessionId           │   │
│  │ ⑥ 内存分页                                             │   │
│  │ ⑦ getSessionListModel()                               │   │
│  │    → querySessionList() (SQL)                         │   │
│  │    → 数据装饰（城市/运营商/接入/应用/别名/分组/在线）     │   │
│  │ ⑧ 设置 sessionNum / exceptionSession / acceptable      │   │
│  └───────────────────────────────────────────────────────┘   │
│                       │                                       │
│                       ▼                                       │
│  返回 RestResponse.success(resModel)                          │
└──────────────────────────────────────────────────────────────┘
```

---

## 11. 前端调用

前端通过 `newonexm/view/rum/src/services/retrieval/session.ts` 调用：

```typescript
export default {
  sessionList(options: BrRecord) {
    return request.post<RUM_experienceuser.ServeList>(
      '/rest/rum/session/search/sessionList',
      options,
      options.isDownload ? { responseType: 'blob' } : {},
    )
  },
}
```

当 `isDownload = true` 时，请求以 blob 方式响应（用于导出下载）。

---

## 12. 涉及文件清单

| 文件 | 说明 |
|------|------|
| `newonexm/framework/plugins/rum/rum-core/.../session/controller/SessionSearchController.java` | Controller 层，接口入口 |
| `newonexm/framework/plugins/rum/rum-core/.../session/service/impl/RumCkSessionService.java` | Service 实现，核心业务逻辑 |
| `newonexm/framework/plugins/rum/rum-core/.../session/service/RumEsToCkSessionService.java` | Service 接口定义 |
| `newonexm/framework/plugins/rum/rum-core/.../session/condition/MemberIdCondition.java` | 请求参数模型 |
| `newonexm/framework/plugins/rum/rum-common/.../bean/condition/RumBaseCondition.java` | 请求参数基类 |
| `newonexm/framework/plugins/rum/rum-common/.../bean/condition/MetricQueryCondition.java` | 内部查询条件模型 |
| `newonexm/framework/plugins/rum/rum-common/.../bean/session/UserSessionModel.java` | 响应模型（外层） |
| `newonexm/framework/plugins/rum/rum-common/.../bean/session/SessionModel.java` | 响应模型（列表项） |
| `newonexm/framework/plugins/rum/rum-common/.../bean/filters/FilterOption.java` | 过滤条件模型 |
| `newonexm/framework/plugins/rum/rum-common/.../bean/filters/enums/FilterTypeEnum.java` | 过滤操作符枚举 |
| `newonexm/framework/plugins/rum/rum-database/.../session/queryservice/query/RumSessionMapper.java` | MyBatis Mapper 接口 |
| `newonexm/framework/plugins/rum/rum-database/.../query/xml/RumSessionMapper.xml` | MyBatis SQL 映射 |
| `newonexm/framework/plugins/rum/rum-core/.../query/utils/SessionSatisfactionUtils.java` | 会话满意度工具类 |
| `newonexm/framework/plugins/rum/rum-core/.../permission/FuncPermissionConstant.java` | 功能权限常量 |
| `newonexm/framework/plugins/rum/rum-core/.../permission/MenuPermissionConstant.java` | 菜单权限常量 |
| `newonexm/view/rum/src/services/retrieval/session.ts` | 前端接口调用 |

---

## 13. 与 kinshipDiagram 接口 `userNum` 的差异分析

本节说明 `sessionList` 返回的 `results` 条数与 `kinshipDiagram` 返回的 `userNum` 在数据来源与语义上的差异，便于排查两者数值不一致的问题。

### 13.1 涉及的两个接口

| 接口 | 路径（相对服务根路径） |
|------|------------------------|
| 应用详情-关系拓扑 | `POST /rest/rum/digit/appDetail/kinshipDiagram` |
| 会话列表（检索/用户会话等共用） | `POST /rest/rum/session/search/sessionList` |

### 13.2 kinshipDiagram 返回体中的 `userNum`

#### 13.2.1 入口与赋值

- **Controller**：`com.bonree.rum.core.terminal.controller.AppDetailController`
  - 类级别：`@RequestMapping("/rest/rum/digit/appDetail")`
  - 方法：`POST /kinshipDiagram` → `appDetailService.kinshipDiagram(condition)`
- **Service**：`com.bonree.rum.core.terminal.service.AppDetailService#kinshipDiagram`
  - 将前台条件转为报表条件后，调用指标工厂查询业务类型 `APP_KINSHI_MEMBER_LIST`（常量 `40004`），从返回列表第一行 Map 中取 **`userNum`** 写入 `AppKinshipDiagramVO`。

#### 13.2.2 指标定义（`userNum` 实际含义）

业务类型 `APP_KINSHI_MEMBER_LIST` 由 **`AppKinshipMemberList`** 组装查询参数：

- 指标表达式：`uniqTheta(metric['one.rum.app.session.effectiveSessionCount'])`，别名 **`userNum`**。
- 维度：`dimension['appId']` → 输出列 `appId`。
- 过滤：`RumSqlFilterFactory` 根据时间、`appId`、`appVersion`、筛选框等生成 WHERE；并**移除**与 `dimension['moduleName']`、`dimension['subModuleName']` 相关的过滤条件（避免影响该指标查询）。
- 执行：`RumCodeExceptionMapper#queryMetric4CodeException`，从 **`metric"."data"`** 拉取聚合结果。

#### 13.2.3 与 CMDB 指标配置的对应关系

指标 `one.rum.app.session.effectiveSessionCount` 在初始化脚本中描述为**有效会话数量**；存储侧配置为宽表 `one_rum_datasource_gran.t_rum_terminal`，聚合使用 **`uniqHLL12(effective_session_num_uniq12)`**（HyperLogLog 类近似去重）。

因此 **`userNum` 表示：在请求时间范围内、按当前过滤条件，对「有效会话数」指标做 uniqTheta 合并后的去重会话规模估计值**（命名虽为 `userNum`，语义上对齐「有效会话」指标，而非业务上的「用户数」）。

### 13.3 sessionList 返回体中的 `results` 条数

#### 13.3.1 入口

- **Controller**：`com.bonree.rum.core.session.controller.SessionSearchController`
  - 类级别：`@RequestMapping({"/api/rum/session/search", "/rest/rum/session/search"})`
  - 方法：`POST /sessionList` → `rumCkSessionService.querySessionList(condition, envId, locale)`
  - 控制器内将 **`condition.setLimit(Boolean.TRUE)`**，走「带 limit 的会话列表」分支。

#### 13.3.2 核心流程（`RumCkSessionService#querySessionList`）

当 `condition.getLimit() == true` 时（`sessionList` 接口固定为 true）：

1. **无筛选条件时**：可能调用 `querySessionStartTimeOfLimit`，用「最近一批会话」的起始时间**收紧** `startTime`（减轻大范围扫描）。
2. **`ConcatQueryEntrySessionList`** 组装 `MetricQueryCondition`：
   - 合并 `filters`、`deviceId`、`sessionId`、`appId` / `appIds`、时间等；
   - 额外增加 **`monitor_time >= sessionDaysAgo`** 的全局下界（与业务传入时间取交集）；
   - **`sessionLimit = rumConfig.queryCkSessionLimit`**（配置项，作为后续 SQL 的 `LIMIT`）；
   - **HAVING**：`sum("eventNum") > 0`（只保留有事件的会话）；
   - 标记是否「仅异常 / 仅可容忍」等（由 `otherFilters` 中 `sessionStatus` 推导）。
3. **`rumSessionMapper.querySessionIdList`**：在 **`one_rum_datasource_snapshot.t_rum_session_view`** 上按 `sessionId, deviceId` 分组，排序后 **`LIMIT sessionLimit`**（未配置时 XML 默认为 **500**）。
4. **`rumSessionMapper.querySessionIdErrorList`**：在同一视图上，用上一步得到的 `sessionId IN (...)` 再查异常/可容忍等标记，用于筛选最终要展示的 `sessionId` 集合。
5. **分页**：若 `sessionIds.size() > pageSize`，对 `sessionIds` 做 `subList` 得到当前页的 id 列表，并写入 WHERE 的 `sessionId IN (...)`。
6. **`getSessionListModel`** → **`rumSessionMapper.querySessionList`**：仍查 **`t_rum_session_view`**，按更细粒度 `GROUP BY` 聚合出列表行，并做字典/别名装饰，结果放入 **`UserSessionModel.results`**。

#### 13.3.3 `results.length` 与 `sessionNum`

- **`results`**：当前页实际返回的会话明细行数，通常 **`≤ pageSize`**，且受 **`sessionId` 筛选子集** 与 **`querySessionList` 的 LIMIT（`queryCkSessionLimit` 或默认 500）** 双重约束。
- **`sessionNum`**（同接口返回）：在 limit 分支下为 **`querySessionIdList` 返回列表 `allList.size()`**，即**第一步 id 列表的长度（上限为 `queryCkSessionLimit`）**，不是全库会话总数。

### 13.4 对比总结

| 对比项 | `kinshipDiagram.userNum` | `sessionList.results` 条数 |
|--------|--------------------------|------------------------------|
| **数据源** | 指标库 `metric.data`，指标 `one.rum.app.session.effectiveSessionCount` | ClickHouse 快照视图 `one_rum_datasource_snapshot.t_rum_session_view` |
| **语义** | 有效会话数的 **Theta/HLL 类去重聚合**（预聚合宽表 `t_rum_terminal`） | 当前过滤 + HAVING 下，**可查到的会话明细行**（快照视图聚合） |
| **是否分页** | 否；按 `appId` 聚合为一行（取首行 `userNum`） | 是；与 `pageNo`、`pageSize` 强相关 |
| **典型上限** | 由指标查询默认 `LIMIT 10000` 等限制（见 `queryMetric4CodeException`） | 先受 `queryCkSessionLimit`（及 mapper 默认 500）限制 id 规模，再分页 |
| **额外过滤** | 移除 `moduleName` / `subModuleName` 维度的 WHERE | **HAVING `sum(eventNum) > 0`**；无筛选时可能收紧 `startTime`；时间条件会按 `sessionQueryTimeExpansion` 在后续查询中扩展 |
| **与「用户数」关系** | 字段名易误解；指标含义为**有效会话数**，非 member 去重用户数 | 列表按会话维度展示；`memberId` 为空时常回退为 `deviceId`（在 `getSessionListModel` 中处理） |

### 13.5 为何两者数值经常不一致

1. **不同存储与聚合链路**：一个是终端粒度预聚合指标（`t_rum_terminal` + 指标服务），一个是快照会话视图（`t_rum_session_view`）上的实时聚合与截断。
2. **会话列表有硬上限与分页**：`userNum` 不是「当前页条数」；`results.size()` 通常等于 `pageSize`（最后一页除外），且整体受 `queryCkSessionLimit` 约束。
3. **列表侧 HAVING**：`eventNum` 合计为 0 的会话不会进入列表链路；指标侧是否完全等价取决于 `effective_session_num_uniq12` 的写入口径。
4. **近似算法**：`uniqTheta` / `uniqHLL12` 为近似去重，**可能与精确会话计数存在偏差**。
5. **时间窗口与默认下界**：`sessionList` 会叠加 `sessionDaysAgo` 等默认时间条件；`kinshipDiagram` 以 `ConditionConvertUtil.convert(condition)` 为准，两者若前端传参不一致会直接反映到数值差异。

### 13.6 关键代码索引（便于跳转）

- `AppDetailController`：`/rest/rum/digit/appDetail` + `POST /kinshipDiagram`
- `AppDetailService#kinshipDiagram`：取 `APP_KINSHI_MEMBER_LIST` 结果中的 `userNum`
- `AppKinshipMemberList#assembleParam`：`uniqTheta(metric['one.rum.app.session.effectiveSessionCount'])` → `userNum`
- `RumCodeExceptionMapper.xml`：`queryMetric4CodeException` → `FROM "metric"."data"`
- `SessionSearchController`：`/rest/rum/session/search` + `POST /sessionList`，`setLimit(true)`
- `RumCkSessionService#querySessionList` / `ConcatQueryEntrySessionList` / `getSessionListModel`
- `RumSessionMapper.xml`：`querySessionIdList`、`querySessionList` → `t_rum_session_view`，`HAVING` 与 `LIMIT`

以上类与 XML 均位于 `newonexm/framework/plugins/rum` 仓库下。
