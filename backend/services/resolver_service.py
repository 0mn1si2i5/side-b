from __future__ import annotations

import logging
import time

from app.config import settings
from models.resolver_models import CanonicalTrack, ParsedSource, ResolverContext, ResolverDiagnostic, SourcePlatformAdapter, TargetPlatformResolver
from resolvers.spotify_platform import fetch_spotify_access_token, parse_spotify_track_id
from services.input_parser import InputParser, InputParseResult
from services.platform_link_cache import get_platform_link_cache
from services.platform_link_resolvers import SpotifyTargetResolver, resolve_platform_link, resolve_platform_links
from services.source_platform_adapters import SpotifySourceAdapter, default_source_adapters


logger = logging.getLogger(__name__)

RESOLVER_VERSION = "music-resolver/v1"
SUPPORTED_LINK_ERROR = "Only Spotify, Apple Music, 网易云音乐, and QQ 音乐 track links are supported in this resolver"
SPOTIFY_TOKEN_CACHE_TTL_SECONDS = 50 * 60
_spotify_token_cache: dict[str, str | float | None] = {"token": None, "fetched_at": None}


class ResolverService:
    def __init__(
        self,
        *,
        input_parser: InputParser | None = None,
        source_adapters: list[SourcePlatformAdapter] | None = None,
        target_resolvers: list[TargetPlatformResolver] | None = None,
    ) -> None:
        self.source_adapters = source_adapters or default_source_adapters()
        self.input_parser = input_parser or InputParser(self.source_adapters)
        self.target_resolvers = target_resolvers
        self.spotify_source_adapter = next(
            (adapter for adapter in self.source_adapters if getattr(adapter, "platform", None) == "Spotify"),
            SpotifySourceAdapter(),
        )
        self.spotify_target_resolver = SpotifyTargetResolver()
        self.platform_link_cache = get_platform_link_cache()

    def resolve(self, raw_input: str, preferred_market: str | None, include_platform_links: bool) -> dict:
        parse_result = self.input_parser.parse(raw_input)
        if parse_result.kind == "unsupported":
            return {
                "status_code": 400,
                "body": {
                    "error": SUPPORTED_LINK_ERROR,
                    "parsingResult": {"type": "unsupportedLink", "rawLink": raw_input},
                },
            }

        if parse_result.kind == "plain_text":
            return {
                "status_code": 400,
                "body": {
                    "error": "Plain text input is reserved for a later phase",
                    "parsingResult": {"type": "unsupportedLink", "rawLink": raw_input},
                },
            }

        if parse_result.kind == "missing_resource" and parse_result.adapter is not None:
            return {
                "status_code": 400,
                "body": {
                    "error": f"{parse_result.adapter.platform} track ID could not be extracted",
                    "parsingResult": self._build_missing_resource_result(raw_input, parse_result.adapter.platform),
                },
            }

        if parse_result.parsed_source is None or parse_result.adapter is None:
            return {
                "status_code": 500,
                "body": {"error": "Resolver failed", "detail": "Input parser returned an invalid state"},
            }

        context = self.build_context(preferred_market)
        source_canonical = parse_result.adapter.fetch_canonical_track(parse_result.parsed_source, context)
        canonical_track, diagnostic = self._promote_to_spotify_if_available(source_canonical, context)
        body = self._build_resolver_response(
            parsed_source=parse_result.parsed_source,
            canonical_track=canonical_track,
            context=context,
            include_platform_links=include_platform_links,
            diagnostic=diagnostic,
        )
        return {"status_code": 200, "body": body}

    def resolve_platform_links(self, canonical_track: CanonicalTrack, preferred_market: str | None) -> dict:
        context = self.build_context(preferred_market)
        platform_links = resolve_platform_links(
            canonical_track,
            context,
            resolvers=self.target_resolvers,
        )

        for link in platform_links:
            if link.get("isSource"):
                continue
            target_platform = link.get("platform")
            destination_url = link.get("destinationURL")
            if target_platform and destination_url:
                self.platform_link_cache.set(
                    canonical_track.source_url, target_platform, destination_url, preferred_market
                )

        return {
            "platformLinks": platform_links,
            "resolverVersion": RESOLVER_VERSION,
        }

    def resolve_platform_link(self, canonical_track: CanonicalTrack, target_platform: str, preferred_market: str | None) -> dict:
        if target_platform == canonical_track.source_platform:
            source_link = {
                "platform": canonical_track.source_platform,
                "destinationURL": canonical_track.source_url,
                "isSource": True,
            }
            return {
                "targetPlatform": target_platform,
                "platformLink": source_link,
                "resolverVersion": RESOLVER_VERSION,
            }

        cached_url = self.platform_link_cache.get(
            canonical_track.source_url, target_platform, preferred_market
        )
        if cached_url:
            platform_link = {
                "platform": target_platform,
                "destinationURL": cached_url,
                "isSource": False,
            }
            return {
                "targetPlatform": target_platform,
                "platformLink": platform_link,
                "resolverVersion": RESOLVER_VERSION,
            }

        context = self.build_context(preferred_market)
        platform_link = resolve_platform_link(
            canonical_track,
            context,
            target_platform,
            resolvers=self.target_resolvers,
        )

        if platform_link and not platform_link.get("isSource"):
            resolved_url = platform_link.get("destinationURL")
            if resolved_url:
                self.platform_link_cache.set(
                    canonical_track.source_url, target_platform, resolved_url, preferred_market
                )

        return {
            "targetPlatform": target_platform,
            "platformLink": platform_link,
            "resolverVersion": RESOLVER_VERSION,
        }

    def build_context(self, preferred_market: str | None) -> ResolverContext:
        client_id = settings.SPOTIFY_CLIENT_ID
        client_secret = settings.SPOTIFY_CLIENT_SECRET
        spotify_access_token = self._spotify_access_token_from_cache(client_id, client_secret)

        return ResolverContext(
            preferred_market=preferred_market,
            spotify_access_token=spotify_access_token,
            netease_api_base_url=settings.NETEASE_API_BASE_URL or None,
            netease_request_timeout=float(settings.NETEASE_REQUEST_TIMEOUT),
        )

    def _build_resolver_response(
        self,
        *,
        parsed_source: ParsedSource,
        canonical_track: CanonicalTrack,
        context: ResolverContext,
        include_platform_links: bool,
        diagnostic: ResolverDiagnostic | None,
    ) -> dict:
        platform_links = (
            resolve_platform_links(canonical_track, context, resolvers=self.target_resolvers)
            if include_platform_links
            else self._build_source_platform_links(canonical_track)
        )
        resolved_track = {
            "track": self._build_track_body(canonical_track),
            "sourcePlatform": canonical_track.source_platform,
            "sourceURL": canonical_track.source_url,
            "sourceResourceID": canonical_track.source_id,
            "platformLinks": platform_links,
        }
        return {
            "resolvedTrack": resolved_track,
            "parsingResult": self._build_parsed_result(parsed_source),
            "metadataStatus": "success",
            "resolverVersion": RESOLVER_VERSION,
            "diagnosticMessage": diagnostic.message if diagnostic else None,
        }

    @staticmethod
    def _build_track_body(canonical_track: CanonicalTrack) -> dict:
        return {
            "title": canonical_track.title,
            "artistName": canonical_track.artist_name,
            "albumTitle": canonical_track.album_title,
            "durationMS": canonical_track.duration_ms,
            "sourcePlatform": canonical_track.source_platform,
            "sourcePlatformID": canonical_track.source_id,
            "sourceURL": canonical_track.source_url,
            "isrc": canonical_track.isrc,
            "artworkURL": canonical_track.artwork_url,
        }

    @staticmethod
    def _build_source_platform_links(canonical_track: CanonicalTrack) -> list[dict]:
        return [
            {
                "platform": canonical_track.source_platform,
                "destinationURL": canonical_track.source_url,
                "isSource": True,
            }
        ]

    @staticmethod
    def _build_parsed_result(parsed_source: ParsedSource) -> dict:
        return {
            "type": "parsed",
            "parsedLink": {
                "originalLink": parsed_source.raw_link,
                "normalizedLink": parsed_source.normalized_link,
                "platform": parsed_source.platform,
                "sourceURL": parsed_source.source_url,
                "resourceID": parsed_source.resource_id,
                "resourceKind": parsed_source.resource_kind,
            },
        }

    @staticmethod
    def _build_missing_resource_result(raw_link: str, platform: str) -> dict:
        return {
            "type": "missingResourceID",
            "partialLink": {
                "originalLink": raw_link,
                "normalizedLink": raw_link.strip().lower(),
                "platform": platform,
                "sourceURL": raw_link,
                "resourceID": None,
                "resourceKind": "track",
            },
        }

    def _promote_to_spotify_if_available(
        self,
        canonical_track: CanonicalTrack,
        context: ResolverContext,
    ) -> tuple[CanonicalTrack, ResolverDiagnostic | None]:
        if canonical_track.source_platform == "Spotify" or not context.spotify_access_token:
            return canonical_track, None

        spotify_url = self.spotify_target_resolver.resolve_link(canonical_track, context)
        if not spotify_url:
            return canonical_track, ResolverDiagnostic(
                code="spotify_promotion_unavailable",
                message="Fell back to source platform metadata because Spotify canonical promotion was not available.",
            )

        spotify_track_id = parse_spotify_track_id(spotify_url)
        if not spotify_track_id:
            return canonical_track, ResolverDiagnostic(
                code="spotify_promotion_malformed",
                message="Fell back to source platform metadata because Spotify promotion returned an invalid track URL.",
            )

        spotify_parsed_source = ParsedSource(
            raw_link=spotify_url,
            normalized_link=spotify_url.strip().lower(),
            platform="Spotify",
            source_url=spotify_url,
            resource_id=spotify_track_id,
        )
        try:
            spotify_canonical = self.spotify_source_adapter.fetch_canonical_track(spotify_parsed_source, context)
            promoted_track = CanonicalTrack(
                source_platform=canonical_track.source_platform,
                source_id=canonical_track.source_id,
                source_url=canonical_track.source_url,
                title=spotify_canonical.title,
                artist_name=spotify_canonical.artist_name,
                album_title=spotify_canonical.album_title,
                duration_ms=spotify_canonical.duration_ms,
                artwork_url=spotify_canonical.artwork_url,
                isrc=spotify_canonical.isrc,
            )
            return promoted_track, ResolverDiagnostic(
                code="spotify_promoted",
                message="Promoted canonical metadata to Spotify while preserving the original source platform.",
            )
        except Exception as e:
            logger.warning("Spotify canonical promotion failed: %s", e)
            return canonical_track, ResolverDiagnostic(
                code="spotify_promotion_failed",
                message="Fell back to source platform metadata because Spotify canonical promotion failed.",
            )

    @staticmethod
    def _spotify_access_token_from_cache(client_id: str | None, client_secret: str | None) -> str | None:
        if not client_id or not client_secret:
            return None

        cached_token = _spotify_token_cache.get("token")
        cached_at = _spotify_token_cache.get("fetched_at")
        if isinstance(cached_token, str) and isinstance(cached_at, (int, float)):
            if time.time() - cached_at < SPOTIFY_TOKEN_CACHE_TTL_SECONDS:
                return cached_token

        access_token = fetch_spotify_access_token(client_id, client_secret)
        _spotify_token_cache["token"] = access_token
        _spotify_token_cache["fetched_at"] = time.time()
        return access_token
