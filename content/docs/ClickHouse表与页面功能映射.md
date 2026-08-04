---
title: RUM ClickHouse 表与页面功能映射
weight: 3
---

# RUM ClickHouse 表与页面功能映射

> **文档版本**：基于 `newonexm` 仓库当前代码与 DDL 梳理
> **基准脚本**：`script/one_framework_rum/INIT/clickhouse/all/one_rum_datasource_gran.sql`、`one_rum_datasource_snapshot.sql`、`one_common_datasource_gran.sql`
> **视图注册**：`script/one_framework_rum/INIT/mariadb/all/one_rum_queryservice_view.sql`
> **后端模块**：`framework/plugins/rum`
> **前端模块**：`view/rum`（路由：`src/routes/route.ts`）
> **整理日期**：2026-07-11
> **快速入口**：全局对照速查见 §2；Gran 明细 §4、Snapshot 明细 §5、菜单索引 §6。

---

## 1. 概述

RUM 运行时查询依赖 **三类** ClickHouse 数据源：

| 数据源 | 库名 | 用途 |
|--------|------|------|
| **统计（Gran）** | `one_rum_datasource_gran` | 分钟/小时/天级指标聚合；列表、趋势图、TopN、健康分计算 |
| **快照（Snapshot）** | `one_rum_datasource_snapshot` | 单条事件明细；检索中心列表/详情、会话时间线、会话宽表 |
| **公共 TopK（Gran）** | `one_common_datasource_gran` | 跨产品维度/筛选项 TopK 预聚合（见 §4B）；与 RUM 业务 Gran 表分离 |

业务代码**通常不直接写物理表名**，而是通过：

- **Gran**：Metric API + `t_basic_formula_config.storage_configure` 将 `one.rum.*` 指标路由到 `t_rum_*` 表族；查询引擎按时间范围自动选择 `_minute/_hour/_day` 粒度。
- **Snapshot**：QueryService 视图 `t_rum_*_snapshot_view`、`t_rum_session_view`；后端 `DataBaseEnum.snapshot` + `SnapshotTableEnum` + `RumSnapshotMapper` / `RumSessionMapper`。

---

## 2. 全局对照总览（速查）

> 本章从 **业务域 / 菜单** 视角汇总 Gran 统计表、Snapshot 快照表与页面功能，便于全局检索。细节与接口说明见 §4（Gran）、§4B（公共 TopK）、§5（Snapshot）、§6（菜单索引）。

### 2.1 三库规模统计

| 库名 | 逻辑表族数 | QueryService 视图 | 典型查询方式 | 主要页面场景 |
|------|-----------|-------------------|--------------|--------------|
| `one_rum_datasource_gran` | **17** 个 `t_rum_*` + 1 联合视图 | `mv_t_rum_net_union_net_resource` | Metric API + `DataTableEnum` | **数字体验**列表/趋势/TopN/健康分 |
| `one_rum_datasource_snapshot` | **16** 张物理快照表族 | **18** 个 `*_view` + `t_rum_snapshot_event` | `SnapshotTableEnum` + `RumSnapshotMapper` / `RumSessionMapper` | **检索中心**列表/详情；会话时间线 |
| `one_common_datasource_gran` | **1** 个 `t_one_common_topk` | 无 | Zeus ETL 写入；平台 Metric/筛选（本仓库无直查） | 全平台 TopK / 筛选候选（RUM **无页面直查**） |

### 2.2 业务域 × 表 × 页面对照（主表）

| 业务域 | Gran 逻辑表族 | 主要 Snapshot 视图 | problemType | 数字体验（Gran 为主） | 检索中心（Snapshot 为主） | 备注 |
|--------|---------------|-------------------|-------------|----------------------|--------------------------|------|
| 网络业务请求 | `t_rum_net` | `t_rum_net_snapshot_view` | 1 | `/experience/request`、应用详情-业务请求 | `/observation/retrieval/request` | 检索中心**不查** Gran |
| 网络资源请求 | `t_rum_net_resource` | 同网络快照 | — | 网络请求-资源 Tab、应用详情 | — | Gran 与业务请求分表 |
| 网络汇总（兼容） | `mv_t_rum_net_union_net_resource` | — | — | 网络请求域名汇总 | — | Gran 视图，非物理表 |
| 自定义协议 / Span | `t_rum_span` | `t_rum_span_snapshot_view` | — | 网络请求-协议扩展 | 协议扩展检索、会话内 Span | |
| H5 / Web 页面 | `t_rum_h5` | `t_rum_h5_snapshot_view` | 2 | 页面分析 H5 Tab、应用详情 H5 | `/record/list/page`、页面加载详情 | |
| SPA 单页路由 | `t_rum_route` | — | — | 应用详情-单页面域名 | — | 仅 Gran |
| 原生视图启动 | `t_rum_view` | `t_rum_view_snapshot_view` | 9 | 页面分析-原生视图 Tab | `/record/list/view` | |
| 小程序页面 | `t_rum_mpview` | `t_rum_mpview_snapshot_view` | — | 页面分析-小程序 Tab | 无独立 Tab；会话时间线可出现 | |
| 用户操作 | `t_rum_action` | `t_rum_action_snapshot_view` | 10 | 应用详情-操作、操作分析（Gran） | `/operate` | |
| 应用启动 | `t_rum_launch` | `t_rum_launch_snapshot_view` | 8 | 应用启动详情 | `/record/list/application` | |
| 原生崩溃 | `t_rum_crash` | `t_rum_crash_snapshot_view` | 6 | 代码异常-崩溃 Tab | `/record/crash` | |
| ANR | `t_rum_anr` | `t_rum_anr_snapshot_view` | 4 | 代码异常-ANR Tab | `/record/anr` | |
| AppFreeze | `t_rum_appfreeze` | `t_rum_appfreeze_snapshot_view` | 12 | 代码异常-AppFreeze Tab | `/record/appfreeze` | 鸿蒙 |
| 卡顿 | `t_rum_lag` | `t_rum_lag_snapshot_view` | 5 | 代码异常-卡顿 Tab | `/record/lag` | |
| JS 错误 | `t_rum_jserror` | `t_rum_jserror_snapshot_view` | 3 | 代码异常-JS 错误 Tab | `/record/js` | |
| 自定义异常 | `t_rum_selfcrash` | `t_rum_selfcrash_snapshot_view` | 7 | 代码异常-自定义异常 Tab | `/record/custom/exception` | |
| 自定义事件 | — | `t_rum_customevent_snapshot_view` | 11 | — | `/record/custom/event` | 视图基于 `common_snapshot` |
| 能耗 / 进程 | `t_rum_battery` | `t_rum_battery_snapshot_view` | — | `/experience/electricityanalyse` | — | Gran+Snapshot 互补 |
| 终端 / 应用汇总 | `t_rum_terminal` | — | — | `/experience/application`、应用详情概览、健康分 | — | 应用级 Gran 汇总 |
| 用户会话 | —（列表不查 Gran） | `t_rum_session_view` | — | `/experience/user` | `/user/session` | **非** `t_rum_terminal` |
| 会话分钟聚合 | — | `t_rum_session_minute_*` | — | 同会话列表 | 同会话列表 | 可选辅助收窄时间 |
| 会话事件时间线 | — | `t_rum_snapshot_event` | — | 会话详情 | 会话详情 | UNION 各 snapshot view |
| 会话回放 | — | `t_rum_common_snapshot_view` | — | Session Replay | Session Replay | `type` 区分 REPLAY 等 |
| 公共 TopK | `t_one_common_topk` | — | — | 筛选器（间接） | 筛选器（间接） | 见 §4B；无页面直查 |

### 2.3 按前端菜单速查

#### 观测洞察 → 检索中心（**仅 Snapshot**）

| 菜单 / 路由 | Snapshot 主表 | Gran |
|-------------|---------------|------|
| 用户会话 | `t_rum_session_view` | — |
| 会话详情 | `t_rum_session_view` + `t_rum_snapshot_event` + 各 `*_snapshot_view` | — |
| 崩溃 / ANR / 卡顿 / JS / 自定义异常 / AppFreeze | 对应 `*_snapshot_view` | — |
| H5 / 视图 / 应用启动 | `t_rum_h5/view/launch_snapshot_view` | — |
| 用户操作 | `t_rum_action_snapshot_view` | — |
| 自定义事件 | `t_rum_customevent_snapshot_view` | — |
| 网络请求 | `t_rum_net_snapshot_view`（+ Span 见 `t_rum_span_snapshot_view`） | — |

接口：`/rest/rum/retrieve-center/record-list|record-stat`、`/rest/rum/problem/*/detail`、`/rest/rum/session/search/*`（详见 §6.1）。

#### 数字体验（**Gran 为主，详情可下钻 Snapshot**）

| 菜单 / 路由 | Gran 主表 | Snapshot（下钻/明细） |
|-------------|-----------|----------------------|
| 终端应用 | `t_rum_terminal` | — |
| 应用详情 | 按 Tab 多 Gran 表 | 各详情页 snapshot |
| 用户会话 | `t_rum_terminal`（汇总指标） | `t_rum_session_view` |
| 页面分析 | `t_rum_h5` / `t_rum_view` / `t_rum_mpview` / `t_rum_route` | `t_rum_mpview_snapshot_view` 等 |
| 代码异常 | `t_rum_crash` 等 6 类 Gran | 详情页 `*_snapshot_view` |
| 网络请求 | `t_rum_net`、`t_rum_net_resource`、联合视图 | `t_rum_net_snapshot_view` |
| 能耗分析 | `t_rum_battery` | `t_rum_battery_snapshot_view` |

接口：`/rest/rum/network/*`、`/rest/rum/app/*`、`/rest/rum/operation/*` 等 Metric 路径（详见 §4、§6.2）。

#### 部署配置（**非 CK 业务表**）

| 菜单 | 运行时 CK | 配置存储 |
|------|-----------|----------|
| 健康评分 | 计算读 `one_rum_datasource_gran` | MySQL `t_rum_config_*` |
| 数据采集 / 应用管理 | — | MySQL + CMDB |

### 2.4 数据源选用规则（一句话）

| 场景 | 选用 |
|------|------|
| 聚合列表、趋势、TopN、健康分 | **Gran**（`one_rum_datasource_gran`） |
| 检索中心记录列表、Tab 统计、单条快照详情 | **Snapshot**（`one_rum_datasource_snapshot`） |
| 用户会话列表 / 会话状态判定 | **Snapshot** `t_rum_session_view`（不是 `t_rum_terminal`） |
| 会话详情多事件时间线 | **Snapshot** `t_rum_snapshot_event` + 各 `*_snapshot_view` |
| 筛选器维度 TopK 候选 | **公共 TopK**（可能，经 Metric 引擎；见 §4B） |
| 健康评分规则配置 | **MySQL**；运行时指标仍来自 Gran |

### 2.5 Gran 逻辑表族清单（17 + 1 视图）

| # | 逻辑表族 / 视图 | 业务域 |
|---|----------------|--------|
| 1 | `t_rum_net` | 网络业务请求 |
| 2 | `t_rum_net_resource` | 网络资源 |
| 3 | `mv_t_rum_net_union_net_resource` | 网络联合视图 |
| 4 | `t_rum_h5` | H5 页面 |
| 5 | `t_rum_route` | SPA 路由 |
| 6 | `t_rum_view` | 原生视图 |
| 7 | `t_rum_mpview` | 小程序页面 |
| 8 | `t_rum_action` | 用户操作 |
| 9 | `t_rum_launch` | 应用启动 |
| 10 | `t_rum_crash` | 崩溃 |
| 11 | `t_rum_anr` | ANR |
| 12 | `t_rum_appfreeze` | AppFreeze |
| 13 | `t_rum_lag` | 卡顿 |
| 14 | `t_rum_jserror` | JS 错误 |
| 15 | `t_rum_selfcrash` | 自定义异常 |
| 16 | `t_rum_span` | 自定义协议 |
| 17 | `t_rum_battery` | 能耗 |
| 18 | `t_rum_terminal` | 终端/应用汇总 |

### 2.6 Snapshot 查询视图清单（18）

| # | QueryService 视图 | 对应物理表族 | problemType |
|---|-------------------|-------------|-------------|
| 1 | `t_rum_net_snapshot_view` | `t_rum_net_snapshot` | 1 |
| 2 | `t_rum_h5_snapshot_view` | `t_rum_h5_snapshot` | 2 |
| 3 | `t_rum_jserror_snapshot_view` | `t_rum_jserror_snapshot` | 3 |
| 4 | `t_rum_anr_snapshot_view` | `t_rum_anr_snapshot` | 4 |
| 5 | `t_rum_lag_snapshot_view` | `t_rum_lag_snapshot` | 5 |
| 6 | `t_rum_crash_snapshot_view` | `t_rum_crash_snapshot` | 6 |
| 7 | `t_rum_selfcrash_snapshot_view` | `t_rum_selfcrash_snapshot` | 7 |
| 8 | `t_rum_launch_snapshot_view` | `t_rum_launch_snapshot` | 8 |
| 9 | `t_rum_view_snapshot_view` | `t_rum_view_snapshot` | 9 |
| 10 | `t_rum_action_snapshot_view` | `t_rum_action_snapshot` | 10 |
| 11 | `t_rum_customevent_snapshot_view` | `t_rum_customevent_snapshot` | 11 |
| 12 | `t_rum_appfreeze_snapshot_view` | `t_rum_appfreeze_snapshot` | 12 |
| 13 | `t_rum_common_snapshot_view` | `t_rum_common_snapshot` | — |
| 14 | `t_rum_span_snapshot_view` | `t_rum_span_snapshot` | — |
| 15 | `t_rum_mpview_snapshot_view` | `t_rum_mpview_snapshot` | — |
| 16 | `t_rum_battery_snapshot_view` | `t_rum_battery_snapshot` | — |
| 17 | `t_rum_session_view` | 会话宽表（聚合 `t_rum_session`） | — |
| 18 | `t_rum_snapshot_event` | 会话时间线 UNION | — |

另：`t_rum_session_minute_*` 为会话 MV 物理表，非 QueryService 视图，见 §5.17。

---

## 3. 表族命名与物理结构

### 3.1 Gran 统计表（`one_rum_datasource_gran`）

每个 **逻辑表族**（`zeus_topic`，如 `t_rum_net`）在 DDL 中通常包含：

| 后缀 | 说明 |
|------|------|
| `_local` | 本地 MergeTree 写入表 |
| 无后缀 / `_distributed` / `_distributed2` | 分布式查询入口 |
| `_minute` / `_hour` / `_day` | 时间 rollup 物理表 + 对应 MV |
| `mv_t_rum_*` | ClickHouse 物化视图（内部 rollup，无独立页面） |

### 3.2 Snapshot 快照表（`one_rum_datasource_snapshot`）

每个 **快照表族** 通常包含：

| 后缀 | 说明 |
|------|------|
| `_local` | 本地写入表 |
| `_distributed` / `_distributed2` | 分布式表 |
| `_buffer` | 仅 `t_rum_session_minute` 使用，承接 MV 写入 |
| `*_view` | QueryService 注册视图（**业务查询入口**） |

### 3.3 会话专用链路

```
各 t_rum_*_snapshot_local
  → MV → t_rum_session_minute_local / buffer
  → QueryService 虚拟表 t_rum_session
  → t_rum_session_view（列表/筛选/会话状态判定）
```

并行：`t_rum_snapshot_event` 为各 snapshot view 的 UNION，供**会话详情时间线**使用。

---

## 4. Gran 统计表全集与页面映射

> 共 **17** 个 `zeus_topic` 逻辑表族 + **1** 个 Gran 联合视图。
> 下列「物理变体」均指 `{表族}`、`{表族}_minute`、`{表族}_hour`、`{表族}_day` 及对应 `_local/_distributed*`。

### 4.1 `t_rum_net` — 网络业务请求

| 项 | 内容 |
|----|------|
| **说明** | 业务 HTTP/HTTPS 请求聚合（域名、URL、状态码、耗时、错误率等） |
| **指标前缀** | `one.rum.net.businessRequest.*` |
| **DataTableEnum** | `network`、`network_outside` |
| **后端** | `NetWorkController`（`/rest/rum/network`）、`NetWorkService`、`RumMetricNetMapper` |
| **页面功能** | **数字体验 → 网络请求**（`/experience/request`）及域名/请求详情 |
| | **数字体验 → 终端应用 → 应用详情 → 业务请求域名/详情** |
| | 健康评分-网络请求（`/deploy/config/score/healthy`，指标来自 Gran） |
| | > 检索中心「网络请求」列表/详情走 Snapshot（`t_rum_net_snapshot_view`），**不查本 Gran 表**，见 §5.1、§6.1 |

### 4.2 `t_rum_net_resource` — 网络资源请求

| 项 | 内容 |
|----|------|
| **说明** | 静态资源/CDN 等资源类请求（含 `meta_type` 等维度） |
| **指标前缀** | `one.rum.net.resourceRequest.*` |
| **DataTableEnum** | `network_resource`、`network_resource_outside` |
| **后端** | 同 `t_rum_net` 网络模块 |
| **页面功能** | **数字体验 → 网络请求 → 资源请求域名/详情** |
| | **应用详情 → 资源请求域名/详情** |

### 4.3 `mv_t_rum_net_union_net_resource` — 业务+资源联合视图（Gran）

| 项 | 内容 |
|----|------|
| **类型** | QueryService 视图（非物理写入表） |
| **说明** | 联合 `t_rum_net` 与 `t_rum_net_resource`，兼容历史 `one.rum.net.request.*` 指标 |
| **指标前缀** | `one.rum.net.request.*`（兼容） |
| **页面功能** | **数字体验 → 网络请求** 汇总域名列表（Metric 引擎自动路由） |

### 4.4 `t_rum_h5` — H5/Web 页面加载

| 项 | 内容 |
|----|------|
| **说明** | Web 页面 PV、加载耗时、白屏、首屏等 |
| **指标前缀** | `one.rum.page.h5.*` |
| **DataTableEnum** | `h5`、`page_analysis_app_h5` |
| **后端** | `AppPageService`、`AppDetailService`、terminal/druid 包 |
| **页面功能** | **数字体验 → 页面分析**（H5 Tab） |
| | **应用详情 → H5 页面域名** |
| | 健康评分-页面（H5/Web） |
| | > 检索中心 H5 页面加载列表/详情走 `t_rum_h5_snapshot_view`，见 §5.2、§6.1 |

### 4.5 `t_rum_route` — SPA 单页路由

| 项 | 内容 |
|----|------|
| **说明** | 单页应用路由切换、域名维度 |
| **指标前缀** | `one.rum.page.singlePage.*` |
| **DataTableEnum** | `route`、`single_route` |
| **后端** | `AppPageService` |
| **页面功能** | **应用详情 → 单页面域名**（`/experience/application/detail/single/...`） |

### 4.6 `t_rum_view` — 原生视图启动

| 项 | 内容 |
|----|------|
| **说明** | Activity / ViewController 等原生视图启动指标 |
| **指标前缀** | `one.rum.page.view.*` |
| **DataTableEnum** | `view`、`page_analysis_native_view` |
| **后端** | `AppDetailService`、`AppViewController` |
| **页面功能** | **数字体验 → 页面分析**（原生视图 Tab） |
| | 健康评分-视图 |
| | > 检索中心原生视图启动列表/详情走 `t_rum_view_snapshot_view`，见 §5.9、§6.1 |

### 4.7 `t_rum_mpview` — 小程序页面

| 项 | 内容 |
|----|------|
| **说明** | 小程序页面 PV、JS 错误率等 |
| **指标前缀** | `one.rum.page.mpView.*` |
| **DataTableEnum** | `mp_view`、`page_analysis_mp_view` |
| **后端** | `MiniProgramService` |
| **页面功能** | **数字体验 → 页面分析**（小程序 Tab） |
| | **部署配置 → 健康评分 → MP 应用** |

### 4.8 `t_rum_action` — 用户操作

| 项 | 内容 |
|----|------|
| **说明** | 操作健康度、慢操作、嵌套网络错误等 |
| **指标前缀** | `one.rum.action.*` |
| **DataTableEnum** | `action` |
| **后端** | `OperationController`（`/rest/rum/operation`）、`OperationService` |
| **页面功能** | **应用详情 → 操作详情** |
| | **操作分析详情**（数字体验侧 Gran 统计；检索中心操作列表/详情走 Snapshot） |
| | 健康评分-操作 |
| | > 检索中心用户操作走 `t_rum_action_snapshot_view`（`problemType=10`），见 §5.10、§6.1 |

### 4.9 `t_rum_launch` — 应用启动

| 项 | 内容 |
|----|------|
| **说明** | 冷启动/热启动耗时与次数 |
| **指标前缀** | `one.rum.app.launch.*` |
| **DataTableEnum** | `launch` |
| **后端** | `AppDetailService` |
| **页面功能** | **应用启动详情**（数字体验/应用详情 Gran 统计） |
| | > 检索中心应用启动列表/详情走 `t_rum_launch_snapshot_view`，见 §5.8、§6.1 |

### 4.10 `t_rum_crash` — 原生崩溃

| 项 | 内容 |
|----|------|
| **说明** | 崩溃次数、影响用户/会话 |
| **指标前缀** | `one.rum.app.crash.*` |
| **DataTableEnum** | `crash` |
| **后端** | `ProblemController`、`ProblemDetailController` |
| **页面功能** | **数字体验 → 代码异常**（崩溃 Tab） |
| | **应用详情 → 崩溃详情** |
| | > 检索中心崩溃记录列表/详情走 `t_rum_crash_snapshot_view`，见 §5.6、§6.1 |

### 4.11 `t_rum_anr` — ANR

| 项 | 内容 |
|----|------|
| **指标前缀** | `one.rum.app.anr.*` |
| **DataTableEnum** | `anr` |
| **页面功能** | **代码异常 → ANR**、**ANR 详情**（Gran 统计） |
| | > 检索中心 ANR 记录列表/详情走 `t_rum_anr_snapshot_view`，见 §5.4、§6.1 |

### 4.12 `t_rum_appfreeze` — AppFreeze（鸿蒙）

| 项 | 内容 |
|----|------|
| **指标前缀** | `one.rum.app.appFreeze.*` |
| **DataTableEnum** | `appfreeze` |
| **页面功能** | **代码异常 → AppFreeze**（Gran 统计） |
| | > 检索中心 AppFreeze 记录走 `t_rum_appfreeze_snapshot_view`，见 §5.13、§6.1 |

### 4.13 `t_rum_lag` — 卡顿

| 项 | 内容 |
|----|------|
| **指标前缀** | `one.rum.app.lag.*` |
| **DataTableEnum** | `lag` |
| **页面功能** | **代码异常 → 卡顿**（Gran 统计） |
| | > 检索中心卡顿记录走 `t_rum_lag_snapshot_view`，见 §5.5、§6.1 |

### 4.14 `t_rum_jserror` — JS 错误

| 项 | 内容 |
|----|------|
| **指标前缀** | `one.rum.app.JSerror.*`、`one.rum.page.*.JSerrorRatio` |
| **DataTableEnum** | `js_error` |
| **页面功能** | **代码异常 → JS 错误**（Gran 统计） |
| | > 检索中心 JS 错误记录走 `t_rum_jserror_snapshot_view`，见 §5.3、§6.1 |

### 4.15 `t_rum_selfcrash` — 自定义异常

| 项 | 内容 |
|----|------|
| **指标前缀** | `one.rum.app.customError.*` |
| **DataTableEnum** | `selfCrash` |
| **页面功能** | **代码异常 → 自定义异常**（Gran 统计） |
| | > 检索中心自定义异常走 `t_rum_selfcrash_snapshot_view`，见 §5.7、§6.1 |

### 4.16 `t_rum_span` — 自定义协议 / Span 请求

| 项 | 内容 |
|----|------|
| **说明** | Socket/WebSocket 等自定义协议扩展请求 |
| **指标前缀** | `one.rum.net.custom.*` |
| **DataTableEnum** | `span_table`、`custom_socket_request` |
| **后端** | `RumCustomSocketServiceImpl`、`RumQueryNetMapper` |
| **页面功能** | **数字体验 → 网络请求 → 协议扩展域名** |
| | **应用详情 → 协议详情** |

### 4.17 `t_rum_battery` — 能耗/进程指标

| 项 | 内容 |
|----|------|
| **说明** | 流量、定位、WakeLock 等进程级能耗 |
| **指标前缀** | `one.rum.app.process.*` |
| **DataTableEnum** | `coulometry` |
| **后端** | `CoulometryController`（`/rest/rum/coulometry`）、`RumMetricBatteryMapper` |
| **页面功能** | **数字体验 → 能耗分析**（`/experience/electricityanalyse`） |

### 4.18 `t_rum_terminal` — 终端/应用汇总

| 项 | 内容 |
|----|------|
| **说明** | 应用级会话数、活跃用户、时长、健康分等汇总 |
| **指标前缀** | `one.rum.app.session.*`、`one.rum.app.userOperation.*`、`one.rum.app.terminal.*` |
| **DataTableEnum** | `app_table`、`user_member` |
| **后端** | `AppController`（`/rest/rum/app`）、`HealthScoreServer`、`AppService` |
| **页面功能** | **数字体验 → 终端应用**（应用列表/健康分/趋势） |
| | **终端应用 → 应用详情**（概览、指标图表） |
| | 健康评分-各平台应用（Android/iOS/H5/MP 等） |

### 4.19 无独立 RUM 页面的 Gran 对象

| 对象 | 说明 |
|------|------|
| `{表族}_minute/_hour/_day` 物理表 | Metric 引擎内部按时间范围路由，Java 不硬编码 |
| `mv_t_rum_*` rollup MV | ClickHouse 内部 rollup，无 UI |

---

## 4B. 公共 Gran 库 `one_common_datasource_gran`（TopK 数据源）

> **脚本**：`script/one_framework_rum/INIT/clickhouse/all/one_common_datasource_gran.sql`（与 RUM Gran/Snapshot 同批由 `all/all.sh` 部署，库注释为「topK数据源」）
> **与 RUM 关系**：属 **ONE 平台公共库**，非 `one_rum_datasource_gran` 业务指标表；本仓库 `framework/plugins/rum`、`view/rum` **未发现**对该库表名的直接 SQL/Java 引用。

### 4B.1 库与表族概览

| 项 | 内容 |
|----|------|
| **库名** | `one_common_datasource_gran` |
| **逻辑表族** | `t_one_common_topk`（仅此 1 个 `zeus_topic`） |
| **设计目的** | 按「产品 + 分类 + 维度模块 + 维度值」预聚合出现次数，为 **TopK / 筛选候选值** 提供轻量查询（TTL 3 天，分钟粒度） |
| **写入** | Zeus Ingest：`zeus_topic = t_one_common_topk`，`zeus_offline_topic = t_one_common_topk_offline`（3.1.8.5+）→ `t_one_common_topk_local`（`ENGINE=Null`）→ MV → `t_one_common_topk_minute_local` |
| **读取（本仓库）** | **无** Mapper/Controller 直查；消费方应在 **Zeus ETL / QueryService / TitanQuery** 等平台层（代码不在本 monorepo） |

### 4B.2 字段语义

| 字段 | 类型 | 说明 |
|------|------|------|
| `monitor_time` | DateTime | 监控时间（MV rollup 为分钟起点） |
| `product_name` | String | 产品名称（如 RUM 对应 `rum` 等产品标识，由 ETL 写入） |
| `type` | String | 分类（DDL 注释「分类」；可能区分 filter/dimension 等 TopK 场景，**具体枚举未在本仓库文档化**） |
| `key_name` | String | 统计模块 / 维度或筛选项标识 |
| `key_value` | String | 统计值 / 维度取值 |
| `num` | Int64 | 出现次数；`-99999` 为无效哨兵值，MV 中 `sumOrNullStateIf` 会过滤 |

**主键 / 分片**：`(product_name, type, key_name, key_value, monitor_time)`；分布式表按 `farmHash64(concat(toStartOfDay(monitor_time), product_name, type, key_name, key_value))` 分片。

### 4B.3 物理对象清单

| 对象 | 引擎 / 类型 | 作用 |
|------|-------------|------|
| `t_one_common_topk_local` | Null + Zeus topic | Zeus 在线/离线写入入口 |
| `t_one_common_topk_distributed` / `_distributed2` | Distributed | 集群查询/写入路由 |
| `t_one_common_topk_minute_local` | ReplicatedAggregatingMergeTree | 分钟聚合存储，TTL 3 天 |
| `t_one_common_topk_minute_distributed` / `_distributed2` | Distributed | 分钟表分布式入口 |
| `mv_t_one_common_topk_minute` | Materialized View | `t_one_common_topk_local` → 分钟表，`sumOrNullStateIf(num, num != -99999)` |

> 历史版本曾使用 `t_one_common_topk_minute_buffer`（Buffer 引擎）；4.0.0.0 全量脚本改为 MV 直写 `_minute_local`。POC 环境见 `one_common_datasource_gran_poc.sql`（表名无 `_local` 后缀）。

### 4B.4 数据流（写入）

```
ETL / Zeus Ingester（本仓库无 producer 实现）
  → Kafka: t_one_common_topk / t_one_common_topk_offline
  → ClickHouse: t_one_common_topk_local (Null)
  → mv_t_one_common_topk_minute
  → t_one_common_topk_minute_local（查询用）
```

### 4B.5 与 RUM 页面 / 功能的对应关系

| 对应层级 | 说明 |
|----------|------|
| **页面直查** | **无**。RUM 列表/详情/图表均走 `one_rum_datasource_gran` 或 `one_rum_datasource_snapshot`，不 SQL 直读 `t_one_common_topk*`。 |
| **间接关联（筛选器）** | RUM 各页「筛选面板」调用 `POST /rest/rum/filter/query`（`FilterService`）。其中 `DataBaseEnum.metric` 类筛选项经 `FilterMapper.queryMetric` 查 `"metric"."data"`（Metric/TitanQuery），**非**本表硬编码；TopK 表是否作为 Metric 引擎底层数据源取决于平台 Zeus 配置，本仓库无法从代码确认。 |
| **可能受益的 RUM 页面（筛选器场景）** | 凡带全局/页面筛选的模块均可能间接使用平台 TopK 能力，例如：**数字体验**（终端应用、页面分析、代码异常、网络请求、能耗等）、**检索中心**（用户会话、各记录列表、网络请求、用户操作等）。具体维度是否走 TopK 表由 ETL 的 `product_name` + `type` + `key_name` 注册决定。 |
| **健康评分** | 运行时读 **`one_rum_datasource_gran`** + MySQL 规则（`HealthScoreServer`、`t_basic_formula_config.storage_configure like 'one_rum_datasource_gran%'`），**不依赖**本公共 TopK 库。 |

### 4B.6 本仓库可定位的相关代码（非 TopK 表本身）

| 用途 | 路径 |
|------|------|
| RUM 筛选器入口 | `rum-core/.../FilterController.java`、`FilterService.java` |
| 筛选项 Metric 查询 | `rum-database/.../FilterMapper.xml`（`queryMetric` → `"metric"."data"`） |
| 筛选项 Snapshot/QueryService 查询 | 同上（`queryService` → 各 `*_snapshot_view` / `t_rum_session_view`） |
| CK 全量部署 | `script/one_framework_rum/INIT/clickhouse/all/all.sh` |
| 结构演进 | `script/one_framework_rum/INIT/clickhouse/3.0.0.3/rum.sql`（首次引入）→ `3.1.8.5`（offline topic）→ `4.0.0.0`（distributed2 + 去 buffer） |

### 4B.7 维护说明

1. 本库随 RUM ClickHouse 初始化脚本一并创建，但服务于 **全平台 TopK**，变更需评估对 APM/Analysis 等其他产品线的影响。
2. 新增 RUM 维度 TopK 写入应在 **Zeus ETL / Ingester** 侧配置 `product_name` 与 `key_name`，而非在 `rum-core` 增加直写 SQL。
3. 若需确认某筛选项是否读本表，需在部署环境查 Zeus 元数据 / Ingester 配置（本 monorepo 无完整 producer 代码）。

---

## 5. Snapshot 快照表全集与页面映射

> 共 **16** 张物理快照表族 + **QueryService 视图层**。
> 业务查询以 `*_view` 为准；物理 `_local` 表主要供写入与 MV 源。

### 5.1 `t_rum_net_snapshot` → `t_rum_net_snapshot_view`

| 项 | 内容 |
|----|------|
| **SnapshotTableEnum** | `NET_SNAPSHOT`（problemType=1） |
| **后端** | `RumSnapshotMapper.queryDataOfRetrievalCenterByNet`、`RetrievalService` |
| **页面功能** | **检索中心 → 网络请求**（列表/详情） |
| | **会话详情**内嵌网络事件 |
| | OpenAPI 网络快照查询 |

### 5.2 `t_rum_h5_snapshot` → `t_rum_h5_snapshot_view`

| 项 | 内容 |
|----|------|
| **SnapshotTableEnum** | `H5_SNAPSHOT`（2） |
| **页面功能** | **检索中心 → H5 页面加载** |
| | **Web/App 页面加载详情**（`/observation/retrieval/web|app/:id`） |

### 5.3 `t_rum_jserror_snapshot` → `t_rum_jserror_snapshot_view`

| 项 | 内容 |
|----|------|
| **SnapshotTableEnum** | `JS_ERROR_SNAPSHOT`（3） |
| **页面功能** | **检索中心 → JS 错误记录**及详情 |

### 5.4 `t_rum_anr_snapshot` → `t_rum_anr_snapshot_view`

| 项 | 内容 |
|----|------|
| **SnapshotTableEnum** | `ANR_SNAPSHOT`（4） |
| **页面功能** | **检索中心 → ANR 记录**及详情 |

### 5.5 `t_rum_lag_snapshot` → `t_rum_lag_snapshot_view`

| 项 | 内容 |
|----|------|
| **SnapshotTableEnum** | `LAG_SNAPSHOT`（5） |
| **页面功能** | **检索中心 → 卡顿记录**及详情 |

### 5.6 `t_rum_crash_snapshot` → `t_rum_crash_snapshot_view`

| 项 | 内容 |
|----|------|
| **SnapshotTableEnum** | `CRASH_SNAPSHOT`（6） |
| **页面功能** | **检索中心 → 崩溃记录**及详情 |
| | 堆栈符号化（`RumSymbolicController`，关联 snapshot 文件字段） |

### 5.7 `t_rum_selfcrash_snapshot` → `t_rum_selfcrash_snapshot_view`

| 项 | 内容 |
|----|------|
| **SnapshotTableEnum** | `SELF_CRASH_SNAPSHOT`（7） |
| **页面功能** | **检索中心 → 自定义异常**及详情 |

### 5.8 `t_rum_launch_snapshot` → `t_rum_launch_snapshot_view`

| 项 | 内容 |
|----|------|
| **SnapshotTableEnum** | `LAUNCH_SNAPSHOT`（8） |
| **页面功能** | **检索中心 → 应用启动**及详情 |

### 5.9 `t_rum_view_snapshot` → `t_rum_view_snapshot_view`

| 项 | 内容 |
|----|------|
| **SnapshotTableEnum** | `VIEW_SNAPSHOT`（9） |
| **页面功能** | **检索中心 → 原生视图启动**及详情 |

### 5.10 `t_rum_action_snapshot` → `t_rum_action_snapshot_view`

| 项 | 内容 |
|----|------|
| **SnapshotTableEnum** | `ACTION_SNAPSHOT`（10） |
| **页面功能** | **检索中心 → 用户操作**（列表/详情） |
| | **操作分析详情**（检索侧为 Snapshot 快照明细） |

### 5.11 `t_rum_common_snapshot` → `t_rum_common_snapshot_view`

| 项 | 内容 |
|----|------|
| **说明** | 通用快照容器（`type` 区分 REPLAY、STATE_CHANGE 等） |
| **后端** | `RumSessionReplayMapper`、`RumSessionReplayController` |
| **页面功能** | **会话回放（Session Replay）** |
| | 间接支撑部分系统/状态类事件 |

> 自定义事件不直接查裸表，见 5.12。

### 5.12 `t_rum_customevent_snapshot` → `t_rum_customevent_snapshot_view`

| 项 | 内容 |
|----|------|
| **视图定义** | 基于 `t_rum_common_snapshot`，过滤 `type='CUSTOM_EVENT'` |
| **SnapshotTableEnum** | `CUSTOM_EVENT_SNAPSHOT`（11） |
| **页面功能** | **检索中心 → 自定义事件**及详情 |

### 5.13 `t_rum_appfreeze_snapshot` → `t_rum_appfreeze_snapshot_view`

| 项 | 内容 |
|----|------|
| **SnapshotTableEnum** | `APP_FREEZE_SNAPSHOT`（12） |
| **页面功能** | **检索中心 → AppFreeze 记录**及详情 |
| | 代码异常 AppFreeze 详情（problemType 与快照枚举有映射特例） |

### 5.14 `t_rum_span_snapshot` → `t_rum_span_snapshot_view`

| 项 | 内容 |
|----|------|
| **后端** | `RumQueryNetMapper`、`RumSessionMapper`（会话内 Span） |
| **DataTableEnum** | `retrieval_custom_socket_request` |
| **页面功能** | **会话详情**中的自定义协议/Span 事件 |
| | 协议扩展相关检索 |

### 5.15 `t_rum_mpview_snapshot` → `t_rum_mpview_snapshot_view`

| 项 | 内容 |
|----|------|
| **说明** | 小程序页面快照；检索中心无独立 Tab |
| **页面功能** | **页面分析**（小程序维度，间接） |
| | 会话时间线中可能出现的小程序页面事件 |

### 5.16 `t_rum_battery_snapshot` → `t_rum_battery_snapshot_view`

| 项 | 内容 |
|----|------|
| **后端** | `RumMetricBatteryMapper`、`CoulometryServiceImpl` |
| **页面功能** | **数字体验 → 能耗分析**（明细/下钻，与 Gran 指标互补） |

### 5.17 `t_rum_session_minute` — 会话分钟聚合（物理表）

| 项 | 内容 |
|----|------|
| **说明** | AggregatingMergeTree；由各 snapshot MV 汇总写入 |
| **物理变体** | `_local`、`_buffer`、`_distributed`、`_distributed2` |
| **fedBy** | `mv_t_rum_*_snapshot_to_t_rum_session_minute_local` 等系列 MV |
| **后端** | `RumCkSessionService`、`RumSessionMapper` |
| **页面功能** | 可选辅助：无筛选时收窄会话列表 `startTime`（Nacos 开关 `session.list.start.time.limit.query.enabled`） |
| | 主链路仍经 `t_rum_session_view` 聚合字段，见 §5.18 |

### 5.18 `t_rum_session_view` — 会话宽表视图（QueryService）

| 项 | 内容 |
|----|------|
| **类型** | 视图（底层 finalize `t_rum_session` 聚合状态） |
| **后端** | `RumSessionMapper`（大量 SQL）、`SessionSearchController`、`RumCkSessionSearchService`、`FilterService` |
| **DataTableEnum** | `session`、`search_session` |
| **页面功能** | **观测洞察 → 检索中心 → 用户会话** |
| | **数字体验 → 用户会话** |
| | **会话详情**头信息（`queryBaseCount`：isHealth/会话状态） |
| | 用户详情中的会话列表 |

### 5.19 `t_rum_snapshot_event` — 会话事件时间线视图（QueryService）

| 项 | 内容 |
|----|------|
| **说明** | UNION ALL 各 `*_snapshot_view`（`sessionFlag=1`） |
| **后端** | `RumSessionMapper` |
| **页面功能** | **会话详情 → 事件时间线**（多类型事件混排） |

---

## 6. 按前端菜单索引（页面 → 主要 CK 表）

### 6.1 观测洞察 → 检索中心

> **数据源约定（重要）**
> 检索中心列表、Tab 统计、快照详情**统一走 Snapshot**，不查 Gran 统计表。
> - 列表 / 统计：`POST /rest/rum/retrieve-center/record-list`、`record-stat` → `RetrievalService` / `RetrievalRepository` → `DataBaseEnum.snapshot` + `SnapshotTableEnum` + `RumSnapshotMapper`
> - 快照详情：`POST /rest/rum/problem/*/detail` 等 → `RetrievalService.querySnapshotDetail`
> - 用户会话：`POST /rest/rum/session/search/sessionList` 等 → `RumSessionMapper` → `t_rum_session_view`（**非** `t_rum_terminal` Gran）
> 与 **数字体验**（`/experience/*`）的 Gran 聚合查询路径不同，勿混用下表与 §4 Gran 章节。

| 页面路由 | 中文名称 | 主要 Snapshot 表/视图 | 典型后端接口 |
|----------|----------|----------------------|--------------|
| `/observation/retrieval/user/session` | 用户会话 | `t_rum_session_view`（可选 `t_rum_session_minute_*` 辅助收窄时间） | `/rest/rum/session/search/sessionList` |
| `/observation/retrieval/user/session/detail/:id` | 会话详情 | `t_rum_session_view`、`t_rum_snapshot_event`、各 `*_snapshot_view` | `/rest/rum/session/search/*` |
| `/observation/retrieval/record/crash` | 崩溃记录 | `t_rum_crash_snapshot_view` | `record-list` / `record-stat`，`problemType=6` |
| `/observation/retrieval/record/anr` | ANR 记录 | `t_rum_anr_snapshot_view` | `problemType=4` |
| `/observation/retrieval/record/appfreeze` | AppFreeze | `t_rum_appfreeze_snapshot_view` | `problemType=12` |
| `/observation/retrieval/record/lag` | 卡顿记录 | `t_rum_lag_snapshot_view` | `problemType=5` |
| `/observation/retrieval/record/js` | JS 错误 | `t_rum_jserror_snapshot_view` | `problemType=3` |
| `/observation/retrieval/record/custom/exception` | 自定义异常 | `t_rum_selfcrash_snapshot_view` | `problemType=7` |
| `/observation/retrieval/record/custom/event` | 自定义事件 | `t_rum_customevent_snapshot_view` | `problemType=11` |
| `/observation/retrieval/operate` | 用户操作 | `t_rum_action_snapshot_view` | `problemType=10` |
| `/observation/retrieval/record/list/page` | H5 页面加载 | `t_rum_h5_snapshot_view` | `problemType=2` |
| `/observation/retrieval/record/list/view` | 原生视图启动 | `t_rum_view_snapshot_view` | `problemType=9` |
| `/observation/retrieval/record/list/application` | 应用启动 | `t_rum_launch_snapshot_view` | `problemType=8` |
| `/observation/retrieval/request` | 网络请求 | `t_rum_net_snapshot_view`（HTTP/HTTPS）；协议扩展另见 `t_rum_span_snapshot_view` | `problemType=1`；详情 `/rest/rum/problem/net/detail` |

### 6.2 数字体验

| 页面路由 | 中文名称 | Gran 统计表 | Snapshot 快照表/视图 |
|----------|----------|-------------|-------------------|
| `/experience/application` | 终端应用 | `t_rum_terminal` | — |
| `/experience/application/detail/:appId` | 应用详情 | 多表（按 Tab） | 详情下钻用 snapshot |
| `/experience/user` | 用户会话 | `t_rum_terminal` | `t_rum_session_view` |
| `/experience/page/analysis` | 页面分析 | `t_rum_h5`、`t_rum_view`、`t_rum_mpview`、`t_rum_route` | `t_rum_mpview_snapshot_view`（间接） |
| `/experience/breakdown` | 代码异常 | `t_rum_crash/anr/lag/jserror/selfcrash/appfreeze` | 对应 `*_snapshot_view`（详情页） |
| `/experience/request` | 网络请求 | `t_rum_net`、`t_rum_net_resource`、`mv_t_rum_net_union_net_resource` | `t_rum_net_snapshot_view` |
| `/experience/electricityanalyse` | 能耗分析 | `t_rum_battery` | `t_rum_battery_snapshot_view` |

### 6.3 部署配置（与 CK 弱相关）

| 页面路由 | 中文名称 | 数据存储 |
|----------|----------|----------|
| `/deploy/config/score/healthy/*` | 健康评分配置 | **MySQL**（`t_rum_config_score_rule` / `t_rum_config_rule`），非 CK 表 |
| `/deploy/config/collection/*` | 数据采集配置 | MySQL |
| `/deploy/manage/application` | 应用管理 | MySQL + CMDB |

> 健康评分**运行时计算**读取 Gran 指标；**用户会话满意度**（class_type=60）读 MySQL 规则 + Snapshot 会话聚合字段。

---

## 7. 后端关键代码索引

| 用途 | 路径 |
|------|------|
| Gran 过滤表枚举 | `rum-common/.../DataTableEnum.java` |
| Snapshot problemType → 视图 | `rum-database/.../SnapshotTableEnum.java` |
| 检索快照 SQL | `rum-database/.../RumSnapshotMapper.xml` |
| 会话 SQL | `rum-database/.../RumSessionMapper.xml` |
| 网络 Gran/Snapshot | `rum-database/.../RumQueryNetMapper.xml`、`RumMetricNetMapper.xml` |
| 能耗 | `rum-database/.../RumMetricBatteryMapper.xml` |
| 会话列表/判定 | `rum-core/.../RumCkSessionService.java`、`RumCkSessionSearchService.java` |
| 检索中心 | `rum-core/.../retrieval/`、`RetrievalController` |
| 健康分（Gran） | `rum-core/.../HealthScoreServer.java` |
| RUM 筛选器 | `rum-core/.../FilterController.java`、`FilterService.java`；`rum-database/.../FilterMapper.xml` |
| 公共 TopK CK DDL | `script/one_framework_rum/INIT/clickhouse/all/one_common_datasource_gran.sql` |
| 前端路由 | `view/rum/src/routes/route.ts` |

---

## 8. QueryService 注册视图清单

来自 `one_rum_queryservice_view.sql`（snapshot 库）：

- `t_rum_action_snapshot_view`
- `t_rum_anr_snapshot_view`
- `t_rum_appfreeze_snapshot_view`
- `t_rum_battery_snapshot_view`
- `t_rum_common_snapshot_view`
- `t_rum_crash_snapshot_view`
- `t_rum_customevent_snapshot_view`
- `t_rum_h5_snapshot_view`
- `t_rum_jserror_snapshot_view`
- `t_rum_lag_snapshot_view`
- `t_rum_launch_snapshot_view`
- `t_rum_mpview_snapshot_view`
- `t_rum_net_snapshot_view`
- `t_rum_selfcrash_snapshot_view`
- `t_rum_session_view`
- `t_rum_span_snapshot_view`
- `t_rum_view_snapshot_view`
- `t_rum_snapshot_event`（会话时间线 UNION 视图）

Gran 库（`one_rum_datasource_gran`）额外视图：

- `mv_t_rum_net_union_net_resource`

公共 TopK 库（`one_common_datasource_gran`）**无 QueryService 视图**，仅物理表 + MV，见 §4B.3。

---

## 9. Gran 表入数据逻辑：以 `t_rum_h5` 为例

本节以 `one_rum_datasource_gran` 库中 `t_rum_h5` 表族为例，详述 Gran 表的入数据链路。其他 Gran 表族（如 `t_rum_net`、`t_rum_view` 等）走相同的 ingester-rum 框架，仅策略类、列定义、Zeus 转换类不同。

### 9.1 表与数据源的绑定关系

枚举 `EtlBizTypeEnum.RUM_DRU_STAT_H5` 声明了物理表名、逻辑数据源及列定义类的绑定：

```java
// ingester-operator: EtlBizTypeEnum.java
RUM_DRU_STAT_H5("t_rum_h5", "one_rum_datasource_gran", CkH5.getColumns(CkH5.class), CkH5.dataSource, CkH5.class)
```

| 属性 | 值 |
|------|------|
| **物理表名** | `t_rum_h5` |
| **逻辑数据源** | `one_rum_datasource_gran`（对应 ClickHouse 库/集群命名约定） |
| **列定义来源** | `CkH5.java` |

### 9.2 触发入数据的三种场景

#### 场景 1：H5 页面事件（H5_EVENT）

**入口策略**：`H5EventMainStrategy` → 分发到 `H5EventDefaultStrategy` 或 `H5EventErrorStrategy`

主策略先对事件做主校验（`H5EventEntityValidator.H5_MAIN_FILTER_TYPE`），通过后再根据是否"错误页"分发到不同子策略。

**1.1 正常 H5 页（H5EventDefaultStrategy）**

触发条件（全部满足）：

| 条件 | 说明 |
|------|------|
| 事件类型为 `EventTypeEnum.H5_EVENT` | 必须是 H5 页面事件 |
| `responseStatus < 400` | HTTP 响应码正常 |
| `domCompleteMs > 0` | DOM 完成时间存在且合法 |
| `domInteractiveMs > 0` | DOM 可交互时间存在且合法 |
| 通过 `H5_DEFAULT_FILTER_TYPE` 时间轴校验 | `validateH5Timing` 对各导航阶段时间做范围检查（非负、不超合理阈值、阶段间顺序一致性） |
| `H5ResultZeusConvert.defaultConvert` 返回非 null | `buildCountData` 内部未检测到负耗时等异常 |

**产出**：`GranDataDTO(EtlBizTypeEnum.RUM_DRU_STAT_H5, H5ResultZeus)` → 最终写入 `t_rum_h5`

**1.2 错误 H5 页（H5EventErrorStrategy）**

触发条件（满足任一即路由到本策略）：

| 条件 | 说明 |
|------|------|
| `responseStatus >= 400` | HTTP 响应码为错误状态 |
| `domCompleteMs` 为 null 或 ≤ 0 | DOM 完成时间缺失或无效 |
| `domInteractiveMs` 为 null 或 ≤ 0 | DOM 可交互时间缺失或无效 |

**特点**：

- 使用 `H5_ERROR_FILTER_TYPE`，校验器**直接返回 true，不做性能时间过滤**
- 强制设置 `error_num=1`、`page_loading_status=3`
- 仍需 `H5ResultZeusConvert.errorConvert` 产出非空对象方可入库

#### 场景 2：WebView 文档级网络错误（NET_WORK 事件）

**入口策略**：`NetBaseStrategy` → 同时注册 `NetErrorEventStrategy` + `WebViewErrorStrategy`

触发条件（全部满足）：

| 条件 | 说明 |
|------|------|
| 事件为网络请求错误 | `errorNetReq == true` |
| 非资源请求 | `resource == false` |
| 请求类型为 `AppRequestTypeEnum.WEBVIEW_DOCUMENT` | 必须是 WebView 文档请求（非 XHR/静态资源） |
| 错误类型为 `ErrorCodeTypeEnum.INTERNET_TYPE` | 网络层连接性错误（非 HTTP 业务错误码） |
| 通过 `NetBaseStrategy.modelFilter` 过滤 | 域名白名单/黑名单、错误过滤配置等均通过 |

**产出**：`GranDataDTO(EtlBizTypeEnum.RUM_DRU_STAT_H5, H5ResultZeus)` → 写入 `t_rum_h5`

> **说明**：此场景下 H5 页面本身未上报 `H5_EVENT`，但因网络错误导致页面无法加载，由本策略补录一条错误类型的 H5 gran 行，确保在 H5 页面维度能看到网络导致的加载失败数据。

#### 场景 3：JS Error 补录（JS_ERROR_EVENT）

**入口策略**：`JsErrorEventStrategy`

触发条件（全部满足）：

| 条件 | 说明 |
|------|------|
| `!model.isBlockFilter()` | 未被屏蔽过滤（如黑名单屏蔽） |
| `model.getPageType() != PageTypeEnum.UNKNOWN` | 页面类型可识别 |
| `model.getPageType() == null` 或 `== PageTypeEnum.H5` | 页面类型为 H5（null 也按 H5 处理） |

**产出**：在 JS Error 专用表写入之外，**额外追加**一条 `GranDataDTO(EtlBizTypeEnum.RUM_DRU_STAT_H5, H5ResultZeus)`

**特点**：

- `jserror_num=1`
- `page_loading_status=3`
- `jserror_page_num_uniq12` 使用页面 PV id

> **说明**：JS Error 事件本身写入 JS Error 专用表，同时补录一行到 `t_rum_h5`，用于在 H5 页面维度聚合 JS 错误数量，支撑 H5 页面错误率等指标的计算。

### 9.3 数据流（端到端）

```
采集上报（SDK）
    ↓
解析为领域模型
（H5EventEntity / NetworkEventModel / JSErrorEventModel）
    ↓
EventProcessFactory 选择主策略（H5 / Net / JS Error）
    ↓
dataClean（过滤非法 URL、性能时间、网络类型等）
    ↓
flatten / modelConvert（分支为 Default / Error 子策略）
    ↓
buildGranResult
    → H5ResultZeus（字段来自协议实体 + CommonModel）
    → GranDataDTO(RUM_DRU_STAT_H5)
    ↓
CkResultModelWrapper.convertToCkResultModel
    → CkResultModel(tableName="t_rum_h5", values=[...])
    → 写入公共列：data_source="Bonree探针"、data_center_id（来自 Nacos GlobalConfig）
    → 处理 uniq12 字段（dealUniq12 case RUM_DRU_STAT_H5）
    ↓
RumMappingData.granResultModels
    + DataForwarder（可选，配置开启时同步转发到 Kafka）
    ↓
下游按 EtlBizTypeEnum 的 dataSource="one_rum_datasource_gran"
    → 路由到对应 ClickHouse 库
    → INSERT INTO t_rum_h5
```

### 9.4 写入字段说明

**维度字段**

| 字段名 | 含义 |
|--------|------|
| `monitor_time` | 监控时间（分钟粒度，聚合时间窗口） |
| `app_id` | 应用 ID |
| `env_id` | 环境 ID |
| `app_type` | 应用类型（来自 CommonModel） |
| `domain` | 页面域名 |
| `page_name` | 页面名称 |
| `client_os_name` | 客户端系统名称 |
| `user_group_id` | 用户分组 ID |
| `data_source` | 固定为 `"Bonree探针"` |
| `account_id` | 账户 ID |
| `data_center_id` | 数据中心 ID（来自 Nacos GlobalConfig） |

**指标字段**

| 字段名 | 含义 |
|--------|------|
| `page_loading_status` | 页面加载状态（1=正常，3=错误） |
| `page_error_type` | 页面错误类型 |
| `dns_*_us` / `tcp_*_us` 等 | 各导航阶段耗时（DNS、TCP、TTFB、DOM 完成等，单位微秒） |
| `error_num` | 错误页面数 |
| `jserror_num` | JS 错误数 |
| `resource_size` | 资源大小 |
| `*_uniq12` | HLL 去重字段（PV、UV、会话等） |

**字段赋值来源**

| 数据来源链路 | 主要 Java 类 | 说明 |
|-------------|-------------|------|
| H5 正常页 | `H5ResultZeusConvert.commonConvert` + `defaultConvert` + `buildCountData` | CommonModel（appId、appType、sdkVersion、brUserId、channel、session、设备等）+ WebviewPerformanceInfoEntity（导航各阶段毫秒时间换算为微秒）+ H5ProblemTypeEnum 决定 request/error/slow 计数 |
| H5 错误页 | `H5ResultZeusConvert.errorConvert` | 在 common 基础上强制 error_num=1、page_loading_status=3、错误设备/会话 uniq |
| WebView 网络错误 | `NetH5ResultZeusConvert` | NetworkEventModel 的 domain/page/错误信息 + CommonModel；模块名走 ModuleSetting/DataFormatUtil.getH5ModuleName |
| JS Error 补录 | `JsErrorEventStrategy.buildH5Result` | jserror_num=1、page_loading_status=3、jserror_page_num_uniq12 用页面 PV id；时间与维度来自 JSErrorEventEntity + CommonModel |

### 9.5 过滤条件汇总（不会入数据的情况）

| 场景 | 过滤原因 | 处理结果 |
|------|---------|---------|
| H5 正常页 | 性能时间轴校验失败（负耗时、阶段顺序不合理等） | 整事件丢弃 |
| H5 正常页 | `H5ResultZeusConvert.defaultConvert` 返回 null | 返回空列表，不产生 gran 行 |
| 网络错误 | 请求类型非 `WEBVIEW_DOCUMENT` | 不路由到 WebViewErrorStrategy |
| 网络错误 | 错误类型非 `INTERNET_TYPE` | 不路由到 WebViewErrorStrategy |
| 网络错误 | 命中域名/URL 黑名单 | modelFilter 过滤，不产生 gran 行 |
| JS Error | `model.isBlockFilter() == true` | 返回空列表 |
| JS Error | `pageType == PageTypeEnum.UNKNOWN` | 不追加 H5 gran 行 |
| JS Error | `pageType` 为 Native App 类型（非 H5） | 不追加 H5 gran 行 |

### 9.6 平台/类型判断对入数据的影响

**appType 判断**

- 来自 `CommonModel.getAppType()`，由 SDK 上报时携带
- 影响 `app_type` 列写入值，**不影响是否入数据**

**platform 对数鉴解析的影响**

`ParserDataStrategyFactory` 对 `RUM_DRU_STAT_H5` 注册的平台解析策略：

| platform | 解析策略 |
|----------|----------|
| `WEB` | `WebViewStrategyParser` |
| `ANDROID` / `APPLE` / `WINDOWS` / `HarmonyOS` | `AppH5StrategyParser` |
| `WECHAT_MINI_PROGRAM` 等其他 | 回退为 null |

> 平台判断影响**数鉴侧 Kafka 展示**，**不决定是否生成 t_rum_h5 gran 行**。

### 9.7 主要相关文件路径

| 角色 | 文件路径（相对 ingester-business 模块） |
|------|----------------------------------------|
| 表与数据源绑定 | `ingester-operator/.../enums/EtlBizTypeEnum.java` |
| CK 列定义 | `ingester-operator/.../enums/ck/CkH5.java` |
| Zeus 行模型 | `ingester-operator/.../zeus/h5/H5ResultZeus.java` |
| Gran DTO | `ingester-operator/.../dto/GranDataDTO.java` |
| CK 转换与公共列 | `ingester-rum/.../strategy/impl/CkResultModelWrapper.java` |
| 策略基类与输出 | `ingester-rum/.../strategy/AbstractEventBaseStrategy.java` |
| 策略注册 | `ingester-rum/.../strategy/EventProcessFactory.java` |
| H5 主策略 | `ingester-rum/.../impl/h5/H5EventMainStrategy.java` |
| H5 默认（正常页）策略 | `ingester-rum/.../impl/h5/H5EventDefaultStrategy.java` |
| H5 错误页策略 | `ingester-rum/.../impl/h5/H5EventErrorStrategy.java` |
| H5 校验器 | `ingester-rum/.../impl/h5/H5EventEntityValidator.java` |
| H5 Zeus 转换 | `ingester-rum/.../convert/h5/H5ResultZeusConvert.java` |
| WebView 网络错误→H5 gran | `ingester-rum/.../impl/network/WebViewErrorStrategy.java` |
| 网络策略基类 | `ingester-rum/.../impl/network/NetBaseStrategy.java` |
| 网络→H5 Zeus 转换 | `ingester-rum/.../convert/net/NetH5ResultZeusConvert.java` |
| JS Error 补录 H5 | `ingester-rum/.../impl/jserror/JsErrorEventStrategy.java` |
| 数鉴平台解析映射 | `ingester-rum/.../util/datasee/factory/ParserDataStrategyFactory.java` |
| 可选 Kafka 转发 | `ingester-rum/.../forward/DataForwarder.java` |
| ingester-rum 数据源枚举 | `ingester-rum/.../enums/CkOutputTypeEnum.java`（含 `ONE_RUM_DATASOURCE_GRAN`） |

---

## 10. 维护说明

1. **新增 Gran 表族**：需在 `one_rum_datasource_gran.sql` 增加 DDL、`t_basic_formula_config` 注册指标，并在 `DataTableEnum` / druid 查询类中补充过滤字段。
2. **新增 Snapshot 表族**：需增加 `_local` 写入表、QueryService `_view`、可选 `SnapshotTableEnum` 与 `RumSnapshotMapper` SQL，并评估是否接入 `t_rum_session_minute` MV 链。
3. **新增前端页面**：在 `view/rum/src/routes/route.ts` 注册路由，后端 Controller 应通过 Metric API 或 Snapshot Mapper 访问，避免硬编码 `_local` 物理表。
4. **版本升级**：增量 DDL 在 `script/one_framework_rum/INIT/clickhouse/{version}/` 下，全量基准以 `all/` 目录为准。
5. **公共 TopK 库**：变更 `one_common_datasource_gran.sql` 时需同步评估 Zeus ETL/Ingester 与全平台筛选 TopK，见 §4B.7。
6. **Gran 入数据链路**：新增 Gran 表族需在 `ingester-operator` 侧新增 `EtlBizTypeEnum`、`Ck*` 列定义、`*ResultZeus` 模型与对应策略类，遵循 §9 描述的三场景模式（事件主链、跨事件补录、错误补录）。
