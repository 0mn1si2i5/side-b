import Foundation

@Observable
final class AddToPlaylistViewModel {
    private let playlistStore: PlaylistStore
    var playlists: [Playlist] = []

    init(playlistStore: PlaylistStore = .shared) {
        self.playlistStore = playlistStore
    }

    func loadPlaylists() {
        playlists = playlistStore.loadPlaylists()
    }

    @discardableResult
    func addTrack(_ trackID: String, to playlist: Playlist) -> Bool {
        playlistStore.addTrack(trackID, to: playlist)
    }
}
