"""
Service wrapper that reuses the existing resolver logic from the ThreadingHTTPServer.

The core resolution functions are imported from the existing modules so that
behaviour stays identical between the old server (port 8787) and the new
FastAPI endpoints (port 8788).
"""

from __future__ import annotations

import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Ensure the backend root (parent of app/) is on sys.path so that we can
# import the existing resolver modules that live outside the app/ package.
# ---------------------------------------------------------------------------
_backend_root = str(Path(__file__).resolve().parent.parent.parent)
if _backend_root not in sys.path:
    sys.path.insert(0, _backend_root)

from models.resolver_models import CanonicalTrack  # noqa: E402
from services.resolver_service import ResolverService  # noqa: E402

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


# Module-level singleton – the same instance the old server uses.
_resolver = ResolverService()


def resolve(
    raw_link: str, preferred_market: str | None, include_platform_links: bool
) -> dict:
    """Resolve a raw music link.

    Delegates to the existing ``ResolverService.resolve`` and returns the
    same dict with ``status_code`` and ``body`` keys.
    """
    return _resolver.resolve(raw_link, preferred_market, include_platform_links)


def resolve_platform_links(payload: dict) -> dict:
    """Resolve platform links for an already-known canonical track.

    Accepts the same payload shape that the old ``/resolve-platform-links``
    endpoint expects, builds a ``CanonicalTrack``, and delegates to
    ``ResolverService.resolve_platform_links``.
    """
    canonical_track = build_canonical_track_from_payload(payload)
    if canonical_track is None:
        return {
            "status_code": 400,
            "body": {
                "error": "sourcePlatform, sourcePlatformID, sourceURL, title, and artistName are required"
            },
        }
    preferred_market = payload.get("preferredMarket")
    result = _resolver.resolve_platform_links(canonical_track, preferred_market)
    return {"status_code": 200, "body": result}


def resolve_platform_link(payload: dict) -> dict:
    """Resolve a single platform link for a canonical track.

    Accepts the same payload shape that the old ``/resolve-platform-link``
    endpoint expects, builds a ``CanonicalTrack``, and delegates to
    ``ResolverService.resolve_platform_link``.
    """
    target_platform = payload.get("targetPlatform")
    if not isinstance(target_platform, str) or not target_platform:
        return {
            "status_code": 400,
            "body": {
                "error": "sourcePlatform, sourcePlatformID, sourceURL, title, artistName, and targetPlatform are required"
            },
        }
    canonical_track = build_canonical_track_from_payload(payload)
    if canonical_track is None:
        return {
            "status_code": 400,
            "body": {
                "error": "sourcePlatform, sourcePlatformID, sourceURL, title, and artistName are required"
            },
        }
    preferred_market = payload.get("preferredMarket")
    result = _resolver.resolve_platform_link(
        canonical_track, target_platform, preferred_market
    )
    return {"status_code": 200, "body": result}
