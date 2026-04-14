import Foundation

protocol MusicResolverService {
    func resolve(request: ResolverRequest) async throws -> ResolverResponse
    func resolveMetadata(request: ResolverRequest) async throws -> ResolverResponse
    func resolvePlatformLinks(for track: Track) async throws -> PlatformLinksResolutionResponse
    func resolvePlatformLink(for track: Track, targetPlatform: MusicPlatform) async throws -> SinglePlatformLinkResolutionResponse
    func resolvePayload(from link: String) async throws -> ResolvedTrackPayload
    func resolveTrack(from link: String) async throws -> Track
}

enum ResolverServiceFactory {
    private static let apiBaseURLKey = "SIDEB_API_BASE_URL"
    private static let legacyResolverURLKey = "SIDEB_RESOLVER_BASE_URL"

    static func makeDefaultService() -> any MusicResolverService {
        let baseURL = resolverBaseURL

        guard let baseURL else {
            return MockMusicResolverService()
        }

        let configuration = ResolverHTTPConfiguration(baseURL: baseURL)
        let apiClient = ResolverHTTPAPIClient(configuration: configuration)
        return RemoteMusicResolverService(
            apiClient: apiClient,
            fallbackService: MockMusicResolverService()
        )
    }

    // SIDEB_API_BASE_URL routes are at /api/resolve, so /api must be appended.
    // SIDEB_RESOLVER_BASE_URL routes are at /resolve directly (no prefix needed).
    private static var resolverBaseURL: URL? {
        let env = ProcessInfo.processInfo.environment

        if let apiBase = env[apiBaseURLKey], let url = URL(string: apiBase) {
            return url.appendingPathComponent("api")
        }

        if let legacyBase = env[legacyResolverURLKey], let url = URL(string: legacyBase) {
            return url
        }

        return nil
    }
}