import Foundation

protocol MusicResolverService {
    func resolve(request: ResolverRequest) -> ResolverResponse
    func resolveMetadata(request: ResolverRequest) -> ResolverResponse
    func resolvePlatformLinks(for track: Track) -> PlatformLinksResolutionResponse
    func resolvePlatformLink(for track: Track, targetPlatform: MusicPlatform) -> SinglePlatformLinkResolutionResponse
    func resolvePayload(from link: String) -> ResolvedTrackPayload
    func resolveTrack(from link: String) -> Track
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