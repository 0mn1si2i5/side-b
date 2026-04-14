import Foundation

enum ResolverResourceKind: String {
    case track
}

struct ResolverRequest {
    let rawLink: String
    let preferredSourcePlatform: MusicPlatform?
    let preferredMarket: String?

    init(
        rawLink: String,
        preferredSourcePlatform: MusicPlatform? = nil,
        preferredMarket: String? = nil
    ) {
        self.rawLink = rawLink
        self.preferredSourcePlatform = preferredSourcePlatform
        self.preferredMarket = preferredMarket
    }
}

extension MusicPlatform {
    init?(resolverWireValue: String) {
        self.init(rawValue: resolverWireValue)
    }

    var resolverWireValue: String {
        rawValue
    }
}

struct ParsedMusicLink {
    let originalLink: String
    let normalizedLink: String
    let platform: MusicPlatform
    let sourceURL: URL?
    let resourceID: String?
    let resourceKind: ResolverResourceKind
}

struct ResolverTrackDTO {
    let title: String
    let artistName: String
    let albumTitle: String?
    let durationMS: Int?
    let artworkURL: URL?
    let sourcePlatform: MusicPlatform
    let sourcePlatformID: String?
    let sourceURL: URL?
    let isrc: String?

    func asTrack(platformLinks: [PlatformLink]) -> Track {
        Track(
            title: title,
            artistName: artistName,
            albumTitle: albumTitle,
            durationMS: durationMS,
            sourcePlatform: sourcePlatform,
            sourcePlatformID: sourcePlatformID,
            sourceURL: sourceURL,
            isrc: isrc,
            platformLinks: platformLinks,
            artworkURL: artworkURL
        )
    }
}

enum LinkParsingResult {
    case parsed(ParsedMusicLink)
    case unsupportedLink(rawLink: String)
    case missingResourceID(partialLink: ParsedMusicLink)
}

struct ResolvedTrackPayload {
    let track: Track
    let sourcePlatform: MusicPlatform
    let sourceURL: URL?
    let sourceResourceID: String?
    let platformLinks: [PlatformLink]
}

struct ResolverResponse {
    let resolvedTrack: ResolvedTrackPayload
    let parsingResult: LinkParsingResult
    let metadataStatus: MetadataFetchStatus
    let resolverVersion: String
    let resolutionSource: ResolverResponseSource
    let diagnosticMessage: String?
}

struct PlatformLinksResolutionResponse {
    let platformLinks: [PlatformLink]
    let status: PlatformLinksStatus
    let resolverVersion: String
    let diagnosticMessage: String?
}

struct SinglePlatformLinkResolutionResponse {
    let platform: MusicPlatform
    let platformLink: PlatformLink?
    let state: PlatformLinkLoadState
    let resolverVersion: String
    let diagnosticMessage: String?
}

enum ResolverResponseSource {
    case remote
    case fallbackMock
    case mockLocal
}

enum ResolverClientError: Error {
    case invalidBaseURL
    case invalidHTTPResponse
    case unsuccessfulStatusCode(Int)
    case transportFailed
    case malformedPayload
}

enum MetadataFetchStatus {
    case success
    case fallbackMock
}

struct TrackMetadataResult {
    let track: ResolverTrackDTO
    let status: MetadataFetchStatus
    let providerResourceID: String?
    let providerDebugSummary: String?
}

protocol MusicLinkParser {
    var platform: MusicPlatform { get }
    func canHandle(link: String) -> Bool
    func parse(link: String) -> LinkParsingResult?
}

protocol TrackMetadataProvider {
    var platform: MusicPlatform { get }
    func fetchTrackMetadata(for parsedLink: ParsedMusicLink) -> TrackMetadataResult?
}

protocol MockPlatformTrackBuilding {
    var platform: MusicPlatform { get }
}

extension MockPlatformTrackBuilding {
    func buildMockTrackResult(for parsedLink: ParsedMusicLink) -> TrackMetadataResult? {
        guard parsedLink.platform == platform else { return nil }
        let baseTrack = MockData.track(for: platform)

        return TrackMetadataResult(
            track: ResolverTrackDTO(
                title: baseTrack.title,
                artistName: baseTrack.artistName,
                albumTitle: baseTrack.albumTitle,
                durationMS: baseTrack.durationMS,
                artworkURL: baseTrack.artworkURL,
                sourcePlatform: baseTrack.sourcePlatform,
                sourcePlatformID: parsedLink.resourceID ?? baseTrack.sourcePlatformID,
                sourceURL: parsedLink.sourceURL ?? baseTrack.sourceURL,
                isrc: baseTrack.isrc
            ),
            status: .success,
            providerResourceID: parsedLink.resourceID,
            providerDebugSummary: "Mock metadata fetched for \(platform.displayName)"
        )
    }
}

struct SpotifyTrackCatalogItem {
    let id: String
    let title: String
    let artistName: String
    let albumTitle: String?
    let durationMS: Int?
    let artworkURL: URL?
    let externalURL: URL?
    let isrc: String?
}

struct SpotifyCatalogRequest {
    let trackID: String
    let market: String?
    let accessToken: String?
}

struct SpotifyTrackCatalogResponse {
    let id: String
    let name: String
    let artistNames: [String]
    let albumName: String?
    let durationMS: Int?
    let artworkURL: URL?
    let externalURL: URL?
    let isrc: String?
}

protocol SpotifyAccessTokenProviding {
    func accessToken() -> String?
}

protocol SpotifyCatalogFetching {
    func fetchTrackResponse(request: SpotifyCatalogRequest) -> SpotifyTrackCatalogResponse?
}

protocol SpotifyTrackCatalogProviding {
    func fetchTrack(request: SpotifyCatalogRequest) -> SpotifyTrackCatalogItem?
}

protocol ResolverAPIClient {
    func resolve(request: ResolverRequest) async throws -> ResolverResponse
    func resolveMetadata(request: ResolverRequest) async throws -> ResolverResponse
    func resolvePlatformLinks(for track: Track) async throws -> PlatformLinksResolutionResponse
    func resolvePlatformLink(for track: Track, targetPlatform: MusicPlatform) async throws -> SinglePlatformLinkResolutionResponse
}

protocol ResolverTransporting {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct ResolverHTTPConfiguration {
    let baseURL: URL
    let timeoutInterval: TimeInterval

    init(baseURL: URL, timeoutInterval: TimeInterval = 20) {
        self.baseURL = baseURL
        self.timeoutInterval = timeoutInterval
    }
}

extension ResolverResponse {
    func withPlatformLinksStatus(_ status: PlatformLinksStatus) -> ResolverResponse {
        let updatedTrack = status == .idle
            ? resolvedTrack.track.markingDeferredPlatformLinksIdle()
            : resolvedTrack.track.updatingPlatformLinks(resolvedTrack.platformLinks, status: status)
        let updatedPayload = ResolvedTrackPayload(
            track: updatedTrack,
            sourcePlatform: resolvedTrack.sourcePlatform,
            sourceURL: resolvedTrack.sourceURL,
            sourceResourceID: resolvedTrack.sourceResourceID,
            platformLinks: resolvedTrack.platformLinks
        )

        return ResolverResponse(
            resolvedTrack: updatedPayload,
            parsingResult: parsingResult,
            metadataStatus: metadataStatus,
            resolverVersion: resolverVersion,
            resolutionSource: resolutionSource,
            diagnosticMessage: diagnosticMessage
        )
    }
}