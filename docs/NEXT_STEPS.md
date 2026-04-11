# NEXT STEPS

## 当前阶段目标

聊天室主路径的代码清理与文档收口已经完成，当前适合先形成一次阶段性提交，再进入下一阶段。

- 纯文本消息
- 引用任意歌曲的消息
- 统一 composer 内发歌链接

---

## 下一轮建议任务

建议按下面顺序逐步推进：

1. 先提交当前聊天室里程碑
2. 在下一阶段二选一：真实深链占位，或 API 预埋
3. 保持当前聊天主路径不回退，不同时推进两条线

---

## Public Interfaces / Types

当前已引入接口与结构：

- `RoomDetailViewModel`
  - `messages`
  - `draftText`
  - `linkInput`
  - `quotedTrack`
  - `isShowingLinkInput`
  - `isSending`
  - `sendTextMessage(...)`
  - `sendResolvedTrackMessage(...)`
  - `startQuoting(track:)`
  - `clearQuotedTrack()`

保持不变：

- `Message` 继续复用 `text + track`
- 不新增独立 `Comment` 模型
- `MusicResolverService` 保持现状，暂不扩展

当前代码组织状态：

- `MainTabViews.swift` 只保留 tab 级页面入口
- `RoomDetailView.swift` 承担房间详情页装配
- `RoomMessageComponents.swift` 承担消息展示组件

---

## 本轮不做

- 不做线程回复
- 不做歌曲卡片下评论
- 不做真实跳转
- 不做真实 API
- 不在本轮新增用户系统

---

## 下一轮验收标准

- `MainTabViews.swift` 中不再堆叠聊天室实现细节
- 聊天室 UI 已拆到 `Features/Rooms`
- 房间页现有行为不回退
- 文档与当前代码状态一致
- 已具备形成一次阶段性提交的边界
