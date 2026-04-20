import Foundation

@Observable
final class CreatePlaylistViewModel {
    private let playlistStore: PlaylistStore

    init(playlistStore: PlaylistStore = .shared) {
        self.playlistStore = playlistStore
    }

    func createPlaylist(name: String) -> Playlist {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return playlistStore.savePlaylist(name: trimmedName)
    }
}
