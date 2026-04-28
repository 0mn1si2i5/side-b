import SwiftUI

struct RoomManagementView: View {
    @State private var viewModel: RoomManagementViewModel
    @Environment(\.dismiss) private var dismiss

    init(room: Room, service: any RoomServiceProtocol = RoomServiceFactory.makeDefaultService()!) {
        _viewModel = State(initialValue: RoomManagementViewModel(room: room, service: service))
    }

    var body: some View {
        Form {
            roomInfoSection
            renameSection
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
                dismiss()
            }
        }
    }

    private var roomInfoSection: some View {
        Section {
            HStack {
                Text("房间名称")
                Spacer()
                Text(viewModel.room.name)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("成员")
                Spacer()
                Text("\(viewModel.room.memberIDs.count) 人")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("房间信息")
        }
    }

    private var renameSection: some View {
        Section {
            Button {
                viewModel.showRenameSheet = true
            } label: {
                Label("重命名房间", systemImage: "pencil")
            }
        }
        .sheet(isPresented: $viewModel.showRenameSheet) {
            renameSheet
        }
    }

    private var renameSheet: some View {
        NavigationStack {
            Form {
                TextField("新名称", text: $viewModel.newRoomName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .navigationTitle("重命名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        viewModel.showRenameSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        viewModel.renameRoom()
                    }
                    .disabled(!viewModel.canRename)
                }
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                }
            }
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
