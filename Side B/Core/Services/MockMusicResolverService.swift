import Foundation

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

    func resolve(request: ResolverRequest) async throws -> ResolverResponse {
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

    func resolveMetadata(request: ResolverRequest) async throws -> ResolverResponse {
        let rawLink = request.rawLink.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let parsingResult = parse(link: rawLink) else {
            return try await resolve(request: request).withPlatformLinksStatus(.failed)
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

    func resolvePlatformLinks(for track: Track) async throws -> PlatformLinksResolutionResponse {
        PlatformLinksResolutionResponse(
            platformLinks: allPlatformLinks(for: track),
            status: .loaded,
            resolverVersion: "mock-resolver/v1",
            diagnosticMessage: nil
        )
    }

    func resolvePlatformLink(for track: Track, targetPlatform: MusicPlatform) async throws -> SinglePlatformLinkResolutionResponse {
        let platformLink = allPlatformLinks(for: track).first(where: { $0.platform == targetPlatform })
        return SinglePlatformLinkResolutionResponse(
            platform: targetPlatform,
            platformLink: platformLink,
            state: platformLink == nil ? .unavailable : .ready,
            resolverVersion: "mock-resolver/v1",
            diagnosticMessage: nil
        )
    }

    func resolvePayload(from link: String) async throws -> ResolvedTrackPayload {
        try await resolve(request: ResolverRequest(rawLink: link)).resolvedTrack
    }

    func resolveTrack(from link: String) async throws -> Track {
        try await resolvePayload(from: link).track
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

func firstMatch(in text: String, pattern: String) -> String? {
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
    let range = NSRange(text.startIndex..., in: text)
    guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else {
        return nil
    }

    guard let captureRange = Range(match.range(at: 1), in: text) else { return nil }
    return String(text[captureRange])
}