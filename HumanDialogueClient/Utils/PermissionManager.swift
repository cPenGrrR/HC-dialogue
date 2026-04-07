import AVFoundation

enum PermissionManager {
    static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static func requestCameraPermission() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }
}
