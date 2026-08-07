# SQL 与类型问题分析

> 分析范围：`framework/plugins/rum` 模块中 rum-core 的 ClickHouse/Snapshot SQL 时间条件问题，以及 rum-database/rum-core 中实体实例 ID（instanceId）的类型一致性问题。

---

## 一、SQL 缺少时间条件问题分析

### 1.1 背景说明

rum-core 模块中查询 ClickHouse（快照库 snapshot / 指标库 metric）的 SQL 主要有以下两类构建方式：

1. **druid 包查询类**：继承 `RumMetricService`，通过 `RumSqlFilterFactory.getSqlFilter(filterOptions, db, envId, accId, startTime, endTime, alias, condition)` 构建 SQL，时间条件由 `startTime`/`endTime` 参数传入。
2. **Session CK 服务**（`RumCkSessionService`、`RumCkSessionSearchService`）：直接构建 `FilterOption` 列表并调用 `getSqlFilter`，对特定接口只添加固定滚动时间窗口（`monitor_time >= now - N天`），不接收用户传入的起止时间。

**问题分级说明**：

- **【一级】完全无时间条件**：SQL 中没有任何时间字段过滤，直接查全量数据
- **【二级】仅固定滚动窗口，无用户指定起止时间**：SQL 只有系统内置的 `monitor_time >= (now - N天)` 约束，前端传入的 `startTime`/`endTime` 被忽略
- **【三级】废弃代码**：整个类已全部注释，Spring 不会加载，不影响运行，但存在歧义

---

### 1.2 【一级】完全无时间条件

#### 1.2.1 请求详情 - 基本属性

| 项目 | 内容 |
|------|------|
| **SQL 构建类** | `framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/network/druid/ReqInfo.java` |
| **业务类型注解** | `@RumMetricApi(RumBusinessType.NET_REQ_INFO)` |
| **Controller** | `NetWorkController` |
| **API 路径** | `POST /rest/rum/network/reqInfo` |
| **功能说明** | 网络请求-请求详情-基本属性 |
| **时间条件** | ❌ **完全无时间条件** |

**SQL 构建代码（`ReqInfo.java` 第 31~46 行）：**

```java
@Override
protected List<Map<String, Object>> assembleParam(ReportCondition condition) {
    Map queryJson = condition.getOtherMap();
    // 直接调用 Mapper，只传 url、envId、accId，没有任何时间参数
    List<Map<String, Object>> data = rumMetricNetMapper.queryRequestEntity(
        queryJson.get("url").toString(),
        condition.getEnvId(),
        condition.getAccId());
    // ...
}
```

**问题分析：**

该方法完全绕过了 `RumSqlFilterFactory.getSqlFilter()` 标准路径，直接调用 `RumMetricNetMapper.queryRequestEntity(url, envId, accId)`，**未传入任何起始时间或结束时间参数**。如果底层 Mapper 对应的 SQL 也不包含时间过滤，则该查询将扫描指定 `envId`/`accId` 下的全量历史数据，存在性能风险。

---

### 1.3 【二级】仅固定滚动窗口，无用户指定起止时间

以下接口均来自 `RumCkSessionService` 和 `RumCkSessionSearchService`，共同特征：

- **已有时间约束**：通过 `FilterTypeEnum.monitorTimeGreaterEqual` 或 `FilterTypeEnum.greaterEqual` 添加了 `monitor_time >= (now - rumConfig.sessionDaysAgo 天)` 的滚动时间窗口
- **缺失用户指定时间**：调用 `getSqlFilter(...)` 时，第 5、6 位参数（`startTime`、`endTime`）均传 `null`，前端请求中的时间范围参数被完全忽略

#### 1.3.1 查询用户标签和属性（用户画像）

| 项目 | 内容 |
|------|------|
| **SQL 构建方法** | `RumCkSessionService.buildQueryUserInfoCondition()` |
| **Controller** | `SessionController` |
| **API 路径** | `POST /rest/rum/session/userInfo` |
| **功能说明** | 查询用户标签和属性（API注释：用户画像固定查30天） |
| **时间条件** | ⚠️ **仅固定滚动窗口，无用户指定起止时间** |

**SQL 构建核心代码：**

```java
private MetricQueryCondition buildQueryUserInfoCondition(MemberIdCondition condition) {
    List<FilterOption> filterOptions = Lists.newArrayList();
    // 只加了固定滚动窗口
    filterOptions.add(RumSqlFilterUtil.putFilterOption("monitor_time", FilterTypeEnum.greaterEqual,
        DateUtil.formatDateToString(DateUtil.getDateAddDate(new Date(), DateUtil.DAY,
            Convert.toInt(-rumConfig.sessionDaysAgo)), DateUtil.YYYY_MM_DDHHMMSS)));
    MetricQueryCondition metricQueryCondition = new MetricQueryCondition();
    // startTime=null, endTime=null ← 用户传入的时间参数被完全忽略
    metricQueryCondition = (MetricQueryCondition) rumSqlFilterFactory.getSqlFilter(
        filterOptions, DataBaseEnum.snapshot,
        condition.getEnvId(), getAccountId(condition.getAccountId()),
        null, null,  // ← 无 startTime / endTime
        "session", metricQueryCondition);
    return metricQueryCondition;
}
```

**备注：** 该接口是用户画像查询，设计上确实是按"最近 N 天"查询，无需用户指定时间窗口，属于业务设计决策。

---

#### 1.3.2 查询用户在线状态

| 项目 | 内容 |
|------|------|
| **SQL 构建方法** | `RumCkSessionService.getOnlineForUserStatus()` |
| **Controller** | `SessionController` |
| **API 路径** | `POST /rest/rum/session/userOnlineStatus` |
| **功能说明** | 查询用户在线状态(近三天) |
| **时间条件** | ⚠️ **固定近3天窗口，不接受用户指定时间** |

**SQL 构建核心代码：**

```java
public UserStatusModel getOnlineForUserStatus(MemberIdCondition condition) {
    Long threeDaysAgo = LocalDateTime.now().minusDays(3).toDate().getTime();
    Long now = LocalDateTime.now().toDate().getTime();
    List<FilterOption> filterOptions = Lists.newArrayList();
    // 硬编码近3天
    filterOptions.add(RumSqlFilterUtil.putFilterOption("monitor_time", FilterTypeEnum.greaterEqual,
        DateUtil.formatDateToString(new Date(threeDaysAgo), DateUtil.YYYY_MM_DDHHMMSS)));
    filterOptions.add(RumSqlFilterUtil.putFilterOption("monitor_time", FilterTypeEnum.less,
        DateUtil.formatDateToString(new Date(now), DateUtil.YYYY_MM_DDHHMMSS)));
    // startTime=null, endTime=null
    metricQueryCondition = (MetricQueryCondition) rumSqlFilterFactory.getSqlFilter(
        filterOptions, DataBaseEnum.snapshot,
        condition.getEnvId(), getAccountId(condition.getAccountId()),
        null, null,  // ← 无 startTime / endTime
        "session", metricQueryCondition);
    // ...
}
```

**备注：** 该接口功能定义就是"近三天在线状态"，固定时间范围属于正常业务设计。

---

#### 1.3.3 查询会话基础和统计信息

| 项目 | 内容 |
|------|------|
| **SQL 构建方法** | `RumCkSessionSearchService.queryBaseCount()` |
| **Controller** | `SessionSearchController` |
| **API 路径** | `POST /api/rum/session/search/querySessionInfo`<br>`POST /rest/rum/session/search/querySessionInfo` |
| **功能说明** | 查询会话的统计信息和基础信息（会话详情顶部卡片） |
| **时间条件** | ⚠️ **仅固定滚动窗口，无用户指定起止时间** |

**SQL 构建核心代码：**

```java
public RestResponse<Map<String, Object>> queryBaseCount(SessionCondition condition, ...) {
    List<FilterOption> filterOptions = Lists.newArrayList();
    // 仅按 sessionId 过滤 + 固定滚动窗口
    filterOptions.add(RumSqlFilterUtil.putFilterOption("sessionId", FilterTypeEnum.equal,
        condition.getSessionId()));
    filterOptions.add(RumSqlFilterUtil.putFilterOption("monitor_time", FilterTypeEnum.greaterEqual,
        DateUtil.formatDateToString(DateUtil.getDateAddDate(new Date(), DateUtil.DAY,
            Convert.toInt(-rumConfig.sessionDaysAgo)), DateUtil.YYYY_MM_DDHHMMSS)));
    // startTime=null, endTime=null
    metricQueryCondition = (MetricQueryCondition) rumSqlFilterFactory.getSqlFilter(
        filterOptions, DataBaseEnum.snapshot,
        condition.getEnvId(), getAccountId(condition.getAccountId()),
        null, null,  // ← 无 startTime / endTime
        "session", metricQueryCondition);
}
```

**备注：** 此接口通过 `sessionId` 精确定位会话，本身不依赖时间范围定位数据，属于会话详情查询的合理设计。

---

#### 1.3.4 查询会话城市运营商

| 项目 | 内容 |
|------|------|
| **SQL 构建方法** | `RumCkSessionSearchService.querySessionCityNetServiceList()` |
| **Controller** | `SessionSearchController` |
| **API 路径** | `POST /api/rum/session/search/queryCityNetServiceList`<br>`POST /rest/rum/session/search/queryCityNetServiceList` |
| **功能说明** | 查询会话城市运营商（会话详情-城市网络轨迹列表） |
| **时间条件** | ⚠️ **仅固定滚动窗口，无用户指定起止时间** |

**SQL 构建核心代码：**

```java
public RestResponse querySessionCityNetServiceList(SessionCondition condition, ...) {
    List<FilterOption> filterOptions = Lists.newArrayList();
    filterOptions.add(RumSqlFilterUtil.putFilterOption("sessionId", FilterTypeEnum.equal,
        condition.getSessionId()));
    filterOptions.add(RumSqlFilterUtil.putFilterOption("appId", FilterTypeEnum.equal,
        condition.getAppId()));
    filterOptions.add(RumSqlFilterUtil.putFilterOption("monitor_time", FilterTypeEnum.greaterEqual,
        DateUtil.formatDateToString(DateUtil.getDateAddDate(new Date(), DateUtil.DAY,
            Convert.toInt(-rumConfig.sessionDaysAgo)), DateUtil.YYYY_MM_DDHHMMSS)));
    // startTime=null, endTime=null
    metricQueryCondition = (MetricQueryCondition) rumSqlFilterFactory.getSqlFilter(
        filterOptions, DataBaseEnum.snapshot,
        condition.getEnvId(), accountId,
        null, null,  // ← 无 startTime / endTime
        "session", metricQueryCondition);
}
```

---

#### 1.3.5 查询会话事件列表（会话详情主事件列表）

| 项目 | 内容 |
|------|------|
| **SQL 构建方法** | `RumCkSessionSearchService.querySessionEventList()` |
| **Controller** | `SessionSearchController` |
| **API 路径** | `POST /api/rum/session/search/querySessionEventList`<br>`POST /rest/rum/session/search/querySessionEventList` |
| **功能说明** | 查询会话事件列表（会话详情事件时间轴） |
| **时间条件** | ⚠️ **只有可选 startTime，endTime 始终为 null** |

**SQL 构建核心代码：**

```java
metricQueryCondition = (MetricQueryCondition) rumSqlFilterFactory.getSqlFilter(
    filterOptions, DataBaseEnum.snapshot,
    condition.getEnvId(), accountId,
    // startTime 条件性传入（非 null 时生效），但 endTime 始终为 null
    Objects.nonNull(condition.getStartTime()) ? condition.getStartTime() : null,
    null,  // ← endTime 始终为 null
    "session", metricQueryCondition);
```

**问题分析：**

`endTime` 参数硬编码为 `null`，导致查询无上界时间限制（只有下界 `startTime` 或固定滚动窗口）。该接口同时被 `queryOnLineTask`（`/queryOnLineTask`）内部调用。

---

#### 1.3.6 查询会话事件列表-抽屉页（网络事件分页）

| 项目 | 内容 |
|------|------|
| **SQL 构建方法** | `RumCkSessionSearchService.queryNetSessionEvent()` |
| **Controller** | `SessionSearchController` |
| **API 路径** | `POST /api/rum/session/search/querySessionEventDetailList`<br>`POST /rest/rum/session/search/querySessionEventDetailList`<br>（当 `drawerType` 不为 CLICK / QUESTION 时触发） |
| **功能说明** | 会话抽屉页-网络事件详情分页列表 |
| **时间条件** | ⚠️ **getSqlFilter 中无 startTime / endTime（通过 eventDetail filter 代替）** |

**SQL 构建核心代码：**

```java
private RestResponse queryNetSessionEvent(SessionEventCondition condition, ...) {
    // 通过 eventDetail FilterType 传入时间范围（非标准 startTime/endTime）
    filterOptions.add(RumSqlFilterUtil.putFilterOption("eventDetail", FilterTypeEnum.eventDetail,
        Arrays.asList(condition.getEventId(),
            DateUtil.formatDateToString4Session(condition.getStartTime(), ...),
            DateUtil.formatDateToString4Session(condition.getEndTime(), ...))));
    // getSqlFilter 的 startTime/endTime 参数为 null
    metricQueryCondition = (MetricQueryCondition) rumSqlFilterFactory.getSqlFilter(
        filterOptions, DataBaseEnum.snapshot,
        condition.getEnvId(), getAccountId(condition.getAccountId()),
        null, null,  // ← startTime/endTime 均为 null
        "session", metricQueryCondition);
}
```

**备注：** 时间范围通过 `FilterTypeEnum.eventDetail` 封装后传入，与标准的 `getSqlFilter` 时间参数路径不同，SQL 生成方式存在差异，需结合 Mapper 实现确认其实际效果。

---

#### 1.3.7 查询会话事件列表-抽屉页（操作/问题事件）

| 项目 | 内容 |
|------|------|
| **SQL 构建方法** | `RumCkSessionSearchService.queryActionOrQuestionSessionEventList()` |
| **Controller** | `SessionSearchController` |
| **API 路径** | `POST /api/rum/session/search/querySessionEventDetailList`<br>（当 `drawerType` 为 CLICK 或 QUESTION 时触发） |
| **功能说明** | 会话抽屉页-操作/问题事件详情分页列表 |
| **时间条件** | ⚠️ **主查询 getSqlFilter 中无 startTime / endTime** |

**SQL 构建核心代码（主查询部分）：**

```java
private RestResponse<...> queryActionOrQuestionSessionEventList(...) {
    // 主查询：getSqlFilter 的 startTime/endTime 均为 null
    metricQueryCondition = (MetricQueryCondition) rumSqlFilterFactory.getSqlFilter(
        filterOptions, DataBaseEnum.snapshot,
        condition.getEnvId(), accountId,
        null, null,  // ← startTime/endTime 均为 null
        "session", metricQueryCondition);

    // 第二查询（secondEvents）：使用时间条件（有 startTime/endTime）
    metricQueryConditionSecondEvents = (MetricQueryCondition) rumSqlFilterFactory.getSqlFilter(
        filterOptionsSecondEvents, DataBaseEnum.snapshot,
        condition.getEnvId(), accountId,
        EmptyUtils.isCollectionNotEmpty(events) ? events.get(0).getMonitorTime() : null,
        Objects.nonNull(condition.getEndTime()) ? condition.getEndTime() : null,
        "session", metricQueryConditionSecondEvents);
}
```

**问题分析：** 主事件查询（操作/问题列表）的时间范围通过 `eventDetail` FilterType 封装，而非标准的 `getSqlFilter` 时间参数。

---

#### 1.3.8 查询会话事件统计（抽屉页事件数量）

| 项目 | 内容 |
|------|------|
| **SQL 构建方法** | `RumCkSessionSearchService.queryDetailActionAndProblemCount()`<br>`RumCkSessionSearchService.queryDetailNetworkCount()` |
| **Controller** | `SessionSearchController` |
| **API 路径** | `POST /api/rum/session/search/querySessionEventDetailListCount`<br>`POST /rest/rum/session/search/querySessionEventDetailListCount` |
| **功能说明** | 查询会话事件列表统计（用户操作数/问题数/网络请求数） |
| **时间条件** | ⚠️ **getSqlFilter 中无 startTime / endTime（通过 eventDetail filter 代替）** |

**SQL 构建核心代码：**

```java
// queryDetailActionAndProblemCount 和 queryDetailNetworkCount 均采用此模式：
filterOptions.add(RumSqlFilterUtil.putFilterOption("eventDetail", FilterTypeEnum.eventDetail,
    Arrays.asList(condition.getEventId(),
        DateUtil.formatDateToString4Session(condition.getStartTime(), ...),
        DateUtil.formatDateToString4Session(condition.getEndTime(), ...))));
metricQueryCondition = (MetricQueryCondition) rumSqlFilterFactory.getSqlFilter(
    filterOptions, DataBaseEnum.snapshot,
    envId, getAccountId(),
    null, null,  // ← startTime/endTime 均为 null
    "session", metricQueryCondition);
```

---

### 1.4 【三级】废弃/全注释的代码文件（已清理）

以下文件中的全部代码已被行注释符（`//`）注释，Spring 不会扫描加载，**对线上业务无影响**，**已于 2026-03-28 删除**。

| 文件名 | 业务类型 | 所属模块 | 状态 |
|--------|----------|---------|------|
| `framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/network/druid/ReqTrend.java` | `NET_REQ_TREND` | 网络请求 | ✅ 已删除 |
| `framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/network/druid/ServerNameCount.java` | `NET_SERVER_NAME_COUNT` | 网络请求 | ✅ 已删除 |
| `framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/network/druid/ReqAnalysis.java` | `NET_REQ_ANALYSIS` | 网络请求 | ✅ 已删除 |
| `framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/network/druid/NetReqStatisticalChart.java` | `NET_REQ_STATISTICAL_CHART` | 网络请求 | ✅ 已删除 |
| `framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/network/druid/NetReqStatistical.java` | `NET_REQ_STATISTICAL` | 网络请求 | ✅ 已删除 |

---

### 1.5 待确认项

#### 1.5.1 SessionTable - 会话统计卡片

| 项目 | 内容 |
|------|------|
| **SQL 构建类** | `framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/session/druid/SessionTable.java` |
| **业务类型注解** | `@RumMetricApi(RumBusinessType.SESSION_TABLE_STATISTICAL)` |
| **时间条件** | ❓ **不确定（完全依赖 `condition.getFilter()` 的内容）** |

**代码：**

```java
@Override
protected List<Map<String, Object>> assembleParam(ReportCondition condition) {
    // 直接传入 filter 对象，绕过标准 getSqlFilter 路径
    return rumSessionMetricMapper.sessionCard(condition.getFilter());
}
```

**说明：** 该类绕过了 `RumSqlFilterFactory.getSqlFilter()` 标准路径，直接将外部传入的 `filter` 对象透传给 Mapper。时间条件是否生效完全取决于调用方组装 `condition.getFilter()` 时是否包含时间字段。

目前代码中 `SESSION_TABLE_STATISTICAL` 类型的调用引用（`NetReqStatistical`、`NetReqStatisticalChart`、`ReqAnalysis` 中的 `metricServiceFactory.query(RumBusinessType.SESSION_TABLE_STATISTICAL, condition)`）**均已被注释**，该 Service 可能已无活跃调用入口，建议进一步确认。

---

### 1.6 汇总对照表

| 序号 | 接口路径 | Controller | SQL 构建类/方法 | 时间条件状态 | 风险等级 |
|------|---------|-----------|----------------|------------|---------|
| 1 | `POST /rest/rum/network/reqInfo` | `NetWorkController` | `ReqInfo.assembleParam` | ❌ 完全无时间条件 | 🔴 高 |
| 2 | `POST /rest/rum/session/userInfo` | `SessionController` | `RumCkSessionService.buildQueryUserInfoCondition` | ⚠️ 仅固定滚动窗口 | 🟡 中（设计合理） |
| 3 | `POST /rest/rum/session/userOnlineStatus` | `SessionController` | `RumCkSessionService.getOnlineForUserStatus` | ⚠️ 固定近3天 | 🟡 中（设计合理） |
| 4 | `POST /api(rest)/rum/session/search/querySessionInfo` | `SessionSearchController` | `RumCkSessionSearchService.queryBaseCount` | ⚠️ 仅固定滚动窗口 | 🟡 中（按 sessionId 查，设计合理） |
| 5 | `POST /api(rest)/rum/session/search/queryCityNetServiceList` | `SessionSearchController` | `RumCkSessionSearchService.querySessionCityNetServiceList` | ⚠️ 仅固定滚动窗口 | 🟡 中（按 sessionId 查，设计合理） |
| 6 | `POST /api(rest)/rum/session/search/querySessionEventList` | `SessionSearchController` | `RumCkSessionSearchService.querySessionEventList` | ⚠️ 仅有 startTime，endTime=null | 🟠 中高 |
| 7 | `POST /api(rest)/rum/session/search/querySessionEventDetailList`<br>（drawerType≠CLICK/QUESTION） | `SessionSearchController` | `RumCkSessionSearchService.queryNetSessionEvent` | ⚠️ getSqlFilter 中无时间，通过 eventDetail filter 代替 | 🟡 中（需验证） |
| 8 | `POST /api(rest)/rum/session/search/querySessionEventDetailList`<br>（drawerType=CLICK/QUESTION，主查询） | `SessionSearchController` | `RumCkSessionSearchService.queryActionOrQuestionSessionEventList` | ⚠️ 主查询无时间，通过 eventDetail filter 代替 | 🟡 中（需验证） |
| 9 | `POST /api(rest)/rum/session/search/querySessionEventDetailListCount` | `SessionSearchController` | `RumCkSessionSearchService.queryDetailActionAndProblemCount`<br>`queryDetailNetworkCount` | ⚠️ getSqlFilter 中无时间，通过 eventDetail filter 代替 | 🟡 中（需验证） |
| - | `session/druid/SessionTable` | 未知（待确认） | `SessionTable.assembleParam` | ❓ 不确定，依赖 filter 内容 | ❓ 待确认 |

---

### 1.7 修复建议

#### 1.7.1 高优先级（立即处理）

**`ReqInfo.java` → `POST /rest/rum/network/reqInfo`**

建议检查 `RumMetricNetMapper.queryRequestEntity` 对应的 MyBatis SQL，确认：

- 如果是查询"请求实体元数据"（类似配置表），则无需时间范围，可保持现状
- 如果是查询时序快照数据，则需补充时间范围参数，建议将 `condition.getLongStartTime()` 和 `condition.getLongEndTime()` 传给 Mapper

#### 1.7.2 中优先级（评估后处理）

**`querySessionEventList` → `POST /api(rest)/rum/session/search/querySessionEventList`**

当前 `endTime` 硬编码为 `null`，若用户会话的事件数据量较大，无上界时间限制可能导致查询结果集过大。建议评估是否需要将 `condition.getEndTime()` 传入 `getSqlFilter`。

---

## 二、实体实例 ID 类型分析

### 2.1 概述

rum 模块中实体实例 id（instanceId）在数据库层面已经是 `bigint` 类型（对应 Java 的 `Long`），大部分 Java 代码也已使用 Long 类型，但在部分实体类中仍使用 Integer 类型，存在类型不一致风险。本节梳理需要从 Integer 改为 Long 的所有位置，以及已经正确使用 Long 的位置。

### 2.2 数据库层面

- **数据库类型**：instanceId 在数据库中是 `bigint` 类型（对应 Java 的 `Long`）
- **实体视图**：entity.app、entity.page、entity.request、entity.user、entity.action、entity.usergroup 等视图中的 instanceId 都是 bigint 类型

### 2.3 Java 代码层面分析

#### 2.3.1 Mapper 接口（已确认使用 Long）

以下 Mapper 接口的 instanceId 参数已经是 Long 类型：

- `RumMetricViewMapper.queryViewEntity()` - 参数类型：Long
- `RumQueryServiceUserGroupMapper.queryUserGroupByInstanceId()` - 参数类型：通过 `ReqUserGroupQuery` 传递

#### 2.3.2 实体类和 DTO（需要修改）

需要将以下实体类中的 id 字段从 Integer 改为 Long：

- `UserMember` - id 字段为 Integer（第 25 行）
- `QueryUser` - id 字段为 Integer（第 24 行）
- 其他实体类需要进一步检查

#### 2.3.3 Service 层（已确认使用 Long）

- `RumCMDBEntityManager` - 大部分方法使用 Long 类型
- `AppViewService` - 使用 `Long.valueOf()` 转换
- `AppService` - 使用 `Convert.toLong()` 转换

#### 2.3.4 XML Mapper 文件

在 XML 映射文件中，instanceId 的使用情况：

- 大部分地方使用 `#{instanceId}` 或 `#{id}`，类型由 Java 参数决定
- 部分地方使用 `CAST(ea.instanceId AS VARCHAR)` 进行类型转换（用于字符串比较）

### 2.4 需要修改的内容

#### 2.4.1 实体类修改

##### 2.4.1.1 UserMember.java

**文件路径**：`framework/plugins/rum/rum-database/src/main/java/com/bonree/rum/setting/entity/user/UserMember.java`

- 第 25 行：`private Integer id;` → `private Long id;`
- 第 40 行：`private Integer appId;` → `private Long appId;`（如果 appId 也代表实体实例 id）
- 第 43 行：`private Integer createUserId;` → 保持不变（这是用户 ID，不是实体实例 ID）

##### 2.4.1.2 QueryUser.java

**文件路径**：`framework/plugins/rum/rum-database/src/main/java/com/bonree/rum/setting/entity/user/QueryUser.java`

- 第 24 行：`private Integer id;` → `private Long id;`

#### 2.4.2 Mapper 接口修改

##### 2.4.2.1 RumQueryServiceUserGroupMapper.java

**文件路径**：`framework/plugins/rum/rum-database/src/main/java/com/bonree/rum/mysql/rumqueryservice/usergroup/queryservice/query/RumQueryServiceUserGroupMapper.java`

- 第 71 行：`getUserGroupByUser(@Param("memberIdList") List<Integer> idList, ...)`
  - 如果 idList 中的 id 是实体实例 id，需要改为 `List<Long>`

#### 2.4.3 XML Mapper 文件修改

##### 2.4.3.1 RumQueryServiceAppMapper.xml

**文件路径**：`framework/plugins/rum/rum-database/src/main/resources/com/bonree/rum/mysql/rumqueryservice/queryservice/query/xml/RumQueryServiceAppMapper.xml`

- 第 465 行：`where instanceId = #{id,jdbcType=BIGINT}` - 已正确使用 BIGINT

#### 2.4.4 Service 层修改

##### 2.4.4.1 AppViewService.java

**文件路径**：`framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/terminal/service/AppViewService.java`

- 第 172 行：`Long.valueOf(condition.getQueryJson().get("viewNameCode").toString())` - 已使用 Long

##### 2.4.4.2 AppService.java

**文件路径**：`framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/terminal/service/AppService.java`

- 第 148 行：`Convert.toLong(instanceId)` - 已使用 Long

#### 2.4.5 其他需要检查的地方

##### 2.4.5.1 测试类

- `RumMetricViewMapperTest.java` - 检查测试中的 instanceId 类型
- `RumQueryServiceUserGroupMapperTest.java` - 检查测试中的 instanceId 类型

##### 2.4.5.2 常量定义

检查是否有硬编码的 Integer 类型常量用于实体实例 id

### 2.5 已验证使用 Long 类型的地方（无需修改）

以下位置已经正确使用 Long 类型：

1. **AlertQueryCondition.java** - instanceId 字段为 Long（第 30 行）
2. **RumMetricViewMapper.java** - `queryViewEntity` 方法的 instanceId 参数为 Long
3. **AppViewService.java** - 使用 `Long.valueOf()` 进行转换
4. **AppService.java** - 使用 `Convert.toLong()` 进行转换
5. **RumCMDBEntityManager.java** - 大部分方法使用 Long 类型
6. **CmdbEntity.java** - instanceId 字段为 Long 类型

### 2.6 相关文件清单

#### 实体类

- `framework/plugins/rum/rum-database/src/main/java/com/bonree/rum/setting/entity/user/UserMember.java`
- `framework/plugins/rum/rum-database/src/main/java/com/bonree/rum/setting/entity/user/QueryUser.java`

#### Mapper 接口

- `framework/plugins/rum/rum-database/src/main/java/com/bonree/rum/mysql/rumqueryservice/usergroup/queryservice/query/RumQueryServiceUserGroupMapper.java`

#### XML Mapper 文件

- `framework/plugins/rum/rum-database/src/main/resources/com/bonree/rum/mysql/rumqueryservice/queryservice/query/xml/RumQueryServiceAppMapper.xml`
- `framework/plugins/rum/rum-database/src/main/resources/com/bonree/rum/mysql/rumqueryservice/queryservice/query/xml/RumQueryServiceUserGroupMapper.xml`
- `framework/plugins/rum/rum-database/src/main/resources/com/bonree/rum/mysql/rumqueryservice/view/queryservice/query/xml/RumQueryViewMapper.xml`

#### Service 类

- `framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/terminal/service/AppViewService.java`
- `framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/terminal/service/AppService.java`
- `framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/common/service/RumCMDBEntityManager.java`

### 2.7 修改建议与优先级

#### 优先级 1（必须修改）

1. **UserMember.java** - id 字段改为 Long
2. **QueryUser.java** - id 字段改为 Long
3. **RumQueryServiceUserGroupMapper.java** - 如果 idList 是实体实例 id，改为 `List<Long>`

#### 优先级 2（需要确认）

1. 检查所有使用 `UserMember.id` 和 `QueryUser.id` 的地方
2. 检查所有相关的 XML Mapper 文件中的类型映射
3. 检查所有相关的测试类

#### 优先级 3（验证）

1. 运行所有相关测试，确保类型转换正确
2. 检查数据库查询结果映射是否正确

### 2.8 注意事项

1. **类型转换**：在修改过程中，需要注意 Integer 到 Long 的隐式转换，但建议显式转换以确保安全
2. **空值处理**：Integer 和 Long 的空值处理方式相同，但需要注意 null 检查
3. **数据库兼容性**：数据库层面已经是 bigint，所以主要是 Java 代码层面的修改
4. **向后兼容性**：如果这些实体类被其他模块使用，需要考虑兼容性问题

---

## 三、共性问题与改进建议

### 3.1 共性问题归纳

1. **绕过标准查询封装路径**
   - SQL 时间条件问题中，`ReqInfo.java` 和 `SessionTable.java` 均绕过 `RumSqlFilterFactory.getSqlFilter()` 标准路径，直接调用 Mapper 或透传 filter 对象，导致时间条件是否生效难以保证。
   - 类型问题中，部分实体类（`UserMember`、`QueryUser`）未遵循"数据库 bigint 对应 Java Long"的统一约定，绕过了已建立的长整型类型规范。

2. **硬编码与隐式忽略参数**
   - SQL 问题中存在 `endTime` 硬编码为 `null`、用户传入的 `startTime`/`endTime` 被完全忽略的情况。
   - 类型问题中存在 `Integer` 与 `Long` 混用，依赖隐式转换，缺乏显式声明。

3. **缺乏统一规范约束**
   - 两类问题都反映出在查询封装层（`RumQueryService`/`RumSqlFilterFactory`）和类型规范层面，缺乏强制性的代码约束，容易在新增代码时遗漏。

### 3.2 改进建议

1. **强制走标准查询封装路径**
   - 所有 ClickHouse/Snapshot 查询必须通过 `RumSqlFilterFactory.getSqlFilter()` 或对应 Mapper 封装，禁止在业务代码中直接透传 filter 对象或绕过时间参数。
   - 对于确实不需要时间条件的查询（如配置元数据查询），应在代码中显式注释说明原因。

2. **统一 ID 类型规范**
   - 数据库 `bigint` 字段在 Java 中统一使用 `Long` 类型，禁止使用 `Integer`。
   - 在 CheckStyle 规则或代码评审中增加对 instanceId/id 字段类型的检查。

3. **补全单元测试**
   - 对涉及时间条件的接口，补充针对不同时间范围输入的测试用例，验证 SQL 生成结果。
   - 对涉及类型转换的实体类和 Mapper，补充类型边界测试（如 null 值、大值超出 Integer 范围的场景）。

4. **清理废弃代码**
   - 已全注释的废弃类应及时删除，避免造成代码歧义（如本分析中已清理的 5 个 network/druid 类）。
   - 对 `SessionTable` 等待确认项，应核实调用入口，若无活跃调用则删除。

5. **建立影响评估机制**
   - 调整查询条件或口径时，必须评估对 ClickHouse 物化视图（MV）刷新和数据一致性的影响。
   - 修改实体类字段类型时，必须评估对所有调用方（包括其他模块）的兼容性影响。
