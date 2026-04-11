import Foundation

struct Message: Identifiable, Hashable {
    let id: UUID
    let senderName: String
    let text: String?
    let track: Track?
    let sentAt: Date

    init(
        id: UUID = UUID(),
        senderName: String,
        text: String? = nil,
        track: Track? = nil,
        sentAt: Date
    ) {
        self.id = id
        self.senderName = senderName
        self.text = text
        self.track = track
        self.sentAt = sentAt
    }
}

