# HumanDialogueClient MVVM 架构说明

## 1. 架构总览

这个项目采用的是典型的 SwiftUI + MVVM 分层，但实现方式比较务实，核心特点如下：

- `App` 和顶层容器负责应用启动与依赖装配。
- `View` 负责界面展示和用户事件转发。
- `ViewModel` 负责页面状态、业务编排和异步流程控制。
- `Model` 负责表达轻量级业务数据和配置数据。
- `Service` 负责封装网络、文件、相机、RTC 等外部能力。
- `Utils` 提供常量、权限请求、格式化等横切能力。

当前项目的业务规则主要集中在 `ViewModel` 层，`Model` 层相对轻量，属于“小而清晰”的 MVVM 结构。

## 2. 分层结构与目录映射

### App 层

#### `HumanDialogueClientApp`

- 应用入口。
- 使用 `@StateObject` 创建全局共享的 `SettingsViewModel`。
- 通过 `.environmentObject(settingsViewModel)` 注入到根视图树。

#### `ContentView`

- 顶层容器视图，同时也是当前项目的轻量级组合根。
- 使用 `TabView` 组织 3 个主功能页面：
  - `DialogueView`
  - `VideoListView`
  - `SettingsView`
- 在这里完成功能级 `ViewModel` 与 `Service` 的组装：
  - `DialogueViewModel(rtcService: RTCService())`
  - `VideoViewModel(networkService: NetworkService(config: settingsViewModel.serverConfig))`
  - `SettingsView(viewModel: settingsViewModel)`

因此，这个项目的依赖注入入口主要就在 `ContentView`。

## 3. Model 层分析

当前 `Models` 目录里的类型都比较纯粹，没有复杂行为，主要承担“数据表达”的职责。

### `DialogueState`

- 表示实时会话页面的状态机。
- 枚举值包括：
  - `idle`
  - `preparing`
  - `connecting`
  - `streaming`
  - `ending`
  - `error`

这个模型直接被 `DialogueViewModel` 使用，用于驱动页面状态文案和控制逻辑。

### `RecordedVideo`

- 表示本地录制视频的数据模型。
- 主要字段包括：
  - `id`
  - `fileName`
  - `fileURL`
  - `createdAt`
  - `duration`

它是视频列表页、视频播放页和文件服务之间共享的核心数据对象。

### `ServerConfig`

- 表示服务端配置。
- 当前只有一个字段：`baseURL`。
- 提供 `default` 默认值，默认值来自 `Constants.defaultBaseURL`。

它是设置页和上传功能之间的桥梁模型。

## 4. Service 层分析

`Service` 层的作用，是把系统能力和基础设施能力从 `ViewModel` 中拆出去，避免页面逻辑直接依赖底层 API。

### `RTCService`

职责：

- 封装 RTC 会话状态。
- 提供是否初始化、是否在房间中、麦克风状态、远端音视频状态、当前房间 ID 等信息。
- 提供加入房间、离开房间、控制麦克风的方法。

当前特点：

- 现在还是一个占位实现，没有接入真实 WebRTC/RTC SDK。
- 它更像一个“会话状态控制器”，供 `DialogueViewModel` 调用并同步状态。

### `VideoService`

职责：

- 封装相机预览和录制流程。
- 管理 `AVCaptureSession`。
- 负责相机会话初始化、预览启动/停止、录制状态维护。

当前特点：

- 已经把 `AVFoundation` 的核心细节与页面隔离开。
- 当前录制实现还是占位式包装，重点在于先建立完整调用链和预览能力。
- 使用专门的 `sessionQueue` 控制预览启动与停止，避免直接在主线程操作采集会话。

### `FileService`

职责：

- 管理本地视频文件目录。
- 生成视频和音频输出路径。
- 枚举本地录制的视频文件。
- 删除指定视频文件。

它是视频模块的本地存储抽象层。

### `NetworkService`

职责：

- 封装视频上传接口。
- 根据 `ServerConfig.baseURL` 创建上传请求。
- 组装 multipart/form-data 请求体。
- 使用 `URLSession` 执行上传。

这个服务完全属于基础设施层，不直接处理 UI 状态。

## 5. ViewModel 层分析

`ViewModel` 层是当前项目 MVVM 架构的核心。每个主页面基本都有自己独立的状态管理对象。

### `SettingsViewModel`

职责：

- 持有 `serverConfig`。
- 初始化时从 `UserDefaults` 读取持久化配置。
- 在 `serverConfig` 变化时自动保存。

它在架构中的角色：

- 作为“设置页配置状态”的单一数据源。
- 同时承担“配置持久化协调者”的职责。

这个 `ViewModel` 比较纯粹，逻辑也最简单。

### `DialogueViewModel`

它维护的主要页面状态包括：

- `dialogueState`
- `errorMessage`
- `isSessionActive`
- `isMicrophoneEnabled`
- `remoteVideoActive`
- `remoteAudioActive`
- `currentRoomID`

职责：

- 响应 `DialogueView` 的用户操作。
- 请求相机和麦克风权限。
- 调用 `RTCService` 初始化、加入房间、离开房间、控制麦克风。
- 把底层 RTC 状态转换为界面可消费的状态。
- 提供 `statusDescription` 这类更适合直接给 UI 展示的派生数据。

这个类体现了 MVVM 中最典型的职责划分：

- `View` 不知道 RTC 细节。
- `Service` 不关心 UI 文案。
- `DialogueViewModel` 负责把“底层能力”翻译成“页面状态”。

### `VideoViewModel`

它维护的主要页面状态包括：

- `videos`
- `isRecording`
- `uploadingVideoID`
- `successMessage`
- `errorMessage`

同时还对外暴露：

- `previewSession`
- `isPreviewRunning`

职责：

- 响应视频页的录制、上传、删除、刷新等操作。
- 请求相机和麦克风权限。
- 协调 `VideoService`、`FileService`、`NetworkService` 三个服务。
- 在操作完成后刷新视频列表。
- 把底层错误转换成页面可直接展示的字符串。

它是当前项目中业务编排最集中的 `ViewModel`，也是最典型的“多服务协作型 ViewModel”。

## 6. View 层分析

View 层整体较薄，基本遵循“状态驱动 UI，交互回调给 ViewModel”的原则。

### `DialogueView`

职责：

- 使用 `@StateObject` 持有 `DialogueViewModel`。
- 显示远端视频区域、控制按钮和状态信息卡片。
- 把用户操作转发给 `DialogueViewModel`：
  - 开始会话
  - 结束会话
  - 切换麦克风

页面本身不负责会话逻辑，只负责展示和触发动作。

### `VideoListView`

职责：

- 使用 `@StateObject` 持有 `VideoViewModel`。
- 展示录制区域、实时预览、本地视频列表。
- 提供上传、删除、刷新等交互入口。
- 根据 `ViewModel` 的状态展示成功或失败提示。

这是一个非常标准的 MVVM 列表页实现。

### `SettingsView`

职责：

- 通过 `@ObservedObject` 观察 `SettingsViewModel`。
- 使用表单直接绑定 `serverConfig.baseURL`。

这个页面说明了当前项目 MVVM 的另一个特点：简单页面可以直接使用双向绑定，不需要额外中间层。

### 辅助视图

#### `VideoPlayerView`

- 负责播放某个 `RecordedVideo`。
- 因为几乎没有业务逻辑，所以没有单独的 `ViewModel`。

#### `CameraPreviewView`

- 使用 `UIViewRepresentable` 封装 `AVCaptureVideoPreviewLayer`。
- 作用是把 UIKit/AVFoundation 的预览能力桥接到 SwiftUI。

#### `WebRTCSampleWebView`

- 使用 `UIViewRepresentable` 封装 `WKWebView`。
- 用于承载 WebRTC 官方 sample 页面。
- 通过 `Binding<String>` 把 WebView 错误回传给上层。

这几个辅助视图本质上都是“平台桥接适配器”，仍然属于 View 层。

## 7. 依赖注入与对象装配方式

当前项目采用的是手动构造 + 构造器注入，没有引入 DI 容器。

装配路径如下：

1. `HumanDialogueClientApp` 创建全局 `SettingsViewModel`
2. `ContentView` 从环境中获取 `SettingsViewModel`
3. `ContentView` 为不同 tab 现场创建对应的 `ViewModel` 和 `Service`

这种方式的优点：

- 简单直接
- 依赖来源清晰
- 阅读成本低
- 小型项目里足够实用

需要注意的一点：

- `VideoViewModel` 初始化时接收的是 `NetworkService(config: settingsViewModel.serverConfig)`。
- 这意味着 `NetworkService` 拿到的是一个创建时刻的 `ServerConfig` 快照。
- 如果设置页之后修改了地址，已创建的 `VideoViewModel` 和其内部 `NetworkService` 不会自动同步更新。

这不是 MVVM 的问题，而是当前依赖装配方式带来的状态同步边界。

## 8. 三条核心业务链路的数据流

### 8.1 实时会话链路

数据流如下：

1. 用户在 `DialogueView` 点击“开始会话”
2. `DialogueView` 调用 `DialogueViewModel.startSession()`
3. `DialogueViewModel` 通过 `PermissionManager` 请求麦克风和相机权限
4. 权限通过后，调用 `RTCService.initialize()` 与 `RTCService.joinRoom()`
5. `DialogueViewModel` 调用 `syncRTCState()` 把服务层状态同步到 `@Published` 属性
6. `DialogueView` 根据这些状态重新渲染
7. 会话激活后显示 `WebRTCSampleWebView`

这里体现的是典型的 MVVM 闭环：

- 用户操作从 `View` 发起
- 业务控制在 `ViewModel`
- 能力调用在 `Service`
- 结果回到 `ViewModel`
- 最终驱动 `View`

### 8.2 视频录制与上传链路

数据流如下：

1. 用户在 `VideoListView` 点击“开始录制”
2. `VideoViewModel.startRecording()` 请求权限
3. `FileService` 创建输出文件路径
4. `VideoService` 启动录制与预览
5. `VideoViewModel` 更新 `isRecording` 并调用 `loadVideos()`
6. 页面根据 `videos` 和 `isPreviewRunning` 更新 UI
7. 用户在某条视频上触发上传
8. `VideoViewModel.uploadVideo(_:)` 调用 `NetworkService.uploadVideo(fileURL:)`
9. 上传结果被转换成 `successMessage` 或 `errorMessage`
10. `VideoListView` 直接根据这些状态显示反馈

这条链路里，`VideoViewModel` 是唯一的业务编排中心。

### 8.3 设置持久化链路

数据流如下：

1. 用户在 `SettingsView` 修改 `baseURL`
2. 双向绑定直接更新 `SettingsViewModel.serverConfig`
3. `didSet` 触发 `save()`
4. `save()` 把配置写入 `UserDefaults`

这是项目里最轻量的一条 MVVM 链路，几乎没有额外控制流。

## 9. Utils 层在架构中的作用

### `PermissionManager`

- 把权限请求统一封装成异步接口。
- 避免 `ViewModel` 直接操作底层权限 API 细节。

### `Constants`

- 统一管理默认地址和持久化 key。
- 避免硬编码散落在各层。

### `Extensions`

- 提供日期格式化、字符串裁剪等通用能力。
- 这些能力不属于特定业务模块，因此放在工具层是合理的。

## 10. 当前 MVVM 设计的优点

- 分层职责清楚，阅读成本低。
- 每个主页面都有独立的 `ViewModel`，职责边界明确。
- `Service` 已经把网络、文件、相机、RTC 等底层能力从页面中隔离出来。
- 依赖注入方式简单直接，便于快速追踪调用路径。
- SwiftUI 视图整体较薄，基本没有把业务逻辑写回 View 层。

对于当前项目规模来说，这套 MVVM 结构是清晰且可维护的。

## 11. 当前架构的边界与改进点

### 1. `DialogueViewModel` 通过手动同步服务状态

`DialogueViewModel` 目前依赖 `syncRTCState()` 手动把 `RTCService` 的状态拷贝到自己的 `@Published` 属性中。

这在当前占位实现下没有问题，但如果未来 RTC SDK 会持续异步回调远端流状态、连接状态、房间事件，这种“手动同步”方式会变得脆弱。

### 2. 服务层状态还没有形成完整响应式链路

虽然 `RTCService` 和 `VideoService` 都带有状态，但当前项目并没有让 `ViewModel` 真正订阅这些状态变化，而是主要通过命令式调用后主动刷新。

这意味着：

- 当前结构更偏“命令式 MVVM”
- 而不是“响应式 MVVM”

### 3. 上传配置是初始化时注入的值快照

`NetworkService` 在初始化时接收 `ServerConfig`，之后不会自动感知设置页变化。

因此，设置页更新地址后，视频页如果不重建对应对象，上传服务仍可能使用旧地址。

### 4. 部分 Service 仍是占位版本

当前架构上已经预留了良好的抽象位置，但功能层面还未完全落地：

- `RTCService` 还未接入真实 RTC 能力
- `VideoService` 还没有完整落地真实文件录制输出流程
- `DialogueView` 中展示的仍是 WebRTC sample 页面，而不是正式远端会话视图

这说明当前项目的 MVVM“骨架”已经成型，但部分“业务器官”仍处于替换占位阶段。

## 12. 总结

这个项目的 MVVM 架构可以概括为：

- `View` 负责显示与交互入口
- `ViewModel` 负责状态和业务编排
- `Model` 负责轻量级数据表达
- `Service` 负责底层能力封装

其中，真正承载业务逻辑的是 `DialogueViewModel`、`VideoViewModel`、`SettingsViewModel` 三个对象；真正负责把系统能力隔离出去的是 `RTCService`、`VideoService`、`FileService`、`NetworkService`。

从工程角度看，这个项目已经具备清晰的 MVVM 分层和可扩展性。后续如果继续演进，最关键的方向不是重新拆层，而是让 `Service -> ViewModel` 的状态流转变得更实时、更响应式，尤其是在 RTC 和录制能力接入真实实现之后。
