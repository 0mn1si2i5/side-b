import Foundation
import os

private let playlistStoreLogger = Logger(subsystem: "com.sideb.app", category: "PlaylistStore")

protocol PlaylistStoreProtocol: AnyObject {
    func loadPlaylists() -> [Playlist]
    @discardableResult func savePlaylist(name: String, isDefault: Bool) -> Playlist
    func deletePlaylist(_ playlist: Playlist) -> Bool
    func renamePlaylist(_ playlist: Playlist, to newName: String) -> Playlist?
    @discardableResult func addTrack(_ trackID: String, to playlist: Playlist) -> Bool
    @discardableResult func addTrack(_ track: Track, to playlist: Playlist) -> Bool
    func removeTrack(_ entry: PlaylistTrackEntry, from playlist: Playlist) -> Bool
    func getTrackEntries(for playlist: Playlist) -> [PlaylistTrackEntry]
    func getDefaultPlaylist() -> Playlist?
}

final class PlaylistStore: PlaylistStoreProtocol {
    static let shared = PlaylistStore()

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageKey = "sideb.playlists"
    private let hasInitializedDefaultKey = "sideb.playlists.hasInitializedDefault"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        ensureDefaultPlaylistExists()
    }

    func loadPlaylists() -> [Playlist] {
        let playlists = loadAllRecords()
        return playlists.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func savePlaylist(name: String, isDefault: Bool = false) -> Playlist {
        let playlist = Playlist(name: name, isDefault: isDefault)
        var playlists = loadAllRecords()
        playlists.append(playlist)
        persistAllRecords(playlists)
        return playlist
    }

    func deletePlaylist(_ playlist: Playlist) -> Bool {
        guard !playlist.isDefault else { return false }

        var playlists = loadAllRecords()
        playlists.removeAll { $0.id == playlist.id }
        persistAllRecords(playlists)
        return true
    }

    func renamePlaylist(_ playlist: Playlist, to newName: String) -> Playlist? {
        var playlists = loadAllRecords()
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            return nil
        }

        let updatedPlaylist = playlists[index].copy(name: newName)
        playlists[index] = updatedPlaylist
        persistAllRecords(playlists)
        return updatedPlaylist
    }

    @discardableResult
    func addTrack(_ trackID: String, to playlist: Playlist) -> Bool {
        var playlists = loadAllRecords()
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            return false
        }

        var playlist = playlists[index]

        if playlist.trackEntries.contains(where: { $0.trackID == trackID }) {
            return false
        }

        let entry = PlaylistTrackEntry(trackID: trackID)
        let updatedEntries = [entry] + playlist.trackEntries
        playlist = playlist.copy(trackEntries: updatedEntries)

        playlists[index] = playlist
        persistAllRecords(playlists)
        return true
    }

    @discardableResult
    func addTrack(_ track: Track, to playlist: Playlist) -> Bool {
        guard let trackID = track.persistenceIdentity else { return false }
        return addTrack(trackID, to: playlist)
    }

    func removeTrack(_ entry: PlaylistTrackEntry, from playlist: Playlist) -> Bool {
        var playlists = loadAllRecords()
        guard let index = playlists.firstIndex(where: { $0.id == playlist.id }) else {
            return false
        }

        var playlist = playlists[index]
        var entries = playlist.trackEntries
        entries.removeAll { $0.id == entry.id }

        playlist = playlist.copy(trackEntries: entries)
        playlists[index] = playlist
        persistAllRecords(playlists)
        return true
    }

    func getTrackEntries(for playlist: Playlist) -> [PlaylistTrackEntry] {
        let playlists = loadAllRecords()
        guard let found = playlists.first(where: { $0.id == playlist.id }) else {
            return []
        }
        return found.trackEntries
    }

    func getDefaultPlaylist() -> Playlist? {
        let playlists = loadAllRecords()
        return playlists.first { $0.isDefault }
    }

    private func ensureDefaultPlaylistExists() {
        let hasInitialized = userDefaults.bool(forKey: hasInitializedDefaultKey)
        guard !hasInitialized else { return }

        var playlists = loadAllRecords()

        if !playlists.contains(where: { $0.isDefault }) {
            let defaultPlaylist = Playlist(name: "已收藏", isDefault: true)
            playlists.append(defaultPlaylist)
            persistAllRecords(playlists)
        }

        userDefaults.set(true, forKey: hasInitializedDefaultKey)
    }

    private func loadAllRecords() -> [Playlist] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [] }
        do {
            return try decoder.decode([Playlist].self, from: data)
        } catch {
            playlistStoreLogger.error("decode failed: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }

    private func persistAllRecords(_ playlists: [Playlist]) {
        let data: Data
        do {
            data = try encoder.encode(playlists)
        } catch {
            playlistStoreLogger.error("encode failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }
}
