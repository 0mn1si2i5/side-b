import SwiftUI

struct CreateRoomView: View {
    @State private var viewModel = CreateRoomViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            roomTypeSection
            detailsSection
            createButtonSection
        }
        .navigationTitle("新建聊天")
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            "创建失败",
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
        .onChange(of: viewModel.createdRoom) { _, _ in
            if viewModel.createdRoom != nil {
                dismiss()
            }
        }
    }

    private var createButtonSection: some View {
        Section {
            Button {
                viewModel.createRoom()
            } label: {
                HStack {
                    Text("创建")
                        .fontWeight(.semibold)
                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .disabled(!viewModel.canCreate)
        }
    }

    private var roomTypeSection: some View {
        Section {
            Picker("类型", selection: $viewModel.roomType) {
                Text("私聊").tag(RoomType.direct)
                Text("群聊").tag(RoomType.group)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("聊天类型")
        }
    }

    private var detailsSection: some View {
        Section {
            if viewModel.roomType == .group {
                TextField("房间名称", text: $viewModel.roomName)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }

            if viewModel.roomType == .direct {
                TextField("对方用户名", text: $viewModel.memberUsername)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                TextField("成员用户名（逗号分隔）", text: $viewModel.memberUsernamesText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
        } header: {
            Text(viewModel.roomType == .group ? "群聊信息" : "私聊信息")
        }
    }
}