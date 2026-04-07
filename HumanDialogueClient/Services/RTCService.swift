import Foundation

@MainActor
final class RTCService: ObservableObject {
    @Published private(set) var isInitialized = false
    @Published private(set) var isPageReady = false
    @Published private(set) var isInRoom = false
    @Published private(set) var microphoneEnabled = false
    @Published private(set) var remoteAudioActive = false
    @Published private(set) var remoteVideoActive = false
    @Published private(set) var currentRoomID = ""
    @Published private(set) var connectionStatus = "idle"
    @Published private(set) var lastErrorMessage = ""

    func initialize() {
        isInitialized = true
        if connectionStatus == "idle" {
            connectionStatus = "initialized"
        }
    }

    func joinRoom(roomId: String) {
        guard isInitialized, !roomId.isEmpty else { return }
        currentRoomID = roomId
        lastErrorMessage = ""
        connectionStatus = isPageReady ? "ready-to-start" : "waiting-page"
    }

    func leaveRoom() {
        isInRoom = false
        remoteAudioActive = false
        remoteVideoActive = false
        microphoneEnabled = false
        connectionStatus = "stopped"
    }

    func enableMicrophone(_ enabled: Bool) {
        microphoneEnabled = enabled
    }

    func handlePageEvent(_ payload: [String: Any]) {
        guard let event = payload["event"] as? String else { return }

        switch event {
        case "ready":
            isPageReady = true
            if isInitialized {
                connectionStatus = "ready"
            }
        case "configUpdated":
            if let roomID = payload["roomId"] as? String, !roomID.isEmpty {
                currentRoomID = roomID
            }
        case "status":
            if let status = payload["status"] as? String {
                applyConnectionStatus(status)
            }
        case "started":
            isInRoom = true
            connectionStatus = "connecting"
        case "stopped":
            isInRoom = false
            remoteAudioActive = false
            remoteVideoActive = false
            microphoneEnabled = false
            connectionStatus = "stopped"
        case "signalingOpen":
            connectionStatus = "signaling-open"
        case "signalingClosed":
            isInRoom = false
            connectionStatus = "closed"
        case "signalingError":
            lastErrorMessage = "Signaling connection failed"
            connectionStatus = "error"
        case "remoteTrack":
            if let kind = payload["kind"] as? String {
                switch kind {
                case "video":
                    remoteVideoActive = true
                    isInRoom = true
                case "audio":
                    remoteAudioActive = true
                    isInRoom = true
                default:
                    break
                }
            }
        case "microphone":
            if let enabled = payload["enabled"] as? Bool {
                microphoneEnabled = enabled
            }
        case "error":
            lastErrorMessage = payload["message"] as? String ?? "Unknown RTC page error"
            isInRoom = false
            connectionStatus = "error"
        default:
            break
        }
    }

    func resetError() {
        lastErrorMessage = ""
    }

    private func applyConnectionStatus(_ status: String) {
        connectionStatus = status

        switch status {
        case "streaming", "connected":
            isInRoom = true
        case "closed", "disconnected", "failed", "error", "stopped":
            isInRoom = false
        default:
            break
        }
    }
}
