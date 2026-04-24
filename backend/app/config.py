import os
from pathlib import Path

from dotenv import load_dotenv

# Load .env from backend directory (parent of app/)
_ENV_PATH = Path(__file__).resolve().parent.parent / ".env"
load_dotenv(_ENV_PATH)


class Settings:
    FASTAPI_HOST: str = os.environ.get("FASTAPI_HOST", "0.0.0.0")
    FASTAPI_PORT: int = int(os.environ.get("FASTAPI_PORT", "8788"))
    DATABASE_URL: str = os.environ.get("DATABASE_URL", "sqlite:///./data/sideb.db")
    JWT_SECRET: str = os.environ.get("JWT_SECRET", "")
    JWT_ALGORITHM: str = os.environ.get("JWT_ALGORITHM", "HS256")
    JWT_EXPIRATION_MINUTES: int = int(os.environ.get("JWT_EXPIRATION_MINUTES", "1440"))
    CORS_ORIGINS: str = os.environ.get("CORS_ORIGINS", "")

    # Spotify API credentials
    SPOTIFY_CLIENT_ID: str = os.environ.get("SPOTIFY_CLIENT_ID", "")
    SPOTIFY_CLIENT_SECRET: str = os.environ.get("SPOTIFY_CLIENT_SECRET", "")

    # Netease Cloud Music API
    NETEASE_API_BASE_URL: str = os.environ.get("NETEASE_API_BASE_URL", "http://localhost:3000")
    NETEASE_REQUEST_TIMEOUT: int = int(os.environ.get("NETEASE_REQUEST_TIMEOUT", "10"))

    # Apple Music
    APPLE_MUSIC_STOREFRONT: str = os.environ.get("APPLE_MUSIC_STOREFRONT", "cn")

    # Songlink API
    SONGLINK_API_KEY: str = os.environ.get("SONGLINK_API_KEY", "")

    # Debug mode
    DEBUG: bool = os.environ.get("DEBUG", "false").lower() == "true"

    def __init__(self) -> None:
        if not self.JWT_SECRET:
            raise ValueError(
                "JWT_SECRET is required. Set it in backend/.env or environment variables."
            )


settings = Settings()
