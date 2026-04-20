import os
import sqlite3
import time


_DEFAULT_TTL_SECONDS = 86400  # 24 hours


def _default_db_path() -> str:
    return os.path.join(os.path.dirname(__file__), "..", "data", "platform_link_cache.db")


class PlatformLinkCache:
    """SQLite-backed persistent cache for cross-platform link resolutions.

    Supplements the existing in-memory cache (context.cache_store) so that
    resolved links survive backend restarts.
    """

    def __init__(self, db_path: str | None = None) -> None:
        self.db_path = db_path or _default_db_path()
        self._ensure_data_dir()
        self._init_db()

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def get(self, source_url: str, target_platform: str, preferred_market: str | None = None) -> str | None:
        """Return a cached target URL if one exists and has not expired."""
        with self._connect() as conn:
            row = conn.execute(
                """SELECT target_url, created_at, ttl_seconds
                     FROM platform_link_cache
                    WHERE source_url = ?
                      AND target_platform = ?
                      AND preferred_market IS NOT DISTINCT FROM ?""",
                (source_url, target_platform, preferred_market),
            ).fetchone()

        if row is None:
            return None

        target_url, created_at, ttl = row
        if time.time() - created_at < ttl:
            return target_url

        # Expired — clean up lazily
        self._delete(source_url, target_platform, preferred_market)
        return None

    def set(
        self,
        source_url: str,
        target_platform: str,
        target_url: str,
        preferred_market: str | None = None,
        ttl: int = _DEFAULT_TTL_SECONDS,
    ) -> None:
        """Store a resolved link with the given TTL (default 24 hours)."""
        with self._connect() as conn:
            conn.execute(
                """INSERT OR REPLACE INTO platform_link_cache
                       (source_url, target_platform, preferred_market, target_url, created_at, ttl_seconds)
                   VALUES (?, ?, ?, ?, ?, ?)""",
                (source_url, target_platform, preferred_market, target_url, time.time(), ttl),
            )

    def clear_expired(self) -> int:
        """Remove all expired entries. Returns the number of rows deleted."""
        with self._connect() as conn:
            cursor = conn.execute(
                "DELETE FROM platform_link_cache WHERE ? - created_at > ttl_seconds",
                (time.time(),),
            )
            return cursor.rowcount

    # ------------------------------------------------------------------
    # Internal
    # ------------------------------------------------------------------

    def _ensure_data_dir(self) -> None:
        data_dir = os.path.dirname(self.db_path)
        if data_dir:
            os.makedirs(data_dir, exist_ok=True)

    def _connect(self) -> sqlite3.Connection:
        conn = sqlite3.connect(self.db_path)
        conn.execute("PRAGMA journal_mode=WAL")
        return conn

    def _init_db(self) -> None:
        with self._connect() as conn:
            conn.execute("""
                CREATE TABLE IF NOT EXISTS platform_link_cache (
                    source_url       TEXT NOT NULL,
                    target_platform  TEXT NOT NULL,
                    preferred_market TEXT,
                    target_url       TEXT NOT NULL,
                    created_at       REAL NOT NULL,
                    ttl_seconds      INTEGER NOT NULL DEFAULT 86400,
                    PRIMARY KEY (source_url, target_platform, preferred_market)
                )
            """)

    def _delete(self, source_url: str, target_platform: str, preferred_market: str | None) -> None:
        with self._connect() as conn:
            conn.execute(
                """DELETE FROM platform_link_cache
                    WHERE source_url = ?
                      AND target_platform = ?
                      AND preferred_market IS NOT DISTINCT FROM ?""",
                (source_url, target_platform, preferred_market),
            )


# Module-level singleton for easy import
_platform_link_cache: PlatformLinkCache | None = None


def get_platform_link_cache() -> PlatformLinkCache:
    global _platform_link_cache
    if _platform_link_cache is None:
        _platform_link_cache = PlatformLinkCache()
    return _platform_link_cache
