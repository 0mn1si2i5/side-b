import SwiftUI

struct CreateRoomView: View {
    @State private var viewModel = CreateRoomViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            detailsSection
            createButtonSection
        }
        .navigationTitle("新建聊天室")
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

    private var detailsSection: some View {
        Section {
            TextField("房间名称（可选）", text: $viewModel.roomName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            TextField("邀请成员（可选，逗号分隔用户名）", text: $viewModel.memberUsernamesText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Text("可以先创建只有自己的聊天室，之后在房间管理中再邀请别人。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } header: {
            Text("聊天室信息")
        }
    }
}
