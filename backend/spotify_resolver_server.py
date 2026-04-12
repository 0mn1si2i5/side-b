#!/usr/bin/env python3
import base64
import json
import os
import re
import sys
import time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib import error, parse, request

VENDOR_PATH = os.path.join(os.path.dirname(__file__), "vendor")
if os.path.isdir(VENDOR_PATH) and VENDOR_PATH not in sys.path:
    sys.path.insert(0, VENDOR_PATH)

try:
    from opencc_purepy import OpenCC
except ImportError:
    OpenCC = None


SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token"
SPOTIFY_TRACK_URL = "https://api.spotify.com/v1/tracks/{track_id}"
ITUNES_SEARCH_URL = "https://itunes.apple.com/search"
SONGLINK_LINKS_URL = "https://api.song.link/v1-alpha.1/links"
ENV_FILE_PATH = os.path.join(os.path.dirname(__file__), ".env")
SUPPORTED_PLATFORM_LABELS = {
    "spotify": "Spotify",
    "applemusic": "Apple Music",
    "itunes": "Apple Music",
    "qq": "QQ 音乐",
    "qqmusic": "QQ 音乐",
    "netease": "网易云音乐",
    "neteasemusic": "网易云音乐",
    "neteasecloudmusic": "网易云音乐",
}
AGGREGATED_LINK_CACHE: dict[tuple[str, str | None], tuple[float, dict[str, str]]] = {}
APPLE_MUSIC_LINK_CACHE: dict[tuple[str, str | None], tuple[float, str | None]] = {}
CACHE_TTL_SECONDS = 15 * 60
CACHE_MISS = object()
TITLE_VERSION_KEYWORDS = (
    "live",
    "remix",
    "mix",
    "acoustic",
    "karaoke",
    "instrumental",
    "commentary",
    "radio edit",
    "sped up",
    "slowed",
)
COMPILATION_KEYWORDS = (
    "various artists",
    "群星",
    "合辑",
    "精选",
    "hits",
    "best of",
    "workout",
    "karaoke",
)
T2S_CONVERTER = OpenCC("t2s") if OpenCC else None
S2T_CONVERTER = OpenCC("s2t") if OpenCC else None


def load_dotenv(env_file_path: str = ENV_FILE_PATH) -> None:
    if not os.path.exists(env_file_path):
        return

    with open(env_file_path, "r", encoding="utf-8") as env_file:
        for raw_line in env_file:
            line = raw_line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue

            key, value = line.split("=", 1)
            os.environ.setdefault(key.strip(), value.strip())


def parse_spotify_track_id(raw_link: str) -> str | None:
    match = re.search(r"track[/:]([A-Za-z0-9]+)", raw_link)
    return match.group(1) if match else None


def normalize_link(raw_link: str) -> str:
    return raw_link.strip().lower()


def normalize_platform_key(raw_value: str | None) -> str:
    if not raw_value:
        return ""

    return re.sub(r"[^a-z0-9]+", "", raw_value.casefold())


def normalize_preferred_market(preferred_market: str | None) -> str | None:
    if not preferred_market:
        return None

    normalized = preferred_market.strip().lower()
    if re.fullmatch(r"[a-z]{2}", normalized):
        return normalized

    return None


def apple_music_storefront(preferred_market: str | None) -> str:
    normalized_market = normalize_preferred_market(preferred_market)
    if normalized_market:
        return normalized_market

    configured_storefront = os.environ.get("APPLE_MUSIC_STOREFRONT", "cn").strip().lower()
    if re.fullmatch(r"[a-z]{2}", configured_storefront):
        return configured_storefront

    return "cn"


def convert_chinese_text(raw_value: str, converter) -> str:
    if not raw_value or converter is None:
        return raw_value

    return converter.convert(raw_value)


def text_variants(raw_value: str | None) -> list[str]:
    if not raw_value:
        return []

    variants = [
        raw_value,
        convert_chinese_text(raw_value, T2S_CONVERTER),
        convert_chinese_text(raw_value, S2T_CONVERTER),
    ]

    deduplicated: list[str] = []
    seen: set[str] = set()
    for value in variants:
        cleaned = value.strip()
        if not cleaned or cleaned in seen:
            continue
        seen.add(cleaned)
        deduplicated.append(cleaned)

    return deduplicated


def normalize_text(raw_value: str | None) -> str:
    if not raw_value:
        return ""

    normalized = convert_chinese_text(raw_value, T2S_CONVERTER).casefold()
    normalized = re.sub(r"\([^)]*\)", " ", normalized)
    normalized = re.sub(r"\[[^\]]*\]", " ", normalized)
    normalized = re.sub(r"[^a-z0-9\u4e00-\u9fff]+", " ", normalized)
    return re.sub(r"\s+", " ", normalized).strip()


def base_title_variants(title: str) -> list[str]:
    variants = [title.strip()]
    stripped_title = re.sub(r"\s*[\(\[].*?[\)\]]\s*", " ", title).strip()
    if stripped_title:
        variants.append(stripped_title)

    deduplicated: list[str] = []
    seen: set[str] = set()
    for value in variants:
        normalized = normalize_text(value)
        if normalized and normalized not in seen:
            seen.add(normalized)
            deduplicated.append(value)

    return deduplicated


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


def read_cached_value(cache_store: dict, cache_key: tuple[str, str | None]):
    cached_entry = cache_store.get(cache_key)
    if not cached_entry:
        return CACHE_MISS

    cached_at, cached_value = cached_entry
    if time.time() - cached_at > CACHE_TTL_SECONDS:
        cache_store.pop(cache_key, None)
        return CACHE_MISS

    return cached_value


def write_cached_value(cache_store: dict, cache_key: tuple[str, str | None], cached_value) -> None:
    cache_store[cache_key] = (time.time(), cached_value)


def cache_key_for_url(source_url: str, preferred_market: str | None) -> tuple[str, str | None]:
    return (source_url, normalize_preferred_market(preferred_market))


def read_cached_apple_music_url(source_url: str, preferred_market: str | None):
    return read_cached_value(APPLE_MUSIC_LINK_CACHE, cache_key_for_url(source_url, preferred_market))


def write_cached_apple_music_url(source_url: str, preferred_market: str | None, apple_music_url: str | None) -> None:
    write_cached_value(APPLE_MUSIC_LINK_CACHE, cache_key_for_url(source_url, preferred_market), apple_music_url)


def fetch_itunes_candidates(search_term: str, storefront: str) -> list[dict]:
    query = parse.urlencode(
        {
            "term": search_term,
            "entity": "song",
            "limit": 10,
            "country": storefront,
        }
    )
    req = request.Request(f"{ITUNES_SEARCH_URL}?{query}", method="GET")

    with request.urlopen(req, timeout=10) as response:
        payload = json.loads(response.read().decode("utf-8"))

    candidates = payload.get("results", [])
    return candidates if isinstance(candidates, list) else []


def contains_keyword(value: str, keywords: tuple[str, ...]) -> bool:
    return any(keyword in value for keyword in keywords)


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
    elif source_artist and candidate_artist and (
        source_artist in candidate_artist or candidate_artist in source_artist
    ):
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
) -> str | None:
    cached_url = read_cached_apple_music_url(source_url, preferred_market)
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
    write_cached_apple_music_url(source_url, preferred_market, resolved_url)
    return resolved_url


def songlink_headers() -> dict[str, str]:
    return {"Accept": "application/json"}


def songlink_cache_key(source_url: str, preferred_market: str | None) -> tuple[str, str | None]:
    return cache_key_for_url(source_url, preferred_market)


def read_cached_aggregated_urls(source_url: str, preferred_market: str | None) -> dict[str, str] | None:
    cached_urls = read_cached_value(AGGREGATED_LINK_CACHE, songlink_cache_key(source_url, preferred_market))
    if cached_urls is CACHE_MISS:
        return None

    return dict(cached_urls)


def write_cached_aggregated_urls(source_url: str, preferred_market: str | None, aggregated_urls: dict[str, str]) -> None:
    write_cached_value(AGGREGATED_LINK_CACHE, songlink_cache_key(source_url, preferred_market), dict(aggregated_urls))


def fetch_aggregated_platform_urls(source_url: str, preferred_market: str | None) -> dict[str, str]:
    cached_urls = read_cached_aggregated_urls(source_url, preferred_market)
    if cached_urls is not None:
        return cached_urls

    query_items = {"url": source_url}
    normalized_market = normalize_preferred_market(preferred_market)
    api_key = os.environ.get("SONGLINK_API_KEY", "").strip()

    if normalized_market:
        query_items["userCountry"] = normalized_market.upper()
    if api_key:
        query_items["key"] = api_key

    query = parse.urlencode(query_items)
    req = request.Request(
        f"{SONGLINK_LINKS_URL}?{query}",
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
        platform_label = SUPPORTED_PLATFORM_LABELS.get(normalized_key)
        if not platform_label or not isinstance(platform_payload, dict):
            continue

        destination_url = platform_payload.get("url")
        if not isinstance(destination_url, str) or not destination_url.startswith("http"):
            continue

        aggregated_urls[platform_label] = destination_url

    write_cached_aggregated_urls(source_url, preferred_market, aggregated_urls)
    return aggregated_urls


def build_platform_links(
    source_url: str,
    source_platform: str,
    title: str,
    artist_name: str,
    album_title: str | None,
    duration_ms: int | None,
    preferred_market: str | None,
) -> list[dict]:
    links = [
        {
            "platform": source_platform,
            "destinationURL": source_url,
            "isSource": True,
        }
    ]
    apple_music_url = None
    if source_platform != "Apple Music":
        apple_music_url = fetch_apple_music_track_url(
            source_url=source_url,
            title=title,
            artist_name=artist_name,
            album_title=album_title,
            duration_ms=duration_ms,
            preferred_market=preferred_market,
        )

    if apple_music_url:
        links.append(
            {
                "platform": "Apple Music",
                "destinationURL": apple_music_url,
                "isSource": False,
            }
        )

    try:
        aggregated_urls = fetch_aggregated_platform_urls(
            source_url=source_url,
            preferred_market=preferred_market,
        )
    except Exception as exc:
        print("Songlink mapping skipped:", exc)
        aggregated_urls = {}

    for platform_label in ("QQ 音乐", "网易云音乐"):
        if platform_label == source_platform:
            continue

        destination_url = aggregated_urls.get(platform_label)
        if not destination_url:
            continue

        links.append(
            {
                "platform": platform_label,
                "destinationURL": destination_url,
                "isSource": False,
            }
        )

    return links


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


def build_parsed_result(raw_link: str, track_id: str | None, source_platform: str) -> dict:
    parsed_link = {
        "originalLink": raw_link,
        "normalizedLink": normalize_link(raw_link),
        "platform": source_platform,
        "sourceURL": raw_link,
        "resourceID": track_id,
        "resourceKind": "track",
    }

    if track_id:
        return {"type": "parsed", "parsedLink": parsed_link}

    return {"type": "missingResourceID", "partialLink": parsed_link}


def build_resolver_response(raw_link: str, track_payload: dict, track_id: str, preferred_market: str | None) -> dict:
    source_platform = "Spotify"
    title = track_payload["name"]
    artist_name = ", ".join(artist["name"] for artist in track_payload.get("artists", []))
    album_title = track_payload.get("album", {}).get("name")
    duration_ms = track_payload.get("duration_ms")
    artwork_url = None

    images = track_payload.get("album", {}).get("images", [])
    if images:
        artwork_url = images[0].get("url")

    external_url = track_payload.get("external_urls", {}).get("spotify", raw_link)
    isrc = track_payload.get("external_ids", {}).get("isrc")
    platform_links = build_platform_links(
        source_url=external_url,
        source_platform=source_platform,
        title=title,
        artist_name=artist_name,
        album_title=album_title,
        duration_ms=duration_ms,
        preferred_market=preferred_market,
    )

    track = {
        "title": title,
        "artistName": artist_name,
        "albumTitle": album_title,
        "durationMS": duration_ms,
        "sourcePlatform": source_platform,
        "sourcePlatformID": track_id,
        "sourceURL": external_url,
        "isrc": isrc,
        "artworkURL": artwork_url,
    }

    resolved_track = {
        "track": track,
        "sourcePlatform": source_platform,
        "sourceURL": external_url,
        "sourceResourceID": track_id,
        "platformLinks": platform_links,
    }

    return {
        "resolvedTrack": resolved_track,
        "parsingResult": build_parsed_result(raw_link, track_id, source_platform),
        "metadataStatus": "success",
        "resolverVersion": "spotify-resolver/v1",
    }


class SpotifyResolverHandler(BaseHTTPRequestHandler):
    server_version = "SpotifyResolver/1.0"

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json(200, {"status": "ok"})
            return

        self._send_json(404, {"error": "Not found"})

    def do_POST(self) -> None:
        if self.path != "/resolve":
            self._send_json(404, {"error": "Not found"})
            return

        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length)

        try:
            payload = json.loads(raw_body.decode("utf-8"))
        except json.JSONDecodeError:
            self._send_json(400, {"error": "Invalid JSON body"})
            return

        raw_link = payload.get("rawLink", "").strip()
        preferred_market = payload.get("preferredMarket")

        if not raw_link:
            self._send_json(400, {"error": "rawLink is required"})
            return

        if "spotify" not in raw_link.lower():
            self._send_json(
                400,
                {
                    "error": "Only Spotify track links are supported in this resolver",
                    "parsingResult": {"type": "unsupportedLink", "rawLink": raw_link},
                },
            )
            return

        track_id = parse_spotify_track_id(raw_link)
        if not track_id:
            self._send_json(
                400,
                {
                    "error": "Spotify track ID could not be extracted",
                    "parsingResult": build_parsed_result(raw_link, None, "Spotify"),
                },
            )
            return

        client_id = os.environ.get("SPOTIFY_CLIENT_ID")
        client_secret = os.environ.get("SPOTIFY_CLIENT_SECRET")

        if not client_id or not client_secret:
            self._send_json(500, {"error": "Missing SPOTIFY_CLIENT_ID or SPOTIFY_CLIENT_SECRET"})
            return

        try:
            access_token = fetch_spotify_access_token(client_id, client_secret)
            track_payload = fetch_spotify_track(access_token, track_id, preferred_market)
            response = build_resolver_response(raw_link, track_payload, track_id, preferred_market)
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="ignore")
            self._send_json(exc.code, {"error": "Spotify API request failed", "detail": detail})
            return
        except Exception as exc:
            self._send_json(500, {"error": "Resolver failed", "detail": str(exc)})
            return

        self._send_json(200, response)

    def log_message(self, format: str, *args) -> None:
        sys.stderr.write("%s - - [%s] %s\n" % (self.client_address[0], self.log_date_time_string(), format % args))

    def _send_json(self, status_code: int, payload: dict) -> None:
        response = json.dumps(payload).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(response)))
        self.end_headers()
        self.wfile.write(response)


def main() -> None:
    load_dotenv()
    host = os.environ.get("HOST", "127.0.0.1")
    port = int(os.environ.get("PORT", "8787"))
    server = HTTPServer((host, port), SpotifyResolverHandler)
    print(f"Spotify resolver server listening on http://{host}:{port}")
    server.serve_forever()


if __name__ == "__main__":
    main()
