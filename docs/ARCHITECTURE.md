# Side B Architecture

## 目标架构

Side B 的正式目标架构是：

`iOS Client -> Backend API -> InputParser -> Resolver Service -> Canonical Track -> Platform Links -> iOS Display`

产品整体采用：

- iOS 轻客户端
- 模块化单体 backend
- resolver-first 架构

## 系统边界

### iOS Client

负责：

- 首页歌单 UI
- Rooms / Chat UI
- Link / text input
- 歌曲卡片与详情页展示
- 平台按钮渲染与跳转
- 调用 backend API

不负责：

- 平台链接推导
- metadata 获取
- resolver 候选打分
- 平台 secret 管理
- 业务持久化核心逻辑

### Backend

负责：

- 输入解析
- 平台 source link parsing
- metadata 获取
- canonical track 构建
- 跨平台映射
- 极简用户、聊天室、歌单等产品域
- API 暴露
- 缓存与降级

## Backend 正式结构

目标目录结构：

- `backend/routes`
- `backend/services`
- `backend/resolvers`
- `backend/models`
- `backend/platform_clients`
- `backend/utils`

当前已演进出的平台模块应逐步迁入上述结构，而不是继续堆在入口脚本中。

## 关键内部模型

### ParsedInput

统一表示输入解析结果，支持：

- link
- plain text

### ParsedSource

统一表示来源平台已解析资源：

- source platform
- source url
- resource id
- resource kind

### CanonicalTrack

统一表示 resolver 输出的歌曲核心对象：

- sourcePlatform
- sourceID
- sourceURL
- title
- artistName
- albumTitle
- durationMS
- artworkURL
- isrc

### ResolverContext

统一承载 resolver 运行上下文：

- preferredMarket
- access tokens
- cache stores
- 第三方 client / credentials

## Resolver 分层

### 1. InputParser

统一处理：

- Spotify / Apple / 网易云 / QQ 链接
- 纯文本

输出：

- ParsedInput

### 2. Source Platform Adapters

每个平台 adapter 只负责：

- 识别本平台输入
- 解析 source link
- 获取 source metadata
- 生成 canonical candidate

当前与未来平台：

- Spotify source adapter
- Apple Music source adapter
- Netease source adapter
- QQ source adapter

### 3. Target Platform Resolvers

每个目标平台 resolver 只负责：

- 接收 canonical track
- 搜索候选
- 返回真实链接或 `None`

当前与未来目标：

- Spotify target resolver
- Apple Music target resolver
- Netease target resolver
- QQ target resolver

### 4. Resolver Orchestrator

统一执行：

`InputParser -> source adapter -> canonical resolution -> target platform resolvers -> response assembly`

职责：

- 优先 Spotify canonical
- fallback 原平台 canonical
- 统一按钮顺序
- 统一失败语义

## Canonical 策略

- Spotify 是 preferred canonical metadata source
- 若 source 平台不是 Spotify，系统先尝试将输入稳定映射到 Spotify
- 成功时 canonical source 使用 Spotify
- 失败时 fallback 使用原平台 metadata

这样做的目标是：

- 让后续跨平台映射尽量围绕一个更稳定的 canonical source
- 同时避免为强制 canonical 化而丢失可用 source metadata

## API 设计方向

统一由 backend 对外暴露 REST API。

首批核心接口：

- `POST /resolve-input`
- `POST /resolve-link`
- `POST /resolve-text`
- `GET /health`

当前 resolver 已经采用“两阶段 + 单平台补全”的演进方向：

- `POST /resolve`
  - 支持 metadata-only 模式
  - metadata 成功后即可创建歌曲卡片
- `POST /resolve-platform-link`
  - 单独解析某一个目标平台链接
  - 用于详情页平台按钮按平台独立加载
- `POST /resolve-platform-links`
  - 仍可保留作为批量接口
  - 但客户端不再依赖它阻塞详情页按钮首屏

未来业务域接口：

- playlists
- rooms
- messages
- users
- auth

## 失败与降级语义

- 输入解析失败：不生成 canonical track
- metadata 获取失败：不生成歌曲
- 其他平台链接未命中：仍返回 canonical track，只是少按钮
- source platform 永远显示
- 非 source platform 只有真实命中才显示

当前客户端消费策略进一步细化为：

- 发卡片阶段只依赖 source metadata
- 详情页平台按钮固定占位
- 每个平台独立进入 `idle / loading / ready / unavailable / failed`
- 某一个平台超时或失败，不影响其他平台按钮继续补全

## 平台接入策略

### Spotify

- preferred canonical source
- 官方 metadata 获取
- 官方搜索与匹配

### Apple Music

- source metadata 走 iTunes lookup
- target mapping 走 iTunes Search API + 本地 matcher

### 网易云

- 通过 `api-enhanced` 自部署服务接入
- source adapter 与 target resolver 分离

### QQ 音乐

- 通过 `QQMusicApi` 自部署服务接入
- source adapter 与 target resolver 分离

### 第三方社区库约束

所有第三方社区库只能出现在：

- platform client
- source adapter
- target resolver

不能出现在：

- route
- iOS 客户端
- UI 层

## 聊天、用户、歌单演进

resolver 不是独立旁路，而是整个产品 backend 的基础能力。

后续：

- Home / Playlist
- Chat / Room / Message
- Minimal User / Auth

都应建立在统一 backend 上，而不是继续在 iOS 本地 mock 中演化。

### 聊天系统约束

- 不做独立私信系统
- 双人沟通通过双人聊天室实现
- `Room` 是唯一消息容器，统一覆盖双人房和多人房

### 歌单系统约束

- 首页是歌单系统主入口
- 默认歌单为“已收藏”
- 首页支持直接粘贴外部链接并加入歌单
- 聊天与详情页中的歌曲都可再次收藏到歌单

### 用户系统约束

- 仅保留极简账号体系
- 通过填写对方账号创建聊天室
- 不做好友关系
- 不做邀请 / 同意流程

## 部署目标

backend 最终应支持：

- VPS / 云服务器部署
- 自定义域名
- HTTPS
- 可独立运行的 resolver / API 服务
