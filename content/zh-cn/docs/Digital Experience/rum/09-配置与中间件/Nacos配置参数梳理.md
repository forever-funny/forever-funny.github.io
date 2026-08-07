# Nacos 配置参数梳理

> 本文档整合 RUM 模块（`controller/rum-controller` 与 `framework/plugins/rum`）全部 Nacos 配置参数清单与配置下发逻辑，作为完整的独立技术参考。所有路径统一为 newonexm 仓库路径。

---

## 一、配置管理机制

### 1.1 Nacos 接入与引导参数

RUM 模块分为两个核心子模块，二者各自维护 Nacos 接入参数：

- `controller/rum-controller`：使用 `@NacosValue` 风格的散点配置 + `@ConfigurationProperties` 绑定类，配置集中在 `BaseConfig`、`GlobalConfig`、`KafkaConfig` 及若干 `special` 配置类。
- `framework/plugins/rum`：未使用 `@NacosValue`，而是通过 `RUMConfig`、`RuleLimitConfig` 以及 `rum-admin/application.properties` 集中承载配置。

两个子模块均通过环境变量 / 系统属性间接驱动 Nacos 接入与配置加载行为。

### 1.2 controller/rum-controller 启动期 Nacos 接入

位置：
- `controller/rum-controller/manager/src/main/java/com/bonree/rum/ApplicationStart.java`
- `controller/rum-controller/base/src/main/java/com/bonree/rum/base/discovery/DiscoveryService.java`
- `controller/rum-controller/config/src/main/resources/config/application.yml`

#### 1.2.1 application.yml

| 配置 key                        | 默认值  | 作用                               | 引用说明                                |
| ------------------------------- | ------: | ---------------------------------- | --------------------------------------- |
| `nacos.config.auto-refresh`     | `true`  | 开启 Nacos 配置自动刷新            | 未见业务代码直接读取，由 Nacos 框架接管 |
| `nacos.config.bootstrap.enable` | `true`  | 启用 bootstrap 阶段加载 Nacos 配置 | 未见业务代码直接读取，由 Nacos 框架接管 |

#### 1.2.2 环境变量 / 系统属性

| 配置 key                                        |      默认值 | 作用                                       | 引用说明                                                     |
| ----------------------------------------------- | ----------: | ------------------------------------------ | ------------------------------------------------------------ |
| `NACOS_AUTH_ENABLED`                            |          无 | 是否开启 Nacos 鉴权                        | `ApplicationStart.loadNacosParams()`、`ApiController.getCacheMsg()` |
| `NACOS_USERNAME`                                |          无 | Nacos 用户名                               | `ApplicationStart.loadNacosParams()`、`ApiController.getCacheMsg()` |
| `NACOS_P`                                       |          无 | Nacos 密码（优先键）                       | `ApplicationStart.loadNacosParams()`、`ApiController.getCacheMsg()` |
| `NACOS_PWD`                                     |          无 | Nacos 密码备用键                           | `ApplicationStart.loadNacosParams()`、`ApiController.getCacheMsg()` |
| `NACOS_SERVER`                                  |          无 | Nacos 服务地址                             | `ApplicationStart.loadNacosParams()`、`MainManager.startTrackServer()` |
| `GLOBAL_NAMESPACE`                              |          无 | 全局 namespace                             | `ApplicationStart.loadNacosParams()`、`MainManager.startTrackServer()` |
| `GLOBAL_DATA_ID`                                |          无 | 全局 dataId                                | `ApplicationStart.loadNacosParams()`                         |
| `GLOBAL_GROUP`                                  |          无 | 全局 group                                 | `ApplicationStart.loadNacosParams()`、`MainManager.startTrackServer()` |
| `ONE_NAMESPACE`                                 |          无 | rum namespace，空时回退 `GLOBAL_NAMESPACE` | `ApplicationStart.loadNacosParams()`、`MainManager.startTrackServer()` |
| `ONE_DATA_ID`                                   |          无 | rum dataId                                 | `ApplicationStart.loadNacosParams()`                         |
| `ONE_GROUP`                                     |          无 | rum group                                  | `ApplicationStart.loadNacosParams()`、`MainManager.startTrackServer()` |
| `nacos.config.username`                         |          无 | 写回 Nacos 客户端用户名                    | `ApplicationStart.loadNacosParams()` 设置；`DiscoveryService.initNamingService()` 读取 |
| `nacos.config.password`                         |          无 | 写回 Nacos 客户端密码                      | 同上                                                         |
| `nacos.config.server-addr`                      |          无 | 写回 Nacos 服务地址                        | `ApplicationStart.loadNacosParams()` 设置                    |
| `nacos.config.namespace`                        |          无 | 写回 namespace                             | `ApplicationStart.loadNacosParams()` 设置                    |
| `nacos.config.group`                            |          无 | 写回 group                                 | `ApplicationStart.loadNacosParams()` 设置                    |
| `nacos.config.data-id`                          |          无 | 写回 data-id                               | `ApplicationStart.loadNacosParams()` 设置                    |
| `nacos.config.type`                             |       `xml` | 固定 Nacos 配置格式                        | `ApplicationStart.loadNacosParams()` 设置                    |
| `nacos.default.timeout`                         | `86400000`  | Nacos 配置获取总超时                       | `ApplicationStart.loadNacosParams()` 设置                    |
| `nacos.remote.client.grpc.retry.times`          |     `99999` | gRPC 重试次数                              | `ApplicationStart.loadNacosParams()` 设置                    |
| `nacos.remote.client.grpc.server.check.timeout` |      `5000` | gRPC 连接超时                              | `ApplicationStart.loadNacosParams()` 设置                    |

#### 1.2.3 DiscoveryService 读取的系统属性

| 配置 key                | 默认值 | 作用                     | 引用说明                               |
| ----------------------- | -----: | ------------------------ | -------------------------------------- |
| `nacos.config.username` |     无 | NamingService 鉴权用户名 | `DiscoveryService.initNamingService()` |
| `nacos.config.password` |     无 | NamingService 鉴权密码   | `DiscoveryService.initNamingService()` |

### 1.3 framework/plugins/rum Nacos 接入

位置：`framework/plugins/rum/rum-admin/src/main/resources/application.properties`

| 配置 key                   |                                     默认值 | 作用               | 引用说明                                   |
| -------------------------- | -----------------------------------------: | ------------------ | ------------------------------------------ |
| `one.conf.type`            |                                    `nacos` | 指定配置中心类型   | 未见 Java 直接读取，通常由基础配置框架接管 |
| `one.conf.file.type`       |                                      `xml` | 配置文件类型       | 同上                                       |
| `nacos.conf.uri`           | `${NACOS_SERVER:http://10.241.60.19:8848}` | Nacos 地址         | 同上                                       |
| `nacos.conf.namespace`     |              `${GLOBAL_NAMESPACE:ONE_RUM}` | Nacos 命名空间     | 同上                                       |
| `nacos.conf.global.dataId` | `${GLOBAL_DATA_ID:CONFIG_GLOBAL_2400.xml}` | global 配置 dataId | 同上                                       |
| `nacos.conf.global.group`  |             `${GLOBAL_GROUP:GLOBAL_GROUP}` | global 配置 group  | 同上                                       |
| `nacos.conf.basic.dataId`  |       `${ONE_DATA_ID:ONE_CONFIG_2400.xml}` | basic 配置 dataId  | 同上                                       |
| `nacos.conf.basic.group`   |                   `${ONE_GROUP:ONE_GROUP}` | basic 配置 group   | 同上                                       |
| `nacos.conf.username`      |                  `${NACOS_USERNAME:nacos}` | Nacos 用户名       | 同上                                       |
| `nacos.conf.password`      |                       `${NACOS_PWD:nacos}` | Nacos 密码         | 同上                                       |
| `conf.use.encrypt.conf`    |                                     `true` | 配置密码是否加密   | 同上                                       |
| `nacos.conf.auth`          |              `${NACOS_AUTH_ENABLED:false}` | 是否开启鉴权       | 同上                                       |

### 1.4 配置加载与动态更新机制

- `controller/rum-controller` 通过 `nacos.config.bootstrap.enable=true` 在 bootstrap 阶段加载 Nacos 配置，`auto-refresh=true` 启用自动刷新；`BaseConfig`、`GlobalConfig`、`KafkaConfig` 等承载类在配置变更时由 Nacos 客户端回调触发字段重载。
- `framework/plugins/rum` 通过 `one.conf.type=nacos` 由基础配置框架接管，配置绑定到 `RUMConfig` 与 `RuleLimitConfig`，由 `RUMConfig.afterOperate()` 等回调完成派生参数初始化（如本地权限缓存配置组装）。
- 涉及可动态调整的参数（阈值、开关、规则、超时时间等）必须走 Nacos，禁止硬编码到代码或 properties 中。新增配置项时需同步更新 Nacos 配置模板和 `application.properties` 注释。

---

## 二、全部配置参数清单

### 2.1 controller/rum-controller

#### 2.1.1 BaseConfig 基础 / Netty / 线程池

位置：`controller/rum-controller/config/src/main/java/com/bonree/rum/config/config/BaseConfig.java`

`BaseConfig` 是 `rum-controller` 中最核心的 Nacos 参数类，覆盖网络、线程池、队列、过滤、上报、快照、回放、转发、H5、license、vm 等多个维度。

| 配置 key                                                 |           默认值 | 字段                    | 作用                       | 主要引用                                                |
| -------------------------------------------------------- | ---------------: | ----------------------- | -------------------------- | ------------------------------------------------------- |
| `global.private.rum.mirror.ng.session`                   |  `BR-SESSION-ID` | `ngMirrorSession`       | 镜像模式 session header 名 | 未检到业务直接读取                                      |
| `global.private.rum.mirror.mode`                         |             `""` | `mirrorMode`            | 镜像模式开关/模式标识      | `BaseInfoService.checkVersion()`、`checkBrand()`        |
| `global.common.authority.type`                           |              `1` | `authorityType`         | 权限类型，1公有云/2私有云  | `BaseConfig.afterOperate()`、`MainManager`              |
| `global.private.rum.server.name`                         | `RUM_CONTROLLER` | `discoveryServerName`   | 注册到 Nacos 的服务名      | `MainManager.startTrackServer()`                        |
| `global.private.rum.netty.server.boss-count`             |              `2` | `bossCount`             | Netty boss 线程数          | `NettyHttpServer.init()`                                |
| `global.private.rum.netty.server.worker-count`           |              `6` | `workerCount`           | Netty worker 线程数        | `NettyHttpServer.init()`                                |
| `global.private.rum.netty.server.max-context-length`     |        `5242880` | `maxContextLength`      | HTTP 最大请求体长度        | `NettyHttpServer.init()`                                |
| `global.private.rum.netty.server.so_keepalive`           |           `true` | `soKeepalive`           | Netty keepalive            | `NettyHttpServer.init()`                                |
| `global.private.rum.netty.server.so_backlog`             |             `-1` | `soBacklog`             | Netty backlog              | `NettyHttpServer.init()`                                |
| `global.private.rum.netty.server.connect_timeout_millis` |          `10000` | `connectTimeoutMillis`  | Netty 连接超时             | `NettyHttpServer.init()`                                |
| `global.private.rum.netty.server.so_rcvbuf`              |         `524288` | `soRcvbuf`              | 接收缓冲区                 | `NettyHttpServer.init()`                                |
| `global.private.rum.netty.server.so_sndbuf`              |           `2048` | `soSndbuf`              | 发送缓冲区                 | `NettyHttpServer.init()`                                |
| `global.private.rum.thread.api.min`                      |              `3` | `apiMinSize`            | API 线程池最小线程数       | `MainManager.initThreadPool()`                          |
| `global.private.rum.thread.api.max`                      |              `6` | `apiMaxSize`            | API 线程池最大线程数       | `MainManager.initThreadPool()`                          |
| `global.private.rum.thread.api.size`                     |           `2000` | `apiQueueSize`          | API 线程池队列长度         | `MainManager.initThreadPool()`                          |
| `global.private.rum.thread.upload.min`                   |              `3` | `uploadMinSize`         | upload 线程池最小线程数    | `MainManager.initThreadPool()`                          |
| `global.private.rum.thread.upload.max`                   |              `6` | `uploadMaxSize`         | upload 线程池最大线程数    | `MainManager.initThreadPool()`                          |
| `global.private.rum.thread.upload.size`                  |           `2000` | `uploadQueueSize`       | upload 队列长度            | `MainManager.initThreadPool()`、`SelfMonitor.execute()` |
| `global.private.rum.thread.replay.upload.min`            |              `3` | `uploadReplayMinSize`   | 回放处理最小线程数         | `MainManager.initThreadPool()`                          |
| `global.private.rum.thread.replay.upload.max`            |              `6` | `uploadReplayMaxSize`   | 回放处理最大线程数         | `MainManager.initThreadPool()`                          |
| `global.private.rum.thread.replay.upload.size`           |           `2000` | `uploadReplayQueueSize` | 回放处理队列长度           | `MainManager.initThreadPool()`                          |
| `global.private.rum.thread.config.min`                   |              `3` | `configMinSize`         | config 线程池最小线程数    | `MainManager.initThreadPool()`                          |
| `global.private.rum.thread.config.max`                   |              `6` | `configMaxSize`         | config 线程池最大线程数    | `MainManager.initThreadPool()`                          |
| `global.private.rum.thread.config.size`                  |           `2000` | `configQueueSize`       | config 队列长度            | `MainManager.initThreadPool()`、`SelfMonitor.execute()` |
| `global.private.rum.thread.track.min`                    |              `3` | `trackMinSize`          | track 线程池最小线程数     | `MainManager.initThreadPool()`                          |
| `global.private.rum.thread.track.max`                    |              `6` | `trackMaxSize`          | track 线程池最大线程数     | `MainManager.initThreadPool()`                          |
| `global.private.rum.thread.track.size`                   |           `1000` | `trackQueueSize`        | track 队列长度             | `MainManager.initThreadPool()`                          |

#### 2.1.2 BaseConfig 本地队列 / Kafka topic / group / 队列容量

| 配置 key                                                     |                           默认值 | 字段                             | 作用                           | 主要引用                                |
| ------------------------------------------------------------ | -------------------------------: | -------------------------------- | ------------------------------ | --------------------------------------- |
| `global.private.rum.data-cache.etl-proto-topic`              |              `ETL-PROTOCOL-DATA` | `protocolMQTopic`                | SDK 协议数据本地消息队列 topic | `MainManager.dataMQRegister()`          |
| `global.private.rum.data-cache.etl-metric-topic`             |                `ETL-metric-DATA` | `metricMQTopic`                  | metric 队列 topic              | `MainManager.initMetricQueue()`         |
| `global.private.rum.data-cache.etl-brfs-topic`               |                  `ETL-BRFS-DATA` | `brfsMQTopic`                    | BRFS 队列 topic                | `MainManager.dataBrfsMQRegister()`      |
| `global.private.rum.data-cache.etl-transfer-topic`           |              `ETL-TRANSFER-DATA` | `transferMQTopic`                | crash/transfer 队列 topic      | `MainManager.dataTransferMQRegister()`  |
| `global.private.rum.data-cache.etl-proto-topic-group`        |        `ETL-PROTOCOL-DATA-GROUP` | `kafkaProtoDataCacheGroup`       | 协议数据 group                 | `MainManager.dataMQRegister()`          |
| `global.private.rum.data-cache.etl-metric-topic-group`       |          `ETL-METRIC-DATA-GROUP` | `kafkaMetricDataCacheGroup`      | metric group                   | `MainManager.initMetricQueue()`         |
| `global.private.rum.data-cache.etl-brfs-topic-group`         |            `ETL-BRFS-DATA-GROUP` | `kafkaBrfsDataCacheGroup`        | brfs group                     | `MainManager.dataBrfsMQRegister()`      |
| `global.private.rum.data-cache.etl-transfer-topic-group`     |        `ETL-TRANSFER-DATA-GROUP` | `kafkaTransferDataCacheGroup`    | transfer group                 | `MainManager.dataTransferMQRegister()`  |
| `global.private.rum.data-cache.etl-proto-replay-topic-group` | `ETL-PROTOCOL-REPLAY-DATA-GROUP` | `kafkaProtoReplayDataCacheGroup` | 回放协议数据 group             | `MainManager.dataReplayMQRegister()`    |
| `global.private.rum.data-cache.etl-proto-replay-topic`       |       `ETL-PROTOCOL-REPLAY-DATA` | `protocolReplayMQTopic`          | 回放协议数据 topic             | `MainManager.dataReplayMQRegister()`    |
| `global.private.rum.data-cache.crash-queue-data-size`        |                             `-1` | `crashQueueDataSize`             | 崩溃/transfer 队列容量         | `MainManager.dataTransferMQRegister()`  |
| `global.private.rum.data-cache.crash-queue-free-rate`        |                            `0.9` | `crashQueueFreeRate`             | 队列空闲率阈值                 | `MainManager.dataTransferMQRegister()`  |
| `global.private.rum.data-cache.crash-queue-kafka-size`       |                             `-1` | `crashQueueKafkaSize`            | crash 队列 Kafka 缓冲上限      | `MainManager.dataTransferMQRegister()`  |
| `global.private.rum.data-cache.snapshot-queue-data-size`     |                             `-1` | `snapshotQueueDataSize`          | snapshot 队列容量              | `MainManager.dataBrfsMQRegister()`      |
| `global.private.rum.data-cache.snapshot-queue-free-rate`     |                            `0.9` | `snapshotQueueFreeRate`          | snapshot 队列空闲率            | `MainManager.dataBrfsMQRegister()`      |
| `global.private.rum.data-cache.snapshot-queue-kafka-size`    |                             `-1` | `snapshotQueueKafkaSize`         | snapshot Kafka 缓冲上限        | `MainManager.dataBrfsMQRegister()`      |
| `global.private.rum.data-cache.upload-queue-data-size`       |                             `-1` | `uploadQueueDataSize`            | upload 队列容量                | `MainManager.dataMQRegister()`          |
| `global.private.rum.data-cache.upload-queue-free-rate`       |                            `0.9` | `uploadQueueFreeRate`            | upload 队列空闲率              | `MainManager.dataMQRegister()`          |
| `global.private.rum.data-cache.upload-queue-kafka-size`      |                             `-1` | `uploadQueueKafkaSize`           | upload Kafka 缓冲上限          | `MainManager.dataMQRegister()`          |
| `global.private.rum.data-cache.metric-queue-data-size`       |                             `-1` | `metricQueueDataSize`            | metric 队列容量                | `MainManager.initMetricQueue()`         |
| `global.private.rum.data-cache.metric-queue-free-rate`       |                            `0.9` | `metricQueueFreeRate`            | metric 队列空闲率              | `MainManager.initMetricQueue()`         |
| `global.private.rum.data-cache.metric-queue-kafka-size`      |                             `-1` | `metricQueueKafkaSize`           | metric Kafka 缓冲上限          | `MainManager.initMetricQueue()`         |
| `global.private.rum.data-cache.config-data-topic`            |          `RUM_CONFIG_DATA_QUEUE` | `configDataTopic`                | config 结果队列 topic          | `MainManager.dataConfigQueueRegister()` |
| `global.private.rum.data-cache.config-data-topic-group`      |          `RUM_CONFIG_DATA-GROUP` | `kafkaConfigDataCacheGroup`      | config 数据 group              | `MainManager.dataConfigQueueRegister()` |
| `global.private.rum.data-cache.config-data-queue-size`       |                             `-1` | `configDataQueueSize`            | config 队列容量                | `MainManager.dataConfigQueueRegister()` |
| `global.private.rum.data-cache.config-data-queue-free-rate`  |                            `0.9` | `configDataQueueFreeRate`        | config 队列空闲率              | `MainManager.dataConfigQueueRegister()` |
| `global.private.rum.data-cache.config-data-queue-kafka-size` |                             `-1` | `configDataQueueKafkaSize`       | config Kafka 缓冲上限          | `MainManager.dataConfigQueueRegister()` |

#### 2.1.3 BaseConfig 上报过滤 / URL / 上传控制 / 自身请求过滤

| 配置 key                                             |                                   默认值 | 字段                       | 作用                               | 主要引用                                               |
| ---------------------------------------------------- | ---------------------------------------: | -------------------------- | ---------------------------------- | ------------------------------------------------------ |
| `global.private.rum.filter.check.deviceId`           |                                   `true` | `checkDeviceId`            | 是否校验设备 ID                    | `DeviceFilter.checkDeviceId()`                         |
| `global.private.rum.filter.ios.sdkversion.down`      |                                  `7.0.0` | `iosSdkversionDown`        | iOS SDK 低版本过滤                 | `DeviceFilter.sdkVersionFilter()`                      |
| `global.private.rum.filter.android.sdkversion.down`  |                                  `6.1.0` | `androidSdkversionDown`    | Android SDK 低版本过滤             | `DeviceFilter.sdkVersionFilter()`                      |
| `global.private.rum.client.save.tme`                 |                                     `24` | `clientSaveTme`            | 客户端数据本地存储最长时间（小时） | `ConfigController`                                     |
| `global.private.rum.get.ip.address`                  |                                  `/grip` | `getIpaddress`             | 获取真实 IP 地址路径               | `ConfigController`                                     |
| `global.private.rum.upload.address`                  |                                `/upload` | `uploadIpaddress`          | upload 地址路径                    | `ConfigController`                                     |
| `global.private.rum.ping.address`                    |                                     `""` | `pingAddress`              | ping 信号量地址                    | `ConfigController`                                     |
| `global.private.rum.rate.of.launch.time`             |                                   `1440` | `rateOfLaunchTime`         | 启动采样/概率有效时长              | `ConfigController`                                     |
| `global.private.rum.launch.filter.time`              |                               `25000000` | `launchFilterTime`         | 启动过滤阈值                       | `LaunchEventService`                                   |
| `global.private.rum.view.filter.time`                |                               `20000000` | `viewFilterTime`           | 视图启动过滤阈值                   | `ViewEventService`                                     |
| `global.private.rum.filter.view.stay-time-threshold` |                                     `60` | `viewStayTimeThreshold`    | 视图停留时间阈值（分钟）           | `ViewEventService`                                     |
| `global.address.upload.url`                          |                                     `""` | `controllerHttpServer`     | controller 外部地址                | `ConfigController`、`ModelBuiness`                     |
| `global.address.upload.url.http`                     |                                     `""` | `controllerRealHttpServer` | controller HTTP 地址               | `BaseConfig.afterOperate()`                            |
| `global.private.rum.controller.path`                 |                                   `/RUM` | `basePath`                 | rum 接口统一前缀                   | `ConfigController`、`ModelBuiness`                     |
| `global.private.rum.filter.network.self-url-filter`  |                                     `""` | `sdkServerUrlSet`          | 自身上报 URL 集合，用于自请求过滤  | `DataCheckUtil`                                        |
| `global.private.rum.filter.network.filter-local-ip`  |                                  `false` | `filterLocalIp`            | 是否过滤本地回环 IP                | `DataCheckUtil`                                        |
| `global.private.rum.url-merge.localhost-merge`       |                                   `true` | `localURLMerge`            | localhost URL 合并策略             | `UrlMergeUtil`                                         |
| `global.private.rum.multipart.maxsize`               |                               `10485760` | `multipartMaxsize`         | 上报报文体大小限制                 | `UploadController.checkParam()`                        |
| `global.private.rum.multipart.save.path`             |   `data/rum_controller/zip_big_package/` | `multipartSavePath`        | 大报文落盘目录                     | `UploadController.saveMultipartToDir()`                |
| `global.private.rum.multipart.unzip.save.path`       | `data/rum_controller/unzip_big_package/` | `multipartUnzipSavePath`   | 解压后超大包落盘目录               | `DataTaskScheduling`                                   |
| `global.private.rum.multipart.save.count`            |                                      `5` | `multipartSaveCount`       | 超限后落盘数量上限                 | `UploadController.saveMultipartToDir()`                |
| `global.private.rum.upload.max.length`               |                               `52428800` | `uploadMaxDatasize`        | upload 包解压后最大限制            | `UploadController`、`DataTaskScheduling`               |
| `global.private.rum.upload.repeat.valid.minute`      |                                     `60` | `uploadRepeatValidMinute`  | upload 数据包去重有效时间          | `UploadController`                                     |
| `global.private.rum.upload.repeat.valid.rate`        |                                 `0.0001` | `uploadBloomRate`          | upload 去重误判率                  | `UploadController`                                     |
| `global.private.rum.upload.repeat.valid.mun`         |                                 `100000` | `uploadBloomMax`           | upload 去重预估数量                | `UploadController`                                     |
| `global.private.rum.real-ip-header`                  |                              `X-Real-IP` | `realIpHeader`             | 获取真实 IP 的 header 名           | `IpController`、`ConfigController`、`UploadController` |
| `global.private.rum.agent.mode`                      |                                  `false` | `agentMode`                | 是否接收精简协议                   | `ConfigController`、`UploadController`                 |

#### 2.1.4 BaseConfig URL 合并 / 网络错误码 / 资源类型 / Span 相关

| 配置 key                                                     |                                默认值 | 字段                              | 作用                          | 主要引用                                     |
| ------------------------------------------------------------ | ------------------------------------: | --------------------------------- | ----------------------------- | -------------------------------------------- |
| `global.private.rum.protocol.expireTime`                     |                                   `7` | `spanDataTTL`                     | 协议扩展/Span TTL             | `SpanUpdateTask`                             |
| `global.private.rum.filter.network.unfilter-642-error-app`   |                                  `""` | `unfilter642ErroridAppid`         | 跳过 642 错误过滤的 appId     | `DataCheckUtil`                              |
| `global.private.rum.filter.network.custom-error-code`        |                                  `""` | `customHttpFilter`                | 自定义过滤 errorCode          | `DataCheckUtil`                              |
| `global.private.rum.filter.network.cancel-code`              |                          `-1012,-999` | `cancelCodeFilter`                | 网络取消 code 过滤列表        | `DataCheckUtil`                              |
| `global.private.rum.url-merge.customBusinessTypeLinkCharacter` |                                   `$` | `customBusinessTypeLinkCharacter` | 自定义业务类型连接符          | `UrlMergeUtil`                               |
| `global.private.rum.url-merge.specialUrlChar`                |                 `.,-,_,/,:,~,%,[,],&` | `specialUrlChar`                  | URL 特殊字符集合              | `UrlMergeUtil`                               |
| `global.private.rum.resource-image-type`                     |                `gif,png,bmp,jpeg,jpg` | `resourceImage`                   | 图片资源后缀集合              | 未检到直接业务读取                           |
| `global.private.rum.resource-media-type`                     | `mp3,wma,flv,mp4,wmv,ogg,avi,m3u8,ts` | `resourceMedia`                   | 媒体资源后缀集合              | 未检到直接业务读取                           |
| `global.private.rum.resource-txt-type`                       |  `doc,docx,xls,xlsx,ppt,pptx,txt,pdf` | `resourceTxt`                     | 文档类资源后缀集合            | 未检到直接业务读取                           |
| `global.private.rum.resource-other-type`                     |      `zip,exe,tat,ico,css,js,swf,apk` | `resourceOther`                   | 其他资源后缀集合              | 未检到直接业务读取                           |
| `global.private.rum.filter.jserror`                          |                                  `""` | `jsErrorFilter`                   | JS 错误过滤配置               | 未检到直接业务读取                           |
| `global.private.rum.span.socket.port`                        |                               `false` | `spanSocketPort`                  | socket/websocket 是否保留端口 | `SpanEventService`、`ActionExitEventService` |
| `global.private.rum.span.socket.filter.account`              |                                  `""` | `filterSpanSocketAccount`         | 过滤 span socket 账户列表     | `SpanEventService`                           |
| `global.private.rum.net.pending.code`                        |                                `6001` | `pendingCode`                     | pending 请求自定义 code       | `DataCheckUtil`、`NetworkBaseService`        |

#### 2.1.5 BaseConfig Track / Online Debug

| 配置 key                                         |              默认值 | 字段                       | 作用                      | 主要引用                         |
| ------------------------------------------------ | ------------------: | -------------------------- | ------------------------- | -------------------------------- |
| `global.private.rum.track.agent.heart.url`       | `/track/agentHeart` | `trackAgentHeartUrl`       | track 心跳地址            | `UploadController`               |
| `global.private.rum.track.file.upload.url`       | `/track/fileUpload` | `trackFileUploadUrl`       | track 文件上传地址        | `AgentService`                   |
| `global.private.rum.track.open`                  |              `true` | `onlineTrackOpen`          | 是否开启 online track     | `MainManager.startTrackServer()` |
| `global.private.rum.track.ready.wait.timeout`    |            `120000` | `trackReadyWaitTimeout`    | trace/调试权限等待超时    | `TrackService.openTrace()`       |
| `global.private.rum.track.web.heart.timeout`     |             `30000` | `trackWebHeartTimeout`     | web 心跳超时              | `WebRedisStatusEnum.get()`       |
| `global.private.rum.track.agent.heart.timeout`   |             `30000` | `trackAgentHeartTimeout`   | agent 心跳超时            | `AgentRedisStatusEnum.get()`     |
| `global.private.rum.track.agent.heart.interval`  |              `2000` | `trackAgentHeartInterval`  | agent 心跳间隔            | `UploadController`               |
| `global.private.rum.track.agent.upload.interval` |              `2000` | `trackAgentUploadInterval` | upload 加速上报间隔       | `UploadController`               |
| `global.private.rum.track.max.response.size`     |            `102400` | `trackMaxResponseSize`     | track 响应体大小上限      | `AgentService`                   |
| `global.private.rum.track.max.log.size`          |          `10485760` | `trackMaxLogSize`          | 拉取日志上限              | `AgentService`                   |
| `global.private.rum.track.task.limit.num`        |                 `6` | `trackTaskLimitNum`        | 单次 task 下发数量限制    | `TrackTaskService.taskSave()`    |
| `global.private.rum.track.session.limit.num`     |                `10` | `trackSessionLimitNum`     | 每账户同时 track 数量限制 | `TrackService.openTrace()`       |
| `global.private.rum.track.task.timeout`          |            `120000` | `trackTaskTimeout`         | task 超时时间             | `TrackTaskService`               |

#### 2.1.6 BaseConfig Snapshot / 布隆去重 / 时间对齐 / Header 采集策略

| 配置 key                                          |                      默认值 | 字段                          | 作用                     | 主要引用                                             |
| ------------------------------------------------- | --------------------------: | ----------------------------- | ------------------------ | ---------------------------------------------------- |
| `global.private.rum.header.collection.strategy`   |                         `2` | `headerCollectionStrategy`    | 网络 header 采集策略     | `ConfigController`                                   |
| `global.private.rum.snapshot.bl-root-path`        | `data/rum_controller/bfbk/` | `snapshotBlRootPath`          | Bloom 本地文件目录       | `LocalBloomFilterUtils.saveLocalCache()`             |
| `global.private.rum.snapshot.bl-max-size`         |                  `10000000` | `snapshotBlMaxSize`           | Bloom 容量               | `LocalBloomFilterUtils`                              |
| `global.private.rum.snapshot.bl-cache-time`       |                  `86400000` | `snapshotBlCacheTime`         | Bloom 有效期             | `LocalBloomFilterUtils`                              |
| `global.private.rum.recovery.cycle`               |                        `15` | `recoveryCycle`               | 客户端回传周期           | `ConfigController`                                   |
| `global.private.rum.controller.time.aligned`      |                      `true` | `controllerTimeAligned`       | 是否开启事件时间对齐     | `DataCheckUtil`                                      |
| `global.private.rum.controller.rowPastLimitDay`   |                        `24` | `controllerRowPastLimitDay`   | 允许过去时间范围（小时） | `DataSchedulingServer`、`ReplayDataSchedulingServer` |
| `global.private.rum.controller.rowFutureLimitDay` |                        `12` | `controllerRowFutureLimitDay` | 允许未来时间范围（小时） | `DataSchedulingServer`、`ReplayDataSchedulingServer` |
| `global.private.rum.ck.data_sava_ent_limit`       |                      `true` | `dataSavaEntLimit`            | 是否开启入库时间限制     | `DataCheckUtil`                                      |
| `global.private.rum.snapshot.file_save_type`      |                         `1` | `snapshotFileSaveType`        | 快照文件存储方式，已废弃 | 未检到直接使用                                       |

#### 2.1.7 BaseConfig RestTemplate / License / IAM / APM / CMDB / 部署模式

| 配置 key                                                   |                     默认值 | 字段                       | 作用                               | 主要引用                                          |
| ---------------------------------------------------------- | -------------------------: | -------------------------- | ---------------------------------- | ------------------------------------------------- |
| `global.private.rum.restTemplate.connectionRequestTimeout` |                    `30000` | `connectionRequestTimeout` | RestTemplate 请求超时              | `RestTemplateConfig`                              |
| `global.private.rum.restTemplate.connectTimeout`           |                   `120000` | `connectTimeout`           | RestTemplate 连接超时              | `RestTemplateConfig`                              |
| `global.private.rum.restTemplate.readTimeout`              |                    `60000` | `readTimeout`              | RestTemplate 读超时                | `RestTemplateConfig`                              |
| `global.private.rum.license.delete`                        |                       `30` | `licenseRecordDeleteTime`  | license 记录保留天数               | `UpdateLicenseUsedJob`                            |
| `global.private.rum.license.hashNum`                       |                       `24` | `redisHashNum`             | license Redis hash 分桶            | `DauLicenseService`、`MauLicenseService`          |
| `global.private.rum.license.expire`                        |                    `86400` | `expireTime`               | cloud 不可用或超量后的缓存过期时间 | `LicenseCache`                                    |
| `global.private.rum.iam.get`                               |  `/api/iam/v4/package/get` | `iamGetUrl`                | cloud license 查询接口             | `LicenseCache.queryAllLicense()`                  |
| `global.private.rum.apm.get.service`                       |   `/api/apm/getServiceIds` | `apmGetServiceUrl`         | APM 服务列表接口                   | `ServiceCache.updateCache()`                      |
| `global.private.rum.apm.get.service.page.size`             |                     `2000` | `apmServicePageSize`       | APM 服务分页大小                   | `ServiceCache.updateCache()`                      |
| `global.private.rum.apm.get.service.max.page`              |                       `10` | `apmServiceMaxPage`        | APM 服务最大分页数                 | `ServiceCache.updateCache()`                      |
| `global.private.rum.apm.mirror.mode`                       |                    `false` | `apmMirrorMode`            | 是否开启查询 APM service id 缓存   | `BaseService.isApmMirrorMode()`                   |
| `global.private.rum.iam.push`                              |    `/api/iam/v3/cost/push` | `iamPushUrl`               | cloud 计费推送接口                 | `PushLicenseUsedJob`                              |
| `global.private.rum.action.methodLevel`                    |                      `100` | `maxMethodLevel`           | 操作分析最大方法层级               | `ActionExitEventService`、`ModelBuiness`          |
| `global.private.rum.action.methodMAxNum`                   |                     `1000` | `maxMethodNum`             | 操作分析最大方法节点数             | `ActionExitEventService`                          |
| `global.private.rum.action.rate`                           |                      `100` | `actionOperateRate`        | 操作分析采集概率                   | `ModelBuiness`                                    |
| `global.common.deploy.type`                                |                        `1` | `deployType`               | 发布类型，1正式/2POC               | `BaseConfig.afterOperate()`、`MainManager`        |
| `global.private.rum.data-cache.poc-queue-data-size`        |                      `200` | `pocQueueDataSize`         | POC 场景队列容量                   | `BaseConfig.afterOperate()`                       |
| `global.common.kafka.open`                                 |                       `-1` | `kafkaOpen`                | 是否开启 Kafka                     | `KafkaConfig.parseData()`、`MainManager`          |
| `global.common.one.common.save-mode`                       |                        `1` | `traceSaveMode`            | 存储模式：CK/ES/双写               | 未检到直接业务读取                                |
| `global.private.common.storage.type`                       |                       `-1` | `STORAGE_TYPE`             | 存储类型（brfs/nfs）               | `DeleteSnapshotFileJob`、`BonreeFileSystemClient` |
| `global.private.rum.common.extensions.path`                |            `/one/snapshot` | `ONE_EXTENSION_PATH`       | 扩展文件路径                       | `NfsSaveService`、`DeleteSnapshotFileJob`         |
| `global.common.zeus.remove.brfs.enabled`                   |                    `false` | `removeBrfs`               | 是否不走 BRFS 直接存 CK            | `BonreeFileSystemClient`                          |
| `global.private.rum.apm.apm_check_table`                   | `br_one.t_apm_host_config` | `apm_check_table`          | 判定 APM 服务存在的表              | `MainManager`                                     |
| `global.private.rum.apm.apm_open`                          |                    `false` | `apmOpen`                  | APM 相关能力开关                   | `MainManager`                                     |
| `global.private.rum.redis.thread.num`                      |                        `2` | `redisThreadNum`           | Redis 线程数                       | `MainManager`                                     |
| `global.private.rum.ipdata.dir`                            |      `conf/common/ipdata/` | `ipDataDir`                | IP 库目录                          | `MainManager`                                     |
| `global.private.rum.ipdata.tempdir`                        | `conf/common/ipdata/temp/` | `ipDataTempDir`            | IP 库临时目录                      | `MainManager`                                     |
| `global.private.rum.ip.update.url`                         |                       `""` | `ipOnlineUpdateUrl`        | IP 在线更新地址                    | `MainManager`                                     |
| `global.private.rum.topk.topKLimit`                        |                      `200` | `topKLimit`                | TopK 上限                          | `MainManager`                                     |

#### 2.1.8 BaseConfig VM、崩溃限制、Replay、H5 阈值

| 配置 key                                         |          默认值 | 字段                  | 作用                            | 主要引用                                    |
| ------------------------------------------------ | --------------: | --------------------- | ------------------------------- | ------------------------------------------- |
| `global.private.rum.vm.switch`                   |         `false` | `vmSwitch`            | 是否开启 VM 双写                | `BaseService.send2Zeus()`、`VmIngestClient` |
| `global.private.rum.vm.thread.pool.size`         |             `1` | `vmThreadPoolSize`    | VM 处理线程数                   | `VmIngestClient`                            |
| `global.private.rum.vm.delay.send`               |             `2` | `vmDelaySend`         | VM 延迟发送秒数                 | `VmTaskScheduling`                          |
| `global.private.rum.vm.max.cache`                |            `25` | `vmMaxCacheCount`     | VM 缓存 key 上限                | `VmDataCache`                               |
| `global.private.rum.crash.limit_period`          |            `30` | `LIMIT_PERIOD`        | 崩溃限制时间周期                | `CrashEventService`                         |
| `global.private.rum.crash.life_period`           |            `60` | `LIFE_PERIOD`         | 崩溃限制过期时间                | `CrashEventService`                         |
| `global.private.rum.replay.upload.address`       | `/uploadReplay` | `uploadReplayAddress` | 会话回放上报地址                | `ModelBuiness`                              |
| `global.private.rum.replay.recording.quality`    |             `0` | `recordingQuality`    | 回放压缩质量                    | `ModelBuiness`                              |
| `global.private.rum.replay.frame.per.second`     |             `2` | `framePerSecond`      | 回放采集帧率                    | `ModelBuiness`                              |
| `global.private.rum.replay.max.collect.interval` |            `10` | `maxCollectInterval`  | 回放最大采集间隔                | `ModelBuiness`                              |
| `global.private.rum.replay.upload.max.size`      |            `10` | `replayUploadMaxSize` | 回放回传大小                    | `ModelBuiness`                              |
| `global.private.rum.replay.upload.cycle`         |            `30` | `uploadCycle`         | 回放回传周期                    | `ModelBuiness`                              |
| `global.private.rum.ping.sdk.version`            |       `8.1.0.0` | `pingSdkVersion`      | ping 下发版本基线               | `ConfigController`                          |
| `global.private.rum.net.full_collection`         |             `0` | `fullCollection`      | network 的 full collection 开关 | `ModelBuiness`                              |
| `global.private.rum.h5.fp.max`                   |         `30000` | `rumH5FpMax`          | H5 FP 最大值                    | `H5EventEntityFilter`                       |
| `global.private.rum.h5.fcp.max`                  |         `30000` | `rumH5FcpMax`         | H5 FCP 最大值                   | `H5EventEntityFilter`                       |
| `global.private.rum.h5.lcp.max`                  |         `30000` | `rumH5LcpMax`         | H5 LCP 最大值                   | `H5EventEntityFilter`                       |

#### 2.1.9 BaseConfig DataForward / Kafka 转发 / 大包落盘

| 配置 key                                                     |                                   默认值 | 字段                                           | 作用                     | 主要引用                                                     |
| ------------------------------------------------------------ | ---------------------------------------: | ---------------------------------------------- | ------------------------ | ------------------------------------------------------------ |
| `global.private.rum.dataForward.switch`                      |                                  `false` | `dataForwardSwitch`                            | 是否开启转发             | `BaseService.send2Zeus()`                                    |
| `global.private.rum.dataForward.gzip`                        |                                  `false` | `dataForwardGzip`                              | 转发数据是否压缩         | `HandleDataService` 间接链路，业务侧未直接检到               |
| `global.private.rum.dataForward.type`                        |                                      `0` | `dataForwardType`                              | 转发类型：0原始，1处理后 | `DataTaskScheduling`、`BaseService.send2Zeus()`              |
| `global.private.rum.dataForward.eventType`                   |                                     `""` | `dataForwardEventType`                         | 处理后允许转发的数据类型 | `BaseService.send2Zeus()`                                    |
| `global.private.rum.dataForward.kafka.host`                  |                                     `""` | `dataForwardKafkaHost`                         | 转发 Kafka 地址          | `MainManager.dataForwardInit()`、`DataForwardKafkaProducer.afterOperate()` |
| `global.private.rum.dataForward.kafka.groupId`               |                     `DATA-FROWARD-GROUP` | `dataForwardKafkaGroupId`                      | 转发 Kafka group         | `DataForwardKafkaProducer.afterOperate()`                    |
| `global.private.rum.dataForward.kafka.topic`                 |                     `DATA-FROWARD-TOPIC` | `dataForwardKafkaTopic`                        | 转发 Kafka topic         | `DataForwardThread.execute()`                                |
| `global.private.rum.dataForward.kafka.encrypt.type`          |                                   `NONE` | `dataForwardKafkaProducerEncryptType`          | Kafka 加密类型           | `DataForwardKafkaProducer.afterOperate()`                    |
| `global.private.rum.dataForward.kafka.producer.security.auth.login.username` |                                     `""` | `dataForwardKafkaProducerSecurityAuthUsername` | SASL 用户名              | `DataForwardKafkaProducer.afterOperate()`                    |
| `global.private.rum.dataForward.kafka.producer.security.auth.login.password` |                                     `""` | `dataForwardKafkaProducerSecurityAuthPassword` | SASL 密码                | `DataForwardKafkaProducer.afterOperate()`                    |
| `global.private.rum.dataForward.kafka.producer.acks`         |                                      `1` | `dataForwardKafkaProducerAcks`                 | producer acks            | `DataForwardKafkaProducer.afterOperate()`                    |
| `global.private.rum.dataForward.kafka.producer.linger.ms`    |                                     `20` | `dataForwardKafkaProducerLingerMs`             | producer linger          | `DataForwardKafkaProducer.afterOperate()`                    |
| `global.private.rum.dataForward.kafka.producer.request.timeout.ms` |                                  `90000` | `dataForwardKafkaProducerRequestTimeoutMs`     | producer request timeout | 未检到直接使用                                               |
| `global.private.rum.dataForward.kafka.producer.max.request.size` |                                `2097152` | `dataForwardKafkaProducerMaxRequestSize`       | producer 请求大小上限    | `DataForwardKafkaProducer.afterOperate()`                    |
| `global.private.rum.dataForward.kafka.producer.buffer.memory` |                               `33554432` | `dataForwardKafkaProducerBufferMemory`         | producer 缓冲区          | `DataForwardKafkaProducer.afterOperate()`                    |
| `global.private.rum.dataForward.kafka.producer.batch.size`   |                                  `81920` | `dataForwardKafkaProducerBatchSize`            | producer batch size      | `DataForwardKafkaProducer.afterOperate()`                    |
| `global.private.rum.dataForward.kafka.producer.retries`      |                                      `5` | `dataForwardKafkaProducerRetries`              | producer retries         | `DataForwardKafkaProducer.afterOperate()`                    |
| `global.private.rum.dataForward.bigData.queue.topic`         |             `DATA-FORWARD-BIGDATA-TOPIC` | `dataForwardBigDataMQTopic`                    | 大数据落盘队列 topic     | `MainManager.dataForwardInit()`                              |
| `global.private.rum.dataForward.bigData.queue.group`         |             `DATA-FORWARD-BIGDATA-GROUP` | `dataForwardBigDataCacheGroup`                 | 大数据落盘队列 group     | `MainManager.dataForwardInit()`                              |
| `global.private.rum.dataForward.bigData.queue.dataSize`      |                                   `2000` | `dataForwardBigDataQueueDataSize`              | 大数据队列容量           | `MainManager.dataForwardInit()`                              |
| `global.private.rum.dataForward.bigData.queue.freeRate`      |                                    `0.9` | `dataForwardBigDataQueueFreeRate`              | 大数据队列空闲率         | `MainManager.dataForwardInit()`                              |
| `global.private.rum.dataForward.bigData.queue.kafkaSize`     |                                   `1000` | `dataForwardBigDataQueueKafkaSize`             | 大数据 Kafka 缓冲上限    | `MainManager.dataForwardInit()`                              |
| `global.private.rum.dataForward.maxSize`                     |                               `52428800` | `dataForwardMaxSize`                           | 超过大小直接落磁盘不转发 | `DataForwardThread.execute()`                                |
| `global.private.rum.dataForward.thread.bigDataSaveNum`       |                                      `1` | `dataForwardThreadBigDataSaveNum`              | 大文件存储线程数         | `MainManager.dataForwardInit()`                              |
| `global.private.rum.dataForward.tempPath`                    | `/data/br/data/common/rum/data_forward/` | `dataForwardTempPath`                          | 大包本地目录             | `SaveFileThread.execute()`                                   |
| `global.private.rum.dataForward.handle.queue.topic`          |              `DATA-FORWARD-HANDLE-TOPIC` | `dataForwardHandleMQTopic`                     | 转发处理队列 topic       | `MainManager.dataForwardInit()`                              |
| `global.private.rum.dataForward.handle.queue.group`          |              `DATA-FORWARD-HANDLE-GROUP` | `dataForwardHandleCacheGroup`                  | 转发处理队列 group       | `MainManager.dataForwardInit()`                              |
| `global.private.rum.dataForward.handle.queue.dataSize`       |                                   `2000` | `dataForwardHandleQueueDataSize`               | 转发处理队列容量         | `MainManager.dataForwardInit()`                              |
| `global.private.rum.dataForward.handle.queue.freeRate`       |                                    `0.9` | `dataForwardHandleQueueFreeRate`               | 转发处理队列空闲率       | `MainManager.dataForwardInit()`                              |
| `global.private.rum.dataForward.handle.queue.kafkaSize`      |                                   `1000` | `dataForwardHandleQueueKafkaSize`              | 转发处理 Kafka 缓冲上限  | `MainManager.dataForwardInit()`                              |
| `global.private.rum.dataForward.handle.thread.num`           |                                      `4` | `dataForwardThreadHandleNum`                   | 转发处理线程数           | `MainManager.dataForwardInit()`                              |

#### 2.1.10 BaseConfig 其他参数

| 配置 key                                                |                           默认值 | 字段                         | 作用                         | 主要引用                                       |
| ------------------------------------------------------- | -------------------------------: | ---------------------------- | ---------------------------- | ---------------------------------------------- |
| `global.private.rum.uniqfield.multiwrite.start.time`    |                             `""` | `uniqfieldStartTime`         | uniq 新老字段双写开始时间    | `BaseConfig.afterOperate()`                    |
| `global.private.rum.uniqfield.multiwrite.duration.days` |                              `7` | `uniqfieldDuration`          | 双写持续天数                 | `BaseConfig.afterOperate()`                    |
| `global.private.rum.action.textTitle.length.limit`      |                             `20` | `actionTextTitleLimit`       | 操作事件 text/title 长度限制 | `DataFormatUtil`                               |
| `global.private.rum.iam.userLocale`                     |        `/api/iam/v1/user/locale` | `iamGetUserLocalUrl`         | 查询用户语言环境             | `UserLocaleEnCache`                            |
| `global.private.rum.metric.max.size`                    |                           `2000` | `metricMaxSize`              | metric 缓存最大长度          | `MetricTaskScheduling.execute()`               |
| `global.private.rum.nebula.send.interval`               |                          `60000` | `nebulaSendInterval`         | 图数据库待发送时间间隔       | `MetricTaskScheduling.execute()`               |
| `global.private.common.biz.upload.topic.list`           |    `BIZ_CONTROLLER_TOPIC0,...,5` | `bizControllerTopicList`     | biz 数据发送 topic 列表      | `BaseService.calculateTopic()`                 |
| `global.private.common.datasee.upload.topic.list`       | `ONE_RUM_DATASEE_TOPIC_0,...,_4` | `dataseeControllerTopicList` | datasee 发送 topic 列表      | `datasee.service.BaseService.calculateTopic()` |
| `global.private.rum.biz.kafka.flag`                     |                              `1` | `bizKafkaFlag`               | biz 数据推送方式             | `datasee.service.BaseService`                  |
| `global.private.rum.biz.retry.num`                      |                          `60000` | `bizMaxRetryNum`             | biz 接口推送最大重试次数     | `datasee.service.BaseService.sendDataByUrl()`  |
| `global.private.common.metric.upload.topic`             |          `ONE_ETL_INNER_METRICS` | `metricUploadTopic`          | span metric 上报 topic       | `MetricTaskScheduling.sendMetricData()`        |
| `global.private.rum.brfs.retryNum`                      |                       `20000000` | `brfsRetryNum`               | BRFS 重试次数                | `BonreeFileSystemClient`                       |
| `global.private.rum.nebula.max.size`                    |                          `10000` | `nebulaMaxSize`              | 图数据库缓存最大长度         | 未检到直接业务读取                             |

#### 2.1.11 GlobalConfig Redis / ClickHouse / Kafka / BRFS / DB

位置：`controller/rum-controller/config/src/main/java/com/bonree/rum/config/config/GlobalConfig.java`

| 配置 key                                |       默认值 | 字段                     | 作用            | 主要引用                                           |
| --------------------------------------- | -----------: | ------------------------ | --------------- | -------------------------------------------------- |
| `global.common.deploy.type`             |          `1` | `deployType`             | 部署类型        | `KafkaConfig.checkPoc()`、`ConfigUtils.checkPoc()` |
| `global.redis.redis.mode`               |          `1` | `redisMode`              | Redis 模式      | `RedisConfig.lettuceConnectionFactory()`           |
| `global.redis.redis.cluster`            |           无 | `redisCluster`           | Redis 集群地址  | `RedisConfig.lettuceConnectionFactory()`           |
| `global.redis.redis.password`           |         `""` | `redisPassword`          | Redis 密码      | `RedisConfig.lettuceConnectionFactory()`           |
| `global.zeus.ch.manager.url`            |         `""` | `chManagerUrls`          | CH manager 地址 | `ZeusClient.init()`、`VmIngestClient.init()`       |
| `global.zeus.ch.jdbc.url`               |         `""` | `clickHouseUrls`         | CH JDBC 地址    | `ZeusClient.init()`                                |
| `global.zeus.zeus.jdbc.catalog`         | `clickhouse` | `zeusCatalog`            | Zeus catalog    | `ZeusClient`                                       |
| `global.kafka.host`                     |         `""` | `kafkaProducerHost`      | Kafka 地址      | `KafkaProducer.afterOperate()`、`MainManager`      |
| `global.brfs.brfs.username`             |       `root` | `brfsUername`            | BRFS 用户名     | `BonreeFileSystemClient.createFileSystemClient()`  |
| `global.brfs.brfs.password`             |      `12345` | `brfsPassword`           | BRFS 密码       | 同上                                               |
| `global.brfs.brfs.hosts`                |         `""` | `brfsHosts`              | BRFS hosts      | 同上                                               |
| `global.brfs.brfs.replices`             |          `2` | `brfsReplices`           | BRFS 副本数     | 未检到直接读取                                     |
| `global.brfs.brfs.connection.pool.size` |        `100` | `brfsConnectionPoolSize` | BRFS 连接池大小 | `BonreeFileSystemClient.createFileSystemClient()`  |
| `global.db.one.driver.class`            |           无 | `dbDriver`               | 主库驱动        | `DataSourceConfig.getDataSource()`                 |
| `global.db.one.url`                     |           无 | `dbUrl`                  | 主库 URL        | `DataSourceConfig.getDataSource()`                 |
| `global.db.one.username`                |           无 | `dbUsername`             | 主库用户名      | `DataSourceConfig.getDataSource()`                 |
| `global.db.one.password`                |           无 | `dbPassword`             | 主库密码        | `DataSourceConfig.getDataSource()`                 |

#### 2.1.12 GlobalConfig 平台地址 / Token / Session / NFS / HTTPS

| 配置 key                          |                 默认值 | 字段             | 作用            | 主要引用                                             |
| --------------------------------- | ---------------------: | ---------------- | --------------- | ---------------------------------------------------- |
| `global.address.web.url.inner`    |                   `""` | `platformUrl`    | 平台内网地址    | `LicenseCache`、`PushLicenseUsedJob`、`ServiceCache` |
| `global.address.web.url`          |                   `""` | `webUrl`         | web 外网地址    | `MainManager`                                        |
| `global.address.web.url.inner`    |                   `""` | `webUrlInner`    | web 内网地址    | 注释代码中出现                                       |
| `global.address.upload.url.inner` |                   `""` | `uploadUrlInner` | upload 内网地址 | `MetricTaskScheduling.sendDataByUrl()`               |
| `global.address.cmdb.url`         |                   `""` | `cmdbServerUrl`  | CMDB 地址       | `CmdbClient.init()`                                  |
| `global.common.one.api.token`     | `eyJhbGciOiJIUzI1NiJ9` | `cloudToken`     | 云接口 token    | `LicenseCache`、`PushLicenseUsedJob`                 |
| `global.common.es.open`           |                 `true` | `sessionOpen`    | 是否开启会话    | `BaseService`、`MainManager.startTrackServer()`      |
| `global.common.nfs.path`          |                  `nfs` | `NFS_BASE_PATH`  | NFS 根路径      | `NfsSaveService`                                     |
| `global.common.root.folder`       |            `/data/br/` | `rootFolder`     | 全局根目录      | `NettyHttpServer`、`RedisConfig`、`MainManager`      |
| `global.common.https.enabled`     |                `false` | `httpsEnable`    | 是否开启 HTTPS  | `NettyHttpServer`、`DataSourceConfig` 等             |
| `global.common.https.crt.path`    |   `conf/common/certs/` | `httpsCrtPath`   | 证书目录        | `DataSourceConfig`、`RedisConfig`                    |

#### 2.1.13 GlobalConfig Query Service / 多中心 / 加密 / SkyEye

| 配置 key                                                     |                 默认值 | 字段                  | 作用                            | 主要引用                                               |
| ------------------------------------------------------------ | ---------------------: | --------------------- | ------------------------------- | ------------------------------------------------------ |
| `global.oneservice.jdbc.url`                                 |                   `""` | `oneServiceJdbcUrl`   | query service JDBC              | `DataSourceConfig.queryService()`                      |
| `global.oneservice.K8sRoundRobin`                            |                `false` | `k8sRoundRobin`       | query service 是否启用 k8s 轮询 | `DataSourceConfig.queryService()`                      |
| `global.datacenter.datacenter.enable`                        |                `false` | `dataCenterEnable`    | 是否开启多中心                  | `LicenseCache.queryAllLicense()`、`PushLicenseUsedJob` |
| `global.datacenter.datacenter.id`                            |                    `1` | `dataCenterId`        | 当前数据中心 ID                 | `BaseService`、`SpanEventService` 等                   |
| `global.datacenter.master.datacenter.id`                     |                    `1` | `masterDataCenterId`  | 主中心 ID                       | `NetworkBaseService`、`CmdbClient.init()`              |
| `global.skyeye.host`                                         |                   `""` | `setSkyEyeHosts`      | SkyEye 地址                     | `MainManager.skyEyeInit()`                             |
| `global.skyeye.token`                                        | `eyJhbGciOiJIUzI1NiJ9` | `setSkyEyeToken`      | SkyEye token                    | `MainManager.skyEyeInit()`                             |
| `global.common.entity.space`                                 |  `entity_relationship` | `relationSpaceName`   | 实体关系 space                  | 未检到直接业务读取                                     |
| `global.private.rum.networkevent.maxUrl.length`              |                 `3000` | `maxUrlLength`        | 网络请求 URL 最大长度           | `DataCheckUtil.truncateUrl()`                          |
| `global.private.rum.networkevent.includeHeader.scenarios.list` |   `healthy,slow,error` | `headerScenariosList` | header 包含场景列表             | `GlobalConfig.afterOperate()`                          |
| `global.common.encrypt.type`                                 |                   `""` | `encryptType`         | 密码/配置加密类型               | `DataSourceConfig`、`RedisConfig`、`KafkaConfig`       |

#### 2.1.14 KafkaConfig

位置：`controller/rum-controller/config/src/main/java/com/bonree/rum/config/config/special/KafkaConfig.java`

| 配置 key                                             |  默认值 | 字段                                | 作用               | 主要引用                             |
| ---------------------------------------------------- | ------: | ----------------------------------- | ------------------ | ------------------------------------ |
| `global.kafka.encrypt.type`                          |  `NONE` | `kafkaProducerEncryptType`          | Kafka 加密类型     | `KafkaConfig.buildKafkaJaasConfig()` |
| `global.kafka.sasl.mechanism`                        | `PLAIN` | `kafkaProducerSaslMechanism`        | Kafka SASL 机制    | 同上                                 |
| `global.kafka.producer.security.auth.login.config`   |     ` ` | `kafkaProducerSecurityAuthConfig`   | producer JAAS 配置 | `KafkaConfig.parseData()`            |
| `global.kafka.consumer.security.auth.login.config`   |     ` ` | `kafkaConsumerSecurityAuthConfig`   | consumer JAAS 配置 | `KafkaConfig.parseData()`            |
| `global.kafka.producer.security.auth.login.username` |    `""` | `kafkaProducerSecurityAuthUsername` | producer 用户名    | `KafkaConfig.parseData()`            |
| `global.kafka.producer.security.auth.login.password` |    `""` | `kafkaProducerSecurityAuthPassword` | producer 密码      | `KafkaConfig.parseData()`            |
| `global.kafka.consumer.security.auth.login.username` |    `""` | `kafkaConsumerSecurityAuthUsername` | consumer 用户名    | `KafkaConfig.parseData()`            |
| `global.kafka.consumer.security.auth.login.password` |    `""` | `kafkaConsumerSecurityAuthPassword` | consumer 密码      | `KafkaConfig.parseData()`            |

补充：`KafkaConfig` 中还有 `@ConfigurationProperties(prefix = "global.kafka")` 绑定的 `producer` / `consumer` map，供各 Kafka 组件初始化时使用。

#### 2.1.15 @ConfigurationProperties 配置类

##### CKThreadConfig

位置：`controller/rum-controller/config/src/main/java/com/bonree/rum/config/config/special/CKThreadConfig.java`

| 前缀                            | 字段     | 默认值 | 作用                          | 主要引用                         |
| ------------------------------- | -------- | -----: | ----------------------------- | -------------------------------- |
| `global.private.rum.zeus.table` | `thread` |     无 | 按表名配置 Zeus/CK 写入线程数 | `ZeusClient.creatTableStreams()` |

##### EncryptionKeyParam

位置：`controller/rum-controller/config/src/main/java/com/bonree/rum/config/config/special/EncryptionKeyParam.java`

| 前缀                            | 字段  | 默认值 | 作用             | 主要引用                                     |
| ------------------------------- | ----- | -----: | ---------------- | -------------------------------------------- |
| `global.private.rum.encryption` | `sm4` |     无 | SM4 密钥版本映射 | `EncryptionHandler.write()`、`channelRead()` |

##### NebulaTableParam

位置：`controller/rum-controller/config/src/main/java/com/bonree/rum/config/config/special/NebulaTableParam.java`

| 前缀                        | 字段    | 默认值 | 作用                  | 主要引用                                        |
| --------------------------- | ------- | -----: | --------------------- | ----------------------------------------------- |
| `global.private.rum.nebula` | `table` |     无 | Nebula 表与数据源映射 | `NebulaBizTypeEnum.getPrivateConfigTableName()` |

##### CustomParam

位置：`controller/rum-controller/config/src/main/java/com/bonree/rum/config/config/special/CustomParam.java`

| 前缀                 | 字段            |                           默认值 | 作用                 | 主要引用                                 |
| -------------------- | --------------- | -------------------------------: | -------------------- | ---------------------------------------- |
| `global.private.rum` | `customer`      |                               无 | 用户自定义配置串     | `ConfigController`                       |
| `global.private.rum` | `table`         |                               无 | 表与数据源配置       | `EtlBizTypeEnum.getSchema()`             |
| `global.private.rum` | `actionTimeout` |                               无 | 操作分析方法超时配置 | `ModelBuiness`、`ActionExitEventService` |
| `global.private.rum` | `errorCode`     | 构造器内置 `curl=[0], win32=[0]` | 网络错误码补充配置   | `DataCheckUtil`                          |

##### ZeusConfig

位置：`controller/rum-controller/config/src/main/java/com/bonree/rum/config/config/special/ZeusConfig.java`

| 前缀              | 字段     | 默认值 | 作用              | 主要引用           |
| ----------------- | -------- | -----: | ----------------- | ------------------ |
| `global.rum.zeus` | `presto` |     无 | Zeus 相关扩展配置 | 未检到直接业务读取 |

### 2.2 framework/plugins/rum

#### 2.2.1 RUMConfig Nacos 连接 / 服务发现

位置：`framework/plugins/rum/rum-common/src/main/java/com/bonree/rum/common/config/RUMConfig.java`

`framework/plugins/rum` 下未使用 `@NacosValue`，`RUMConfig` 是该模块的核心配置承载类，通过配置框架绑定参数，并在多个服务中直接使用。

| 配置 key                                  |                  默认值 | 字段                  | 作用                           | 主要引用                                  |
| ----------------------------------------- | ----------------------: | --------------------- | ------------------------------ | ----------------------------------------- |
| `NACOS_SERVER`                            |            无类内默认值 | `nacosHost`           | Nacos 地址                     | `DiscoveryService.initNamingService()`    |
| `GLOBAL_NAMESPACE` / 回退 `ONE_NAMESPACE` |                      无 | `discoveryNamespace`  | Nacos namespace                | `DiscoveryService.initNamingService()`    |
| `GLOBAL_GROUP` / 回退 `ONE_GROUP`         |                      无 | `discoveryGroup`      | Nacos group                    | `DiscoveryService.getControllerAddress()` |
| `global.private.rum.server.name`          |        `RUM_CONTROLLER` | `discoveryServerName` | Nacos 中 rum-controller 服务名 | `DiscoveryService.getControllerAddress()` |
| `global.private.rum.server.address`       | `http://127.0.0.1:8888` | `trackServerUrl`      | 发现不到服务时的兜底地址       | `DiscoveryService.getControllerAddress()` |

#### 2.2.2 RUMConfig 上传地址 / 基础 URL / JS Agent / Symbol / RestTemplate

| 配置 key                                                   |             默认值 | 字段                       | 作用                    | 主要引用                                                     |
| ---------------------------------------------------------- | -----------------: | -------------------------- | ----------------------- | ------------------------------------------------------------ |
| `global.address.upload.url`                                |                 无 | `baseUrl`                  | upload 基础地址         | `RumApiController.jsinfoNew()`、`RumCommonServiceImpl.jsInfo()` |
| `global.address.upload.url.http`                           |                 无 | `baseUrlHttp`              | HTTP 基础地址           | `RumApiController.jsinfoNew()`                               |
| `global.private.rum.controller.path`                       |             `/RUM` | `basePath`                 | rum 接口前缀            | `RumCommonServiceImpl.jsInfo()`、`RumAddressController.getAddress()` |
| `global.private.rum.upload.address`                        |          `/upload` | `uploadAddr`               | upload 路径             | `RumCommonServiceImpl.jsInfo()`                              |
| `global.private.rum.js.script.id`                          |      `BonreeAgent` | `scriptId`                 | JS Agent script 标签 ID | `RumCommonServiceImpl.jsInfo()`                              |
| `global.private.rum.js.agent.cache.dir`                    |             `tmp/` | `agentBaseDir`             | JS agent 本地缓存目录   | `RumApiController.downloadjs()`                              |
| `global.private.rum.android.symbol.file.path`              |   `android_symbol` | `androidSymbol`            | Android 符号文件目录    | `ConfigAggServiceImpl.getSymbolBasePath()`                   |
| `global.private.rum.ios.symbol.file.path`                  |       `ios_symbol` | `iosSymbol`                | iOS 符号文件目录        | `ConfigAggServiceImpl.getSymbolBasePath()`                   |
| `global.private.rum.js.sourcemap.brfs.sr`                  | `T_RUM_SOURCE_MAP` | `sourceMapBrfsSR`          | sourcemap BRFS 存储名   | `RumSymbolicController`                                      |
| `global.private.rum.restTemplate.connectionRequestTimeout` |            `30000` | `connectionRequestTimeout` | RestTemplate 请求超时   | `RestTemplateConfig.customRestTemplate()`                    |
| `global.private.rum.restTemplate.connectTimeout`           |           `120000` | `connectTimeout`           | RestTemplate 连接超时   | `RestTemplateConfig.customRestTemplate()`                    |
| `global.private.rum.restTemplate.readTimeout`              |            `60000` | `readTimeout`              | RestTemplate 读超时     | `RestTemplateConfig.customRestTemplate()`                    |

#### 2.2.3 RUMConfig 查询 / Session / ES/CK / 线程池

| 配置 key                                           | 默认值 | 字段                        | 作用                                   | 主要引用                                             |
| -------------------------------------------------- | -----: | --------------------------- | -------------------------------------- | ---------------------------------------------------- |
| `global.common.es2ck.rum.query.ttl`                |     无 | `esToCkRumQueryTtl`         | session replay 查询 TTL                | `RumSessionReplayQueryFactory.getService()`          |
| `global.private.rum.es.processListBucket`          |  `300` | `processListBucket`         | 电量分析进程列表分桶上限               | `CoulometryServiceImpl`                              |
| `global.private.rum.es.expireTime`                 |   `14` | `expireTime`                | ES 数据过期时间/历史判断               | `RumCkSessionService`、`RetrievalService`            |
| `global.private.rum.web.thread.query.metric.core`  |   `10` | `queryMetricCoreSize`       | 指标查询线程池 core                    | `ExecuteService.getMetricQueryExecute()`             |
| `global.private.rum.web.thread.query.metric.max`   |  `100` | `queryMetricMaxSize`        | 指标查询线程池 max                     | 同上                                                 |
| `global.private.rum.web.thread.query.metric.queue` | `3000` | `queryMetricQueueSize`      | 指标查询线程池队列                     | 同上                                                 |
| `global.private.rum.web.thread.query.stack.core`   |    `8` | `stackAnalysisCoreSize`     | 堆栈解析线程池 core                    | `ExecuteService.getStackExecute()`                   |
| `global.private.rum.web.thread.query.stack.max`    |   `64` | `stackAnalysisMaxSize`      | 堆栈解析线程池 max                     | 同上                                                 |
| `global.private.rum.web.thread.query.stack.queue`  | `1024` | `stackAnalysisQueueSize`    | 堆栈解析线程池队列                     | 同上                                                 |
| `global.private.rum.query.ck.session.limit`        |  `500` | `queryCkSessionLimit`       | session 列表查询上限                   | `RumCkSessionService.querySessionList()`             |
| `global.private.rum.query.entity.limit`            | `1000` | `queryEntityLimit`          | 实体筛选结果上限                       | `RumQueryServiceSnapshotFilterUtil`                  |
| `global.private.rum.session.days.ago`              |   `13` | `sessionDaysAgo`            | CK session 查询最大时间范围            | `RumCkSessionService`、`RumCkSessionSearchService`   |
| `global.private.rum.session.id.start.time.limit`   | `1000` | `sessionIdStartTimeLimit`   | 通过前 N 个 session 计算起始时间的限制 | `RumCkSessionService.querySessionStartTimeOfLimit()` |
| `global.private.rum.session.query.time.expansion`  |   `60` | `sessionQueryTimeExpansion` | session 查询时间窗扩展值               | `RumCkSessionService.querySessionList()`             |

#### 2.2.4 RUMConfig DataSource / 表映射 / Replay / Header / Full Collection

| 配置 key                                                 |                            默认值 | 字段                         | 作用                      | 主要引用                                              |
| -------------------------------------------------------- | --------------------------------: | ---------------------------- | ------------------------- | ----------------------------------------------------- |
| `global.private.rum.table.t_dru_rum_stat_snapshot`       |         `rum_datasource_snapshot` | `configSnapshot`             | 配置快照数据源            | `ZeusTableEnum.getConfigDataSource()`                 |
| `global.private.rum.table.t_dru_rum_stat_session`        |             `rum_datasource_gran` | `configSessionGran`          | 配置统计数据源            | `ZeusTableEnum.getConfigDataSource()`                 |
| `global.private.rum.table.t_dru_rum_stat_h5`             |              `rum_datasource_net` | `configH5NetPerf`            | 配置 H5/网络数据源        | `ZeusTableEnum.getConfigDataSource()`                 |
| `global.private.rum.table.t_dru_rum_stat_crash_snapshot` |   `rum_datasource_crash_snapshot` | `configCrashSnapshot`        | 配置崩溃快照数据源        | `ZeusTableEnum.getConfigDataSource()`                 |
| `global.private.rum.table.sessionDataSource`             | `rum_datasource_session_snapshot` | `sessionDataSource`          | 配置 session 数据源       | `ZeusTableEnum.getConfigDataSource()`                 |
| `global.private.rum.replay.upload.address`               |                   `/uploadReplay` | `sessionReplayUploadAddress` | replay 上报地址           | `RumCommonServiceImpl.getModuleConfigurationConfig()` |
| `global.private.rum.replay.upload.cycle`                 |                              `15` | `sessionReplayUploadCycle`   | replay 上传周期           | `RumCommonServiceImpl.getModuleConfigurationConfig()` |
| `global.private.rum.header.collection.strategy`          |                               `2` | `headerCollectionStrategy`   | 网络 header 采集策略      | `RumCommonServiceImpl.getModuleConfigurationConfig()` |
| `global.private.rum.net.full_collection`                 |                               `0` | `fullCollection`             | 网络 full collection 开关 | `RumCommonServiceImpl.getModuleConfigurationConfig()` |

#### 2.2.5 RUMConfig 权限缓存 / 向导 / 加密 / 多中心 / 其他

| 配置 key                                                  |                               默认值 | 字段                              | 作用                         | 主要引用                                                     |
| --------------------------------------------------------- | -----------------------------------: | --------------------------------- | ---------------------------- | ------------------------------------------------------------ |
| `global.private.rum.permission.local.switch`              |                              `false` | `permissionLocalSwitch`           | 是否启用本地权限缓存         | `PermissionUtil.hasPermissions()`                            |
| `global.private.rum.permission.local.expire`              |                                 `30` | `permissionLocalExpire`           | 本地权限缓存过期时间         | `RUMConfig.afterOperate()`                                   |
| `global.private.rum.permission.local.cache.maximum.size`  |                              `50000` | `permissionLocalCacheMaximumSize` | 本地权限缓存最大条数         | `RUMConfig.afterOperate()`                                   |
| `global.private.rum.permission.redis.expire`              |                                `300` | `permissionRedisExpire`           | Redis 权限缓存过期时间       | `RedisPermissionUtil.updatePermission()`                     |
| `global.private.rum.encryption`                           |                                   无 | `encryptionVersionKey`            | 加密版本与 key 配置          | `RumCommonServiceImpl.getEncryptionVersionKey()`             |
| `global.private.rum.symbol.analysis.base.path`            |          `data/common/rum/analysis/` | `symbolAnalysisBasePath`          | 符号化文件基础路径           | `InitService.initRumSymbolAnalysis()`                        |
| `global.private.rum.symbol.analysis.open.log`             |                               `true` | `openAnalysisInfoLog`             | 是否开启符号化 info 日志     | `InitService.initRumSymbolAnalysis()`                        |
| `global.private.common.path`                              |                         初始值 `one` | `ONE_PATH`                        | 公共路径前缀                 | `ConfigAggServiceImpl.getSymbolBasePath()`                   |
| `global.common.root.folder`                               |                          `/data/br/` | `rootFolder`                      | 根目录                       | `InitService`、`RumApiController`                            |
| `global.common.encrypt.type`                              |                                   无 | `encryptType`                     | 加密方式                     | `RestTemplateConfig.customRestTemplate()`                    |
| `global.datacenter.datacenter.enable`                     |                              `false` | `dataCenterEnable`                | 多中心开关                   | `RumApiController.jsinfoNew()`、`RemoteService.getIngesterUrl()` |
| `global.datacenter.datacenter.id`                         |                                  `1` | `dataCenterId`                    | 当前中心 ID                  | `RumCommonServiceImpl.jsInfo()`                              |
| `global.datacenter.master.datacenter.id`                  |                                  `1` | `masterDataCenterId`              | 主中心 ID                    | `RemoteService.getIngesterUrl()`                             |
| `global.datacenter.datacenter.list`                       |                                   无 | `dataCenterList`                  | 数据中心定义列表             | `RUMConfig.afterOperate()`                                   |
| `global.datacenter.datacenter.upload.url.list`            |                                   无 | `dataCenterUploadList`            | 各中心 upload 地址映射       | `RumAddressController.getAddress()`                          |
| `global.datacenter.datacenter.ingester.url.list`          |                                   无 | `dataCenterIngesterList`          | 各中心 ingester 地址映射     | `RemoteService.getIngesterUrl()`                             |
| `global.private.rum.networkevent.maxUrl.length`           |                               `3000` | `maxUrlLength`                    | 网络 URL 最大长度            | `RetrievalService`                                           |
| `global.private.rum.trace.sample.rate`                    |                                   无 | `traceSampleRate`                 | trace 采样率                 | `RumCommonServiceImpl.addPrivateWebAgentSettings()`          |
| `global.private.rum.openapi.check.filters`                |                               `true` | `checkFilters`                    | OpenAPI 是否校验 filters     | `RumOpenApiBaseController.checkFilters()`                    |
| `global.address.web.url.inner`                            |                                   无 | `webInnerUrl`                     | web 内网地址                 | `RumConfigWizardService.getWizardDownloadUrlPrefix()`        |
| `global.address.download.url`                             |                                   无 | `agentDownloadUrl`                | agent 下载地址               | `RumConfigWizardService.getWizardDownloadUrlPrefix()`        |
| `global.private.rum.etl.config.send`                      |                               `true` | `config2Etl`                      | 配置变更是否通知 ETL         | `RemoteService.sendConfigChange2ETL()`                       |
| `global.private.rum.network.rule.param.num`               |                                 `64` | `maxParamNum`                     | 网络自定义识别规则最大参数数 | `RuleServiceImpl.validateParamLimitCount()`                  |
| `global.private.rum.wizard.max.version.count`             |                                 `30` | `wizardMaxVersionCount`           | 向导版本最大创建数           | `RumConfigWizardService`                                     |
| `global.private.rum.wizard.token.expire.seconds`          |                              `86400` | `wizardTokenExpireSeconds`        | 向导 token 过期时间          | `RumConfigWizardService.saveTokenConfig()`                   |
| `global.private.rum.wizard.package.limit.size`            |                          `209715200` | `wizardPackageLimitSize`          | 向导上传包大小限制           | `RumConfigWizardService`                                     |
| `global.private.rum.wizard.archive.import.path`           | `/data/br/conf/one_framework/wizard` | `wizardArchiveImportPath`         | 向导归档自动导入扫描路径     | `RumWizardArchiveImportJob`                                  |
| `global.private.rum.wizard.archive.import.enable`         |                               `true` | `wizardArchiveImportEnable`       | 是否开启向导归档自动导入     | `RumWizardArchiveImportJob.importWizardArchives()`           |
| `global.private.rum.wizard.supported.file.extensions`     |                  `zip,sh,exe,tar,gz` | `wizardSupportedFileExtensions`   | 向导支持上传的文件扩展名     | `RumConfigWizardService.isSupportedFileExtension()`          |
| `global.private.rum.wizard.cleanup.thread.pool.core.size` |                                  `2` | `wizardCleanupThreadPoolCoreSize` | 临时文件清理线程池 core 数   | `RumWizardTempFileCleanupService`                            |
| `global.private.rum.wizard.temp.file.path`                |                      `/data/common/` | `wizardTempFilePath`              | 向导临时文件目录             | `RumConfigWizardService.archiveWizard()`                     |

#### 2.2.6 RUMConfig 中扫描到但未发现直接 Java 读取的参数

这些参数仍属于配置项，但本次扫描中未看到明确消费点，可能被基础框架或 XML 配置间接消费、仅在老逻辑中保留或后续扩展预留：

- `global.common.es2ck.rum.write`
- `global.common.es2ck.apm.write`
- `global.common.es2ck.apm.query.ttl`
- `global.private.rum.es.index.track`
- `global.private.rum.es.index.session-prefix`
- `global.private.rum.es.index.call-chain-index`
- `global.private.rum.es.query-event-num`
- `global.private.rum.es.filter-cardinality-num`
- `global.private.rum.es.bucketNum`
- `global.private.rum.shard.offset`
- `global.private.rum.protocol.expireTime`
- `global.private.rum.ios.system.symbol.file.path`
- `global.private.rum.web.thread.query.stack.time`
- `global.private.common.storage.type`
- `global.common.nfs.path`
- `global.brfs.brfs.replices`
- `global.common.brfs.path`
- `global.private.rum.common.extensions.path`
- `global.private.rum.table.electricityDataSource`
- `global.private.rum.query.ck.cluster.name`

#### 2.2.7 RuleLimitConfig 规则数量上限

位置：`framework/plugins/rum/rum-core/src/main/java/com/bonree/rum/core/common/config/RuleLimitConfig.java`

用于控制各类规则的最大数量，实际入口为 `RuleServiceImpl.ruleAdd()`，通过 `ruleLimitConfig.getLimit(req.getClassType())` 取上限。

| 配置 key                                            | 默认值 | 字段                  | 作用                      | 主要引用                     |
| --------------------------------------------------- | -----: | --------------------- | ------------------------- | ---------------------------- |
| `global.private.rum.rule.limit.appPage`             |   `10` | `appPage`             | 终端应用-页面识别规则上限 | `RuleLimitConfig.getLimit()` |
| `global.private.rum.rule.limit.appNet`              |   `50` | `appNet`              | 终端网络请求识别规则上限  | 同上                         |
| `global.private.rum.rule.limit.aiNet`               |   `10` | `aiNet`               | AI 慢速检测网络规则上限   | 同上                         |
| `global.private.rum.rule.limit.sessionSatisfaction` |   `10` | `sessionSatisfaction` | 健康评分-用户会话规则上限 | 同上                         |
| `global.private.rum.rule.limit.abnormalNetwork`     |   `10` | `abnormalNetwork`     | 异常判定-网络请求规则上限 | 同上                         |
| `global.private.rum.rule.limit.appPageMp`           |   `10` | `appPageMp`           | 小程序页面识别规则上限    | 同上                         |
| `global.private.rum.rule.limit.module`              |   `10` | `module`              | 业务模块识别规则上限      | 同上                         |
| `global.private.rum.rule.limit.crashRecognize`      |   `10` | `crashRecognize`      | 崩溃识别规则上限          | 同上                         |
| `global.private.rum.rule.limit.maxLimit`            |  `100` | `maxLimit`            | 统一最大上限兜底          | `RuleLimitConfig.getLimit()` |

补充：`defaultLimit = 10` 是类内常量，不是 Nacos 参数。

### 2.3 核心配置类汇总

#### controller/rum-controller

- `BaseConfig`：核心 Nacos 参数类，覆盖接口入口、队列容量、线程池、去重、时间校验、H5 阈值、数据转发、Replay、VM 双写、追踪/在线调试等。
- `GlobalConfig`：Redis / ClickHouse / Kafka / BRFS / DB / 平台地址 / 多中心等全局基础设施参数。
- `KafkaConfig`：Kafka 加密、SASL、JAAS 配置。
- `CKThreadConfig`：按表名配置 Zeus/CK 写入线程数。
- `EncryptionKeyParam`：SM4 密钥版本映射。
- `NebulaTableParam`：Nebula 表与数据源映射。
- `CustomParam`：用户自定义配置串、表与数据源、操作分析方法超时、网络错误码补充。
- `ZeusConfig`：Zeus 相关扩展配置。

#### framework/plugins/rum

- `RUMConfig`：模块核心配置承载类，包括 Nacos 连接、上传地址、查询/Session、数据源映射、权限缓存、向导、多中心等。
- `RuleLimitConfig`：各类规则数量上限控制。

---

## 三、配置下发逻辑

### 3.1 配置下发入口接口

| 接口路径                  | 所在模块                    | 说明                                      |
| ------------------------- | --------------------------- | ----------------------------------------- |
| **`POST /rum/v1/config`** | `controller/controller`     | 统一 Controller 入口，供 SDK 探针拉取配置 |
| **`POST /config`**        | `controller/rum-controller` | RUM 独立 Netty 服务入口                   |

### 3.2 配置下发主流程

以 `controller/controller` 的 `RumConfigServiceImpl.execute()` 为例：

1. **参数校验**：URL 参数 `d`、`a` 等；请求体协议参数
2. **协议解析**：支持 GZIP，解析为 `ConfigRequestEntity`
3. **应用过滤**：`filterApp`，根据 appMd5 查找应用
4. **设备过滤**：`DeviceFilter`
5. **采集概率/白名单**：`filterSdkCollectRate`
6. **License 校验**：`checkLicense`
7. **生成 sessionId**
8. **落库基础信息**：`saveData`
9. **构建配置响应**：`buildConfigResponse`（核心逻辑）

### 3.3 配置响应构建（buildConfigResponse）

配置来源分三类：

1. **本地缓存**
   - `AppCache`、`AppVersionCache`、`CollectConfigCache`（应用/版本/采集配置）
   - `TerminalUserGroupCache`、`UserGroupCache`（用户组、白名单）

2. **Redis 用户配置**
   - `RumUserEnvVO`：轨迹规则、网络规则、业务模块规则
   - `RumUserAppVO`：敏感信息脱敏规则

3. **系统全局配置** `PrivateConfig`：恢复周期、上传地址、ping 地址等

### 3.4 下发的配置内容（ConfigResponseModel）

| 字段                                                         | 说明                                                         |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| `sessionId`                                                  | 会话 ID                                                      |
| `modelConfigs`                                               | 采集模块配置（启动、崩溃、卡顿、ANR、H5、网络、视图、操作、自定义事件、会话回放等） |
| `uploadAddress`                                              | 数据上报地址                                                 |
| `insertRequestHeaderTraceConfig`                             | 端到端 trace 域名配置                                        |
| `requestHeaderTraceKeys` / `responseHeaderTraceKeys`         | 请求头/响应头采集 key                                        |
| `customBusinessHeaderKeys` / `customBusinessBodyKeys` / `customBusinessQueryKeys` | 自定义业务字段                                               |
| `sensitiveNetworkRuleModel`                                  | 敏感信息脱敏规则                                             |
| `traceThreshold`                                             | 轨迹长度                                                     |
| `headerCollectionStrategy`                                   | Header 采集策略（0: 不采 / 1: 仅错误 / 2: 全量）             |

### 3.5 采集模块配置（ModelBuiness.buildModel）

根据 `appVersionConfig`、`appLevelConfig` 决定启用的采集模块及参数：

- 系统事件：热启动、冷启动、状态变化
- 问题数据：崩溃、卡顿、ANR、Widget 崩溃
- 页面加载：H5、单页路由
- 网络
- 视图（含小程序视图）
- 操作采集
- 自定义事件/日志/指标
- 电量
- 会话回放

### 3.6 配置同步链路（平台配置 → Redis）

**Pull（从 DB 拉取）**：
- `RumUserEnvConfigPull`：用户环境配置
- `RumUserAppConfigPull`：用户应用配置

**Flush（写入 Redis）**：
- `RumUserEnvConfigFlush`：Module、NetWork、Trace 规则 → `RUM_USER_ENV_CONFIG_KEY`
- `RumUserAppConfigFlush`：敏感信息规则 → `RUM_USER_APP_CONFIG_KEY`

**驱动**：`SyncServiceImpl` 调用 `RumConfigFlushTemplate` 执行 Pull + Flush。

### 3.7 framework/plugins/rum 中的配置相关接口

framework 层主要是平台管理接口，不直接负责 SDK 配置下发：

- `RumAddressController`：`GET /rest/rum/address`，地址查询
- `RumConfigWizardController`：`POST /rest/rum/wizard/config`，探针向导配置
- `TerminalCollectController`：终端采集管理（地域、采集开关、快照、黑/白名单等）
- `TraceController`：轨迹域名配置
- `NetworkReqAggController`、`TerminalAggController`：网络/终端聚合识别配置

### 3.8 整体流程示意

```
平台配置变更（DB）
        ↓
SyncServiceImpl（RumConfigFlushTemplate）
        ↓
IConfigPull（RumUserEnvConfigPull、RumUserAppConfigPull）
        ↓
IConfigFlush（RumUserEnvConfigFlush、RumUserAppConfigFlush）
        ↓
Redis（RUM_USER_ENV_CONFIG_KEY、RUM_USER_APP_CONFIG_KEY）
        ↓
探针请求 /rum/v1/config 或 POST /config
        ↓
RumConfigServiceImpl.execute()
        ↓
AppCache / CollectConfigCache + RumCacheService（Redis）
        ↓
buildConfigResponse → ConfigResponseModel
        ↓
返回给探针
```

### 3.9 关键代码路径

| 功能         | 文件路径                                                     |
| ------------ | ------------------------------------------------------------ |
| 配置入口     | `controller/controller/.../ConfigController.java`            |
| 配置服务实现 | `controller/controller/.../rum/impl/RumConfigServiceImpl.java` |
| 模块配置构建 | `controller/controller/.../rum/impl/ModelBuiness.java`       |
| 缓存服务     | `controller/controller/.../rum/impl/RumCacheServiceImpl.java` |
| 配置同步模板 | `controller/controller/.../sync/template/RumConfigFlushTemplate.java` |
| 响应模型     | `controller/controller/.../domain/model/rum/response/ConfigResponseModel.java` |

### 3.10 缓存策略与生效时机

- **本地缓存**：`AppCache`、`AppVersionCache`、`CollectConfigCache`、`TerminalUserGroupCache`、`UserGroupCache` 等由 `rum-cache` 模块的 `JobFactory` 按注册的执行间隔定时刷新（如 `FiveMinuteJob`、`OneMinuteJob`、`OneDayJob`），变更在下一个刷新周期内对探针可见。
- **Redis 用户配置**：由 `SyncServiceImpl` 调用 `RumConfigFlushTemplate` 主动 Pull + Flush 写入 Redis，探针请求时由 `RumCacheService` 读取，变更实时性取决于 SyncService 的触发频率与平台配置变更通知链路。
- **系统全局配置** `PrivateConfig`：由 Nacos 自动刷新回调驱动，`BaseConfig.afterOperate()` 等回调完成派生参数初始化，无需重启即可生效。
- **权限缓存**：本地 Caffeine 缓存（`permission.local.expire` 默认 30 秒）→ Redis 缓存（`permission.redis.expire` 默认 300 秒）→ 远程 IAM 查询，三级回源；用户权限变更时 `PermissionUtil.cleanRedisCache()` 通过 SCAN 命令按 pattern 批量清理 Redis key。
- **实时性要求高**的查询（如当前活跃会话、实时告警）禁止长期缓存，避免数据滞后。

### 3.11 配置变更风险矩阵建议

针对每个配置项，建议标注以下维度（治理建议）：

- 是否支持热更新
- 是否影响上报口径
- 是否影响入库
- 是否影响查询
- 是否需要重启

并按以下三类区分"未发现直接引用"的参数：

- 仍由框架隐式使用
- 已废弃可删除
- 未来预留

对 `BaseConfig` 可做二次治理，按功能拆分为多个配置类，降低维护复杂度。
