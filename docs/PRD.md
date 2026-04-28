# Side B PRD

## 产品定位

Side B 是一个以跨平台歌曲分享为核心的产品。

产品目标是把任意输入形式的歌曲内容转换成一个可被不同平台用户消费的统一歌曲对象，并围绕这个对象构建聊天室、极简用户与歌单能力。

当前正式产品方向：

- Spotify 作为 preferred canonical metadata source
- 多平台 resolver 作为核心能力
- iOS 客户端作为轻客户端
- backend 作为统一业务核心

## 核心目标

Side B 需要从原型升级为可部署上线的完整产品，具备：

- Spotify / Apple Music / 网易云 / QQ 的统一输入解析
- canonical track 构建与多平台映射
- 聊天室与消息流
- 极简用户系统
- 歌单系统
- 可部署 backend、域名与 HTTPS

## 核心用户

- 经常互相分享音乐的小群体用户
- 同时使用不同音乐平台的用户
- 需要把“平台专属链接”转化为“可消费歌曲对象”的用户

## 产品原则

- 先把 resolver 体系做对，再扩展业务系统
- 客户端只负责输入、展示、跳转
- 平台解析、metadata 获取、候选搜索、映射打分全部放到 backend
- 链接命中必须保守，不能返回错误目标

## 核心能力

### 1. Input Parsing

统一支持：

- Spotify 链接
- Apple Music 链接
- 网易云音乐链接
- QQ 音乐链接
- 含前后文的分享文案链接提取

通过 `InputParser` 统一入口，将可识别链接转换为统一解析结果。当前输入主链路是音乐平台链接与含链接的分享文案。

### 2. Canonical Track

所有可解析内容最终都应尽可能转换为 canonical track。

canonical track 至少包含：

- title
- artistName
- albumTitle
- durationMS
- artworkURL
- sourcePlatform
- sourcePlatformID
- sourceURL
- isrc
- platformLinks

### 3. Resolver

resolver 是 Side B 的产品核心能力。

正式包含：

- Spotify source adapter / target resolver
- Apple Music source adapter / target resolver
- Netease source adapter / target resolver
- QQ Music source adapter / target resolver

每个 resolver 负责：

- source link parsing
- metadata 获取
- 搜索候选
- 链接与置信度返回

### 4. Chat / Room

用户可以：

- 在房间中发送文本消息
- 粘贴链接发歌（直接发送歌曲卡片，不附加文本气泡）
- 长按消息弹出上下文菜单（引用回复 / emoji 回应）
- 查看歌曲详情与平台按钮
- 歌曲卡片右侧有蓝色加号按钮可加入歌单

产品方案：

- 用户可以先创建仅包含自己的聊天室，再邀请其他成员
- 一对一和多人聊天都是成员数量不同的 Room
- Room 是唯一消息承载单元

消息交互设计：

- 仿照 Instagram / Discord 的聊天体系
- 每条消息（文本或歌曲）可长按弹出上下文菜单
- 上下文菜单包含：引用回复、emoji 回应
- 歌曲卡片紧凑展示：右侧蓝色加号按钮（加入歌单），替代底部两个蓝色小按钮
- 发送歌曲时不附加 "Shared a song" 文本，直接发送歌曲卡片

### 5. User System

极简用户系统：

- 用户注册 / 登录（不需要复杂安全验证）
- 用户资料：昵称 + 头像（从预提供图像池选择，暂不支持上传）
- 用户可展示偏好音乐平台

聊天室权限：

- 用户可创建仅包含自己的聊天室
- 创建时可选填房间名与邀请成员用户名
- 任何成员可更改聊天室名称
- 任何成员可邀请新成员
- 任何成员可解散聊天室
- 成员管理直接由房间内邀请完成

### 6. Playlist

歌单系统支持：

- 首页歌单入口
- 默认歌单“已收藏”
- 歌单创建、编辑、删除
- 从首页直接粘贴外部链接并加入歌单
- 从聊天或详情页加入歌单
- 歌单内统一展示 canonical track

该能力用于覆盖以下核心场景：

- 用户只想解析并跳转，不想发给别人
- 用户想收藏别人发给自己的歌
- 用户想先收藏一首歌，之后再发给一个或多个聊天室

## 数据源策略

- Spotify 是 preferred canonical metadata source
- 所有输入都先识别来源平台
- 若可稳定转换为 Spotify，则优先使用 Spotify metadata 提升歌曲信息质量
- source platform / source URL 保留原始来源，确保源平台按钮和历史消息语义稳定
- 若无法稳定转换，则使用原平台 metadata 构建 canonical track

## 平台按钮策略

- source platform 永远显示
- 其他平台只有在真实命中可直达链接时才显示
- 不返回搜索页 fallback

## 当前范围与阶段

### 当前已完成

- iOS 聊天主路径
- 粘贴链接发歌与分享文案链接提取
- Spotify / Apple Music / 网易云 / QQ 四平台 source resolving
- 四平台 target link mapping
- 解析与平台匹配拆阶段：
  - 发卡片只依赖 metadata 成功
  - 其他平台链接在详情页异步补全
  - 详情页平台按钮按平台独立加载、独立失败、独立回写
- 极简用户系统、Room 系统、消息持久化与 WebSocket 广播
- 歌单系统与本地平台链接缓存

### 当前主线

1. 保持本地运行、实机测试和自动化测试稳定
2. 修复四平台 resolver 在真实网络与第三方服务下的边界问题
3. 准备个人服务器 Docker 部署、域名、HTTPS 与 SQLite volume 备份
4. 收敛错误提示、诊断信息和手工验收路径

## 当前产品范围

- 歌曲消费方式是跳转到用户自己的音乐平台
- 社交能力围绕 Room、成员、消息、引用回复和 emoji 回应
- iOS 客户端负责输入、展示与跳转
- backend 负责平台 secret、metadata 获取、候选搜索与映射打分

## 成功标准

产品进入可上线阶段时，应满足：

- 多输入源统一生成 canonical track
- 房间消息与歌曲详情可稳定消费 resolver 结果
- backend 独立部署可用
- 用户、聊天室、歌单具备最小闭环
- 一对一和多人沟通均通过 Room 完成
- 多平台链接映射对错误命中保持保守
