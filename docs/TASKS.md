# Side B Tasks

## Current Baseline

- iOS 已接入 FastAPI：认证、用户资料、房间、消息、WebSocket、resolver。
- 歌曲页支持链接解析、最近解析、歌单和详情页平台跳转。
- 房间页支持文本消息、歌曲消息、引用回复、emoji 回应和历史消息持久化。
- 设置页支持显示名称、头像、常用平台和 App 外观设置。
- 后端支持 Spotify、Apple Music、网易云音乐、QQ 音乐 source 解析与 target link mapping。
- Docker Compose 可启动 `api`、`netease`、`nginx`，并使用 SQLite volume 作为 v1 持久化方案。

## Current Goal

当前目标是推进 TestFlight N=20 熟人小规模发布。发布前稳定化主计划见 [RELEASE_PLAN.md](RELEASE_PLAN.md)。

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

- [ ] P0 Freeze And Baseline：提交当前稳定变更，排除本地 scheme，完成后端/iOS 构建和测试。
- [ ] P1 Production Backend Stabilization：完成服务器 HTTPS、证书续期、SQLite 备份恢复和公网 smoke test。
- [ ] P2 iOS TestFlight Readiness：确认远程 API URL、签名、版本号、TestFlight 安装和核心流程。
- [ ] P3 End-To-End User Flow Hardening：完成 2-3 人灰度、四平台样本、房间消息和歌曲分享回归。
- [ ] P4 Minimal Operations：固定日志、备份、恢复、重启、回滚和最小管理脚本计划。

## Backlog

- [ ] 平台链接缓存过期、清理和调试入口。
- [ ] 房间成员在线状态和更明确的同步状态。
- [ ] 歌单导出或分享能力。
- [ ] 更完整的服务端备份与恢复脚本。
- [ ] 多端支持前的 API 契约整理。
