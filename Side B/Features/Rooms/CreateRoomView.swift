import SwiftUI

@Observable
final class CreateRoomViewModel {
    var roomType: RoomType = .direct
    var roomName = ""
    var memberUsername = ""
    var isLoading = false
    var errorMessage: String?
    var createdRoom: Room?

    private let service: any RoomServiceProtocol

    init(service: any RoomServiceProtocol = RoomServiceFactory.makeDefaultService()) {
        self.service = service
    }

    var canCreate: Bool {
        if isLoading { return false }
        switch roomType {
        case .direct:
            return !memberUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .group:
            return !roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !memberUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    func createRoom() {
        let name: String
        switch roomType {
        case .direct:
            name = memberUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        case .group:
            name = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let username = memberUsername.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, !username.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let room = try await service.createRoom(
                    name: name,
                    type: roomType.rawValue,
                    memberUsername: username
                )
                createdRoom = room
            } catch {
                errorMessage = localizedErrorMessage(for: error)
            }
            isLoading = false
        }
    }

    func clearError() {
        errorMessage = nil
    }
}

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

            TextField("对方用户名", text: $viewModel.memberUsername)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text(viewModel.roomType == .group ? "群聊信息" : "私聊信息")
        }
    }
}