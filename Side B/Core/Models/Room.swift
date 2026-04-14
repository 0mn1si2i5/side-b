import Foundation

enum RoomType: String, Codable, Hashable {
    case direct = "direct"
    case group = "group"
}

struct Room: Identifiable, Hashable {
    let id: UUID
    let name: String
    let type: RoomType
    let memberIDs: [UUID]
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
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.isActive = isActive
        self.latestTrack = latestTrack
        self.latestMessagePreview = latestMessagePreview
    }
}
