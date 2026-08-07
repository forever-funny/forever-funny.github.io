---
title: 关键词路由索引
sidebar:
  exclude: true
---

# RUM 知识库关键词路由索引

> 本文件是知识库的路由入口（文件名 `kb-index.md`，原 `INDEX.md`；在 Windows 大小写不敏感文件系统上不可命名为 INDEX/index，否则 Hugo 会把本节当成 leaf bundle）。模型根据用户问题中的关键词，在下表中找到对应文档路径，然后读取该文档。
>
> **知识库根目录**：`D:\Bonree\AiProject\forever-funny\content\zh-cn\docs\Digital Experience\rum`  
> 下表「对应文档」路径均相对本根目录；站点浏览入口为 `/docs/digital-experience/rum/`。

## 关键词路由表

### 01-数据存储与表结构

| 关键词 | 对应文档 |
|--------|---------|
| ClickHouse表、Gran表、Snapshot表、表族、MV、物化视图、TopK、数据源 | 01-数据存储与表结构/ClickHouse表与页面功能映射.md |
| t_rum_h5入数据、Gran入数据链路、字段赋值来源 | 01-数据存储与表结构/ClickHouse表与页面功能映射.md |
| 快照表列定义、CkSnapshot、other_index、other_json、t_rum_battery_snapshot、t_trace | 01-数据存储与表结构/快照表结构清单.md |
| 会话级预聚合、sessionList DDL、MV脚本、历史回填、预聚合表 | 01-数据存储与表结构/sessionList会话级表DDL与MV脚本设计.md |
| quantileDD、分位、P50、P99、P95、alias、qds、分位字段、businessType、queryType | 01-数据存储与表结构/quantileDD分位字段映射.md |
| t_rum_net、t_rum_net_resource、t_rum_span、t_rum_h5、t_rum_route、t_rum_view、t_rum_action、t_rum_launch、t_rum_mpview | 01-数据存储与表结构/quantileDD分位字段映射.md |
| 分位展开、Snapshot vs Gran、故障分级、alias碰撞 | 01-数据存储与表结构/quantileDD分位字段映射.md |

### 02-接口文档

| 关键词 | 对应文档 |
|--------|---------|
| recordList接口、快照记录列表、problemType路由、快照表路由、otherIndex、snapshotFile | 02-接口文档/recordList接口文档.md |
| sessionList接口、会话列表查询、userNum、列表条数、kinshipDiagram | 02-接口文档/sessionList接口文档.md |
| querySessionInfo、duration取值、querySessionReplay、getWebAppJsInfo、嵌码配置、userdefine、saveHeader、表头保存 | 02-接口文档/其他接口分析.md |
| 部署状态、终端应用列表、appListQuery、ManageApplication、ConfigMonitorTerminal、默认排序、updateTime、detectedName、searchAppList、应用别名排序、监控应用列表 | 02-接口文档/部署状态-终端应用列表默认排序.md |

### 03-数据上报与协议

| 关键词 | 对应文档 |
|--------|---------|
| config请求、upload请求、grip请求、uploadReplay请求、字段全链路、配置上报 | 03-数据上报与协议/config-upload-grip-uploadReplay字段全链路.md |
| 协议扩展、扩展数据流程、平均耗时、P99耗时差异、页面耗时差异 | 03-数据上报与协议/协议扩展数据流程分析.md |
| 域名类型、getDomainType、DataFormatUtil、页面识别、网络请求识别、ingester-rum识别规则 | 03-数据上报与协议/页面与网络请求识别规则.md |
| rum-controller、数鉴数据、数据接收、数据转发、数据处理转换、特殊处理逻辑 | 03-数据上报与协议/rum-controller数鉴数据处理流程.md |
| brKey去重、上传去重、晚回数据、memberId全链路、memberId入库、RUM-memberId | 03-数据上报与协议/数据上报其他逻辑.md |
| client_brand_name、client_device_name、clientBrandName、clientDeviceName、设备品牌、设备机型、机型纠偏、BrandCache、BrandCheckCache、t_bas_brand、t_bas_brand_check、brandList、brandCheckList、bn、型号字典、DataFactory.buildDeviceInfo | 03-数据上报与协议/设备品牌机型纠偏与t_bas_brand字典.md |
| 会话回放、sessionReplay、uploadReplay、querySessionReplay、querySessionReplayData、T_RUM_SESSION_REPLAY、eventFileId、wsd、msd、rrweb、VFramePlay、replayFlag、*_event、*_imgs、SessionReplay | 03-数据上报与协议/会话回放上传入库与查询.md |

### 04-符号化与堆栈解析

| 关键词 | 对应文档 |
|--------|---------|
| 符号化、Symbol、SourceMap、iOS符号文件、Info.plist、路径拼接、MappingPathUtils、getAppSymbolPath、PlatformEnum、AbiTypeEnum、LocalSymbolFileJob、符号文件删除、符号文件清理、定时任务、误删根因、配置表删除、TYPE安全、操作审计、操作日志 | 04-符号化与堆栈解析/符号化体系全链路.md |
| 堆栈解析、JS错误堆栈、sourcemap-resolver、解析引擎、前端过滤校验、API入口、问题类型、crashEventId、问题ID、问题归并、crashType、causeBy、crashFunction、OSPlatformTypeEnum、Stack组件、CodeException | 04-符号化与堆栈解析/堆栈解析与展示.md |

### 05-会话与用户管理

| 关键词 | 对应文档 |
|--------|---------|
| 真实用户、访客、memberId、userType、用户定义、用户识别、游客 | 05-会话与用户管理/真实用户与访客定义识别逻辑.md |
| 用户ID采集、用户ID采集规则、userdefine、JsRuleCache、classType 11000、USER_ID_COLLECTION、userIdCollectionSwitch、实体识别终端用户、账号环境应用生效 | 05-会话与用户管理/用户ID采集规则下发与生效范围.md |
| SDK启动概率、用户白名单、filterSdkCollectRate、采集率、sdkCollectRate、用户组、成员关系、缓存机制、布隆过滤器、首启动、license边界、银行场景 | 05-会话与用户管理/SDK启动概率与用户白名单完整逻辑.md |
| 用户组缓存、UserGroupCache、用户组匹配、缓存优化、ingester-rum用户组 | 05-会话与用户管理/用户组缓存设计分析与优化方案.md |
| 有效会话、活跃设备、hasSession、sessionFlag、预聚合、会话数不一致、sessionNum、无效会话、query-field.xml | 05-会话与用户管理/有效会话数与活跃设备数指标分析.md |
| 会话回放、sessionReplay、uploadReplay回放、回放文件、eventFileId | 03-数据上报与协议/会话回放上传入库与查询.md |

### 06-页面视图与性能指标

| 关键词 | 对应文档 |
|--------|---------|
| 终端应用、页面操作请求、view/action/net、前端查询链路、采集入库、四类对象、场景过滤 | 06-页面视图与性能指标/终端应用-页面-操作-请求完整逻辑.md |
| 视图类型、页面类型、识别规则、upload协议层、落库层、聚合层、前端归并层 | 06-页面视图与性能指标/页面与视图类型识别逻辑.md |
| H5加载、FP、FCP、LCP、TTI、页面完全加载耗时、快照详情、回退逻辑 | 06-页面视图与性能指标/H5页面加载快照详情字段链路.md |
| 自定义视图、视图取舍、端到端打通、service_detected_name、t_trace、自定义视图过滤 | 06-页面视图与性能指标/自定义视图与端到端打通逻辑.md |

### 07-代码异常与修复状态

| 关键词 | 对应文档 |
|--------|---------|
| 修复状态、problem_status、problem_type、t_rum_problem_status、t_rum_problem_record、状态枚举、状态流转、JS_ERROR、ANR、LAG、CRASH、SELF_CRASH、APP_FREEZE、崩溃记录页、外部跳转、URL参数、搜索框、useAutoLinkFilter、crash字段 | 07-代码异常与修复状态/代码异常-修复状态与崩溃记录页.md |

### 08-计费与MAU

| 关键词 | 对应文档 |
|--------|---------|
| 计费、MAU、月活、月活跃用户、License、configFilter、MauLicenseService、UsmLicenseService、HyperLogLog、Bitmap、Redis去重、License缓存、t_rum_license_record、定时Job、UpdateLicenseUsedJob、PushLicenseUsedJob、超量、计费类型 | 08-计费与MAU/计费逻辑与MAU完整分析.md |

### 09-配置与中间件

| 关键词 | 对应文档 |
|--------|---------|
| Nacos配置、配置参数、配置下发、BaseConfig、GlobalConfig、KafkaConfig、RUMConfig、RuleLimitConfig、配置管理、动态更新 | 09-配置与中间件/Nacos配置参数梳理.md |
| Redis Key、BPI、RUM Redis、首次崩溃、Redis内存、NewCrashUtils、Bitmap优化、分桶、分布式锁、慢操作、hash tag | 09-配置与中间件/Redis使用与问题分析.md |

### 10-产品分析与工程化

| 关键词 | 对应文档 |
|--------|---------|
| 产品调研、竞品对比、能力分析、优化建议、路线图、能力支柱、产品定位 | 10-产品分析与工程化/产品调研与能力分析.md |
| 工程化重构、性能调优、代码质量、绞杀者模式、Controller性能、参数配置、压测、技术债务、重构方案 | 10-产品分析与工程化/工程化重构与性能调优方案.md |

### 11-代码质量

| 关键词 | 对应文档 |
|--------|---------|
| SQL时间条件、no-time-condition、实体实例ID、ID类型、类型问题、rum-core SQL、查询封装 | 11-代码质量/SQL与类型问题分析.md |

### 12-健康评分

| 关键词 | 对应文档 |
|--------|---------|
| 健康评分、HealthScore、HealthScoreServer、HealthScoreUtils、评分模型、线性评分、y=kx+b、T0、T1、metricDirection、weightRate、zero、一票零分、权重分摊 | 12-健康评分/健康评分模型与默认规则影响范围.md |
| HealthScoreEnum、classType、评分类型、HealthPlatformMapping、ANDROID评分、IOS评分、HarmonyOS评分、Windows评分、H5评分、小程序评分、MINI_PROGRAM评分、应用评分、页面评分、视图评分、网络请求评分、操作评分 | 12-健康评分/健康评分模型与默认规则影响范围.md |
| 评分规则、t_rum_config_app_score_rule、规则类型、type=1自定义、type=2预置、type=3默认、规则优先级、distributeRule、单规则去重、SINGLE_RULE_APP_TYPES、selectRuleList、order_index | 12-健康评分/健康评分模型与默认规则影响范围.md |
| 指标缺失兜底、healthScoreMetricMap、兜底默认值、隐形满分、satisfyingRatio、apdex缺失、crash.count兜底 | 12-健康评分/健康评分模型与默认规则影响范围.md |
| 崩溃率100%健康评分97.42、崩溃率与崩溃次数口径错位、one.rum.app.crash.count、one.rum.app.crash.crashRatio、crashRatio、崩溃计数、评分口径错位、低会话量高分 | 12-健康评分/健康评分模型与默认规则影响范围.md |
| 默认规则编辑、editDefaultRules、editRules、copy-on-write、写时复制、规则克隆、initAppCustomScoreRule、completeMissingCustomRules、selectAppCreateSourceRule、新应用评分规则、已有应用评分规则、InitAppScoreRuleSync、规则影响范围 | 12-健康评分/健康评分模型与默认规则影响范围.md |
| 会话时长指标废弃、sessionTime、网络指标向后兼容、businessRequest、request指标转换、环比、ringRate、OpenAPI评分、getHealthScoreForApi、getPageHealthScoreForApi | 12-健康评分/健康评分模型与默认规则影响范围.md |

## 多关键词命中规则

当用户问题命中多个关键词时：
1. 分别定位到对应文档
2. 合并去重
3. 优先读取与问题最直接相关的文档
4. 如有关联文档（见 SKILL.md 交叉引用规则），一并读取

## 未命中规则

如果用户问题中的关键词未在上表中命中：
1. 先读取 `README.md` 中的"文档速查矩阵"，尝试从文档概述中匹配
2. 如仍无法匹配，基于源码直接回答，并提示用户可能需要扩充 kb-index.md 的关键词覆盖
