import Foundation
import Observation

@Observable
final class CreateRoomViewModel {
    var roomType: RoomType = .direct
    var roomName = ""
    var memberUsername = ""
    var memberUsernamesText = ""
    var isLoading = false
    var errorMessage: String?
    var createdRoom: Room?

    private let service: any RoomServiceProtocol

    init(service: any RoomServiceProtocol = RoomServiceFactory.makeDefaultService()!) {
        self.service = service
    }

    private var parsedMemberUsernames: [String] {
        let fromSingle = memberUsername.trimmingCharacters(in: .whitespacesAndNewlines)
        let fromMulti = memberUsernamesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        switch roomType {
        case .direct:
            return fromSingle.isEmpty ? [] : [fromSingle]
        case .group:
            let combined = if fromSingle.isEmpty { fromMulti } else { [fromSingle] }
            return combined
        }
    }

    var canCreate: Bool {
        if isLoading { return false }
        switch roomType {
        case .direct:
            return !parsedMemberUsernames.isEmpty
        case .group:
            return !roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !parsedMemberUsernames.isEmpty
        }
    }

    func createRoom() {
        let name: String
        switch roomType {
        case .direct:
            name = parsedMemberUsernames.first ?? ""
        case .group:
            name = roomName.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let usernames = parsedMemberUsernames

        guard !name.isEmpty, !usernames.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let room = try await service.createRoom(
                    name: name,
                    type: roomType.rawValue,
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
