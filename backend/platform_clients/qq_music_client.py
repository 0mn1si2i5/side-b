from __future__ import annotations

import asyncio
import os
import sys
import threading
from typing import Any


VENDOR_PATH = os.path.join(os.path.dirname(os.path.dirname(__file__)), "vendor")
if os.path.isdir(VENDOR_PATH) and VENDOR_PATH not in sys.path:
    sys.path.insert(0, VENDOR_PATH)

try:
    from qqmusic_api import Client  # type: ignore
    from qqmusic_api.modules.search import SearchType  # type: ignore
except ImportError as exc:  # pragma: no cover - import is environment-dependent
    raise ImportError(
        "QQMusicApi is required. Install backend requirements or keep backend/vendor populated."
    ) from exc


def _track_to_dict(track: Any) -> dict:
    singer_names = [singer.name for singer in getattr(track, "singer", []) if getattr(singer, "name", "")]
    album = getattr(track, "album", None)
    album_name = getattr(album, "name", "") if album else ""
    artwork_url = album.cover_url(1200) if album and hasattr(album, "cover_url") else ""

    return {
        "mid": getattr(track, "mid", ""),
        "title": getattr(track, "name", "") or getattr(track, "title", ""),
        "artist_name": ", ".join(singer_names),
        "album_title": album_name or None,
        "duration_ms": getattr(track, "interval", 0) * 1000 if isinstance(getattr(track, "interval", None), int) else None,
        "artwork_url": artwork_url or None,
        "isrc": None,
    }


async def _fetch_track_detail_async(track_mid: str) -> dict:
    async with Client() as client:
        response = await client.song.get_detail(track_mid)
        return _track_to_dict(response.track)


async def _search_tracks_async(query_text: str, limit: int) -> list[dict]:
    async with Client() as client:
        response = await client.search.search_by_type(
            query_text,
            search_type=SearchType.SONG,
            num=limit,
        )
        return [_track_to_dict(track) for track in response.song]


def _run_async_client_call(coro):
    result: dict[str, Any] = {}

    def _runner() -> None:
        try:
            result["value"] = asyncio.run(coro)
        except BaseException as exc:  # pragma: no cover - re-raised in caller thread
            result["error"] = exc

    thread = threading.Thread(target=_runner, daemon=True)
    thread.start()
    thread.join()

    if "error" in result:
        raise result["error"]
    return result.get("value")


def fetch_track_detail(track_mid: str) -> dict:
    track_payload = _run_async_client_call(_fetch_track_detail_async(track_mid))
    if not isinstance(track_payload, dict) or not track_payload.get("mid"):
        raise ValueError("Invalid QQ Music song detail response")
    return track_payload


def search_tracks(query_text: str, limit: int = 10) -> list[dict]:
    track_payloads = _run_async_client_call(_search_tracks_async(query_text, limit))
    return track_payloads if isinstance(track_payloads, list) else []
