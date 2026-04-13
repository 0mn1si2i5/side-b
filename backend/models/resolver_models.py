from dataclasses import dataclass, field
from typing import Protocol


@dataclass(frozen=True)
class ParsedSource:
    raw_link: str
    normalized_link: str
    platform: str
    source_url: str
    resource_id: str
    resource_kind: str = "track"


@dataclass(frozen=True)
class CanonicalTrack:
    source_platform: str
    source_id: str
    source_url: str
    title: str
    artist_name: str
    album_title: str | None
    duration_ms: int | None
    artwork_url: str | None
    isrc: str | None


@dataclass
class ResolverContext:
    preferred_market: str | None
    spotify_access_token: str | None = None
    cache_stores: dict[str, dict] = field(default_factory=dict)

    def cache_store(self, name: str) -> dict:
        cache_store = self.cache_stores.get(name)
        if cache_store is None:
            cache_store = {}
            self.cache_stores[name] = cache_store
        return cache_store


class SourcePlatformAdapter(Protocol):
    platform: str

    def can_handle(self, raw_link: str) -> bool: ...

    def parse_source_link(self, raw_link: str) -> ParsedSource | None: ...

    def fetch_canonical_track(self, parsed_source: ParsedSource, context: ResolverContext) -> CanonicalTrack: ...


class TargetPlatformResolver(Protocol):
    platform: str

    def resolve_link(self, canonical_track: CanonicalTrack, context: ResolverContext) -> str | None: ...
