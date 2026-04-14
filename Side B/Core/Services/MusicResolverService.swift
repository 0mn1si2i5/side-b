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
    private static let environmentBaseURLKey = "SIDEB_RESOLVER_BASE_URL"

    static func makeDefaultService() -> any MusicResolverService {
        guard
            let baseURLString = ProcessInfo.processInfo.environment[environmentBaseURLKey],
            let baseURL = URL(string: baseURLString)
        else {
            return MockMusicResolverService()
        }

        let configuration = ResolverHTTPConfiguration(baseURL: baseURL)
        let apiClient = ResolverHTTPAPIClient(configuration: configuration)
        return RemoteMusicResolverService(
            apiClient: apiClient,
            fallbackService: MockMusicResolverService()
        )
    }
}