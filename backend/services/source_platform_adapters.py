from models.resolver_models import CanonicalTrack, ParsedSource, ResolverContext, SourcePlatformAdapter
from resolvers.apple_music_platform import (
    apple_music_storefront,
    fetch_itunes_track,
    parse_apple_music_track_id,
    upgrade_apple_music_artwork_url,
)
from resolvers.spotify_platform import fetch_spotify_track, parse_spotify_track_id


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
        if not context.spotify_access_token:
            raise ValueError("Missing SPOTIFY_CLIENT_ID or SPOTIFY_CLIENT_SECRET")

        track_payload = fetch_spotify_track(
            context.spotify_access_token,
            parsed_source.resource_id,
            context.preferred_market,
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


def default_source_adapters() -> list[SourcePlatformAdapter]:
    return [SpotifySourceAdapter(), AppleMusicSourceAdapter()]


def select_source_adapter(raw_link: str, adapters: list[SourcePlatformAdapter] | None = None) -> SourcePlatformAdapter | None:
    for adapter in adapters or default_source_adapters():
        if adapter.can_handle(raw_link):
            return adapter

    return None
