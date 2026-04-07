import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        Form {
            Section("登录") {
                if let currentUser = viewModel.currentUser {
                    HStack {
                        Text("当前用户")
                        Spacer()
                        Text(currentUser.username)
                            .foregroundStyle(.secondary)
                    }

                    Button("退出登录", role: .destructive) {
                        viewModel.logout()
                    }
                } else {
                    TextField("用户名", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("密码", text: $password)

                    Button("登录") {
                        viewModel.login(username: username, password: password)
                    }
                    .buttonStyle(.borderedProminent)

                    Text("占位账号：admin / 123456")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if !viewModel.loginErrorMessage.isEmpty {
                        Text(viewModel.loginErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
            }

            Section("服务器配置") {
                TextField("上传接口 URL", text: $viewModel.serverConfig.baseURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                TextField("RTC Offer URL", text: $viewModel.serverConfig.rtcOfferURL)
                    .keyboardType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            Section("说明") {
                Text("登录状态与本地录制视频绑定，切换用户会切换本地视频列表。上传接口与实时会话接口分开配置：上传页使用“上传接口 URL”，实时会话页中的内置 WebRTC 页面使用“RTC Offer URL”。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("设置")
    }
}

#Preview {
    NavigationStack {
        SettingsView(viewModel: SettingsViewModel())
    }
}
