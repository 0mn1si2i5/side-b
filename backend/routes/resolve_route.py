import json
import os
import sys
from http.server import BaseHTTPRequestHandler
from urllib import error

from models.resolver_models import CanonicalTrack
from services.resolver_service import ResolverService


ENV_FILE_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
resolver_service = ResolverService()


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

        try:
            resolution = resolver_service.resolve(raw_link, preferred_market, include_platform_links)
        except error.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="ignore")
            self._send_json(exc.code, {"error": "Resolver upstream request failed", "detail": detail})
            return
        except Exception as exc:
            self._send_json(500, {"error": "Resolver failed", "detail": str(exc)})
            return

        self._send_json(resolution["status_code"], resolution["body"])

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
            response = resolver_service.resolve_platform_links(canonical_track, preferred_market)
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
            response = resolver_service.resolve_platform_link(canonical_track, target_platform, preferred_market)
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
