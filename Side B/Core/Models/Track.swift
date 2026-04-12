import Foundation

struct Track: Identifiable, Hashable {
    let id: UUID
    let title: String
    let artistName: String
    let albumTitle: String?
    let durationMS: Int?
    let sourcePlatform: MusicPlatform
    let sourcePlatformID: String?
    let sourceURL: URL?
    let isrc: String?
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
        durationMS: Int? = nil,
        sourcePlatform: MusicPlatform,
        sourcePlatformID: String? = nil,
        sourceURL: URL? = nil,
        isrc: String? = nil,
        platformLinks: [PlatformLink] = [],
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.durationMS = durationMS
        self.sourcePlatform = sourcePlatform
        self.sourcePlatformID = sourcePlatformID
        self.sourceURL = sourceURL
        self.isrc = isrc
        self.platformLinks = platformLinks
        self.artworkURL = artworkURL
    }
}
