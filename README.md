# Side B

一个以多平台歌曲解析与跳转为核心的 iOS App。

当前版本的核心体验：

- 粘贴链接
- 解析歌曲
- 展示歌曲卡片
- 跳转到用户自己的音乐平台

## 当前状态

当前仓库主链路已具备真实 resolver 能力。

### iOS 侧

- 聊天主路径已接入后端持久化
- 支持文本消息、链接发歌、引用回复、emoji 回应
- WebSocket 只用于接收后端广播，历史消息以 REST 拉取为准
- 歌曲卡片可进入详情页
- 详情页展示：
  - 封面
  - 歌名
  - 艺人
  - 专辑
  - 来源平台
  - 平台按钮
- 平台按钮按平台独立加载

### Backend / Resolver 侧

- 已有本地 FastAPI 服务：认证、房间、消息、WebSocket、resolver 均在端口 8788
- 已有极简用户系统：注册、登录、JWT、头像池、常用平台偏好
- 已有极简聊天室系统：单一 Room 模型、成员、历史消息、emoji、软删除
- 已支持源平台解析：
  - Spotify
  - Apple Music
  - 网易云音乐
  - QQ 音乐
- 已支持目标平台映射：
  - Spotify
  - Apple Music
  - 网易云音乐
  - QQ 音乐
- 已支持两阶段链路：
  1. metadata-only 解析成功后立即创建卡片
  2. 详情页异步补全其他平台链接
- 已支持平台链接补全结果本地持久化：
  - 同一首歌的补全结果可在本机复用
  - 重进详情页、重进房间、重启 App 后仍可命中已缓存结果

### 当前平台规则

- 源平台永远显示
- 其他平台只有命中真实链接时才显示
- metadata 失败不生成歌曲卡片
- 其他平台匹配失败不影响歌曲卡片创建

## 当前技术路线

正式路线：

`iOS Client -> Backend API -> Resolver / Rooms / Messages -> iOS Display`

职责划分：

- iOS 负责输入、展示、交互、跳转
- backend 负责用户认证、房间消息持久化、链接解析、metadata 获取、跨平台匹配、失败语义与缓存

当前范围：

- 歌曲消费方式是平台跳转
- 聊天关系通过 Room 成员管理
- 社交能力保持在房间、成员、消息、emoji 的最小闭环
- 平台解析逻辑集中在 backend service / resolver / platform client

## 本地运行

### 1. 安装 backend 依赖

```bash
pip install -r backend/requirements.txt
```

### 2. 配置环境变量

复制示例文件并填写密钥：

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

可选：

```env
FASTAPI_HOST=0.0.0.0
FASTAPI_PORT=8788
DATABASE_URL=sqlite:///./data/sideb.db
CORS_ORIGINS=http://localhost:3000,http://localhost:5173
APPLE_MUSIC_STOREFRONT=cn
NETEASE_REQUEST_TIMEOUT=10
```

### 3. 启动网易云 api-enhanced

当前网易云接入依赖独立运行的 `api-enhanced` 服务，例如：

```bash
# 你的网易云服务应运行在 .env 中配置的 NETEASE_API_BASE_URL
http://127.0.0.1:3000
```

### 4. 启动 Side B API (FastAPI)

```bash
cd backend
alembic upgrade head
uvicorn app.main:app --host 0.0.0.0 --port 8788
```

> 所有后端功能统一通过 FastAPI 提供。

默认监听：

```text
http://0.0.0.0:8788
```

### 5. iOS 端指向本地 API

在 Xcode Scheme 的环境变量里设置：

```text
SIDEB_API_BASE_URL=http://<你的Mac局域网IP>:8788
```

真机运行时不能使用 `127.0.0.1`，必须使用 Mac 在局域网中的可访问地址。

新开发统一使用 `SIDEB_API_BASE_URL`。

### 6. 运行测试

```bash
python3 -m pytest backend/tests -q
Tests/run_tests.sh
xcodebuild -list -project "Side B.xcodeproj"
```

如本机 Xcode Simulator 或 DerivedData 权限导致 `xcodebuild` 警告，先记录环境问题；代码基线以可列出 scheme 和后端测试通过为准。

## Docker 本地运行

```bash
cp backend/.env.example backend/.env
docker compose up --build
```

Docker 默认使用 SQLite volume 和单个 Uvicorn worker。WebSocket 当前使用进程内连接管理。

部署到个人服务器前，按 [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) 做环境变量、healthcheck、resolver、WebSocket 和 SQLite 备份检查。

## 仓库结构

- `Side B/`：iOS 客户端
- `backend/`：resolver backend
- `docs/`：产品、架构、路线文档

## 当前后端依赖策略

- Spotify：直接请求官方 API
- Apple Music：`iTunes lookup + iTunes Search API`
- 网易云音乐：独立 `api-enhanced` 服务
- QQ 音乐：直接集成 `QQMusicApi` Python 库

注意：

- `backend/vendor/` 已被忽略，不作为正式提交内容
- 新开发者拉仓库后，需要先执行 `pip install -r backend/requirements.txt`

## 下一步

当前最合理的产品方向是：

1. 保持本地启动、测试与实机调试闭环可靠
2. 完成个人服务器 Docker 部署、域名与 HTTPS
3. 完善平台服务可观测性、缓存清理与备份策略
