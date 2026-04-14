import Foundation

struct EmojiReaction: Identifiable, Hashable, Codable {
    let id: UUID
    let messageId: UUID
    let userId: UUID
    let emoji: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        messageId: UUID,
        userId: UUID,
        emoji: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.messageId = messageId
        self.userId = userId
        self.emoji = emoji
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case messageId = "message_id"
        case userId = "user_id"
        case emoji
        case createdAt = "created_at"
    }
}
