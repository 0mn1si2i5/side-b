import Foundation
import os

protocol MusicResolverService {
    func resolve(request: ResolverRequest) async throws -> ResolverResponse
    func resolveMetadata(request: ResolverRequest) async throws -> ResolverResponse
    func resolvePlatformLinks(for track: Track) async throws -> PlatformLinksResolutionResponse
    func resolvePlatformLink(for track: Track, targetPlatform: MusicPlatform) async throws -> SinglePlatformLinkResolutionResponse
    func resolvePayload(from link: String) async throws -> ResolvedTrackPayload
    func resolveTrack(from link: String) async throws -> Track
}

enum ResolverServiceFactory {
    private static let logger = Logger(subsystem: "com.sideb.app", category: "ServiceFactory")
    private static let apiBaseURLKey = "SIDEB_API_BASE_URL"
    private static let legacyResolverURLKey = "SIDEB_RESOLVER_BASE_URL"
    private static let userDefaultsKey = "SideB_ResolverBaseURL"

    /// Programmatically override the resolver base URL (e.g., from AppDelegate or Settings).
    /// Takes precedence over environment variables and UserDefaults.
    static var configuredBaseURL: URL?

    /// Whether the resolver has a valid base URL configured.
    static var isConfigured: Bool {
        resolverBaseURL != nil
    }

    static func makeDefaultService() -> (any MusicResolverService)? {
        let baseURL = resolverBaseURL

        guard let baseURL else {
            #if DEBUG
            return MockMusicResolverService()
            #else
            logger.error("ResolverServiceFactory: No resolver base URL configured. Set SIDEB_API_BASE_URL or SIDEB_RESOLVER_BASE_URL.")
            return nil
            #endif
        }

        let configuration = ResolverHTTPConfiguration(baseURL: baseURL)
        let apiClient = ResolverHTTPAPIClient(configuration: configuration)
        #if DEBUG
        return RemoteMusicResolverService(
            apiClient: apiClient,
            fallbackService: MockMusicResolverService()
        )
        #else
        return RemoteMusicResolverService(
            apiClient: apiClient,
            fallbackService: nil
        )
        #endif
    }

    /// Save a base URL to UserDefaults for production use without Xcode env vars.
    static func persistBaseURL(_ url: URL) {
        UserDefaults.standard.set(url.absoluteString, forKey: userDefaultsKey)
    }

    // SIDEB_API_BASE_URL routes are at /api/resolve, so /api must be appended.
    // SIDEB_RESOLVER_BASE_URL routes are at /resolve directly (no prefix needed).
    private static var resolverBaseURL: URL? {
        if let configured = configuredBaseURL {
            return configured
        }

        let env = ProcessInfo.processInfo.environment

        if let apiBase = env[apiBaseURLKey], let url = URL(string: apiBase) {
            return url.appendingPathComponent("api")
        }

        if let legacyBase = env[legacyResolverURLKey], let url = URL(string: legacyBase) {
            return url
        }

        if let saved = UserDefaults.standard.string(forKey: userDefaultsKey),
           let url = URL(string: saved) {
            return url
        }

        return nil
    }
}