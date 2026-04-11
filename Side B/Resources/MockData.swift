import Foundation

enum MockData {
    static let tracks: [Track] = [
        Track(
            title: "Nights",
            artistName: "Frank Ocean",
            albumTitle: "Blonde",
            sourcePlatform: .spotify,
            platformLinks: defaultPlatformLinks(for: .spotify),
            artworkURL: URL(string: "https://example.com/artwork/nights.jpg")
        ),
        Track(
            title: "想去海边",
            artistName: "夏日入侵企画",
            albumTitle: "想去海边",
            sourcePlatform: .neteaseMusic,
            platformLinks: defaultPlatformLinks(for: .neteaseMusic),
            artworkURL: URL(string: "https://example.com/artwork/beach.jpg")
        ),
        Track(
            title: "After Hours",
            artistName: "The Weeknd",
            albumTitle: "After Hours",
            sourcePlatform: .appleMusic,
            platformLinks: defaultPlatformLinks(for: .appleMusic),
            artworkURL: URL(string: "https://example.com/artwork/after-hours.jpg")
        )
    ]

    static let tracksByPlatform: [MusicPlatform: Track] = [
        .spotify: tracks[0],
        .neteaseMusic: tracks[1],
        .appleMusic: tracks[2],
        .qqMusic: Track(
            title: tracks[1].title,
            artistName: tracks[1].artistName,
            albumTitle: tracks[1].albumTitle,
            sourcePlatform: .qqMusic,
            platformLinks: defaultPlatformLinks(for: .qqMusic),
            artworkURL: tracks[1].artworkURL
        )
    ]

    static let platformLinks: [PlatformLink] = [
        PlatformLink(
            platform: .spotify,
            destinationURL: URL(string: "https://open.spotify.com/track/mock-nights")!,
            isSource: true
        ),
        PlatformLink(
            platform: .neteaseMusic,
            destinationURL: URL(string: "https://music.163.com/song?id=mock-beach")!
        ),
        PlatformLink(
            platform: .appleMusic,
            destinationURL: URL(string: "https://music.apple.com/song/mock-after-hours")!
        )
    ]

    static let messages: [Message] = [
        Message(
            senderName: "Mia",
            text: "这首适合凌晨听",
            track: tracks[0],
            sentAt: Date(timeIntervalSince1970: 1_712_000_000)
        ),
        Message(
            senderName: "Leo",
            text: "副歌一出来就上头了",
            track: tracks[1],
            sentAt: Date(timeIntervalSince1970: 1_712_086_400)
        ),
        Message(
            senderName: "Noah",
            text: "这版制作很满，适合耳机",
            track: tracks[2],
            sentAt: Date(timeIntervalSince1970: 1_712_172_800)
        )
    ]

    static let rooms: [Room] = [
        Room(
            name: "Late Night Loop",
            latestTrack: tracks[0],
            latestMessagePreview: messages[0].text
        ),
        Room(
            name: "Side B Club",
            latestTrack: tracks[1],
            latestMessagePreview: messages[1].text
        ),
        Room(
            name: "Daily Finds",
            latestTrack: tracks[2],
            latestMessagePreview: messages[2].text
        )
    ]

    static func track(for platform: MusicPlatform, platformLinks: [PlatformLink] = []) -> Track {
        let baseTrack = tracksByPlatform[platform] ?? tracks[0]
        let resolvedPlatformLinks = platformLinks.isEmpty ? baseTrack.platformLinks : platformLinks

        return Track(
            id: baseTrack.id,
            title: baseTrack.title,
            artistName: baseTrack.artistName,
            albumTitle: baseTrack.albumTitle,
            sourcePlatform: baseTrack.sourcePlatform,
            platformLinks: resolvedPlatformLinks,
            artworkURL: baseTrack.artworkURL
        )
    }

    private static func defaultPlatformLinks(for sourcePlatform: MusicPlatform) -> [PlatformLink] {
        let destinations: [MusicPlatform: URL] = [
            .spotify: URL(string: "https://open.spotify.com/track/mock-nights")!,
            .appleMusic: URL(string: "https://music.apple.com/song/mock-after-hours")!,
            .neteaseMusic: URL(string: "https://music.163.com/song?id=mock-beach")!,
            .qqMusic: URL(string: "https://y.qq.com/n/ryqq/songDetail/004O1DHG4MjYOi")!
        ]

        return MusicPlatform.allCases.compactMap { platform in
            guard let destinationURL = destinations[platform] else { return nil }

            return PlatformLink(
                platform: platform,
                destinationURL: destinationURL,
                isSource: platform == sourcePlatform
            )
        }
    }
}
