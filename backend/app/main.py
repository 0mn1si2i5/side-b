import logging

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded
from slowapi.util import get_remote_address

from app.config import settings

logger = logging.getLogger(__name__)

limiter = Limiter(key_func=get_remote_address)

app = FastAPI(title="Side B API", version="0.1.0")
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

origins = [origin.strip() for origin in settings.CORS_ORIGINS.split(",")]
# allow_credentials=True with origins=["*"] is a security violation;
# when origins is wildcard, credentials must be False.
allow_credentials = "*" not in origins
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=allow_credentials,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.error(f"Unhandled exception: {exc}", exc_info=True)
    return JSONResponse(
        status_code=500,
        content={"error": "Internal server error", "detail": "An unexpected error occurred"},
    )


@app.exception_handler(RateLimitExceeded)
async def rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    return JSONResponse(
        status_code=429,
        content={"error": "Rate limit exceeded", "detail": "Too many requests"},
    )


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


from app.routers import auth, resolve, rooms, users, ws

app.include_router(auth.router, prefix="/api/auth", tags=["auth"])
app.include_router(resolve.router, prefix="/api", tags=["resolve"])
app.include_router(rooms.router, prefix="/api/rooms", tags=["rooms"])
app.include_router(users.router, prefix="/api/users", tags=["users"])
app.include_router(ws.router, prefix="/ws", tags=["websocket"])


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app.main:app",
        host=settings.FASTAPI_HOST,
        port=settings.FASTAPI_PORT,
        reload=True,
    )
