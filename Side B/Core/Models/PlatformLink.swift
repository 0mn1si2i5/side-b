import Foundation

struct PlatformLink: Identifiable, Hashable {
    let id: UUID
    let platform: MusicPlatform
    let destinationURL: URL
    let isSource: Bool

    var platformName: String {
        platform.displayName
    }

    init(
        id: UUID = UUID(),
        platform: MusicPlatform,
        destinationURL: URL,
        isSource: Bool = false
    ) {
        self.id = id
        self.platform = platform
        self.destinationURL = destinationURL
        self.isSource = isSource
    }
}
