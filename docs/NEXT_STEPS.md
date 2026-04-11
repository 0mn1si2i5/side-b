# NEXT STEPS

## 当前阶段目标

聊天室主路径和基础展示细节已基本完成，调试入口已移除，下一步更适合继续做轻量 polish 或转入保留项。

- 纯文本消息
- 引用任意歌曲的消息
- 统一 composer 内发歌链接

---

## 下一轮建议任务

建议按下面顺序逐步实现，不要一次做完：

1. 继续优化歌曲附件和引用动作的层级、边界对比与贴合度
2. 评估是否需要进一步补消息状态，例如失败态或重试入口
3. 或在确认当前聊天体验满意后，直接转入保留项：真实深链、真实 API、用户系统

---

## Public Interfaces / Types

当前已引入接口：

- `RoomDetailViewModel`
  - `messages`
  - `draftText`
  - `linkInput`
  - `quotedTrack`
  - `isShowingLinkInput`
  - `sendTextMessage(...)`
  - `sendResolvedTrackMessage(...)`
  - `startQuoting(track:)`
  - `clearQuotedTrack()`

保持不变：

- `Message` 继续复用 `text + track`
- 不新增独立 `Comment` 模型
- `MusicResolverService` 保持现状，暂不扩展

---

## 本轮不做

- 不做线程回复
- 不做歌曲卡片下评论
- 不做真实跳转
- 不做真实 API

---

## 下一轮验收标准

- 房间页看起来更像聊天室而不是表单页
- 房间页底部有统一输入栏
- 消息流按上旧下新顺序展示
- 可以发送纯文本消息
- 可以发送带“任意歌曲引用”的消息
- 可以从统一 composer 发送歌曲链接
- 自己发送消息后会自动滚动到底部
- 只有未停留在底部时，他人新消息才会出现提示气泡
- 连续同一发送者的消息会弱化重复的名字和时间
- 发送消息时会有轻量发送中过渡反馈
- 两类消息都进入同一消息流
- 现有歌曲详情、平台按钮反馈、resolver 不回退
- 不出现线程评论或多级回复 UI
