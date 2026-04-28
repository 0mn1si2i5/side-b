import Foundation
import Observation

@Observable
final class CreateRoomViewModel {
    var roomName = ""
    var memberUsernamesText = ""
    var isLoading = false
    var errorMessage: String?
    var createdRoom: Room?

    private let service: any RoomServiceProtocol

    init(service: any RoomServiceProtocol = RoomServiceFactory.makeDefaultService()!) {
        self.service = service
    }

    private var parsedMemberUsernames: [String] {
        memberUsernamesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var canCreate: Bool {
        !isLoading
    }

    func createRoom() {
        let name = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        let usernames = parsedMemberUsernames

        isLoading = true
        errorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let room = try await service.createRoom(
                    name: name,
                    type: RoomType.group.rawValue,
                    memberUsernames: usernames
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
