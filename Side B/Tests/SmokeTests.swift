import Foundation

// MARK: - Test Harness

var testsPassed = 0
var testsFailed = 0

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if condition {
        testsPassed += 1
        print("  ✅ PASS: \(message)")
    } else {
        testsFailed += 1
        print("  ❌ FAIL: \(message) [\(file):\(line)]")
    }
}

// MARK: - Track Tests

func testTrackUpdatingPlatformLinksPreservesId() {
    let originalId = UUID()
    let track = Track(
        id: originalId,
        title: "Test Song",
        artistName: "Test Artist",
        sourcePlatform: .spotify,
        sourcePlatformID: "spotify:track:abc123"
    )
    let newLinks = [
        PlatformLink(platform: .appleMusic, destinationURL: URL(string: "https://music.apple.com/song/1")!),
        PlatformLink(platform: .spotify, destinationURL: URL(string: "https://open.spotify.com/track/abc123")!, isSource: true)
    ]
    let updated = track.updatingPlatformLinks(newLinks, status: .loaded)
    assert(updated.id == originalId, "updatingPlatformLinks preserves track id")
    assert(updated.platformLinks.count == 2, "updatingPlatformLinks sets platformLinks count")
    assert(updated.platformLinksStatus == .loaded, "updatingPlatformLinks sets status to loaded")
}

func testTrackPlatformLinkStateReturnsCorrectState() {
    let track = Track(
        title: "Test Song",
        artistName: "Test Artist",
        sourcePlatform: .spotify,
        sourcePlatformID: "spotify:track:abc123",
        platformLinks: [
            PlatformLink(platform: .spotify, destinationURL: URL(string: "https://open.spotify.com/track/abc123")!, isSource: true)
        ]
    )
    assert(track.platformLinkState(for: .spotify) == .ready, "platformLinkState returns .ready for source platform")
    assert(track.platformLinkState(for: .appleMusic) == .unavailable, "platformLinkState returns .unavailable for missing platform")
    assert(track.platformLinkState(for: .qqMusic) == .unavailable, "platformLinkState returns .unavailable for QQ Music")
}

func testTrackPersistenceIdentityIsStable() {
    let id1 = UUID()
    let id2 = UUID()
    let track1 = Track(
        id: id1,
        title: "Song A",
        artistName: "Artist A",
        sourcePlatform: .spotify,
        sourcePlatformID: "spotify:track:xyz789"
    )
    let track2 = Track(
        id: id2,
        title: "Song B",
        artistName: "Artist B",
        sourcePlatform: .spotify,
        sourcePlatformID: "spotify:track:xyz789"
    )
    assert(track1.persistenceIdentity == track2.persistenceIdentity, "persistenceIdentity is stable for same sourcePlatform + sourcePlatformID")
    assert(track1.persistenceIdentity == "Spotify::spotify:track:xyz789", "persistenceIdentity format is platform::id")

    let track3 = Track(
        title: "Song C",
        artistName: "Artist C",
        sourcePlatform: .appleMusic,
        sourcePlatformID: "apple:track:different"
    )
    assert(track1.persistenceIdentity != track3.persistenceIdentity, "persistenceIdentity differs for different sourcePlatformID")
}

// MARK: - Message / Room Tests

func testMessageUpdatingTrackPreservesIdAndSenderName() {
    let originalId = UUID()
    let message = Message(
        id: originalId,
        senderName: "Alice",
        contentType: .song,
        track: Track(title: "Old Song", artistName: "Old Artist", sourcePlatform: .spotify),
        sentAt: Date()
    )
    let newTrack = Track(title: "New Song", artistName: "New Artist", sourcePlatform: .appleMusic)
    let updated = message.updatingTrack(newTrack)
    assert(updated.id == originalId, "updatingTrack preserves message id")
    assert(updated.senderName == "Alice", "updatingTrack preserves senderName")
    assert(updated.track?.title == "New Song", "updatingTrack updates track")
    assert(updated.contentType == .song, "updatingTrack preserves contentType")
}

func testRoomTypeEnumValues() {
    assert(RoomType.direct.rawValue == "direct", "RoomType.direct rawValue is 'direct'")
    assert(RoomType.group.rawValue == "group", "RoomType.group rawValue is 'group'")
}

func testRoomInitWithDefaultValues() {
    let room = Room(name: "Test Room")
    assert(room.type == .group, "Room type defaults to .group")
    assert(room.isActive == true, "Room isActive defaults to true")
    assert(room.name == "Test Room", "Room name is set correctly")
    assert(room.memberIDs.isEmpty, "Room memberIDs defaults to empty")
    assert(room.latestTrack == nil, "Room latestTrack defaults to nil")
}

// MARK: - PlaylistStore Tests

func testPlaylistStoreSaveAndLoadRoundTrip() {
    let testDefaults = UserDefaults(suiteName: "SideBTests")!
    testDefaults.removePersistentDomain(forName: "SideBTests")

    let store = PlaylistStore(userDefaults: testDefaults)
    let playlist = store.savePlaylist(name: "My Playlist")
    let loaded = store.loadPlaylists()

    let matchingPlaylist = loaded.first(where: { $0.id == playlist.id })
    assert(matchingPlaylist != nil, "Saved playlist appears in loadPlaylists")
    assert(matchingPlaylist?.name == "My Playlist", "Loaded playlist name matches")
}

func testPlaylistStoreAddAndRemoveTrack() {
    let testDefaults = UserDefaults(suiteName: "SideBTests")!
    testDefaults.removePersistentDomain(forName: "SideBTests")

    let store = PlaylistStore(userDefaults: testDefaults)
    let playlist = store.savePlaylist(name: "AddRemove Test")

    let trackId = "Spotify::spotify:track:test123"
    let added = store.addTrack(trackId, to: playlist)
    assert(added == true, "addTrack returns true for new track")

    let entries = store.getTrackEntries(for: playlist)
    assert(entries.count == 1, "Playlist has 1 track entry after add")
    assert(entries.first?.trackID == trackId, "Track entry has correct trackID")

    let addedAgain = store.addTrack(trackId, to: playlist)
    assert(addedAgain == false, "addTrack returns false for duplicate track")

    let removed = store.removeTrack(entries.first!, from: playlist)
    assert(removed == true, "removeTrack returns true")

    let entriesAfterRemove = store.getTrackEntries(for: playlist)
    assert(entriesAfterRemove.isEmpty, "Playlist is empty after remove")
}

func testPlaylistStoreRenamePlaylist() {
    let testDefaults = UserDefaults(suiteName: "SideBTests")!
    testDefaults.removePersistentDomain(forName: "SideBTests")

    let store = PlaylistStore(userDefaults: testDefaults)
    let playlist = store.savePlaylist(name: "Original Name")

    let renamed = store.renamePlaylist(playlist, to: "New Name")
    assert(renamed != nil, "renamePlaylist returns non-nil")
    assert(renamed?.name == "New Name", "Renamed playlist has new name")
    assert(renamed?.id == playlist.id, "Renamed playlist preserves id")

    let loaded = store.loadPlaylists()
    let loadedPlaylist = loaded.first(where: { $0.id == playlist.id })
    assert(loadedPlaylist?.name == "New Name", "Renamed playlist persists after load")
}

// When included in Xcode, this conflicts with SideBApp's @main.
// Use: swiftc -o /tmp/sideb_tests "Side B/Tests/SmokeTests.swift" ... to compile standalone.
// Or exclude this file from the Xcode build target.

// MARK: - Run All Tests

struct SmokeTestRunner {
    static func main() {
        print("=== Side B Smoke Tests ===\n")

        print("Track Tests:")
        testTrackUpdatingPlatformLinksPreservesId()
        testTrackPlatformLinkStateReturnsCorrectState()
        testTrackPersistenceIdentityIsStable()

        print("\nMessage/Room Tests:")
        testMessageUpdatingTrackPreservesIdAndSenderName()
        testRoomTypeEnumValues()
        testRoomInitWithDefaultValues()

        print("\nPlaylistStore Tests:")
        testPlaylistStoreSaveAndLoadRoundTrip()
        testPlaylistStoreAddAndRemoveTrack()
        testPlaylistStoreRenamePlaylist()

        print("\n=== Results: \(testsPassed) passed, \(testsFailed) failed ===")

        if testsFailed > 0 {
            exit(1)
        }
    }
}