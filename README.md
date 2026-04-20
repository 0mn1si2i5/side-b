# Side B

一个以多平台歌曲解析与跳转为核心的 iOS App。

当前版本的核心体验不是播放，而是：

- 粘贴链接
- 解析歌曲
- 展示歌曲卡片
- 跳转到用户自己的音乐平台

## 当前状态

当前仓库已经不是纯 mock 原型，主链路已具备真实 resolver 能力。

### iOS 侧

- 聊天主路径可用
- 支持文本消息、链接发歌、引用歌曲消息
- 歌曲卡片可进入详情页
- 详情页展示：
  - 封面
  - 歌名
  - 艺人
  - 专辑
  - 来源平台
  - 平台按钮
- 平台按钮按平台独立加载，不再整块阻塞

### Backend / Resolver 侧

- 已有本地 resolver 服务：FastAPI (端口 8788)，旧 `spotify_resolver_server.py` 已废弃
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

`iOS Client -> Backend Resolver API -> Canonical Track -> Platform Links -> iOS Display`

职责划分：

- iOS 负责输入、展示、交互、跳转
- backend 负责链接解析、metadata 获取、跨平台匹配、失败语义与缓存

当前不做：

- 站内播放
- 好友系统
- 私信系统
- 复杂社交关系
- 在 SwiftUI View 中写平台解析逻辑

## 本地运行

### 1. 安装 backend 依赖

```bash
pip install -r backend/requirements.txt
```

### 2. 配置环境变量

在 `backend/.env` 中至少配置：

```env
SPOTIFY_CLIENT_ID=...
SPOTIFY_CLIENT_SECRET=...
JWT_SECRET=...
NETEASE_API_BASE_URL=http://127.0.0.1:3000
```

可选：

```env
APPLE_MUSIC_STOREFRONT=cn
NETEASE_REQUEST_TIMEOUT=10
PORT=8788
HOST=0.0.0.0
```

### 3. 启动网易云 api-enhanced

当前网易云接入依赖独立运行的 `api-enhanced` 服务，例如：

```bash
# 你的网易云服务应运行在 .env 中配置的 NETEASE_API_BASE_URL
http://127.0.0.1:3000
```

### 4. 启动 Side B resolver (FastAPI)

```bash
uvicorn backend.app.main:app --host 0.0.0.0 --port 8788
```

> 旧 `spotify_resolver_server.py` 已废弃，所有功能已迁移至 FastAPI (端口 8788)

默认监听：

```text
http://0.0.0.0:8788
```

### 5. iOS 端指向本地 resolver

在 Xcode Scheme 的环境变量里设置：

```text
SIDEB_RESOLVER_BASE_URL=http://<你的Mac局域网IP>:8788
```

真机运行时不能使用 `127.0.0.1`，必须使用 Mac 在局域网中的可访问地址。

## 仓库结构

- `Side B/`：iOS 客户端
- `backend/`：resolver backend
- `docs/`：产品、架构、路线文档
- `prompts/`：提示词模板

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

1. 首页歌单入口
2. 极简用户系统与聊天室后端化
3. 平台补全缓存的淘汰/清理策略
