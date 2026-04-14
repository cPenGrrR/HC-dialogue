import AVFoundation
import Foundation

@MainActor
final class VideoViewModel: ObservableObject {
    @Published var videos: [RecordedVideo] = []
    @Published var isRecording = false
    @Published var isPreviewRunning = false
    @Published var uploadingVideoID: UUID?
    @Published var successMessage = ""
    @Published var errorMessage = ""
    @Published var modelName = ""
    @Published private(set) var uploadProgress: Double = 0
    @Published private(set) var uploadLogs: [String] = []

    private let videoService: VideoService
    private let fileService: FileService
    private let networkService: NetworkService
    private var currentUsername: String?

    init(
        networkService: NetworkService,
        videoService: VideoService = VideoService(),
        fileService: FileService = FileService()
    ) {
        self.networkService = networkService
        self.videoService = videoService
        self.fileService = fileService
        bindVideoService()
        loadVideos()
    }

    func updateCurrentUser(_ username: String?) {
        currentUsername = username
        loadVideos()
    }

    func loadVideos() {
        guard let currentUsername else {
            videos = []
            return
        }
        videos = fileService.listVideos(for: currentUsername)
    }

    func updateServerConfig(_ config: ServerConfig) {
        networkService.updateConfig(config)
    }

    var previewSession: AVCaptureSession {
        videoService.captureSession
    }

    var canUpload: Bool {
        uploadingVideoID == nil && !modelName.trimmed.isEmpty
    }

    func preparePreview() async {
        guard !isPreviewRunning else { return }

        let cameraGranted = await PermissionManager.requestCameraPermission()
        guard cameraGranted else {
            errorMessage = "请先授予相机权限"
            return
        }

        do {
            try await videoService.preparePreview()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopPreview() {
        videoService.stopPreview()
    }

    func startRecording() async {
        errorMessage = ""
        successMessage = ""

        guard let currentUsername else {
            errorMessage = "请先登录后再录制"
            return
        }

        let cameraGranted = await PermissionManager.requestCameraPermission()
        let microphoneGranted = await PermissionManager.requestMicrophonePermission()

        guard cameraGranted && microphoneGranted else {
            errorMessage = "请先授予相机和麦克风权限"
            return
        }

        let outputURL = fileService.createVideoFileURL(for: currentUsername)
        do {
            try await videoService.startRecording(to: outputURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stopRecording() async {
        errorMessage = ""

        do {
            _ = try await videoService.stopRecording()
            loadVideos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func uploadVideo(_ video: RecordedVideo) async {
        errorMessage = ""
        successMessage = ""

        let trimmedModelName = modelName.trimmed
        guard !trimmedModelName.isEmpty else {
            errorMessage = "请先输入 Avatar 名称"
            return
        }

        uploadingVideoID = video.id
        uploadProgress = 0
        uploadLogs = []
        appendUploadLog("开始处理视频: \(video.fileName)")

        do {
            let result = try await networkService.uploadAndTrainVideo(
                fileURL: video.fileURL,
                modelName: trimmedModelName
            ) { [weak self] progress, message in
                Task { @MainActor in
                    self?.uploadProgress = progress
                    self?.appendUploadLog(message)
                }
            }

            successMessage = "上传并训练已提交：\(result.modelName) v\(result.modelVersion)"
            appendUploadLog("任务完成，upload_id: \(result.uploadID)")
        } catch {
            errorMessage = "上传失败：\(error.localizedDescription)"
            appendUploadLog("错误：\(error.localizedDescription)")
        }

        uploadingVideoID = nil
    }

    func deleteVideo(_ video: RecordedVideo) {
        do {
            try fileService.deleteVideo(at: video.fileURL)
            loadVideos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func bindVideoService() {
        videoService.onStateChange = { [weak self] isRecording, isPreviewRunning in
            self?.isRecording = isRecording
            self?.isPreviewRunning = isPreviewRunning
        }

        videoService.onRecordingFinished = { [weak self] _ in
            self?.loadVideos()
        }
    }

    private func appendUploadLog(_ message: String) {
        let timestamp = DateFormatter.displayFormatter.string(from: Date())
        uploadLogs.append("[\(timestamp)] \(message)")
    }
}
