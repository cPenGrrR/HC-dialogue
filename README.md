# HumanDialogueClient

`HumanDialogueClient` 是一个 iOS SwiftUI 客户端，用于完成两类和服务端联动的能力：

- 本地录制用户视频，并调用服务端上传与训练接口创建 Avatar 模型
- 通过内置 `WKWebView` 加载本地打包的 WebRTC 页面，与服务端完成实时音视频会话

当前项目已经可以正常运行，并已完成与服务端的联调。

## 功能概览

- `会话` 页
  - 申请相机、麦克风权限
  - 加载内置 `index.html`
  - 通过原生与 Web 页面桥接，发起 WebRTC 会话
  - 支持开始会话、结束会话、切换麦克风静音
- `视频` 页
  - 打开前置摄像头实时预览
  - 录制本地视频文件
  - 按登录用户隔离本地视频目录
  - 将视频按分片上传到服务端
  - 调用模型创建接口触发训练
- `设置` 页
  - 本地登录/退出登录
  - 配置上传服务地址和 RTC Offer 地址
  - 配置持久化到 `UserDefaults`

## 技术栈

- SwiftUI
- AVFoundation
- WebKit
- 原生与 H5 JavaScript Bridge
- WebRTC 页面内信令请求

## 项目结构

```text
HC dialogue/
├── HumanDialogueClient/
│   ├── App/
│   ├── Models/
│   ├── Services/
│   ├── ViewModels/
│   ├── Views/
│   └── Resources/
└── Tests/
```

核心文件说明：

- `HumanDialogueClient/Views/WebRTCSampleWebView.swift`
  - 原生 `WKWebView` 封装，负责注入 Offer URL、收发 JS 消息、代发信令请求
- `HumanDialogueClient/Resources/index.html`
  - 内置 WebRTC 页面，负责创建 `RTCPeerConnection`、采集麦克风、创建 Offer、接收 Answer
- `HumanDialogueClient/Services/NetworkService.swift`
  - 视频分片上传、合并、模型创建
- `HumanDialogueClient/Services/VideoService.swift`
  - 相机预览与本地录制
- `HumanDialogueClient/ViewModels/DialogueViewModel.swift`
  - 实时会话状态管理
- `HumanDialogueClient/ViewModels/VideoViewModel.swift`
  - 视频录制、列表、上传训练状态管理

## 运行环境

- Xcode 15+
- iOS 16+
- 可访问目标后端服务的网络环境
- 真机优先

说明：

- WebRTC、相机和麦克风能力建议在 iPhone 真机上验证
- `Info.plist` 已配置相机、麦克风权限说明
- `NSAppTransportSecurity` 当前允许任意加载，便于联调 HTTP/HTTPS 服务

## 启动方式

1. 使用 Xcode 打开工程。
2. 选择 `HumanDialogueClient` 目标和 iPhone 设备。
3. 编译并运行 App。
4. 首次启动时允许相机和麦克风权限。

## 使用说明

### 1. 登录

当前登录为本地占位逻辑，默认账号：

- 用户名：`admin`
- 密码：`123456`

登录后的用户名会用于隔离本地录制视频目录。

### 2. 配置服务端地址

在 `设置` 页中配置两个地址：

- `上传接口 URL`
  - 用于视频上传、分片合并、模型创建
- `RTC Offer URL`
  - 用于 WebRTC SDP Offer/Answer 交换

默认值定义在 `HumanDialogueClient/Utils/Constants.swift`：

- `https://example.com/api`
- `https://example.com/offer`

联调时请替换成实际服务端地址。

### 3. 录制并上传训练视频

进入 `视频` 页后：

1. 先登录
2. 输入 `Avatar 名称 (modelName)`
3. 点击 `开始录制`
4. 录制完成后点击 `停止录制`
5. 在视频列表左滑或使用上传操作，执行 `上传并训练`

上传成功后页面会显示：

- 分片上传进度
- 上传日志
- 服务端返回的 `modelName` 和 `modelVersion`
- 本次训练对应的 `upload_id`

### 4. 发起实时会话

进入 `会话` 页后：

1. 点击 `开始会话`
2. App 申请权限并加载内置 WebRTC 页面
3. 页面创建本地 Offer
4. 原生层将 Offer 提交到 `RTC Offer URL`
5. 服务端返回 Answer 后建立连接
6. 连接成功后可通过按钮控制结束会话或切换麦克风

## 服务端接口约定

### 上传训练相关

基于 `上传接口 URL`，客户端依次调用：

1. `POST /upload/chunk`
   - 表单字段：
     - `chunk_index`
     - `total_chunks`
     - `upload_id`
     - `file`
2. `POST /upload/complete`
   - 表单字段：
     - `upload_id`
     - `filename`
3. `POST /models/?name={modelName}&video_upload_id={uploadID}`
   - 期望返回 JSON，至少包含：
     - `name`
     - `version`

### RTC 信令相关

客户端向 `RTC Offer URL` 发起：

- `POST`
- `Content-Type: application/json`
- 请求体为本地 `RTCSessionDescription`，包含：
  - `type`
  - `sdp`

服务端需要返回可被 `setRemoteDescription` 接受的 Answer JSON，通常包含：

- `type`
- `sdp`

## 本地数据存储

- 服务配置：`UserDefaults`
- 当前登录用户：`UserDefaults`
- 录制视频：App Documents 目录下的 `RecordedVideos/<username>/`

## 当前实现说明

- 登录逻辑目前是本地占位实现，不依赖服务端认证
- 实时会话页面使用打包在 App 内的 `Resources/index.html`
- WebRTC 页面默认使用 `stun:stun.l.google.com:19302`
- 远端视频通过 Web 页面中的 `<video>` 标签播放
- 原生侧负责配置注入、状态同步和信令转发

## 联调状态

当前版本已完成以下验证：

- App 可正常编译运行
- 本地视频录制流程可用
- 视频上传、分片合并、模型创建流程已接通服务端
- WebRTC Offer/Answer 流程已接通服务端
- 原生与内置 Web 页面桥接可用

## 常见问题排查

### 无法录制

- 检查是否已授予相机和麦克风权限
- 建议使用真机运行

### 上传失败

- 检查 `上传接口 URL` 是否正确
- 检查服务端是否支持分片上传接口
- 检查返回状态码是否为 `2xx`

### RTC 会话失败

- 检查 `RTC Offer URL` 是否正确
- 检查服务端是否返回合法 Answer JSON
- 检查当前网络是否可访问信令服务
- 检查目标环境下 ICE candidate 是否可达

## 后续建议

- 将本地占位登录替换为真实认证
- 为上传与 RTC 错误增加更细粒度提示
- 补充单元测试和 UI 自动化测试
- 区分开发、测试、生产环境配置
