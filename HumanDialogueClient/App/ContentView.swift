import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var settingsViewModel: SettingsViewModel
    @StateObject private var dialogueViewModel = DialogueViewModel(rtcService: RTCService())
    @StateObject private var videoViewModel = VideoViewModel(networkService: NetworkService(config: .default))

    var body: some View {
        TabView {
            NavigationStack {
                DialogueView(viewModel: dialogueViewModel)
            }
            .tabItem {
                Label("会话", systemImage: "waveform.badge.mic")
            }

            NavigationStack {
                VideoListView(viewModel: videoViewModel)
            }
            .tabItem {
                Label("视频", systemImage: "film")
            }

            NavigationStack {
                SettingsView(viewModel: settingsViewModel)
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
        }
        .task {
            videoViewModel.updateServerConfig(settingsViewModel.serverConfig)
            dialogueViewModel.updateServerConfig(settingsViewModel.serverConfig)
            videoViewModel.updateCurrentUser(settingsViewModel.currentUser?.username)
        }
        .onChange(of: settingsViewModel.serverConfig) { _, newValue in
            videoViewModel.updateServerConfig(newValue)
            dialogueViewModel.updateServerConfig(newValue)
        }
        .onChange(of: settingsViewModel.currentUser) { _, newValue in
            videoViewModel.updateCurrentUser(newValue?.username)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(SettingsViewModel())
}
