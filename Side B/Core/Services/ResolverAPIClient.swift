import Foundation
import os

private let logger = Logger(subsystem: "com.sideb.app", category: "RemoteMusicResolverService")

struct RemoteMusicResolverService: MusicResolverService {
    let apiClient: any ResolverAPIClient
    let fallbackService: (any MusicResolverService)?

    init(
        apiClient: any ResolverAPIClient,
        fallbackService: (any MusicResolverService)? = nil
    ) {
        self.apiClient = apiClient
        self.fallbackService = fallbackService
    }

    func resolve(request: ResolverRequest) async throws -> ResolverResponse {
        do {
            let response = try await apiClient.resolve(request: request)
            return ResolverResponse(
                resolvedTrack: response.resolvedTrack,
                parsingResult: response.parsingResult,
                metadataStatus: response.metadataStatus,
                resolverVersion: response.resolverVersion,
                resolutionSource: .remote,
                diagnosticMessage: response.diagnosticMessage
            )
        } catch {
            guard let fallbackService else { throw error }
            logger.info("fallback to mock: \(error)")
            let fallbackResponse = try await fallbackService.resolve(request: request)
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

    func resolveMetadata(request: ResolverRequest) async throws -> ResolverResponse {
        do {
            let response = try await apiClient.resolveMetadata(request: request)
            return ResolverResponse(
                resolvedTrack: response.resolvedTrack,
                parsingResult: response.parsingResult,
                metadataStatus: response.metadataStatus,
                resolverVersion: response.resolverVersion,
                resolutionSource: .remote,
                diagnosticMessage: response.diagnosticMessage
            )
        } catch {
            guard let fallbackService else { throw error }
            logger.info("metadata fallback to mock: \(error)")
            let fallbackResponse = try await fallbackService.resolveMetadata(request: request)
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

    func resolvePlatformLinks(for track: Track) async throws -> PlatformLinksResolutionResponse {
        do {
            return try await apiClient.resolvePlatformLinks(for: track)
        } catch {
            logger.error("platform links failed: \(error)")
            return PlatformLinksResolutionResponse(
                platformLinks: track.platformLinks,
                status: .failed,
                resolverVersion: "remote-platform-links/v1",
                diagnosticMessage: error.localizedDescription
            )
        }
    }

    func resolvePlatformLink(for track: Track, targetPlatform: MusicPlatform) async throws -> SinglePlatformLinkResolutionResponse {
        do {
            return try await apiClient.resolvePlatformLink(for: track, targetPlatform: targetPlatform)
        } catch {
            logger.error("single platform link failed: \(error)")
            return SinglePlatformLinkResolutionResponse(
                platform: targetPlatform,
                platformLink: nil,
                state: .failed,
                resolverVersion: "remote-platform-link/v1",
                diagnosticMessage: error.localizedDescription
            )
        }
    }

    func resolvePayload(from link: String) async throws -> ResolvedTrackPayload {
        try await resolve(request: ResolverRequest(rawLink: link)).resolvedTrack
    }

    func resolveTrack(from link: String) async throws -> Track {
        try await resolvePayload(from: link).track
    }
}

struct URLSessionResolverTransport: ResolverTransporting {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ResolverClientError.invalidHTTPResponse
        }

        return (data, httpResponse)
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

    func resolve(request: ResolverRequest) async throws -> ResolverResponse {
        try await resolve(request: request, includePlatformLinks: true)
    }

    func resolveMetadata(request: ResolverRequest) async throws -> ResolverResponse {
        let response = try await resolve(request: request, includePlatformLinks: false)
        return response.withPlatformLinksStatus(.idle)
    }

    func resolvePlatformLinks(for track: Track) async throws -> PlatformLinksResolutionResponse {
        let endpointURL = configuration.baseURL.appending(path: "resolve-platform-links")
        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(ResolverPlatformLinksRequestBody(track: track))

        let (data, response) = try await transport.send(urlRequest)
        guard (200...299).contains(response.statusCode) else {
            throw ResolverClientError.unsuccessfulStatusCode(response.statusCode)
        }

        let body = try decoder.decode(PlatformLinksResponseBody.self, from: data)
        return try body.toDomain()
    }

    func resolvePlatformLink(for track: Track, targetPlatform: MusicPlatform) async throws -> SinglePlatformLinkResolutionResponse {
        let endpointURL = configuration.baseURL.appending(path: "resolve-platform-link")
        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(
            ResolverSinglePlatformLinkRequestBody(track: track, targetPlatform: targetPlatform)
        )

        let (data, response) = try await transport.send(urlRequest)
        guard (200...299).contains(response.statusCode) else {
            throw ResolverClientError.unsuccessfulStatusCode(response.statusCode)
        }

        let body = try decoder.decode(SinglePlatformLinkResponseBody.self, from: data)
        return try body.toDomain(targetPlatform: targetPlatform)
    }

    private func resolve(request: ResolverRequest, includePlatformLinks: Bool) async throws -> ResolverResponse {
        let endpointURL = configuration.baseURL.appending(path: "resolve")
        var urlRequest = URLRequest(url: endpointURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.timeoutInterval
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try encoder.encode(
            ResolverAPIRequestBody(request: request, includePlatformLinks: includePlatformLinks)
        )

        let (data, response) = try await transport.send(urlRequest)
        guard (200...299).contains(response.statusCode) else {
            throw ResolverClientError.unsuccessfulStatusCode(response.statusCode)
        }

        let body = try decoder.decode(ResolverAPIResponseBody.self, from: data)
        return try body.toDomain()
    }
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
    let diagnosticMessage: String?

    func toDomain() throws -> ResolverResponse {
        ResolverResponse(
            resolvedTrack: try resolvedTrack.toDomain(),
            parsingResult: try parsingResult.toDomain(),
            metadataStatus: MetadataFetchStatus(apiValue: metadataStatus),
            resolverVersion: resolverVersion,
            resolutionSource: .remote,
            diagnosticMessage: diagnosticMessage
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
    let diagnosticMessage: String?

    func toDomain() throws -> PlatformLinksResolutionResponse {
        PlatformLinksResolutionResponse(
            platformLinks: try platformLinks.map { try $0.toDomain() },
            status: .loaded,
            resolverVersion: resolverVersion,
            diagnosticMessage: diagnosticMessage
        )
    }
}

private struct SinglePlatformLinkResponseBody: Decodable {
    let targetPlatform: String
    let platformLink: PlatformLinkBody?
    let resolverVersion: String
    let diagnosticMessage: String?

    func toDomain(targetPlatform fallbackPlatform: MusicPlatform) throws -> SinglePlatformLinkResolutionResponse {
        let platform = MusicPlatform(resolverWireValue: targetPlatform) ?? fallbackPlatform
        let link = try platformLink?.toDomain()
        return SinglePlatformLinkResolutionResponse(
            platform: platform,
            platformLink: link,
            state: link == nil ? .unavailable : .ready,
            resolverVersion: resolverVersion,
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