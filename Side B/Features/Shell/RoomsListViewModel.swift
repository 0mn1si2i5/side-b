import Foundation
import Observation

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

    init(service: any RoomServiceProtocol = RoomServiceFactory.makeDefaultService()) {
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

    func refreshRooms() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let rooms = try await service.fetchRooms()
                state = .loaded(rooms)
            } catch {
                if case .loaded = state {
                    return
                }
                state = .failed(localizedErrorMessage(for: error))
            }
        }
    }

    func removeRoom(id: UUID) {
        guard case .loaded(let rooms) = state else { return }
        state = .loaded(rooms.filter { $0.id != id })
    }

}
