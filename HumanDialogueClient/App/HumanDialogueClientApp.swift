import SwiftUI

@main
struct HumanDialogueClientApp: App {
    @StateObject private var settingsViewModel = SettingsViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsViewModel)
        }
    }
}
