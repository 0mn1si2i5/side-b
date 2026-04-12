# Side B 架构说明

## 目标架构判断

Side B 当前不应再被理解成“只有前端 mock 页面”的项目。

新的正式目标是：

- iOS 客户端负责输入、展示、交互、跳转
- 服务层 / 后端负责链接解析、Spotify metadata 获取、跨平台映射
- 客户端最终只消费统一结构化歌曲对象

也就是说，Side B 的核心技术路线不再是“前端手动填假数据”，而是：

`客户端输入链接 -> resolver service 解析并聚合 -> 返回 canonical track -> 客户端展示与跳转`

---

## 技术组成

### iOS Client

- SwiftUI
- MVVM
- 负责：
  - Rooms / Chat UI
  - Link input
  - 歌曲详情展示
  - 多平台按钮渲染
  - 调用 resolver service

### Resolver Service / Backend

后续正式主链路的核心应放在服务端或独立服务层，而不是放在 iOS 客户端内。

负责：

- 链接解析
- 平台识别
- Spotify token 获取
- Spotify track metadata 拉取
- canonical track 组装
- 其他平台链接映射
- 缓存与失败兜底

### 外部平台能力

当前正式优先级：

1. Spotify 官方链路
2. Apple Music 映射
3. QQ 音乐映射
4. 网易云音乐映射

歌词能力后置，不属于当前主线。

---

## 目录结构理解

### `Side B/`

iOS 工程代码，当前包含：

- `App/`
- `Core/Models`
- `Core/Services`
- `Features/Rooms`
- `Features/Shell`
- `Resources/`

### `docs/`

产品、架构、任务计划文档。

### `backend/`

后端服务目录，当前可视为未来 resolver service 的预留位置。

### `/Users/ostrovsky/Desktop/Zen/ios-sdk`

本地已有 Spotify iOS SDK 仓库。

当前判断：

- 它更适合未来用于 App Remote / 登录授权 / 客户端平台能力扩展
- 当前 Spotify metadata 主链路不应依赖 iOS SDK 直接完成
- 当前主线仍应优先使用服务端 / resolver 调用 Spotify 官方 Web API

---

## Canonical Track 思路

项目未来应围绕统一歌曲对象设计，而不是围绕某个平台的原始数据结构。

### 建议核心字段

- `title`
- `artistName`
- `albumTitle`
- `artworkURL`
- `duration`
- `sourcePlatform`
- `sourcePlatformID`
- `sourceURL`
- `isrc`
- `platformLinks`

### 设计原则

- `Track` 是客户端消费对象，不应直接等同于 Spotify / Apple Music 原始响应
- 各平台 provider 负责把平台原始响应映射成 canonical track
- `platformLinks` 应该是统一跳转集合，而不是各页面自己拼 URL

---

## Spotify 主链路架构

### 1. 链接解析

输入：

- 任意原始字符串链接

处理：

- 判断是否为 Spotify track 链接
- 提取 Spotify track ID

输出：

- `platform = spotify`
- `resourceID = spotifyTrackID`
- `sourceURL`

### 2. Spotify Metadata Fetching

输入：

- Spotify track ID

处理：

- 获取 access token
- 调用 Spotify 官方 track endpoint
- 解析封面、歌名、艺人、专辑、时长、原始链接、ISRC 等字段

输出：

- Spotify 原始响应
- 映射后的 canonical track

### 3. 平台映射

输入：

- canonical track
- 优先使用 `ISRC`
- 如无 ISRC，再退回标题 + 艺人 + 专辑等策略

输出：

- Apple Music 链接
- QQ 音乐链接
- 网易云音乐链接（如可行）

### 4. Resolver 聚合

服务端最终返回统一结构，例如：

- `track`
- `sourcePlatform`
- `sourceResourceID`
- `sourceURL`
- `platformLinks`

---

## Resolver Service 职责边界

resolver service 不应只是一个“本地 if-else mock service”。

正式职责应包括：

- `LinkParser`
  - 识别平台
  - 提取资源 id
- `MetadataProvider`
  - 调用平台 API
  - 获取 metadata
- `CatalogMapper`
  - 生成其他平台链接
- `ResponseAssembler`
  - 返回统一结果对象

这几层可以在实现上合并或拆分，但职责边界需要在架构上明确。

---

## iOS Client 与 Service 的边界

### iOS Client 负责

- 采集用户输入
- 调用 resolver 接口
- 渲染 canonical track
- 展示平台按钮
- 打开目标平台链接

### Service / Backend 负责

- 平台解析规则
- token 与鉴权
- 平台 API 请求
- 跨平台映射
- 统一结果拼装

### 不推荐的做法

- 在 iOS 客户端里持有 Spotify secret
- 在 ViewModel 内直接写完整平台解析和映射逻辑
- 在多个页面各自拼装平台目标链接

---

## Mock 与真实 API 的边界

### 当前可先 mock 的部分

- resolver response
- platform mapping 结果
- token provider
- Spotify track 原始响应
- 后端接口返回

### 必须朝真实目标设计的部分

- Spotify track URL 识别
- Spotify track ID 提取
- canonical track 字段设计
- resolver service 请求 / 响应结构
- metadata provider 抽象
- platform links 统一承载结构

说明：

- mock 只是阶段策略，不是目标架构
- 当前所有 mock 都应服务于后续真实 Spotify 链路落地

---

## 当前推荐实现路线

### Phase A：iOS + Mock Resolver

目标：

- 保持聊天主路径稳定
- 完成 canonical track 展示
- 保持 `platformLinks` 贯通 UI

### Phase B：Spotify Resolver Service

目标：

- 先完成 Spotify 官方链路
- 让 resolver 真正输出结构化结果

### Phase C：Cross-Platform Mapping

目标：

- 基于 canonical track 做 Apple Music / QQ / 网易云映射

### Phase D：客户端切换到真实 service

目标：

- iOS 从 mock service 切换到真实 resolver API
- UI 层尽量不改模型形状

---

## 当前架构原则

1. 主线优先：先打通 Spotify 单曲解析与 metadata
2. 服务端优先：解析和映射逻辑放在 resolver service
3. 统一模型优先：客户端围绕 canonical track 消费
4. 平台映射优先于歌词
5. 允许较大步幅推进，但要保持边界清晰
6. 必要时允许重组阶段、重写旧计划、替换过度保守的设计
