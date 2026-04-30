# Side B PRD

## Product Positioning

Side B 将不同音乐平台里的歌曲链接转换成统一歌曲对象，并让用户围绕歌曲完成收藏、跳转和房间分享。

核心用户是经常互相分享音乐、但使用不同音乐平台的小群体。

## Product Principles

- resolver 是核心能力，必须保守匹配，避免错误歌曲链接。
- iOS 负责输入、展示、跳转和轻量本地缓存。
- backend 负责平台 API、metadata、候选搜索、匹配打分和房间消息持久化。
- 社交能力围绕 Room、成员、消息、引用和 emoji 保持最小闭环。

## Core Capabilities

### Music Input

支持输入：

- Spotify 链接
- Apple Music 链接
- 网易云音乐链接
- QQ 音乐链接
- 带前后文的分享文案

`InputParser` 从输入中提取干净链接，并识别来源平台和资源 ID。

### Canonical Track

统一歌曲对象包含：

- `title`
- `artistName`
- `albumTitle`
- `durationMS`
- `artworkURL`
- `sourcePlatform`
- `sourcePlatformID`
- `sourceURL`
- `isrc`
- `platformLinks`

source platform 与 source URL 始终保留，用于历史消息、详情页和平台按钮语义。

### Resolver

当前平台策略：

- Spotify：官方 API，作为 preferred canonical metadata source。
- Apple Music：iTunes lookup/search。
- 网易云音乐：Netease-compatible API 服务。
- QQ 音乐：`qqmusic-api-python`。

解析成功以 metadata 成功为准。其他平台链接可以在详情页异步补全，单个平台失败不影响歌曲卡片存在。

### Songs And Playlists

用户可以：

- 在歌曲页粘贴链接解析歌曲。
- 查看最近解析。
- 创建、重命名、删除歌单。
- 将歌曲加入默认“已收藏”或自定义歌单。
- 从歌曲详情页或房间歌曲卡片进入详情，再执行收藏或平台跳转。

### Rooms

用户可以：

- 创建房间。
- 邀请成员。
- 重命名或解散房间。
- 发送文本消息。
- 粘贴链接发送歌曲卡片。
- 引用回复消息。
- 对消息添加 emoji 回应。
- 点击歌曲卡片进入歌曲详情页。

消息由 backend 持久化。WebSocket 负责在线广播，历史消息由 REST 拉取。

### User And Settings

用户系统包含：

- 注册 / 登录。
- JWT 会话。
- Keychain 记住密码和自动登录恢复。
- 显示名称修改。
- 15 个预置头像。
- 常用平台偏好。
- 浅色 / 深色 / 跟随系统外观。

## Current Product Scope

- 歌曲消费方式是跳转到用户自己的音乐平台。
- 平台按钮只在真实命中可直达链接时可用。
- 不用搜索页 fallback 伪装成命中结果。
- 房间是一对一和多人聊天的统一承载模型。
- v1 部署目标是个人服务器、Docker Compose、SQLite volume。

## Success Criteria

- 四平台输入都能稳定生成 canonical track。
- 房间消息、歌曲消息和历史消息在重启 App 后仍可恢复。
- 歌曲详情页能展示源平台和已命中的其他平台链接。
- 用户资料、头像、常用平台和记住密码在真机上可用。
- Docker 部署后 `/health`、auth、resolver、rooms、WebSocket 主链路可通过 smoke test。
