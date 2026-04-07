import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    struct UserAccount: Equatable {
        let username: String
    }

    @Published var serverConfig: ServerConfig {
        didSet {
            saveServerConfig()
        }
    }

    @Published private(set) var currentUser: UserAccount?
    @Published var loginErrorMessage = ""

    private let allowedUsername = "admin"
    private let allowedPassword = "123456"

    init() {
        if
            let data = UserDefaults.standard.data(forKey: Constants.serverConfigStorageKey),
            let config = try? JSONDecoder().decode(ServerConfig.self, from: data)
        {
            serverConfig = config
        } else {
            serverConfig = .default
        }

        if let storedUsername = UserDefaults.standard.string(forKey: Constants.loggedInUserStorageKey) {
            currentUser = UserAccount(username: storedUsername)
        } else {
            currentUser = nil
        }
    }

    func login(username: String, password: String) {
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        loginErrorMessage = ""

        guard !trimmedUsername.isEmpty, !trimmedPassword.isEmpty else {
            loginErrorMessage = "请输入用户名和密码"
            return
        }

        guard isValidUsername(trimmedUsername) else {
            loginErrorMessage = "用户名仅支持英文、数字和 ._-"
            return
        }

        guard trimmedUsername == allowedUsername, trimmedPassword == allowedPassword else {
            loginErrorMessage = "用户名或密码错误"
            return
        }

        currentUser = UserAccount(username: trimmedUsername)
        UserDefaults.standard.set(trimmedUsername, forKey: Constants.loggedInUserStorageKey)
    }

    func logout() {
        currentUser = nil
        UserDefaults.standard.removeObject(forKey: Constants.loggedInUserStorageKey)
    }

    private func isValidUsername(_ username: String) -> Bool {
        let pattern = "^[A-Za-z0-9._-]+$"
        return username.range(of: pattern, options: .regularExpression) != nil
    }

    private func saveServerConfig() {
        guard let data = try? JSONEncoder().encode(serverConfig) else { return }
        UserDefaults.standard.set(data, forKey: Constants.serverConfigStorageKey)
    }
}
