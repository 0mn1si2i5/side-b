# 开发任务

## 文档目的

本文件不再记录细碎执行过程，只保留当前可复用的项目现状与后续开发路线。

后续 coding agent 应优先把它当作：

- 当前能力边界说明
- 下一阶段 phase 拆分
- 真实接入前的分层约束

---

## 当前已完成能力

当前仓库已完成 MVP 前期主链路，后续开发应默认这些能力已存在且不应回退：

- Rooms 列表可浏览并进入房间详情
- Room 详情已是轻量聊天室结构
- 支持发送纯文本消息
- 支持在统一 composer 内粘贴链接发歌
- 支持引用已有歌曲消息继续发言
- 歌曲消息可进入歌曲详情页
- `Track` / `PlatformLink` / `Room` / `Message` 已形成当前统一模型
- `MusicPlatform` 已作为共享平台类型进入模型层
- `Track.platformLinks` 已接入歌曲详情页按钮渲染
- `PlatformNavigationService` 已提供真机可测试的跳转占位 URL
- `MusicResolverService` 已返回 `ResolvedTrackPayload`
- 当前 resolver 已能识别 4 个平台的最小链接并提取资源 id：
  - Spotify
  - Apple Music
  - 网易云音乐
  - QQ 音乐
- 当前 resolver 已具备最小 provider 抽象，但仍是 mock 驱动

---

## 当前架构判断

基于现有代码，项目已经从“纯 mock 页面阶段”进入“真实 metadata 接入前的分层准备阶段”。

当前最重要的判断：

- 聊天 UI 主路径已经可用，下一阶段不要重做 Rooms / Chat 交互
- 平台统一类型已经落地，但平台相关字段仍有继续收口空间
- resolver 现在同时承担了链接识别、资源 id 提取、mock metadata 组装、platformLinks 生成，职责仍偏厚
- 真实 API 接入前，必须先拆清 `LinkParsing` 和 `MetadataFetching`

---

## 当前不做

以下内容在当前阶段明确不做，避免后续 agent 跑偏：

- 站内播放
- 登录、鉴权、账号体系
- 云端同步
- 社区、评论、推荐
- 截图识别
- 多平台同时真实接入
- 大规模 UI 重构
- 改聊天主路径交互
- 为了接 API 提前引入复杂第三方架构

---

## Phase 1：Resolver 分层收口

目标：把当前 mock resolver 拆成后续可替换真实 provider 的稳定结构，但先不接真实 API。

本 phase 应解决：

- 将“链接识别 / 平台判断 / 资源 id 提取”从“歌曲 metadata 获取”中拆开
- 明确 resolver 编排层只负责流程调度，不直接持有平台 mock 细节
- 为后续真实 provider 保留稳定输入输出

建议交付：

- 新增或明确 `LinkParsing` 层职责
- 新增或明确 `MetadataFetching` / provider 层职责
- 让 `ResolvedTrackPayload` 成为 resolver 对上层的稳定结果
- 保持 `RoomDetailViewModel` 调用方式尽量不变

验收标准：

- 代码里能区分“解析链接”和“拉取 metadata”两步
- mock 数据仍可驱动完整发歌链路
- 不改聊天 UI 行为

---

## Phase 2：Spotify 真实 metadata 接入

目标：优先打通 Spotify 的真实歌曲信息获取，作为第一条真实 provider 链路。

为什么先做 Spotify：

- 当前链接识别已存在最小基础
- 资源 id 提取已具备
- 最适合作为 metadata provider 骨架的第一平台

本 phase 应优先完成：

- 定义 Spotify metadata provider 协议或服务骨架
- 明确 provider 输入：
  - 平台类型
  - 资源 id
- 明确 provider 输出：
  - 标准化后的 `Track`
  - 可选的原始平台上下文
- 保留 mock fallback，保证工程可继续运行

本 phase 暂不要求：

- 完整鉴权闭环
- 多平台一起接入
- UI 上增加复杂错误态

验收标准：

- Spotify provider 可以作为独立层被 resolver 调用
- 即使真实调用未完全接通，代码结构也已经从 mock provider 中抽离
- 上层 UI 不需要知道 Spotify 的平台细节

---

## Phase 3：平台模型继续统一

目标：减少平台相关过渡字段，让共享模型成为唯一可信来源。

本 phase 重点：

- 继续收口 `MusicPlatform`
- 逐步减少过渡型展示字段的扩散，例如 `sourcePlatformName`
- 明确 `PlatformLink` 在“来源平台”和“目标跳转平台”中的角色
- 统一平台展示顺序、按钮数据来源和来源标记逻辑

验收标准：

- UI 展示尽量从 `MusicPlatform` / `PlatformLink` 推导，而不是依赖散落字符串
- resolver / mock data / details UI 使用同一套平台定义

---

## Phase 4：Apple Music 第二阶段接入

目标：在 Spotify 路径稳定后，复制同样的 provider 结构接入 Apple Music。

本 phase 应遵守：

- 复用 Spotify 阶段已经稳定的分层
- 不为 Apple Music 单独发明另一套 resolver 流程
- 继续保证 mock fallback 可用

验收标准：

- Apple Music provider 接入方式与 Spotify 保持一致
- resolver 不因平台增多而继续膨胀

---

## Phase 5：网易云 / QQ 第三阶段接入

目标：在前两个平台路径稳定后，再扩展中文平台。

本 phase 关注点：

- 保持 provider 接口不变
- 优先复用统一链接解析结果
- 不在这一阶段反向改坏前面已稳定的 Spotify / Apple Music 结构

说明：

- 网易云与 QQ 不要求在当前阶段提前设计过深
- 先保证架构可接，再逐个平台落地

---

## Phase 6：`platformLinks` 继续接入 UI

目标：让 `platformLinks` 不只停留在歌曲详情页，而是逐步成为统一跳转数据源。

本 phase 重点：

- 继续确认所有平台按钮都从 `Track.platformLinks` 读取
- 评估 Rooms 列表、聊天消息卡片是否需要轻量暴露平台状态
- 保持 UI 只消费结果，不拼平台目标 URL

验收标准：

- 平台跳转相关 UI 不再各自拼装目标链接
- 平台按钮来源稳定、顺序稳定、来源平台标记稳定

---

## 每轮开发约束

后续 agent 继续开发时，默认遵守以下约束：

- 每次只做一个最小任务
- 每次最多修改 1-3 个文件
- 始终保持项目可编译
- 不修改 `project.pbxproj`
- 不把业务逻辑塞回 SwiftUI View
- 优先补结构，再做真实接入
- 任何新抽象都必须服务于后续真实 provider 落地
