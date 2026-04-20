# HumanDialogueClient

一个基于 SwiftUI 的 iOS 客户端，提供两条核心能力：

- 本地录制视频并分片上传到后端，触发 Avatar/模型训练。
- 在 App 内通过 `WKWebView` 加载内置 `index.html`，发起 WebRTC 实时会话。

## 当前功能状态

- 三个主页面（Tab）
- `会话`：原生按钮控制内置 WebRTC 页面（开始、结束、麦克风开关）
- `视频`：相机预览、视频录制、视频列表、删除、本地播放、上传并训练
- `设置`：登录状态与服务端配置管理

- 登录
- 当前为占位账号：`admin / 123456`
- 登录用户会绑定本地视频目录，切换用户会切换视频列表

- 本地录制
- 使用 `AVCaptureSession + AVCaptureMovieFileOutput`
- 默认前置摄像头（不可用时回退系统默认视频设备）
- 文件保存到 `Documents/RecordedVideos/<username>/video_yyyyMMdd_HHmmss.mov`

- 上传训练
- 5MB 分片上传：`POST /upload/chunk`
- 合并通知：`POST /upload/complete`
- 创建模型：`POST /models/?name=<modelName>&video_upload_id=<uploadID>`
- UI 显示进度条和时间戳日志

- WebRTC 会话
- `Resources/index.html` 暴露 `window.HCRTC.start/stop/toggleMute`
- iOS 侧通过 `WebRTCSampleWebView` 下发命令并接收事件
- Offer/Answer 由原生侧转发：Web 页面上报 `signalOffer`，Swift 侧请求 `RTC Offer URL`，再把 answer 回传页面

## 技术栈与架构

- UI：SwiftUI
- 媒体：AVFoundation / AVKit
- Web 容器：WebKit (`WKWebView`)
- 网络：`URLSession`（async/await）
- 状态管理：MVVM（`ViewModels` + `Services` + `Models`）

核心模块：

- `ViewModels`
- `DialogueViewModel`：会话状态机、权限请求、Web 命令派发
- `VideoViewModel`：录制/上传流程编排、进度日志
- `SettingsViewModel`：登录与服务配置持久化（UserDefaults）

- `Services`
- `RTCService`：WebRTC 页面事件状态聚合
- `VideoService`：相机会话与录制控制
- `NetworkService`：分片上传与训练请求
- `FileService`：本地视频目录管理

## 配置说明

在 `设置` 页可配置两类地址：

- `上传接口 URL`（`baseURL`）
- 用于分片上传与模型创建（`/upload/chunk`、`/upload/complete`、`/models/`）

- `RTC Offer URL`（`rtcOfferURL`）
- 用于 WebRTC 信令（接收本地 offer，返回远端 answer）

默认值定义在 `Utils/Constants.swift`：

- `https://example.com/api`
- `https://example.com/offer`

## 运行要求

- Xcode（建议最新稳定版）
- iOS（与工程 Deployment Target 保持一致）
- 真机调试（推荐，便于验证相机/麦克风/WebRTC）

`Info.plist` 已包含：

- `NSCameraUsageDescription`
- `NSMicrophoneUsageDescription`
- `NSAppTransportSecurity` 允许任意加载（含 Web 内容）

## 快速开始

1. 用 Xcode 打开工程并运行 `HumanDialogueClient`。
2. 进入 `设置` 页登录（当前占位账号：`admin / 123456`）。
3. 配置后端 `上传接口 URL` 与 `RTC Offer URL`。
4. 进入 `视频` 页录制并上传训练。
5. 进入 `会话` 页点击“开始会话”验证 WebRTC 链路。

## 目录概览

- `HumanDialogueClient/App`：入口与根视图
- `HumanDialogueClient/Models`：数据模型
- `HumanDialogueClient/Services`：录制/网络/RTC/文件服务
- `HumanDialogueClient/ViewModels`：业务状态与交互逻辑
- `HumanDialogueClient/Views`：SwiftUI 页面
- `HumanDialogueClient/Resources/index.html`：内置 WebRTC 页面
- `Tests`：单元测试与 UI 测试目标

## 已知说明

- 当前登录为本地占位逻辑，未接入真实鉴权服务。
- WebRTC 页面依赖后端正确返回 answer JSON（包含有效 SDP）。
- 上传接口路径为约定格式，如后端路由不同需同步调整 `NetworkService`。
- 根目录的 `index_2.html` 为历史调试页面，App 实际加载的是 `Resources/index.html`。
