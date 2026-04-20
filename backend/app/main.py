from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import settings

app = FastAPI(title="Side B API", version="0.1.0")

origins = [origin.strip() for origin in settings.CORS_ORIGINS.split(",")]
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=500,
        content={"error": "Internal server error", "detail": str(exc)},
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
