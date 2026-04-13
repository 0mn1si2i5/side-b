import json
import os
import re
from urllib import parse, request

from models.resolver_models import CanonicalTrack, ResolverContext, TargetPlatformResolver
from resolvers.apple_music_platform import fetch_apple_music_track_url
from resolvers.spotify_platform import fetch_spotify_track_url
from utils.resolver_common import CACHE_MISS, cache_key_for_url, normalize_preferred_market, read_cached_value, write_cached_value


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
    api_key = os.environ.get("SONGLINK_API_KEY", "").strip()

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


class AggregatedTargetResolver:
    def __init__(self, platform: str) -> None:
        self.platform = platform

    def resolve_link(self, canonical_track: CanonicalTrack, context: ResolverContext) -> str | None:
        if canonical_track.source_platform == self.platform:
            return None

        try:
            aggregated_urls = fetch_aggregated_platform_urls(canonical_track.source_url, context)
        except Exception as exc:
            print("Songlink mapping skipped:", exc)
            return None

        return aggregated_urls.get(self.platform)


def default_target_resolvers() -> list[TargetPlatformResolver]:
    return [
        AppleMusicTargetResolver(),
        SpotifyTargetResolver(),
        AggregatedTargetResolver("QQ 音乐"),
        AggregatedTargetResolver("网易云音乐"),
    ]


def resolve_platform_links(
    canonical_track: CanonicalTrack,
    context: ResolverContext,
    resolvers: list[TargetPlatformResolver] | None = None,
) -> list[dict]:
    target_resolvers = resolvers or default_target_resolvers()
    resolved_urls: dict[str, str] = {}

    for resolver in target_resolvers:
        resolved_url = resolver.resolve_link(canonical_track, context)
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
