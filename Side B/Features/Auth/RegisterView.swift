import SwiftUI

struct RegisterView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var username = ""
    @State private var password = ""
    @State private var displayName = ""

    private let defaultAvatarName = "avatar_1"

    var body: some View {
        Form {
            Section {
                TextField("用户名", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("密码", text: $password)
                    .textContentType(.newPassword)

                TextField("显示名称", text: $displayName)
                    .textContentType(.name)
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("选择头像")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    // Placeholder for Task 16: avatar selection grid
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)

                        Text("头像选择即将上线")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                }
            }

            Section {
                Button {
                    Task {
                        await viewModel.register(
                            username: username,
                            password: password,
                            displayName: displayName,
                            avatarName: defaultAvatarName
                        )
                    }
                } label: {
                    HStack {
                        Text("注册")
                            .fontWeight(.semibold)
                        if viewModel.isLoading {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.isLoading || username.isEmpty || password.isEmpty || displayName.isEmpty)
            }

            Section {
                NavigationLink {
                    LoginView(viewModel: viewModel)
                } label: {
                    HStack(spacing: 4) {
                        Text("已有账号？")
                            .foregroundStyle(.secondary)
                        Text("登录")
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .navigationTitle("注册")
        .alert(
            "注册失败",
            isPresented: .init(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            ),
            actions: {
                Button("好的", role: .cancel) {}
            },
            message: {
                Text(viewModel.errorMessage ?? "")
            }
        )
    }
}