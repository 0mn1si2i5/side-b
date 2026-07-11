import SwiftUI

struct CreateRoomView: View {
    @State private var viewModel = CreateRoomViewModel()
    @Environment(\.dismiss) private var dismiss
    let onCompleted: (() -> Void)?

    init(onCompleted: (() -> Void)? = nil) {
        self.onCompleted = onCompleted
    }

    var body: some View {
        Form {
            createSection
            joinSection
        }
        .navigationTitle("房间")
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
        .onChange(of: viewModel.createdRoom) { _, room in
            if room != nil {
                onCompleted?()
                dismiss()
            }
        }
        .onChange(of: viewModel.joinedRoom) { _, room in
            if room != nil {
                onCompleted?()
                dismiss()
            }
        }
    }

    private var createSection: some View {
        Section {
            TextField("房间名称（可选）", text: $viewModel.roomName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Button {
                viewModel.createRoom()
            } label: {
                actionButtonLabel(
                    title: "创建",
                    isLoading: viewModel.isLoading,
                    isActive: viewModel.hasRoomNameInput
                )
            }
            .disabled(!viewModel.canCreate)
            .buttonStyle(.plain)
        } header: {
            Text("创建房间")
        } footer: {
            Text("也可以留空，系统会使用默认房间名称。房间创建后再邀请成员。")
        }
    }

    private var joinSection: some View {
        Section {
            TextField("例如 A1B2C3D4", text: $viewModel.roomCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .font(.system(.body, design: .monospaced))
                .onChange(of: viewModel.roomCode) { _, newValue in
                    viewModel.roomCode = newValue.uppercased()
                }

            Button {
                viewModel.joinRoom()
            } label: {
                actionButtonLabel(
                    title: "加入",
                    isLoading: viewModel.isJoining,
                    isActive: viewModel.hasRoomCodeInput
                )
            }
            .disabled(viewModel.isJoining)
            .buttonStyle(.plain)
        } header: {
            Text("加入房间")
        } footer: {
            Text("房间号可在房间管理页查看。")
        }
    }

    private func actionButtonLabel(title: String, isLoading: Bool, isActive: Bool) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.medium))

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 11)
        .foregroundStyle(isActive ? Color.sideBLinkBlue : Color.secondary)
        .background(
            isActive ? Color.sideBLinkBlue.opacity(0.12) : Color.secondary.opacity(0.10),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isActive ? Color.sideBLinkBlue.opacity(0.18) : Color.secondary.opacity(0.12), lineWidth: 1)
        }
    }
}
