import Foundation

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

struct PlaylistTrackEntry: Identifiable, Hashable, Codable {
    let id: UUID
    let trackID: String
    let addedAt: Date

    init(
        id: UUID = UUID(),
        trackID: String,
        addedAt: Date = Date()
    ) {
        self.id = id
        self.trackID = trackID
        self.addedAt = addedAt
    }

    func copy(
        trackID: String? = nil,
        addedAt: Date? = nil
    ) -> PlaylistTrackEntry {
        PlaylistTrackEntry(
            id: id,
            trackID: trackID ?? self.trackID,
            addedAt: addedAt ?? self.addedAt
        )
    }
}
