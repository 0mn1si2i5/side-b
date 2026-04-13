import json
import os
import re
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


ITUNES_SEARCH_URL = "https://itunes.apple.com/search"
ITUNES_LOOKUP_URL = "https://itunes.apple.com/lookup"


def parse_apple_music_track_id(raw_link: str) -> str | None:
    parsed_url = parse.urlparse(raw_link)
    query_track_id = parse.parse_qs(parsed_url.query).get("i", [None])[0]
    if query_track_id and query_track_id.isdigit():
        return query_track_id

    path_match = re.search(r"/(?:song|album)/[^/]+/(\d+)", parsed_url.path)
    if path_match:
        return path_match.group(1)

    id_match = re.search(r"[?&]i=(\d+)", raw_link)
    return id_match.group(1) if id_match else None


def apple_music_storefront(preferred_market: str | None) -> str:
    normalized_market = normalize_preferred_market(preferred_market)
    if normalized_market:
        return normalized_market

    configured_storefront = os.environ.get("APPLE_MUSIC_STOREFRONT", "cn").strip().lower()
    if re.fullmatch(r"[a-z]{2}", configured_storefront):
        return configured_storefront

    return "cn"


def upgrade_apple_music_artwork_url(raw_url: str | None) -> str | None:
    if not raw_url:
        return None

    return re.sub(r"/\d+x\d+bb(?=\.)", "/1200x1200bb", raw_url)


def build_apple_music_search_terms(title: str, artist_name: str, album_title: str | None) -> list[str]:
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


def fetch_itunes_candidates(search_term: str, storefront: str) -> list[dict]:
    query = parse.urlencode({"term": search_term, "entity": "song", "limit": 10, "country": storefront})
    req = request.Request(f"{ITUNES_SEARCH_URL}?{query}", method="GET")

    with request.urlopen(req, timeout=10) as response:
        payload = json.loads(response.read().decode("utf-8"))

    candidates = payload.get("results", [])
    return candidates if isinstance(candidates, list) else []


def fetch_itunes_track(track_id: str, storefront: str) -> dict:
    query = parse.urlencode({"id": track_id, "entity": "song", "country": storefront})
    req = request.Request(f"{ITUNES_LOOKUP_URL}?{query}", method="GET")

    with request.urlopen(req, timeout=10) as response:
        payload = json.loads(response.read().decode("utf-8"))

    results = payload.get("results", [])
    if not isinstance(results, list):
        raise ValueError("Invalid iTunes lookup response")

    for result in results:
        if isinstance(result, dict) and str(result.get("trackId")) == track_id:
            return result

    raise ValueError("Apple Music track not found")


def apple_music_candidate_score(
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

    candidate_title = normalize_text(candidate.get("trackName"))
    candidate_artist = normalize_text(candidate.get("artistName"))
    candidate_album = normalize_text(candidate.get("collectionName"))
    candidate_collection_artist = normalize_text(candidate.get("collectionArtistName"))

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

    candidate_duration = candidate.get("trackTimeMillis")
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

    if candidate_collection_artist and candidate_collection_artist not in ("", source_artist):
        score -= 8

    if contains_keyword(candidate_album, COMPILATION_KEYWORDS):
        score -= 24
    if contains_keyword(candidate_artist, COMPILATION_KEYWORDS):
        score -= 20

    source_has_version = contains_keyword(source_title, TITLE_VERSION_KEYWORDS)
    candidate_has_version = contains_keyword(candidate_title, TITLE_VERSION_KEYWORDS)
    if candidate_has_version and not source_has_version:
        score -= 20

    if (
        query_rank == 0
        and duration_delta is not None
        and duration_delta <= 2_000
        and not candidate_has_version
        and not contains_keyword(candidate_album, COMPILATION_KEYWORDS)
        and not contains_keyword(candidate_artist, COMPILATION_KEYWORDS)
    ):
        score += 22

    return score


def fetch_apple_music_track_url(
    *,
    source_url: str,
    title: str,
    artist_name: str,
    album_title: str | None,
    duration_ms: int | None,
    preferred_market: str | None,
    cache_store: dict,
) -> str | None:
    cached_url = read_cached_value(cache_store, cache_key_for_url(source_url, preferred_market))
    if cached_url is not CACHE_MISS:
        return cached_url if isinstance(cached_url, str) else None

    storefront = apple_music_storefront(preferred_market)
    best_url: str | None = None
    best_score = -10_000

    for search_term in build_apple_music_search_terms(title, artist_name, album_title):
        try:
            candidates = fetch_itunes_candidates(search_term, storefront)
        except Exception as exc:
            print("Apple Music search skipped:", exc)
            continue

        for query_rank, candidate in enumerate(candidates):
            candidate_url = candidate.get("trackViewUrl")
            if not isinstance(candidate_url, str) or not candidate_url.startswith("http"):
                continue

            candidate_score = apple_music_candidate_score(
                candidate,
                title=title,
                artist_name=artist_name,
                album_title=album_title,
                duration_ms=duration_ms,
                query_rank=query_rank,
            )

            if candidate_score > best_score:
                best_score = candidate_score
                best_url = candidate_url

    resolved_url = best_url if best_score >= 64 else None
    write_cached_value(cache_store, cache_key_for_url(source_url, preferred_market), resolved_url)
    return resolved_url
