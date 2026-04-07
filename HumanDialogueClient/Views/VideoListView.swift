import SwiftUI

struct VideoListView: View {
    @StateObject var viewModel: VideoViewModel

    var body: some View {
        List {
            Section("录制") {
                previewPanel

                Button(viewModel.isRecording ? "停止录制" : "开始录制") {
                    Task {
                        if viewModel.isRecording {
                            await viewModel.stopRecording()
                        } else {
                            await viewModel.startRecording()
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isRecording ? .red : .accentColor)

                if !viewModel.errorMessage.isEmpty {
                    Text(viewModel.errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("本地视频") {
                if viewModel.videos.isEmpty {
                    ContentUnavailableView("暂无本地视频", systemImage: "film")
                } else {
                    ForEach(viewModel.videos) { video in
                        NavigationLink {
                            VideoPlayerView(video: video)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(video.fileName)
                                    .font(.headline)
                                Text("创建时间：\(video.createdAt.displayString)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if video.duration > 0 {
                                    Text("时长：\(video.duration.formattedDuration)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button("删除", role: .destructive) {
                                viewModel.deleteVideo(video)
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button(viewModel.uploadingVideoID == video.id ? "上传中" : "上传") {
                                Task {
                                    await viewModel.uploadVideo(video)
                                }
                            }
                            .tint(.blue)
                            .disabled(viewModel.uploadingVideoID != nil)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteVideo(viewModel.videos[index])
                        }
                    }
                }
            }

            if !viewModel.successMessage.isEmpty {
                Section {
                    Text(viewModel.successMessage)
                        .font(.footnote)
                        .foregroundStyle(.green)
                }
            }
        }
        .navigationTitle("视频")
        .task {
            await viewModel.preparePreview()
        }
        .onDisappear {
            viewModel.stopPreview()
        }
        .toolbar {
            Button("刷新") {
                viewModel.loadVideos()
            }
        }
    }

    private var previewPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.08))

            if viewModel.isPreviewRunning {
                CameraPreviewView(session: viewModel.previewSession)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Label("实时预览", systemImage: "camera.viewfinder")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.55), in: Capsule())
                            .foregroundStyle(.white)
                            .padding(12)
                    }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "video")
                        .font(.system(size: 34))
                    Text("开始录制后显示实时预览")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }
}

#Preview {
    NavigationStack {
        VideoListView(viewModel: VideoViewModel(networkService: NetworkService(config: .default)))
    }
}
