# TASKS

## Phase 0：现状分析与重构规划

- [x] 完成 Master Plan 文档
- [x] 统一 PRD / ARCHITECTURE / TASKS 文档口径
- [x] 盘点当前 iOS 与 backend 结构的保留/修改/删除项
- [x] 明确 backend 模块化单体目录结构

## Phase 1：基础架构重构

- [ ] 新增 InputParser 统一入口
- [x] 定义 ParsedInput / ParsedSource / CanonicalTrack / ResolverContext
- [x] 收口 backend 为 routes / services / resolvers / models / platform_clients / utils
- [x] 将入口脚本瘦身为 app entry / route bootstrap
- [ ] 建立 `/resolve-input` / `/resolve-link` / `/resolve-text` / `/health`
- [x] 固化失败与降级语义
- [x] 建立 metadata-only 与平台链接异步补全两阶段主链路
- [x] 建立详情页按平台独立加载的按钮状态模型

## Phase 2：Spotify 主链路

- [ ] 固化 Spotify preferred canonical 策略
- [x] 完善 Spotify metadata 获取与 canonical 构建
- [x] 完善 Spotify search / matching / cache / market fallback
- [x] 回归验证 Spotify source path

## Phase 3：Apple Resolver

- [x] 固化 Apple source adapter
- [x] 固化 Apple target resolver
- [x] 稳定 iTunes lookup + Search matcher
- [x] 验证 Apple source -> Spotify link

## Phase 4：网易云 Resolver

- [x] 接入 api-enhanced 自部署服务
- [x] 实现 Netease source adapter
- [x] 实现 Netease target resolver
- [x] 打通 Spotify / Apple / 网易云三平台链路

## Phase 5：QQ Resolver

- [ ] 接入 QQMusicApi 自部署服务
- [ ] 实现 QQ source adapter
- [ ] 实现 QQ target resolver
- [ ] 打通四平台链路

## Phase 6：统一 Resolver Service

- [ ] 新建统一 orchestration service
- [ ] 实现 canonical source 优先级策略
- [ ] 实现平台按钮统一编排
- [ ] 实现置信度与 diagnostics 内部结构
- [ ] 补 source adapter / target resolver / orchestration 测试

## Phase 7：歌单系统

- [ ] 首页歌单系统设计
- [ ] 默认歌单“已收藏”
- [ ] 歌单模型与存储
- [ ] 支持首页直接粘贴外部链接加入歌单
- [ ] 支持新增、删除、编辑自定义歌单
- [ ] 从聊天/详情加入歌单

## Phase 8：聊天室系统

- [ ] Room / Message 后端模型
- [ ] 双人聊天室与多人聊天室统一模型
- [ ] 明确不引入私信域
- [ ] 房间消息 API
- [ ] 持久化与同步策略

## Phase 9：用户系统

- [ ] 极简用户模型
- [ ] 登录 / 注册
- [ ] 按账号创建聊天室
- [ ] 明确不引入好友系统
- [ ] 明确不引入邀请 / 同意流程

## Phase 10：客户端完善

- [ ] iOS 接入正式 backend API
- [ ] 完善加载态、错误态、重试
- [ ] 完善歌曲详情与平台按钮体验
- [ ] 推进客户端脱离本地 mock

## Phase 11：部署与上线

- [ ] backend 部署到 VPS / 云服务器
- [ ] 配置域名
- [ ] 配置 HTTPS
- [ ] 运行环境与服务结构稳定化

## Phase 12：后续扩展

- [ ] 推荐系统
- [ ] 多端支持
- [ ] 数据分析与指标
