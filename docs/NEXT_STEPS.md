# NEXT STEPS

## 当前阶段目标

把房间详情页从“分区输入”改成更像聊天室的结构，并支持两类消息：

- 纯文本消息
- 引用当前歌曲的消息

---

## 下一轮建议任务

建议按下面顺序逐步实现，不要一次做完：

1. 新建 `RoomDetailViewModel`，接管 `messages`、输入状态和发送动作
2. 在房间详情页接入底部统一输入栏
3. 先实现纯文本消息发送
4. 再实现“引用当前歌曲”发送

---

## Public Interfaces / Types

下一轮将引入但尚未实现的接口：

- `RoomDetailViewModel`
  - `messages`
  - `draftText`
  - `isQuotingCurrentTrack`
  - `sendMessage(...)`

保持不变：

- `Message` 继续复用 `text + track`
- 不新增独立 `Comment` 模型
- `MusicResolverService` 保持现状，暂不扩展

---

## 本轮不做

- 不做线程回复
- 不做歌曲卡片下评论
- 不把链接解析并入统一 composer
- 不做真实跳转
- 不做真实 API

---

## 下一轮验收标准

- 房间页看起来更像聊天室而不是表单页
- 可以发送纯文本消息
- 可以发送带“当前歌曲引用”的消息
- 两类消息都进入同一消息流
- 现有歌曲详情、平台按钮反馈、resolver 不回退
- 不出现线程评论或多级回复 UI
