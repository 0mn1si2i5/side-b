# 开发任务

## 文档定位

本文件现在用于定义项目正式开发路线，而不再强调“每次只能极小步推进”的旧策略。

新的执行原则是：

- 允许较大步幅推进
- 允许重组 phase
- 允许为了主线效率做更大范围的设计调整
- 但仍需保持结构清晰、主链路优先、工程可维护

---

## 当前已完成能力

当前仓库已完成的基础能力：

- Rooms 列表与房间详情可用
- Room 详情已是轻量聊天室
- 支持纯文本消息
- 支持统一 composer 内粘贴链接发歌
- 支持引用已有歌曲消息
- 歌曲消息可进入歌曲详情页
- `Track / PlatformLink / Room / Message` 已形成当前模型骨架
- `MusicPlatform` 已进入共享模型层
- `Track.platformLinks` 已接到详情页按钮
- 详情页当前聚焦封面、歌名、艺人、专辑、来源平台和四个平台按钮
- 当前 resolver 已具备：
  - 4 平台链接识别
  - 最小资源 id 提取
  - `ResolvedTrackPayload`
  - `LinkParsing` / `MetadataFetching` 初步分层
  - Spotify metadata provider 骨架

---

## 当前正式主线

从现在开始，项目正式主线之一是：

`Spotify 单曲链接 -> Spotify metadata -> canonical track -> 多平台链接映射 -> iOS 展示`

这条主线优先级高于：

- 歌词
- 更复杂聊天能力
- 社区化功能
- 大范围 UI 打磨

---

## 当前不做

以下内容当前继续不做，避免主线跑偏：

- 站内播放
- 歌词主线能力
- 推荐 / 社区 / 评论
- 截图识别
- 复杂账号体系
- 云端同步复杂化
- 为了前端方便把完整平台逻辑塞进 iOS 客户端

说明：

- “不做歌词”是当前阶段策略，不影响未来扩展
- “不做复杂社区”与当前 Spotify 主链路无关，不应抢占优先级

---

## Phase 1：Canonical Track 与 Resolver 基础收口

目标：

- 把 canonical track 作为正式数据中心
- 完成 iOS 展示层与统一结果对象的对齐
- 保持聊天主路径稳定

工作项：

- 收口 `Track` 字段
- 明确 `sourcePlatform / sourcePlatformID / sourceURL / platformLinks`
- 继续减少 UI 对过渡展示字段的依赖
- 保持详情页只消费 canonical track

验收标准：

- iOS 详情页不再依赖平台散落字符串逻辑
- `platformLinks` 成为多平台按钮唯一来源

---

## Phase 2：Spotify Resolver 主链路

目标：

- 把 Spotify 单曲解析正式纳入项目主链路
- 完成从链接到 Spotify metadata 的完整服务设计

工作项：

- Spotify URL 识别
- Spotify track ID 提取
- Spotify metadata provider 设计
- Spotify access token 获取边界
- Spotify catalog request / response 映射
- 真实 Spotify track metadata 字段映射到 canonical track：
  - 封面
  - 歌名
  - 歌手
  - 专辑
  - 时长
  - Spotify 原始链接
  - ISRC

验收标准：

- 项目计划层明确 Spotify 是第一条真实 metadata 来源
- 服务层结构能够自然替换为真实 Spotify API client
- 上层 iOS 不需要知道 Spotify 原始响应格式

---

## Phase 3：Resolver Service / Backend 正式化

目标：

- 明确 iOS 与服务端边界
- 把 resolver 从“本地 mock service”提升为正式服务设计

工作项：

- 定义 resolver service 请求结构
- 定义 resolver service 响应结构
- 明确服务端职责：
  - 链接解析
  - token 获取
  - metadata 拉取
  - 多平台映射
  - 结果组装
- 明确缓存位点：
  - link -> parsed result
  - platformID -> metadata
  - canonical track -> mapped links

验收标准：

- 后续可以在 `backend/` 下真正落 resolver 服务
- iOS 客户端可以从 mock service 平滑切到真实 service

---

## Phase 4：跨平台链接映射

目标：

- 在 canonical track 基础上返回其他平台链接
- 让平台按钮真正基于映射结果服务用户

优先目标平台：

1. Apple Music
2. QQ 音乐
3. 网易云音乐（如可行）

工作项：

- 设计 mapping service / mapper 层
- 优先用 `ISRC` 做匹配
- 无 `ISRC` 时退回标题 + 艺人 + 专辑策略
- 统一输出 `platformLinks`

验收标准：

- 客户端不再自己拼平台链接
- resolver 输出中可直接带多平台可消费链接

---

## Phase 5：iOS 接入真实 Resolver

目标：

- 客户端开始消费真实 resolver 结果
- 保持现有聊天和详情页体验不回退

工作项：

- 新增 resolver API client
- 将当前 mock resolver 调用替换为真实 service 调用
- 增加最小 loading / failure / fallback 状态
- 校验详情页和平台按钮在真实返回下是否稳定

验收标准：

- 粘贴 Spotify 链接后，客户端可拿到真实 canonical track 结果
- 详情页可稳定显示基础信息和多平台按钮

---

## Phase 6：Apple Music / QQ / 网易云逐步落地

目标：

- 在 Spotify 主链路稳定后，把映射目标平台逐步做实

工作项：

- Apple Music 映射优先落地
- QQ 音乐映射第二优先
- 网易云映射第三优先
- 评估不同平台映射的可靠性、区域差异和 fallback 策略

验收标准：

- 至少 1-2 个目标平台的映射稳定可用
- 平台映射失败不应影响 Spotify 原始链路展示

---

## 开发策略调整

旧策略中的“严格小步、一次只做极小任务”不再作为强约束。

当前策略调整为：

- 允许围绕一条主线做更大步幅的规划与实现
- 允许为主线效率重写 phase 和任务结构
- 允许在必要时主动重构旧设计
- 允许为了打通 Spotify 主链路先做更完整的服务边界设计

但仍需坚持：

- 核心目标优先
- 结构清晰
- 关键模型稳定
- 不做与主线无关的大规模分叉

---

## 近期最高优先级任务

当前最应该优先推进的，不是继续做更多 UI，而是以下主链路：

1. 正式定义 Spotify resolver service 请求 / 响应
2. 正式定义 Spotify access token 获取与 catalog fetching 边界
3. 明确 canonical track 扩展字段
4. 明确跨平台 mapping service 设计
5. 准备 iOS 侧真实 resolver client 接入点

---

## 如果下一轮进入 coding mode，建议优先打的链路

建议优先直接打通这一条：

`Spotify track URL -> resource id -> resolver service response shape -> canonical track -> detail UI consume`

理由：

- 这是当前最有产品价值的一条主链路
- 也是最适合尽快替换 mock 的链路
- 它打通后，Apple Music / QQ / 网易云映射才有稳定输入
