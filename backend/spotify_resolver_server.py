#!/usr/bin/env python3
import base64
import json
import os
import re
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib import error, parse, request


SPOTIFY_TOKEN_URL = "https://accounts.spotify.com/api/token"
SPOTIFY_TRACK_URL = "https://api.spotify.com/v1/tracks/{track_id}"
ENV_FILE_PATH = os.path.join(os.path.dirname(__file__), ".env")


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


def build_search_url(platform: str, title: str, artist_name: str) -> str:
    query = parse.quote(f"{title} {artist_name}")

    if platform == "Apple Music":
        return f"https://music.apple.com/us/search?term={query}"
    if platform == "QQ 音乐":
        return f"https://y.qq.com/n/ryqq/search?w={query}"
    if platform == "网易云音乐":
        return f"https://music.163.com/#/search/m/?s={query}&type=1"
    return f"https://open.spotify.com/search/{query}"


def build_platform_links(source_url: str, title: str, artist_name: str) -> list[dict]:
    platforms = ["Spotify", "Apple Music", "QQ 音乐", "网易云音乐"]
    links = []

    for platform in platforms:
        destination_url = source_url if platform == "Spotify" else build_search_url(platform, title, artist_name)
        links.append(
            {
                "platform": platform,
                "destinationURL": destination_url,
                "isSource": platform == "Spotify",
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


def build_parsed_result(raw_link: str, track_id: str | None) -> dict:
    parsed_link = {
        "originalLink": raw_link,
        "normalizedLink": normalize_link(raw_link),
        "platform": "Spotify",
        "sourceURL": raw_link,
        "resourceID": track_id,
        "resourceKind": "track",
    }

    if track_id:
        return {"type": "parsed", "parsedLink": parsed_link}

    return {"type": "missingResourceID", "partialLink": parsed_link}


def build_resolver_response(raw_link: str, track_payload: dict, track_id: str) -> dict:
    title = track_payload["name"]
    artist_name = ", ".join(artist["name"] for artist in track_payload.get("artists", []))
    album_title = track_payload.get("album", {}).get("name")
    artwork_url = None

    images = track_payload.get("album", {}).get("images", [])
    if images:
        artwork_url = images[0].get("url")

    external_url = track_payload.get("external_urls", {}).get("spotify", raw_link)
    isrc = track_payload.get("external_ids", {}).get("isrc")
    platform_links = build_platform_links(external_url, title, artist_name)

    track = {
        "title": title,
        "artistName": artist_name,
        "albumTitle": album_title,
        "durationMS": track_payload.get("duration_ms"),
        "sourcePlatform": "Spotify",
        "sourcePlatformID": track_id,
        "sourceURL": external_url,
        "isrc": isrc,
        "artworkURL": artwork_url,
    }

    resolved_track = {
        "track": track,
        "sourcePlatform": "Spotify",
        "sourceURL": external_url,
        "sourceResourceID": track_id,
        "platformLinks": platform_links,
    }

    return {
        "resolvedTrack": resolved_track,
        "parsingResult": build_parsed_result(raw_link, track_id),
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
                    "parsingResult": build_parsed_result(raw_link, None),
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
            response = build_resolver_response(raw_link, track_payload, track_id)
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
