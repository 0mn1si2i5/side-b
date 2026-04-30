# Side B Tasks

## Current Baseline

- iOS 已接入 FastAPI：认证、用户资料、房间、消息、WebSocket、resolver。
- 歌曲页支持链接解析、最近解析、歌单和详情页平台跳转。
- 房间页支持文本消息、歌曲消息、引用回复、emoji 回应和历史消息持久化。
- 设置页支持显示名称、头像、常用平台和 App 外观设置。
- 后端支持 Spotify、Apple Music、网易云音乐、QQ 音乐 source 解析与 target link mapping。
- Docker Compose 可启动 `api`、`netease`、`nginx`，并使用 SQLite volume 作为 v1 持久化方案。

## Active Work

- [x] 修复房间消息 REST 持久化与 WebSocket 广播主路径。
- [x] 修复歌曲详情页沉浸式背景、平台按钮和发送/收藏入口。
- [x] 支持设置页修改显示名称和头像。
- [x] 支持 15 个预置头像。
- [x] 修复启动时失效 token 反复触发自动登录失败提示。
- [x] 增加 Keychain 记住密码和静默重新登录。
- [x] 清理本地 SQLite 开发数据库并保留 Alembic 重建路径。
- [x] 清理仓库中的 vendor、缓存、Xcode 用户态文件和本地数据库。

## Near-Term Work

- [ ] 完成可用 Xcode 环境下的 Debug build 验证。
- [ ] 完成服务器 HTTPS、证书续期和 SQLite volume 备份恢复验收。
- [ ] 增加部署后 smoke test 记录：auth、resolve、room message、WebSocket。
- [ ] 为 resolver 第三方失败增加更清晰的日志和用户可理解错误。
- [ ] 补齐自动登录、记住密码、房间消息历史和 resolver 边界测试。

## Backlog

- [ ] 平台链接缓存过期、清理和调试入口。
- [ ] 房间成员在线状态和更明确的同步状态。
- [ ] 歌单导出或分享能力。
- [ ] 更完整的服务端备份与恢复脚本。
- [ ] 多端支持前的 API 契约整理。
