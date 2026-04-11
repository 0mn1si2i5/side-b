# NEXT STEPS

## 当前目标

下一阶段不是继续堆聊天功能，而是为真实歌曲信息获取做结构准备。

默认原则：

- 先拆分 resolver 职责
- 先做 Spotify provider 骨架
- 不改聊天 UI 主路径

---

## 下一个 agent 先做什么

### 1. 先拆 `LinkParsing` 和 `MetadataFetching`

这是当前最优先任务。

原因：

- 现在 `MusicResolverService` 同时承担链接识别、资源 id 提取、mock track 组装、`platformLinks` 生成
- 如果不先拆层，后面接 Spotify 真实 metadata 时会继续把 resolver 做厚

本轮目标应是：

- 把“从链接得到平台与资源 id”定义成独立步骤
- 把“根据平台与资源 id 获取 metadata”定义成独立步骤
- 保持上层调用仍然能拿到 `ResolvedTrackPayload`

限制：

- 不改 `RoomDetailViewModel` 主调用路径
- 不改聊天页面交互

---

### 2. 建立 Spotify metadata provider 骨架

在分层之后，下一最小任务就是给 Spotify 建一个真实接入前可落位的 provider 骨架。

本轮只需要做到：

- 有清晰的 Spotify provider 类型或协议实现位置
- 输入是 Spotify 资源 id
- 输出对齐统一 `Track` / `ResolvedTrackPayload`
- 暂时允许内部继续返回 mock 数据或 placeholder 数据

先不要做：

- 多平台一起接
- UI 改版
- 复杂错误态铺开

---

### 3. 保持聊天主路径冻结

下一阶段所有结构调整，都不应该影响以下行为：

- Rooms 列表进入 Room 详情
- 文本消息发送
- 粘贴链接发歌
- 引用歌曲消息
- 歌曲详情页查看
- 详情页平台按钮展示与跳转占位

如果新改动会触碰以上 UI 行为，优先回到更小的结构性任务。

---

## 建议的最小起手任务

下一轮 coding mode 建议直接从下面这个最小任务开始：

`把当前 resolver 中“链接解析结果”抽成独立类型，并让 Spotify 走这条解析结果到 metadata provider 的新骨架，但暂时仍返回 mock track。`

这样做的原因：

- 改动范围最小
- 不需要碰聊天 UI
- 能直接为真实 Spotify 接入铺路
- 能验证新的分层是否成立
