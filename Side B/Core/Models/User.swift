import Foundation

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