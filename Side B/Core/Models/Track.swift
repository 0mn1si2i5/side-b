import Foundation

struct Track: Identifiable, Hashable {
    let id: UUID
    let title: String
    let artistName: String
    let albumTitle: String?
    let sourcePlatform: MusicPlatform
    let platformLinks: [PlatformLink]
    let artworkURL: URL?

    var sourcePlatformName: String {
        sourcePlatform.displayName
    }

    init(
        id: UUID = UUID(),
        title: String,
        artistName: String,
        albumTitle: String? = nil,
        sourcePlatform: MusicPlatform,
        platformLinks: [PlatformLink] = [],
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.sourcePlatform = sourcePlatform
        self.platformLinks = platformLinks
        self.artworkURL = artworkURL
    }
}
