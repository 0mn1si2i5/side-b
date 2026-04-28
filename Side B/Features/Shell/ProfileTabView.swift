import SwiftUI

struct ProfileTabView: View {
    @Environment(AuthState.self) private var authState
    @State private var isUpdatingPlatform = false
    @State private var selectedPlatform: MusicPlatform?

    var body: some View {
        List {
            if let user = authState.currentUser {
                Section {
                    HStack(spacing: 16) {
                        let avatarConfig = AvatarService.config(for: user.avatarName)
                        Image(systemName: avatarConfig.symbolName)
                            .font(.system(size: 48))
                            .foregroundStyle(avatarConfig.backgroundColor.swiftUIColor)
                            .frame(width: 64, height: 64)
                            .background(avatarConfig.backgroundColor.swiftUIColor.opacity(0.15))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(user.displayName)
                                .font(.title3)
                                .fontWeight(.semibold)

                            Text("@\(user.username)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let platform = user.preferredPlatform {
                                Text("常用平台：\(platform.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Picker("常用平台", selection: Binding<MusicPlatform?>(
                        get: { selectedPlatform },
                        set: { newPlatform in
                            selectedPlatform = newPlatform
                            Task { await updatePlatform(newPlatform) }
                        }
                    )) {
                        Text("未设置").tag(MusicPlatform?.none)
                        ForEach(MusicPlatform.allCases, id: \.self) { platform in
                            HStack {
                                Text(platform.displayName)
                                if isUpdatingPlatform {
                                    Spacer()
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                            .tag(MusicPlatform?.some(platform))
                        }
                    }
                    .disabled(isUpdatingPlatform)
                } header: {
                    Text("偏好设置")
                }

                Section {
                    Button(role: .destructive) {
                        Task { await authState.logout() }
                    } label: {
                        HStack {
                            Spacer()
                            Text("退出登录")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("我的")
        .onAppear {
            selectedPlatform = authState.currentUser?.preferredPlatform
        }
        .onChange(of: authState.currentUser) { _, newUser in
            guard !isUpdatingPlatform else { return }
            selectedPlatform = newUser?.preferredPlatform
        }
    }

    private func updatePlatform(_ platform: MusicPlatform?) async {
        isUpdatingPlatform = true
        await authState.updatePreferredPlatform(platform)
        selectedPlatform = authState.currentUser?.preferredPlatform
        isUpdatingPlatform = false
    }
}
