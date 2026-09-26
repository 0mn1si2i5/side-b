from models.resolver_models import CanonicalTrack, ParsedSource, ResolverContext, SourcePlatformAdapter
from platform_clients.netease_client import fetch_track_detail
from platform_clients.qq_music_client import fetch_track_detail as fetch_qq_track_detail
from resolvers.apple_music_platform import (
    apple_music_storefront,
    fetch_itunes_track,
    parse_apple_music_track_id,
    upgrade_apple_music_artwork_url,
)
from resolvers.netease_platform import build_netease_track_url, parse_netease_track_id
from resolvers.qq_music_platform import build_qq_music_track_url, parse_qq_music_track_id
from resolvers.spotify_platform import (
    fetch_spotify_public_metadata,
    fetch_spotify_track,
    parse_spotify_track_id,
)


def normalize_link(raw_link: str) -> str:
    return raw_link.strip().lower()


class SpotifySourceAdapter:
    platform = "Spotify"

    def can_handle(self, raw_link: str) -> bool:
        return "spotify" in normalize_link(raw_link)

    def parse_source_link(self, raw_link: str) -> ParsedSource | None:
        track_id = parse_spotify_track_id(raw_link)
        if not track_id:
            return None

        return ParsedSource(
            raw_link=raw_link,
            normalized_link=normalize_link(raw_link),
            platform=self.platform,
            source_url=raw_link,
            resource_id=track_id,
        )

    def fetch_canonical_track(self, parsed_source: ParsedSource, context: ResolverContext) -> CanonicalTrack:
        track_payload = (
            fetch_spotify_track(
                context.spotify_access_token,
                parsed_source.resource_id,
                context.preferred_market,
            )
            if context.spotify_access_token
            else fetch_spotify_public_metadata(parsed_source.resource_id)
        )
        images = track_payload.get("album", {}).get("images", [])
        artwork_url = images[0].get("url") if images else None

        return CanonicalTrack(
            source_platform=self.platform,
            source_id=parsed_source.resource_id,
            source_url=track_payload.get("external_urls", {}).get("spotify", parsed_source.raw_link),
            title=track_payload["name"],
            artist_name=", ".join(artist["name"] for artist in track_payload.get("artists", [])),
            album_title=track_payload.get("album", {}).get("name"),
            duration_ms=track_payload.get("duration_ms"),
            artwork_url=artwork_url,
            isrc=track_payload.get("external_ids", {}).get("isrc"),
        )


class AppleMusicSourceAdapter:
    platform = "Apple Music"

    def can_handle(self, raw_link: str) -> bool:
        normalized_link = normalize_link(raw_link)
        return "music.apple.com" in normalized_link or "itunes.apple.com" in normalized_link

    def parse_source_link(self, raw_link: str) -> ParsedSource | None:
        track_id = parse_apple_music_track_id(raw_link)
        if not track_id:
            return None

        return ParsedSource(
            raw_link=raw_link,
            normalized_link=normalize_link(raw_link),
            platform=self.platform,
            source_url=raw_link,
            resource_id=track_id,
        )

    def fetch_canonical_track(self, parsed_source: ParsedSource, context: ResolverContext) -> CanonicalTrack:
        storefront = apple_music_storefront(context.preferred_market)
        track_payload = fetch_itunes_track(parsed_source.resource_id, storefront)
        artwork_url = upgrade_apple_music_artwork_url(
            track_payload.get("artworkUrl100")
            or track_payload.get("artworkUrl60")
            or track_payload.get("artworkUrl30")
        )

        return CanonicalTrack(
            source_platform=self.platform,
            source_id=parsed_source.resource_id,
            source_url=track_payload.get("trackViewUrl", parsed_source.raw_link),
            title=track_payload.get("trackName"),
            artist_name=track_payload.get("artistName"),
            album_title=track_payload.get("collectionName"),
            duration_ms=track_payload.get("trackTimeMillis"),
            artwork_url=artwork_url,
            isrc=None,
        )


class NeteaseSourceAdapter:
    platform = "网易云音乐"

    def can_handle(self, raw_link: str) -> bool:
        normalized_link = normalize_link(raw_link)
        return (
            "music.163.com" in normalized_link
            or "y.music.163.com" in normalized_link
            or "163cn.tv" in normalized_link
        )

    def parse_source_link(self, raw_link: str) -> ParsedSource | None:
        track_id = parse_netease_track_id(raw_link)
        if not track_id:
            return None

        return ParsedSource(
            raw_link=raw_link,
            normalized_link=normalize_link(raw_link),
            platform=self.platform,
            source_url=build_netease_track_url(track_id),
            resource_id=track_id,
        )

    def fetch_canonical_track(self, parsed_source: ParsedSource, context: ResolverContext) -> CanonicalTrack:
        if not context.netease_api_base_url:
            raise ValueError("Missing NETEASE_API_BASE_URL")

        track_payload = fetch_track_detail(
            context.netease_api_base_url,
            parsed_source.resource_id,
            context.netease_request_timeout,
        )
        album_payload = track_payload.get("al", {})
        artist_payloads = track_payload.get("ar", [])
        artwork_url = album_payload.get("picUrl") if isinstance(album_payload, dict) else None

        return CanonicalTrack(
            source_platform=self.platform,
            source_id=parsed_source.resource_id,
            source_url=build_netease_track_url(parsed_source.resource_id),
            title=track_payload.get("name"),
            artist_name=", ".join(
                artist.get("name", "")
                for artist in artist_payloads
                if isinstance(artist, dict) and artist.get("name")
            ),
            album_title=album_payload.get("name") if isinstance(album_payload, dict) else None,
            duration_ms=track_payload.get("dt"),
            artwork_url=artwork_url if isinstance(artwork_url, str) else None,
            isrc=None,
        )


class QQMusicSourceAdapter:
    platform = "QQ 音乐"

    def can_handle(self, raw_link: str) -> bool:
        normalized_link = normalize_link(raw_link)
        return (
            "y.qq.com" in normalized_link
            or "qqmusic.qq.com" in normalized_link
            or "c6.y.qq.com" in normalized_link
            or "ryqq" in normalized_link
        )

    def parse_source_link(self, raw_link: str) -> ParsedSource | None:
        track_mid = parse_qq_music_track_id(raw_link)
        if not track_mid:
            return None

        return ParsedSource(
            raw_link=raw_link,
            normalized_link=normalize_link(raw_link),
            platform=self.platform,
            source_url=build_qq_music_track_url(track_mid),
            resource_id=track_mid,
        )

    def fetch_canonical_track(self, parsed_source: ParsedSource, context: ResolverContext) -> CanonicalTrack:
        track_payload = fetch_qq_track_detail(parsed_source.resource_id)

        return CanonicalTrack(
            source_platform=self.platform,
            source_id=parsed_source.resource_id,
            source_url=build_qq_music_track_url(parsed_source.resource_id),
            title=track_payload.get("title"),
            artist_name=track_payload.get("artist_name"),
            album_title=track_payload.get("album_title"),
            duration_ms=track_payload.get("duration_ms"),
            artwork_url=track_payload.get("artwork_url"),
            isrc=track_payload.get("isrc"),
        )


def default_source_adapters() -> list[SourcePlatformAdapter]:
    return [SpotifySourceAdapter(), AppleMusicSourceAdapter(), NeteaseSourceAdapter(), QQMusicSourceAdapter()]


def select_source_adapter(raw_link: str, adapters: list[SourcePlatformAdapter] | None = None) -> SourcePlatformAdapter | None:
    for adapter in adapters or default_source_adapters():
        if adapter.can_handle(raw_link):
            return adapter

    return None
