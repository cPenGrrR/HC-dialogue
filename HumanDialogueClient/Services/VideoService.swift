@preconcurrency import AVFoundation
import Foundation

final class VideoService: NSObject, @unchecked Sendable {
    let captureSession = AVCaptureSession()

    var onStateChange: (@MainActor (_ isRecording: Bool, _ isPreviewRunning: Bool) -> Void)?
//    var onError: (@MainActor (_ message: String) -> Void)?
    var onRecordingFinished: (@MainActor (_ url: URL) -> Void)?

    private let movieOutput = AVCaptureMovieFileOutput()
    private let sessionQueue = DispatchQueue(label: "human.dialogue.video.capture")

    private var isSessionConfigured = false
    private var isSessionRunning = false
    private var stopRequested = false
    private var stopRecordingContinuation: CheckedContinuation<URL, Error>?

    override init() {
        super.init()
    }

    func preparePreview() async throws {
        try await runOnSessionQueue {
            try self.configureSessionIfNeeded()
            self.startSessionIfNeeded()
        }

        await MainActor.run {
            onStateChange?(movieOutput.isRecording, true)
        }
    }

    func startRecording(to url: URL) async throws {
        try removeExistingFileIfNeeded(at: url)

        try await runOnSessionQueue {
            try self.configureSessionIfNeeded()
            self.startSessionIfNeeded()

            guard !self.movieOutput.isRecording else {
                throw VideoServiceError.recordingInProgress
            }

            self.stopRequested = false
            self.movieOutput.startRecording(to: url, recordingDelegate: self)
        }

        await MainActor.run {
            onStateChange?(true, true)
        }
    }

    func stopRecording() async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                guard self.movieOutput.isRecording else {
                    continuation.resume(throwing: VideoServiceError.notRecording)
                    return
                }

                self.stopRequested = true
                self.stopRecordingContinuation = continuation
                self.movieOutput.stopRecording()
            }
        }
    }

    func stopPreview() {
        sessionQueue.async {
            guard self.isSessionRunning, !self.movieOutput.isRecording else { return }
            self.captureSession.stopRunning()
            self.isSessionRunning = false

            Task { @MainActor in
                self.onStateChange?(false, false)
            }
        }
    }

    private func configureSessionIfNeeded() throws {
        guard !isSessionConfigured else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        captureSession.automaticallyConfiguresApplicationAudioSession = true

        defer {
            captureSession.commitConfiguration()
        }

        let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            ?? AVCaptureDevice.default(for: .video)
        guard let videoDevice else {
            throw VideoServiceError.cameraUnavailable
        }

        let videoInput = try AVCaptureDeviceInput(device: videoDevice)
        guard captureSession.canAddInput(videoInput) else {
            throw VideoServiceError.cannotAddCameraInput
        }
        captureSession.addInput(videoInput)

        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw VideoServiceError.microphoneUnavailable
        }

        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
        guard captureSession.canAddInput(audioInput) else {
            throw VideoServiceError.cannotAddMicrophoneInput
        }
        captureSession.addInput(audioInput)

        guard captureSession.canAddOutput(movieOutput) else {
            throw VideoServiceError.cannotAddMovieOutput
        }
        captureSession.addOutput(movieOutput)

        if let connection = movieOutput.connection(with: .video), connection.isVideoMirroringSupported {
            connection.isVideoMirrored = true
        }

        isSessionConfigured = true
    }

    private func startSessionIfNeeded() {
        guard !isSessionRunning else { return }
        captureSession.startRunning()
        isSessionRunning = true
    }

    private func runOnSessionQueue(_ work: @escaping () throws -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            sessionQueue.async {
                do {
                    try work()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func removeExistingFileIfNeeded(at url: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    private func runSessionCleanup() async {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                if !self.movieOutput.isRecording, self.isSessionRunning {
                    self.captureSession.stopRunning()
                    self.isSessionRunning = false
                }
                continuation.resume()
            }
        }
    }
}

extension VideoService: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        Task { @MainActor in
            onStateChange?(true, true)
        }
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        let stopContinuation = stopRecordingContinuation
        stopRecordingContinuation = nil

        let finishError: Error?
        if let nsError = error as NSError?,
           nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool == false {
            finishError = nsError
            try? FileManager.default.removeItem(at: outputFileURL)
        } else if !stopRequested {
            finishError = VideoServiceError.recordingEndedUnexpectedly
            try? FileManager.default.removeItem(at: outputFileURL)
        } else {
            finishError = nil
        }

        stopRequested = false

        Task {
            if finishError == nil {
                await MainActor.run {
                    onStateChange?(false, true)
                    onRecordingFinished?(outputFileURL)
                }
                stopContinuation?.resume(returning: outputFileURL)
            }
        }
    }
}

enum VideoServiceError: LocalizedError {
    case cameraUnavailable
    case microphoneUnavailable
    case cannotAddCameraInput
    case cannotAddMicrophoneInput
    case cannotAddMovieOutput
    case recordingInProgress
    case notRecording
    case recordingEndedUnexpectedly

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "当前设备没有可用相机"
        case .microphoneUnavailable:
            return "当前设备没有可用麦克风"
        case .cannotAddCameraInput:
            return "无法创建相机输入"
        case .cannotAddMicrophoneInput:
            return "无法创建麦克风输入"
        case .cannotAddMovieOutput:
            return "无法创建视频录制输出"
        case .recordingInProgress:
            return "当前已有录制任务正在进行"
        case .notRecording:
            return "当前没有进行中的录制任务"
        case .recordingEndedUnexpectedly:
            return "录制在未手动停止的情况下提前结束。"
        }
    }
}
