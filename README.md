# Side B

一个轻量级跨平台歌曲分享 iOS App。

## 当前状态

当前仓库已经不是纯 mock UI。

主链路现状：

- iOS 聊天主路径可用
- 支持文本消息、粘贴链接发歌、引用歌曲消息
- 歌曲卡片可进入详情页
- 详情页当前聚焦：
  - 封面
  - 歌名
  - 艺人
  - 专辑
  - 来源平台
  - 平台按钮

Resolver / backend 现状：

- 已有本地 resolver 服务落点：`backend/spotify_resolver_server.py`
- 已打通 `Spotify -> canonical track -> iOS detail UI`
- 已打通 `Apple Music -> canonical track -> iOS detail UI`
- 已支持：
  - Spotify metadata 真实获取
  - Apple Music metadata 真实获取
  - Apple Music <-> Spotify 双向链接映射
  - Apple Music artwork 高清 URL 返回
  - 中文简繁归一化

当前平台策略：

- 源平台永远显示
- 其它平台只有命中真实链接时才显示

## 当前技术路线

正式路线是：

`iOS client -> resolver service / backend -> canonical track -> platform links`

职责划分：

- iOS 客户端负责输入、展示、跳转
- resolver / backend 负责链接解析、metadata 获取、跨平台映射

当前不做：

- 站内播放
- 复杂歌词
- 社区系统
- 在 SwiftUI View 中写平台解析逻辑

## 下一阶段

下一阶段优先顺序：

1. 网易云音乐
   - 先做网易云作为输入源
   - 目标是三平台彼此双向连接：Spotify / Apple Music / 网易云音乐
2. QQ 音乐
   - 再扩到四平台彼此双向连接：Spotify / Apple Music / 网易云音乐 / QQ 音乐

说明：

- 网易云音乐方向优先按开放平台 / resolver 思路推进
- 当前已看到第三方资料引用网易云开放平台接口路径，例如：
  - `/openapi/music/basic/search/song/get/v3`
  - `/openapi/music/basic/song/detail/get/v2`
- 这组接口路径本轮未直接在官方文档页完成验证，后续接入前需要再次核对

## 仓库结构

- `Side B/`：iOS 客户端
- `docs/`：产品、架构、任务文档
- `backend/`：resolver / backend
- `prompts/`：提示词模板
