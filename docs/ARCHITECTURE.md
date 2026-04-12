# Side B 架构说明

## 当前实际架构

当前项目应按下面这条链路理解：

`客户端输入链接 -> resolver service / backend -> canonical track -> iOS 展示与跳转`

不是：

- 纯前端 mock 项目
- 在客户端内直接做完整平台解析

## 职责边界

### iOS Client

负责：

- Rooms / Chat UI
- Link input
- 歌曲卡片与详情页展示
- 平台按钮渲染
- 调用 resolver

不负责：

- 持有平台 secret
- 写平台搜索 / 匹配逻辑
- 在 View 中拼平台链接

### Resolver / Backend

负责：

- 链接解析
- 平台识别
- 资源 ID 提取
- 平台 metadata 获取
- canonical track 组装
- 跨平台链接映射
- 结果缓存

当前已落地：

- Spotify source resolving
- Apple Music source resolving
- Apple Music <-> Spotify 双向链接映射
- Apple Music artwork 高清 URL 返回
- 中文简繁归一化

## Canonical Track

客户端消费对象继续统一到 `Track`。

当前关键字段：

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

设计原则：

- `Track` 不等于任一平台原始响应
- 平台 provider / resolver 负责映射
- `platformLinks` 是唯一平台按钮来源

## 当前平台策略

- 源平台永远显示
- 非源平台只有命中真实链接时才显示
- 不再返回“搜索页 fallback 按钮”

## 当前已支持的平台主链路

### Spotify 作为输入源

已支持：

- 链接识别
- track id 提取
- Spotify metadata 获取
- canonical track 返回
- Apple Music 真实链接映射

### Apple Music 作为输入源

已支持：

- 链接识别
- track id 提取
- iTunes lookup 获取 metadata
- canonical track 返回
- Spotify 真实链接映射

## 下一阶段架构目标

### Phase 1：网易云音乐

目标：

- 接入网易云作为第三个 source platform
- 形成三平台双向连接：
  - Spotify
  - Apple Music
  - 网易云音乐

当前计划：

- 优先走 resolver / backend
- 优先验证网易云开放平台路径
- 先打通：
  - 链接解析
  - song id 提取
  - metadata 获取
  - canonical track 返回
- 再补跨平台映射

说明：

- 当前已看到第三方资料引用网易云开放平台接口路径：
  - `/openapi/music/basic/search/song/get/v3`
  - `/openapi/music/basic/song/detail/get/v2`
- 这组路径后续接入前需要再次做官方来源核对

### Phase 2：QQ 音乐

目标：

- 扩展到四平台双向连接：
  - Spotify
  - Apple Music
  - 网易云音乐
  - QQ 音乐

策略：

- 先保证网易云三平台链路稳定
- 再进入 QQ 音乐 source path

## 当前不做

- 站内播放
- 歌词主链路
- 社区功能
- 大规模推荐能力
- 将复杂平台逻辑回灌到 SwiftUI View
