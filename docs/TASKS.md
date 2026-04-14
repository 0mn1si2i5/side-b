# TASKS

## Phase 0：现状分析与重构规划

- [x] 完成 Master Plan 文档
- [x] 统一 PRD / ARCHITECTURE / TASKS 文档口径
- [x] 盘点当前 iOS 与 backend 结构的保留/修改/删除项
- [x] 明确 backend 模块化单体目录结构

## Phase 1：基础架构重构

- [x] 新增正式 `InputParser` 统一入口
- [x] 定义 `ParsedSource / CanonicalTrack / ResolverContext`
- [x] 收口 backend 为 `routes / services / resolvers / models / platform_clients / utils`
- [x] 将入口脚本瘦身为 app entry / route bootstrap
- [x] 固化失败与降级语义
- [x] 建立 metadata-only 与平台链接异步补全两阶段主链路
- [x] 建立详情页按平台独立加载的按钮状态模型

## Phase 2：Spotify 主链路

- [x] 固化 Spotify preferred canonical 策略
- [x] 完善 Spotify metadata 获取与 canonical 构建
- [x] 完善 Spotify search / matching / cache / market fallback
- [x] 回归验证 Spotify source path

## Phase 3：Apple Resolver

- [x] 固化 Apple source adapter
- [x] 固化 Apple target resolver
- [x] 稳定 `iTunes lookup + Search matcher`
- [x] 验证 Apple source -> Spotify link

## Phase 4：网易云 Resolver

- [x] 接入 `api-enhanced` 自部署服务
- [x] 实现 Netease source adapter
- [x] 实现 Netease target resolver
- [x] 打通 Spotify / Apple / 网易云三平台链路
- [x] 支持网易云短链解析

## Phase 5：QQ Resolver

- [x] 接入 `QQMusicApi` Python 库
- [x] 实现 QQ source adapter
- [x] 实现 QQ target resolver
- [x] 修复 QQ 分享短链解析
- [x] 打通四平台链路

## Phase 6：统一 Resolver Service

- [x] 新建正式 `ResolverService` 编排层
- [x] 实现平台按钮统一编排与独立加载
- [x] 实现 diagnostics / confidence 内部结构
- [x] 补 source parser / target resolver / orchestration 测试
- [x] 做平台链接结果缓存/持久化

## Phase 7：歌单系统

- [x] 首页歌单系统设计
- [x] 默认歌单"已收藏"
- [x] 歌单模型与存储
- [x] 支持首页直接粘贴外部链接加入歌单
- [x] 支持新增、删除、编辑自定义歌单
- [x] 支持从聊天/详情加入歌单
- [x] 最近解析区域（渐进式解析、异步补全平台链接）
- [x] 歌单详情页下拉刷新
- [x] 歌单重命名功能
- [x] 歌单删除功能（工具栏菜单 + 确认弹窗）
- [x] 全 App 中文化
- [x] 加入歌单 Toast 反馈
- [x] 聊天室歌曲卡片只显示歌曲卡片（不附加文本气泡）

## Phase 8：聊天室系统

### 8.1 消息交互升级

- [ ] 长按消息弹出上下文菜单（引用回复 / emoji 回复）
- [ ] 歌曲卡片右侧蓝色加号按钮（加入歌单），替代底部两个蓝色按钮
- [ ] 引用回复功能：长按文本消息可引用回复
- [ ] emoji 回复：每条消息下方可显示 emoji 回应

### 8.2 后端化

- [ ] Room / Message 后端模型
- [ ] 双人聊天室与多人聊天室统一模型
- [x] 明确不引入私信域
- [ ] 房间消息 API
- [ ] 持久化与同步策略

## Phase 9：用户系统

### 9.1 极简用户模型

- [ ] 用户注册 / 登录（极简，不需要复杂验证）
- [ ] 用户资料：昵称 + 头像（从预提供图像池选择，暂不支持上传）
- [ ] 用户偏好音乐平台展示

### 9.2 聊天室权限

- [ ] 通过输入对方账号创建聊天室
- [ ] 第一个建立聊天室的用户负责起名
- [ ] 任何用户可更改聊天室名称
- [ ] 任何用户可邀请新成员
- [ ] 任何用户可解散聊天室
- [x] 明确不引入好友系统
- [x] 明确不引入邀请 / 同意流程

## Phase 10：客户端完善

- [ ] iOS 接入正式 backend API
- [ ] 完善加载态、错误态、重试
- [x] 完善歌曲详情与平台按钮体验
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