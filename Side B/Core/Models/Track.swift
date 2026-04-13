import Foundation

enum PlatformLinksStatus: String, Hashable {
    case idle
    case loading
    case loaded
    case failed
}

enum PlatformLinkLoadState: String, Hashable {
    case idle
    case loading
    case ready
    case unavailable
    case failed
}

struct PlatformLinkStatusEntry: Hashable, Identifiable {
    var id: MusicPlatform { platform }
    let platform: MusicPlatform
    let state: PlatformLinkLoadState
}

struct Track: Identifiable, Hashable {
    let id: UUID
    let title: String
    let artistName: String
    let albumTitle: String?
    let durationMS: Int?
    let sourcePlatform: MusicPlatform
    let sourcePlatformID: String?
    let sourceURL: URL?
    let isrc: String?
    let platformLinks: [PlatformLink]
    let platformLinksStatus: PlatformLinksStatus
    let platformLinkStatuses: [PlatformLinkStatusEntry]
    let artworkURL: URL?

    var sourcePlatformName: String {
        sourcePlatform.displayName
    }

    init(
        id: UUID = UUID(),
        title: String,
        artistName: String,
        albumTitle: String? = nil,
        durationMS: Int? = nil,
        sourcePlatform: MusicPlatform,
        sourcePlatformID: String? = nil,
        sourceURL: URL? = nil,
        isrc: String? = nil,
        platformLinks: [PlatformLink] = [],
        platformLinksStatus: PlatformLinksStatus = .loaded,
        platformLinkStatuses: [PlatformLinkStatusEntry]? = nil,
        missingPlatformLinksState: PlatformLinkLoadState = .unavailable,
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.durationMS = durationMS
        self.sourcePlatform = sourcePlatform
        self.sourcePlatformID = sourcePlatformID
        self.sourceURL = sourceURL
        self.isrc = isrc
        self.platformLinks = platformLinks
        self.platformLinksStatus = platformLinksStatus
        self.platformLinkStatuses = platformLinkStatuses ?? Self.defaultPlatformLinkStatuses(
            sourcePlatform: sourcePlatform,
            platformLinks: platformLinks,
            missingPlatformLinksState: missingPlatformLinksState
        )
        self.artworkURL = artworkURL
    }

    func updatingPlatformLinks(_ platformLinks: [PlatformLink], status: PlatformLinksStatus) -> Track {
        copy(
            platformLinks: platformLinks,
            platformLinksStatus: status,
            platformLinkStatuses: platformLinkStatuses
        )
    }

    func platformLinkState(for platform: MusicPlatform) -> PlatformLinkLoadState {
        platformLinkStatuses.first(where: { $0.platform == platform })?.state ?? .idle
    }

    func platformLink(for platform: MusicPlatform) -> PlatformLink? {
        platformLinks.first(where: { $0.platform == platform })
    }

    func updatingPlatformLinkState(_ state: PlatformLinkLoadState, for platform: MusicPlatform) -> Track {
        let updatedStatuses = MusicPlatform.allCases.map { currentPlatform in
            PlatformLinkStatusEntry(
                platform: currentPlatform,
                state: currentPlatform == platform ? state : platformLinkState(for: currentPlatform)
            )
        }

        return copy(platformLinkStatuses: updatedStatuses)
    }

    func updatingPlatformLink(_ platformLink: PlatformLink?, state: PlatformLinkLoadState, for platform: MusicPlatform) -> Track {
        var updatedLinks = platformLinks.filter { $0.platform != platform }
        if let platformLink {
            updatedLinks.append(platformLink)
        }

        let updatedStatuses = MusicPlatform.allCases.map { currentPlatform in
            PlatformLinkStatusEntry(
                platform: currentPlatform,
                state: currentPlatform == platform ? state : platformLinkState(for: currentPlatform)
            )
        }

        return copy(
            platformLinks: updatedLinks.sorted { lhs, rhs in
                guard
                    let lhsIndex = MusicPlatform.allCases.firstIndex(of: lhs.platform),
                    let rhsIndex = MusicPlatform.allCases.firstIndex(of: rhs.platform)
                else {
                    return lhs.platform.displayName < rhs.platform.displayName
                }
                return lhsIndex < rhsIndex
            },
            platformLinkStatuses: updatedStatuses
        )
    }

    func markingDeferredPlatformLinksIdle() -> Track {
        copy(
            platformLinksStatus: .idle,
            platformLinkStatuses: Self.deferredPlatformLinkStatuses(
                sourcePlatform: sourcePlatform,
                platformLinks: platformLinks
            )
        )
    }

    static func deferredPlatformLinkStatuses(sourcePlatform: MusicPlatform, platformLinks: [PlatformLink]) -> [PlatformLinkStatusEntry] {
        defaultPlatformLinkStatuses(
            sourcePlatform: sourcePlatform,
            platformLinks: platformLinks,
            missingPlatformLinksState: .idle
        )
    }

    var persistenceIdentity: String? {
        if let sourcePlatformID, !sourcePlatformID.isEmpty {
            return "\(sourcePlatform.rawValue)::\(sourcePlatformID)"
        }

        if let sourceURL {
            return sourceURL.absoluteString
        }

        return nil
    }

    func restoringPersistedPlatformLinks(
        _ platformLinks: [PlatformLink],
        statuses persistedStatuses: [PlatformLinkStatusEntry]
    ) -> Track {
        let availablePlatforms = Set(platformLinks.map(\.platform))
        let mergedStatuses = MusicPlatform.allCases.map { platform in
            if platform == sourcePlatform || availablePlatforms.contains(platform) {
                return PlatformLinkStatusEntry(platform: platform, state: .ready)
            }

            if let persistedStatus = persistedStatuses.first(where: { $0.platform == platform }) {
                return persistedStatus
            }

            return PlatformLinkStatusEntry(platform: platform, state: .idle)
        }

        let resolvedStatus: PlatformLinksStatus = mergedStatuses.contains(where: { $0.state == .failed }) ? .failed : .loaded
        return copy(
            platformLinks: platformLinks,
            platformLinksStatus: resolvedStatus,
            platformLinkStatuses: mergedStatuses
        )
    }

    private static func defaultPlatformLinkStatuses(
        sourcePlatform: MusicPlatform,
        platformLinks: [PlatformLink],
        missingPlatformLinksState: PlatformLinkLoadState
    ) -> [PlatformLinkStatusEntry] {
        let availablePlatforms = Set(platformLinks.map(\.platform))

        return MusicPlatform.allCases.map { platform in
            let state: PlatformLinkLoadState
            if availablePlatforms.contains(platform) || platform == sourcePlatform {
                state = .ready
            } else {
                state = missingPlatformLinksState
            }

            return PlatformLinkStatusEntry(platform: platform, state: state)
        }
    }

    private func copy(
        platformLinks: [PlatformLink]? = nil,
        platformLinksStatus: PlatformLinksStatus? = nil,
        platformLinkStatuses: [PlatformLinkStatusEntry]? = nil
    ) -> Track {
        Track(
            id: id,
            title: title,
            artistName: artistName,
            albumTitle: albumTitle,
            durationMS: durationMS,
            sourcePlatform: sourcePlatform,
            sourcePlatformID: sourcePlatformID,
            sourceURL: sourceURL,
            isrc: isrc,
            platformLinks: platformLinks ?? self.platformLinks,
            platformLinksStatus: platformLinksStatus ?? self.platformLinksStatus,
            platformLinkStatuses: platformLinkStatuses ?? self.platformLinkStatuses,
            artworkURL: artworkURL
        )
    }
}
