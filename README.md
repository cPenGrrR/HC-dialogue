# HumanDialogueClient

`HumanDialogueClient` 是一个面向 iOS 的人机实时交互客户端原型，目标是提供两类能力：

1. 实时会话
   客户端通过 WebRTC 相关链路与服务端建立实时连接，采集用户麦克风音频，并播放服务端返回的数字人视频和语音。
2. 本地视频管理
   客户端支持录制用户本地视频、查看本地视频列表、播放视频，并将视频上传到服务端。

当前工程以 SwiftUI 为主，采用轻量 View + ViewModel + Service 分层，便于后续替换占位实现并接入真实服务端协议、WebRTC SDK 和视频录制能力。

## 当前功能

### 1. 实时会话页

- 不提供传统文字聊天窗口。
- 页面聚焦实时音视频会话状态。
- 支持开始会话、结束会话、麦克风开关。
- UI 已明确区分：
  - 本地端只上传语音。
  - 服务端返回数字人人脸视频和语音。
- 当前 `RTCService` 为占位骨架，已具备状态管理结构，但尚未接入真实 WebRTC SDK。

### 2. 视频页

- 录制与视频列表已合并为一个页面。
- 支持开始录制、停止录制。
- 录制时显示实时相机预览。
- 支持查看本地视频列表。
- 支持播放本地视频。
- 支持删除本地视频。
- 支持将本地视频上传到设置页配置的服务器地址。

说明：

- 当前实时预览已基于 `AVCaptureSession` 实现。
- 当前“录制视频文件”仍是占位流程，尚未接入真实的视频编码输出，因此现在生成的是用于流程联调的占位文件。

### 3. 设置页

- 配置 HTTP / 上传地址。
- 配置 WebSocket 地址。
- 配置 RTC 房间 ID。
- 所有服务器相关配置统一从设置页维护，首页不再展示服务器地址。

## 项目结构

```text
HumanDialogueClient/
├── App/
│   ├── HumanDialogueClientApp.swift
│   └── ContentView.swift
├── Models/
│   ├── ChatMessage.swift
│   ├── DialogueState.swift
│   ├── RecordedVideo.swift
│   └── ServerConfig.swift
├── Services/
│   ├── AudioService.swift
│   ├── FileService.swift
│   ├── NetworkService.swift
│   ├── RTCService.swift
│   └── VideoService.swift
├── ViewModels/
│   ├── DialogueViewModel.swift
│   ├── SettingsViewModel.swift
│   └── VideoViewModel.swift
├── Views/
│   ├── CameraPreviewView.swift
│   ├── DialogueView.swift
│   ├── SettingsView.swift
│   ├── VideoListView.swift
│   ├── VideoPlayerView.swift
│   └── VideoRecordView.swift
├── Utils/
│   ├── Constants.swift
│   ├── Extensions.swift
│   └── PermissionManager.swift
├── Resources/
│   ├── Assets.xcassets
│   ├── Info.plist
│   └── Preview Content/
└── Tests/
    ├── HumanDialogueClientTests.swift
    └── HumanDialogueClientUITests.swift
```

## 技术栈

- Swift
- SwiftUI
- AVFoundation
- AVKit
- URLSession

## 架构说明

### View

负责页面结构和用户交互展示，例如：

- `DialogueView`
- `VideoListView`
- `VideoPlayerView`
- `SettingsView`
- `CameraPreviewView`

### ViewModel

负责状态组织、业务调度和页面数据绑定，例如：

- `DialogueViewModel`
  负责实时会话页面的状态、会话启动与结束、麦克风控制。
- `VideoViewModel`
  负责视频录制、视频列表加载、视频上传、错误提示等。
- `SettingsViewModel`
  负责服务器配置的读写与持久化。

### Service

负责底层能力和与系统 / 服务端的交互封装，例如：

- `RTCService`
  负责 WebRTC 会话相关状态骨架。
- `NetworkService`
  负责 WebSocket、上传请求等网络能力。
- `VideoService`
  负责相机预览和录制流程包装。
- `AudioService`
  负责音频录制和播放骨架。
- `FileService`
  负责本地文件路径、视频列表、删除文件等能力。

## 页面说明

### 1. 会话页

定位：

- 用于实时音视频人机交互。

设计原则：

- 不使用传统文本对话窗口。
- 会话控制尽量简单。
- 强调“服务端数字人返回流”的产品形态。

当前页面包含：

- 远端数字人视频展示区域
- 当前连接状态
- 远端音频状态
- 本地麦克风状态
- 开始 / 结束会话按钮
- 麦克风静音按钮

### 2. 视频页

定位：

- 处理用户本地视频录制和管理。

当前页面包含：

- 录制说明
- 实时相机预览区
- 开始 / 停止录制按钮
- 本地视频列表
- 上传操作
- 删除操作
- 上传与错误提示

### 3. 设置页

定位：

- 集中管理服务端相关配置。

配置项：

- `HTTP / 上传 Base URL`
- `WebSocket URL`
- `RTC Room ID`

## 关键数据模型

### `ServerConfig`

用于保存服务端配置：

- `baseURL`
- `webSocketURL`
- `rtcRoomId`

### `DialogueState`

用于标识实时会话状态，例如：

- 待连接
- 准备中
- 连接中
- 实时会话中
- 断开中
- 错误

### `RecordedVideo`

用于表示本地录制的视频文件：

- 文件名
- 文件 URL
- 创建时间
- 时长

## 本地存储

服务器配置通过 `UserDefaults` 保存。

本地视频默认存储在应用沙盒 `Documents/RecordedVideos` 目录下。

## 权限

项目当前依赖以下系统权限：

- 相机权限
- 麦克风权限

对应配置位于 `Info.plist`：

- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`

## 上传机制

当前视频上传逻辑为：

- 使用设置页中的 `baseURL` 作为上传目标地址。
- 使用 `multipart/form-data` 发起 `POST` 请求。
- 上传字段名固定为 `file`。
- 文件 MIME 类型为 `video/mp4`。

如果服务端协议不同，需要根据接口文档调整以下内容：

- 上传 URL
- 请求方法
- 表单字段名
- 认证信息
- 附加参数
- 响应解析逻辑

## 当前实现边界

当前工程已经具备可演进的交互骨架，但仍有一些部分属于占位实现：

### 已具备

- SwiftUI 页面结构
- 基础状态管理
- 服务端配置持久化
- 本地视频列表管理
- 视频上传流程
- 相机实时预览

### 尚未完成

- 真实 WebRTC SDK 接入
- 真实远端视频渲染
- 真实远端音频播放链路
- 真实本地视频录制编码输出
- 服务端信令协议适配
- 更完整的错误处理与重试机制
- 上传鉴权
- 单元测试和 UI 测试完善

## 运行方式

### 环境要求

- Xcode
- iOS 模拟器或真机

说明：

- 相机预览和麦克风相关能力更适合在真机测试。
- 视频录制和多媒体权限验证建议优先使用真机。

### 运行步骤

1. 用 Xcode 打开工程。
2. 选择 iOS 目标设备。
3. 运行 App。
4. 打开“设置”页，填写服务端配置。
5. 返回“会话”页或“视频”页进行测试。

## 后续建议

### 优先级高

1. 将 `RTCService` 替换为真实 WebRTC SDK 接入。
2. 将 `VideoService` 从占位录制改为真实视频文件录制。
3. 根据服务端协议细化上传接口和返回处理。

### 优先级中

1. 为上传增加进度显示。
2. 为录制增加时长、状态和失败提示。
3. 优化会话页远端视频渲染组件。

### 优先级低

1. 补充单元测试。
2. 补充 UI 自动化测试。
3. 优化页面视觉表现与空状态文案。

## 适用场景

该项目适合作为以下用途的原型基础：

- 数字人对话客户端
- 远端语音 / 视频交互演示
- 本地视频采集与上传客户端
- WebRTC 人机交互产品验证

## 备注

如果后续继续演进，建议优先统一以下契约：

- WebRTC 信令协议
- 视频上传接口协议
- 服务端返回媒体流格式
- 本地录制视频格式
- 错误码与重试策略

在这些契约明确后，现有工程结构可以较平滑地替换占位能力并扩展为可用版本。
