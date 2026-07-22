
# 代理测试规格：godot-csharp-specialist

## 代理摘要
领域：Godot 4 中的 C# 模式、应用于 Godot 的 .NET 惯用用法、[Export] 属性用法、信号委托 (signal delegates) 以及 async/await 模式。
不负责：GDScript 代码（gdscript-specialist）、GDExtension C/C++ 绑定（gdextension-specialist）。
模型层级：Sonnet（默认）。
未分配门禁 ID。

---

## 静态断言（结构性）

- [ ] `description:` 字段存在且与领域相关（提及 Godot 4 中的 C# / .NET 模式 / 信号委托）
- [ ] `allowed-tools:` 列表包含 Read、Write、Edit、Bash、Glob、Grep
- [ ] 模型层级为 Sonnet（专家代理默认值）
- [ ] 代理定义未宣称对 GDScript 或 GDExtension 代码的管辖权

---

## 测试用例

### 用例 1：领域内请求 —— 合适的输出
**输入：** "创建一个带有验证的敌人生命值导出属性，将其限制在 1 到 1000 之间。"
**预期行为：**
- 产出带有 `[Export]` 属性的 C# 属性
- 使用带有属性 getter/setter 的后备字段，在 setter 中限制数值
- 不使用无验证的原始 `[Export]` 公共字段
- 遵循 Godot 4 C# 命名约定（属性使用帕斯卡命名法 PascalCase，字段使用下划线前缀且为私有）
- 按照编码标准，在属性上包含 XML 文档注释

### 用例 2：领域外出请求 —— 正确重定向
**输入：** "用 GDScript 重写这个敌人生命值系统。"
**预期行为：**
- 不产出 GDScript 代码
- 明确说明 GDScript 编写属于 `godot-gdscript-specialist`
- 将请求重定向到 `godot-gdscript-specialist`
- 可以描述 C# 接口，以便 gdscript-specialist 了解预期的 API 形状

### 用例 3：异步信号等待
**输入：** "使用 C# async 等待动画完成后再切换游戏状态。"
**预期行为：**
- 使用 `ToSignal()` 等待 Godot 信号，产出正确的 `async Task` 模式
- 使用 `await ToSignal(animationPlayer, AnimationPlayer.SignalName.AnimationFinished)`
- 不使用 `Thread.Sleep()` 或 `Task.Delay()` 作为轮询替代方案
- 注明调用方法必须是 `async`，并且即发即弃的 `async void` 仅适用于事件处理器
- 处理动画可能无法触发时的取消或超时情况

### 用例 4：线程模型冲突
**输入：** "这段 C# 代码从后台 Task 线程访问 Godot Node 来更新其位置。"
**预期行为：**
- 将此标记为竞态条件风险：Godot 节点不是线程安全的，只能从主线程访问
- 不批准或实现多线程节点访问模式
- 提供正确的模式：使用 `CallDeferred()`、`Callable.From().CallDeferred()`，或通过线程安全队列编组回主线程
- 解释 Godot 的主线程要求与 .NET 的线程无关类型之间的区别

### 用例 5：上下文传递 —— Godot 4.6 API 正确性
**输入：** 引擎版本上下文：Godot 4.6。请求："使用新的类型化信号委托模式连接一个信号。"
**预期行为：**
- 使用 Godot 4 C# 中引入的类型化委托模式（在类型化信号上使用 `+=` 运算符）产出 C# 信号连接
- 检查 4.6 上下文，确认在 4.4、4.5 或 4.6 中没有对信号委托 API 的破坏性变更
- 不使用基于字符串的旧式 `Connect("signal_name", callable)` 模式（已在 Godot 4 C# 中弃用）
- 产出与项目锁定的 4.6 版本兼容的代码，如 VERSION.md 中所记录

---

## 协议合规

- [ ] 保持在声明的领域内（Godot 4 中的 C# —— 模式、导出、信号、异步）
- [ ] 将 GDScript 请求重定向到 godot-gdscript-specialist
- [ ] 将 GDExtension 请求重定向到 godot-gdextension-specialist
- [ ] 返回遵循 Godot 4 约定的 C# 代码（而非 Unity MonoBehaviour 模式）
- [ ] 将多线程 Godot 节点访问标记为不安全，并提供正确的模式
- [ ] 使用类型化信号委托 —— 不使用已弃用的基于字符串的 Connect() 调用
- [ ] 在产出代码前检查引擎版本参考中的 API 变更

---

## 覆盖说明
- 带有验证的导出属性（用例 1）应有一个单元测试来验证限制行为
- 线程冲突（用例 4）关乎安全关键：代理必须识别此问题并主动修复
- 异步信号（用例 3）验证代理在 Godot 的单线程约束下正确应用 .NET 惯用用法
