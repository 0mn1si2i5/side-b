import Foundation

struct CachedTrack: Codable {
    let persistenceIdentity: String
    let title: String
    let artistName: String
    let albumTitle: String?
    let durationMS: Int?
    let sourcePlatformRaw: String
    let sourcePlatformID: String?
    let sourceURLString: String?
    let isrc: String?
    let artworkURLString: String?
    let platformLinks: [CachedPlatformLink]
    let platformLinkStatuses: [CachedPlatformLinkStatus]
    let cachedAt: Date

    init(
        persistenceIdentity: String,
        title: String,
        artistName: String,
        albumTitle: String? = nil,
        durationMS: Int? = nil,
        sourcePlatformRaw: String,
        sourcePlatformID: String? = nil,
        sourceURLString: String? = nil,
        isrc: String? = nil,
        artworkURLString: String? = nil,
        platformLinks: [CachedPlatformLink] = [],
        platformLinkStatuses: [CachedPlatformLinkStatus] = [],
        cachedAt: Date
    ) {
        self.persistenceIdentity = persistenceIdentity
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.durationMS = durationMS
        self.sourcePlatformRaw = sourcePlatformRaw
        self.sourcePlatformID = sourcePlatformID
        self.sourceURLString = sourceURLString
        self.isrc = isrc
        self.artworkURLString = artworkURLString
        self.platformLinks = platformLinks
        self.platformLinkStatuses = platformLinkStatuses
        self.cachedAt = cachedAt
    }

    init(track: Track) {
        self.persistenceIdentity = track.persistenceIdentity ?? ""
        self.title = track.title
        self.artistName = track.artistName
        self.albumTitle = track.albumTitle
        self.durationMS = track.durationMS
        self.sourcePlatformRaw = track.sourcePlatform.rawValue
        self.sourcePlatformID = track.sourcePlatformID
        self.sourceURLString = track.sourceURL?.absoluteString
        self.isrc = track.isrc
        self.artworkURLString = track.artworkURL?.absoluteString
        self.platformLinks = track.platformLinks.map(CachedPlatformLink.init)
        self.platformLinkStatuses = track.platformLinkStatuses.map(CachedPlatformLinkStatus.init)
        self.cachedAt = Date()
    }
}

struct CachedPlatformLink: Codable {
    let platformRaw: String
    let destinationURLString: String
    let isSource: Bool

    init(platformRaw: String, destinationURLString: String, isSource: Bool) {
        self.platformRaw = platformRaw
        self.destinationURLString = destinationURLString
        self.isSource = isSource
    }

    init(platformLink: PlatformLink) {
        platformRaw = platformLink.platform.rawValue
        destinationURLString = platformLink.destinationURL.absoluteString
        isSource = platformLink.isSource
    }

    func toPlatformLink() -> PlatformLink? {
        guard
            let platform = MusicPlatform(rawValue: platformRaw),
            let url = URL(string: destinationURLString)
        else {
            return nil
        }
        return PlatformLink(platform: platform, destinationURL: url, isSource: isSource)
    }
}

struct CachedPlatformLinkStatus: Codable {
    let platformRaw: String
    let stateRaw: String

    init(platformRaw: String, stateRaw: String) {
        self.platformRaw = platformRaw
        self.stateRaw = stateRaw
    }

    init(status: PlatformLinkStatusEntry) {
        platformRaw = status.platform.rawValue
        stateRaw = status.state.rawValue
    }

    func toStatus() -> PlatformLinkStatusEntry? {
        guard
            let platform = MusicPlatform(rawValue: platformRaw),
            let state = PlatformLinkLoadState(rawValue: stateRaw)
        else {
            return nil
        }
        return PlatformLinkStatusEntry(platform: platform, state: state)
    }
}

protocol TrackCacheProtocol: AnyObject {
    func save(track: Track)
    func track(for persistenceIdentity: String) -> Track?
    func removeTrack(for persistenceIdentity: String)
}

final class TrackCache: TrackCacheProtocol {
    static let shared = TrackCache()

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageKey = "sideb.trackCache"
    private let maxCacheSize = 50

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func save(track: Track) {
        guard let identity = track.persistenceIdentity else { return }
        var records = loadAllRecords()
        
        let cachedTrack = CachedTrack(track: track)
        records[identity] = cachedTrack
        
        // FIFO eviction: if exceeding max size, remove oldest entries
        if records.count > maxCacheSize {
            let sortedRecords = records.sorted { $0.value.cachedAt < $1.value.cachedAt }
            let recordsToRemove = sortedRecords.prefix(records.count - maxCacheSize)
            for (key, _) in recordsToRemove {
                records.removeValue(forKey: key)
            }
        }
        
        persistAllRecords(records)
    }

    func track(for persistenceIdentity: String) -> Track? {
        guard let cachedTrack = loadAllRecords()[persistenceIdentity] else { return nil }
        return reconstructTrack(from: cachedTrack)
    }

    func removeTrack(for persistenceIdentity: String) {
        var records = loadAllRecords()
        records.removeValue(forKey: persistenceIdentity)
        persistAllRecords(records)
    }

    private func loadAllRecords() -> [String: CachedTrack] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [:] }
        do {
            return try decoder.decode([String: CachedTrack].self, from: data)
        } catch {
            print("[TrackCache] decode failed:", error)
            return [:]
        }
    }

    private func persistAllRecords(_ records: [String: CachedTrack]) {
        let data: Data
        do {
            data = try encoder.encode(records)
        } catch {
            print("[TrackCache] encode failed:", error)
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }

    private func reconstructTrack(from cachedTrack: CachedTrack) -> Track? {
        guard let sourcePlatform = MusicPlatform(rawValue: cachedTrack.sourcePlatformRaw) else {
            return nil
        }

        let sourceURL = cachedTrack.sourceURLString.flatMap { URL(string: $0) }
        let artworkURL = cachedTrack.artworkURLString.flatMap { URL(string: $0) }

        var platformLinks = cachedTrack.platformLinks.compactMap { $0.toPlatformLink() }
        if let sourceURL = sourceURL, !platformLinks.contains(where: { $0.platform == sourcePlatform }) {
            platformLinks.append(PlatformLink(
                platform: sourcePlatform,
                destinationURL: sourceURL,
                isSource: true
            ))
        }

        let cachedStatuses = cachedTrack.platformLinkStatuses.compactMap { $0.toStatus() }
        let platformLinkStatuses = MusicPlatform.allCases.map { platform in
            if let cachedStatus = cachedStatuses.first(where: { $0.platform == platform }) {
                return cachedStatus
            }

            let state: PlatformLinkLoadState
            if platform == sourcePlatform || platformLinks.contains(where: { $0.platform == platform }) {
                state = .ready
            } else {
                state = .idle
            }
            return PlatformLinkStatusEntry(platform: platform, state: state)
        }

        return Track(
            title: cachedTrack.title,
            artistName: cachedTrack.artistName,
            albumTitle: cachedTrack.albumTitle,
            durationMS: cachedTrack.durationMS,
            sourcePlatform: sourcePlatform,
            sourcePlatformID: cachedTrack.sourcePlatformID,
            sourceURL: sourceURL,
            isrc: cachedTrack.isrc,
            platformLinks: platformLinks,
            platformLinksStatus: .idle,
            platformLinkStatuses: platformLinkStatuses,
            artworkURL: artworkURL
        )
    }
}
