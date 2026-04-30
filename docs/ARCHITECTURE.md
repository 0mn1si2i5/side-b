# Side B Architecture

## Overview

Side B 当前是一个 iOS 轻客户端 + FastAPI 模块化单体后端。

```text
iOS Client -> FastAPI API -> Resolver / Auth / Rooms / Messages -> SQLite + third-party music APIs
```

后端是业务核心：负责认证、房间消息持久化、平台 secret、metadata 获取、候选搜索和跨平台匹配。iOS 负责输入、展示、缓存、跳转和实时状态呈现。

## iOS Client

主要模块：

- `Features/Playlists`：歌曲页、最近解析、歌单和本地歌单存储。
- `Features/Rooms`：房间列表、房间详情、消息输入、歌曲卡片和房间管理。
- `Features/Auth`：登录、注册、头像选择和认证 UI。
- `Features/Shell`：主 Tab、歌曲详情、发送歌曲到房间、设置页。
- `Core/Services`：API service、Keychain token/credential、WebSocket、本地缓存和 resolver client。

本地持久化：

- JWT token 与记住密码凭据存入 Keychain。
- 最近解析、歌单、track cache、平台链接补全结果存入 `UserDefaults`。
- 图片使用内存缓存和 URLSession cache。

## Backend

主要结构：

- `backend/app/routers`：FastAPI routes。
- `backend/app/services`：auth、user、room、message、WebSocket orchestration。
- `backend/services`：resolver 编排、input parser、source adapter 聚合。
- `backend/resolvers`：各平台 target resolver。
- `backend/platform_clients`：第三方 API 或第三方库封装。
- `backend/models`：resolver domain models。

后端运行数据：

- SQLite 是 v1 默认数据库。
- Alembic 负责 schema migration。
- Docker 使用 `sideb-data` volume 保存数据库。

## Resolver Flow

`POST /api/resolve`：

- 从用户输入或分享文案中提取音乐链接。
- 识别 source platform。
- 获取 source metadata 并构建 canonical track。
- 可选同步补全其他平台链接。

`POST /api/resolve-platform-link`：

- 对已知 canonical track 补全单个平台链接。
- 详情页按平台独立加载和回写本地缓存。

平台策略：

- Spotify 使用官方 API。
- Apple Music 使用 iTunes lookup/search。
- 网易云音乐通过 Netease-compatible API sidecar。
- QQ 音乐通过 `qqmusic-api-python`。
- 非源平台只有命中真实歌曲链接才显示为可点击。

## Rooms And Messages

Room 是唯一消息承载单元。

- `POST /api/rooms` 创建房间。
- `GET /api/rooms` 拉取当前用户房间列表。
- `GET /api/rooms/{room_id}/messages` 拉取历史消息。
- `POST /api/rooms/{room_id}/messages` 创建文本、歌曲和引用消息。
- `WS /ws/rooms/{room_id}` 接收 `new_message`、emoji、删除和房间更新广播。

同步规则：

- iOS 创建消息必须先走 REST 持久化。
- 后端持久化成功后广播给在线成员。
- iOS 重新进入房间以 REST 历史消息为准。
- Docker v1 使用单 worker，因为 WebSocket 连接管理在进程内。

## Auth And Profile

认证能力：

- 注册、登录、JWT、`/api/auth/me`。
- iOS 启动时优先用 Keychain token 恢复会话。
- token 失效时可用 Keychain 保存的记住密码凭据静默重新登录。
- 显式退出会清理 token 和记住密码凭据。

用户资料：

- `displayName`
- `avatarName`
- `preferredPlatform`

头像由预置头像池提供，不依赖上传或对象存储。

## Deployment

Docker Compose 服务：

- `api`：FastAPI、Alembic、resolver、QQ Music client。
- `netease`：网易云音乐兼容 API。
- `nginx`：公网入口、反向代理、限流、healthcheck。
- `certbot`：证书申请和续期。

关键约束：

- `UVICORN_WORKERS=1`。
- SQLite volume 需要备份策略。
- `backend/vendor/` 不作为交付物，依赖通过 `backend/requirements.txt` 安装。

## Development Direction

1. 保持本地、真机、Docker 运行闭环稳定。
2. 固化服务器部署、HTTPS、备份和恢复。
3. 提升 resolver 第三方失败的日志、诊断和用户反馈。
4. 为认证恢复、房间历史、消息顺序、平台链接补全补测试。
