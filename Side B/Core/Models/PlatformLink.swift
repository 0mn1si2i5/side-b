import Foundation

struct PlatformLink: Identifiable, Hashable {
    let id: UUID
    let platformName: String
    let destinationURL: URL
    let isSource: Bool

    init(
        id: UUID = UUID(),
        platformName: String,
        destinationURL: URL,
        isSource: Bool = false
    ) {
        self.id = id
        self.platformName = platformName
        self.destinationURL = destinationURL
        self.isSource = isSource
    }
}

