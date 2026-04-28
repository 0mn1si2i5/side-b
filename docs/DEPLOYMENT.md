# Deployment Checklist

Side B v1 deploys as a small Docker Compose stack for a personal server.

Runtime services:

- `api`: Side B FastAPI backend. It owns auth, rooms, messages, WebSocket, resolver orchestration, SQLite migrations, and QQ Music access through `qqmusic-api-python`.
- `netease`: Netease-compatible API service on port `3000`. The backend reaches it through `NETEASE_API_BASE_URL`.
- `nginx`: public HTTP/HTTPS entrypoint, reverse proxy, rate limits, and `/health`.

## 1. Server Prerequisites

- Docker and Docker Compose plugin installed.
- Ports `80` and `443` open on the server firewall.
- A domain A/AAAA record pointing to the server.
- A deploy directory containing this repository and a private `backend/.env`.
- Enough disk for the SQLite volume and backups.

## 2. Environment

Create `backend/.env` from the example:

```bash
cp backend/.env.example backend/.env
```

Required production values:

```env
JWT_SECRET=<generate_with_python_secrets_token_hex_32>
SPOTIFY_CLIENT_ID=<spotify_client_id>
SPOTIFY_CLIENT_SECRET=<spotify_client_secret>
DATABASE_URL=sqlite:///./data/sideb.db
CORS_ORIGINS=https://<your-domain>
APPLE_MUSIC_STOREFRONT=cn
NETEASE_REQUEST_TIMEOUT=10
UVICORN_WORKERS=1
```

Compose sets:

```env
NETEASE_API_BASE_URL=http://netease:3000
```

Keep `UVICORN_WORKERS=1` for v1. WebSocket connection management is process-local.

## 3. Netease API Service

The backend expects a Netease-compatible HTTP API with endpoints used by:

- `/cloudsearch`
- `/song/detail`
- `/song/url`
- `/check/music`

For local testing, run `api-enhanced` on `127.0.0.1:3000` and set `NETEASE_API_BASE_URL=http://127.0.0.1:3000`.

For Docker deployment, run the Netease service inside the compose network under service name `netease`, and keep the backend value as `http://netease:3000`.

## 4. First Deploy

Build and start:

```bash
docker compose up -d --build
```

Check container status:

```bash
docker compose ps
docker compose logs -f api
```

The API container runs migrations on startup through `backend/entrypoint.sh`.

## 5. Smoke Tests

From the server:

```bash
curl -f http://127.0.0.1/health
curl -f http://127.0.0.1:8788/health
```

From your local machine after DNS/HTTPS is ready:

```bash
curl -f https://<your-domain>/health
```

Auth smoke test:

```bash
curl -s -X POST https://<your-domain>/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"deploytest1","password":"TestPass123!","displayName":"Deploy Test","avatarName":"avatar_1"}'
```

Resolver smoke test:

```bash
curl -s -X POST https://<your-domain>/api/resolve \
  -H "Content-Type: application/json" \
  -d '{"rawLink":"分享G.E.M.邓紫棋的单曲《唯一》https://163cn.tv/5ZcJvPj (@网易云音乐)","includePlatformLinks":true}'
```

Expected resolver behavior:

- Source metadata succeeds for Spotify / Apple Music / Netease / QQ links when credentials and third-party services are healthy.
- Target platform misses hide that platform button instead of failing the whole card.
- Netease failures should be isolated to Netease source or Netease target mapping.

## 6. iOS Production Pointing

Set the scheme or app configuration to:

```text
SIDEB_API_BASE_URL=https://<your-domain>
```

For LAN testing before domain cutover:

```text
SIDEB_API_BASE_URL=http://<server-lan-ip>
```

## 7. SQLite Volume Backup

The default database lives in Docker volume `sideb-data` at `/app/data/sideb.db`.

Create a backup:

```bash
docker compose exec api python -c "import sqlite3; src=sqlite3.connect('/app/data/sideb.db'); dst=sqlite3.connect('/app/data/sideb-backup.db'); src.backup(dst); dst.close(); src.close()"
docker cp sideb-api:/app/data/sideb-backup.db ./sideb-backup-$(date +%Y%m%d-%H%M%S).db
```

Restore during maintenance:

```bash
docker compose down
docker compose run --rm --no-deps --entrypoint sh -v "$PWD":/backup api -c "cp /backup/sideb-backup.db /app/data/sideb.db"
docker compose up -d
```

Verify after restore:

```bash
docker compose logs api
curl -f http://127.0.0.1/health
```

## 8. Operational Checks

- `docker compose ps` shows `api`, `netease`, and `nginx` healthy.
- `docker compose logs api` has no migration errors.
- `/health` returns success through nginx.
- `/api/auth/register` and `/api/auth/login` work.
- `/api/resolve` works for at least one Spotify or Apple Music link.
- Netease link resolution works when the `netease` service is healthy.
- QQ link resolution works from inside the `api` container.
- WebSocket connects with one API worker.

## 9. Rollback

For code rollback:

```bash
git checkout <previous-commit>
docker compose up -d --build
```

For data rollback, restore the SQLite backup before starting the new containers.
