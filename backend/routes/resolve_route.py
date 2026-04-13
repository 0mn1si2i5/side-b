import json
import os
import sys
import time
from http.server import BaseHTTPRequestHandler
from urllib import error

from models.resolver_models import CanonicalTrack, ParsedSource, ResolverContext
from services.platform_link_resolvers import resolve_platform_link, resolve_platform_links
from services.source_platform_adapters import select_source_adapter
from resolvers.spotify_platform import fetch_spotify_access_token


ENV_FILE_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
RESOLVER_VERSION = "music-resolver/v1"
SUPPORTED_LINK_ERROR = "Only Spotify, Apple Music, and 网易云音乐 track links are supported in this resolver"
SPOTIFY_TOKEN_CACHE_TTL_SECONDS = 50 * 60
_spotify_token_cache: dict[str, str | float | None] = {"token": None, "fetched_at": None}


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


def build_parsed_result(parsed_source: ParsedSource) -> dict:
    parsed_link = {
        "originalLink": parsed_source.raw_link,
        "normalizedLink": parsed_source.normalized_link,
        "platform": parsed_source.platform,
        "sourceURL": parsed_source.source_url,
        "resourceID": parsed_source.resource_id,
        "resourceKind": parsed_source.resource_kind,
    }
    return {"type": "parsed", "parsedLink": parsed_link}


def build_missing_resource_result(raw_link: str, platform: str) -> dict:
    return {
        "type": "missingResourceID",
        "partialLink": {
            "originalLink": raw_link,
            "normalizedLink": raw_link.strip().lower(),
            "platform": platform,
            "sourceURL": raw_link,
            "resourceID": None,
            "resourceKind": "track",
        },
    }


def build_resolver_context(preferred_market: str | None) -> ResolverContext:
    client_id = os.environ.get("SPOTIFY_CLIENT_ID")
    client_secret = os.environ.get("SPOTIFY_CLIENT_SECRET")
    spotify_access_token = spotify_access_token_from_cache(client_id, client_secret)

    netease_request_timeout = 10.0
    raw_timeout = os.environ.get("NETEASE_REQUEST_TIMEOUT")
    if raw_timeout:
        try:
            netease_request_timeout = float(raw_timeout)
        except ValueError:
            pass

    return ResolverContext(
        preferred_market=preferred_market,
        spotify_access_token=spotify_access_token,
        netease_api_base_url=os.environ.get("NETEASE_API_BASE_URL"),
        netease_request_timeout=netease_request_timeout,
    )


def build_track_body(canonical_track: CanonicalTrack) -> dict:
    return {
        "title": canonical_track.title,
        "artistName": canonical_track.artist_name,
        "albumTitle": canonical_track.album_title,
        "durationMS": canonical_track.duration_ms,
        "sourcePlatform": canonical_track.source_platform,
        "sourcePlatformID": canonical_track.source_id,
        "sourceURL": canonical_track.source_url,
        "isrc": canonical_track.isrc,
        "artworkURL": canonical_track.artwork_url,
    }


def build_source_platform_links(canonical_track: CanonicalTrack) -> list[dict]:
    return [
        {
            "platform": canonical_track.source_platform,
            "destinationURL": canonical_track.source_url,
            "isSource": True,
        }
    ]


def build_resolver_response(
    parsed_source: ParsedSource,
    canonical_track: CanonicalTrack,
    context: ResolverContext,
    include_platform_links: bool,
) -> dict:
    platform_links = (
        resolve_platform_links(canonical_track, context)
        if include_platform_links
        else build_source_platform_links(canonical_track)
    )
    resolved_track = {
        "track": build_track_body(canonical_track),
        "sourcePlatform": canonical_track.source_platform,
        "sourceURL": canonical_track.source_url,
        "sourceResourceID": canonical_track.source_id,
        "platformLinks": platform_links,
    }
    return {
        "resolvedTrack": resolved_track,
        "parsingResult": build_parsed_result(parsed_source),
        "metadataStatus": "success",
        "resolverVersion": RESOLVER_VERSION,
    }


def build_platform_links_response(canonical_track: CanonicalTrack, context: ResolverContext) -> dict:
    return {
        "platformLinks": resolve_platform_links(canonical_track, context),
        "resolverVersion": RESOLVER_VERSION,
    }


def build_canonical_track_from_payload(payload: dict) -> CanonicalTrack | None:
    source_platform = payload.get("sourcePlatform")
    source_platform_id = payload.get("sourcePlatformID")
    source_url = payload.get("sourceURL")
    title = payload.get("title")
    artist_name = payload.get("artistName")

    if not all(isinstance(value, str) and value for value in (source_platform, source_platform_id, source_url, title, artist_name)):
        return None

    return CanonicalTrack(
        source_platform=source_platform,
        source_id=source_platform_id,
        source_url=source_url,
        title=title,
        artist_name=artist_name,
        album_title=payload.get("albumTitle"),
        duration_ms=payload.get("durationMS"),
        artwork_url=payload.get("artworkURL"),
        isrc=payload.get("isrc"),
    )


def spotify_access_token_from_cache(client_id: str | None, client_secret: str | None) -> str | None:
    if not client_id or not client_secret:
        return None

    cached_token = _spotify_token_cache.get("token")
    cached_at = _spotify_token_cache.get("fetched_at")
    if isinstance(cached_token, str) and isinstance(cached_at, (int, float)):
        if time.time() - cached_at < SPOTIFY_TOKEN_CACHE_TTL_SECONDS:
            return cached_token

    access_token = fetch_spotify_access_token(client_id, client_secret)
    _spotify_token_cache["token"] = access_token
    _spotify_token_cache["fetched_at"] = time.time()
    return access_token


class ResolveRouteHandler(BaseHTTPRequestHandler):
    server_version = "MusicResolver/1.0"

    def do_GET(self) -> None:
        if self.path == "/health":
            self._send_json(200, {"status": "ok"})
            return

        self._send_json(404, {"error": "Not found"})

    def do_POST(self) -> None:
        if self.path == "/resolve":
            self._handle_resolve()
            return

        if self.path == "/resolve-platform-link":
            self._handle_resolve_platform_link()
            return

        if self.path == "/resolve-platform-links":
            self._handle_resolve_platform_links()
            return

        self._send_json(404, {"error": "Not found"})

    def _handle_resolve(self) -> None:
        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length)

        try:
            payload = json.loads(raw_body.decode("utf-8"))
        except json.JSONDecodeError:
            self._send_json(400, {"error": "Invalid JSON body"})
            return

        raw_link = payload.get("rawLink", "").strip()
        preferred_market = payload.get("preferredMarket")
        include_platform_links = bool(payload.get("includePlatformLinks", True))

        if not raw_link:
            self._send_json(400, {"error": "rawLink is required"})
            return

        adapter = select_source_adapter(raw_link)
        if adapter is None:
            self._send_json(
                400,
                {"error": SUPPORTED_LINK_ERROR, "parsingResult": {"type": "unsupportedLink", "rawLink": raw_link}},
            )
            return

        parsed_source = adapter.parse_source_link(raw_link)
        if parsed_source is None:
            self._send_json(
                400,
                {
                    "error": f"{adapter.platform} track ID could not be extracted",
                    "parsingResult": build_missing_resource_result(raw_link, adapter.platform),
                },
            )
            return

        try:
            context = build_resolver_context(preferred_market)
            canonical_track = adapter.fetch_canonical_track(parsed_source, context)
            response = build_resolver_response(
                parsed_source,
                canonical_track,
                context,
                include_platform_links=include_platform_links,
            )
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="ignore")
            self._send_json(exc.code, {"error": "Resolver upstream request failed", "detail": detail})
            return
        except Exception as exc:
            self._send_json(500, {"error": "Resolver failed", "detail": str(exc)})
            return

        self._send_json(200, response)

    def _handle_resolve_platform_links(self) -> None:
        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length)

        try:
            payload = json.loads(raw_body.decode("utf-8"))
        except json.JSONDecodeError:
            self._send_json(400, {"error": "Invalid JSON body"})
            return

        preferred_market = payload.get("preferredMarket")
        canonical_track = build_canonical_track_from_payload(payload)
        if canonical_track is None:
            self._send_json(400, {"error": "sourcePlatform, sourcePlatformID, sourceURL, title, and artistName are required"})
            return

        try:
            context = build_resolver_context(preferred_market)
            response = build_platform_links_response(canonical_track, context)
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="ignore")
            self._send_json(exc.code, {"error": "Resolver upstream request failed", "detail": detail})
            return
        except Exception as exc:
            self._send_json(500, {"error": "Resolver failed", "detail": str(exc)})
            return

        self._send_json(200, response)

    def _handle_resolve_platform_link(self) -> None:
        content_length = int(self.headers.get("Content-Length", "0"))
        raw_body = self.rfile.read(content_length)

        try:
            payload = json.loads(raw_body.decode("utf-8"))
        except json.JSONDecodeError:
            self._send_json(400, {"error": "Invalid JSON body"})
            return

        target_platform = payload.get("targetPlatform")
        preferred_market = payload.get("preferredMarket")
        canonical_track = build_canonical_track_from_payload(payload)
        if canonical_track is None or not isinstance(target_platform, str) or not target_platform:
            self._send_json(400, {"error": "sourcePlatform, sourcePlatformID, sourceURL, title, artistName, and targetPlatform are required"})
            return

        try:
            context = build_resolver_context(preferred_market)
            platform_link = resolve_platform_link(canonical_track, context, target_platform)
            response = {
                "targetPlatform": target_platform,
                "platformLink": platform_link,
                "resolverVersion": RESOLVER_VERSION,
            }
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="ignore")
            self._send_json(exc.code, {"error": "Resolver upstream request failed", "detail": detail})
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
