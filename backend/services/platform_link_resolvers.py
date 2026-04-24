import json
import logging
import re
from urllib import parse, request

from app.config import settings
from models.resolver_models import CanonicalTrack, ResolverContext, TargetPlatformResolver
from platform_clients.netease_client import check_music, fetch_song_url, search_tracks
from platform_clients.qq_music_client import search_tracks as search_qq_tracks
from resolvers.apple_music_platform import fetch_apple_music_track_url
from resolvers.netease_platform import build_netease_track_url
from resolvers.qq_music_platform import build_qq_music_track_url
from resolvers.spotify_platform import fetch_spotify_track_url
from utils.resolver_common import CACHE_MISS, cache_key_for_url, normalize_preferred_market, read_cached_value, write_cached_value
from utils.resolver_common import (
    COMPILATION_KEYWORDS,
    TITLE_VERSION_KEYWORDS,
    base_title_variants,
    contains_keyword,
    normalize_text,
    text_variants,
)


logger = logging.getLogger(__name__)

SONGLINK_LINKS_URL = "https://api.song.link/v1-alpha.1/links"
SUPPORTED_AGGREGATED_PLATFORM_LABELS = {
    "qq": "QQ 音乐",
    "qqmusic": "QQ 音乐",
    "netease": "网易云音乐",
    "neteasemusic": "网易云音乐",
    "neteasecloudmusic": "网易云音乐",
}
PLATFORM_ORDER = ("Apple Music", "Spotify", "QQ 音乐", "网易云音乐")


def normalize_platform_key(raw_value: str | None) -> str:
    if not raw_value:
        return ""

    return re.sub(r"[^a-z0-9]+", "", raw_value.casefold())


def songlink_headers() -> dict[str, str]:
    return {"Accept": "application/json"}


def read_cached_aggregated_urls(context: ResolverContext, source_url: str) -> dict[str, str] | None:
    cached_urls = read_cached_value(
        context.cache_store("aggregated_platform_urls"),
        cache_key_for_url(source_url, context.preferred_market),
    )
    if cached_urls is CACHE_MISS:
        return None

    return dict(cached_urls)


def write_cached_aggregated_urls(context: ResolverContext, source_url: str, aggregated_urls: dict[str, str]) -> None:
    write_cached_value(
        context.cache_store("aggregated_platform_urls"),
        cache_key_for_url(source_url, context.preferred_market),
        dict(aggregated_urls),
    )


def fetch_aggregated_platform_urls(source_url: str, context: ResolverContext) -> dict[str, str]:
    cached_urls = read_cached_aggregated_urls(context, source_url)
    if cached_urls is not None:
        return cached_urls

    query_items = {"url": source_url}
    normalized_market = normalize_preferred_market(context.preferred_market)
    api_key = settings.SONGLINK_API_KEY.strip()

    if normalized_market:
        query_items["userCountry"] = normalized_market.upper()
    if api_key:
        query_items["key"] = api_key

    req = request.Request(
        f"{SONGLINK_LINKS_URL}?{parse.urlencode(query_items)}",
        headers=songlink_headers(),
        method="GET",
    )

    with request.urlopen(req, timeout=10) as response:
        payload = json.loads(response.read().decode("utf-8"))

    links_by_platform = payload.get("linksByPlatform")
    if not isinstance(links_by_platform, dict):
        return {}

    aggregated_urls: dict[str, str] = {}
    for raw_platform_key, platform_payload in links_by_platform.items():
        normalized_key = normalize_platform_key(raw_platform_key)
        platform_label = SUPPORTED_AGGREGATED_PLATFORM_LABELS.get(normalized_key)
        if not platform_label or not isinstance(platform_payload, dict):
            continue

        destination_url = platform_payload.get("url")
        if not isinstance(destination_url, str) or not destination_url.startswith("http"):
            continue

        aggregated_urls[platform_label] = destination_url

    write_cached_aggregated_urls(context, source_url, aggregated_urls)
    return aggregated_urls


class AppleMusicTargetResolver:
    platform = "Apple Music"

    def resolve_link(self, canonical_track: CanonicalTrack, context: ResolverContext) -> str | None:
        if canonical_track.source_platform == self.platform:
            return None

        return fetch_apple_music_track_url(
            source_url=canonical_track.source_url,
            title=canonical_track.title,
            artist_name=canonical_track.artist_name,
            album_title=canonical_track.album_title,
            duration_ms=canonical_track.duration_ms,
            preferred_market=context.preferred_market,
            cache_store=context.cache_store("apple_music_links"),
        )


class SpotifyTargetResolver:
    platform = "Spotify"

    def resolve_link(self, canonical_track: CanonicalTrack, context: ResolverContext) -> str | None:
        if canonical_track.source_platform == self.platform or not context.spotify_access_token:
            return None

        return fetch_spotify_track_url(
            source_url=canonical_track.source_url,
            title=canonical_track.title,
            artist_name=canonical_track.artist_name,
            album_title=canonical_track.album_title,
            duration_ms=canonical_track.duration_ms,
            preferred_market=context.preferred_market,
            access_token=context.spotify_access_token,
            cache_store=context.cache_store("spotify_links"),
        )


def build_netease_search_terms(title: str, artist_name: str, album_title: str | None) -> list[str]:
    terms: list[str] = []
    title_variants = [variant for base_variant in base_title_variants(title) for variant in text_variants(base_variant)]
    artist_variants = text_variants(artist_name) or [artist_name]
    album_variants = text_variants(album_title) if album_title else []

    for title_variant in title_variants:
        for artist_variant in artist_variants:
            terms.append(f"{title_variant} {artist_variant}".strip())
        for album_variant in album_variants:
            terms.append(f"{title_variant} {album_variant}".strip())
        terms.append(title_variant)

    deduplicated: list[str] = []
    seen: set[str] = set()
    for term in terms:
        normalized = normalize_text(term)
        if normalized and normalized not in seen:
            seen.add(normalized)
            deduplicated.append(term)

    return deduplicated


def build_platform_search_terms(title: str, artist_name: str, album_title: str | None) -> list[str]:
    return build_netease_search_terms(title, artist_name, album_title)


def netease_candidate_score(
    candidate: dict,
    *,
    title: str,
    artist_name: str,
    album_title: str | None,
    duration_ms: int | None,
    query_rank: int,
) -> int:
    score = 0

    source_title = normalize_text(title)
    source_title_variants = [normalize_text(value) for value in base_title_variants(title)]
    source_artist = normalize_text(artist_name)
    source_album = normalize_text(album_title)

    candidate_title = normalize_text(candidate.get("name"))
    candidate_artist = normalize_text(
        ", ".join(
            artist.get("name", "")
            for artist in candidate.get("ar", [])
            if isinstance(artist, dict)
        )
    )
    candidate_album = normalize_text(candidate.get("al", {}).get("name"))

    if candidate_title in source_title_variants:
        score += 60
    elif source_title and candidate_title and (source_title in candidate_title or candidate_title in source_title):
        score += 32

    if source_artist and candidate_artist == source_artist:
        score += 32
    elif source_artist and candidate_artist and (source_artist in candidate_artist or candidate_artist in source_artist):
        score += 14

    if source_album and candidate_album == source_album:
        score += 24
    elif source_album and candidate_album and (source_album in candidate_album or candidate_album in source_album):
        score += 12

    candidate_duration = candidate.get("dt")
    duration_delta = None
    if duration_ms and isinstance(candidate_duration, int):
        duration_delta = abs(candidate_duration - duration_ms)
        if duration_delta <= 2_000:
            score += 28
        elif duration_delta <= 5_000:
            score += 18
        elif duration_delta <= 10_000:
            score += 8

    if query_rank < 10:
        score += max(0, 18 - query_rank * 2)

    candidate_has_version = contains_keyword(candidate_title, TITLE_VERSION_KEYWORDS)
    source_has_version = contains_keyword(source_title, TITLE_VERSION_KEYWORDS)
    if candidate_has_version and not source_has_version:
        score -= 20

    if contains_keyword(candidate_album, COMPILATION_KEYWORDS):
        score -= 20

    if query_rank == 0 and duration_delta is not None and duration_delta <= 2_000 and not candidate_has_version:
        score += 22

    return score


class NeteaseTargetResolver:
    platform = "网易云音乐"

    def resolve_link(self, canonical_track: CanonicalTrack, context: ResolverContext) -> str | None:
        if canonical_track.source_platform == self.platform or not context.netease_api_base_url:
            return None

        cache_store = context.cache_store("netease_links")
        cached_url = read_cached_value(cache_store, cache_key_for_url(canonical_track.source_url, context.preferred_market))
        if cached_url is not CACHE_MISS:
            return cached_url if isinstance(cached_url, str) else None

        best_candidate: dict | None = None
        best_score = -10_000

        for search_term in build_netease_search_terms(
            canonical_track.title,
            canonical_track.artist_name,
            canonical_track.album_title,
        ):
            try:
                candidates = search_tracks(
                    context.netease_api_base_url,
                    search_term,
                    limit=10,
                    timeout_seconds=context.netease_request_timeout,
                )
            except Exception as exc:
                logger.warning("Netease search skipped: %s", exc)
                continue

            for query_rank, candidate in enumerate(candidates):
                candidate_id = candidate.get("id")
                if not isinstance(candidate_id, int):
                    continue

                candidate_score = netease_candidate_score(
                    candidate,
                    title=canonical_track.title,
                    artist_name=canonical_track.artist_name,
                    album_title=canonical_track.album_title,
                    duration_ms=canonical_track.duration_ms,
                    query_rank=query_rank,
                )

                try:
                    playable = check_music(
                        context.netease_api_base_url,
                        str(candidate_id),
                        context.netease_request_timeout,
                    )
                    if playable is True:
                        candidate_score += 6
                    elif playable is False:
                        candidate_score -= 8
                except Exception:
                    pass

                try:
                    preview_url = fetch_song_url(
                        context.netease_api_base_url,
                        str(candidate_id),
                        timeout_seconds=context.netease_request_timeout,
                    )
                    if preview_url:
                        candidate_score += 4
                except Exception:
                    pass

                if candidate_score > best_score:
                    best_score = candidate_score
                    best_candidate = candidate

        resolved_url = None
        if best_candidate is not None and best_score >= 64:
            resolved_url = build_netease_track_url(str(best_candidate["id"]))

        write_cached_value(cache_store, cache_key_for_url(canonical_track.source_url, context.preferred_market), resolved_url)
        return resolved_url


def qq_candidate_score(
    candidate: dict,
    *,
    title: str,
    artist_name: str,
    album_title: str | None,
    duration_ms: int | None,
    query_rank: int,
) -> int:
    score = 0

    source_title = normalize_text(title)
    source_title_variants = [normalize_text(value) for value in base_title_variants(title)]
    source_artist = normalize_text(artist_name)
    source_album = normalize_text(album_title)

    candidate_title = normalize_text(candidate.get("title"))
    candidate_artist = normalize_text(candidate.get("artist_name"))
    candidate_album = normalize_text(candidate.get("album_title"))

    if candidate_title in source_title_variants:
        score += 60
    elif source_title and candidate_title and (source_title in candidate_title or candidate_title in source_title):
        score += 32

    if source_artist and candidate_artist == source_artist:
        score += 32
    elif source_artist and candidate_artist and (source_artist in candidate_artist or candidate_artist in source_artist):
        score += 14

    if source_album and candidate_album == source_album:
        score += 24
    elif source_album and candidate_album and (source_album in candidate_album or candidate_album in source_album):
        score += 12

    candidate_duration = candidate.get("duration_ms")
    duration_delta = None
    if duration_ms and isinstance(candidate_duration, int):
        duration_delta = abs(candidate_duration - duration_ms)
        if duration_delta <= 2_000:
            score += 28
        elif duration_delta <= 5_000:
            score += 18
        elif duration_delta <= 10_000:
            score += 8

    if query_rank < 10:
        score += max(0, 18 - query_rank * 2)

    candidate_has_version = contains_keyword(candidate_title, TITLE_VERSION_KEYWORDS)
    source_has_version = contains_keyword(source_title, TITLE_VERSION_KEYWORDS)
    if candidate_has_version and not source_has_version:
        score -= 20

    if contains_keyword(candidate_album, COMPILATION_KEYWORDS):
        score -= 20

    if query_rank == 0 and duration_delta is not None and duration_delta <= 2_000 and not candidate_has_version:
        score += 22

    return score


class QQMusicTargetResolver:
    platform = "QQ 音乐"

    def resolve_link(self, canonical_track: CanonicalTrack, context: ResolverContext) -> str | None:
        if canonical_track.source_platform == self.platform:
            return None

        cache_store = context.cache_store("qq_music_links")
        cached_url = read_cached_value(cache_store, cache_key_for_url(canonical_track.source_url, context.preferred_market))
        if cached_url is not CACHE_MISS:
            return cached_url if isinstance(cached_url, str) else None

        best_candidate: dict | None = None
        best_score = -10_000

        for search_term in build_platform_search_terms(
            canonical_track.title,
            canonical_track.artist_name,
            canonical_track.album_title,
        ):
            try:
                candidates = search_qq_tracks(search_term, limit=10)
            except Exception as exc:
                logger.warning("QQ Music search skipped: %s", exc)
                continue

            for query_rank, candidate in enumerate(candidates):
                candidate_mid = candidate.get("mid")
                if not isinstance(candidate_mid, str) or not candidate_mid:
                    continue

                candidate_score = qq_candidate_score(
                    candidate,
                    title=canonical_track.title,
                    artist_name=canonical_track.artist_name,
                    album_title=canonical_track.album_title,
                    duration_ms=canonical_track.duration_ms,
                    query_rank=query_rank,
                )

                if candidate_score > best_score:
                    best_score = candidate_score
                    best_candidate = candidate

        resolved_url = None
        if best_candidate is not None and best_score >= 64:
            resolved_url = build_qq_music_track_url(best_candidate["mid"])

        write_cached_value(cache_store, cache_key_for_url(canonical_track.source_url, context.preferred_market), resolved_url)
        return resolved_url


class AggregatedTargetResolver:
    def __init__(self, platform: str) -> None:
        self.platform = platform

    def resolve_link(self, canonical_track: CanonicalTrack, context: ResolverContext) -> str | None:
        if canonical_track.source_platform == self.platform:
            return None

        try:
            aggregated_urls = fetch_aggregated_platform_urls(canonical_track.source_url, context)
        except Exception as exc:
            logger.warning("Songlink mapping skipped: %s", exc)
            return None

        return aggregated_urls.get(self.platform)


def default_target_resolvers() -> list[TargetPlatformResolver]:
    return [
        AppleMusicTargetResolver(),
        SpotifyTargetResolver(),
        NeteaseTargetResolver(),
        QQMusicTargetResolver(),
    ]


def resolve_platform_link(
    canonical_track: CanonicalTrack,
    context: ResolverContext,
    target_platform: str,
    resolvers: list[TargetPlatformResolver] | None = None,
) -> dict | None:
    if target_platform == canonical_track.source_platform:
        return {
            "platform": canonical_track.source_platform,
            "destinationURL": canonical_track.source_url,
            "isSource": True,
        }

    target_resolvers = resolvers or default_target_resolvers()
    resolver = next((resolver for resolver in target_resolvers if resolver.platform == target_platform), None)
    if resolver is None:
        return None

    resolved_url = resolver.resolve_link(canonical_track, context)
    if not resolved_url:
        return None

    return {
        "platform": target_platform,
        "destinationURL": resolved_url,
        "isSource": False,
    }


def resolve_platform_links(
    canonical_track: CanonicalTrack,
    context: ResolverContext,
    resolvers: list[TargetPlatformResolver] | None = None,
) -> list[dict]:
    target_resolvers = resolvers or default_target_resolvers()
    resolved_urls: dict[str, str] = {}

    for resolver in target_resolvers:
        try:
            resolved_url = resolver.resolve_link(canonical_track, context)
        except Exception as exc:
            logger.warning("%s mapping skipped: %s", resolver.platform, exc)
            continue

        if resolved_url:
            resolved_urls[resolver.platform] = resolved_url

    platform_links = [
        {
            "platform": canonical_track.source_platform,
            "destinationURL": canonical_track.source_url,
            "isSource": True,
        }
    ]

    for platform in PLATFORM_ORDER:
        if platform == canonical_track.source_platform:
            continue

        destination_url = resolved_urls.get(platform)
        if not destination_url:
            continue

        platform_links.append(
            {
                "platform": platform,
                "destinationURL": destination_url,
                "isSource": False,
            }
        )

    return platform_links
