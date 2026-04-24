"""
FastAPI router that mirrors the existing ThreadingHTTPServer resolver endpoints.

Routes:
    POST /resolve              – main resolve endpoint
    POST /resolve-platform-link – single platform link
    POST /resolve-platform-links – all platform links
    GET  /platforms            – supported platforms list
"""

from __future__ import annotations

import logging

from fastapi import APIRouter, Request
from fastapi.responses import JSONResponse

from app.main import limiter
from app.services.resolver_service import (
    resolve,
    resolve_platform_link,
    resolve_platform_links,
)

logger = logging.getLogger(__name__)

router = APIRouter(tags=["resolve"])


@router.post("/resolve")
@limiter.limit("30/minute")
async def resolve_endpoint(request: Request) -> JSONResponse:
    """Resolve a raw music link into canonical track data."""
    try:
        payload = await request.json()
    except Exception as e:
        logger.warning("Resolve request parse error: %s", e)
        return JSONResponse(status_code=400, content={"error": "Invalid JSON body"})

    raw_link = payload.get("rawLink", "").strip()
    if not raw_link:
        return JSONResponse(status_code=400, content={"error": "rawLink is required"})

    preferred_market = payload.get("preferredMarket")
    include_platform_links = bool(payload.get("includePlatformLinks", True))

    result = resolve(raw_link, preferred_market, include_platform_links)
    return JSONResponse(status_code=result["status_code"], content=result["body"])


@router.post("/resolve-platform-links")
@limiter.limit("10/minute")
async def resolve_platform_links_endpoint(request: Request) -> JSONResponse:
    """Resolve platform links for an already-known canonical track."""
    try:
        payload = await request.json()
    except Exception as e:
        logger.warning("Resolve platform links request parse error: %s", e)
        return JSONResponse(status_code=400, content={"error": "Invalid JSON body"})

    result = resolve_platform_links(payload)
    return JSONResponse(status_code=result["status_code"], content=result["body"])


@router.post("/resolve-platform-link")
@limiter.limit("30/minute")
async def resolve_platform_link_endpoint(request: Request) -> JSONResponse:
    """Resolve a single platform link for a canonical track."""
    try:
        payload = await request.json()
    except Exception as e:
        logger.warning("Resolve platform link request parse error: %s", e)
        return JSONResponse(status_code=400, content={"error": "Invalid JSON body"})

    result = resolve_platform_link(payload)
    return JSONResponse(status_code=result["status_code"], content=result["body"])


@router.get("/platforms")
async def platforms_endpoint() -> dict:
    """Return the list of platforms supported by the resolver."""
    return {
        "platforms": [
            {"id": "Spotify", "name": "Spotify"},
            {"id": "AppleMusic", "name": "Apple Music"},
            {"id": "Netease", "name": "网易云音乐"},
            {"id": "QQMusic", "name": "QQ 音乐"},
        ]
    }
