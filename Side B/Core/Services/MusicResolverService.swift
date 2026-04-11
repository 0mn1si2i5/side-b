import Foundation

protocol MusicResolverService {
    func resolvePayload(from link: String) -> ResolvedTrackPayload
    func resolveTrack(from link: String) -> Track
}

struct ResolvedTrackPayload {
    let track: Track
    let sourcePlatform: MusicPlatform
    let sourceURL: URL?
    let sourceResourceID: String?
    let platformLinks: [PlatformLink]
}

protocol MusicPlatformProvider {
    var platform: MusicPlatform { get }
    func canHandle(link: String) -> Bool
    func extractResourceIdentifier(from link: String) -> String?
    func resolvePayload(from link: String) -> ResolvedTrackPayload?
}

struct MockMusicResolverService: MusicResolverService {
    private let providers: [any MusicPlatformProvider]

    init(providers: [any MusicPlatformProvider] = MockMusicPlatformProvider.defaultProviders) {
        self.providers = providers
    }

    func resolvePayload(from link: String) -> ResolvedTrackPayload {
        let rawLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedLink = rawLink.lowercased()

        for provider in providers where provider.canHandle(link: normalizedLink) {
            if let resolvedPayload = provider.resolvePayload(from: rawLink) {
                return resolvedPayload
            }
        }

        return MockMusicPlatformProvider.fallbackPayload(for: rawLink)
    }

    func resolveTrack(from link: String) -> Track {
        resolvePayload(from: link).track
    }
}

struct MockMusicPlatformProvider: MusicPlatformProvider {
    let platform: MusicPlatform
    let matchingKeywords: [String]
    let resourceIDExtractor: (String) -> String?

    func canHandle(link: String) -> Bool {
        matchingKeywords.contains { link.contains($0) }
    }

    func extractResourceIdentifier(from link: String) -> String? {
        resourceIDExtractor(link)
    }

    func resolvePayload(from link: String) -> ResolvedTrackPayload? {
        guard canHandle(link: link.lowercased()) else { return nil }

        let resourceID = extractResourceIdentifier(from: link)
        let sourceURL = URL(string: link)
        let platformLinks = Self.platformLinks(for: MockData.track(for: platform), sourcePlatform: platform, sourceURL: sourceURL)
        let track = MockData.track(for: platform, platformLinks: platformLinks)

        return ResolvedTrackPayload(
            track: track,
            sourcePlatform: platform,
            sourceURL: sourceURL,
            sourceResourceID: resourceID,
            platformLinks: platformLinks
        )
    }

    static let defaultProviders: [any MusicPlatformProvider] = [
        MockMusicPlatformProvider(
            platform: .spotify,
            matchingKeywords: ["open.spotify.com", "spotify.link", "spotify:"],
            resourceIDExtractor: { link in
                firstMatch(in: link, pattern: #"track[/:]([A-Za-z0-9]+)"#)
            }
        ),
        MockMusicPlatformProvider(
            platform: .neteaseMusic,
            matchingKeywords: ["music.163.com", "163cn.tv", "netease"],
            resourceIDExtractor: { link in
                firstMatch(in: link, pattern: #"[?&]id=(\d+)"#)
            }
        ),
        MockMusicPlatformProvider(
            platform: .appleMusic,
            matchingKeywords: ["music.apple.com", "itunes.apple.com"],
            resourceIDExtractor: { link in
                firstMatch(in: link, pattern: #"(?:song/[^/]+/|i=)(\d+)"#)
            }
        ),
        MockMusicPlatformProvider(
            platform: .qqMusic,
            matchingKeywords: ["y.qq.com", "qqmusic.qq.com", "ryqq", "c6.y.qq.com"],
            resourceIDExtractor: { link in
                firstMatch(in: link, pattern: #"songDetail/([A-Za-z0-9]+)"#)
                    ?? firstMatch(in: link, pattern: #"song/([A-Za-z0-9]+)"#)
            }
        )
    ]

    static func fallbackPayload(for link: String) -> ResolvedTrackPayload {
        let sourceURL = URL(string: link)
        let sourcePlatform = MockData.tracks[0].sourcePlatform
        let platformLinks = platformLinks(for: MockData.tracks[0], sourcePlatform: sourcePlatform, sourceURL: sourceURL)
        let fallbackTrack = MockData.track(for: sourcePlatform, platformLinks: platformLinks)

        return ResolvedTrackPayload(
            track: fallbackTrack,
            sourcePlatform: sourcePlatform,
            sourceURL: sourceURL,
            sourceResourceID: nil,
            platformLinks: platformLinks
        )
    }

    private static func platformLinks(for track: Track, sourcePlatform: MusicPlatform, sourceURL: URL?) -> [PlatformLink] {
        let navigationService = MockPlatformNavigationService()

        return MusicPlatform.allCases.compactMap { platform in
            let destinationURL: URL?

            if platform == sourcePlatform, let sourceURL {
                destinationURL = sourceURL
            } else {
                destinationURL = navigationService.destinationURL(for: platform, track: track)
            }

            guard let destinationURL else { return nil }

            return PlatformLink(
                platform: platform,
                destinationURL: destinationURL,
                isSource: platform == sourcePlatform
            )
        }
    }

    private static func firstMatch(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else {
            return nil
        }

        guard let captureRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captureRange])
    }
}
