import json
import time
from urllib import parse, request


DEFAULT_TIMEOUT_SECONDS = 10.0
CACHE_TTL_SECONDS = 30 * 60
REQUEST_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/135.0 Safari/537.36"
    )
}
PUBLIC_SEARCH_URL = "https://music.163.com/api/search/get/web"
PUBLIC_SEARCH_HEADERS = {
    **REQUEST_HEADERS,
    "Content-Type": "application/x-www-form-urlencoded",
    "Referer": "https://music.163.com/",
}

_cache_store: dict[tuple, tuple[float, object]] = {}


def _read_cache(cache_key: tuple):
    cached_entry = _cache_store.get(cache_key)
    if not cached_entry:
        return None

    cached_at, cached_value = cached_entry
    if time.time() - cached_at > CACHE_TTL_SECONDS:
        _cache_store.pop(cache_key, None)
        return None

    return cached_value


def _write_cache(cache_key: tuple, cached_value) -> None:
    _cache_store[cache_key] = (time.time(), cached_value)


def _request_json(base_url: str, path: str, query_items: dict[str, str | int | None], timeout_seconds: float) -> dict:
    filtered_items = {key: value for key, value in query_items.items() if value is not None}
    url = f"{base_url.rstrip('/')}{path}"
    if filtered_items:
        url = f"{url}?{parse.urlencode(filtered_items)}"

    cache_key = (path, tuple(sorted(filtered_items.items())))
    cached_payload = _read_cache(cache_key)
    if isinstance(cached_payload, dict):
        return dict(cached_payload)

    last_error = None
    for _ in range(2):
        try:
            req = request.Request(url, headers=REQUEST_HEADERS, method="GET")
            with request.urlopen(req, timeout=timeout_seconds) as response:
                payload = json.loads(response.read().decode("utf-8"))
            break
        except Exception as exc:
            last_error = exc
            time.sleep(0.15)
    else:
        raise last_error or ValueError(f"Netease request failed for {path}")

    if not isinstance(payload, dict):
        raise ValueError(f"Invalid Netease API response for {path}")

    _write_cache(cache_key, payload)
    return payload


def fetch_track_detail(base_url: str, track_id: str, timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS) -> dict:
    payload = _request_json(base_url, "/song/detail", {"ids": track_id}, timeout_seconds)
    songs = payload.get("songs")
    if not isinstance(songs, list):
        raise ValueError("Invalid Netease song/detail response")

    for song in songs:
        if isinstance(song, dict) and str(song.get("id")) == str(track_id):
            return song

    raise ValueError("Netease track not found")


def search_tracks(base_url: str, query_text: str, limit: int = 10, timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS) -> list[dict]:
    payload = _request_json(
        base_url,
        "/cloudsearch",
        {"keywords": query_text, "type": 1, "limit": limit},
        timeout_seconds,
    )
    songs = payload.get("result", {}).get("songs", [])
    return songs if isinstance(songs, list) else []


def search_public_tracks(query_text: str, limit: int = 10, timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS) -> list[dict]:
    body = parse.urlencode({"s": query_text, "type": 1, "limit": limit, "offset": 0}).encode("utf-8")
    req = request.Request(PUBLIC_SEARCH_URL, data=body, headers=PUBLIC_SEARCH_HEADERS, method="POST")
    with request.urlopen(req, timeout=timeout_seconds) as response:
        payload = json.loads(response.read().decode("utf-8"))
    if not isinstance(payload, dict) or payload.get("code") != 200:
        raise ValueError("Netease public search unavailable")
    result = payload.get("result") or {}
    if not isinstance(result, dict) or not isinstance(result.get("songs", []), list):
        raise ValueError("Invalid Netease public search result")
    return [song for song in result.get("songs", []) if isinstance(song, dict)]


def fetch_song_url(
    base_url: str,
    track_id: str,
    level: str = "standard",
    timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS,
) -> str | None:
    payload = _request_json(base_url, "/song/url/v1", {"id": track_id, "level": level}, timeout_seconds)
    data = payload.get("data")
    if not isinstance(data, list) or not data:
        return None

    song_payload = data[0]
    if not isinstance(song_payload, dict):
        return None

    song_url = song_payload.get("url")
    return song_url if isinstance(song_url, str) and song_url.startswith("http") else None


def check_music(base_url: str, track_id: str, timeout_seconds: float = DEFAULT_TIMEOUT_SECONDS) -> bool | None:
    payload = _request_json(base_url, "/check/music", {"id": track_id}, timeout_seconds)

    success = payload.get("success")
    if isinstance(success, bool):
        return success

    message = payload.get("message")
    if isinstance(message, str):
        lowered = message.casefold()
        if "ok" in lowered or "可用" in lowered:
            return True
        if "不可" in lowered or "not" in lowered or "fail" in lowered:
            return False

    return None
