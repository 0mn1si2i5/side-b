import Foundation

enum MockData {
    private static let realSourceURLs: [MusicPlatform: URL] = [
        .spotify: URL(string: "https://open.spotify.com/track/6qxvy9Pe4RJIq5JBVbbwbS?si=A8pcxUVOSAydRfDBx_IONw")!,
        .appleMusic: URL(string: "https://music.apple.com/cn/album/maroon/1689131527?i=1689131532")!,
        .qqMusic: URL(string: "https://c6.y.qq.com/base/fcgi-bin/u?__=ctDFhEfIaJUS")!,
        .neteaseMusic: URL(string: "https://163cn.tv/4XYD10p")!
    ]

    static let tracks: [Track] = [
        Track(
            title: "Maroon",
            artistName: "Taylor Swift",
            albumTitle: "Midnights (The Til Dawn Edition)",
            durationMS: 218_270,
            sourcePlatform: .spotify,
            sourcePlatformID: "6qxvy9Pe4RJIq5JBVbbwbS",
            sourceURL: realSourceURLs[.spotify]!,
            isrc: "USUG12306678",
            platformLinks: defaultPlatformLinks(for: .spotify),
            artworkURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/44/1f/b7/441fb7c1-1005-4d0b-85d2-6890af9bf7fb/23UMGIM63834.rgb.jpg/1200x1200bb.jpg")
        ),
        Track(
            title: "Maroon",
            artistName: "Taylor Swift",
            albumTitle: "Midnights (The Til Dawn Edition)",
            durationMS: 218_270,
            sourcePlatform: .neteaseMusic,
            sourcePlatformID: "2049512695",
            sourceURL: realSourceURLs[.neteaseMusic]!,
            isrc: "USUG12306678",
            platformLinks: defaultPlatformLinks(for: .neteaseMusic),
            artworkURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/44/1f/b7/441fb7c1-1005-4d0b-85d2-6890af9bf7fb/23UMGIM63834.rgb.jpg/1200x1200bb.jpg")
        ),
        Track(
            title: "Maroon",
            artistName: "Taylor Swift",
            albumTitle: "Midnights (The Til Dawn Edition)",
            durationMS: 218_270,
            sourcePlatform: .appleMusic,
            sourcePlatformID: "1689131532",
            sourceURL: realSourceURLs[.appleMusic]!,
            isrc: "USUG12306678",
            platformLinks: defaultPlatformLinks(for: .appleMusic),
            artworkURL: URL(string: "https://is1-ssl.mzstatic.com/image/thumb/Music126/v4/44/1f/b7/441fb7c1-1005-4d0b-85d2-6890af9bf7fb/23UMGIM63834.rgb.jpg/1200x1200bb.jpg")
        )
    ]

    static let tracksByPlatform: [MusicPlatform: Track] = [
        .spotify: tracks[0],
        .neteaseMusic: tracks[1],
        .appleMusic: tracks[2],
        .qqMusic: Track(
            title: tracks[0].title,
            artistName: tracks[0].artistName,
            albumTitle: tracks[0].albumTitle,
            durationMS: tracks[0].durationMS,
            sourcePlatform: .qqMusic,
            sourcePlatformID: "003OUlho2HcRHC",
            sourceURL: realSourceURLs[.qqMusic]!,
            isrc: tracks[0].isrc,
            platformLinks: defaultPlatformLinks(for: .qqMusic),
            artworkURL: tracks[0].artworkURL
        )
    ]

    static let platformLinks: [PlatformLink] = [
        PlatformLink(
            platform: .spotify,
            destinationURL: realSourceURLs[.spotify]!,
            isSource: true
        ),
        PlatformLink(
            platform: .neteaseMusic,
            destinationURL: realSourceURLs[.neteaseMusic]!
        ),
        PlatformLink(
            platform: .appleMusic,
            destinationURL: realSourceURLs[.appleMusic]!
        ),
        PlatformLink(
            platform: .qqMusic,
            destinationURL: realSourceURLs[.qqMusic]!
        )
    ]

    static let messages: [Message] = [
        Message(
            senderName: "Mia",
            text: "这首的颜色感太强了",
            track: tracks[0],
            sentAt: Date(timeIntervalSince1970: 1_712_000_000)
        ),
        Message(
            senderName: "Leo",
            text: "我最近一直单曲循环这首",
            track: tracks[1],
            sentAt: Date(timeIntervalSince1970: 1_712_086_400)
        ),
        Message(
            senderName: "Noah",
            text: "这张专辑里我最先回放的就是它",
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
            durationMS: baseTrack.durationMS,
            sourcePlatform: baseTrack.sourcePlatform,
            sourcePlatformID: baseTrack.sourcePlatformID,
            sourceURL: baseTrack.sourceURL,
            isrc: baseTrack.isrc,
            platformLinks: resolvedPlatformLinks,
            artworkURL: baseTrack.artworkURL
        )
    }

    private static func defaultPlatformLinks(for sourcePlatform: MusicPlatform) -> [PlatformLink] {
        let destinations: [MusicPlatform: URL] = [
            .spotify: realSourceURLs[.spotify]!,
            .appleMusic: realSourceURLs[.appleMusic]!,
            .neteaseMusic: realSourceURLs[.neteaseMusic]!,
            .qqMusic: realSourceURLs[.qqMusic]!
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
