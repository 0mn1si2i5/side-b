import SwiftUI
import UIKit

struct RegisterView: View {
    @Bindable var viewModel: AuthViewModel
    @State private var username = ""
    @State private var password = ""
    @State private var displayName = ""
    @State private var selectedAvatar: String = "avatar_1"

    var body: some View {
        ZStack {
            authBackground

            VStack(alignment: .leading, spacing: 20) {
                header

                VStack(alignment: .leading, spacing: 13) {
                    authTextField("用户名", text: $username, contentType: .username)

                    SecureField("密码", text: $password)
                        .textContentType(.newPassword)
                        .sideBAuthFieldStyle()

                    authTextField("显示名称", text: $displayName, contentType: .name)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择头像")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        AvatarSelectionView(selectedAvatar: $selectedAvatar)
                    }
                    .padding(.top, 2)

                    primaryButton(title: "注册", isLoading: viewModel.isLoading) {
                        Task {
                            await viewModel.register(
                                username: username,
                                password: password,
                                displayName: displayName,
                                avatarName: selectedAvatar
                            )
                        }
                    }
                    .disabled(viewModel.isLoading || username.isEmpty || password.isEmpty || displayName.isEmpty)
                    .opacity(viewModel.isLoading || username.isEmpty || password.isEmpty || displayName.isEmpty ? 0.45 : 1)
                    .padding(.top, 2)

                    NavigationLink {
                        LoginView(viewModel: viewModel)
                    } label: {
                        HStack(spacing: 4) {
                            Text("已有账号？")
                                .foregroundStyle(.secondary)
                            Text("登录")
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
                .padding(18)
                .sideBGlassSurface(cornerRadius: 30)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.top, 56)
            .padding(.bottom, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("创建账号")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(.primary)

            Text("选择一个头像，开始保存和分享音乐。")
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
