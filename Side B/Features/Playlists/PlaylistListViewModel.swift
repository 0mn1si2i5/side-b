import Foundation
import os

private let logger = Logger(subsystem: "com.sideb.app", category: "PlaylistListViewModel")

@MainActor
@Observable
final class PlaylistListViewModel {
    var playlists: [Playlist] = []
    var linkInput = ""
    var isResolving = false
    var errorMessage = ""
    var recentlyResolved: [Track] = []
    var showAllRecentlyResolved = false
    var showErrorAlert = false
    var showingAddToPlaylistSheet = false
    var selectedTrackForPlaylist: Track?
    var showAddSuccessToast = false
    var addSuccessMessage = ""
    var showingCreateSheet = false

    private let resolver: any MusicResolverService

    init(resolver: any MusicResolverService = ResolverServiceFactory.makeDefaultService()) {
        self.resolver = resolver
    }

    // MARK: - Link Resolution

    func resolveLink() {
        let trimmedLink = linkInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLink.isEmpty else { return }

        isResolving = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let response = try await resolver.resolveMetadata(request: ResolverRequest(rawLink: trimmedLink))

                switch response.parsingResult {
                case .unsupportedLink:
                    errorMessage = "无法识别该链接，请粘贴 Spotify、Apple Music、网易云音乐或 QQ 音乐的歌曲链接"
                    showErrorAlert = true
                    isResolving = false
                    return
                case .missingResourceID:
                    errorMessage = "无法从链接中提取歌曲 ID"
                    showErrorAlert = true
                    isResolving = false
                    return
                case .parsed:
                    break
                }

                #if !DEBUG
                if response.metadataStatus == .fallbackMock {
                    errorMessage = "无法解析该歌曲，请检查链接是否正确"
                    showErrorAlert = true
                    isResolving = false
                    return
                }
                #endif

                let track = response.resolvedTrack.track
                if !track.title.isEmpty {
                    TrackCache.shared.save(track: track)

                    if let identity = track.persistenceIdentity {
                        RecentlyResolvedStore.shared.add(identity)
                        recentlyResolved.removeAll { $0.persistenceIdentity == identity }
                    }
                    recentlyResolved.insert(track, at: 0)

                    if recentlyResolved.count > 50 {
                        recentlyResolved = Array(recentlyResolved.prefix(50))
                    }

                    linkInput = ""
                    isResolving = false

                    resolvePlatformLinksAsync(for: track)
                } else {
                    errorMessage = "无法解析该链接，请检查链接是否正确"
                    showErrorAlert = true
                    isResolving = false
                }
            } catch {
                errorMessage = "解析失败：\(error.localizedDescription)"
                showErrorAlert = true
                isResolving = false
            }
        }
    }

    func resolvePlatformLinksAsync(for track: Track) {
        let nonSourcePlatforms = MusicPlatform.allCases.filter { $0 != track.sourcePlatform }
        let pendingPlatforms = nonSourcePlatforms.filter { platform in
            let state = track.platformLinkState(for: platform)
            return state == .idle || state == .failed
        }

        guard !pendingPlatforms.isEmpty else { return }

        Task { [weak self] in
            guard let self else { return }
            let resolver = self.resolver
            await withTaskGroup(of: (MusicPlatform, SinglePlatformLinkResolutionResponse?).self) { group in
                for platform in pendingPlatforms {
                    group.addTask {
                        do {
                            let result = try await resolver.resolvePlatformLink(for: track, targetPlatform: platform)
                            return (platform, result)
                        } catch {
                            logger.error("resolvePlatformLink failed: \(error)")
                            return (platform, nil)
                        }
                    }
                }

                for await (platform, result) in group {
                    guard let result else { continue }
                    if let index = self.recentlyResolved.firstIndex(where: { $0.id == track.id }) {
                        let updatedTrack = self.recentlyResolved[index].updatingPlatformLink(
                            result.platformLink,
                            state: result.state,
                            for: platform
                        )
                        self.recentlyResolved[index] = updatedTrack
                        TrackCache.shared.save(track: updatedTrack)
                    }
                }
            }
        }
    }

    // MARK: - Data Loading

    func loadRecentlyResolved() {
        let identities = RecentlyResolvedStore.shared.allEntries()
        var tracks: [Track] = []
        for identity in identities {
            if let track = TrackCache.shared.track(for: identity) {
                tracks.append(PlatformLinkPersistenceStore.shared.restore(track: track) ?? track)
            }
        }

        guard persistenceIdentities(for: tracks) != persistenceIdentities(for: recentlyResolved) else {
            return
        }

        recentlyResolved = tracks
    }

    func refreshPlaylists() {
        playlists = PlaylistStore.shared.loadPlaylists()
    }

    // MARK: - Mutations

    func deletePlaylists(at offsets: IndexSet) {
        for index in offsets {
            let playlist = playlists[index]
            if !playlist.isDefault {
                _ = PlaylistStore.shared.deletePlaylist(playlist)
            }
        }
        refreshPlaylists()
    }

    func removeRecentlyResolved(_ track: Track) {
        recentlyResolved.removeAll { $0.id == track.id }
        if let identity = track.persistenceIdentity {
            RecentlyResolvedStore.shared.remove(identity: identity)
        }
    }

    func updateRecentlyResolvedTrack(_ updatedTrack: Track) {
        if let index = recentlyResolved.firstIndex(where: { $0.id == updatedTrack.id }) {
            recentlyResolved[index] = updatedTrack
        } else if let identity = updatedTrack.persistenceIdentity,
                  let index = recentlyResolved.firstIndex(where: { $0.persistenceIdentity == identity }) {
            recentlyResolved[index] = updatedTrack
        }
        TrackCache.shared.save(track: updatedTrack)
    }

    private func persistenceIdentities(for tracks: [Track]) -> [String] {
        tracks.compactMap(\.persistenceIdentity)
    }
}
