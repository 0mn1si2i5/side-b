import SwiftUI

struct ProfileTabView: View {
    @Environment(AuthState.self) private var authState
    @AppStorage(SideBVisualStyle.appAppearanceStorageKey) private var appAppearanceRawValue = AppAppearance.system.rawValue
    @State private var isUpdatingPlatform = false
    @State private var isUpdatingProfile = false
    @State private var selectedPlatform: MusicPlatform?
    @State private var showingEditProfile = false
    @State private var draftDisplayName = ""
    @State private var draftAvatarName = "avatar_1"
    @State private var draftPreferredPlatform: MusicPlatform?

    var body: some View {
        List {
            if let user = authState.currentUser {
                Section {
                    Button {
                        beginEditingProfile(user)
                    } label: {
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

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                }

                Section {
                    Picker("外观", selection: $appAppearanceRawValue) {
                        ForEach(AppAppearance.allCases) { appearance in
                            Text(appearance.displayName)
                                .tag(appearance.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("显示")
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
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedPlatform = authState.currentUser?.preferredPlatform
        }
        .onChange(of: authState.currentUser) { _, newUser in
            guard !isUpdatingPlatform else { return }
            selectedPlatform = newUser?.preferredPlatform
        }
        .sheet(isPresented: $showingEditProfile) {
            editProfileSheet
        }
        .alert(
            "操作失败",
            isPresented: .init(
                get: { authState.errorMessage != nil },
                set: { if !$0 { authState.errorMessage = nil } }
            )
        ) {
            Button("好的", role: .cancel) {
                authState.errorMessage = nil
            }
        } message: {
            Text(authState.errorMessage ?? "")
        }
    }

    private var editProfileSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("显示名称", text: $draftDisplayName)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("显示名称")
                } footer: {
                    Text("2 到 20 个字符。")
                }

                Section {
                    AvatarSelectionView(selectedAvatar: $draftAvatarName)
                        .padding(.vertical, 4)
                } header: {
                    Text("头像")
                }

                Section {
                    Picker("常用平台", selection: $draftPreferredPlatform) {
                        Text("未设置").tag(MusicPlatform?.none)
                        ForEach(MusicPlatform.allCases, id: \.self) { platform in
                            Text(platform.displayName)
                                .tag(MusicPlatform?.some(platform))
                        }
                    }
                    .tint(.sideBLinkBlue)
                } header: {
                    Text("偏好设置")
                }
            }
            .navigationTitle("编辑资料")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        showingEditProfile = false
                    }
                    .disabled(isUpdatingProfile)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await saveProfileChanges() }
                    } label: {
                        if isUpdatingProfile {
                            ProgressView()
                        } else {
                            Text("保存")
                        }
                    }
                    .disabled(!canSaveProfile || isUpdatingProfile)
                    .tint(.sideBLinkBlue)
                }
            }
        }
    }

    private var canSaveProfile: Bool {
        let trimmedName = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...20).contains(trimmedName.count) else { return false }
        guard let user = authState.currentUser else { return false }
        return trimmedName != user.displayName
            || draftAvatarName != user.avatarName
            || draftPreferredPlatform != user.preferredPlatform
    }

    private func beginEditingProfile(_ user: User) {
        draftDisplayName = user.displayName
        draftAvatarName = user.avatarName
        draftPreferredPlatform = user.preferredPlatform
        showingEditProfile = true
    }

    private func updatePlatform(_ platform: MusicPlatform?) async {
        isUpdatingPlatform = true
        await authState.updatePreferredPlatform(platform)
        selectedPlatform = authState.currentUser?.preferredPlatform
        isUpdatingPlatform = false
    }

    private func saveProfileChanges() async {
        let trimmedName = draftDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canSaveProfile else { return }

        isUpdatingProfile = true
        let didUpdate = await authState.updateProfile(
            displayName: trimmedName,
            avatarName: draftAvatarName
        )
        if didUpdate, draftPreferredPlatform != authState.currentUser?.preferredPlatform {
            await authState.updatePreferredPlatform(draftPreferredPlatform)
        }
        isUpdatingProfile = false

        if didUpdate {
            showingEditProfile = false
        }
    }
}
