# Deployment

Side B v1 使用 Docker Compose 部署到个人服务器。

## Services

- `api`：FastAPI backend，负责 auth、profile、rooms、messages、WebSocket、resolver orchestration 和 Alembic migration。
- `netease`：网易云音乐兼容 API，backend 通过 `NETEASE_API_BASE_URL` 访问。
- `nginx`：公网 HTTP/HTTPS 入口、反向代理、限流和 `/health`。
- `certbot`：Let's Encrypt 证书申请和续期。

## Requirements

- Docker 和 Docker Compose plugin。
- 服务器开放 80/443。
- 域名 A/AAAA 记录指向服务器。
- 仓库已 clone 到服务器。
- 私有 `backend/.env` 已配置。
- SQLite volume 有备份策略。

## Environment

```bash
cp backend/.env.example backend/.env
```

生产必填：

```env
JWT_SECRET=<python_secrets_token_hex_32>
SPOTIFY_CLIENT_ID=<spotify_client_id>
SPOTIFY_CLIENT_SECRET=<spotify_client_secret>
DATABASE_URL=sqlite:///./data/sideb.db
CORS_ORIGINS=https://<your-domain>
APPLE_MUSIC_STOREFRONT=cn
NETEASE_REQUEST_TIMEOUT=10
UVICORN_WORKERS=1
```

Compose 内部使用：

```env
NETEASE_API_BASE_URL=http://netease:3000
```

保持 `UVICORN_WORKERS=1`，因为当前 WebSocket 连接管理在进程内。

## Deploy Or Update

首次部署：

```bash
docker compose up -d --build
```

服务器拉取新代码：

```bash
git pull
docker compose up -d --build api nginx
```

只改 iOS 代码或文档时，服务器后端不需要重启。改后端 Python、requirements、Dockerfile、nginx、compose 或 `.env` 后，需要 rebuild/restart 对应服务。

查看状态：

```bash
docker compose ps
docker compose logs -f api
```

`api` 容器启动时会运行：

```bash
alembic upgrade head
```

## HTTPS

DNS 指向服务器且 80 可访问后，申请证书：

```bash
docker compose --profile certbot run --rm certbot certonly \
  --webroot -w /var/www/certbot \
  -d <your-domain> \
  --email <your-email> \
  --agree-tos \
  --no-eff-email
```

重启 nginx：

```bash
docker compose up -d --build nginx
```

续期 cron 示例：

```bash
17 3 * * * cd /path/to/Side-B && docker compose --profile certbot run --rm certbot renew --quiet --webroot -w /var/www/certbot && docker compose kill -s HUP nginx >/dev/null 2>&1
```

## Smoke Tests

服务器本机：

```bash
curl -f http://127.0.0.1/health
curl -f http://127.0.0.1:8788/health
```

公网：

```bash
curl -f https://<your-domain>/health
```

注册：

```bash
curl -s -X POST https://<your-domain>/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"deploytest1","password":"TestPass123!","displayName":"Deploy Test","avatarName":"avatar_1"}'
```

解析：

```bash
curl -s -X POST https://<your-domain>/api/resolve \
  -H "Content-Type: application/json" \
  -d '{"rawLink":"分享G.E.M.邓紫棋的单曲《唯一》https://163cn.tv/5ZcJvPj (@网易云音乐)","includePlatformLinks":true}'
```

验收点：

- `/health` 通过 nginx 和 api 都返回 ok。
- `/api/auth/register`、`/api/auth/login`、`/api/auth/me` 可用。
- `/api/resolve` 能解析至少一个 Spotify 或 Apple Music 链接。
- Netease service healthy 时网易云链接可解析。
- QQ Music 依赖安装后 QQ 链接可解析。
- 真机可连接 WebSocket，并收到房间消息广播。

## SQLite Data

默认数据库位于 Docker volume `sideb-data` 中的 `/app/data/sideb.db`。

备份：

```bash
docker compose exec api python -c "import sqlite3; src=sqlite3.connect('/app/data/sideb.db'); dst=sqlite3.connect('/app/data/sideb-backup.db'); src.backup(dst); dst.close(); src.close()"
docker cp sideb-api:/app/data/sideb-backup.db ./sideb-backup-$(date +%Y%m%d-%H%M%S).db
```

恢复：

```bash
docker compose down
docker compose run --rm --no-deps --entrypoint sh -v "$PWD":/backup api -c "cp /backup/sideb-backup.db /app/data/sideb.db"
docker compose up -d
```

本地开发清库后重建：

```bash
rm -f backend/*.db backend/data/*.db
cd backend
alembic upgrade head
```

## Repository Hygiene

- `backend/vendor/` 不部署、不提交，依赖由 `backend/requirements.txt` 安装。
- `.env`、本地 DB、虚拟环境、缓存、Xcode `xcuserdata/` 不进入 Git。
- Xcode Scheme 中的个人 `SIDEB_API_BASE_URL` 不提交。

## Rollback

代码回滚：

```bash
git checkout <known-good-revision>
docker compose up -d --build
```

数据回滚需要先恢复 SQLite backup，再启动容器。
