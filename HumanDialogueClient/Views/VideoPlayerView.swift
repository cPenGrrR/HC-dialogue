import AVKit
import SwiftUI

struct VideoPlayerView: View {
    let video: RecordedVideo

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VideoPlayer(player: AVPlayer(url: video.fileURL))
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))

            Text(video.fileName)
                .font(.headline)

            Text("文件路径：\(video.fileURL.lastPathComponent)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding()
        .navigationTitle("视频播放")
    }
}
