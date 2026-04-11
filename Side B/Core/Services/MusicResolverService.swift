import Foundation

protocol MusicResolverService {
    func resolveTrack(from link: String) -> Track
}

enum MusicPlatform: String, CaseIterable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case qqMusic = "QQ 音乐"
    case neteaseMusic = "网易云音乐"
}

protocol MusicPlatformProvider {
    var platform: MusicPlatform { get }
    func canHandle(link: String) -> Bool
    func resolveTrack(from link: String) -> Track?
}

struct MockMusicResolverService: MusicResolverService {
    private let providers: [any MusicPlatformProvider]

    init(providers: [any MusicPlatformProvider] = MockMusicPlatformProvider.defaultProviders) {
        self.providers = providers
    }

    func resolveTrack(from link: String) -> Track {
        let normalizedLink = link.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        for provider in providers where provider.canHandle(link: normalizedLink) {
            if let resolvedTrack = provider.resolveTrack(from: normalizedLink) {
                return resolvedTrack
            }
        }

        return MockData.tracks[0]
    }
}

struct MockMusicPlatformProvider: MusicPlatformProvider {
    let platform: MusicPlatform
    let matchingKeywords: [String]

    func canHandle(link: String) -> Bool {
        matchingKeywords.contains { link.contains($0) }
    }

    func resolveTrack(from link: String) -> Track? {
        guard canHandle(link: link) else { return nil }
        return MockData.track(for: platform)
    }

    static let defaultProviders: [any MusicPlatformProvider] = [
        MockMusicPlatformProvider(
            platform: .spotify,
            matchingKeywords: ["open.spotify.com", "spotify.link", "spotify:"]
        ),
        MockMusicPlatformProvider(
            platform: .neteaseMusic,
            matchingKeywords: ["music.163.com", "163cn.tv", "netease"]
        ),
        MockMusicPlatformProvider(
            platform: .appleMusic,
            matchingKeywords: ["music.apple.com", "itunes.apple.com"]
        ),
        MockMusicPlatformProvider(
            platform: .qqMusic,
            matchingKeywords: ["y.qq.com", "qqmusic.qq.com", "ryqq"]
        )
    ]
}
