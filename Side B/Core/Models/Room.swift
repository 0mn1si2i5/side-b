import Foundation

struct Room: Identifiable, Hashable {
    let id: UUID
    let name: String
    let latestTrack: Track?
    let latestMessagePreview: String?

    init(
        id: UUID = UUID(),
        name: String,
        latestTrack: Track? = nil,
        latestMessagePreview: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latestTrack = latestTrack
        self.latestMessagePreview = latestMessagePreview
    }
}
