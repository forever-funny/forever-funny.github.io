---
title: quantileDD 分位字段与 RUM 页面映射
---

# quantileDD 分位字段与 RUM 页面映射

> **基准脚本**：`script/one_framework_rum/INIT/clickhouse/all/one_rum_datasource_gran.sql`
> **后端模块**：`framework/plugins/rum/`
> **前端模块**：`view/rum/`
> **整理日期**：2026-07-11
> **范围**：ClickHouse Gran 层 `quantileDD` 聚合态字段（`*_qds`）与 RUM 前后端列表/卡片/筛选/导出的完整链路。

---

## 1. 总论

### 1.1 数据链路（全表统一，唯一事实源）

```
明细 / local 表（单条事件，源字段为标量）
  └─ MV minute：quantileDDStateIf(0.001, 0.5)(源字段, 源字段 != 0) → *_qds
       └─ MV hour / day：quantileDDMergeState(0.001, 0.5)(*_qds)
            └─ 查询 / PROJECTION：quantileDDMerge(0.001, P)(*_qds) → P50/P75/P90/P95/P99
                 └─ Query Service：quantile(metric['指标ID'], P)
                      └─ API alias（如 p50TotalTime）→ RUM 前端列表/卡片/趋势/筛选/导出
```

**关键参数**：`quantileDD(0.001, 0.5)` —— 精度 0.001，中位数基准 0.5；查询时按 `0.5 / 0.75 / 0.9 / 0.95 / 0.99` 展开。

**四级一致性约束**：任意 `*_qds` 字段的改动必须同步 `local → minute → hour → day` 四级 MV；若表带 PROJECTION，PROJECTION 中的 `quantileDDMerge` 分位列表也须同步。

### 1.2 分位展开规则（全表统一）

| 阶段 | 函数 | 说明 |
|------|------|------|
| Minute MV | `quantileDDStateIf(0.001, 0.5)(源字段, 源字段 != 0)` | 写入 `*_qds` AggregateFunction 态 |
| Hour/Day MV | `quantileDDMergeState(0.001, 0.5)(*_qds)` | 跨粒度合并分位态 |
| 查询/PROJECTION | `quantileDDMerge(0.001, P)(*_qds)` | P = 0.5 / 0.75 / 0.9 / 0.95 / 0.99 |
| Query Service | `quantile(metric['指标ID'], P)` | 对上层透明，alias 由后端配置决定 |

**改 `quantileDD(0.001, 0.5)` 参数会影响历史态合并**，须全量重算或评估兼容性。

### 1.3 Snapshot vs Gran（不读 qds 的场景）

| 场景 | businessType 示例 | 数据来源 | 是否读 `*_qds` |
|------|-------------------|----------|----------------|
| 网络请求记录明细 | 10007 / 100071 / 100072 | `t_rum_net_snapshot_view` 单条 `loadTime`/`requestTime` | 否 |
| 协议扩展记录明细 | 180014 等 | `t_rum_span_snapshot_view` | 否 |
| 应用启动记录 | launch snapshot | `t_rum_launch_snapshot_view` 单条 `launchTime` | 否 |
| 操作记录明细 | 检索明细 | `t_rum_action_snapshot_view` | 否 |
| H5 / 视图单次访问 | 会话详情内 | 对应 `*_snapshot_view` | 否 |
| 业务/资源/协议扩展聚合 P 分位 | 21001~21008 | Gran `*_qds` | 是 |
| 页面分析聚合 P 分位 | 25001~25003 / 20002~22001 | Gran `*_qds` | 是 |

**原则**：聚合列表/卡片/趋势/筛选走 Gran `*_qds`；单条明细走 Snapshot。改 Gran MV 不影响 Snapshot，反之亦然。

### 1.4 后端配置入口（全表共用，唯一事实源）

| 配置 | 路径 |
|------|------|
| 列表默认字段 | `framework/plugins/rum/rum-core/src/main/resources/query-field.xml` |
| 自定义表头 | `framework/plugins/rum/rum-core/src/main/resources/custom-header-cn.xml` |
| 高级筛选项 | `framework/plugins/rum/rum-common/src/main/resources/filter-component-data.xml` |
| 筛选字段构建 | `rum-common/.../FilterFieldsCreator.java` |
| 分布/卡片 metricName | `rum-common/.../MapCountMetric.java` |
| 网络统计 | `rum-core/.../NetResultUtil.java`、`NetworkMetricBuild.java` |
| 协议扩展 alias | `rum-core/.../CustomSocketList.java` |
| 小程序 P 分位 | `rum-core/.../MiniProgramMetricEnum.java` |
| OpenAPI 网络 | `rum-core/.../OpenApiAppNetworkVO.java` |

### 1.5 前端公共路径（全表共用，唯一事实源）

```
view/rum/src/packages/
├── experience/request/              # 网络 21001/21004/21008
│   ├── index.tsx
│   ├── networkDomain/               # 21002
│   ├── resourceDomain/              # 21005
│   ├── socketDomain/                # 21008 详情
│   └── models/tableColmun.tsx       # p50TotalTime 等渲染
├── experience/application/
│   ├── details/                     # 应用详情各 Tab
│   ├── pageDetails/                 # H5/SPA 页面详情
│   ├── viewDetails/                 # 原生/小程序视图
│   └── operateDetails/              # 操作 44001
├── experience/pageAnalysis/         # 25001/25002/25003
└── retrieval/
    ├── netRequest/                  # 检索网络（聚合+明细）
    └── userOperateList/             # 检索操作
```

---

## 2. 全表总览矩阵

> 9 个 Gran 表族 × qds 列 × 源字段 × 指标 ID × 典型 P50 alias × 主 businessType × RUM 菜单。

| CK 表族 | qds 列 | 源字段 | 指标 ID | 典型 API alias (P50) | 主 businessType | RUM 菜单 |
|---------|--------|--------|---------|---------------------|-----------------|----------|
| `t_rum_net_*` | `total_time_qds` | `total_time` | `one.rum.net.businessRequest.totalTime` | `p50TotalTime` | 21001 / 21002 | 数字体验→网络请求（业务） |
| `t_rum_net_*` | `request_time_qds` | `request_time` | `one.rum.net.businessRequest.request` | `p50ResponseTime` | 21001 / 21002 | 同上 |
| `t_rum_net_resource_*` | `total_time_qds` | `total_time` | `one.rum.net.resourceRequest.totalTime` | `p50TotalTime` | 21004 / 21005 | 网络请求（资源） |
| `t_rum_net_resource_*` | `request_time_qds` | `request_time` | `one.rum.net.resourceRequest.request` | `p50ResponseTime` | 21004 / 21005 | 同上 |
| `t_rum_span_*` | `load_time_qds` | `load_time_sum` | `one.rum.net.custom.time` | `p50TotalTime` | 21008 | 网络请求（协议扩展） |
| `t_rum_h5_*` | `total_time_qds` | `total_time` | `one.rum.page.h5.totalLoadTime` | `quantile50TotalLoadTime` | 20002 / 20004 | 应用详情→页面(H5) |
| `t_rum_h5_*` | `fp_qds` | `fp` | `one.rum.page.h5.fp` | `p50Fp` | 20002 / 20004 | 同上 |
| `t_rum_h5_*` | `fcp_qds` | `fcp` | `one.rum.page.h5.fcp` | `p50Fcp` | 20002 / 20004 | 同上 |
| `t_rum_h5_*` | `first_byte_time_qds` | `first_byte_time` | `one.rum.page.h5.timeToFirstByte` | `p50TimeToFirstByte` | 20002 / 20004 | 同上 |
| `t_rum_route_*` | `switch_time_qds` | `switch_time` | `one.rum.page.singlePage.switchTime` | `p50RouteSwitchTime` | 20003 / 20006 | 应用详情→页面(SPA) |
| `t_rum_view_*` | `launch_time_qds` | `launch_time` | `one.rum.page.view.launchTime` | `p50LaunchTime` | 22001 | 应用详情→视图 |
| `t_rum_action_*` | `load_time_qds` | `load_time` | `one.rum.action.performance.time` | `p50OptTime` | 44001 / 44006 | 应用详情→操作 |
| `t_rum_launch_*` | `launch_time_qds` | `launch_time` | `one.rum.app.terminal.launchTime` | （UI 未暴露 P 列） | 20001 avg only | 应用列表启动 avg |
| `t_rum_mpview_*` | `launch_time_qds` | `launch_time` | `one.rum.page.mpView.launchTime` | `p50MPViewLaunchTime` | 小程序视图 | 小程序应用→视图 |

---

## 3. businessType / queryType 速查表

| businessType | queryType | 关联 CK 表 | 页面场景 |
|--------------|-----------|-----------|----------|
| 21001 | 500000 | `t_rum_net` | 业务网络域名列表 |
| 21002 | 501000 | `t_rum_net` | 业务请求 URL 聚合列表 |
| 21004 | 510000 | `t_rum_net_resource` | 资源网络域名列表 |
| 21005 | 511000 | `t_rum_net_resource` | 资源请求 URL 列表 |
| 21008 | — | `t_rum_span` | 协议扩展域名列表 |
| 20001 | 200000 | `t_rum_launch` / `t_rum_terminal` | 应用列表（仅 avg 网络指标，无 P 分位列） |
| 20002 | 700000 | `t_rum_h5` | H5 域名列表 |
| 20004 | 710000 | `t_rum_h5` | H5 页面 URL 列表 |
| 20003 | 800000 | `t_rum_route` | SPA 域名维度 |
| 20006 | 810000 | `t_rum_route` | SPA 路由 URL 列表 |
| 22001 | 210000 | `t_rum_view` | 原生视图列表 |
| 44001 | 600000 | `t_rum_action` | 操作列表 |
| 44006 | 610000 | `t_rum_action` | 单操作详情 |
| 25001 | 910000 | `t_rum_h5` | 页面分析-Web（部分 header 无全部分位列） |
| 25002 | 920000 | `t_rum_route` | 页面分析-SPA（header 仅 avg，无 P 列） |
| 25003 | 930000 | `t_rum_view` | 页面分析-原生视图（header 无 P 列，仅 avg） |

> 检索中心网络聚合 Tab、检索用户操作列表分别复用 21001/21002 与 44001 查询模型。

---

## 4. 易混淆点与故障分级

### 4.1 易混淆 alias 对照（横切，唯一事实源）

| alias / 列名 | 可能来源表 | 区分方式 |
|--------------|-----------|----------|
| `p50TotalTime` | `t_rum_net` / `t_rum_net_resource` / `t_rum_span` | businessType 21001 / 21004 / 21008；指标 ID `businessRequest.totalTime` / `resourceRequest.totalTime` / `net.custom.time` |
| `p50ResponseTime` | `t_rum_net` / `t_rum_net_resource` | businessType 21001/21002 vs 21004/21005；指标前缀 `businessRequest` vs `resourceRequest` |
| `load_time_qds` | `t_rum_span` / `t_rum_action` | 指标 `net.custom.time` vs `action.performance.time`；源字段 `load_time_sum` vs `load_time` |
| `launch_time_qds` | `t_rum_view` / `t_rum_launch` / `t_rum_mpview` | 指标 `page.view.launchTime` vs `app.terminal.launchTime` vs `page.mpView.launchTime` |
| `p50LaunchTime` | `t_rum_view` / `t_rum_launch` / `t_rum_mpview` | 同上；`t_rum_launch` 当前 UI 不暴露 P 列 |
| `p50RouteSwitchTime` vs `p50SwitchTimes` | `t_rum_route` | 前者为列表 field（query-field.xml），后者为卡片/趋势 MapCountMetric 前端 metricName |
| `p50OptTime` vs `p50ActionTimes` | `t_rum_action` | 前者为列表 field，后者为详情卡片 MapCountMetric metricName |
| `quantile50TotalLoadTime` vs `p50Fp` / `p50Fcp` | `t_rum_h5` | 命名风格不一致，前端表头 key 须精确匹配 |
| `p50TimeToFirstByte` | `t_rum_h5` | CK 字段 `first_byte_time` ↔ 指标 `timeToFirstByte`，非 `firstByteTime` |

### 4.2 故障影响分级（横切，唯一事实源）

| 级别 | 表 | 典型症状 |
|------|-----|----------|
| **高** | `t_rum_net` / `t_rum_net_resource` | 网络列表 P 列空/错；OpenAPI 分位异常；网络筛选 P 失效；CSV 导出分位列异常 |
| **中** | `t_rum_span` | 仅协议扩展 Tab P 列异常 |
| **中** | `t_rum_h5` / `t_rum_route` | 页面详情卡片/趋势 P 切换异常；H5/SPA 列表 P 列 |
| **中** | `t_rum_view` / `t_rum_action` / `t_rum_mpview` | 对应 Tab 列表/筛选 P 列；操作详情性能卡片 P 分位切换 |
| **低** | `t_rum_launch` | 当前 UI 几乎无 P 列；avg 启动仍可用其他列 |

---

## 5. 按表深挖（9 章，统一模板）

> 每张表按 5 段结构：① 表族结构 ② 全分位映射（CK 列 / 源字段 / 指标 ID / P50~P99 alias） ③ businessType / queryType ④ 页面功能（含完整路径与渲染/筛选/导出入口） ⑤ 影响范围与排查要点。

### 5.1 `t_rum_net`（业务网络请求）

**脚本位置**：`one_rum_datasource_gran.sql`（约 L286–L1474）
**业务域**：业务网络请求（非资源、非协议扩展）

#### 5.1.1 表族结构

| 层级 | 表名模式 | MV |
|------|----------|-----|
| Local | `t_rum_net_local` | 明细写入 |
| Minute | `t_rum_net_minute_local` / `_distributed` | `mv_t_rum_net_minute` |
| Hour | `t_rum_net_hour_local` / `_distributed` | `mv_t_rum_net_hour` |
| Day | `t_rum_net_day_local` / `_distributed` | `mv_t_rum_net_day` |

#### 5.1.2 全分位映射

**`total_time_qds`（网络请求总耗时）**

| 分位 | Query Service 表达式 | API alias | 中文名 |
|------|---------------------|-----------|--------|
| P50 | `quantile(metric['one.rum.net.businessRequest.totalTime'],0.5)` | `p50TotalTime` | P50 网络请求响应时间 |
| P75 | `...,0.75)` | `p75TotalTime` | P75 网络请求响应时间 |
| P90 | `...,0.9)` | `p90TotalTime` | P90 网络请求响应时间 |
| P95 | `...,0.95)` | `p95TotalTime` | P95 网络请求响应时间 |
| P99 | `...,0.99)` | `p99TotalTime` | P99 网络请求响应时间 |

**`request_time_qds`（服务响应耗时）**

| 分位 | Query Service 表达式 | API alias | 中文名 |
|------|---------------------|-----------|--------|
| P50 | `quantile(metric['one.rum.net.businessRequest.request'],0.5)` | `p50ResponseTime` | P50 服务响应耗时 |
| P75 | `...,0.75)` | `p75ResponseTime` | P75 服务响应耗时 |
| P90 | `...,0.9)` | `p90ResponseTime` | P90 服务响应耗时 |
| P95 | `...,0.95)` | `p95ResponseTime` | P95 服务响应耗时 |
| P99 | `...,0.99)` | `p99ResponseTime` | P99 服务响应耗时 |

MV 写入：`quantileDDStateIf(0.001,0.5)(total_time, total_time != 0)` / `quantileDDStateIf(0.001,0.5)(request_time, request_time != 0)`；Hour/Day rollup：`quantileDDMergeState(0.001,0.5)(*_qds)`。

#### 5.1.3 businessType / queryType

| businessType | queryType | 页面场景 |
|--------------|-----------|----------|
| **21001** | 500000 | 数字体验 → 网络请求 → 业务网络域名列表 |
| **21002** | 501000 | 业务域名详情 → 请求 URL 聚合列表 |
| 20001 | 200000 | 应用列表（仅 avg 网络指标，**无 P 分位列**） |

检索中心网络聚合 Tab 复用 21001/21002 查询模型。

#### 5.1.4 页面功能

| 菜单 | 前端路径 | 功能点 | 使用的 alias |
|------|----------|--------|--------------|
| 数字体验 → 网络请求 | `view/rum/src/packages/experience/request/index.tsx` | Tab0 业务域名表、自定义表头、统计卡片 | `p50TotalTime`、`p50ResponseTime` 等 |
| 业务域名详情 | `.../experience/request/networkDomain/index.tsx` | 请求 URL 列表、统计图 | 同上 |
| 业务请求详情（聚合侧） | `.../experience/request/networkRequestDetail/` | 域名下 URL 聚合 | 同上 |
| 应用详情 → 网络 | `.../experience/application/details/` | 嵌入网络 Tab（21001） | 同上 |
| 检索中心 → 网络请求 | `.../retrieval/netRequest/` | 域名/请求聚合 Tab | 动态表头 |
| OpenAPI 网络列表 | 后端 `RumAppNetworkOpenApiController` | 第三方 API | `OpenApiAppNetworkVO.p50TotalTime` 等 |

**列渲染**：`experience/request/models/tableColmun.tsx`（`p50TotalTime`、`p50ResponseTime` 等 format 为 ms）。

**统计卡片/趋势**：
- 首页卡片：`experience/request/models/index.ts` → `getCardList`，`calcRule` 4~7 映射分位
- 域名详情：`experience/request/models/domain.ts` → `POST /rest/rum/network/statisticalChart`

**高级筛选**：`FilterFieldsCreator.java` + `filter-component-data.xml` —— P50~P99 网络耗时条件。

**导出**：`NetDownloadFilter.java` —— CSV 含 `p50TotalTime` 等列。

**MapCountMetric**：`net_p50_totalTime` 等分布图 metricName。

**后端关键类**：`NetResultUtil.java`（calcRule ↔ quantile 映射）、`NetworkMetricBuild.java`（网络统计卡片/趋势指标构建）、`MapCountMetric.java`、`query-field.xml`（businessType 21001/21002 字段定义）。

#### 5.1.5 影响范围与排查要点

**受影响（qds 异常时）**：21001/21002 聚合列表 P50~P99 列；自定义表头中选中的分位列；网络高级筛选 P 分位条件；域名详情统计卡片/趋势（分位切换）；CSV 导出、OpenAPI 分位字段；检索中心网络聚合 Tab。

**不受影响**：请求明细记录（10007/100071/100072，Snapshot 单条）；资源网络（21004/21005，见 §5.2）；协议扩展 21008（见 §5.3）。

**排查要点**：
1. 改 MV/PROJECTION 须同步 minute/hour/day 三级。
2. 改 `quantileDD(0.001,0.5)` 参数会影响历史态合并。
3. 改指标 ID 须同步 `query-field.xml`、`custom-header-cn.xml`、筛选 XML。
4. 前端列 key 与 API alias 强绑定，勿与 21008 的 `p50TotalTime`（span 表）混查。

---

### 5.2 `t_rum_net_resource`（资源网络请求）

**脚本位置**：`one_rum_datasource_gran.sql`（约 L1761–L2949）
**业务域**：资源网络请求（图片/音视频/静态资源等，`request_source`/`meta_type` 区分）

#### 5.2.1 表族结构

| 层级 | 表名模式 | MV |
|------|----------|-----|
| Local | `t_rum_net_resource_local` | — |
| Minute/Hour/Day | `t_rum_net_resource_{minute,hour,day}_local` | `mv_t_rum_net_resource_minute/hour/day` |

字段与 `t_rum_net_*` **结构对称**，仅数据源表不同。

#### 5.2.2 全分位映射

**`total_time_qds`（资源请求总耗时）**

| 分位 | Query Service 表达式 | API alias |
|------|---------------------|-----------|
| P50 | `quantile(metric['one.rum.net.resourceRequest.totalTime'],0.5)` | `p50TotalTime` |
| P75 | `...,0.75)` | `p75TotalTime` |
| P90 | `...,0.9)` | `p90TotalTime` |
| P95 | `...,0.95)` | `p95TotalTime` |
| P99 | `...,0.99)` | `p99TotalTime` |

**`request_time_qds`（资源服务响应耗时）**

| 分位 | Query Service 表达式 | API alias |
|------|---------------------|-----------|
| P50 | `quantile(metric['one.rum.net.resourceRequest.request'],0.5)` | `p50ResponseTime` |
| P75 | `...,0.75)` | `p75ResponseTime` |
| P90 | `...,0.9)` | `p90ResponseTime` |
| P95 | `...,0.95)` | `p95ResponseTime` |
| P99 | `...,0.99)` | `p99ResponseTime` |

聚合/展开函数与 `t_rum_net_*` 相同（`quantileDDStateIf` → `quantileDDMergeState` → `quantileDDMerge`）。

#### 5.2.3 businessType / queryType

| businessType | queryType | 页面场景 |
|--------------|-----------|----------|
| **21004** | 510000 | 数字体验 → 网络请求 → 资源网络域名列表（Tab1） |
| **21005** | 511000 | 资源域名详情 → 资源请求 URL 列表 |

应用详情：`resource_businessType: '21004'`（`application/details/models/index.ts`）。

#### 5.2.4 页面功能

| 菜单 | 前端路径 | 功能 |
|------|----------|------|
| 网络请求 Tab1 | `experience/request/index.tsx` | 资源域名列表、表头 businessType=21004 |
| 资源域名详情 | `experience/request/resourceDomain/index.tsx` | 21005 请求列表、自定义表头 |
| 资源请求详情 | `experience/request/resourceRequestDetail/` | 聚合列表侧 |
| 应用详情 → 网络 | `experience/application/details/` | 资源 Tab |
| 检索中心 | `retrieval/netRequest/` | 资源聚合 Tab |

**共用组件**：`tableColmun.tsx`、`models/index.ts`（Tab 索引 1 时 businessType 21004）。

**MapCountMetric**：`resource_p50_totalTime` 等（分布图 metricName）。

#### 5.2.5 影响范围与排查要点

**受影响**：与 `t_rum_net_*` 相同模式，但**仅影响资源网络 Tab（21004/21005）**，不影响业务网络 21001/21002。

**不受影响**：资源请求明细 Snapshot（10007 等单条记录）。

**与 `t_rum_net` 差异点**：

| 项 | 业务 net | 资源 net_resource |
|----|----------|-------------------|
| 指标前缀 | `one.rum.net.businessRequest.*` | `one.rum.net.resourceRequest.*` |
| businessType | 21001/21002 | 21004/21005 |
| 前端 Tab | `index.tsx` Tab0 | Tab1 |

**排查要点**：排查时需确认 Query 请求的 businessType，避免查错 Gran 表。

---

### 5.3 `t_rum_span`（协议扩展 / 自定义 Socket）

**脚本位置**：`one_rum_datasource_gran.sql`（约 L7710–L8336）
**业务域**：协议扩展（WebSocket/Socket 等，`businessType=21008`）
⚠️ **非** `t_rum_net_*`，但 API alias 与网络表同名（如 `p50TotalTime`）

#### 5.3.1 表族结构

| 层级 | 表名 | MV |
|------|------|-----|
| Local | `t_rum_span_local` | — |
| Minute/Hour/Day | `t_rum_span_{minute,hour,day}_local` | `mv_t_rum_span_minute/hour/day` |

#### 5.3.2 全分位映射

**`load_time_qds`（协议扩展耗时）** —— 源字段 `load_time_sum`

| 分位 | Query Service 表达式 | API alias | 中文名（custom-header） |
|------|---------------------|-----------|------------------------|
| P50 | `quantile(metric['one.rum.net.custom.time'],0.5)` | `p50TotalTime` | P50耗时 |
| P75 | `...,0.75)` | `p75TotalTime` | P75耗时 |
| P90 | `...,0.90)` | `p90TotalTime` | P90耗时 |
| P95 | `...,0.95)` | `p95TotalTime` | P95耗时 |
| P99 | `...,0.99)` | `p99TotalTime` | P99耗时（**默认列**） |

avg/max/min：`avg(metric['one.rum.net.custom.time'])` → `avgTotalTime` 等。

MV 写入：`quantileDDStateIf(0.001,0.5)(load_time_sum, load_time_sum != 0)`。
查询：`quantileDDMerge(0.001, P)(load_time_qds)` → P50~P99。

**后端映射类**：`CustomSocketList.java`（metricMap 硬编码 alias）。

#### 5.3.3 businessType / queryType

| businessType | queryType | 场景 |
|--------------|-----------|------|
| **21008** | — | 网络请求 Tab2「协议扩展」域名列表 |
| 180014 等 | — | 协议扩展详情/子列表（custom-header 明细配置） |

`custom-header-cn.xml`：`businessType="21008"` 定义 P50~P99 列。

#### 5.3.4 页面功能

| 菜单 | 前端路径 | 说明 |
|------|----------|------|
| 网络请求 Tab2 | `experience/request/index.tsx` | `businessType: ['21001','21004','21008'][2]` |
| 协议扩展域名详情 | `experience/request/socketDomain/` | 21008 详情 |
| 应用详情 | `experience/application/details/models/index.ts` | `socket_businessType: '21008'` |

**高级筛选**：`FilterFieldsCreator.java` ——「P50耗时」等，`quantile(metric['one.rum.net.custom.time'],...)`。

**MapCountMetric**：`custom_socket_load_time_p50` 等。

**明细记录**：Snapshot 单条 `loadTime`，**不读** `load_time_qds`。

#### 5.3.5 影响范围与排查要点

**受影响**：21008 聚合列表、协议扩展自定义表头、协议扩展筛选 P 分位、协议扩展统计（若有分位切换）。

**不受影响**：21001/21004 业务/资源网络（不同 CK 表）。

**排查要点**：
- 用户反馈「网络请求 P99 不准」需先确认 Tab：**业务 / 资源 / 协议扩展**。
- 21008 的 `p50TotalTime` 来自 **span.load_time_qds**，不是 net.total_time_qds。
- 改 span MV 不影响 net 表，反之亦然。

---

### 5.4 `t_rum_h5`（H5 / Web 页面性能）

**脚本位置**：`one_rum_datasource_gran.sql`（约 L8626–L10068）
**业务域**：Web/H5 页面加载性能（FP、FCP、TTFB、完全加载等）

#### 5.4.1 表族结构

| 层级 | 表名 | MV |
|------|------|-----|
| Local | `t_rum_h5_local` | — |
| Minute/Hour/Day | `t_rum_h5_{minute,hour,day}_local` | `mv_t_rum_h5_minute/hour/day` |

#### 5.4.2 全分位映射（四类 qds × 5 分位）

**`total_time_qds`（页面完全加载）** —— 源字段 `total_time`

| 分位 | Query Service 表达式 | API alias |
|------|---------------------|-----------|
| P50 | `quantile(metric['one.rum.page.h5.totalLoadTime'],0.5)` | `quantile50TotalLoadTime` |
| P75 | `...,0.75)` | `quantile75TotalLoadTime` |
| P90 | `...,0.9)` | `quantile90TotalLoadTime` |
| P95 | `...,0.95)` | `quantile95TotalLoadTime` |
| P99 | `...,0.99)` | `quantile99TotalLoadTime` |

**`fp_qds`（白屏 FP）** —— 源字段 `fp`

| 分位 | Query Service 表达式 | API alias |
|------|---------------------|-----------|
| P50 | `quantile(metric['one.rum.page.h5.fp'],0.5)` | `p50Fp` |
| P75 | `...,0.75)` | `p75Fp` |
| P90 | `...,0.9)` | `p90Fp` |
| P95 | `...,0.95)` | `p95Fp` |
| P99 | `...,0.99)` | `p99Fp` |

**`fcp_qds`（首屏 FCP）** —— 源字段 `fcp`

| 分位 | Query Service 表达式 | API alias |
|------|---------------------|-----------|
| P50 | `quantile(metric['one.rum.page.h5.fcp'],0.5)` | `p50Fcp` |
| P75 | `...,0.75)` | `p75Fcp` |
| P90 | `...,0.9)` | `p90Fcp` |
| P95 | `...,0.95)` | `p95Fcp` |
| P99 | `...,0.99)` | `p99Fcp` |

**`first_byte_time_qds`（TTFB）** —— 源字段 `first_byte_time`

| 分位 | Query Service 表达式 | API alias |
|------|---------------------|-----------|
| P50 | `quantile(metric['one.rum.page.h5.timeToFirstByte'],0.5)` | `p50TimeToFirstByte` |
| P75 | `...,0.75)` | `p75TimeToFirstByte` |
| P90 | `...,0.9)` | `p90TimeToFirstByte` |
| P95 | `...,0.95)` | `p95TimeToFirstByte` |
| P99 | `...,0.99)` | `p99TimeToFirstByte` |

#### 5.4.3 businessType / queryType

| businessType | queryType | 场景 |
|--------------|-----------|------|
| **20002** | 700000 | H5 域名列表（应用详情-页面 Tab） |
| **20004** | 710000 | H5 页面 URL 列表 |
| **25001** | 910000 | 页面分析（Web 域，部分 header 无全部分位列） |

`application/details/models/index.ts`：`page_businessType1: '20002'`。

#### 5.4.4 页面功能

| 菜单 | 前端路径 | 使用的分位 |
|------|----------|-----------|
| 应用详情 → 页面 | `experience/application/pageDetails/` | 列表自定义表头：FP/FCP/TTFB/完全加载 P 列 |
| 页面详情 | `experience/application/pageDetails/index.tsx` | 统计卡片：`appAdomain.ts` 中 `p50PageFullLoadTime` → `h5_p50_totalTime` |
| 页面分析 | `experience/pageAnalysis/` | businessType 25001 |
| 列格式化 | `component/application/tableColumns/setTableColumnsFn.ts` | `p50Fp`、`p50Fcp` 等 ms 格式化 |

**MapCountMetric**：`h5_p50_totalTime`、`h5_p50_fp`、`h5_p50_fcp` 等（分布/卡片 metricName）。

**高级筛选**：`filter-component-data.xml` —— H5 各耗时指标 P50~P99。

**默认展示**：多数列表默认 **avg**；P 分位需用户勾选自定义表头。

#### 5.4.5 影响范围与排查要点

**受影响**：H5 域名/页面聚合列表中的 P 列、页面详情统计卡片（切换 P50 等）、H5 高级筛选 P 条件、页面分析相关聚合。

**不受影响**：H5 单次加载 Snapshot 明细、原生视图（`t_rum_view`）、SPA 路由（`t_rum_route`）。

**排查要点**：
- `quantile50TotalLoadTime` 与 `p50Fp` 命名风格不一致，前端表头 key 需精确匹配。
- CK `first_byte_time` ↔ 指标 `timeToFirstByte`，非 `firstByteTime` 字符串混用。
- 25001 header 未包含全部 quantile 字段，以 20002/20004 为准。

---

### 5.5 `t_rum_route`（SPA 单页应用路由切换）

**脚本位置**：`one_rum_datasource_gran.sql`（约 L10268–L10800）
**业务域**：SPA 单页应用路由切换耗时

#### 5.5.1 表族结构

| 层级 | 表名 | MV |
|------|------|-----|
| Local | `t_rum_route_local` | — |
| Minute/Hour/Day | `t_rum_route_{minute,hour,day}_local` | `mv_t_rum_route_minute/hour/day` |

#### 5.5.2 全分位映射

**`switch_time_qds`（路由切换耗时）** —— 源字段 `switch_time`

| 分位 | Query Service 表达式 | API alias | 中文 |
|------|---------------------|-----------|------|
| P50 | `quantile(metric['one.rum.page.singlePage.switchTime'],0.5)` | `p50RouteSwitchTime` | P50 路由切换耗时 |
| P75 | `...,0.75)` | `p75RouteSwitchTime` | P75 路由切换耗时 |
| P90 | `...,0.9)` | `p90RouteSwitchTime` | P90 路由切换耗时 |
| P95 | `...,0.95)` | `p95RouteSwitchTime` | P95 路由切换耗时 |
| P99 | `...,0.99)` | `p99RouteSwitchTime` | P99 路由切换耗时 |

MV 写入：`quantileDDStateIf(0.001,0.5)(switch_time, switch_time != 0)`。

#### 5.5.3 businessType / queryType

| businessType | queryType | 场景 |
|--------------|-----------|------|
| **20003** | 800000 | SPA 域名维度 |
| **20006** | 810000 | SPA 路由 URL 列表 |
| **25002** | 920000 | 页面分析-SPA（header 仅 avg，无 P 列） |

#### 5.5.4 页面功能

| 菜单 | 前端路径 | 说明 |
|------|----------|------|
| 应用详情 → 页面（SPA） | `experience/application/pageDetails/` | 路由切换统计 |
| 统计卡片 | `pageDetails/view/middleCont/tabCont/statisticalCard/index.tsx` | 分位下拉：P50/P75… |
| 趋势图 | `.../tabCont/trend/index.tsx` | metricName：`p50SwitchTimes` 等 |
| 分布图 | `.../tabCont/distribute/index.tsx` | 同上 |
| 模型映射 | `pageDetails/models/appAdomain.ts` | `p50SwitchTimes` → `h5_p50_switchTimes`（MapCountMetric） |

**MapCountMetric**：`h5_p50_switchTimes` … `h5_p99_switchTimes`。

**高级筛选**：`filter-component-data.xml` —— 路由切换 P50~P99。

#### 5.5.5 影响范围与排查要点

**受影响**：SPA 页面详情中「路由切换耗时」卡片/趋势/分布的分位切换；20003/20006 列表自定义 P 列；SPA 筛选 P 条件。

**不受影响**：H5 整页加载（`t_rum_h5`）、原生视图启动（`t_rum_view`）。

**命名注意**：
- 列表字段：`p50RouteSwitchTime`（query-field）
- 卡片/趋势：`p50SwitchTimes`（MapCountMetric 前端 metricName）
- 排查前后端需两套 key 对照

---

### 5.6 `t_rum_view`（原生视图启动）

**脚本位置**：`one_rum_datasource_gran.sql`（约 L10996–L11616，视图 Gran）
**业务域**：Android/iOS 原生视图（Activity/Fragment）启动耗时

#### 5.6.1 表族结构

| 层级 | 表名 | MV |
|------|------|-----|
| Local | `t_rum_view_local` | — |
| Minute/Hour/Day | `t_rum_view_{minute,hour,day}_local` | `mv_t_rum_view_minute/hour/day` |

#### 5.6.2 全分位映射

**`launch_time_qds`（视图启动耗时）** —— 源字段 `launch_time`

| 分位 | Query Service 表达式 | API alias |
|------|---------------------|-----------|
| P50 | `quantile(metric['one.rum.page.view.launchTime'],0.5)` | `p50LaunchTime` |
| P75 | `...,0.75)` | `p75LaunchTime` |
| P90 | `...,0.9)` | `p90LaunchTime` |
| P95 | `...,0.95)` | `p95LaunchTime` |
| P99 | `...,0.99)` | `p99LaunchTime` |

avg/max/min：`avgLaunchTime`、`maxLaunchTime`、`minLaunchTime`（**默认列 avg**）。

#### 5.6.3 businessType / queryType

| businessType | queryType | 场景 |
|--------------|-----------|------|
| **22001** | 210000 | 应用详情 → 视图列表 |
| **25003** | 930000 | 页面分析-原生视图（header 无 P 列，仅 avg） |

`application/details/models/index.ts`：`view_businessType1: '22001'`。

#### 5.6.4 页面功能

| 菜单 | 前端路径 | 说明 |
|------|----------|------|
| 应用详情 → 视图 | `experience/application/viewDetails/` | 视图列表，自定义表头可选 P50~P99 |
| 视图详情 | `viewDetails/index.tsx` | 统计卡片默认 `avgLaunchTime`（`activity.ts`） |
| 分布/趋势 | `viewDetails/view/component/distribute/` | 默认 aggsField：`avgLaunchTime` |
| 检索 | 视图相关检索 Tab | 聚合侧可用 P 列 |

**MapCountMetric**：`view_p50_launchTime`、`p50LaunchTime` 等。

**高级筛选**：`filter-component-data.xml` ——「P50启动耗时」等（view.launchTime）。

#### 5.6.5 影响范围与排查要点

**受影响**：22001 视图列表 P 列、视图高级筛选 P 条件、用户勾选 P 列后的排序/导出。

**弱影响**：视图详情默认卡片/趋势（多为 avg，除非产品切换至 P 分位 metric）。

**不受影响**：小程序视图（`t_rum_mpview`）、应用级启动 Gran（`t_rum_launch`）、H5 页面。

**与 `t_rum_mpview` 区分**：

| 表 | 指标 | 场景 |
|----|------|------|
| `t_rum_view` | `one.rum.page.view.launchTime` | Activity/Fragment |
| `t_rum_mpview` | `one.rum.page.mpView.launchTime` | 微信小程序等 |

---

### 5.7 `t_rum_action`（用户操作性能）

**脚本位置**：`one_rum_datasource_gran.sql`（约 L12687–L12837）
**业务域**：终端用户操作耗时（点击、滑动等）

#### 5.7.1 表族结构

| 层级 | 表名 | MV |
|------|------|-----|
| Local | `t_rum_action_local` | — |
| Minute/Hour/Day | `t_rum_action_{minute,hour,day}_local` | `mv_t_rum_action_minute/hour/day` |

#### 5.7.2 全分位映射

**`load_time_qds`（操作耗时）** —— 源字段 `load_time`

⚠️ 列名 `load_time_qds` 与 span 表同名，**指标与表均不同**。

| 分位 | Query Service 表达式 | API alias |
|------|---------------------|-----------|
| P50 | `quantile(metric['one.rum.action.performance.time'],0.5)` | `p50OptTime` |
| P75 | `...,0.75)` | `p75OptTime` |
| P90 | `...,0.90)` | `p90OptTime` |
| P95 | `...,0.95)` | `p95OptTime` |
| P99 | `...,0.99)` | `p99OptTime` |

默认列：`avgOptTime`（平均操作耗时）。

#### 5.7.3 businessType / queryType

| businessType | queryType | 场景 |
|--------------|-----------|------|
| **44001** | 600000 | 应用详情 → 操作列表 |
| **44006** | 610000 | 单操作详情（查看此操作） |
| 检索 | — | `retrieval/userOperateList/` businessType 44001 |

#### 5.7.4 页面功能

| 菜单 | 前端路径 | 说明 |
|------|----------|------|
| 应用详情 → 操作 | `experience/application/operateDetails/` | 操作列表自定义 P 列 |
| 操作详情 | `operateDetails/models/operate.ts` | 卡片 metricName：`p50ActionTimes`（MapCountMetric 映射） |
| 检索 → 用户操作 | `retrieval/userOperateList/index.tsx` | businessType 44001 |

**MapCountMetric**：`action_p50_actionTimes` … `action_p99_actionTimes`。

**高级筛选**：操作耗时 P50~P99（`filter-component-data.xml` / `FilterFieldsCreator`）。

#### 5.7.5 影响范围与排查要点

**受影响**：44001/44006 操作聚合列表 P 列、操作详情性能卡片（P 分位切换）、操作筛选 P 条件。

**不受影响**：操作 Snapshot 单条记录明细、网络/页面 Gran 表。

**命名对照**：

| 层级 | 命名 |
|------|------|
| query-field | `p50OptTime` |
| MapCountMetric / 详情卡片 | `p50ActionTimes` |

排查接口响应 field 与前端 metricName 时需做映射。

---

### 5.8 `t_rum_launch`（应用冷/热启动）

**脚本位置**：`one_rum_datasource_gran.sql`（约 L5042–L5540）
**业务域**：应用级启动（非视图级 launchTime）

#### 5.8.1 表族结构

| 层级 | 表名 | MV |
|------|------|-----|
| Local | `t_rum_launch_local` | — |
| Minute/Hour/Day | `t_rum_launch_{minute,hour,day}_local` | `mv_t_rum_launch_minute/hour/day` |

#### 5.8.2 全分位映射

**`launch_time_qds`（应用启动耗时）** —— 源字段 `launch_time`

MV 写入：`quantileDDStateIf(0.001,0.5)(launch_time, launch_time != 0)`。

| 类型 | 表达式 / 指标 | 产品暴露 |
|------|--------------|----------|
| **avg（常用）** | `avg(metric['one.rum.app.terminal.launchTime'])` | ✅ 应用列表 20001、`launchTime` 字段 |
| **quantile（Gran 支撑）** | 理论上 `quantile(metric['one.rum.app.terminal.launchTime'], P)` | ⚠️ **query-field.xml 未配置 P50~P99 列** |
| 筛选 | `filter-component-data.xml` 仅 **avg** 应用启动耗时 | 无 P 分位筛选项 |

**结论**：CK 已写入 `launch_time_qds`，但 RUM **页面侧几乎不暴露 P 分位**；启动分析明细走 **`t_rum_launch_snapshot_view`** 单条 `launchTime`。

#### 5.8.3 businessType

| businessType | 场景 |
|--------------|------|
| 20001 | 应用列表 — 仅 `launchTime`（avg） |
| — | 启动记录检索 — Snapshot，非 Gran qds |

#### 5.8.4 页面功能

| 菜单 | 路径 | 与 qds 关系 |
|------|------|-------------|
| 应用列表 | 终端应用概览 | 仅 avg 启动耗时 |
| 启动分析/检索 | `FilterFieldsCreator` `@t_rum_launch_snapshot_view` | Snapshot，**不用 qds** |
| 健康评分/慢启动 | 计数类指标 | slowCount/ratio，非 P 分位 |

#### 5.8.5 影响范围与排查要点

**理论受影响**：若未来新增「应用启动 P99」类指标，依赖本表 `launch_time_qds`。

**当前实际受影响面**：**极小** —— 仅 Query Service 内部聚合或报表扩展；现有 UI 默认不展示。

**改表影响**：avg 启动耗时、慢启动计数等 **sum/avg 类**指标仍依赖同 Gran 表其他列，与 qds 列独立。

**排查要点**：
- 用户反馈「启动 P99」问题时，先确认是 **应用启动** 还是 **视图启动**（`t_rum_view`）或 **小程序视图**（`t_rum_mpview`）。
- 改 `launch_time_qds` MV 对当前 UI 影响有限，但会影响潜在 quantile 查询与数据一致性。
- 明细页勿查 Gran qds，应查 Snapshot。

---

### 5.9 `t_rum_mpview`（小程序视图启动）

**脚本位置**：`one_rum_datasource_gran.sql`（约 L11919–L14117）
**业务域**：微信小程序 / 小程序页面视图启动

#### 5.9.1 表族结构

| 层级 | 表名 | MV |
|------|------|-----|
| Local | `t_rum_mpview_local` | — |
| Minute/Hour/Day | `t_rum_mpview_{minute,hour,day}_local` | `mv_t_rum_mpview_minute/hour/day` |

#### 5.9.2 全分位映射

**`launch_time_qds`（小程序视图启动耗时）** —— 源字段 `launch_time`

| 分位 | Query Service 表达式 | 响应 alias |
|------|---------------------|------------|
| P50 | `quantile(metric['one.rum.page.mpView.launchTime'],0.5)` | `p50MPViewLaunchTime` |
| P75 | `...,0.75)` | `p75MPViewLaunchTime` |
| P90 | `...,0.9)` | `p90MPViewLaunchTime` |
| P95 | `...,0.95)` | `p95MPViewLaunchTime` |
| P99 | `...,0.99)` | `p99MPViewLaunchTime` |

avg/max/min：`avgMPViewLaunchTime` 等。

**后端枚举**：`MiniProgramMetricEnum.java`（硬编码 alias 映射）、`AppViewCardEnum`（`MP_VIEW_LAUNCH_TIME` → metric `one.rum.page.mpView.launchTime`）。

#### 5.9.3 businessType / queryType

小程序视图列表/详情通过 Query Service + 自定义表头驱动；**无独立 query-field.xml header 块**（与 22001 原生视图分开）。

筛选：`filter-component-data.xml` —— P50~P99 小程序视图启动耗时。

#### 5.9.4 页面功能

| 菜单 | 前端路径 | 说明 |
|------|----------|------|
| 应用详情（小程序） | `experience/application/details/index.tsx` | `isMiniProgram()` 时默认视图 Tab |
| 视图列表/详情 | `experience/application/viewDetails/` | 小程序视图（无 Activity/Fragment 子表） |
| 会话详情 | `retrieval/sessionDetail/` | 109001 小程序视图 Snapshot |

**ViewMetric.java**：默认卡片 `mpViewLaunchTime` → avg。

**高级筛选**：P50~P99 小程序视图启动耗时（FilterFieldsCreator）。

#### 5.9.5 影响范围与排查要点

**受影响**：小程序应用视图聚合的 P 列（自定义表头）、小程序视图启动 P 筛选、小程序性能卡片（若切换 P 分位）。

**不受影响**：原生 Activity/Fragment（`t_rum_view`）、H5 Web 页面。

**与 `t_rum_view` 区分**：

| 维度 | mpview | view |
|------|--------|------|
| 平台 | 微信/抖音等小程序 | Android/iOS 原生 |
| 指标 | `one.rum.page.mpView.launchTime` | `one.rum.page.view.launchTime` |
| API 前缀 | `p50MPViewLaunchTime` | `p50LaunchTime` |

---

## 6. 横切附录

### 6.1 改造检查清单（任意 qds 表通用）

- [ ] local → minute → hour → day MV 四级一致
- [ ] PROJECTION（如有）`quantileDDMerge` 分位完整
- [ ] Query Service 指标 ID 与 CK 列映射未断
- [ ] `query-field.xml` / `custom-header-cn.xml` 同步
- [ ] `filter-component-data.xml` P 分位条件可解析
- [ ] `MapCountMetric` 卡片/分布 metricName 与前端一致
- [ ] 前端 `tableColmun` / `setTableColumnsFn` 渲染 key 存在
- [ ] 区分 Snapshot 明细接口未误改 Gran 查询
- [ ] 改 `quantileDD(0.001,0.5)` 参数时评估历史态合并影响
- [ ] 改指标 ID 时同步 `query-field.xml`、`custom-header-cn.xml`、筛选 XML

### 6.2 后端关键类索引（横切）

| 类 / 文件 | 作用 |
|-----------|------|
| `NetResultUtil.java` | calcRule ↔ quantile 映射 |
| `NetworkMetricBuild.java` | 网络统计卡片/趋势指标构建 |
| `MapCountMetric.java` | 分布/卡片 metricName（`net_p50_totalTime`、`resource_p50_totalTime`、`h5_p50_*`、`view_p50_*`、`action_p50_*`、`custom_socket_load_time_p50` 等） |
| `CustomSocketList.java` | 协议扩展 alias 硬编码 |
| `MiniProgramMetricEnum.java` | 小程序 P 分位 alias 枚举 |
| `AppViewCardEnum` | 视图卡片 metric 映射 |
| `OpenApiAppNetworkVO.java` | OpenAPI 网络分位字段 |
| `FilterFieldsCreator.java` | 高级筛选 P 分位条件构建 |
| `query-field.xml` | businessType 列表字段定义 |
| `custom-header-cn.xml` | 自定义表头 P50~P99 列 |
| `filter-component-data.xml` | 高级筛选项 |

### 6.3 前端模块树（横切）

```
view/rum/src/packages/
├── experience/request/              # 网络 21001/21004/21008
│   ├── index.tsx
│   ├── networkDomain/               # 21002
│   ├── resourceDomain/              # 21005
│   ├── socketDomain/                # 21008 详情
│   ├── networkRequestDetail/        # 业务请求详情
│   ├── resourceRequestDetail/       # 资源请求详情
│   └── models/
│       ├── tableColmun.tsx          # p50TotalTime 等渲染
│       ├── index.ts                 # getCardList、calcRule 4~7
│       └── domain.ts                # statisticalChart
├── experience/application/
│   ├── details/                     # 应用详情各 Tab
│   │   └── models/index.ts          # page/view/socket/resource_businessType
│   ├── pageDetails/                 # H5/SPA 页面详情
│   │   ├── index.tsx
│   │   ├── models/appAdomain.ts     # p50PageFullLoadTime → h5_p50_totalTime
│   │   └── view/middleCont/tabCont/
│   │       ├── statisticalCard/index.tsx
│   │       ├── trend/index.tsx
│   │       └── distribute/index.tsx
│   ├── viewDetails/                 # 原生/小程序视图
│   │   ├── index.tsx
│   │   └── view/component/distribute/
│   └── operateDetails/              # 操作 44001
│       └── models/operate.ts        # p50ActionTimes
├── experience/pageAnalysis/         # 25001/25002/25003
└── retrieval/
    ├── netRequest/                  # 检索网络（聚合+明细）
    ├── userOperateList/index.tsx    # 检索操作 44001
    └── sessionDetail/               # 会话详情（含 109001 小程序视图 Snapshot）
```

### 6.4 明细 vs 聚合速查（横切，不读 qds 的场景）

| 场景 | businessType 示例 | 数据来源 |
|------|-------------------|----------|
| 网络请求记录 | 10007/100071/100072 | Snapshot 单条 `loadTime`/`requestTime` |
| 协议扩展记录 | 180014 等 | Snapshot |
| 应用启动记录 | launch snapshot | `t_rum_launch_snapshot_view` |
| 操作记录 | 检索明细 | Snapshot |
| H5/视图单次访问 | 会话详情内 | Snapshot |
