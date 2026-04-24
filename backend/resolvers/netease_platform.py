import logging
import re
import time
from urllib import request
from urllib.error import HTTPError

logger = logging.getLogger(__name__)


NETEASE_TRACK_URL_TEMPLATE = "https://music.163.com/#/song?id={track_id}"
NETEASE_REQUEST_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) "
        "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    )
}
SHORT_LINK_CACHE_TTL_SECONDS = 30 * 60
_short_link_cache: dict[str, tuple[float, str]] = {}


def resolve_netease_link(raw_link: str) -> str:
    normalized = raw_link.strip()
    if "163cn.tv" not in normalized:
        return normalized

    cached_url = _read_short_link_cache(normalized)
    if cached_url:
        return cached_url

    resolved_url = _resolve_with_head_or_get(normalized)
    if resolved_url:
        _write_short_link_cache(normalized, resolved_url)
        return resolved_url

    html_url = _resolve_from_html(normalized)
    if html_url:
        _write_short_link_cache(normalized, html_url)
        return html_url

    raise ValueError("Netease short link expansion failed")


def parse_netease_track_id(raw_link: str) -> str | None:
    try:
        resolved_link = resolve_netease_link(raw_link)
    except Exception as e:
        logger.warning("Netease link resolution failed: %s", e)
        return None

    query_id_match = re.search(r"[?&]id=(\d+)", resolved_link)
    if query_id_match:
        return query_id_match.group(1)

    path_id_match = re.search(r"/song/(\d+)", resolved_link)
    if path_id_match:
        return path_id_match.group(1)

    return None


def build_netease_track_url(track_id: str) -> str:
    return NETEASE_TRACK_URL_TEMPLATE.format(track_id=track_id)


def _resolve_with_head_or_get(raw_link: str) -> str | None:
    for method in ("HEAD", "GET"):
        try:
            redirected_url = _resolve_redirect_location(raw_link, method)
            if redirected_url:
                return redirected_url

            req = request.Request(raw_link, headers=NETEASE_REQUEST_HEADERS, method=method)
            with request.urlopen(req, timeout=10) as response:
                resolved_url = response.geturl()
                if isinstance(resolved_url, str) and resolved_url:
                    return resolved_url
        except Exception as e:
            logger.debug("Netease redirect resolution failed: %s", e)
            continue

    return None


class _NoRedirectHandler(request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _resolve_redirect_location(raw_link: str, method: str) -> str | None:
    opener = request.build_opener(_NoRedirectHandler)
    req = request.Request(raw_link, headers=NETEASE_REQUEST_HEADERS, method=method)

    try:
        with opener.open(req, timeout=10) as response:
            location = response.headers.get("Location")
            if isinstance(location, str) and location:
                return location
    except HTTPError as exc:
        location = exc.headers.get("Location")
        if isinstance(location, str) and location:
            return location
    except Exception as e:
        logger.debug("Netease redirect location resolution failed: %s", e)
        return None

    return None


def _resolve_from_html(raw_link: str) -> str | None:
    req = request.Request(raw_link, headers=NETEASE_REQUEST_HEADERS, method="GET")
    with request.urlopen(req, timeout=10) as response:
        html = response.read().decode("utf-8", errors="ignore")

    patterns = (
        r'URL=([^"\'>\s]+)',
        r'window\.location(?:\.href)?\s*=\s*"([^"]+)"',
        r"window\.location(?:\.href)?\s*=\s*'([^']+)'",
        r'location\.replace\("([^"]+)"\)',
        r"location\.replace\('([^']+)'\)",
    )

    for pattern in patterns:
        match = re.search(pattern, html, re.IGNORECASE)
        if match:
            return match.group(1)

    return None


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
