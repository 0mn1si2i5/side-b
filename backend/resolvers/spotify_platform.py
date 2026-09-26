import base64
import json
import logging
from html.parser import HTMLParser
from urllib import parse, request

from utils.resolver_common import (
    COMPILATION_KEYWORDS,
    TITLE_VERSION_KEYWORDS,
    base_title_variants,
    cache_key_for_url,
    contains_keyword,
    normalize_preferred_market,
    normalize_text,
    read_cached_value,
    text_variants,
    write_cached_value,
    CACHE_MISS,
)


logger = logging.getLogger(__name__)

SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token"
SPOTIFY_TRACK_URL = "https://api.spotify.com/v1/tracks/{track_id}"
SPOTIFY_SEARCH_URL = "https://api.spotify.com/v1/search"
SPOTIFY_TRACK_PAGE_URL = "https://open.spotify.com/track/{track_id}"


class _SpotifyMetadataParser(HTMLParser):
    def __init__(self) -> None:
        super().__init__()
        self.values: dict[str, str] = {}

    def handle_starttag(self, tag: str, attrs: list[tuple[str, str | None]]) -> None:
        if tag != "meta":
            return
        values = dict(attrs)
        key = values.get("property") or values.get("name")
        content = values.get("content")
        if key and content and key not in self.values:
            self.values[key] = content


def parse_spotify_track_id(raw_link: str) -> str | None:
    import re

    match = re.search(r"track[/:]([A-Za-z0-9]+)", raw_link)
    return match.group(1) if match else None


def fetch_spotify_access_token(client_id: str, client_secret: str) -> str:
    credentials = f"{client_id}:{client_secret}".encode("utf-8")
    authorization = base64.b64encode(credentials).decode("utf-8")
    body = parse.urlencode({"grant_type": "client_credentials"}).encode("utf-8")

    req = request.Request(
        SPOTIFY_TOKEN_URL,
        data=body,
        headers={
            "Authorization": f"Basic {authorization}",
            "Content-Type": "application/x-www-form-urlencoded",
        },
        method="POST",
    )

    with request.urlopen(req, timeout=10) as response:
        payload = json.loads(response.read().decode("utf-8"))
        return payload["access_token"]


def fetch_spotify_track(access_token: str, track_id: str, market: str | None) -> dict:
    query = ""
    if market:
        query = "?" + parse.urlencode({"market": market})

    req = request.Request(
        SPOTIFY_TRACK_URL.format(track_id=track_id) + query,
        headers={"Authorization": f"Bearer {access_token}"},
        method="GET",
    )

    with request.urlopen(req, timeout=10) as response:
        return json.loads(response.read().decode("utf-8"))


def fetch_spotify_public_metadata(track_id: str) -> dict:
    """Read Spotify's public track metadata when API credentials are unavailable."""
    req = request.Request(
        SPOTIFY_TRACK_PAGE_URL.format(track_id=parse.quote(track_id, safe="")),
        headers={"Accept": "text/html", "User-Agent": "SideBResolver/1.0"},
        method="GET",
    )
    with request.urlopen(req, timeout=10) as response:
        parser = _SpotifyMetadataParser()
        parser.feed(response.read().decode("utf-8"))

    title = parser.values.get("og:title")
    artist_name = parser.values.get("music:musician_description")
    if not title or not artist_name:
        raise ValueError("Spotify public metadata omitted title or artist")
    description_parts = [
        part.strip() for part in parser.values.get("og:description", "").split("·")
    ]
    album_title = description_parts[1] if len(description_parts) >= 3 else None
    duration_seconds = parser.values.get("music:duration")
    return {
        "name": title,
        "artists": [{"name": artist_name}],
        "album": {
            "name": album_title,
            "images": ([{"url": parser.values["og:image"]}]
                       if parser.values.get("og:image") else []),
        },
        "duration_ms": (round(float(duration_seconds) * 1000)
                        if duration_seconds else None),
        "external_urls": {"spotify": SPOTIFY_TRACK_PAGE_URL.format(track_id=track_id)},
        "external_ids": {},
    }


def fetch_spotify_search_candidates(
    access_token: str,
    query_text: str,
    market: str | None,
) -> list[dict]:
    query_items = {"q": query_text, "type": "track", "limit": 10}
    if market:
        query_items["market"] = market.upper()

    req = request.Request(
        f"{SPOTIFY_SEARCH_URL}?{parse.urlencode(query_items)}",
        headers={"Authorization": f"Bearer {access_token}"},
        method="GET",
    )

    with request.urlopen(req, timeout=10) as response:
        payload = json.loads(response.read().decode("utf-8"))

    items = payload.get("tracks", {}).get("items", [])
    return items if isinstance(items, list) else []


def build_spotify_search_terms(title: str, artist_name: str, album_title: str | None) -> list[str]:
    terms: list[str] = []
    title_variants = [variant for base_variant in base_title_variants(title) for variant in text_variants(base_variant)]
    artist_variants = text_variants(artist_name) or [artist_name]
    album_variants = text_variants(album_title) if album_title else []

    for title_variant in title_variants:
        for artist_variant in artist_variants:
            terms.append(f'track:"{title_variant}" artist:"{artist_variant}"')
            terms.append(f"{title_variant} {artist_variant}")
        for album_variant in album_variants:
            terms.append(f'track:"{title_variant}" album:"{album_variant}"')

    deduplicated: list[str] = []
    seen: set[str] = set()
    for term in terms:
        normalized = normalize_text(term)
        if normalized and normalized not in seen:
            seen.add(normalized)
            deduplicated.append(term)

    return deduplicated


def spotify_search_markets(preferred_market: str | None) -> list[str | None]:
    normalized_market = normalize_preferred_market(preferred_market)
    fallback_markets: list[str | None] = [normalized_market, None]

    if normalized_market == "cn":
        fallback_markets.extend(["tw", "us"])
    elif normalized_market and normalized_market != "tw":
        fallback_markets.append("tw")

    deduplicated: list[str | None] = []
    seen: set[str] = set()
    for value in fallback_markets:
        marker = value or "_none_"
        if marker in seen:
            continue
        seen.add(marker)
        deduplicated.append(value)

    return deduplicated


def spotify_candidate_score(
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
    candidate_artist = normalize_text(", ".join(artist.get("name", "") for artist in candidate.get("artists", [])))
    candidate_album = normalize_text(candidate.get("album", {}).get("name"))

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


def fetch_spotify_track_url(
    *,
    source_url: str,
    title: str,
    artist_name: str,
    album_title: str | None,
    duration_ms: int | None,
    preferred_market: str | None,
    access_token: str,
    cache_store: dict,
) -> str | None:
    cached_url = read_cached_value(cache_store, cache_key_for_url(source_url, preferred_market))
    if cached_url is not CACHE_MISS:
        return cached_url if isinstance(cached_url, str) else None

    best_url: str | None = None
    best_score = -10_000

    for search_term in build_spotify_search_terms(title, artist_name, album_title):
        for search_market in spotify_search_markets(preferred_market):
            try:
                candidates = fetch_spotify_search_candidates(access_token, search_term, search_market)
            except Exception as exc:
                logger.warning("Spotify search skipped: %s", exc)
                continue

            for query_rank, candidate in enumerate(candidates):
                candidate_url = candidate.get("external_urls", {}).get("spotify")
                if not isinstance(candidate_url, str) or not candidate_url.startswith("http"):
                    continue

                candidate_score = spotify_candidate_score(
                    candidate,
                    title=title,
                    artist_name=artist_name,
                    album_title=album_title,
                    duration_ms=duration_ms,
                    query_rank=query_rank,
                )

                if search_market is None:
                    candidate_score += 4
                elif search_market == "tw":
                    candidate_score += 2

                if candidate_score > best_score:
                    best_score = candidate_score
                    best_url = candidate_url

    resolved_url = best_url if best_score >= 64 else None
    write_cached_value(cache_store, cache_key_for_url(source_url, preferred_market), resolved_url)
    return resolved_url
