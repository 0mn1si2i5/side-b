from __future__ import annotations

import http.client
import logging
import re
import subprocess
import time
from urllib import parse, request

logger = logging.getLogger(__name__)


QQ_MUSIC_TRACK_URL_TEMPLATE = "https://y.qq.com/n/ryqq/songDetail/{track_mid}"
QQ_MUSIC_REQUEST_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) "
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    )
}
SHORT_LINK_CACHE_TTL_SECONDS = 30 * 60
_short_link_cache: dict[str, tuple[float, str]] = {}


def resolve_qq_music_link(raw_link: str) -> str:
    normalized = raw_link.strip()
    if "c6.y.qq.com" not in normalized:
        return normalized

    cached_url = _read_short_link_cache(normalized)
    if cached_url:
        return cached_url

    resolved_url = _resolve_with_head_or_get(normalized)
    if resolved_url:
        _write_short_link_cache(normalized, resolved_url)
        return resolved_url

    raise ValueError("QQ Music short link expansion failed")


def parse_qq_music_track_id(raw_link: str) -> str | None:
    try:
        resolved_link = resolve_qq_music_link(raw_link)
    except Exception as e:
        logger.warning("QQ Music link resolution failed: %s", e)
        return None

    parsed_url = parse.urlparse(parse.unquote(resolved_link))
    query = parse.parse_qs(parsed_url.query)
    for key in ("songmid", "mid", "mids", "song_mid"):
        raw_value = query.get(key, [None])[0]
        if isinstance(raw_value, str) and raw_value:
            candidate = raw_value.split(",")[0].strip()
            if re.fullmatch(r"[A-Za-z0-9]+", candidate):
                return candidate

    for pattern in (
        r"/(?:songDetail|song)/([A-Za-z0-9]+)",
        r"[?&]songmid=([A-Za-z0-9]+)",
    ):
        match = re.search(pattern, resolved_link, re.IGNORECASE)
        if match:
            return match.group(1)

    return None


def build_qq_music_track_url(track_mid: str) -> str:
    return QQ_MUSIC_TRACK_URL_TEMPLATE.format(track_mid=track_mid)


class _NoRedirectHandler(request.HTTPRedirectHandler):
    def http_error_301(self, req, fp, code, msg, headers):
        return fp

    def http_error_302(self, req, fp, code, msg, headers):
        return fp

    def http_error_303(self, req, fp, code, msg, headers):
        return fp

    def http_error_307(self, req, fp, code, msg, headers):
        return fp

    def http_error_308(self, req, fp, code, msg, headers):
        return fp

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _resolve_with_head_or_get(raw_link: str) -> str | None:
    for method in ("HEAD", "GET"):
        try:
            location = _resolve_redirect_location(raw_link, method)
            if isinstance(location, str) and location:
                return location

            req = request.Request(raw_link, headers=QQ_MUSIC_REQUEST_HEADERS, method=method)
            with request.urlopen(req, timeout=10) as response:
                resolved_url = response.geturl()
                if isinstance(resolved_url, str) and resolved_url:
                    return resolved_url
        except Exception as e:
            logger.debug("QQ Music redirect resolution failed: %s", e)
            continue

    return None


def _resolve_redirect_location(raw_link: str, method: str) -> str | None:
    parsed_url = parse.urlparse(raw_link)
    if not parsed_url.scheme or not parsed_url.netloc:
        return None

    connection_cls = http.client.HTTPSConnection if parsed_url.scheme == "https" else http.client.HTTPConnection
    path = parsed_url.path or "/"
    if parsed_url.query:
        path = f"{path}?{parsed_url.query}"

    connection = connection_cls(parsed_url.netloc, timeout=10)
    try:
        connection.request(method, path, headers=QQ_MUSIC_REQUEST_HEADERS)
        response = connection.getresponse()
        location = response.getheader("Location")
        if isinstance(location, str) and location:
            return location
    except Exception as e:
        logger.debug("QQ Music redirect location resolution failed: %s", e)
        return None
    finally:
        connection.close()

    curl_location = _resolve_redirect_location_with_curl(raw_link)
    if curl_location:
        return curl_location

    return None


def _resolve_redirect_location_with_curl(raw_link: str) -> str | None:
    try:
        completed = subprocess.run(
            ["curl", "-i", "-s", raw_link],
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
    except Exception as e:
        logger.debug("QQ Music curl redirect resolution failed: %s", e)
        return None

    if not isinstance(completed.stdout, str) or not completed.stdout:
        return None

    match = re.search(r"^location:\s*(.+)$", completed.stdout, re.IGNORECASE | re.MULTILINE)
    if not match:
        return None

    location = match.group(1).strip()
    return location if location.startswith("http") else None


def _read_short_link_cache(raw_link: str) -> str | None:
    cached_entry = _short_link_cache.get(raw_link)
    if not cached_entry:
        return None

    cached_at, cached_value = cached_entry
    if time.time() - cached_at > SHORT_LINK_CACHE_TTL_SECONDS:
        _short_link_cache.pop(raw_link, None)
        return None

    return cached_value


def _write_short_link_cache(raw_link: str, resolved_url: str) -> None:
    _short_link_cache[raw_link] = (time.time(), resolved_url)
