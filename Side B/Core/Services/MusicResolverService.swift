import Foundation

protocol MusicResolverService {
    func resolve(request: ResolverRequest) -> ResolverResponse
    func resolveMetadata(request: ResolverRequest) -> ResolverResponse
    func resolvePlatformLinks(for track: Track) -> PlatformLinksResolutionResponse
    func resolvePlatformLink(for track: Track, targetPlatform: MusicPlatform) -> SinglePlatformLinkResolutionResponse
    func resolvePayload(from link: String) -> ResolvedTrackPayload
    func resolveTrack(from link: String) -> Track
}

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
    func resolve(request: ResolverRequest) throws -> ResolverResponse
    func resolveMetadata(request: ResolverRequest) throws -> ResolverResponse
    func resolvePlatformLinks(for track: Track) throws -> PlatformLinksResolutionResponse
    func resolvePlatformLink(for track: Track, targetPlatform: MusicPlatform) throws -> SinglePlatformLinkResolutionResponse
}

protocol ResolverTransporting {
    func send(_ request: URLRequest) throws -> (Data, HTTPURLResponse)
}

struct ResolverHTTPConfiguration {
    let baseURL: URL
    let timeoutInterval: TimeInterval

    init(baseURL: URL, timeoutInterval: TimeInterval = 20) {
        self.baseURL = baseURL
        self.timeoutInterval = timeoutInterval
    }
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

struct RemoteMusicResolverService: MusicResolverService {
    let apiClient: any ResolverAPIClient
    let fallbackService: any MusicResolverService

    init(
        apiClient: any ResolverAPIClient,
        fallbackService: any MusicResolverService = MockMusicResolverService()
    ) {
        self.apiClient = apiClient
        self.fallbackService = fallbackService
    }

    func resolve(request: ResolverRequest) -> ResolverResponse {
        do {
            let response = try apiClient.resolve(request: request)
            return ResolverResponse(
                resolvedTrack: response.resolvedTrack,
                parsingResult: response.parsingResult,
                metadataStatus: response.metadataStatus,
                resolverVersion: response.resolverVersion,
                resolutionSource: .remote,
                diagnosticMessage: response.diagnosticMessage
            )
        } catch {
            print("RemoteMusicResolverService fallback to mock:", error)
            let fallbackResponse = fallbackService.resolve(request: request)
            return ResolverResponse(
                resolvedTrack: fallbackResponse.resolvedTrack,
                parsingResult: fallbackResponse.parsingResult,
                metadataStatus: .fallbackMock,
                resolverVersion: fallbackResponse.resolverVersion,
                resolutionSource: .fallbackMock,
                diagnosticMessage: error.localizedDescription
            )
        }
    }

    func resolveMetadata(request: ResolverRequest) -> ResolverResponse {
        do {
            let response = try apiClient.resolveMetadata(request: request)
            return ResolverResponse(
                resolvedTrack: response.resolvedTrack,
                parsingResult: response.parsingResult,
                metadataStatus: response.metadataStatus,
                resolverVersion: response.resolverVersion,
                resolutionSource: .remote,
                diagnosticMessage: response.diagnosticMessage
            )
        } catch {
            print("RemoteMusicResolverService metadata fallback to mock:", error)
            let fallbackResponse = fallbackService.resolveMetadata(request: request)
            return ResolverResponse(
                resolvedTrack: fallbackResponse.resolvedTrack,
                parsingResult: fallbackResponse.parsingResult,
                metadataStatus: .fallbackMock,
                resolverVersion: fallbackResponse.resolverVersion,
                resolutionSource: .fallbackMock,
                diagnosticMessage: error.localizedDescription
            )
        }
    }

    func resolvePlatformLinks(for track: Track) -> PlatformLinksResolutionResponse {
        do {
            return try apiClient.resolvePlatformLinks(for: track)
        } catch {
            print("RemoteMusicResolverService platform links failed:", error)
            return PlatformLinksResolutionResponse(
                platformLinks: track.platformLinks,
                status: .failed,
                resolverVersion: "remote-platform-links/v1",
                diagnosticMessage: error.localizedDescription
            )
        }
    }

    func resolvePlatformLink(for track: Track, targetPlatform: MusicPlatform) -> SinglePlatformLinkResolutionResponse {
        do {
            return try apiClient.resolvePlatformLink(for: track, targetPlatform: targetPlatform)
        } catch {
            print("RemoteMusicResolverService single platform link failed:", error)
            return SinglePlatformLinkResolutionResponse(
                platform: targetPlatform,
                platformLink: nil,
                state: .failed,
                resolverVersion: "remote-platform-link/v1",
                diagnosticMessage: error.localizedDescription
            )
        }
    }

    func resolvePayload(from link: String) -> ResolvedTrackPayload {
        resolve(request: ResolverRequest(rawLink: link)).resolvedTrack
    }

    func resolveTrack(from link: String) -> Track {
        resolvePayload(from: link).track
    }
}

struct URLSessionResolverTransport: ResolverTransporting {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        let semaphore = DispatchSemaphore(value: 0)
        var capturedData: Data?
        var capturedResponse: URLResponse?
        var capturedError: Error?

        session.dataTask(with: request) { data, response, error in
            capturedData = data
            capturedResponse = response
            capturedError = error
            semaphore.signal()
        }.resume()

        semaphore.wait()

        if let capturedError {
            throw capturedError
        }

        guard let httpResponse = capturedResponse as? HTTPURLResponse else {
            throw ResolverClientError.invalidHTTPResponse
        }

        return (capturedData ?? Data(), httpResponse)
    }
}

struct ResolverHTTPAPIClient: ResolverAPIClient {
    let configuration: ResolverHTTPConfiguration
    let transport: any ResolverTransporting
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        configuration: ResolverHTTPConfiguration,
        transport: any ResolverTransporting = URLSessionResolverTransport()
    ) {
        self.configuration = configuration
        self.transport = transport
    }

    func resolve(request: ResolverRequest) throws -> ResolverResponse {
        try resolve(request: request, includePlatformLinks: true)
    }

    func resolveMetadata(request: ResolverRequest) throws -> ResolverResponse {
        let response = try resolve(request: request, includePlatformLinks: false)
        return response.withPlatformLinksStatus(.idle)
    }

    func resolvePlatformLinks(for track: Track) throws -> PlatformLinksResolutionResponse {
        let endpointURL = configuration.baseURL.appending(path: "resolve-platform-links")
        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(ResolverPlatformLinksRequestBody(track: track))

        let (data, response) = try transport.send(urlRequest)
        guard (200...299).contains(response.statusCode) else {
            throw ResolverClientError.unsuccessfulStatusCode(response.statusCode)
        }

        let body = try decoder.decode(PlatformLinksResponseBody.self, from: data)
        return try body.toDomain()
    }

    func resolvePlatformLink(for track: Track, targetPlatform: MusicPlatform) throws -> SinglePlatformLinkResolutionResponse {
        let endpointURL = configuration.baseURL.appending(path: "resolve-platform-link")
        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(
            ResolverSinglePlatformLinkRequestBody(track: track, targetPlatform: targetPlatform)
        )

        let (data, response) = try transport.send(urlRequest)
        guard (200...299).contains(response.statusCode) else {
            throw ResolverClientError.unsuccessfulStatusCode(response.statusCode)
        }

        let body = try decoder.decode(SinglePlatformLinkResponseBody.self, from: data)
        return try body.toDomain(targetPlatform: targetPlatform)
    }

    private func resolve(request: ResolverRequest, includePlatformLinks: Bool) throws -> ResolverResponse {
        let endpointURL = configuration.baseURL.appending(path: "resolve")
        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(
            ResolverAPIRequestBody(request: request, includePlatformLinks: includePlatformLinks)
        )

        let (data, response) = try transport.send(urlRequest)
        guard (200...299).contains(response.statusCode) else {
            throw ResolverClientError.unsuccessfulStatusCode(response.statusCode)
        }

        let body = try decoder.decode(ResolverAPIResponseBody.self, from: data)
        return try body.toDomain()
    }
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

struct MockMusicResolverService: MusicResolverService {
    private let linkParsers: [any MusicLinkParser]
    private let metadataProviders: [any TrackMetadataProvider]
    private let navigationService: PlatformNavigationService

    init(
        linkParsers: [any MusicLinkParser] = MockMusicLinkParser.defaultParsers,
        metadataProviders: [any TrackMetadataProvider] = MockTrackMetadataProvider.defaultProviders,
        navigationService: PlatformNavigationService = MockPlatformNavigationService()
    ) {
        self.linkParsers = linkParsers
        self.metadataProviders = metadataProviders
        self.navigationService = navigationService
    }

    func resolve(request: ResolverRequest) -> ResolverResponse {
        let rawLink = request.rawLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsingResult = parse(link: rawLink) else {
            let payload = fallbackPayload(for: rawLink)
            return ResolverResponse(
                resolvedTrack: payload,
                parsingResult: .unsupportedLink(rawLink: rawLink),
                metadataStatus: .fallbackMock,
                resolverVersion: "mock-resolver/v1",
                resolutionSource: .mockLocal,
                diagnosticMessage: nil
            )
        }

        let payload: ResolvedTrackPayload
        let metadataStatus: MetadataFetchStatus

        switch parsingResult {
        case .parsed(let parsedLink):
            let metadataResult = fetchMetadata(for: parsedLink)
                ?? TrackMetadataResult(
                    track: fallbackTrackDTO(
                        platform: parsedLink.platform,
                        sourceURL: parsedLink.sourceURL,
                        sourceResourceID: parsedLink.resourceID
                    ),
                    status: .fallbackMock,
                    providerResourceID: parsedLink.resourceID,
                    providerDebugSummary: "Metadata provider unavailable for \(parsedLink.platform.displayName)"
                )

            payload = assemblePayload(
                from: metadataResult.track,
                sourcePlatform: parsedLink.platform,
                sourceURL: parsedLink.sourceURL,
                sourceResourceID: metadataResult.providerResourceID ?? parsedLink.resourceID
            )
            metadataStatus = metadataResult.status
        case .missingResourceID(let partialLink):
            payload = fallbackPayload(
                for: rawLink,
                sourcePlatform: partialLink.platform,
                sourceURL: partialLink.sourceURL
            )
            metadataStatus = .fallbackMock
        case .unsupportedLink(let unresolvedLink):
            payload = fallbackPayload(for: unresolvedLink)
            metadataStatus = .fallbackMock
        }

        return ResolverResponse(
            resolvedTrack: payload,
            parsingResult: parsingResult,
            metadataStatus: metadataStatus,
            resolverVersion: "mock-resolver/v1",
            resolutionSource: .mockLocal,
            diagnosticMessage: nil
        )
    }

    func resolveMetadata(request: ResolverRequest) -> ResolverResponse {
        let rawLink = request.rawLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsingResult = parse(link: rawLink) else {
            return resolve(request: request).withPlatformLinksStatus(.failed)
        }

        let payload: ResolvedTrackPayload
        let metadataStatus: MetadataFetchStatus

        switch parsingResult {
        case .parsed(let parsedLink):
            let metadataResult = fetchMetadata(for: parsedLink)
                ?? TrackMetadataResult(
                    track: fallbackTrackDTO(
                        platform: parsedLink.platform,
                        sourceURL: parsedLink.sourceURL,
                        sourceResourceID: parsedLink.resourceID
                    ),
                    status: .fallbackMock,
                    providerResourceID: parsedLink.resourceID,
                    providerDebugSummary: "Metadata provider unavailable for \(parsedLink.platform.displayName)"
                )

            payload = assemblePayload(
                from: metadataResult.track,
                sourcePlatform: parsedLink.platform,
                sourceURL: parsedLink.sourceURL,
                sourceResourceID: metadataResult.providerResourceID ?? parsedLink.resourceID,
                includePlatformLinks: false
            )
            metadataStatus = metadataResult.status
        case .missingResourceID(let partialLink):
            payload = fallbackPayload(
                for: rawLink,
                sourcePlatform: partialLink.platform,
                sourceURL: partialLink.sourceURL
            )
            metadataStatus = .fallbackMock
        case .unsupportedLink(let unresolvedLink):
            payload = fallbackPayload(for: unresolvedLink)
            metadataStatus = .fallbackMock
        }

        return ResolverResponse(
            resolvedTrack: payload,
            parsingResult: parsingResult,
            metadataStatus: metadataStatus,
            resolverVersion: "mock-resolver/v1",
            resolutionSource: .mockLocal,
            diagnosticMessage: nil
        )
    }

    func resolvePlatformLinks(for track: Track) -> PlatformLinksResolutionResponse {
        PlatformLinksResolutionResponse(
            platformLinks: allPlatformLinks(for: track),
            status: .loaded,
            resolverVersion: "mock-resolver/v1",
            diagnosticMessage: nil
        )
    }

    func resolvePlatformLink(for track: Track, targetPlatform: MusicPlatform) -> SinglePlatformLinkResolutionResponse {
        let platformLink = allPlatformLinks(for: track).first(where: { $0.platform == targetPlatform })
        return SinglePlatformLinkResolutionResponse(
            platform: targetPlatform,
            platformLink: platformLink,
            state: platformLink == nil ? .unavailable : .ready,
            resolverVersion: "mock-resolver/v1",
            diagnosticMessage: nil
        )
    }

    func resolvePayload(from link: String) -> ResolvedTrackPayload {
        resolve(request: ResolverRequest(rawLink: link)).resolvedTrack
    }

    func resolveTrack(from link: String) -> Track {
        resolvePayload(from: link).track
    }

    private func parse(link: String) -> LinkParsingResult? {
        let normalizedLink = link.lowercased()

        for parser in linkParsers where parser.canHandle(link: normalizedLink) {
            if let parsingResult = parser.parse(link: link) {
                return parsingResult
            }
        }

        return .unsupportedLink(rawLink: link)
    }

    private func fetchMetadata(for parsedLink: ParsedMusicLink) -> TrackMetadataResult? {
        metadataProviders
            .first { $0.platform == parsedLink.platform }?
            .fetchTrackMetadata(for: parsedLink)
    }

    private func fallbackPayload(
        for link: String,
        sourcePlatform: MusicPlatform? = nil,
        sourceURL: URL? = nil
    ) -> ResolvedTrackPayload {
        let resolvedSourceURL = sourceURL ?? URL(string: link)
        let resolvedSourcePlatform = sourcePlatform ?? MockData.tracks[0].sourcePlatform
        let fallbackTrack = MockData.track(for: resolvedSourcePlatform)
        let fallbackDTO = ResolverTrackDTO(
            title: fallbackTrack.title,
            artistName: fallbackTrack.artistName,
            albumTitle: fallbackTrack.albumTitle,
            durationMS: fallbackTrack.durationMS,
            artworkURL: fallbackTrack.artworkURL,
            sourcePlatform: fallbackTrack.sourcePlatform,
            sourcePlatformID: fallbackTrack.sourcePlatformID,
            sourceURL: resolvedSourceURL ?? fallbackTrack.sourceURL,
            isrc: fallbackTrack.isrc
        )

        return assemblePayload(
            from: fallbackDTO,
            sourcePlatform: resolvedSourcePlatform,
            sourceURL: resolvedSourceURL,
            sourceResourceID: nil
        )
    }

    private func assemblePayload(
        from trackDTO: ResolverTrackDTO,
        sourcePlatform: MusicPlatform,
        sourceURL: URL?,
        sourceResourceID: String?,
        includePlatformLinks: Bool = true
    ) -> ResolvedTrackPayload {
        let platformLinks = includePlatformLinks
            ? allPlatformLinks(for: trackDTO, sourcePlatform: sourcePlatform, sourceURL: sourceURL)
            : sourcePlatformLinks(for: trackDTO, sourcePlatform: sourcePlatform, sourceURL: sourceURL)
        let resolvedTrack = trackDTO.asTrack(platformLinks: platformLinks).updatingPlatformLinks(
            platformLinks,
            status: includePlatformLinks ? .loaded : .idle
        )
        let finalizedTrack = includePlatformLinks
            ? resolvedTrack
            : Track(
                id: resolvedTrack.id,
                title: resolvedTrack.title,
                artistName: resolvedTrack.artistName,
                albumTitle: resolvedTrack.albumTitle,
                durationMS: resolvedTrack.durationMS,
                sourcePlatform: resolvedTrack.sourcePlatform,
                sourcePlatformID: resolvedTrack.sourcePlatformID,
                sourceURL: resolvedTrack.sourceURL,
                isrc: resolvedTrack.isrc,
                platformLinks: resolvedTrack.platformLinks,
                platformLinksStatus: resolvedTrack.platformLinksStatus,
                platformLinkStatuses: Track.deferredPlatformLinkStatuses(
                    sourcePlatform: resolvedTrack.sourcePlatform,
                    platformLinks: resolvedTrack.platformLinks
                ),
                artworkURL: resolvedTrack.artworkURL
            )

        return ResolvedTrackPayload(
            track: finalizedTrack,
            sourcePlatform: sourcePlatform,
            sourceURL: sourceURL ?? trackDTO.sourceURL,
            sourceResourceID: sourceResourceID ?? trackDTO.sourcePlatformID,
            platformLinks: platformLinks
        )
    }

    private func fallbackTrackDTO(
        platform: MusicPlatform,
        sourceURL: URL?,
        sourceResourceID: String?
    ) -> ResolverTrackDTO {
        let fallbackTrack = MockData.track(for: platform)
        return ResolverTrackDTO(
            title: fallbackTrack.title,
            artistName: fallbackTrack.artistName,
            albumTitle: fallbackTrack.albumTitle,
            durationMS: fallbackTrack.durationMS,
            artworkURL: fallbackTrack.artworkURL,
            sourcePlatform: platform,
            sourcePlatformID: sourceResourceID ?? fallbackTrack.sourcePlatformID,
            sourceURL: sourceURL ?? fallbackTrack.sourceURL,
            isrc: fallbackTrack.isrc
        )
    }

    private func sourcePlatformLinks(for track: ResolverTrackDTO, sourcePlatform: MusicPlatform, sourceURL: URL?) -> [PlatformLink] {
        guard let resolvedSourceURL = sourceURL ?? track.sourceURL else { return [] }
        return [
            PlatformLink(
                platform: sourcePlatform,
                destinationURL: resolvedSourceURL,
                isSource: true
            )
        ]
    }

    private func allPlatformLinks(for track: Track) -> [PlatformLink] {
        allPlatformLinks(
            for: ResolverTrackDTO(
                title: track.title,
                artistName: track.artistName,
                albumTitle: track.albumTitle,
                durationMS: track.durationMS,
                artworkURL: track.artworkURL,
                sourcePlatform: track.sourcePlatform,
                sourcePlatformID: track.sourcePlatformID,
                sourceURL: track.sourceURL,
                isrc: track.isrc
            ),
            sourcePlatform: track.sourcePlatform,
            sourceURL: track.sourceURL
        )
    }

    private func allPlatformLinks(for track: ResolverTrackDTO, sourcePlatform: MusicPlatform, sourceURL: URL?) -> [PlatformLink] {
        let canonicalTrack = track.asTrack(platformLinks: [])

        return MusicPlatform.allCases.compactMap { platform in
            let destinationURL: URL?

            if platform == sourcePlatform, let sourceURL {
                destinationURL = sourceURL
            } else {
                destinationURL = navigationService.destinationURL(for: platform, track: canonicalTrack)
            }

            guard let destinationURL else { return nil }

            return PlatformLink(
                platform: platform,
                destinationURL: destinationURL,
                isSource: platform == sourcePlatform
            )
        }
    }
}

struct MockMusicLinkParser: MusicLinkParser {
    let platform: MusicPlatform
    let matchingKeywords: [String]
    let resourceIDExtractor: (String) -> String?

    func canHandle(link: String) -> Bool {
        matchingKeywords.contains { link.contains($0) }
    }

    func parse(link: String) -> LinkParsingResult? {
        guard canHandle(link: link.lowercased()) else { return nil }

        let parsedLink = ParsedMusicLink(
            originalLink: link,
            normalizedLink: link.lowercased(),
            platform: platform,
            sourceURL: URL(string: link),
            resourceID: resourceIDExtractor(link),
            resourceKind: .track
        )

        guard parsedLink.resourceID != nil else {
            return .missingResourceID(partialLink: parsedLink)
        }

        return .parsed(parsedLink)
    }

    static let defaultParsers: [any MusicLinkParser] = [
        MockMusicLinkParser(
            platform: .spotify,
            matchingKeywords: ["open.spotify.com", "spotify.link", "spotify:"],
            resourceIDExtractor: { link in
                firstMatch(in: link, pattern: #"track[/:]([A-Za-z0-9]+)"#)
            }
        ),
        MockMusicLinkParser(
            platform: .neteaseMusic,
            matchingKeywords: ["music.163.com", "163cn.tv", "netease"],
            resourceIDExtractor: { link in
                firstMatch(in: link, pattern: #"[?&]id=(\d+)"#)
            }
        ),
        MockMusicLinkParser(
            platform: .appleMusic,
            matchingKeywords: ["music.apple.com", "itunes.apple.com"],
            resourceIDExtractor: { link in
                firstMatch(in: link, pattern: #"(?:song/[^/]+/|i=)(\d+)"#)
            }
        ),
        MockMusicLinkParser(
            platform: .qqMusic,
            matchingKeywords: ["y.qq.com", "qqmusic.qq.com", "ryqq", "c6.y.qq.com"],
            resourceIDExtractor: { link in
                firstMatch(in: link, pattern: #"songDetail/([A-Za-z0-9]+)"#)
                    ?? firstMatch(in: link, pattern: #"song/([A-Za-z0-9]+)"#)
            }
        )
    ]
}

enum MockTrackMetadataProvider {
    static let defaultProviders: [any TrackMetadataProvider] = [
        MockSpotifyMetadataProvider(
            catalogClient: MockSpotifyTrackCatalogClient(
                tokenProvider: MockSpotifyAccessTokenProvider(),
                fetcher: MockSpotifyCatalogFetcher()
            )
        ),
        MockAppleMusicMetadataProvider(),
        MockNeteaseMusicMetadataProvider(),
        MockQQMusicMetadataProvider()
    ]
}

struct MockSpotifyMetadataProvider: TrackMetadataProvider, MockPlatformTrackBuilding {
    let platform: MusicPlatform = .spotify
    let catalogClient: any SpotifyTrackCatalogProviding

    func fetchTrackMetadata(for parsedLink: ParsedMusicLink) -> TrackMetadataResult? {
        guard parsedLink.platform == .spotify, let resourceID = parsedLink.resourceID else {
            return nil
        }

        let request = SpotifyCatalogRequest(
            trackID: resourceID,
            market: nil,
            accessToken: nil
        )

        guard let catalogItem = catalogClient.fetchTrack(request: request) else {
            return TrackMetadataResult(
                track: ResolverTrackDTO(
                    title: MockData.track(for: .spotify).title,
                    artistName: MockData.track(for: .spotify).artistName,
                    albumTitle: MockData.track(for: .spotify).albumTitle,
                    durationMS: MockData.track(for: .spotify).durationMS,
                    artworkURL: MockData.track(for: .spotify).artworkURL,
                    sourcePlatform: .spotify,
                    sourcePlatformID: resourceID,
                    sourceURL: parsedLink.sourceURL ?? MockData.track(for: .spotify).sourceURL,
                    isrc: MockData.track(for: .spotify).isrc
                ),
                status: .fallbackMock,
                providerResourceID: resourceID,
                providerDebugSummary: "Spotify catalog lookup fallback for resource \(resourceID)"
            )
        }

        return TrackMetadataResult(
            track: ResolverTrackDTO(
                title: catalogItem.title,
                artistName: catalogItem.artistName,
                albumTitle: catalogItem.albumTitle,
                durationMS: catalogItem.durationMS,
                artworkURL: catalogItem.artworkURL,
                sourcePlatform: .spotify,
                sourcePlatformID: catalogItem.id,
                sourceURL: parsedLink.sourceURL ?? catalogItem.externalURL,
                isrc: catalogItem.isrc
            ),
            status: .success,
            providerResourceID: catalogItem.id,
            providerDebugSummary: "Spotify catalog metadata fetched for \(catalogItem.id)"
        )
    }
}

struct MockAppleMusicMetadataProvider: TrackMetadataProvider, MockPlatformTrackBuilding {
    let platform: MusicPlatform = .appleMusic

    func fetchTrackMetadata(for parsedLink: ParsedMusicLink) -> TrackMetadataResult? {
        buildMockTrackResult(for: parsedLink)
    }
}

struct MockNeteaseMusicMetadataProvider: TrackMetadataProvider, MockPlatformTrackBuilding {
    let platform: MusicPlatform = .neteaseMusic

    func fetchTrackMetadata(for parsedLink: ParsedMusicLink) -> TrackMetadataResult? {
        buildMockTrackResult(for: parsedLink)
    }
}

struct MockQQMusicMetadataProvider: TrackMetadataProvider, MockPlatformTrackBuilding {
    let platform: MusicPlatform = .qqMusic

    func fetchTrackMetadata(for parsedLink: ParsedMusicLink) -> TrackMetadataResult? {
        buildMockTrackResult(for: parsedLink)
    }
}

struct MockSpotifyCatalogRecord {
    let response: SpotifyTrackCatalogResponse
}

struct MockSpotifyAccessTokenProvider: SpotifyAccessTokenProviding {
    func accessToken() -> String? {
        "mock-spotify-access-token"
    }
}

struct MockSpotifyCatalogFetcher: SpotifyCatalogFetching {
    private let records: [String: MockSpotifyCatalogRecord] = {
        let spotifyTrack = MockData.track(for: .spotify)
        let record = MockSpotifyCatalogRecord(
            response: SpotifyTrackCatalogResponse(
                id: "6qxvy9Pe4RJIq5JBVbbwbS",
                name: spotifyTrack.title,
                artistNames: [spotifyTrack.artistName],
                albumName: spotifyTrack.albumTitle,
                durationMS: spotifyTrack.durationMS,
                artworkURL: spotifyTrack.artworkURL,
                externalURL: spotifyTrack.sourceURL,
                isrc: spotifyTrack.isrc
            )
        )

        return [record.response.id: record]
    }()

    func fetchTrackResponse(request: SpotifyCatalogRequest) -> SpotifyTrackCatalogResponse? {
        guard request.accessToken != nil else { return nil }
        return records[request.trackID]?.response
    }
}

struct MockSpotifyTrackCatalogClient: SpotifyTrackCatalogProviding {
    let tokenProvider: any SpotifyAccessTokenProviding
    let fetcher: any SpotifyCatalogFetching

    func fetchTrack(request: SpotifyCatalogRequest) -> SpotifyTrackCatalogItem? {
        let authorizedRequest = SpotifyCatalogRequest(
            trackID: request.trackID,
            market: request.market,
            accessToken: request.accessToken ?? tokenProvider.accessToken()
        )

        guard let response = fetcher.fetchTrackResponse(request: authorizedRequest) else { return nil }
        return mapResponseToCatalogItem(response)
    }

    private func mapResponseToCatalogItem(_ response: SpotifyTrackCatalogResponse) -> SpotifyTrackCatalogItem {
        SpotifyTrackCatalogItem(
            id: response.id,
            title: response.name,
            artistName: response.artistNames.joined(separator: ", "),
            albumTitle: response.albumName,
            durationMS: response.durationMS,
            artworkURL: response.artworkURL,
            externalURL: response.externalURL,
            isrc: response.isrc
        )
    }
}

private func firstMatch(in text: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else {
        return nil
    }

    guard let captureRange = Range(match.range(at: 1), in: text) else { return nil }
    return String(text[captureRange])
}

private struct ResolverAPIRequestBody: Encodable {
    let rawLink: String
    let preferredSourcePlatform: String?
    let preferredMarket: String?
    let includePlatformLinks: Bool

    init(request: ResolverRequest, includePlatformLinks: Bool = true) {
        self.rawLink = request.rawLink
        self.preferredSourcePlatform = request.preferredSourcePlatform?.resolverWireValue
        self.preferredMarket = request.preferredMarket
        self.includePlatformLinks = includePlatformLinks
    }
}

private struct ResolverPlatformLinksRequestBody: Encodable {
    let sourcePlatform: String
    let sourcePlatformID: String?
    let sourceURL: URL?
    let title: String
    let artistName: String
    let albumTitle: String?
    let durationMS: Int?
    let artworkURL: URL?
    let isrc: String?

    init(track: Track) {
        sourcePlatform = track.sourcePlatform.resolverWireValue
        sourcePlatformID = track.sourcePlatformID
        sourceURL = track.sourceURL
        title = track.title
        artistName = track.artistName
        albumTitle = track.albumTitle
        durationMS = track.durationMS
        artworkURL = track.artworkURL
        isrc = track.isrc
    }
}

private struct ResolverSinglePlatformLinkRequestBody: Encodable {
    let sourcePlatform: String
    let sourcePlatformID: String?
    let sourceURL: URL?
    let title: String
    let artistName: String
    let albumTitle: String?
    let durationMS: Int?
    let artworkURL: URL?
    let isrc: String?
    let targetPlatform: String

    init(track: Track, targetPlatform: MusicPlatform) {
        sourcePlatform = track.sourcePlatform.resolverWireValue
        sourcePlatformID = track.sourcePlatformID
        sourceURL = track.sourceURL
        title = track.title
        artistName = track.artistName
        albumTitle = track.albumTitle
        durationMS = track.durationMS
        artworkURL = track.artworkURL
        isrc = track.isrc
        self.targetPlatform = targetPlatform.resolverWireValue
    }
}

private struct ResolverAPIResponseBody: Decodable {
    let resolvedTrack: ResolvedTrackPayloadBody
    let parsingResult: ParsingResultBody
    let metadataStatus: String
    let resolverVersion: String

    func toDomain() throws -> ResolverResponse {
        ResolverResponse(
            resolvedTrack: try resolvedTrack.toDomain(),
            parsingResult: try parsingResult.toDomain(),
            metadataStatus: MetadataFetchStatus(apiValue: metadataStatus),
            resolverVersion: resolverVersion,
            resolutionSource: .remote,
            diagnosticMessage: nil
        )
    }
}

private struct ResolvedTrackPayloadBody: Decodable {
    let track: TrackBody
    let sourcePlatform: String
    let sourceURL: URL?
    let sourceResourceID: String?
    let platformLinks: [PlatformLinkBody]

    func toDomain() throws -> ResolvedTrackPayload {
        guard let platform = MusicPlatform(resolverWireValue: sourcePlatform) else {
            throw ResolverClientError.malformedPayload
        }

        let links = try platformLinks.map { try $0.toDomain() }
        return ResolvedTrackPayload(
            track: try track.toDomain(platformLinks: links),
            sourcePlatform: platform,
            sourceURL: sourceURL,
            sourceResourceID: sourceResourceID,
            platformLinks: links
        )
    }
}

private struct TrackBody: Decodable {
    let title: String
    let artistName: String
    let albumTitle: String?
    let durationMS: Int?
    let sourcePlatform: String
    let sourcePlatformID: String?
    let sourceURL: URL?
    let isrc: String?
    let artworkURL: URL?

    func toDomain(platformLinks: [PlatformLink]) throws -> Track {
        guard let platform = MusicPlatform(resolverWireValue: sourcePlatform) else {
            throw ResolverClientError.malformedPayload
        }

        return Track(
            title: title,
            artistName: artistName,
            albumTitle: albumTitle,
            durationMS: durationMS,
            sourcePlatform: platform,
            sourcePlatformID: sourcePlatformID,
            sourceURL: sourceURL,
            isrc: isrc,
            platformLinks: platformLinks,
            artworkURL: artworkURL
        )
    }
}

private struct PlatformLinkBody: Decodable {
    let platform: String
    let destinationURL: URL
    let isSource: Bool

    func toDomain() throws -> PlatformLink {
        guard let platform = MusicPlatform(resolverWireValue: platform) else {
            throw ResolverClientError.malformedPayload
        }

        return PlatformLink(
            platform: platform,
            destinationURL: destinationURL,
            isSource: isSource
        )
    }
}

private struct ParsingResultBody: Decodable {
    let type: String
    let parsedLink: ParsedMusicLinkBody?
    let partialLink: ParsedMusicLinkBody?
    let rawLink: String?

    func toDomain() throws -> LinkParsingResult {
        switch type {
        case "parsed":
            guard let parsedLink else { throw ResolverClientError.malformedPayload }
            return .parsed(try parsedLink.toDomain())
        case "missingResourceID":
            guard let partialLink else { throw ResolverClientError.malformedPayload }
            return .missingResourceID(partialLink: try partialLink.toDomain())
        case "unsupportedLink":
            guard let rawLink else { throw ResolverClientError.malformedPayload }
            return .unsupportedLink(rawLink: rawLink)
        default:
            throw ResolverClientError.malformedPayload
        }
    }
}

private struct ParsedMusicLinkBody: Decodable {
    let originalLink: String
    let normalizedLink: String
    let platform: String
    let sourceURL: URL?
    let resourceID: String?
    let resourceKind: String

    func toDomain() throws -> ParsedMusicLink {
        guard
            let platform = MusicPlatform(resolverWireValue: platform),
            let resourceKind = ResolverResourceKind(rawValue: resourceKind)
        else {
            throw ResolverClientError.malformedPayload
        }

        return ParsedMusicLink(
            originalLink: originalLink,
            normalizedLink: normalizedLink,
            platform: platform,
            sourceURL: sourceURL,
            resourceID: resourceID,
            resourceKind: resourceKind
        )
    }
}

private struct PlatformLinksResponseBody: Decodable {
    let platformLinks: [PlatformLinkBody]
    let resolverVersion: String

    func toDomain() throws -> PlatformLinksResolutionResponse {
        PlatformLinksResolutionResponse(
            platformLinks: try platformLinks.map { try $0.toDomain() },
            status: .loaded,
            resolverVersion: resolverVersion,
            diagnosticMessage: nil
        )
    }
}

private struct SinglePlatformLinkResponseBody: Decodable {
    let targetPlatform: String
    let platformLink: PlatformLinkBody?
    let resolverVersion: String

    func toDomain(targetPlatform fallbackPlatform: MusicPlatform) throws -> SinglePlatformLinkResolutionResponse {
        let platform = MusicPlatform(resolverWireValue: targetPlatform) ?? fallbackPlatform
        let link = try platformLink?.toDomain()
        return SinglePlatformLinkResolutionResponse(
            platform: platform,
            platformLink: link,
            state: link == nil ? .unavailable : .ready,
            resolverVersion: resolverVersion,
            diagnosticMessage: nil
        )
    }
}

private extension ResolverResponse {
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

private extension MetadataFetchStatus {
    init(apiValue: String) {
        switch apiValue {
        case "success":
            self = .success
        default:
            self = .fallbackMock
        }
    }
}
