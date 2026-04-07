import Foundation

@MainActor
final class DialogueViewModel: ObservableObject {
    @Published var dialogueState: DialogueState = .idle
    @Published var errorMessage = ""
    @Published private(set) var isSessionActive = false
    @Published private(set) var isMicrophoneEnabled = false
    @Published private(set) var remoteVideoActive = false
    @Published private(set) var remoteAudioActive = false
    @Published private(set) var currentRoomID = ""
    @Published private(set) var offerURLDisplayString = Constants.defaultRTCOfferURL
    @Published private(set) var isWebViewVisible = false
    @Published private(set) var webCommand = ""
    @Published private(set) var webCommandID = 0

    private let rtcService: RTCService
    private var serverConfig: ServerConfig = .default
    private var shouldStartWhenPageReady = false

    var offerURL: URL {
        URL(string: offerURLDisplayString) ?? URL(string: Constants.defaultRTCOfferURL)!
    }

    init(rtcService: RTCService) {
        self.rtcService = rtcService
        loadInitialState()
    }

    private func loadInitialState() {
        syncRTCState()
    }

    var statusDescription: String {
        switch dialogueState {
        case .idle:
            return "点击开始会话后，使用原生按钮控制内置 WebRTC 页面建立连接。"
        case .preparing:
            return "正在申请麦克风和相机权限，并准备加载会话页面。"
        case .connecting:
            return "正在建立 WebRTC 实时会话。"
        case .streaming:
            return "实时会话进行中，可用原生按钮结束会话或静音麦克风。"
        case .ending:
            return "正在关闭实时会话。"
        case .error:
            return errorMessage.isEmpty ? "实时会话发生错误。" : errorMessage
        }
    }

    func startSession() async {
        errorMessage = ""
        dialogueState = .preparing

        guard URL(string: serverConfig.rtcOfferURL) != nil else {
            dialogueState = .error
            errorMessage = "RTC Offer URL 无效，请前往设置页修正。"
            return
        }

        let microphoneGranted = await PermissionManager.requestMicrophonePermission()
        let cameraGranted = await PermissionManager.requestCameraPermission()
        guard microphoneGranted && cameraGranted else {
            dialogueState = .error
            errorMessage = "相机或麦克风权限未授权"
            return
        }

        rtcService.initialize()
        rtcService.joinRoom(roomId: "human-dialogue")
        syncRTCState()

        dialogueState = .connecting
        isWebViewVisible = true
        shouldStartWhenPageReady = true

        if rtcService.isPageReady {
            sendWebCommand("start")
            shouldStartWhenPageReady = false
        }
    }

    func endSession() {
        errorMessage = ""

        guard isWebViewVisible else {
            dialogueState = .idle
            return
        }

        dialogueState = .ending
        shouldStartWhenPageReady = false
        sendWebCommand("stop")
    }

    func toggleMicrophone() {
        guard isWebViewVisible else { return }
        sendWebCommand("toggleMute")
    }

    func updateServerConfig(_ config: ServerConfig) {
        serverConfig = config
        offerURLDisplayString = config.rtcOfferURL
    }

    func handleWebPageEvent(_ payload: [String: Any]) {
        rtcService.handlePageEvent(payload)

        if let event = payload["event"] as? String {
            switch event {
            case "ready":
                if shouldStartWhenPageReady {
                    sendWebCommand("start")
                    shouldStartWhenPageReady = false
                }
            case "started":
                dialogueState = .streaming
            case "stopped":
                isWebViewVisible = false
                if dialogueState != .error {
                    dialogueState = .idle
                }
            case "error":
                dialogueState = .error
                errorMessage = payload["message"] as? String ?? "WebRTC 页面发生错误"
            default:
                break
            }
        }

        syncRTCState()
    }

    private func sendWebCommand(_ command: String) {
        webCommand = command
        webCommandID += 1
    }

    private func syncRTCState() {
        isSessionActive = rtcService.isInRoom
        isMicrophoneEnabled = rtcService.microphoneEnabled
        remoteVideoActive = rtcService.remoteVideoActive
        remoteAudioActive = rtcService.remoteAudioActive
        currentRoomID = rtcService.currentRoomID
    }
}
