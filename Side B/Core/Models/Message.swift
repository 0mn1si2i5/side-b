import Foundation

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

    func updatingTrack(_ track: Track?) -> Message {
        Message(
            id: id,
            senderName: senderName,
            senderID: senderID,
            contentType: contentType,
            text: text,
            track: track,
            replyToMessageID: replyToMessageID,
            sentAt: sentAt,
            emojiReactions: emojiReactions
        )
    }
}
