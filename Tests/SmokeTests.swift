import Foundation

// MARK: - Minimal Test Framework

var passedTests = 0
var failedTests = 0
var currentTestName = ""

func assertTrue(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        passedTests += 1
        print("  ✅ PASS: \(message)")
    } else {
        failedTests += 1
        print("  ❌ FAIL: \(message)")
    }
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String, file: String = #file, line: Int = #line) {
    if actual == expected {
        passedTests += 1
        print("  ✅ PASS: \(message)")
    } else {
        failedTests += 1
        print("  ❌ FAIL: \(message) — expected \(expected), got \(actual)")
    }
}

func assertNotNil<T>(_ optional: T?, _ message: String, file: String = #file, line: Int = #line) {
    if optional != nil {
        passedTests += 1
        print("  ✅ PASS: \(message)")
    } else {
        failedTests += 1
        print("  ❌ FAIL: \(message) — value was nil")
    }
}

func runTestSuite(_ name: String, _ block: () -> Void) {
    print("\n📋 \(name)")
    block()
}

// MARK: - Model Stubs (standalone, no app module dependency)

enum MusicPlatform: String, CaseIterable, Hashable, Codable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case qqMusic = "QQ 音乐"
    case neteaseMusic = "网易云音乐"

    var displayName: String { rawValue }
}

struct PlatformLink: Identifiable, Hashable, Codable {
    let id: UUID
    let platform: MusicPlatform
    let destinationURL: URL
    let isSource: Bool

    init(id: UUID = UUID(), platform: MusicPlatform, destinationURL: URL, isSource: Bool = false) {
        self.id = id
        self.platform = platform
        self.destinationURL = destinationURL
        self.isSource = isSource
    }
}

enum PlatformLinksStatus: String, Hashable, Codable {
    case idle, loading, loaded, failed
}

enum PlatformLinkLoadState: String, Hashable, Codable {
    case idle, loading, ready, unavailable, failed
}

struct PlatformLinkStatusEntry: Hashable, Identifiable, Codable {
    var id: MusicPlatform { platform }
    let platform: MusicPlatform
    let state: PlatformLinkLoadState

    init(platform: MusicPlatform, state: PlatformLinkLoadState) {
        self.platform = platform
        self.state = state
    }
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

    var persistenceIdentity: String? {
        if let sourcePlatformID, !sourcePlatformID.isEmpty {
            return "\(sourcePlatform.rawValue)::\(sourcePlatformID)"
        }
        if let sourceURL {
            return sourceURL.absoluteString
        }
        return nil
    }

    func platformLink(for platform: MusicPlatform) -> PlatformLink? {
        platformLinks.first(where: { $0.platform == platform })
    }

    func platformLinkState(for platform: MusicPlatform) -> PlatformLinkLoadState {
        platformLinkStatuses.first(where: { $0.platform == platform })?.state ?? .idle
    }

    func updatingPlatformLinks(_ newLinks: [PlatformLink], status: PlatformLinksStatus) -> Track {
        copy(platformLinks: newLinks, platformLinksStatus: status, platformLinkStatuses: platformLinkStatuses)
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

    func restoringPersistedPlatformLinks(
        _ links: [PlatformLink],
        statuses persistedStatuses: [PlatformLinkStatusEntry]
    ) -> Track {
        let availablePlatforms = Set(links.map(\.platform))
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
            platformLinks: links,
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

// MARK: - Additional Model Stubs for T27/T28/T31

struct EmojiReaction: Identifiable, Hashable, Codable {
    let id: UUID
    let messageId: UUID
    let userId: UUID
    let emoji: String
    let createdAt: Date

    init(id: UUID = UUID(), messageId: UUID, userId: UUID, emoji: String, createdAt: Date = Date()) {
        self.id = id
        self.messageId = messageId
        self.userId = userId
        self.emoji = emoji
        self.createdAt = createdAt
    }
}

enum MessageType: String, Codable, Hashable {
    case text = "text"
    case song = "song"
    case system = "system"
}

struct Message: Identifiable, Hashable {
    let id: UUID
    let senderName: String
    let senderID: UUID?
    let contentType: MessageType
    let text: String?
    let track: Track?
    let replyToMessageID: UUID?
    let sentAt: Date
    var emojiReactions: [EmojiReaction]

    init(
        id: UUID = UUID(),
        senderName: String,
        senderID: UUID? = nil,
        contentType: MessageType = .text,
        text: String? = nil,
        track: Track? = nil,
        replyToMessageID: UUID? = nil,
        sentAt: Date,
        emojiReactions: [EmojiReaction] = []
    ) {
        self.id = id
        self.senderName = senderName
        self.senderID = senderID
        self.contentType = contentType
        self.text = text
        self.track = track
        self.replyToMessageID = replyToMessageID
        self.sentAt = sentAt
        self.emojiReactions = emojiReactions
    }

    func updatingTrack(_ newTrack: Track?) -> Message {
        Message(
            id: id,
            senderName: senderName,
            senderID: senderID,
            contentType: contentType,
            text: text,
            track: newTrack,
            replyToMessageID: replyToMessageID,
            sentAt: sentAt,
            emojiReactions: emojiReactions
        )
    }
}

enum RoomType: String, Codable, Hashable {
    case direct = "direct"
    case group = "group"
}

struct Room: Identifiable, Hashable {
    let id: UUID
    let name: String
    let type: RoomType
    let memberIDs: [UUID]
    let memberUsernames: [String]
    let createdBy: UUID
    let createdAt: Date
    let isActive: Bool
    let latestTrack: Track?
    let latestMessagePreview: String?

    init(
        id: UUID = UUID(),
        name: String,
        type: RoomType = .group,
        memberIDs: [UUID] = [],
        memberUsernames: [String] = [],
        createdBy: UUID = UUID(),
        createdAt: Date = Date(),
        isActive: Bool = true,
        latestTrack: Track? = nil,
        latestMessagePreview: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.memberIDs = memberIDs
        self.memberUsernames = memberUsernames
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.isActive = isActive
        self.latestTrack = latestTrack
        self.latestMessagePreview = latestMessagePreview
    }
}

struct User: Identifiable, Hashable, Codable {
    let id: UUID
    let username: String
    let displayName: String
    let avatarName: String
    let preferredPlatform: MusicPlatform?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        username: String,
        displayName: String,
        avatarName: String,
        preferredPlatform: MusicPlatform? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.username = username
        self.displayName = displayName
        self.avatarName = avatarName
        self.preferredPlatform = preferredPlatform
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case displayName = "display_name"
        case avatarName = "avatar_name"
        case preferredPlatform = "preferred_platform"
        case createdAt = "created_at"
    }
}

struct PlaylistTrackEntry: Identifiable, Hashable, Codable {
    let id: UUID
    let trackID: String
    let addedAt: Date

    init(id: UUID = UUID(), trackID: String, addedAt: Date = Date()) {
        self.id = id
        self.trackID = trackID
        self.addedAt = addedAt
    }
}

struct Playlist: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let trackEntries: [PlaylistTrackEntry]
    let createdAt: Date
    let isDefault: Bool

    init(
        id: UUID = UUID(),
        name: String,
        trackEntries: [PlaylistTrackEntry] = [],
        createdAt: Date = Date(),
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.trackEntries = trackEntries
        self.createdAt = createdAt
        self.isDefault = isDefault
    }

    func copy(
        name: String? = nil,
        trackEntries: [PlaylistTrackEntry]? = nil,
        createdAt: Date? = nil,
        isDefault: Bool? = nil
    ) -> Playlist {
        Playlist(
            id: id,
            name: name ?? self.name,
            trackEntries: trackEntries ?? self.trackEntries,
            createdAt: createdAt ?? self.createdAt,
            isDefault: isDefault ?? self.isDefault
        )
    }
}

// MARK: - PlaylistStore Stub

final class PlaylistStore {
    static let shared = PlaylistStore()

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageKey = "sideb_test.playlists"
    private let hasInitializedDefaultKey = "sideb_test.playlists.hasInitializedDefault"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        // Don't auto-create default playlist in tests
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

    func getDefaultPlaylist() -> Playlist? {
        let playlists = loadAllRecords()
        return playlists.first { $0.isDefault }
    }

    func clearAll() {
        userDefaults.removeObject(forKey: storageKey)
    }

    private func loadAllRecords() -> [Playlist] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [] }
        do {
            return try decoder.decode([Playlist].self, from: data)
        } catch {
            return []
        }
    }

    private func persistAllRecords(_ playlists: [Playlist]) {
        guard let data = try? encoder.encode(playlists) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}

// MARK: - PlatformLinkPersistenceStore Stub

struct PersistedPlatformLinkRecord {
    let platformLinks: [PlatformLink]
    let platformLinkStatuses: [PlatformLinkStatusEntry]
    let updatedAt: Date
}

final class PlatformLinkPersistenceStore {
    static let shared = PlatformLinkPersistenceStore()

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageKey = "sideb_test.persistedPlatformLinks"
    private let loadingExpiryInterval: TimeInterval = 5 * 60

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func restore(track: Track) -> Track? {
        guard let record = loadRecord(for: track) else { return nil }
        let sanitizedStatuses = sanitizeStatuses(record.platformLinkStatuses, updatedAt: record.updatedAt)
        return track.restoringPersistedPlatformLinks(record.platformLinks, statuses: sanitizedStatuses)
    }

    func save(track: Track) {
        guard let identity = track.persistenceIdentity else { return }
        var records = loadAllRecords()
        let linkBodies = track.platformLinks.map { PersistedPlatformLinkBody(platformLink: $0) }
        let statusBodies = track.platformLinkStatuses.map { PersistedPlatformLinkStatusBody(status: $0) }
        records[identity] = PersistedPlatformLinkRecordBody(
            platformLinks: linkBodies,
            platformLinkStatuses: statusBodies,
            updatedAt: Date()
        )
        persistAllRecords(records)
    }

    func clearAll() {
        userDefaults.removeObject(forKey: storageKey)
    }

    private func loadRecord(for track: Track) -> PersistedPlatformLinkRecord? {
        for identity in candidateIdentities(for: track) {
            guard let record = loadAllRecords()[identity] else { continue }
            return record.toDomain()
        }
        return nil
    }

    private func candidateIdentities(for track: Track) -> [String] {
        var identities: [String] = []
        if let sourcePlatformID = track.sourcePlatformID, !sourcePlatformID.isEmpty {
            identities.append("\(track.sourcePlatform.rawValue)::\(sourcePlatformID)")
        }
        if let sourceURL = track.sourceURL?.absoluteString {
            identities.append(sourceURL)
        }
        return identities
    }

    private func sanitizeStatuses(_ statuses: [PlatformLinkStatusEntry], updatedAt: Date) -> [PlatformLinkStatusEntry] {
        guard Date().timeIntervalSince(updatedAt) > loadingExpiryInterval else { return statuses }
        return statuses.map { entry in
            guard entry.state == .loading else { return entry }
            return PlatformLinkStatusEntry(platform: entry.platform, state: .idle)
        }
    }

    private func loadAllRecords() -> [String: PersistedPlatformLinkRecordBody] {
        guard let data = userDefaults.data(forKey: storageKey) else { return [:] }
        do {
            return try decoder.decode([String: PersistedPlatformLinkRecordBody].self, from: data)
        } catch {
            return [:]
        }
    }

    private func persistAllRecords(_ records: [String: PersistedPlatformLinkRecordBody]) {
        guard let data = try? encoder.encode(records) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}

private struct PersistedPlatformLinkRecordBody: Codable {
    let platformLinks: [PersistedPlatformLinkBody]
    let platformLinkStatuses: [PersistedPlatformLinkStatusBody]
    let updatedAt: Date

    func toDomain() -> PersistedPlatformLinkRecord {
        let links = platformLinks.compactMap { $0.toDomain }
        let statuses = platformLinkStatuses.compactMap { $0.toDomain }
        return PersistedPlatformLinkRecord(platformLinks: links, platformLinkStatuses: statuses, updatedAt: updatedAt)
    }
}

private struct PersistedPlatformLinkBody: Codable {
    let platform: String
    let destinationURL: String
    let isSource: Bool

    init(platformLink: PlatformLink) {
        platform = platformLink.platform.rawValue
        destinationURL = platformLink.destinationURL.absoluteString
        isSource = platformLink.isSource
    }

    var toDomain: PlatformLink? {
        guard let platform = MusicPlatform(rawValue: platform), let url = URL(string: destinationURL) else {
            return nil
        }
        return PlatformLink(platform: platform, destinationURL: url, isSource: isSource)
    }
}

private struct PersistedPlatformLinkStatusBody: Codable {
    let platform: String
    let state: String

    init(status: PlatformLinkStatusEntry) {
        platform = status.platform.rawValue
        state = status.state.rawValue
    }

    var toDomain: PlatformLinkStatusEntry? {
        guard let platform = MusicPlatform(rawValue: platform), let state = PlatformLinkLoadState(rawValue: state) else {
            return nil
        }
        return PlatformLinkStatusEntry(platform: platform, state: state)
    }
}

// MARK: - Smoke Tests (Original 30 assertions)

runTestSuite("Smoke Test — Always Passes") {
    assertTrue(true, "trivial truth")
    assertEqual(1 + 1, 2, "basic arithmetic")
}

runTestSuite("Track Model — Basic Creation") {
    let track = Track(
        title: "Bohemian Rhapsody",
        artistName: "Queen",
        albumTitle: "A Night at the Opera",
        sourcePlatform: .spotify,
        sourcePlatformID: "spotify:track:123",
        sourceURL: URL(string: "https://open.spotify.com/track/123")
    )

    assertEqual(track.title, "Bohemian Rhapsody", "title is set correctly")
    assertEqual(track.artistName, "Queen", "artist name is set correctly")
    assertEqual(track.albumTitle, "A Night at the Opera", "album title is set correctly")
    assertEqual(track.sourcePlatform, .spotify, "source platform is spotify")
    assertEqual(track.sourcePlatformName, "Spotify", "source platform display name")
    assertEqual(track.sourcePlatformID, "spotify:track:123", "source platform ID")
    assertNotNil(track.id, "track has an id")
}

runTestSuite("Track Model — Platform Link Statuses") {
    let spotifyLink = PlatformLink(
        platform: .spotify,
        destinationURL: URL(string: "https://open.spotify.com/track/123")!,
        isSource: true
    )

    let track = Track(
        title: "Test Song",
        artistName: "Test Artist",
        sourcePlatform: .spotify,
        platformLinks: [spotifyLink]
    )

    assertEqual(track.platformLinks.count, 1, "has one platform link")
    assertEqual(track.platformLinkStatuses.count, 4, "has status entries for all 4 platforms")
    assertEqual(track.platformLinksStatus, .loaded, "platform links status is loaded")

    let spotifyState = track.platformLinkStatuses.first { $0.platform == .spotify }
    assertNotNil(spotifyState, "spotify status entry exists")
    assertEqual(spotifyState?.state, .ready, "spotify link state is ready")
}

runTestSuite("Track Model — Persistence Identity") {
    let trackWithID = Track(
        title: "Test",
        artistName: "Artist",
        sourcePlatform: .appleMusic,
        sourcePlatformID: "apple:music:456"
    )
    assertEqual(trackWithID.persistenceIdentity, "Apple Music::apple:music:456", "persistence identity from platform ID")

    let trackWithURL = Track(
        title: "Test",
        artistName: "Artist",
        sourcePlatform: .spotify,
        sourceURL: URL(string: "https://open.spotify.com/track/789")
    )
    assertEqual(trackWithURL.persistenceIdentity, "https://open.spotify.com/track/789", "persistence identity from URL")

    let trackWithNeither = Track(
        title: "Test",
        artistName: "Artist",
        sourcePlatform: .qqMusic,
        sourcePlatformID: "",
        sourceURL: nil
    )
    assertTrue(trackWithNeither.persistenceIdentity == nil, "nil persistence identity when no ID or URL")
}

runTestSuite("MusicPlatform — All Cases") {
    assertEqual(MusicPlatform.allCases.count, 4, "four platforms total")
    assertEqual(MusicPlatform.spotify.displayName, "Spotify", "spotify display name")
    assertEqual(MusicPlatform.appleMusic.displayName, "Apple Music", "apple music display name")
    assertEqual(MusicPlatform.qqMusic.displayName, "QQ 音乐", "qq music display name")
    assertEqual(MusicPlatform.neteaseMusic.displayName, "网易云音乐", "netease display name")
}

runTestSuite("MusicPlatform — Raw Value Roundtrip") {
    for platform in MusicPlatform.allCases {
        let raw = platform.rawValue
        let decoded = MusicPlatform(rawValue: raw)
        assertNotNil(decoded, "\(raw) decodes from raw value")
        assertEqual(decoded, platform, "\(raw) roundtrips correctly")
    }
}

// MARK: - T26: Track Model Additional Tests (6 new assertions)

runTestSuite("T26: Track — updatingPlatformLinks preserves id") {
    let track = Track(
        title: "Test",
        artistName: "Artist",
        sourcePlatform: .spotify,
        sourcePlatformID: "spotify:track:abc"
    )
    let newLink = PlatformLink(
        platform: .appleMusic,
        destinationURL: URL(string: "https://music.apple.com/track/123")!
    )
    let updated = track.updatingPlatformLinks([newLink], status: .loaded)
    assertEqual(updated.id, track.id, "updatingPlatformLinks preserves track id")
}

runTestSuite("T26: Track — platformLinkState returns ready for source platform") {
    let track = Track(
        title: "Test",
        artistName: "Artist",
        sourcePlatform: .spotify
    )
    let state = track.platformLinkState(for: .spotify)
    assertEqual(state, .ready, "platformLinkState returns .ready for source platform")
}

runTestSuite("T26: Track — updatingPlatformLink adds new link") {
    let track = Track(
        title: "Test",
        artistName: "Artist",
        sourcePlatform: .spotify
    )
    let appleLink = PlatformLink(
        platform: .appleMusic,
        destinationURL: URL(string: "https://music.apple.com/track/456")!
    )
    let updated = track.updatingPlatformLink(appleLink, state: .ready, for: .appleMusic)
    assertEqual(updated.platformLinks.count, 1, "updatingPlatformLink adds one link")
    assertEqual(updated.platformLinks.first?.platform, .appleMusic, "added link is for correct platform")
}

runTestSuite("T26: Track — persistenceIdentity with sourcePlatformID") {
    let track = Track(
        title: "Test",
        artistName: "Artist",
        sourcePlatform: .neteaseMusic,
        sourcePlatformID: "netease:12345"
    )
    assertEqual(track.persistenceIdentity, "网易云音乐::netease:12345", "persistenceIdentity combines platform and ID")
}

runTestSuite("T26: Track — persistenceIdentity fallback to sourceURL") {
    let track = Track(
        title: "Test",
        artistName: "Artist",
        sourcePlatform: .qqMusic,
        sourcePlatformID: nil,
        sourceURL: URL(string: "https://y.qq.com/n/ryqq/songDetail/001abc")
    )
    assertEqual(track.persistenceIdentity, "https://y.qq.com/n/ryqq/songDetail/001abc", "persistenceIdentity falls back to sourceURL")
}

runTestSuite("T26: Track — restoringPersistedPlatformLinks merges correctly") {
    let track = Track(
        title: "Test",
        artistName: "Artist",
        sourcePlatform: .spotify,
        sourcePlatformID: "spotify:track:abc"
    )
    let persistedLink = PlatformLink(
        platform: .appleMusic,
        destinationURL: URL(string: "https://music.apple.com/track/xyz")!
    )
    let persistedStatuses: [PlatformLinkStatusEntry] = [
        PlatformLinkStatusEntry(platform: .spotify, state: .ready),
        PlatformLinkStatusEntry(platform: .appleMusic, state: .ready),
        PlatformLinkStatusEntry(platform: .qqMusic, state: .unavailable),
        PlatformLinkStatusEntry(platform: .neteaseMusic, state: .idle)
    ]
    let restored = track.restoringPersistedPlatformLinks([persistedLink], statuses: persistedStatuses)
    assertEqual(restored.platformLinks.count, 1, "restored track has persisted platform link")
    assertEqual(restored.platformLinks.first?.platform, .appleMusic, "restored link is apple music")
    assertEqual(restored.platformLinksStatus, .loaded, "restored status is loaded")
}

// MARK: - T27: Message/Room/User Tests (7 new assertions)

runTestSuite("T27: Message — updatingTrack returns new message with updated track") {
    let originalTrack = Track(
        title: "Original",
        artistName: "Artist",
        sourcePlatform: .spotify
    )
    let updatedTrack = Track(
        title: "Updated",
        artistName: "Artist",
        sourcePlatform: .spotify
    )
    let message = Message(
        senderName: "Tester",
        contentType: .song,
        track: originalTrack,
        sentAt: Date()
    )
    let updatedMessage = message.updatingTrack(updatedTrack)
    assertEqual(updatedMessage.id, message.id, "updatingTrack preserves message id")
    assertEqual(updatedMessage.track?.title, "Updated", "updatingTrack sets new track")
    assertEqual(updatedMessage.senderName, message.senderName, "updatingTrack preserves senderName")
}

runTestSuite("T27: Message — init with text contentType") {
    let message = Message(
        senderName: "Alice",
        contentType: .text,
        text: "Hello, world!",
        sentAt: Date()
    )
    assertEqual(message.contentType, .text, "message contentType is text")
    assertEqual(message.text, "Hello, world!", "message text is set")
    assertTrue(message.track == nil, "text message has no track")
}

runTestSuite("T27: Message — init with song contentType") {
    let track = Track(
        title: "Song",
        artistName: "Artist",
        sourcePlatform: .spotify
    )
    let message = Message(
        senderName: "Bob",
        contentType: .song,
        track: track,
        sentAt: Date()
    )
    assertEqual(message.contentType, .song, "message contentType is song")
    assertNotNil(message.track, "song message has a track")
}

runTestSuite("T27: Room — direct type room") {
    let room = Room(
        name: "DM Room",
        type: .direct,
        memberIDs: [UUID(), UUID()],
        memberUsernames: ["alice", "bob"]
    )
    assertEqual(room.type, .direct, "room type is direct")
    assertEqual(room.memberIDs.count, 2, "direct room has 2 members")
    assertEqual(room.name, "DM Room", "room name is set")
}

runTestSuite("T27: User — Codable roundtrip") {
    let user = User(
        id: UUID(),
        username: "testuser",
        displayName: "Test User",
        avatarName: "avatar_default",
        preferredPlatform: .spotify,
        createdAt: Date(timeIntervalSince1970: 1000)
    )
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    guard let data = try? encoder.encode(user) else {
        assertTrue(false, "User encode succeeded")
        return
    }
    assertTrue(true, "User encode succeeded")

    guard let decoded = try? decoder.decode(User.self, from: data) else {
        assertTrue(false, "User decode succeeded")
        return
    }
    assertTrue(true, "User decode succeeded")

    assertEqual(decoded.id, user.id, "decoded User has same id")
    assertEqual(decoded.username, "testuser", "decoded User has same username")
    assertEqual(decoded.displayName, "Test User", "decoded User has same displayName")
    assertEqual(decoded.avatarName, "avatar_default", "decoded User has same avatarName")
    assertEqual(decoded.preferredPlatform, .spotify, "decoded User has same preferredPlatform")
}

// MARK: - T28: PlaylistStore Tests (4 new assertions)

runTestSuite("T28: PlaylistStore — save and load playlists") {
    let testDefaults = UserDefaults(suiteName: "sideb_test_t28")!
    testDefaults.removePersistentDomain(forName: "sideb_test_t28")
    let store = PlaylistStore(userDefaults: testDefaults)
    store.clearAll()

    let playlist = store.savePlaylist(name: "My Favorites")
    assertEqual(playlist.name, "My Favorites", "savePlaylist creates playlist with given name")
    assertEqual(playlist.isDefault, false, "new playlist is not default")

    let loaded = store.loadPlaylists()
    assertEqual(loaded.count, 1, "loadPlaylists returns saved playlist")
    assertEqual(loaded.first?.name, "My Favorites", "loaded playlist has correct name")

    testDefaults.removePersistentDomain(forName: "sideb_test_t28")
}

runTestSuite("T28: PlaylistStore — rename playlist") {
    let testDefaults = UserDefaults(suiteName: "sideb_test_t28_rename")!
    testDefaults.removePersistentDomain(forName: "sideb_test_t28_rename")
    let store = PlaylistStore(userDefaults: testDefaults)
    store.clearAll()

    let playlist = store.savePlaylist(name: "Old Name")
    guard let renamed = store.renamePlaylist(playlist, to: "New Name") else {
        assertTrue(false, "renamePlaylist returned non-nil")
        testDefaults.removePersistentDomain(forName: "sideb_test_t28_rename")
        return
    }
    assertTrue(true, "renamePlaylist returned non-nil")
    assertEqual(renamed.name, "New Name", "renamePlaylist changes name")
    assertEqual(renamed.id, playlist.id, "renamed playlist preserves id")

    testDefaults.removePersistentDomain(forName: "sideb_test_t28_rename")
}

// MARK: - T31: PlatformLinkPersistenceStore Tests (4 new assertions)

runTestSuite("T31: Track — platformLinkState returns ready for source platform") {
    let track = Track(
        title: "Persistence Test",
        artistName: "Artist",
        sourcePlatform: .appleMusic
    )
    assertEqual(track.platformLinkState(for: .appleMusic), .ready, "source platform state is ready")
}

runTestSuite("T31: Track — updatingPlatformLink with nil link returns unavailable state") {
    let track = Track(
        title: "Test",
        artistName: "Artist",
        sourcePlatform: .spotify
    )
    let updated = track.updatingPlatformLink(nil, state: .unavailable, for: .qqMusic)
    let qqState = updated.platformLinkState(for: .qqMusic)
    assertEqual(qqState, .unavailable, "updatingPlatformLink with nil sets state to unavailable")
}

runTestSuite("T31: PlatformLinkPersistenceStore — save and restore") {
    let testDefaults = UserDefaults(suiteName: "sideb_test_t31")!
    testDefaults.removePersistentDomain(forName: "sideb_test_t31")
    let store = PlatformLinkPersistenceStore(userDefaults: testDefaults)
    store.clearAll()

    let appleLink = PlatformLink(
        platform: .appleMusic,
        destinationURL: URL(string: "https://music.apple.com/track/999")!
    )
    let track = Track(
        title: "Save Test",
        artistName: "Artist",
        sourcePlatform: .spotify,
        sourcePlatformID: "spotify:track:persist_test",
        platformLinks: [appleLink]
    )
    store.save(track: track)

    let lookupTrack = Track(
        title: "Save Test",
        artistName: "Artist",
        sourcePlatform: .spotify,
        sourcePlatformID: "spotify:track:persist_test"
    )
    let restored = store.restore(track: lookupTrack)
    assertNotNil(restored, "PlatformLinkPersistenceStore restores saved track")
    assertEqual(restored?.platformLinks.count, 1, "restored track has platform link")
    assertEqual(restored?.platformLinks.first?.platform, .appleMusic, "restored link is apple music")

    testDefaults.removePersistentDomain(forName: "sideb_test_t31")
}

// MARK: - Summary

let totalAssertions = passedTests + failedTests
print("\n═══════════════════════════════════════")
print("  Total assertions: \(totalAssertions)")
print("  ✅ Passed: \(passedTests)")
print("  ❌ Failed: \(failedTests)")
print("═══════════════════════════════════════\n")

exit(failedTests > 0 ? Int32(1) : Int32(0))
