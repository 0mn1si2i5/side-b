# NEXT STEPS

## 当前阶段目标

聊天室主路径的代码清理与文档收口已经完成，平台按钮也已接入真实深链占位打开逻辑。当前开始进入 API 预埋阶段。

- 纯文本消息
- 引用任意歌曲的消息
- 统一 composer 内发歌链接

---

## 下一轮建议任务

建议按下面顺序逐步推进：

1. 继续把平台信息从字符串迁到统一模型边界，例如进一步减少兼容层
2. 评估是否需要让 `PlatformLink` 和 `Track` 共享更多平台映射信息
3. 保持当前聊天主路径和跳转占位不回退

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
- `PlatformNavigationService` 提供平台搜索页占位打开能力
- `MusicPlatformProvider` 作为后续真实平台接入的最小 provider 抽象
- mock 数据已开始按平台集中映射，不再散落在 resolver 内
- `MusicPlatform` 作为共享平台定义，已进入模型层

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
- mock resolver 已不再依赖一组散落的字符串判断
- 平台 mock 数据与 provider 映射关系已集中到 `MockData`
- 平台按钮、resolver、mock 数据已开始共享同一套平台定义
- 平台按钮已不再只是提示，而会尝试打开对应平台搜索页
