# Side B Agent 工作规范

## 项目目标

构建一个 iOS 轻量级跨平台歌曲分享 App。

核心场景：
用户把歌曲链接私发给朋友，或发送到房间中。
接收方可以在 Side B 中查看歌曲信息、平台映射、歌词（如可用）和跳转入口，并跳转到自己常用的音乐 App。

---

## 产品边界

当前版本不是播放器，不实现站内播放。

当前优先做：

- 分享
- 解析
- 展示
- 跳转

不优先做：

- 音频播放
- 复杂推荐
- 社区系统
- 多平台真实 API 深度接入

---

## 开发原则

1. 始终保证项目可编译
2. 不要随意重构目录
3. 不要修改 project.pbxproj，除非明确要求

---

## 架构要求

- 使用 SwiftUI
- 使用 MVVM
- View 不写复杂业务逻辑
- 业务逻辑放在 ViewModel / Service
- 优先小文件、小改动、低耦合

---

## 开发顺序

1. Models
2. Mock Services
3. ViewModels
4. Basic Views
5. Navigation
6. Real Integrations

---

## 当前阶段限制

- 后端已接入四平台真实 API，iOS 端保留 mock fallback（仅 #if DEBUG）
- 不接入真实 Spotify / 网易云 / QQ / Apple Music API（后端已接入，iOS 端不做直连）
- 不实现截图识别，截图输入仅作为未来能力预留
- 不实现站内播放

---

## 目录约定

- `App/`：应用入口与根视图
- `Core/`：模型、服务、基础能力
- `Features/`：业务模块
- `Shared/`：通用 UI 组件
- `Resources/`：本地资源与 mock 数据
- `docs/`：产品与架构文档
- `prompts/`：提示词模板

---

## 输出要求

执行任务时：

1. 先列出将修改的文件
2. 只改必要文件
3. 输出完整代码而不是片段
4. 保证代码可编译

---

## 禁止事项

- 不要引入复杂第三方架构
- 不要一开始就接真实平台 API
- 不要把默认模板代码无限叠加
- 不要把业务逻辑写进 SwiftUI View


## 当前状态（每次接手前更新）

### 已完成
- Phase 1–7 全部完成
- Phase 8–10 主体功能
- 歌单系统、聊天室主路径、四平台 resolver 均可用

### 进行中
- Phase 13：稳定性修复与结构整理

### 当前已知 Bug
- 暂无已知 Bug

### 下一个任务
- [ ] 执行稳定性修复 plan (.sisyphus/plans/stabilization-cleanup.md)

### 近期不要动的模块
- MockMusicResolverService 中的 MockData 引用是有意为之，不要移除
- backend/app/routers/resolve.py 已接替旧 resolve_route.py，不要回退
