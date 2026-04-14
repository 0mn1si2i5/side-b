import SwiftUI

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        Form {
            Section {
                TextField("用户名", text: $username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                SecureField("密码", text: $password)
                    .textContentType(.password)
            }

            Section {
                Button {
                    Task {
                        await viewModel.login(username: username, password: password)
                    }
                } label: {
                    HStack {
                        Text("登录")
                            .fontWeight(.semibold)
                        if viewModel.isLoading {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(viewModel.isLoading || username.isEmpty || password.isEmpty)
            }

            Section {
                NavigationLink {
                    RegisterView(viewModel: viewModel)
                } label: {
                    HStack(spacing: 4) {
                        Text("还没有账号？")
                            .foregroundStyle(.secondary)
                        Text("注册")
                            .fontWeight(.medium)
                    }
                }
            }
        }
        .navigationTitle("登录")
        .alert(
            "登录失败",
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