import SwiftUI
import UIKit

struct LoginView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var username = ""
    @State private var password = ""

    var body: some View {
        ZStack {
            authBackground

            VStack(alignment: .leading, spacing: 28) {
                header

                VStack(spacing: 14) {
                    authTextField("用户名", text: $username, contentType: .username)

                    SecureField("密码", text: $password)
                        .textContentType(.password)
                        .sideBAuthFieldStyle()

                    primaryButton(title: "登录", isLoading: viewModel.isLoading) {
                        Task {
                            await viewModel.login(username: username, password: password)
                        }
                    }
                    .disabled(viewModel.isLoading || username.isEmpty || password.isEmpty)
                    .opacity(viewModel.isLoading || username.isEmpty || password.isEmpty ? 0.45 : 1)
                    .padding(.top, 4)

                    NavigationLink {
                        RegisterView(viewModel: viewModel)
                    } label: {
                        HStack(spacing: 4) {
                            Text("还没有账号？")
                                .foregroundStyle(.secondary)
                            Text("注册")
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .sideBGlassSurface(cornerRadius: 30)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 74)
            .padding(.bottom, 28)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Side B")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.primary)

            Text("登录后继续同步歌曲和房间。")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var authBackground: some View {
        Color(.systemGroupedBackground)
        .ignoresSafeArea()
    }

    private func authTextField(_ title: String, text: Binding<String>, contentType: UITextContentType) -> some View {
        TextField(title, text: text)
            .textContentType(contentType)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .sideBAuthFieldStyle()
    }

    private func primaryButton(title: String, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Spacer()
                Text(title)
                    .fontWeight(.semibold)
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
                Spacer()
            }
            .foregroundStyle(.primary)
            .frame(height: 52)
            .background(.regularMaterial)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
