import Foundation
import Observation

@Observable
final class RoomManagementViewModel {
    var room: Room
    var newRoomName = ""
    var inviteUsername = ""
    var isLoading = false
    var errorMessage: String?
    var showRenameSheet = false
    var showDissolveConfirmation = false
    var isDissolved = false

    private let service: any RoomServiceProtocol

    init(room: Room, service: any RoomServiceProtocol = RoomServiceFactory.makeDefaultService()!) {
        self.room = room
        self.service = service
    }

    var canRename: Bool {
        !newRoomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    var canInvite: Bool {
        !inviteUsername.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    func renameRoom() {
        let name = newRoomName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                room = try await service.renameRoom(id: room.id, newName: name)
                newRoomName = ""
                showRenameSheet = false
            } catch {
                errorMessage = "重命名失败：\(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    func inviteMember() {
        let username = inviteUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !username.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                room = try await service.addMember(roomId: room.id, username: username)
                inviteUsername = ""
            } catch {
                errorMessage = "邀请失败：\(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    func dissolveRoom() {
        isLoading = true
        errorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await service.dissolveRoom(id: room.id)
                isDissolved = true
            } catch {
                errorMessage = "解散失败：\(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
