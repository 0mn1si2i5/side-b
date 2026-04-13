# Side B PRD

## 产品定位

Side B 是一个以跨平台歌曲分享为核心的产品。

目标不是播放器，而是把任意输入形式的歌曲内容转换成一个可被不同平台用户消费的统一歌曲对象，并围绕这个对象构建聊天室、极简用户与歌单能力。

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
- 纯文本输入

通过 `InputParser` 统一入口，将所有输入转换为统一解析结果。

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

- SpotifyResolver
- AppleResolver
- NeteaseResolver
- QQResolver

每个 resolver 负责：

- source link parsing
- metadata 获取
- 搜索候选
- 链接与置信度返回

### 4. Chat / Room

用户可以：

- 在房间中发送文本消息
- 粘贴链接发歌
- 引用已有歌曲消息
- 查看歌曲详情与平台按钮

产品约束：

- 不做独立私信系统
- 两个用户之间的一对一消息，也通过创建双人聊天室实现
- Room 是唯一消息承载单元

### 5. User System

后续产品必须支持：

- 用户模型
- 登录/注册
- 用户资料

并明确保持极简：

- 通过填写其他用户账号创建聊天室
- 不做好友系统
- 不做邀请 / 同意流程
- 不做复杂社交关系链

### 6. Playlist

后续产品必须支持：

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
- 若可稳定转换为 Spotify，则 canonical source 统一落到 Spotify
- 若无法稳定转换，则 fallback 原平台 metadata 作为 canonical source

## 平台按钮策略

- source platform 永远显示
- 其他平台只有在真实命中可直达链接时才显示
- 不返回搜索页 fallback

## 当前范围与阶段

### 当前已完成

- iOS 聊天主路径
- 粘贴链接发歌
- Spotify source resolving
- Apple Music source resolving
- Spotify / Apple Music 双向映射基础链路

### 当前主线

1. InputParser 与统一 resolver service
2. Spotify canonical 主链路稳定化
3. 网易云接入
4. QQ 接入
5. backend 化聊天室、极简用户、歌单

## 非目标

当前不做：

- 站内播放
- 推荐系统首发版本
- 重社区互动
- 复杂歌词系统作为主线
- 在 iOS 客户端中持有平台 secret

## 成功标准

产品进入可上线阶段时，应满足：

- 多输入源统一生成 canonical track
- 房间消息与歌曲详情可稳定消费 resolver 结果
- backend 独立部署可用
- 用户、聊天室、歌单具备最小闭环
- 一对一沟通无需私信域即可通过双人聊天室完成
- 多平台链接映射对错误命中保持保守
