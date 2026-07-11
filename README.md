# Side B

Side B 是一个以跨平台歌曲解析、收藏和房间分享为核心的 iOS App。

核心路径是：

```text
iOS Client -> FastAPI Backend -> Music Resolver -> Room / Playlist UI
```

## 当前状态

### iOS

- 歌曲页支持粘贴 Spotify、Apple Music、网易云音乐、QQ 音乐链接或带前后文的分享文案。
- 最近解析、歌单和歌曲详情使用本地缓存保存 canonical track 与平台链接补全结果。
- 歌曲详情页使用专辑封面氛围背景、玻璃平台栏和四平台跳转按钮。
- 房间页支持文本消息、链接发歌、歌曲卡片、引用回复、emoji 回应和 WebSocket 实时同步。
- 设置页支持显示名称、头像、常用平台和浅色/深色/跟随系统外观设置。
- 注册、登录和资料修改使用 15 个预置头像；登录支持 Keychain 记住密码和自动恢复登录。

### Backend

- FastAPI 统一提供认证、用户资料、房间、消息、WebSocket 与 resolver API。
- SQLite 是个人服务器 v1 默认数据库，Docker 通过 volume 持久化。
- 所有房间消息通过 REST API 持久化，WebSocket 只负责服务端广播。
- resolver 支持 Spotify、Apple Music、网易云音乐、QQ 音乐 source 解析与 target link mapping。
- 网易云音乐依赖独立 Netease-compatible API 服务；QQ 音乐依赖 `qqmusic-api-python`。

## 本地运行

### 1. 安装依赖

```bash
pip install -r backend/requirements.txt
```

### 2. 配置后端环境

```bash
cp backend/.env.example backend/.env
```

`backend/.env` 至少需要：

```env
SPOTIFY_CLIENT_ID=...
SPOTIFY_CLIENT_SECRET=...
JWT_SECRET=...
NETEASE_API_BASE_URL=http://127.0.0.1:3000
```

常用可选项：

```env
FASTAPI_HOST=0.0.0.0
FASTAPI_PORT=8788
DATABASE_URL=sqlite:///./data/sideb.db
CORS_ORIGINS=http://localhost:3000,http://localhost:5173
APPLE_MUSIC_STOREFRONT=cn
NETEASE_REQUEST_TIMEOUT=10
```

### 3. 启动网易云 API 服务

本地开发时，先让 Netease-compatible API 服务运行在 `NETEASE_API_BASE_URL` 指向的地址，例如：

```text
http://127.0.0.1:3000
```

如果使用仓库内的 compose sidecar，可以只启动网易云服务：

```bash
docker compose up -d netease
curl -i "http://127.0.0.1:3000/song/detail?ids=2083785152"
```

本地 `uvicorn` 会通过 `NETEASE_API_BASE_URL=http://127.0.0.1:3000` 访问它。Docker 部署时，`api` 容器会通过 compose 内网的 `http://netease:3000` 访问同一个服务。

### 4. 启动 FastAPI

```bash
cd backend
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8788
```

### 5. iOS 指向后端

本地真机调试时，在 Xcode Scheme 环境变量中设置：

```text
SIDEB_API_BASE_URL=http://<Mac局域网IP>:8788
```

真机不能使用 `127.0.0.1` 指向 Mac。服务器部署后可使用：

```text
SIDEB_API_BASE_URL=https://<your-domain>
```

## Docker 运行

```bash
cp backend/.env.example backend/.env
docker compose up --build
```

Docker 默认包含：

- `api`：FastAPI backend，启动时运行 Alembic migration。
- `netease`：网易云兼容 API sidecar。
- `nginx`：反向代理、限流和 `/health`。
- `certbot`：按 profile 手动申请或续期证书。

更多部署细节见 [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)。

## 测试

```bash
python3 -m pytest backend/tests -q
Tests/run_tests.sh
xcodebuild -list -project "Side B.xcodeproj"
```

如果 Xcode Simulator 或 DerivedData 权限导致 `xcodebuild` 警告，先记录为本机环境问题；后端 pytest 和 Swift smoke tests 仍应保持通过。

## 仓库规则

- `backend/vendor/`、虚拟环境、缓存、本地 SQLite 数据库、Xcode `xcuserdata/` 不进入 Git。
- 后端 Python 依赖以 `backend/requirements.txt` 为准。
- 本地 API URL 可放在 Xcode Scheme，但不要提交个人环境变量改动。
- SQLite 是运行数据；清库后用 `alembic upgrade head` 重建 schema。

## 当前开发方向

当前优先目标是 TestFlight N=20 熟人小规模发布。发布前稳定化、验收、部署和运维任务以 [docs/RELEASE_PLAN.md](docs/RELEASE_PLAN.md) 为准。

1. 保持本地、真机、Docker、远程 HTTPS 四套运行方式稳定。
2. 完成服务器 HTTPS、SQLite 备份/恢复和 TestFlight 发布流程固化。
3. 提升 resolver 第三方失败诊断、用户反馈和手工验收路径。
4. 在不扩张复杂社交系统的前提下，继续打磨房间、歌单和歌曲详情体验。
