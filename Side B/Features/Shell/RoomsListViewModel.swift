import SwiftUI

enum RoomsListState {
    case idle
    case loading
    case loaded([Room])
    case failed(String)
}

@Observable
final class RoomsListViewModel {
    var state: RoomsListState = .idle

    private let service: any RoomServiceProtocol

    init(service: any RoomServiceProtocol = RoomServiceFactory.makeDefaultService()!) {
        self.service = service
    }

    func loadRooms() {
        state = .loading
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let rooms = try await service.fetchRooms()
                state = .loaded(rooms)
            } catch {
                state = .failed(localizedErrorMessage(for: error))
            }
        }
    }
}
