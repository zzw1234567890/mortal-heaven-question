
# 代理测试规格：unity-specialist

## 代理摘要
领域：Unity 特有的架构模式、MonoBehaviour 与 DOTS 的决策，以及子系统选择（Addressables、New Input System、UI Toolkit、Cinemachine 等）。
不负责：特定语言的深入探讨（委派给 unity-dots-specialist、unity-ui-specialist 等）。
模型层级：Sonnet（默认）。
未分配门禁 ID。

---

## 静态断言（结构性）

- [ ] `description:` 字段存在且与领域相关（提及 Unity 模式 / MonoBehaviour / 子系统决策）
- [ ] `allowed-tools:` 列表包含 Read、Write、Edit、Bash、Glob、Grep
- [ ] 模型层级为 Sonnet（专家代理默认值）
- [ ] 代理定义承认子专家路由表（DOTS、UI、Shader、Addressables）

---

## 测试用例

### 用例 1：领域内请求 —— 合适的输出
**输入：** "存储敌人配置数据应该使用 MonoBehaviour 还是 ScriptableObject？"
**预期行为：**
- 产出涵盖以下内容的模式决策树：
  - MonoBehaviour：用于运行时行为，需要附加到 GameObject，具有 Update() 生命周期
  - ScriptableObject：用于纯数据/配置，作为资源存在，跨实例共享，无场景依赖
- 推荐使用 ScriptableObject 存储敌人配置数据（无状态、可复用、对设计师友好）
- 注明 MonoBehaviour 可以引用 ScriptableObject 供运行时使用
- 提供 ScriptableObject 类定义外观的具体示例（不产出完整代码 —— 交由 engine-programmer 或 gameplay-programmer 实现）

### 用例 2：错误引擎重定向
**输入：** "为此敌人系统设置一个带有信号的 Node 场景树。"
**预期行为：**
- 不产出 Godot Node/信号代码
- 识别此为 Godot 模式
- 说明在 Unity 中等效方案是 GameObject 层级结构 + UnityEvent 或 C# 事件
- 映射概念：Godot Node → Unity MonoBehaviour，Godot Signal → C# event / UnityEvent
- 在继续之前确认项目基于 Unity

### 用例 3：Unity 版本 API 标记
**输入：** "使用新的 Unity 6 GPU Resident Drawer 进行批量渲染。"
**预期行为：**
- 识别 Unity 6 功能（GPU Resident Drawer）
- 标记此 API 在较早的 Unity 版本中可能不可用
- 在提供实现指导前询问或检查项目的 Unity 版本
- 引导用户对照官方 Unity 6 文档进行验证
- 不经确认即假定项目运行在 Unity 6

### 用例 4：DOTS 与 MonoBehaviour 冲突
**输入：** "战斗系统使用 MonoBehaviour 进行状态管理，但我们想添加一个基于 DOTS 的投射物系统。它们能共存吗？"
**预期行为：**
- 识别此为混合架构场景
- 解释混合方法：MonoBehaviour 可以通过 SystemAPI、IComponentData 和托管组件与 DOTS 交互
- 说明混合两种模式的性能和复杂性权衡
- 建议将架构决策升级至 `lead-programmer` 或 `technical-director`
- 将 DOTS 端的实现细节交由 `unity-dots-specialist` 处理

### 用例 5：上下文传递 —— Unity 版本
**输入：** 项目上下文提供：Unity 2023.3 LTS。请求："为此项目配置 New Input System。"
**预期行为：**
- 应用 Unity 2023.3 LTS 上下文：使用 New Input System（com.unity.inputsystem）包
- 不产出旧的输入管理器代码（`Input.GetKeyDown()`、`Input.GetAxis()`）
- 注明任何 2023.3 特有的 Input System 行为或包版本约束
- 如果 Input System 与 DOTS 交互，引用项目版本以确认 Burst/Jobs 兼容性

---

## 协议合规

- [ ] 保持在声明的领域内（Unity 架构决策、模式选择、子系统路由）
- [ ] 将 Godot 模式重定向到相应的 Godot 专家，或标记为错误引擎
- [ ] 将 DOTS 实现重定向到 unity-dots-specialist
- [ ] 将 UI 实现重定向到 unity-ui-specialist
- [ ] 标记受 Unity 版本限制的 API，并在建议前要求确认版本
- [ ] 返回结构化的模式决策指南，而非自由形式的意见

---

## 覆盖说明
- MonoBehaviour 与 ScriptableObject（用例 1）如果产生项目级决策，应记录为 ADR
- 版本标记（用例 3）确认代理不会在无上下文的情况下假定最新 Unity 版本
- DOTS 混合（用例 4）验证代理会将架构冲突升级处理，而非单方面解决
