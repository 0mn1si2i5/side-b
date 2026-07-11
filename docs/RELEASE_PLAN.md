# Side B Small-Scale Release Plan

## Goal

把 Side B 从“可开发测试”推进到“TestFlight N=20 熟人小规模可用”。

默认发布形态：

- iOS 通过 TestFlight 分发给约 20 位熟人用户。
- 后端部署在个人服务器，使用 Docker Compose、HTTPS、SQLite volume、Netease sidecar 和单 worker WebSocket。
- 项目暂不商业化，不引入复杂后台、企业级权限、好友系统或对象存储。

## Current Gap

- 后端部署链路需要固定：服务器 `git pull`、`.env`、Docker、nginx、HTTPS、日志、健康检查、备份和恢复都要可重复。
- 第三方 resolver 需要降级策略：网易云和 QQ 音乐依赖非官方服务或第三方库，失败时不能表现为 App 无响应。
- iOS 需要完整实机回归：注册、登录、自动登录、房间、消息、歌曲解析、平台跳转、后台切回和深浅色模式。
- 错误提示需要收敛：网络断开、第三方失败、空房间和解析失败优先用非阻断提示。
- 需要最小运维能力：能查看日志、备份/恢复 SQLite、重启服务、回滚代码，并规划简单管理脚本。

## Milestones

### P0: Freeze And Baseline

Agent 要做：

- 整理当前未提交变更，排除本地 Xcode scheme 环境变量，形成可回滚 commit。
- 跑通 `python3 -m pytest backend/tests -q`、`Tests/run_tests.sh`、`xcodebuild ... CODE_SIGNING_ALLOWED=NO build`。
- 检查仓库卫生，确认没有 DB、vendor、`.build`、`xcuserdata`、个人 `.env` 进入 Git。
- 更新文档中的当前状态，不保留过时方向或阶段流水账。

用户要做：

- 确认远程域名、服务器、Apple Developer/TestFlight 路径继续使用。
- 确认本轮不新增大功能，只修稳定性和发布必需项。

验收标准：

- 本地后端、Docker 后端、远程 HTTPS 后端三种路径有明确命令。
- 当前代码能构建，主要测试通过。
- 文档能告诉下一个接手者从哪里继续。

### P1: Production Backend Stabilization

Agent 要做：

- 固化服务器部署步骤：`git pull`、`.env`、`docker compose up -d --build`、日志查看、健康检查。
- 完善 SQLite 备份/恢复说明，至少包含手动备份和恢复命令。
- 明确哪些代码变更需要重启后端，哪些只需 iOS 重新打包。
- 检查 `/health`、auth、resolve、rooms、WebSocket 的公网 smoke test 命令是否完整。
- 为第三方 resolver 失败规划用户可理解错误和日志策略，优先不让失败表现成 App 无响应。

用户要做：

- 在服务器确认 80/443、安全组、DNS、证书续期路径。
- 提供或确认生产 `backend/.env` 中的 Spotify secret、JWT secret、域名 CORS。
- 手动执行一次备份和恢复演练，确认 DB 文件能取回。

验收标准：

- `https://sideb.omnis1215.org/health` 可用。
- 真机使用远程域名能注册、登录、进房间、发文本、发歌曲。
- 服务器重启后容器自动恢复，SQLite 数据仍存在。
- 至少有一份可恢复的 DB backup。

### P2: iOS TestFlight Readiness

Agent 要做：

- 确认 Release/TestFlight 构建需要的 bundle id、signing、version/build number、API base URL 配置路径。
- 文档化 TestFlight 前检查：远程 API URL、登录恢复、深浅色模式、房间消息、歌曲解析、平台跳转。
- 收敛阻断式弹窗：网络断线、解析失败、空房间、第三方失败优先使用非阻断提示。
- 保持 App 内核心流程可在无 Xcode 连接状态下运行。

用户要做：

- 在 Apple Developer / App Store Connect 中创建 App 或确认已有 App。
- 配置 TestFlight 内测成员，先 2-3 人，再扩到 20 人。
- 提供 App 名称、图标、隐私说明、测试说明和必要截图。
- 确认 TestFlight 构建使用远程域名，不再依赖 Xcode scheme 本地变量。

验收标准：

- TestFlight 构建可安装。
- 拔线后 App 能连接远程后端。
- 首次启动、自动登录、退出登录、重新登录均正常。
- 2-3 人灰度无阻断 bug 后再扩容。

### P3: End-To-End User Flow Hardening

Agent 要做：

- 固定手工回归清单：注册/登录/记住密码/自动登录、资料设置、创建/加入/管理房间、文本/歌曲/引用/emoji、历史恢复、四平台解析、歌曲详情、弱网、后台切回、深色模式。
- 为高风险链路补测试：消息时间、排序、历史持久化、join room、room_updated、resolver partial failure。
- 明确第三方服务失败时的预期 UI：歌曲可存在，缺失平台灰化，可重试，不误报全局失败。

用户要做：

- 找 2-3 个熟人做第一轮灰度，收集具体失败截图、输入链接、时间点。
- 提供每个平台至少 3 条真实分享链接作为验收样本。
- 决定网易云/QQ 如果短期不稳定，是否接受“可解析源平台但部分目标链接缺失”。

验收标准：

- 连续一周内核心聊天和歌曲分享无数据丢失。
- 第三方解析失败不会影响房间消息基本使用。
- 熟人用户不需要开发者协助即可完成注册、进房间、分享歌曲。

### P4: Minimal Operations

Agent 要做：

- 文档化最小运维命令：查看容器状态、查看 API 日志、备份 DB、恢复 DB、重启服务、回滚代码。
- 规划最小管理脚本：列用户、禁用/删除测试用户、删除异常房间、导出房间消息或 DB。
- 明确 SQLite 继续可接受的边界：N=20、单服务器、低并发、手动备份。

用户要做：

- 保存服务器 SSH、域名、Apple Developer、Spotify 凭据的安全访问方式。
- 决定备份频率，推荐每日一次，发布前必备份一次。
- 明确如果服务挂了，是否允许短暂停机手动恢复。

验收标准：

- 出问题时能在 10 分钟内定位是 API、nginx、Netease sidecar、DB、还是 iOS 配置。
- 能从最近一次 DB backup 恢复。
- 有明确的发布后一周观察事项。

## Release Checklist

上线前：

- [ ] 当前分支已提交，且不包含本地 scheme API URL、`.env`、DB、vendor、缓存。
- [ ] 后端 pytest、Swift smoke tests、iOS Debug build 通过。
- [ ] 远程服务器 `.env`、Docker Compose、nginx、HTTPS 均确认。
- [ ] SQLite 已完成一次备份和恢复演练。
- [ ] 真机使用远程域名完成注册、登录、房间消息和歌曲分享。
- [ ] TestFlight 构建使用远程后端，不依赖 Xcode 本地环境变量。

上线当天：

- [ ] `git pull` 后按部署文档重建或重启必要服务。
- [ ] 公网 `/health`、auth、resolver、rooms、WebSocket smoke test 通过。
- [ ] 先邀请 2-3 位熟人安装 TestFlight。
- [ ] 收集失败截图、输入链接、用户账号、发生时间和服务器日志时间窗口。

上线后一周：

- [ ] 每天检查容器状态、API 错误日志和 SQLite backup。
- [ ] 记录 resolver 失败最多的平台和样本链接。
- [ ] 确认消息历史、房间成员、自动登录和歌曲卡片没有数据丢失。
- [ ] 灰度稳定后扩展到 20 人。

## Do Not Expand Yet

- 不做商业化、支付、复杂审核后台或增长功能。
- 不做好友系统、邀请审批、复杂权限或私信域拆分。
- 不引入对象存储、Redis、Postgres 或消息队列，除非 N=20 实测证明 SQLite/单机/单 worker 不够。
- 不用搜索结果页伪装成平台命中链接；平台链接只有真实命中时才可点击。

## References

- 本地运行和测试入口：`README.md`
- 部署命令和运维细节：`docs/DEPLOYMENT.md`
- 当前任务索引：`docs/TASKS.md`
- 架构约束：`docs/ARCHITECTURE.md`
