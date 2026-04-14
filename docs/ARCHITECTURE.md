# Side B Architecture

## 总体目标

Side B 的目标不是做播放器，而是做一套可部署的多平台歌曲解析与分享系统。

当前正式架构方向：

`iOS Client -> Backend API -> Source Parsing -> Canonical Track -> Target Link Resolution -> iOS Display`

整体采用：

- iOS 轻客户端
- 模块化单体 backend
- resolver-first 架构

## 客户端与后端边界

### iOS Client

负责：

- 首页歌单 UI
- 聊天室 UI
- 输入歌曲链接
- 展示歌曲卡片与详情页
- 平台按钮渲染与跳转
- 调用 resolver API

不负责：

- 平台链接推导
- metadata 获取
- 匹配策略与打分
- 平台密钥管理
- 第三方服务接入

### Backend

负责：

- 输入解析
- 来源平台识别
- metadata 获取
- canonical track 构建
- 跨平台目标链接匹配
- 缓存与超时控制
- 后续用户、聊天室、歌单域能力

## 当前 backend 结构

当前仓库已按以下结构收口：

- `backend/routes`
- `backend/services`
- `backend/resolvers`
- `backend/models`
- `backend/platform_clients`
- `backend/utils`

约束：

- route 只做 HTTP 协议与 response assembly
- service 做 orchestration
- resolver 处理平台级 source / target 逻辑
- platform client 封装第三方服务或第三方库

## 关键内部模型

### ParsedSource

表示已识别的来源平台资源：

- `platform`
- `source_url`
- `resource_id`
- `resource_kind`

### CanonicalTrack

表示统一歌曲对象：

- `source_platform`
- `source_id`
- `source_url`
- `title`
- `artist_name`
- `album_title`
- `duration_ms`
- `artwork_url`
- `isrc`

### ResolverContext

承载 resolver 运行上下文：

- `preferred_market`
- `spotify_access_token`
- `netease_api_base_url`
- cache stores

## Resolver 分层

### 1. Source Platform Adapters

每个平台 source adapter 只负责：

- 判断能否处理输入
- 从链接中提取资源 ID
- 获取 source metadata
- 构建 canonical track

当前已存在：

- `SpotifySourceAdapter`
- `AppleMusicSourceAdapter`
- `NeteaseSourceAdapter`
- `QQMusicSourceAdapter`

### 2. Target Platform Resolvers

每个平台 target resolver 只负责：

- 接收 canonical track
- 搜索目标平台候选
- 返回真实歌曲链接或 `None`

当前已存在：

- `SpotifyTargetResolver`
- `AppleMusicTargetResolver`
- `NeteaseTargetResolver`
- `QQMusicTargetResolver`

### 3. Route / Orchestration

当前 resolver 路径已采用两阶段模型：

- `POST /resolve`
  - 支持 metadata-only
  - 解析成功即可创建歌曲卡片
- `POST /resolve-platform-link`
  - 单独解析某一个目标平台
- `POST /resolve-platform-links`
  - 批量解析接口，保留为后端能力

## 当前客户端交互模型

### 发歌阶段

- 只依赖 metadata 成功
- 一旦 canonical track 构建成功，就立即创建歌曲卡片
- 不等待所有平台按钮同步完成

### 详情页阶段

- 四个平台位置固定存在
- 源平台立即可点击
- 先读本地平台链接持久化结果，再决定是否发请求
- 其他平台独立进入以下状态：
  - `idle`
  - `loading`
  - `ready`
  - `unavailable`
  - `failed`
- 某一个平台超时或失败，不影响其他平台继续补全

## 平台接入方式

### Spotify

- 官方 API
- 用于 source metadata 与 target 匹配
- 当前是 preferred canonical metadata source

### Apple Music

- source metadata：`iTunes lookup`
- target mapping：`iTunes Search API + 本地 matcher`

### 网易云音乐

- 依赖独立 `api-enhanced` 服务
- 通过 `NETEASE_API_BASE_URL` 接入

### QQ 音乐

- 直接集成 `QQMusicApi` Python 库
- 不额外起独立 HTTP 服务
- share 短链由 resolver 内部解析

## 当前失败语义

- 输入无法识别：不生成歌曲卡片
- metadata 获取失败：不生成歌曲卡片
- 某目标平台匹配失败：只是不显示该按钮
- 源平台按钮永远显示
- 非源平台只有真实命中才显示

## 下一阶段架构重点

1. 首页歌单系统
2. 用户、聊天室、歌单域后端化
3. 平台补全缓存的淘汰/清理策略
4. 进一步推进客户端脱离 mock fallback
