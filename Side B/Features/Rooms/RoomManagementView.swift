import SwiftUI

struct RoomManagementView: View {
    @State private var viewModel: RoomManagementViewModel
    @Environment(\.dismiss) private var dismiss
    private let onRoomUpdated: (Room) -> Void
    private let onDissolved: () -> Void

    init(
        room: Room,
        service: any RoomServiceProtocol = RoomServiceFactory.makeDefaultService(),
        onRoomUpdated: @escaping (Room) -> Void = { _ in },
        onDissolved: @escaping () -> Void = {}
    ) {
        _viewModel = State(initialValue: RoomManagementViewModel(room: room, service: service))
        self.onRoomUpdated = onRoomUpdated
        self.onDissolved = onDissolved
    }

    var body: some View {
        Form {
            roomInfoSection
            membersSection
            inviteSection
            dissolveSection
        }
        .navigationTitle("房间管理")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "操作失败",
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
        .onChange(of: viewModel.isDissolved) { _, isDissolved in
            if isDissolved {
                onDissolved()
                dismiss()
            }
        }
        .onChange(of: viewModel.room) { _, updatedRoom in
            onRoomUpdated(updatedRoom)
        }
        .task {
            await viewModel.loadMembers()
        }
    }

    private var roomInfoSection: some View {
        Section {
            HStack {
                Text("房间名称")
                Spacer()
                if viewModel.isEditingRoomName {
                    TextField("房间名称", text: $viewModel.newRoomName)
                        .multilineTextAlignment(.trailing)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .onSubmit {
                            viewModel.renameRoom()
                        }

                    Button("保存") {
                        viewModel.renameRoom()
                    }
                    .disabled(!viewModel.canRename)
                    .foregroundStyle(.sideBLinkBlue)

                    Button("取消") {
                        viewModel.cancelEditingRoomName()
                    }
                    .foregroundStyle(.secondary)
                } else {
                    Button {
                        viewModel.beginEditingRoomName()
                    } label: {
                        HStack(spacing: 6) {
                            Text(viewModel.room.name)
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("房间号")
                Spacer()
                Text(viewModel.room.roomCode)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("成员")
                Spacer()
                Text("\(memberCount) 人")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("房间信息")
        }
    }

    private var memberCount: Int {
        [
            viewModel.members.count,
            viewModel.room.memberUsernames.count,
            viewModel.room.memberIDs.count,
        ].max() ?? 0
    }

    private var membersSection: some View {
        Section {
            if viewModel.members.isEmpty {
                Text("暂无成员信息")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.members) { member in
                    NavigationLink {
                        RoomMemberDetailView(member: member)
                    } label: {
                        RoomMemberRow(member: member)
                    }
                }
            }
        } header: {
            Text("成员")
        }
    }

    private var inviteSection: some View {
        Section {
            TextField("输入用户名", text: $viewModel.inviteUsername)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button("邀请成员") {
                viewModel.inviteMember()
            }
            .disabled(!viewModel.canInvite)
            .foregroundStyle(.sideBLinkBlue)
        } header: {
            Text("邀请成员")
        }
    }

    private var dissolveSection: some View {
        Section {
            Button("解散房间", role: .destructive) {
                viewModel.showDissolveConfirmation = true
            }
        }
        .confirmationDialog(
            "确定要解散这个房间吗？",
            isPresented: $viewModel.showDissolveConfirmation,
            titleVisibility: .visible
        ) {
            Button("解散", role: .destructive) {
                viewModel.dissolveRoom()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("此操作不可撤销，房间内的所有消息将被删除。")
        }
    }
}

private struct RoomMemberRow: View {
    let member: RoomMemberProfile

    var body: some View {
        HStack(spacing: 12) {
            RoomMemberAvatar(avatarName: member.avatarName, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(member.displayName)
                    .font(.body)
                Text("@\(member.username)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct RoomMemberDetailView: View {
    let member: RoomMemberProfile

    var body: some View {
        List {
            Section {
                VStack(spacing: 14) {
                    RoomMemberAvatar(avatarName: member.avatarName, size: 80)
                    Text(member.displayName)
                        .font(.title3.bold())
                    Text("@\(member.username)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
            }

            Section("资料") {
                LabeledContent("用户名", value: member.username)
                LabeledContent("显示名称", value: member.displayName)
                LabeledContent("加入时间", value: member.joinedAt.formatted(date: .abbreviated, time: .shortened))
            }
        }
        .navigationTitle("成员资料")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct RoomMemberAvatar: View {
    let avatarName: String
    let size: CGFloat

    var body: some View {
        let config = AvatarService.config(for: avatarName)
        Circle()
            .fill(config.backgroundColor.swiftUIColor.opacity(0.18))
            .frame(width: size, height: size)
            .overlay {
                Image(systemName: config.symbolName)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .foregroundStyle(config.backgroundColor.swiftUIColor)
                    .padding(size * 0.24)
            }
    }
}
