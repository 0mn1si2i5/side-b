import json
import os
import sys
from http.server import BaseHTTPRequestHandler
from urllib import error

from models.resolver_models import CanonicalTrack, ParsedSource, ResolverContext
from services.platform_link_resolvers import resolve_platform_links
from services.source_platform_adapters import select_source_adapter
from resolvers.spotify_platform import fetch_spotify_access_token


ENV_FILE_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
RESOLVER_VERSION = "music-resolver/v1"
SUPPORTED_LINK_ERROR = "Only Spotify and Apple Music track links are supported in this resolver"


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
    spotify_access_token = None
    client_id = os.environ.get("SPOTIFY_CLIENT_ID")
    client_secret = os.environ.get("SPOTIFY_CLIENT_SECRET")
    if client_id and client_secret:
        spotify_access_token = fetch_spotify_access_token(client_id, client_secret)

    return ResolverContext(preferred_market=preferred_market, spotify_access_token=spotify_access_token)


def build_resolver_response(parsed_source: ParsedSource, canonical_track: CanonicalTrack, context: ResolverContext) -> dict:
    platform_links = resolve_platform_links(canonical_track, context)
    track = {
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
    resolved_track = {
        "track": track,
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


class ResolveRouteHandler(BaseHTTPRequestHandler):
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
            response = build_resolver_response(parsed_source, canonical_track, context)
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
