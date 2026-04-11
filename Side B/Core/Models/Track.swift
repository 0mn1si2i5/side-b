import Foundation

struct Track: Identifiable, Hashable {
    let id: UUID
    let title: String
    let artistName: String
    let albumTitle: String?
    let sourcePlatformName: String
    let artworkURL: URL?

    init(
        id: UUID = UUID(),
        title: String,
        artistName: String,
        albumTitle: String? = nil,
        sourcePlatformName: String,
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.artistName = artistName
        self.albumTitle = albumTitle
        self.sourcePlatformName = sourcePlatformName
        self.artworkURL = artworkURL
    }
}
