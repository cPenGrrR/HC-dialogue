# HumanDialogueClient

`HumanDialogueClient` 是一个基于 SwiftUI 的 iOS 原型项目，当前聚焦两条主线：

1. 实时会话：通过内嵌 `WKWebView` 加载本地 `index.html`，由页面发起 WebRTC offer/answer 流程，客户端侧负责权限申请、页面桥接和状态展示。
2. 本地视频：支持相机预览、视频录制、本地列表管理、播放、删除，以及上传到服务端。

项目现在已经不是纯骨架状态，视频录制和上传链路可用；实时会话部分已完成 Native 与 Web 页面之间的控制闭环，但仍依赖页面内的 WebRTC 实现，尚未接入原生 WebRTC SDK。

## 当前实现

### 1. 实时会话页

- 页面入口为“会话” Tab。
- 点击“开始会话”后会先申请相机和麦克风权限。
- App 通过 `WebRTCSampleWebView` 加载包内 [index.html](/Users/vercet1/Documents/Xcode/HC%20dialogue/HC%20dialogue/HumanDialogueClient/Resources/index.html)。
- Native 侧通过 JavaScript 注入 `RTC Offer URL`，并通过 `window.HCRTC.start/stop/toggleMute` 控制页面。
- 页面通过 `window.webkit.messageHandlers.hcRtc` 把 `ready`、`started`、`stopped`、`error`、`remoteTrack`、`microphone`、`status` 等事件回传给 Swift。
- 当前 UI 会展示会话状态、Offer 接口地址、麦克风状态、远端音频状态。

当前边界：

- 远端媒体渲染由页面内 WebRTC 完成，不是原生渲染。
- `RTCService` 目前负责状态同步和事件归一，不负责真正的信令或媒体实现。
- 房间 ID 目前在 `DialogueViewModel` 中写死为 `human-dialogue`，设置页不提供房间配置。
- [index.html](/Users/vercet1/Documents/Xcode/HC%20dialogue/HC%20dialogue/HumanDialogueClient/Resources/index.html) 当前使用 `iceServers: []`，偏向局域网/LAN 调试；如果服务端部署在更复杂网络环境，通常还需要补充 STUN/TURN。

### 2. 视频页

- 页面入口为“视频” Tab。
- 进入页面时会准备相机预览。
- 使用 `AVCaptureSession + AVCaptureMovieFileOutput` 进行真实视频录制，不再是旧文档中的占位输出。
- 支持开始录制、停止录制、播放本地视频、删除视频、手动刷新列表。
- 支持将本地视频以 `multipart/form-data` 上传到服务端。

本地文件策略：

- 视频保存在应用沙盒 `Documents/RecordedVideos/<username>/` 目录下。
- 文件名格式为 `video_时间戳.mov`。
- 本地视频列表会根据当前登录用户切换。

上传策略：

- 使用设置页中的 `上传接口 URL` 作为请求地址。
- 请求方法为 `POST`。
- 表单字段名固定为 `file`。
- MIME 类型由文件扩展名推断，当前录制文件默认为 `video/quicktime`。

### 3. 设置页

- 页面入口为“设置” Tab。
- 当前包含两部分：登录、服务器配置。

登录：

- 目前是本地占位登录，不接后端鉴权。
- 默认账号固定为 `admin / 123456`。
- 登录状态会持久化到 `UserDefaults`。

服务器配置：

- `上传接口 URL`
- `RTC Offer URL`

说明：

- 这两个地址分开维护。
- 上传页面使用 `上传接口 URL`。
- 实时会话页中的内嵌 WebRTC 页面使用 `RTC Offer URL`。

## 目录结构

```text
HC dialogue/
├── HumanDialogueClient/
│   ├── App/
│   │   ├── HumanDialogueClientApp.swift
│   │   └── ContentView.swift
│   ├── Models/
│   │   ├── DialogueState.swift
│   │   ├── RecordedVideo.swift
│   │   └── ServerConfig.swift
│   ├── Services/
│   │   ├── FileService.swift
│   │   ├── NetworkService.swift
│   │   ├── RTCService.swift
│   │   └── VideoService.swift
│   ├── ViewModels/
│   │   ├── DialogueViewModel.swift
│   │   ├── SettingsViewModel.swift
│   │   └── VideoViewModel.swift
│   ├── Views/
│   │   ├── CameraPreviewView.swift
│   │   ├── DialogueView.swift
│   │   ├── SettingsView.swift
│   │   ├── VideoListView.swift
│   │   ├── VideoPlayerView.swift
│   │   └── WebRTCSampleWebView.swift
│   ├── Utils/
│   │   ├── Constants.swift
│   │   ├── Extensions.swift
│   │   └── PermissionManager.swift
│   └── Resources/
│       ├── Assets.xcassets
│       ├── index.html
│       ├── Info.plist
│       └── Preview Content/
└── README.md
```

## 关键实现说明

### 架构

项目采用轻量的 `View + ViewModel + Service` 分层：

- `View`：负责界面展示和交互。
- `ViewModel`：负责页面状态、权限调用、业务流程组织。
- `Service`：负责相机录制、文件管理、网络上传和 RTC 状态同步。

### 关键类

- `DialogueViewModel`
  负责会话启动/结束、权限申请、Web 页面命令下发和事件处理。
- `RTCService`
  负责同步页面回传的 RTC 状态，例如页面是否 ready、是否在会话中、麦克风是否开启、是否有远端轨道等。
- `VideoViewModel`
  负责视频录制、列表加载、上传、删除和当前用户切换。
- `VideoService`
  负责 `AVCaptureSession` 配置、预览启动、视频录制和录制结束回调。
- `NetworkService`
  负责视频上传请求。
- `SettingsViewModel`
  负责登录状态和服务器配置持久化。

### 默认配置

默认值定义在 [Constants.swift](/Users/vercet1/Documents/Xcode/HC%20dialogue/HC%20dialogue/HumanDialogueClient/Utils/Constants.swift)：

- `defaultBaseURL`: `https://example.com/api`
- `defaultRTCOfferURL`: `https://example.com/offer`

## 运行方式

### 环境要求

- Xcode
- iOS 17+ 开发环境
- 建议使用真机验证相机、麦克风、录制和 WebRTC 能力

### 启动步骤

1. 用 Xcode 打开工程。
2. 选择 iPhone 真机或模拟器并运行。
3. 进入“设置”页，填写 `上传接口 URL` 和 `RTC Offer URL`。
4. 如需录制或查看本地视频，先使用 `admin / 123456` 登录。
5. 进入“会话”页验证实时会话，或进入“视频”页验证录制、播放和上传。

## 权限与存储

- 相机权限：用于视频录制和实时会话页面媒体采集。
- 麦克风权限：用于视频录制和实时会话音频采集。
- 服务器配置和当前登录用户通过 `UserDefaults` 保存。
- 录制视频保存在应用沙盒文档目录。

## 已完成与未完成

### 已完成

- 三个主页面和 Tab 结构
- 本地占位登录和用户持久化
- 按用户隔离的本地视频目录
- 相机预览
- 真实视频录制
- 本地视频播放、删除、上传
- Native 与 WebRTC 页面之间的桥接
- 会话状态、错误和麦克风状态展示

### 仍待完善

- 原生 WebRTC SDK 接入
- 更完整的 STUN/TURN 和复杂网络适配
- 上传鉴权、上传进度、失败重试
- 服务端协议文档化和错误码约定
- 更完善的单元测试与 UI 自动化测试

## 当前适用场景

- 数字人/远端媒体交互原型验证
- iOS 侧本地录制与上传流程联调
- WebRTC offer/answer 服务端接口联调

如果后续要继续演进，优先建议先明确两份契约：上传接口协议，以及 WebRTC offer/answer 与 ICE 部署方案。当前代码结构已经足够支撑这两条链路继续落地。
