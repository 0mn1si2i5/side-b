# TASKS

## 已完成

- [x] iOS 聊天主路径可用
- [x] 支持文本消息
- [x] 支持粘贴链接发歌
- [x] 支持引用已有歌曲消息
- [x] 歌曲消息可进入详情页
- [x] 详情页已收口到基础信息 + 平台按钮
- [x] 建立 canonical track 模型骨架
- [x] 建立 resolver request / response contract
- [x] 建立 remote resolver client 落点
- [x] 打通 Spotify source resolving
- [x] 打通 Apple Music source resolving
- [x] 打通 Apple Music <-> Spotify 双向链接映射
- [x] Apple Music artwork 升级为高清 URL
- [x] 中文简繁归一化接入 OpenCC 体系

## 当前进行中

- [ ] 提交当前 Apple Music / Spotify 双平台阶段成果

## 下一步：网易云音乐（三平台双向连接）

- [ ] 核对网易云开放平台官方文档与接入约束
- [ ] 确认网易云 source link 形态与 song id 提取规则
- [ ] 接入网易云 song detail metadata 获取
- [ ] 将网易云 metadata 映射为 canonical track
- [ ] 打通 `网易云 -> Spotify` 链接映射
- [ ] 打通 `网易云 -> Apple Music` 链接映射
- [ ] 打通 `Spotify / Apple Music -> 网易云` 链接映射
- [ ] 完成三平台按钮显示规则联调

## 后续：QQ 音乐（四平台双向连接）

- [ ] 确认 QQ 音乐 source link 形态与 song id 提取规则
- [ ] 接入 QQ 音乐 metadata 获取
- [ ] 将 QQ 音乐 metadata 映射为 canonical track
- [ ] 打通 `QQ -> Spotify` 链接映射
- [ ] 打通 `QQ -> Apple Music` 链接映射
- [ ] 打通 `QQ -> 网易云` 链接映射
- [ ] 打通 `Spotify / Apple Music / 网易云 -> QQ` 链接映射
- [ ] 完成四平台按钮显示规则联调

## 暂不处理

- [ ] 站内播放
- [ ] 歌词主链路
- [ ] 社区 / 推荐 / 评论
- [ ] 截图识别
