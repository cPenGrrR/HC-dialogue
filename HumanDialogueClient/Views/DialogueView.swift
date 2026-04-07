import SwiftUI

struct DialogueView: View {
    @StateObject var viewModel: DialogueViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                remoteVideoPanel
                controlPanel
                sessionStatusCard
            }
            .padding()
        }
        .navigationTitle("实时会话")
    }

    private var remoteVideoPanel: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.88), Color.blue.opacity(0.42)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            if viewModel.isWebViewVisible {
                WebRTCSampleWebView(
                    offerURL: viewModel.offerURL,
                    command: viewModel.webCommand,
                    commandID: viewModel.webCommandID,
                    errorMessage: $viewModel.errorMessage,
                    onEvent: { payload in
                        viewModel.handleWebPageEvent(payload)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "globe")
                        .font(.system(size: 54))
                        .foregroundStyle(.white)
                    Text("开始会话后使用 WebKit 加载后端提供的 WebRTC 页面")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
        }
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 6) {
                Label("WebRTC 实时会话", systemImage: "safari")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(viewModel.isWebViewVisible ? "已加载会话页面" : "等待加载会话页面")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
    }

    private var sessionStatusCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("当前状态：\(viewModel.dialogueState.rawValue)", systemImage: "waveform")
                .font(.headline)

            Text(viewModel.statusDescription)
                .foregroundStyle(.secondary)

            LabeledContent("Offer 接口", value: viewModel.offerURLDisplayString)
            LabeledContent("远端音频", value: viewModel.remoteAudioActive ? "占位开启" : "未接入")
            LabeledContent("本地麦克风", value: viewModel.isMicrophoneEnabled ? "开启" : "关闭")

            if !viewModel.errorMessage.isEmpty, viewModel.dialogueState == .error {
                Text(viewModel.errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.gray.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var controlPanel: some View {
        HStack(spacing: 12) {
            Button(viewModel.isWebViewVisible ? "结束会话" : "开始会话") {
                Task {
                    if viewModel.isWebViewVisible {
                        viewModel.endSession()
                    } else {
                        await viewModel.startSession()
                    }
                }
            }
            .buttonStyle(.borderedProminent)

            Button(viewModel.isMicrophoneEnabled ? "麦克风静音" : "打开麦克风") {
                viewModel.toggleMicrophone()
            }
            .buttonStyle(.bordered)
            .disabled(!viewModel.isWebViewVisible)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    NavigationStack {
        DialogueView(
            viewModel: DialogueViewModel(
                rtcService: RTCService()
            )
        )
    }
}
