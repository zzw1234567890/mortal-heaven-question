
# 代理测试规格：godot-specialist

## 代理摘要
领域：Godot 特有模式、节点/场景架构 (node/scene architecture)、信号 (signals)、资源 (resources) 以及 GDScript 与 C# 与 GDExtension 的决策。
不负责：特定语言的实际代码编写（委派给语言子专家）。
模型层级：Sonnet（默认）。
未分配门禁 ID。

---

## 静态断言（结构性）

- [ ] `description:` 字段存在且与领域相关（提及 Godot 架构 / 节点模式 / 引擎决策）
- [ ] `allowed-tools:` 列表包含 Read、Write、Edit、Bash、Glob、Grep
- [ ] 模型层级为 Sonnet（专家代理默认值）
- [ ] 代理定义引用 `docs/engine-reference/godot/VERSION.md` 作为权威 API 来源

---

## 测试用例

### 用例 1：领域内请求 —— 合适的输出
**输入：** "在 Godot 中，何时应该使用信号 (signal) 而非直接方法调用 (direct method call)？"
**预期行为：**
- 产出带有理由的模式决策指南：
  - 信号：解耦通信、父级对子级无知、事件驱动的 UI 更新、一对多通知
  - 直接调用：调用者需要返回值的紧耦合系统，或性能关键的热路径
- 提供每种模式在项目上下文中的具体示例
- 不产出两种模式的原始代码 —— 具体实现请参考 gdscript-specialist 或 csharp-specialist
- 注明"不向上发信号"约定（子级不直接调用父级方法——而是使用信号）

### 用例 2：错误引擎重定向
**输入：** "编写一个在 Start() 运行时订阅 UnityEvent 的 MonoBehaviour。"
**预期行为：**
- 不产出 Unity MonoBehaviour 代码
- 明确指出这是 Unity 模式，而非 Godot 模式
- 提供 Godot 等效方案：使用 `_ready()` 代替 `Start()` 的 Node 脚本，以及使用 Godot 信号代替 UnityEvent
- 确认项目基于 Godot，并重定向概念映射

### 用例 3：知识截止后的 API 风险
**输入：** "使用新的 Godot 4.5 @abstract 注解来定义一个抽象基类。"
**预期行为：**
- 识别出 `@abstract` 是知识截止日期之后的功能（在 Godot 4.5 中引入，晚于 LLM 知识截止日期）
- 标记版本风险：LLM 对该注解的了解可能不完整或不正确
- 引导用户参照 `docs/engine-reference/godot/VERSION.md` 和官方 4.5 迁移指南进行验证
- 基于版本参考中的迁移说明提供尽力而为的指导，同时明确标注为未经验证

### 用例 4：热路径的语言选择
**输入：** "物理查询循环每帧对 500 个对象运行。对此我们应该使用 GDScript 还是 C#？"
**预期行为：**
- 提供平衡分析：
  - GDScript：更简单，团队熟悉，但在紧循环中较慢
  - C#：对 CPU 密集型循环更快，需要 .NET 运行时，团队需要 C# 知识
- 不单方面做出最终决定
- 将决策连同分析结果提交给 `lead-programmer`
- 注明对于极端性能情况，GDExtension（C++）是第三种选择，并建议在 C# 不足时升级处理

### 用例 5：上下文传递 —— 引擎版本 4.6
**输入：** 引擎版本上下文提供：Godot 4.6，Jolt 为默认物理引擎。请求："为玩家角色设置一个 RigidBody3D。"
**预期行为：**
- 读取 4.6 上下文并应用 Jolt 默认知（来自 VERSION.md 迁移说明）
- 推荐与 Jolt 兼容的 RigidBody3D 配置选择（例如，注明任何在 Jolt 下表现不同的 GodotPhysics 特有设置）
- 引用 4.6 迁移说明中关于 Jolt 成为默认物理引擎的说明，而非仅依赖 LLM 训练数据
- 标记任何在 GodotPhysics 和 Jolt 之间行为发生变化的 RigidBody3D 属性

---

## 协议合规

- [ ] 保持在声明的领域内（Godot 架构决策、节点/场景模式、语言选择）
- [ ] 将特定语言的实现重定向到 godot-gdscript-specialist 或 godot-csharp-specialist
- [ ] 返回结构化结果（决策树、带理由的模式推荐）
- [ ] 将 `docs/engine-reference/godot/VERSION.md` 视为高于 LLM 训练数据的权威来源
- [ ] 标记知识截止日期后的 API 使用（4.4、4.5、4.6）并要求验证
- [ ] 当存在权衡时，将语言选择决策交由 lead-programmer 处理

---

## 覆盖说明
- 信号与直接调用指南（用例 1）应作为可复用的模式文档写入 `docs/architecture/`
- 截止日期后标记（用例 3）确认代理不会自信地使用其无法验证的 API
- 引擎版本用例（用例 5）验证代理应用版本参考中的迁移说明而非自己的假设
