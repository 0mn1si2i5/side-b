import Foundation

@Observable
final class PlaylistDetailViewModel {
    var trackEntries: [PlaylistTrackEntry] = []
    var entryTracks: [String: Track] = [:]
    var isRefreshing = false
    var currentPlaylist: Playlist
    var renameText: String
    var showingRenameSheet = false
    var showingDeleteConfirmation = false

    init(playlist: Playlist) {
        self.currentPlaylist = playlist
        self.renameText = playlist.name
    }

    // MARK: - Computed

    var sortedTrackEntries: [PlaylistTrackEntry] {
        trackEntries.sorted { $0.addedAt > $1.addedAt }
    }

    // MARK: - Data Loading

    func loadTrackEntries() {
        trackEntries = PlaylistStore.shared.getTrackEntries(for: currentPlaylist)
        resolveTracksForEntries()
    }

    private func resolveTracksForEntries() {
        var tracks: [String: Track] = [:]
        for entry in trackEntries {
            if let cachedTrack = TrackCache.shared.track(for: entry.trackID) {
                tracks[entry.trackID] = cachedTrack
            }
        }
        entryTracks = tracks
    }

    func resolvedTrack(for entry: PlaylistTrackEntry) -> Track? {
        entryTracks[entry.trackID]
    }

    // MARK: - Track Entry Actions

    func deleteTrackEntry(_ entry: PlaylistTrackEntry) {
        if PlaylistStore.shared.removeTrack(entry, from: currentPlaylist) {
            loadTrackEntries()
        }
    }

    // MARK: - Playlist Actions

    func renamePlaylist(to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let updated = PlaylistStore.shared.renamePlaylist(currentPlaylist, to: trimmed) {
            currentPlaylist = updated
        }
    }

    func deletePlaylist() -> Bool {
        guard !currentPlaylist.isDefault else { return false }
        _ = PlaylistStore.shared.deletePlaylist(currentPlaylist)
        return true
    }

    func resetRenameText() {
        renameText = currentPlaylist.name
    }
}
