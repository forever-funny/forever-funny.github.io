---
title: 接口文档：检索中心记录列表 record-list
---

# 接口文档：检索中心记录列表 record-list

## 1. 接口概览

| 属性 | 说明 |
|------|------|
| **URL** | `/rest/rum/retrieve-center/record-list` |
| **备用URL（Common API）** | `/api/rum/common/retrieve-center/record-list` |
| **请求方式** | `POST` |
| **Content-Type** | `application/json` |
| **接口描述** | 检索中心记录列表查询接口，支持查询网络请求(NET)、页面加载(H5)、JS错误(JS_ERROR)、ANR、卡顿(LAG)、崩溃(CRASH)、自定义异常(SELF_CRASH)、启动(LAUNCH)、视图(VIEW)、操作(ACTION)、自定义事件(CUSTOM_EVENT) 共 11 种数据类型的快照记录列表。根据 `problemType` 动态路由到对应的 ClickHouse 快照表，支持分页、排序和多种过滤条件。 |
| **所属Controller** | `RetrievalController`（产品 UI）/ `RumApiController`（Common API） |
| **Service实现** | `RetrievalService.getRecordList()` |
| **Repository** | `RetrievalRepository.queryProblemDataList()` |
| **数据源** | ClickHouse（由 `SnapshotTableEnum` 根据 `problemType` 动态选择快照表） |

---

## 2. 权限校验

### 2.1 功能权限（@OperatePermissionCheck）

需要以下任一功能权限（OR 关系）：

| 权限标识 | 常量 | 说明 |
|---------|------|------|
| `one:resource:rumReadResource` | `RUM_RESOURCE_READ` | RUM 资源只读权限 |
| `one:resource:rumManageResource` | `RUM_RESOURCE_READ_AND_WRITE` | RUM 资源读写权限 |

### 2.2 列表页签特殊过滤（@OtherFilter）

该注解用于列表页签的特殊过滤处理，`parentFilterFlag` 默认为 `true`。

### 2.3 Common API 入口（@IamRestrictApi）

通过 `/api/rum/common/retrieve-center/record-list` 进入时，走 `RumApiController`，该入口：
- 标注了 `@IamRestrictApi` 注解
- 会额外设置 `condition.setIsFromApi(true)`，影响后续数据处理逻辑（不限制环境及资源域）

---

## 3. 请求参数

### 3.1 RumBaseCondition（请求体）

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| startTime | Long | 是 | 0 | 开始时间（时间戳，毫秒） |
| endTime | Long | 是 | 0 | 结束时间（时间戳，毫秒） |
| appId | Long | 否 | -1 | 应用ID，-1 表示不限制 |
| appIds | List\<Long\> | 否 | [] | 应用ID列表 |
| pageNo | Integer | 否 | 1 | 页码 |
| pageSize | Integer | 否 | 10 | 每页条数 |
| sortField | String | 否 | null | 排序字段 |
| sortOrder | String | 否 | "desc" | 排序方向（desc/asc） |
| filters | List\<FilterOption\> | 否 | [] | 过滤条件列表 |
| queryJson | Map | 否 | {} | 其他过滤参数的 JSON 对象（包含 `problemType` 等关键字段） |
| isDownload | Boolean | 否 | null | 是否是下载请求 |
| accountId | Long | 否 | null | 主账号ID（非 API 来源时由系统自动填充） |
| envId | String | 否 | null | 环境ID（非 API 来源时由系统自动填充） |
| language | String | 否 | "zh_CN" | 当前语言 |
| downLoadHeaders | List\<Map\<String, String\>\> | 否 | null | 下载请求的列名字段和反显 |
| otherFilters | List\<FilterOption\> | 否 | [] | 筛选框过滤插件 |
| parentFilters | List\<FilterOption\> | 否 | [] | 父子页面传参 |
| ln | Long | 否 | null | 前端带回的 limit 数量 |
| lnFlag | String | 否 | null | 前端带回的控制 limit tag 标识 |
| isFromApi | Boolean | 否 | false | 是否从 API 来源（内部使用） |
| isFromOpenApi | Boolean | 否 | false | 是否从 OpenAPI 来源 |
| keyEntityFlag | Integer | 否 | null | 传1查询关键实体数据 |

### 3.2 queryJson 关键字段

| 参数名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| problemType | Integer | **是** | 数据类型：1-NET, 2-H5, 3-JS_ERROR, 4-ANR, 5-LAG, 6-CRASH, 7-SELF_CRASH, 8-LAUNCH, 9-VIEW, 10-ACTION, 11-CUSTOM_EVENT |
| problemId | String | 否 | 问题ID，可配合 `problemGroup` 使用 |
| problemGroup | String | 否 | 问题分组类型（page/file/info），决定 problemId 匹配字段 |
| platform | String | 否 | 平台标识，存在时 `hasDetail` 为 true |
| actionCode | String | 否 | 操作ID，用于操作页面过滤 |
| actionType | String | 否 | 操作类型 |
| viewCode | String | 否 | 视图编码，过滤 `otherIndex['pageId']` |
| actionSnapshotId | String | 否 | 操作快照ID，过滤 `parentId` |
| healthyType | String | 否 | 操作健康类型 |
| domain | String | 否 | 域名（NET 类型使用） |
| reqType | String | 否 | 请求类型（NET 类型使用） |
| dataType | String | 否 | 数据类型（NET 类型使用，过滤 requestSource） |
| url | String | 否 | URL 编码（NET 类型使用，过滤 requestId） |
| viewNameCode | String | 否 | 视图名称编码 |
| parentViewName | String | 否 | 父视图名称 |
| viewType | String | 否 | 视图类型（1-Activity 等主视图, 其他-Fragment） |
| page | String | 否 | 页面过滤 |
| deviceID | String | 否 | 设备ID |
| fileId | String | 否 | 快照文件ID（排除当前快照） |

### 3.3 FilterOption（过滤条件）

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| keyword | String | 是 | - | 查询字段名 |
| operator | FilterTypeEnum | 否 | in | 查询操作类型 |
| value | Object | 是 | - | 查询值 |
| orFilterOptions | List\<FilterOption\> | 否 | null | OR 子条件 |
| andFilterOptions | List\<FilterOption\> | 否 | null | AND 子条件 |

**FilterTypeEnum 枚举值**：

| 枚举值 | SQL表达式 | 说明 |
|--------|----------|------|
| equal | = | 等于 |
| notEqual | <> | 不等于 |
| greater | > | 大于 |
| greaterEqual | >= | 大于等于 |
| less | < | 小于 |
| lessEqual | <= | 小于等于 |
| between | BETWEEN | 介于 |
| notBetween | NOT BETWEEN | 不介于 |
| contain | LIKE '%x%' | 包含 |
| notContain | NOT LIKE '%x%' | 不包含 |
| start | LIKE 'x%' | 起始于 |
| end | LIKE '%x' | 结束于 |
| in | IN | 在列表中 |
| empty | IS NULL | 为空 |
| notEmpty | IS NOT NULL | 不为空 |

### 3.4 请求示例

```json
{
  "startTime": 1711584000000,
  "endTime": 1711670400000,
  "appId": 123,
  "pageNo": 1,
  "pageSize": 10,
  "sortField": "monitorTime",
  "sortOrder": "desc",
  "queryJson": {
    "problemType": 6,
    "platform": "android"
  },
  "filters": [
    {
      "keyword": "appVersion",
      "operator": "equal",
      "value": "1.0.0"
    }
  ]
}
```

---

## 4. Controller 层处理

### 4.1 产品 UI 入口（RetrievalController）

```java
@PostMapping("/retrieve-center/record-list")
@OperatePermissionCheck(value = {RUM_RESOURCE_READ, RUM_RESOURCE_READ_AND_WRITE})
@OtherFilter
public RestResponse<RetrievePageEsp> recordList(@Valid @RequestBody RumBaseCondition condition) {
    return retrievalService.getRecordList(condition);
}
```

处理步骤：
1. Spring 自动校验 `@Valid` 注解的请求参数
2. `@OperatePermissionCheck` 拦截器验证功能权限
3. `@OtherFilter` 拦截器执行列表页签特殊过滤
4. 直接委托给 `RetrievalService.getRecordList(condition)`

### 4.2 Common API 入口（RumApiController）

```java
@IamRestrictApi
@PostMapping("/retrieve-center/record-list")
public RestResponse<RetrievePageEsp> recordList(@Valid @RequestBody RumBaseCondition condition, HttpServletRequest req) {
    condition.setIsFromApi(true);
    return retrievalService.getRecordList(condition);
}
```

处理步骤：
1. `@IamRestrictApi` 校验 IAM 权限
2. 设置 `condition.setIsFromApi(true)` 标记为 API 来源
3. 委托给 `RetrievalService.getRecordList(condition)`

---

## 5. Service 层逻辑

### 5.1 主方法 RetrievalService.getRecordList()

总体流程：

```
getRecordList(condition)
├── 1. decorateFilters(condition)                    // 过滤条件预处理
├── 2. 获取 problemType                              // 从 queryJson 中取出
├── 3. 构建 MetricQueryCondition（count 和 list）      // 初始化两套查询条件
├── 4. 根据来源设置 envId、accountId、language         // API/非API 分支
├── 5. 根据 problemType 设置 pageType                 // H5/JS_ERROR/VIEW 特殊处理
├── 6. rumSqlFilterFactory.getSqlFilter() (count)    // 构建 count 查询条件
├── 7. rumSnapshotMapper.queryCountOfRetrievalCenter()// 查询总记录数
├── 8. rumSqlFilterFactory.getSqlFilter() (list)     // 构建 list 查询条件
├── 9. 设置分页和排序参数                               // limit/offset/sort
├── 10. queryProblemDataList()                        // 查询数据列表
├── 11. 组装 RetrievePageEsp 分页响应                   // 封装结果
├── 12. 如果是 API 来源，执行 decorateData4Alert()      // Alert 格式适配
└── 13. 返回 RestResponse.success(pageRsp)
```

### 5.2 步骤详解

#### 5.2.1 decorateFilters(condition) - 过滤条件预处理

遍历 `condition.getFilters()` 中的每一个 `FilterOption`，进行如下转换：

| 条件 | 处理逻辑 |
|------|---------|
| keyword 为 `requestErrorRate` | 将 value 除以 100（百分比转小数），支持 String 和 List 类型 |
| keyword 为 `APP_ALIAS_VERSION`（应用别名版本） | keyword 替换为 `SQL_APP_VERSION`，并设 `appAliasVersionFlag = true` |
| keyword 为 `OTHER_INDEX_TRACE_ID`（traceId） | 调用 `FilterUtil.splitOrAddAndChildren(filter)` 拆分为 OR 子条件 |
| 其他 | 调用 `FilterUtil.splitAndAddAndChildren(filter)` 拆分为 AND 子条件 |

#### 5.2.2 获取 problemType 与初始化查询条件

```java
Integer problemType = Convert.toInt(condition.getQueryJson().get("problemType"));
```

分别为 **count 查询** 和 **list 查询** 创建两个 `MetricQueryCondition` 对象，设置：
- `table`：通过 `SnapshotTableEnum.getTableByProblemType(problemType)` 获取
- `isFromOpenApi`：继承 `condition.getIsFromApi()`
- `problemType`：设置数据类型

#### 5.2.3 来源分支处理

| 来源 | envId | accountId | language |
|------|-------|-----------|----------|
| 产品 UI（isFromApi = false） | `ResourceUtil.getEnvId(userProvider)` 自动获取 | `userProvider.getAccountId()` 自动获取 | `I18nUtil.INSTANCE.getLocale()` |
| API（isFromApi = true） | 使用 condition 中传入的值 | 使用 condition 中传入的值 | `condition.getLanguage()` |

> **设计说明**：API 来源不限制环境及资源域，允许调用方自行传入 `envId` 和 `accountId`。

#### 5.2.4 根据 problemType 设置 pageType

| problemType | 枚举 | pageType 列表 | 说明 |
|-------------|------|--------------|------|
| 2 | H5_SNAPSHOT | [1] | 仅 H5 页面 |
| 3 | JS_ERROR_SNAPSHOT | [1, 10, 11] | H5、小程序、路由 |
| 9 | VIEW_SNAPSHOT | [2,3,4,5,6,7,8,9] | Activity/Fragment/Windows/Controller/RN/Flutter/Ability/AbilitySlice |
| 其他 | - | 不设置 | 不限制 pageType |

#### 5.2.5 构建 SQL 过滤条件

通过 `rumSqlFilterFactory.getSqlFilter()` 将 `FilterOption` 列表转换为 SQL WHERE 子句所需的 `MetricQueryCondition`。

入参组装流程：
1. 深拷贝 `condition.getFilters()` 避免互相影响
2. 调用 `SnapshotBuildCondition.buildCondition(filterOptions, condition)` 将 `queryJson` 中的特殊参数转换为 `FilterOption` 并追加到列表
3. 调用 `rumSqlFilterFactory.getSqlFilter()` 生成最终的 `MetricQueryCondition`（包含 `whereFilterList`、`envId`、`accountId`、时间范围等）

**SnapshotBuildCondition.buildCondition() 的特殊条件构建**：

| queryJson 字段 | 生成的过滤条件 |
|---------------|--------------|
| problemId + problemGroup="page" | `otherIndex['pageName'] = {problemId}` |
| problemId + problemGroup="file" | `otherIndex['jsFile'] = {problemId}` |
| problemId + problemGroup="info" | `otherIndex['codeErrorId'] = {problemId}` |
| problemId（无 problemGroup） | `otherIndex['codeErrorId'] = {problemId}` |
| actionCode | `otherIndex['actionId'] = {actionCode}` |
| actionType | `otherIndex['actionType'] = {actionType}` |
| viewCode | `otherIndex['pageId'] = {viewCode}` |
| actionSnapshotId | `parentId = {actionSnapshotId}` |
| healthyType（非 HEALTHY） | `otherIndex['actionHealthyStatus'] = {code}` |
| appId != -1 | `appId = {appId}` |
| appIds 非空 | `appId IN {appIds}` |
| domain | `domain = {domain}` |
| reqType（NET） | `otherIndex['requestType'] = {reqType}` |
| dataType（NET） | `otherIndex['requestSource'] = {dataType}` |
| url（NET） | `otherIndex['requestId'] = {url}` |
| viewNameCode | `otherIndex['pageId'] = {viewNameCode}` |
| parentViewName | `otherIndex['onPageName'] = {parentViewName}` |
| viewType=1 | `pageType IN [1,2,4,5,6,7,8,10]` |
| viewType≠1 | `pageType IN [3,9]` |
| page | `page = {page}` |
| deviceID | `deviceId = {deviceID}` |
| fileId | `id != {fileId}` |

#### 5.2.6 查询总记录数

```java
Long totalCount = rumSnapshotMapper.queryCountOfRetrievalCenter(metricQueryConditionCount);
```

对应的 SQL（MyBatis XML）：

```sql
SELECT count(*) as count
FROM ${table} snap
<commonWhereClause/>
```

> `${table}` 由 `SnapshotTableEnum` 根据 `problemType` 动态决定。

#### 5.2.7 设置分页与排序

```java
metricQueryConditionList.setLimit((condition.getPageNo() - 1) * condition.getPageSize());
metricQueryConditionList.setOffset(condition.getPageSize());
metricQueryConditionList.setSortField(condition.getSortField());
metricQueryConditionList.setSortOrder(condition.getSortOrder());
```

> 注意：`limit` 对应 SQL 中的 **OFFSET** 偏移量，`offset` 对应 **LIMIT** 取回条数（变量命名与 SQL 语义相反，实际 SQL 为 `LIMIT #{limit}, #{offset}`）。

#### 5.2.8 queryProblemDataList() - 查询数据列表

```
queryProblemDataList(condition, metricQueryConditionList, language)
├── repository.queryProblemDataList()
│   ├── SnapshotTableEnum.getEnumByProblemType(problemType)
│   │   └── .querySnapshotData(rumSnapshotMapper, metricQueryCondition)  // 策略模式
│   └── formatSnapshotData()                                            // 格式化结果集
└── 城市名称回填 (cmdbSdkUtils.getCityCache)
```

#### 5.2.9 decorateData4Alert() - API 来源数据适配

仅在 `condition.getIsFromApi() == true` 时执行，对结果列表进行老格式适配，供告警模块使用：

| problemType | 处理内容 |
|-------------|---------|
| 1（NET） | 添加 `totalTime`（loadTime/1000）、`problemType`、`tcpTime`、`dnsTime`、`sslTime`、`downloadTime`、`errorMsg`、`urlCode` |
| 2（H5） | 添加 `totalTime`（loadTime/1000）、`interactiveTime`（domInteractive/1000）、`requestTime` |
| 通用 | 设置 `appVerName`、`fileId`、`pageName`；将处理后的 `otherIndex` 设置为 `metricInfo` |

---

## 6. 数据查询（Repository 层）

### 6.1 快照表策略路由

通过 `SnapshotTableEnum` 枚举的策略模式，根据 `problemType` 路由到不同的快照表和 SQL：

| problemType | 枚举 | ClickHouse 表名 | Mapper 方法 |
|-------------|------|----------------|-------------|
| 1 | NET_SNAPSHOT | `one_rum_datasource_snapshot.t_rum_net_snapshot_view` | `queryDataOfRetrievalCenterByNet` |
| 2 | H5_SNAPSHOT | `one_rum_datasource_snapshot.t_rum_h5_snapshot_view` | `queryDataOfRetrievalCenterByPage` |
| 3 | JS_ERROR_SNAPSHOT | `one_rum_datasource_snapshot.t_rum_jserror_snapshot_view` | `queryDataOfRetrievalCenterByJsError` |
| 4 | ANR_SNAPSHOT | `one_rum_datasource_snapshot.t_rum_anr_snapshot_view` | `queryDataOfRetrievalCenterByAnr` |
| 5 | LAG_SNAPSHOT | `one_rum_datasource_snapshot.t_rum_lag_snapshot_view` | `queryDataOfRetrievalCenterByLag` |
| 6 | CRASH_SNAPSHOT | `one_rum_datasource_snapshot.t_rum_crash_snapshot_view` | `queryDataOfRetrievalCenterByCrash` |
| 7 | SELF_CRASH_SNAPSHOT | `one_rum_datasource_snapshot.t_rum_selfcrash_snapshot_view` | `queryDataOfRetrievalCenterBySelfCrash` |
| 8 | LAUNCH_SNAPSHOT | `one_rum_datasource_snapshot.t_rum_launch_snapshot_view` | `queryDataOfRetrievalCenterByAppLaunch` |
| 9 | VIEW_SNAPSHOT | `one_rum_datasource_snapshot.t_rum_view_snapshot_view` | `queryDataOfRetrievalCenterByViewLaunch` |
| 10 | ACTION_SNAPSHOT | `one_rum_datasource_snapshot.t_rum_action_snapshot_view` | `queryDataOfRetrievalCenterByAction` |
| 11 | CUSTOM_EVENT_SNAPSHOT | `one_rum_datasource_snapshot.t_rum_customevent_snapshot_view` | `queryDataOfRetrievalCenterByCustomEvent` |

### 6.2 SQL 结构（以 CRASH 为例）

所有查询 SQL 采用 **CTE（WITH 子句）** 结构，分两层查询：

**第一层**：从快照表查询基础数据

```sql
WITH snap AS (
  SELECT snap.id,
    snap.name, snap.nameCode, snap.type, snap.configTime,
    toUnixTimestamp64Milli(snap."monitor_time") monitorTime,
    snap.appType, snap.moduleName, snap.subModuleName,
    snap.appId, snap.appVersion, snap.channel,
    snap.accessModelId, snap.netserviceId, snap.cityId,
    snap.clientOsName, snap.clientDeviceName, snap.deviceId,
    snap.clientIp, snap.customOsName, snap.sessionId,
    snap.actionId, snap.parentId, snap.sdkVersion,
    snap.memberId, snap.memberType, snap.userGroupId,
    snap.sessionFlag, snap.dataCenterId,
    toJSONString(snap.otherIndex) otherIndex
  FROM one_rum_datasource_snapshot.t_rum_crash_snapshot_view snap
  <commonWhereClause/>
  ORDER BY ${sortField} ${sortOrder}  -- 或默认 ORDER BY monitorTime desc
  LIMIT #{limit}, #{offset}
)
```

**第二层**：LEFT JOIN 实体表补充别名信息

```sql
SELECT snap.*,
  ea.customizedName appName,
  eug.customizedName userGroupName,
  ifnull(eu.customizedName, snap.memberId) userName
FROM snap
LEFT JOIN entity.app ea ON snap.appId = CAST(ea.instanceId AS VARCHAR)
  AND ea.envId = #{envId} AND ea.accountId = #{accountId}
LEFT JOIN entity.user eu ON snap.memberId = CAST(eu.detectedName AS VARCHAR)
  AND eu.envId = #{envId} AND eu.accountId = #{accountId}
LEFT JOIN entity.usergroup eug ON snap.userGroupId = CAST(eug.instanceId AS VARCHAR)
  AND eug.envId = #{envId} AND eug.accountId = #{accountId}
ORDER BY ${sortField} ${sortOrder}
```

### 6.3 各类型 SQL 的差异

| problemType | 额外查询字段 | 额外 JOIN |
|-------------|------------|-----------|
| NET(1) | `url`(name→url), `nameCode`(→requestId), `snapshotFileStr`, `loadTime` | `entity.request rq`（请求别名） |
| H5(2) | `name`(→pageName), `nameCode`(→pageId), `snapshotFileStr` | `entity.page ev`（页面别名） |
| JS_ERROR(3) | `pageId`, `pageName`（从 otherIndex 回退取值） | `entity.page ev` |
| ACTION(10) | `actionName`(name→), `nameCode`(→actionId), `pageName`, `pageId` | `entity.action eac`, `entity.page view` |
| VIEW(9) | `name`(→pageName), `nameCode`(→pageId) | `entity.page ev` |
| CRASH(6)/ANR(4)/LAG(5)/SELF_CRASH(7)/LAUNCH(8)/CUSTOM_EVENT(11) | 标准字段 | 无额外 JOIN |

> **注意**：部分类型的 `name`、`nameCode` 字段使用 `IF` 函数做兼容处理，优先使用快照表的 `name`/`nameCode`，为空时回退到 `otherIndex` 中的对应字段。

---

## 7. 数据处理（formatSnapshotData）

### 7.1 基础字段映射

`RetrievalRepository.formatSnapshotData()` 将查询结果的 `Map<String, Object>` 转换为 `ProblemResult` 对象：

| ProblemResult 字段 | 数据来源 | 说明 |
|-------------------|---------|------|
| id | prepare.get("id") | 快照ID |
| monitorTime | prepare.get("monitorTime") | 监控时间戳 |
| appId | prepare.get("appId") | 应用ID |
| appName | AppCache 缓存（优先别名） | 应用名称/别名 |
| appVersion | prepare.get("appVersion") | 应用版本 |
| sdkVersion | prepare.get("sdkVersion") | SDK版本 |
| sessionId | prepare.get("sessionId") | 会话ID |
| cityId / cityName | prepare + CmdbSdkUtils | 城市ID及名称（国际化） |
| netServiceId / netServiceName | prepare + CmdbSdkUtils | 运营商ID及名称（国际化） |
| accessModelId / accessModelName | prepare + CmdbSdkUtils | 接入方式ID及名称（国际化） |
| dataCenter | CmdbSdkUtils.getDictValue | 数据中心 |
| clientOsName | prepare.get("clientOsName") | 操作系统 |
| deviceId | prepare.get("deviceId") | 设备ID |
| clientIp | prepare.get("clientIp") | 客户端IP |
| memberId | prepare.get("memberId") | 用户ID |
| appType | prepare.get("appType") | 应用类型 |
| otherIndex | JSON 解析 prepare.get("otherIndex") | 附加指标信息 |
| channel | prepare.get("channel") | 下载渠道 |
| moduleName / subModuleName | prepare | 模块/子模块名 |
| clientDeviceName | prepare | 设备名称 |
| userName | prepare.get("userName") | 用户名称（entity JOIN 结果） |
| userGroupName | prepare.get("userGroupName") | 用户组名称 |
| name | prepare.get("name") | 摘要/事件名称 |
| pageName / pageCustomName / pageAlias | prepare | 页面名称/别名 |
| requestAlias | prepare | 请求地址别名 |
| type | prepare.get("type") | 类型 |
| actionId / actionAlias / actionName | prepare | 操作信息 |
| sessionFlag | prepare | 会话标识 |
| parentId | prepare | 父ID |
| nameCode | prepare | 名称编码 |
| snapshotFile | JSON 解析 prepare.get("snapshotFileStr") | 快照文件内容 |
| appAliasVersion | 拼接 appName + "(" + appVersion + ")" | 应用别名版本 |
| memberName | 如果 userName 非空则使用 userName | 用户显示名 |
| hasDetail | queryJson 中包含 "platform" 则为 true | 是否有详情 |

### 7.2 自定义数据格式化（customDataFormat）

根据 `problemType` 执行不同的格式化逻辑：

| problemType | 方法 | 处理内容 |
|-------------|------|---------|
| 1（NET） | `formatNetwork()` | 查询 URL 别名（`AliasEnum.URL`），设置 `requestAlias`；旧版快照（无 snapshotVersion）添加 `url`、`requestTime`、`requestMethod` |
| 2（H5） | `formatH5work()` | 查询 H5 页面别名（`AliasEnum.H5`） |
| 8（LAUNCH）/ 9（VIEW） | `formatView()` | 查询视图别名（`AliasEnum.VIEW`），设置 `viewName` |
| 10（ACTION） | `formatAction()` | 请求错误率乘100转百分比；旧版快照 `loadTime` 除以 1000 |
| 3（JS_ERROR）/ 4（ANR）/ 5（LAG）/ 6（CRASH）/ 7（SELF_CRASH） | `formatError()` | 旧版快照设置 `codeErrorId`（来自 nameCode）、`eventInfo`（来自 name） |
| 5（LAG） | `formatLag()`（额外） | 旧版快照设置 `lagType`（来自 type） |

### 7.3 城市名称回填

在 `RetrievalService.queryProblemDataList()` 中，对 Repository 返回的结果列表二次处理：

```java
resultList.forEach(result -> {
    RumCityNameEntity cityCacheEntity = cmdbSdkUtils.getCityCache(result.getCityId(), languageType);
    String cityName = CityUtil.getDistrictCityName(cityCacheEntity, languageType);
    result.setCityName(cityName);
});
```

使用 `CityUtil.getDistrictCityName()` 获取包含区县级别的城市名称，覆盖 Repository 层设置的简单城市名。

---

## 8. 响应结果

### 8.1 外层响应 RestResponse\<RetrievePageEsp\>

| 字段 | 类型 | 说明 |
|------|------|------|
| code | String | 状态码，成功为 "200" |
| msg | String | 消息 |
| data | RetrievePageEsp\<ProblemResult\> | 分页数据 |

### 8.2 RetrievePageEsp（分页信息）

继承自 `BasePageRsp`，增加 `sessionExpireTime` 字段。

| 字段 | 类型 | 说明 |
|------|------|------|
| totalRecord | long | 总记录数 |
| pageNo | int | 当前页码 |
| pageSize | int | 每页条数 |
| results | List\<ProblemResult\> | 数据列表 |
| sessionExpireTime | int | 会话过期时间（来自 `RUMConfig.expireTime`） |

### 8.3 ProblemResult（记录详情）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String | 快照ID |
| appId | Long | 应用ID |
| appName | String | 应用名称/别名 |
| monitorTime | Long | 监控时间（毫秒时间戳） |
| appVersion | String | 应用版本 |
| name | String | 崩溃/卡顿/ANR/自定义摘要 |
| sdkVersion | String | SDK版本 |
| sessionId | String | 会话ID |
| cityId | Integer | 城市ID |
| cityName | String | 城市名称 |
| netServiceId | Integer | 运营商ID |
| netServiceName | String | 运营商名称 |
| accessModelId | Integer | 接入方式ID |
| accessModelName | String | 接入方式名称 |
| clientIp | String | 客户端IP |
| deviceId | String | 设备ID |
| memberId | String | 客户用户ID |
| clientOsName | String | 操作系统 |
| appType | Integer | 应用类型 |
| otherIndex | Map\<String, Object\> | 附加指标信息（包含 snapshotVersion、codeErrorId、eventInfo 等） |
| memberName | String | 客户用户别名 |
| hasDetail | boolean | 是否有详情 |
| channel | String | 下载渠道 |
| moduleName | String | 模块名称 |
| subModuleName | String | 子模块名称 |
| clientDeviceName | String | 设备名称 |
| userName | String | 用户名称 |
| userGroupName | String | 用户组名称 |
| requestAlias | String | 请求地址别名 |
| pageName | String | 页面名称 |
| pageAlias | String | 页面别名 |
| pageCustomName | String | 页面自定义名称 |
| type | String | 类型标识 |
| actionId | String | 操作记录ID |
| actionAlias | String | 操作别名 |
| actionName | String | 操作名称 |
| sessionFlag | Integer | 会话标识 |
| parentId | String | 父ID |
| nameCode | String | 名称编码 |
| snapshotFile | Map\<String, Object\> | 快照文件内容 |
| appAliasVersion | String | 应用别名(版本) |
| dataCenter | String | 数据中心 |
| urlCode | String | 请求编码（API 来源, NET 类型） |

#### ProblemResult4Alert 继承字段（API 来源时填充）

| 字段 | 类型 | 说明 |
|------|------|------|
| fileId | String | 文件ID |
| metricInfo | Map\<String, Object\> | 指标信息（API 来源时由 otherIndex 处理后设置） |
| appVerName | String | 应用版本名 |
| appAliasVersion | String | 应用别名及版本 |

### 8.4 响应示例

```json
{
  "code": "200",
  "msg": "success",
  "data": {
    "totalRecord": 150,
    "pageNo": 1,
    "pageSize": 10,
    "sessionExpireTime": 14,
    "results": [
      {
        "id": "abc123",
        "appId": 100,
        "appName": "示例应用",
        "monitorTime": 1711660800000,
        "appVersion": "1.0.0",
        "name": "java.lang.NullPointerException",
        "sdkVersion": "3.5.0",
        "sessionId": "sess_001",
        "cityId": 110100,
        "cityName": "北京市",
        "netServiceId": 1,
        "netServiceName": "中国移动",
        "accessModelId": 1,
        "accessModelName": "WiFi",
        "clientIp": "192.168.1.1",
        "deviceId": "device_001",
        "memberId": "user_001",
        "clientOsName": "Android 12",
        "appType": 1,
        "otherIndex": {
          "codeErrorId": "err_001",
          "eventInfo": "NullPointerException at ...",
          "snapshotVersion": 1,
          "crashType": "1"
        },
        "hasDetail": true,
        "channel": "default",
        "moduleName": "main",
        "clientDeviceName": "Pixel 6",
        "userName": "张三",
        "appAliasVersion": "示例应用(1.0.0)",
        "dataCenter": "华北"
      }
    ]
  }
}
```

---

## 9. 异常处理

| 场景 | 处理方式 |
|------|---------|
| `problemType` 未传或为空 | `SnapshotBuildCondition.buildCondition()` 抛出 `IllegalArgumentException` |
| 请求参数校验失败（`@Valid`） | Spring 返回 400 Bad Request |
| 权限校验失败 | `@OperatePermissionCheck` 拦截返回 403 |
| 数据库查询异常 | 异常上抛，由全局异常处理器处理 |
| otherIndex JSON 解析失败 | `convertMap()` 中 catch 异常，返回空 Map，日志记录 `druid map data convert failed` |

---

## 10. 关键配置项

| 配置类 | 配置项 | 说明 |
|--------|--------|------|
| `RUMConfig` | `expireTime` | 会话/快照过期天数，写入响应的 `sessionExpireTime` |
| `RUMConfig` | `maxUrlLength` | URL 最大长度（快照详情使用） |

---

## 11. 核心流程图

```
┌─────────────────────┐
│   前端发起 POST 请求   │
│ /retrieve-center/    │
│ record-list          │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│  @OperatePermission  │──── 权限不足 ──→ 403
│  @OtherFilter        │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│ RetrievalService     │
│ .getRecordList()     │
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│ decorateFilters()    │ requestErrorRate÷100
│                      │ APP_ALIAS_VERSION→SQL
│                      │ traceId→OR拆分
│                      │ 其他→AND拆分
└─────────┬───────────┘
          │
          ▼
┌─────────────────────┐
│ 获取 problemType     │
│ 确定快照表           │ SnapshotTableEnum
│ 设置 pageType        │
└─────────┬───────────┘
          │
          ├──────────────────────┐
          ▼                      ▼
┌──────────────────┐   ┌──────────────────┐
│ 构建 count 条件    │   │ 构建 list 条件    │
│ getSqlFilter()   │   │ getSqlFilter()   │
└────────┬─────────┘   │ + limit/offset   │
         │             │ + sort           │
         ▼             └────────┬─────────┘
┌──────────────────┐           │
│ queryCount       │           ▼
│ OfRetrieval      │  ┌──────────────────┐
│ Center()         │  │ SnapshotTableEnum│
│  → totalCount    │  │ .querySnapshot   │
└──────────────────┘  │ Data()           │
                      │ (策略路由到对应SQL) │
                      └────────┬─────────┘
                               │
                               ▼
                      ┌──────────────────┐
                      │ formatSnapshot   │
                      │ Data()           │
                      │ Map→ProblemResult│
                      │ + 缓存回填        │
                      │ + 别名查询        │
                      └────────┬─────────┘
                               │
                               ▼
                      ┌──────────────────┐
                      │ customDataFormat │
                      │ 按 problemType   │
                      │ 格式化           │
                      └────────┬─────────┘
                               │
                               ▼
                      ┌──────────────────┐
                      │ 城市名称回填       │
                      │ (Service层)       │
                      └────────┬─────────┘
                               │
                               ▼
                      ┌──────────────────┐
                      │ 组装              │
                      │ RetrievePageEsp  │
                      │ + decorateData   │
                      │   4Alert (API)   │
                      └────────┬─────────┘
                               │
                               ▼
                      ┌──────────────────┐
                      │ RestResponse     │
                      │ .success(pageRsp)│
                      └──────────────────┘
```

---

## 12. 前端调用

### 12.1 通用服务（common.ts）

```typescript
// 检索中心-记录列表
getRecordList(options: BrRecord) {
  return request.post<RUM_experienceuser.ServeList>(
    '/rest/rum/retrieve-center/record-list',
    options,
    options.isDownload ? { responseType: 'blob' } : {},
  )
},
```

路径：`newonexm/view/rum/src/services/common.ts`

### 12.2 其他前端调用入口

| 文件路径 | 方法名 | 说明 |
|---------|--------|------|
| `newonexm/view/rum/src/services/retrieval/breakdown/index.ts` | `getRecord` | 检索中心细分页 |
| `newonexm/view/rum/src/services/experience/request.ts` | `getQuestionList` | 数字体验-问题列表 |
| `newonexm/view/rum/src/services/experience/application/index.ts` | `getOperateDetailsList` | 应用-操作详情列表 |

### 12.3 前端页面组件

| 文件路径 | 说明 |
|---------|------|
| `newonexm/view/rum/src/packages/retrieval/application/view/recordList/index.tsx` | 检索中心记录列表主页面，入口组件 `RetrievalAppViewPageRecordList` |

---

## 13. 涉及文件清单

| 文件路径 | 说明 |
|---------|------|
| `newonexm/framework/plugins/rum/rum-core/.../retrieval/controller/RetrievalController.java` | 产品 UI 入口 Controller |
| `newonexm/framework/plugins/rum/rum-core/.../common/controller/RumApiController.java` | Common API 入口 Controller |
| `newonexm/framework/plugins/rum/rum-core/.../retrieval/service/RetrievalService.java` | Service 层核心逻辑 |
| `newonexm/framework/plugins/rum/rum-core/.../retrieval/druid/RetrievalRepository.java` | Repository 层，数据查询与格式化 |
| `newonexm/framework/plugins/rum/rum-common/.../bean/condition/RumBaseCondition.java` | 请求参数模型 |
| `newonexm/framework/plugins/rum/rum-common/.../bean/condition/MetricQueryCondition.java` | SQL 查询条件模型 |
| `newonexm/framework/plugins/rum/rum-common/.../bean/filters/FilterOption.java` | 过滤条件模型 |
| `newonexm/framework/plugins/rum/rum-common/.../bean/filters/enums/FilterTypeEnum.java` | 过滤操作符枚举 |
| `newonexm/framework/plugins/rum/rum-common/.../query/SnapshotBuildCondition.java` | 快照查询条件构建器 |
| `newonexm/framework/plugins/rum/rum-common/.../bean/BasePageRsp.java` | 基础分页响应模型 |
| `newonexm/framework/plugins/rum/rum-core/.../common/bean/RetrievePageEsp.java` | 扩展分页响应模型（含 sessionExpireTime） |
| `newonexm/framework/plugins/rum/rum-core/.../retrieval/model/ProblemResult.java` | 记录结果模型 |
| `newonexm/framework/plugins/rum/rum-core/.../retrieval/model/ProblemResult4Alert.java` | 告警适配基类模型 |
| `newonexm/framework/plugins/rum/rum-database/.../enums/SnapshotTableEnum.java` | 快照表枚举（策略路由） |
| `newonexm/framework/plugins/rum/rum-database/.../query/RumSnapshotMapper.java` | MyBatis Mapper 接口 |
| `newonexm/framework/plugins/rum/rum-database/.../query/xml/RumSnapshotMapper.xml` | MyBatis SQL 映射（11 种快照查询 + count） |
| `newonexm/framework/plugins/rum/rum-core/.../annotation/OperatePermissionCheck.java` | 操作权限注解 |
| `newonexm/framework/plugins/rum/rum-core/.../annotation/OtherFilter.java` | 列表特殊过滤注解 |
| `newonexm/framework/plugins/rum/rum-core/.../permission/FuncPermissionConstant.java` | 权限常量定义 |
| `newonexm/framework/plugins/rum/rum-core/.../common/factroy/RumSqlFilterFactory.java` | SQL 过滤条件工厂 |
| `newonexm/framework/plugins/rum/rum-core/.../common/service/DownloadFilter.java` | 下载过滤器（注册 recordList 场景的自定义导出处理） |
| `newonexm/framework/plugins/rum/rum-core/.../listener/InitService.java` | 网关 RPC 注册（注册 Common API 路径） |
| `newonexm/view/rum/src/services/common.ts` | 前端通用服务（getRecordList） |
| `newonexm/view/rum/src/packages/retrieval/application/view/recordList/index.tsx` | 前端记录列表页面组件 |

---

## 14. 前端对 otherIndex 与 snapshotFile 字段的引用

### 14.1 数据展平机制（getCompatibleNewVersionsData）

前端在接收到 `record-list` 接口响应后，会通过 `getCompatibleNewVersionsData()` 函数将嵌套数据展平到单行对象上，供表格列直接通过 `dataIndex` 访问。

**核心逻辑**（`newonexm/view/rum/src/utils/compatibleNewVerData.ts`）：

```typescript
const otherInfo = {
  ...item,                          // 顶层字段（appId, monitorTime, sessionId 等）
  ...item?.metricInfo,              // API 来源的 metricInfo
  ...item?.snapshotFile?.baseInfo,  // 快照文件 - 基础信息
  ...item?.snapshotFile?.deviceInfo,// 快照文件 - 设备信息
  ...item?.snapshotFile?.metricInfo,// 快照文件 - 指标信息
  ...item?.otherIndex,              // 附加指标信息（最高优先级覆盖）
}
```

> **覆盖优先级**：`otherIndex` > `snapshotFile.metricInfo` > `snapshotFile.deviceInfo` > `snapshotFile.baseInfo` > `metricInfo` > 顶层字段。新版快照（`snapshotVersion` 存在）走此路径，旧版快照直接使用 `baseInfo`/`deviceInfo`/`metricInfo`。

**调用位置**：

| 文件 | 第二参数 | 场景 |
|------|---------|------|
| `retrieval/application/view/recordList/index.tsx` | `'page'` | 检索中心-应用启动/视图启动/页面加载 |
| `retrieval/application/view/detail/pageDetail/.../record/index.tsx`（新/旧） | `'page'` | 页面详情-记录 Tab |
| `retrieval/netRequest/models/index.ts` | `'request'` | 检索中心-网络请求 |
| `retrieval/userOperateList/models/index.ts` | `'operate'` | 检索中心-用户操作 |
| `retrieval/breakdown/CrashRecord/index.tsx` | 无 | 崩溃记录列表 |
| `retrieval/breakdown/AnrRecord/index.tsx` | 无 | ANR 记录列表 |
| `retrieval/breakdown/CatonRecord/index.tsx` | 无 | 卡顿记录列表 |
| `retrieval/breakdown/JSRecord/index.tsx` | 无 | JS 错误记录列表 |
| `retrieval/breakdown/CustomExceptionRecord/index.tsx` | 无 | 自定义异常记录列表 |
| `experience/request/models/domain.ts` | `'request'` | 数字体验-请求域名 |
| `experience/application/viewDetails/models/activity.ts` | - | 数字体验-视图详情 |
| `experience/application/pageDetails/index.tsx` | `'page'` | 数字体验-页面详情 |
| `experience/application/operateDetails/models/operate.ts` | `'operate'` | 数字体验-操作详情 |

> 以上文件均位于 `newonexm/view/rum/src/packages/` 目录下。

### 14.2 otherIndex 字段引用汇总

以下列出前端代码中**明确访问**的 `otherIndex` 子字段，按使用场景分类：

#### 14.2.1 列表表格列（通过展平后作为 dataIndex 使用）

**崩溃/ANR/卡顿/JS 错误/自定义异常记录列表**（`useColumns.tsx`）：

| dataIndex（展平后字段名） | 来源 | 说明 | 适用 problemType |
|--------------------------|------|------|-----------------|
| `codeErrorId` | `otherIndex.codeErrorId` | 代码异常ID（新版） | 3,4,5,6,7 |
| `eventInfo` | `otherIndex.eventInfo` | 问题摘要/事件信息（新版） | 3,4,5,6,7 |
| `questionId` | `otherIndex.questionId` | 问题ID（旧版） | 3,4,5,6,7 |
| `summary` | `otherIndex.summary` | 摘要（旧版） | 3,4,5,6,7 |
| `crashType` | `otherIndex.crashType` | 崩溃类型（1-Native,2-Java,3-WatchDog,4-Hybrid,6-ArkTS） | 6 |
| `crashSource` | `otherIndex.crashSource` | 崩溃来源（1-系统,2-应用,3-我的） | 6 |
| `lagType` | `otherIndex.lagType` | 卡顿类型（0-主线程,1-FPS流畅度） | 5 |
| `widgetType` | `otherIndex.widgetType` | 部件类型（0-应用,1-组件） | 6 |
| `firstCrash` | `otherIndex.firstCrash` | 是否首次崩溃 | 6 |
| `isShielded` | `otherIndex.isShielded` | 是否屏蔽 | 6 |
| `jsErrorType` | `otherIndex.jsErrorType` | JS 错误类型 | 3 |
| `background` / `appGround` | `otherIndex.appGround` | 前台/后台 | 6,7 |
| `errorMsg` / `jsErrorInfo` | `otherIndex.jsErrorInfo` | JS 错误信息 | 3 |
| `jsFile` | `otherIndex.jsFile` | JS 文件名 | 3 |
| `page` | `otherIndex.page` | 页面 | 3 |
| `runTime` | `otherIndex.runTime` | 运行时长 | 6,4,5 |
| `browser` | `otherIndex.browser` | 浏览器 | 3 |
| `snapshotVersion` | `otherIndex.snapshotVersion` | 快照版本标识（区分新旧数据格式） | 通用 |

**应用启动/视图启动/页面加载记录列表**（`recordList/component/table/index.tsx`）：

| dataIndex（展平后字段名） | 来源 | 说明 | 适用 problemType |
|--------------------------|------|------|-----------------|
| `loadTime` | `otherIndex.loadTime` | 页面完全加载耗时 | 2,8,9 |
| `launchTime` | `otherIndex.launchTime` | 启动耗时 | 8 |
| `launchType` | `otherIndex.launchType` | 启动类型（1-冷启,2-热启,3-首次） | 8 |
| `viewName` | `otherIndex.viewName` | 视图名称 | 9 |
| `viewLaunchStatus` | `otherIndex.viewLaunchStatus` | 视图启动状态（1-正常,2-慢） | 9 |
| `appLaunchStatus` | `otherIndex.appLaunchStatus` | 应用启动状态（1-正常,2-慢） | 8 |
| `problemType` | `otherIndex.problemType` | H5 加载类型（0-正常,1-错误,2-整体慢,3-白屏慢,4-首屏慢,5-可交互慢） | 2 |
| `errorMsg` | `otherIndex.errorMsg` | 错误信息 | 2 |
| `fcp` | `otherIndex.fcp` | FCP 耗时 | 2 |
| `fp` | `otherIndex.fp` | FP 耗时 | 2 |
| `lcp` | `otherIndex.lcp` | LCP 耗时 | 2 |
| `domInteractive` | `otherIndex.domInteractive` | TTI 耗时 | 2 |
| `firstByteTime` | `otherIndex.firstByteTime` | TTFB 耗时 | 2 |
| `snapshotVersionTable` | `otherIndex.snapshotVersion` | 展平后重命名，用于表格中区分新旧版本的耗时单位转换 | 通用 |
| `parentRequestId` | `otherIndex.parentRequestId` | 父请求ID（视图跳转会话详情时使用） | 9 |

**网络请求记录列表**（NET 类型通过 `tableColmun.tsx`）：

| dataIndex（展平后字段名） | 来源 | 说明 |
|--------------------------|------|------|
| `url` | `otherIndex.url` / `otherIndex.name` | 请求 URL |
| `requestTime` | `otherIndex.requestTime` / `otherIndex.totalTime` | 请求耗时 |
| `requestStatus` | `otherIndex.requestStatus` | 请求状态（1-正常,2-慢,3-错误） |
| `requestMethod` | `otherIndex.requestMethod` / `otherIndex.method` | 请求方法 |
| `responseTime` | `otherIndex.responseTime` | 响应时间 |
| `loadTime` | `otherIndex.loadTime` | 加载耗时 |
| `traceId` | `otherIndex.traceId` | 链路追踪ID |
| `domain` | `otherIndex.domain` | 域名 |
| `requestId` | `otherIndex.requestId` | 请求编码 |

**用户操作记录列表**（ACTION 类型通过 `tableColmun.tsx`）：

| dataIndex（展平后字段名） | 来源 | 说明 |
|--------------------------|------|------|
| `actionHealthyStatus` | `otherIndex.actionHealthyStatus` | 操作健康状态（1-健康,2-慢,3-阻塞,5-错误,6-失败,7-崩溃） |
| `requestErrorRate` | `otherIndex.requestErrorRate` | 请求错误率 |
| `loadTime` | `otherIndex.loadTime` | 操作耗时 |
| `actionName` | `otherIndex.actionName` | 操作名称 |
| `actionType` | `otherIndex.actionType` | 操作类型 |
| `actionId` | `otherIndex.actionId` | 操作ID |

**自定义事件记录列表**（`customEvent/index.tsx`）：

| dataIndex（展平后字段名） | 来源 | 说明 |
|--------------------------|------|------|
| `eventName` | `otherIndex.eventName` | 事件名称 |
| `eventId` | `otherIndex.eventId` | 事件ID |
| `loadTime` | `otherIndex.loadTime` | 事件耗时 |
| `record?.otherIndex?.[item.columnFields]` | 动态字段 | 后端 `getHeader` 返回的自定义列字段名，动态从 `otherIndex` 取值 |

#### 14.2.2 详情页面直接访问

**崩溃详情**（`CrashDetail/index.tsx`）—— 其他类似详情页（AnrDetail、CatonDetail、JSDetail、CustomExceptionDetail）结构相同：

| 访问方式 | 取出的字段 | 说明 |
|---------|-----------|------|
| `res?.otherIndex?.snapshotVersion` | `snapshotVersion` | 判断新旧版本 |
| `...res?.otherIndex` | 整对象展开 | 所有字段展平到详情数据 |
| 展平后使用 `res.eventInfo` | `eventInfo` | 崩溃摘要 |
| 展平后使用 `res.status` | `status` | 问题状态 |
| 展平后使用 `res.operationalTrackList` | `operationalTrackList` | 操作轨迹列表 |
| 展平后使用 `res.userInfo` | `userInfo` | 自定义用户信息 |
| 展平后使用 `res.systemLog` | `systemLog` | 系统日志 |
| 展平后使用 `res.stackInfoList` | `stackInfoList` | 堆栈信息列表 |
| 展平后使用 `res.fileSize` | `fileSize` | 文件大小 |
| 展平后使用 `res.realAppName` | `realAppName` | 真实应用名（堆栈高亮） |
| 展平后使用 `res.questionId` / `res.codeErrorId` | `questionId` / `codeErrorId` | 问题ID |
| 展平后使用 `res.platform` / `res.appType` | `appType` | 应用类型 |

**自定义事件详情**（`customEventDetail/index.tsx`）：

| 访问方式 | 取出的字段 | 说明 |
|---------|-----------|------|
| `otherIndex?.eventName` | `eventName` | 事件名称 |
| `otherIndex?.eventId` | `eventId` | 事件记录ID |
| `otherIndex?.customEventTag` | `customEventTag` | 事件标签 |
| `otherIndex?.loadTime` | `loadTime` | 事件耗时 |
| `otherIndex?.customEventInfo` | `customEventInfo` | 事件附加信息 |

#### 14.2.3 过滤器字段映射（useAutoLinkFilter）

`useAutoLinkFilter.ts` 中实体映射转换，将前端实体属性名转为后端 `otherIndex` 过滤字段：

| 前端实体属性 | 转换后的 keyword | 说明 |
|-------------|-----------------|------|
| `action.detectedName` | `otherIndex['actionName']` | 操作名称 |
| `request.detectedName` | `otherIndex['url']` | 请求 URL |
| `page.detectedName` | `otherIndex['pageName']` | 页面名称 |
| `userExtraInfo` | `otherIndex['userInfo']` | 用户附加信息 |
| `customizedEventName` | `otherIndex['eventName']` | 自定义事件名称 |
| `customizedEventId` | `otherIndex['eventId']` | 自定义事件ID |

#### 14.2.4 过滤器操作符限制（BrFilter）

`BrFilter/index.tsx` 中针对 `otherIndex` 字段的特殊过滤规则：

| keyword | 限制的操作符 | 说明 |
|---------|------------|------|
| `otherIndex['pageName']` | equal, contain, start, end | 页面名称（仅正向查询） |
| `otherIndex['url']` | equal, contain, start, end | 请求 URL（仅正向查询） |
| `otherIndex['eventInfo']`（retrievalSummary 场景） | contain | 问题摘要（仅包含） |

### 14.3 snapshotFile 字段引用汇总

#### 14.3.1 一级子字段

前端对 `snapshotFile` 的访问固定为以下三个一级子字段，用于数据展平：

| 子字段 | 说明 | 引用位置 |
|--------|------|---------|
| `snapshotFile.baseInfo` | 基础信息（如会话、应用等基础属性） | `compatibleNewVerData.ts`、所有 Detail 页面、`sessionDetail` 相关组件 |
| `snapshotFile.deviceInfo` | 设备信息（如设备名称、操作系统等） | 同上 |
| `snapshotFile.metricInfo` | 指标信息（如各类耗时、状态指标等） | 同上 |
| `snapshotFile.stackInfoList` | 堆栈信息列表（自定义异常场景） | `sessionDetail/utils/eventTypeConfig.tsx`（取 `stackInfoList[0].dumInfo`） |

#### 14.3.2 展平后使用的 snapshotFile 内嵌字段

通过 `...snapshotFile.baseInfo`、`...snapshotFile.deviceInfo`、`...snapshotFile.metricInfo` 展平后，前端实际使用的字段包括（与 `otherIndex` 中同名字段存在覆盖关系）：

**baseInfo 中的常见字段**：

| 字段 | 说明 |
|------|------|
| `appId` | 应用ID |
| `appName` | 应用名称 |
| `appVersion` | 应用版本 |
| `sessionId` | 会话ID |
| `memberId` | 用户ID |
| `memberAlias` | 用户别名 |
| `deviceId` | 设备ID |
| `sessionExpireTime` | 会话过期时间 |
| `sessionFlag` | 会话标记 |
| `snapshotVersion` | 快照版本 |

**deviceInfo 中的常见字段**：

| 字段 | 说明 |
|------|------|
| `clientOsName` | 操作系统 |
| `clientDeviceName` | 设备名称 |
| `platform` / `appType` | 应用平台类型 |
| `sdkVersion` | SDK 版本 |
| `osName` | 操作系统名称 |
| `brandName` | 设备品牌 |

**metricInfo 中的常见字段**（因 problemType 不同而有差异）：

| 字段 | 说明 | 适用 problemType |
|------|------|-----------------|
| `stackInfoList` | 堆栈信息列表（含 `tid`、`name`、`dumInfo`） | 6,7,4,5 |
| `operationalTrackList` | 操作轨迹列表 | 6,7,4,5 |
| `systemLog` | 系统日志 | 6 |
| `fileSize` | 文件大小 | 6,7,4,5 |
| `realAppName` | 真实应用包名（堆栈高亮） | 6,7 |
| `userInfo` | 自定义用户信息 | 6,7,4,5 |
| `eventInfo` | 事件/问题摘要 | 6,7,4,5,3 |
| `status` | 问题状态 | 通用 |
| `loadTime` | 加载/完全加载耗时 | 1,2,8,9,10,11 |
| `requestTime` | 请求耗时 | 1 |
| `tcpTime` | TCP 连接耗时 | 1 |
| `dnsTime` | DNS 解析耗时 | 1 |
| `sslTime` | SSL 握手耗时 | 1 |
| `downloadTime` | 下载耗时 | 1 |
| `fcp` | FCP 耗时 | 2 |
| `fp` | FP 耗时 | 2 |
| `lcp` | LCP 耗时 | 2 |
| `domInteractive` | 可交互耗时 | 2 |
| `firstByteTime` | 首字节耗时 | 2 |

#### 14.3.3 snapshotFile 引用文件清单

以下文件均位于 `newonexm/view/rum/src/packages/` 目录下：

| 文件路径 | 引用方式 |
|---------|---------|
| `utils/compatibleNewVerData.ts`（位于 `newonexm/view/rum/src/`） | 展平 `baseInfo` / `deviceInfo` / `metricInfo` |
| `retrieval/breakdown/CrashDetail/index.tsx` | 展平三级子字段 |
| `retrieval/breakdown/AnrDetail/index.tsx` | 同上 |
| `retrieval/breakdown/CatonDetail/index.tsx` | 同上 |
| `retrieval/breakdown/JSDetail/index.tsx` | 同上 |
| `retrieval/breakdown/CustomExceptionDetail/index.tsx` | 同上 |
| `retrieval/customEventDetail/index.tsx` | 展平三级子字段 |
| `retrieval/userOperateList/models/index.ts` | 展平三级子字段 |
| `retrieval/sessionDetail/utils/eventTypeConfig.tsx` | 取 `stackInfoList[0].dumInfo`（自定义异常堆栈展示） |
| `retrieval/sessionDetail/models/sessionDetail/reducer/tableList.tsx` | 展平三级子字段 |
| `retrieval/sessionDetail/container/expendTable/common.tsx` | 展平三级子字段 |
| `retrieval/sessionDetail/container/drawerExpendTable/common.tsx` | 展平三级子字段 |
| `retrieval/sessionDetail/container/drawerExpendTable/index.tsx` | 整对象传递 |
| `retrieval/sessionDetail/container/SessionDetailsModal/.../waterfallsTableView/index.tsx` | 展平三级子字段 |
| `experience/request/models/domain.ts` | 展平三级子字段 |

### 14.4 新旧版本数据格式兼容

前端通过 `otherIndex.snapshotVersion` 字段判断数据格式版本：

| snapshotVersion | 数据格式 | 前端处理方式 |
|----------------|---------|-------------|
| 存在且为 `1` | 新版快照 | 通过 `getCompatibleNewVersionsData()` 展平 `otherIndex` + `snapshotFile`（三级子字段），展平后 `snapshotVersionTable` 标记行数据版本 |
| 不存在 / `null` | 旧版快照 | 直接使用 `baseInfo` / `deviceInfo` / `metricInfo` 顶层字段（旧格式快照详情接口返回的结构） |

> **注意**：表格中耗时字段的单位转换依赖 `snapshotVersionTable`：新版本耗时单位为**微秒**（需 `toUsTos` 转换），旧版本为**毫秒**（需 `toMsTos` 转换）。

---

## 15. 新旧快照版本入库与兼容性分析

### 15.1 入库端现状：已完全统一为新版格式

当前 ingester（数据入库）代码**不再产生** `snapshotVersion` 为 null 的旧版快照数据。

所有 11 种事件类型的快照入库路径均经过公共方法 `BusinessCommonBiz.dealCommonOtherIndex()`，该方法**无条件**设置：

```java
// 快照调整版本(快照存储优化 版本 添加)
otherIndex.put("snapshotVersion", "1");
```

调用链路为：各业务策略实现 → `BusinessCommonBiz.getCommonSnapshotTable()` / `dealCommonEventSnapshot()` → `dealCommonOtherIndex()` → **写入 `snapshotVersion = "1"`**。

涉及的入库策略实现共 **21 个文件**，包括：

| 策略类 | 对应事件 |
|--------|---------|
| `CrashEventDefaultStrategy` / `CrashEventCustomStrategy` | 崩溃 / 自定义异常 |
| `AnrEventStrategy` | ANR |
| `LagEventStrategy` | 卡顿 |
| `JsErrorEventStrategy` | JS 错误 |
| `LaunchEventStrategy` | 应用启动 |
| `ActionExitEventStrategy` | 用户操作 |
| `MpviewEventStrategy` / `RouteChangeEventStrategy` | 小程序视图 / 路由变更 |
| `StateChangeEventStrategy` | 状态变更 |
| `ConsoleEventStrategy` | 控制台事件 |
| `ReplayEventStrategy` | 回放事件 |
| `WebViewErrorStrategy` | WebView 错误 |
| `ViewSnapshotResultZeusConvert` | 视图快照 |
| `H5SnapshotResultZeusConvert` | H5 快照 |
| `NetWorkResultBuild` / `SpanSnapshotResultZeusConvert` | 网络请求 / Span |
| `UploadSnapshotResultZeusConvert` | Upload 事件 |
| `CustomEventSnapshotConvert` / `CustomLogEventSnapshotConvert` / `CustomMetricEventSnapshotConvert` | 自定义事件 / 日志 / 指标 |

> **结论**：所有入库路径均通过公共方法统一设置 `snapshotVersion = "1"`，不存在遗漏的旧版写入路径。

### 15.2 查询/展示端现状：仍保留大量旧版兼容代码

尽管入库端已统一，但查询和展示端仍然保留了大量针对 `snapshotVersion == null`（旧版快照）的兼容分支，用于处理 ClickHouse 中"快照存储优化"上线前入库的历史数据。

#### 15.2.1 后端旧版兼容代码清单

| 文件 | 位置 | 旧版逻辑说明 |
|------|------|-------------|
| `RetrievalService.java` | 第 277 行 | `if (Objects.isNull(snapshotVersion))` → 快照详情走 `formatNetworkOld` / `formatH5workOld` / `formatViewOld` / `formatJSErrorView` 处理旧格式 |
| `RetrievalRepository.formatLag()` | 第 285-288 行 | `if (Objects.isNull(snapshotVersion))` → 从顶层 `type` 字段补充 `lagType` 到 otherIndex |
| `RetrievalRepository.formatError()` | 第 295-298 行 | `if (Objects.isNull(snapshotVersion))` → 从顶层 `nameCode`/`name` 补充 `codeErrorId`/`eventInfo` |
| `RetrievalRepository.formatAction()` | 第 315-317 行 | `if snapshotVersion != 1` → 旧版 `loadTime` 需除以 1000 转换单位 |
| `RetrievalRepository.formatNetwork()` | 第 426-431 行 | `if (Objects.isNull(snapshotVersion))` → 从旧字段补充 `url`/`requestTime`/`requestMethod` |
| `SnapshotService.java` | 第 198 行 | 旧版走 `snapshotFile` 字符串解析，新版走 `decorateSnapshotFile` |
| `OperationService.java` | 第 406 行 | `if (Objects.isNull(snapshotVersion))` → 注释明确标注为"老数据"分支 |
| `SessionUtil.java` | 第 101-105 行 | 旧版走旧事件数据处理，新版走 `decorateNewSessionEventData` |
| `DownloadFilter.java` / `DownLoadDataConvert.java` | 多处 | 下载场景的旧格式字段兼容 |

#### 15.2.2 前端旧版兼容代码清单

| 文件 | 旧版逻辑说明 |
|------|-------------|
| `utils/compatibleNewVerData.ts` | `item?.otherIndex?.snapshotVersion` 为真时走新版展平逻辑（合并 otherIndex + snapshotFile 三级子字段），否则走旧版 |
| `breakdown/CrashDetail/index.tsx` 等所有 Detail 页面 | `res?.otherIndex?.snapshotVersion` 分支：有则合并 `otherIndex + snapshotFile`，无则合并旧版顶层 `baseInfo`/`deviceInfo`/`metricInfo` |
| 表格列耗时渲染（`recordList/component/table/index.tsx` 等） | `snapshotVersionTable` 存在时用 `toUsTos`（微秒→秒），否则用 `toMsTos`（毫秒→秒） |

### 15.3 旧版兼容代码清理建议

| 判断维度 | 说明 |
|---------|------|
| **可否清理** | 取决于 ClickHouse 快照表的 **TTL（数据保留周期）** 是否已超过"快照存储优化"功能的上线时间 |
| **如果旧数据已全部过期** | 可安全移除所有 `snapshotVersion == null` 的兼容分支，包括后端的 `formatXxxOld` 方法和前端的旧版展平逻辑，简化代码维护成本 |
| **如果仍有旧数据存活** | 需继续保留兼容逻辑，否则旧数据的展示会出现字段缺失或单位错误 |
| **清理范围** | 后端约 9 个文件（含 `formatNetworkOld`/`formatH5workOld`/`formatViewOld` 等 Old 后缀方法），前端约 12 个文件 |
| **清理收益** | 减少约 30% 的数据格式化分支代码，降低后续迭代时的认知负担和回归测试范围 |
