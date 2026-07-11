import Foundation
import Observation

@Observable
final class CreateRoomViewModel {
    var roomName = ""
    var roomCode = ""
    var isLoading = false
    var isJoining = false
    var errorMessage: String?
    var createdRoom: Room?
    var joinedRoom: Room?

    private let service: any RoomServiceProtocol

    init(service: any RoomServiceProtocol = RoomServiceFactory.makeDefaultService()) {
        self.service = service
    }

    var canCreate: Bool {
        !isLoading
    }

    var hasRoomNameInput: Bool {
        !roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasRoomCodeInput: Bool {
        !roomCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func createRoom() {
        let name = roomName.trimmingCharacters(in: .whitespacesAndNewlines)

        isLoading = true
        errorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let room = try await service.createRoom(
                    name: name,
                    type: RoomType.group.rawValue,
                    memberUsernames: []
                )
                createdRoom = room
            } catch {
                errorMessage = localizedErrorMessage(for: error)
            }
            isLoading = false
        }
    }

    func joinRoom() {
        let code = roomCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }

        isJoining = true
        errorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                joinedRoom = try await service.joinRoom(code: code)
            } catch {
                errorMessage = localizedErrorMessage(for: error)
            }
            isJoining = false
        }
    }

    func clearError() {
        errorMessage = nil
    }
}
