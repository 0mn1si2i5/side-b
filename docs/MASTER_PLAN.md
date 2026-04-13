# Side B Master Plan

## Summary

Side B 将从当前的 iOS 原型升级为一个可部署上线的模块化单体产品。

正式方向：

- Spotify 作为 preferred canonical metadata source
- 多平台 resolver 作为核心能力
- InputParser 统一处理链接与纯文本
- backend 作为产品核心
- iOS 保持轻客户端

长期产品目标覆盖：

- Spotify / Apple Music / 网易云 / QQ 的解析与映射
- 聊天室系统
- 歌单系统
- 极简用户系统
- backend 部署、域名与 HTTPS

## Phase 0：现状分析与重构规划

### 当前架构问题

- 文档仍停留在 MVP / 双平台阶段，无法指导完整产品开发。
- backend 已开始模块化，但入口脚本仍承担过多 orchestration 逻辑。
- 当前产品目标未正式覆盖用户、聊天室、歌单与部署。
- 现有仓库说明仍混有“小步 mock 阶段”口径，与当前真实链路不一致。

### 当前与目标架构差距

- 缺少统一 InputParser。
- 缺少正式的 backend 目录结构规范。
- 缺少覆盖四平台的统一 resolver contract。
- 缺少用户、聊天、歌单的长期系统规划。
- 缺少“仅聊天室、不做私信”“首页歌单”“极简用户系统”的明确产品约束。
- 缺少从原型到可部署产品的阶段路线图。

### 保留 / 修改 / 删除

保留：

- iOS Rooms / Chat UI 主路径
- 统一 Track 模型方向
- 当前 resolver response contract
- 已拆出的 Spotify / Apple Music 平台模块

修改：

- backend 结构正式收口为模块化单体
- server 入口只保留 route/bootstrap 职责
- docs 全面改为长期产品路线

删除或降级：

- 仅以 MVP / 双平台为主叙事的文档结构
- 要求客户端承担平台解析逻辑的设计
- 旧的 mock-first 阶段性限制作为正式产品原则

### 重构优先级

1. 文档统一
2. backend 结构正式化
3. InputParser + resolver orchestration
4. Spotify canonical 主链路稳定化
5. 网易云与 QQ 接入
6. 聊天、用户、歌单后端化

## Phase 1：基础架构重构

### InputParser

统一支持：

- Spotify / Apple Music / 网易云 / QQ 链接
- 纯文本

输出：

- ParsedInput
- link / text 类型
- 可选 source platform 提示

### 统一内部模型

- ParsedInput
- ParsedSource
- CanonicalTrack
- ResolverCandidate
- PlatformLinkResult
- ResolverContext

### Backend 结构

目标目录：

- `backend/routes`
- `backend/services`
- `backend/resolvers`
- `backend/models`
- `backend/platform_clients`
- `backend/utils`

### API 设计

- `POST /resolve-input`
- `POST /resolve-link`
- `POST /resolve-text`
- `GET /health`
- 后续聊天室与歌单 API 都建立在同一 backend 上，不单独设计私信域

### 失败语义

- 输入解析失败：不生成 canonical track
- metadata 失败：不生成歌曲
- 其他平台链接未命中：仍返回 canonical track，只是少按钮

## Phase 2：Spotify 主链路

- Spotify 作为 preferred canonical metadata source
- Spotify 输入直接获取 Spotify metadata
- 非 Spotify 输入优先尝试转换为 Spotify
- 成功时 canonical source 统一落到 Spotify
- 失败时 fallback 原平台 canonical metadata
- 建立 Spotify canonical track 标准字段
- 稳定 Spotify search / fetch / matching / cache / market fallback

## Phase 3：Apple Resolver

- Apple source adapter
  - Apple Music / iTunes 链接解析
  - track id 提取
  - iTunes lookup metadata
- Apple target resolver
  - iTunes Search API
  - title / artist / album / duration / 版本词 / 简繁归一化评分
  - 仅返回真实 track URL
- Apple 输入优先尝试转换 Spotify canonical
- 失败时保留 Apple fallback canonical
- 保留高清 artwork URL 升级逻辑

## Phase 4：网易云 Resolver

- 接入 `api-enhanced` 自部署服务
- Netease source adapter
  - 标准链接与短链解析
  - song id 提取
  - song detail metadata
- Netease target resolver
  - 基于 canonical track 搜索候选
  - 返回真实链接与置信度
- 无法稳定转换 Spotify 时，保留网易云作为 fallback canonical

## Phase 5：QQ Resolver

- 接入 `QQMusicApi` 自部署服务
- QQ source adapter
  - 链接解析
  - song id 提取
  - metadata 获取
- QQ target resolver
  - 基于 canonical metadata 搜索候选
  - 返回真实 QQ 链接
- 与 Netease 共享同一 resolver contract 与 fallback 语义

## Phase 6：统一 Resolver Service

- 建立统一 orchestration service
- 执行链路：
  - InputParser
  - source adapter
  - canonical resolution
  - target platform resolvers
  - response assembler
- 建立 canonical source 优先级：
  - Spotify 优先
  - 原平台 fallback
- 建立统一按钮规则：
  - 源平台永远显示
  - 其他平台仅真实命中时显示
- 返回结构统一包含：
  - canonical track
  - source platform / resource id
  - platform links
  - parsing result
  - metadata status
  - diagnostics / confidence
- 在客户端交互层采用两阶段消费策略：
  - 阶段 1：metadata-only，成功即创建歌曲卡片
  - 阶段 2：详情页按目标平台独立补全链接
  - 每个平台独立维护 `idle / loading / ready / unavailable / failed`
  - 单个平台超时不再拖累整个详情页按钮区

## Phase 7：歌单系统

- 首页承载歌单系统
- 默认歌单为“已收藏”
- 支持新增、删除、编辑自定义歌单
- 支持把外部链接直接粘贴到首页并加入歌单
- 支持把聊天里的歌曲收藏到歌单
- 支持“先解析收藏、后续再分享给一个或多个聊天室”的使用路径

## Phase 8：聊天室系统

- 只做聊天室系统，不做私信系统
- 两个用户的一对一消息通过创建双人聊天室实现
- Room / Message 统一模型覆盖双人房与多人房
- 不区分 DM 与 Room 两套后端结构

## Phase 9：用户系统

- 极简用户模型 / 登录
- 通过填写其他用户账号创建聊天室
- 不做好友系统
- 不做邀请 / 同意流程
- 不做复杂社交关系链

## Phase 10：客户端完善

- iOS UI / 交互

## Phase 11：部署与上线

- backend 部署
- 域名与 HTTPS
- 服务结构

## Phase 12：后续扩展

- 推荐系统
- 多端支持
- 数据分析

## Assumptions

- backend 正式形态采用模块化单体
- Spotify 是 preferred canonical source，但允许 fallback 原平台
- 网易云走 `api-enhanced` 自部署
- QQ 走 `QQMusicApi` 自部署
- iOS 继续保持轻客户端
- 产品层明确不做私信域，双人沟通统一使用聊天室
- 首页歌单系统是正式主线，不是后续附属功能
- 用户系统保持极简，不引入好友/邀请/同意机制
