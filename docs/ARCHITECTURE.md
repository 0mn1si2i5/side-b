# Side B 架构说明

## 技术方案

- iOS
- SwiftUI
- MVVM（简化版）

---

## 当前实现策略

先做前端 MVP，使用 mock 数据打通核心链路。

核心链路：
链接输入
→ 解析服务（先 mock）
→ 统一歌曲模型
→ 房间消息
→ UI 展示
→ 平台跳转

---

## 目录结构说明

### App/

应用入口、根视图、全局状态入口

### Core/

跨模块共享的基础层：

- Models
- Services
- Utils

### Features/

按业务模块组织页面与 ViewModel：

- Rooms
- Share
- TrackDetail
- Profile（未来）

### Shared/

可复用组件与样式：

- 通用卡片
- 通用按钮
- 主题与扩展

### Resources/

本地 mock 数据、静态资源

---

## 核心模型（MVP）

### Track

统一歌曲模型

### PlatformLink

歌曲对应的平台链接信息

### Room

房间

### Message

房间中的一条消息，可承载歌曲卡片

---

## 核心服务（MVP）

### MusicResolverService

输入：

- 一个歌曲链接字符串

输出：

- 一个统一 Track 对象（先 mock）

职责：

- 识别链接来源平台
- 返回基础歌曲信息
- 返回平台跳转信息

---

## 当前技术原则

1. 先打通核心数据流
2. 再补 UI
3. 最后再考虑真实 API
4. 截图识别后置
5. 站内播放不做
