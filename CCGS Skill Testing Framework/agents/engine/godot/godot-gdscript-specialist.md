
# 代理测试规格：godot-gdscript-specialist

## 代理摘要
领域：GDScript 静态类型 (static typing)、GDScript 中的设计模式 (design patterns)、信号架构 (signal architecture)、协程/await 模式 (coroutine/await patterns) 以及 GDScript 性能优化。
不负责：着色器代码（godot-shader-specialist）、GDExtension 绑定（godot-gdextension-specialist）。
模型层级：Sonnet（默认）。
未分配门禁 ID。

---

## 静态断言（结构性）

- [ ] `description:` 字段存在且与领域相关（提及 GDScript / 静态类型 / 信号 / 协程）
- [ ] `allowed-tools:` 列表包含 Read、Write、Edit、Bash、Glob、Grep
- [ ] 模型层级为 Sonnet（专家代理默认值）
- [ ] 代理定义未宣称对着色器代码或 GDExtension 的管辖权

---

## 测试用例

### 用例 1：领域内请求 —— 合适的输出
**输入：** "审查这个 GDScript 文件的类型注解覆盖情况。"
**预期行为：**
- 读取提供的 GDScript 文件
- 标记每个缺少静态类型注解的变量、参数和返回类型
- 产出逐行发现的列表：`var speed = 5.0` → `var speed: float = 5.0`
- 说明 Godot 4 中静态类型在性能和工具支持方面的优势
- 不主动重写整个文件 —— 产出供开发者应用的发现列表

### 用例 2：领域外出请求 —— 正确重定向
**输入：** "编写一个顶点着色器来在世界空间中扭曲网格。"
**预期行为：**
- 不产出 GDScript 或 Godot 着色语言中的着色器代码
- 明确说明着色器编写属于 `godot-shader-specialist`
- 将请求重定向到 `godot-shader-specialist`
- 可以注明 GDScript 端（向着色器传递 uniform、设置着色器参数）属于其领域

### 用例 3：使用协程的异步加载
**输入：** "异步加载一个场景，并在加载完成后生成它。"
**预期行为：**
- 产出一个 Godot 4 的 `await` + `ResourceLoader.load_threaded_request` 模式
- 全程使用静态类型（`var scene: PackedScene`）
- 使用 `ResourceLoader.load_threaded_get_status()` 处理完成检查
- 说明加载失败的错误处理
- 不使用已弃用的 Godot 3 `yield()` 语法

### 用例 4：性能问题 —— 类型化数组建议
**输入：** "实体更新循环很慢；它每帧迭代一个包含 1,000 个节点的非类型化 Array。"
**预期行为：**
- 识别出非类型化的 `Array` 放弃了 GDScript 中的编译器优化
- 建议转换为类型化数组（`Array[Node]` 或特定类型）以启用 JIT 提示
- 注明如果仍然不够，则将该热路径升级为 C# 迁移建议
- 产出类型化数组重构作为即时修复方案
- 在没有性能分析证据的情况下，不建议将整个代码库迁移到 C#

### 用例 5：上下文传递 —— 包含截止日期后功能的 Godot 4.6
**输入：** 引擎版本上下文提供：Godot 4.6。请求："使用 @abstract 为所有敌人类创建一个抽象基类。"
**预期行为：**
- 将 `@abstract` 识别为 Godot 4.5+ 功能（知识截止日期后）
- 在输出中注明：该功能在 4.5 中引入，已对照 VERSION.md 迁移说明验证
- 使用迁移说明中记录的正确语法，以 `@abstract` 产出 GDScript 类
- 由于功能在知识截止日期后，标记输出需要对照官方 4.5 发布说明进行验证
- 在抽象类的所有方法签名中使用静态类型

---

## 协议合规

- [ ] 保持在声明的领域内（GDScript —— 类型、模式、信号、协程、性能）
- [ ] 将着色器请求重定向到 godot-shader-specialist
- [ ] 将 GDExtension 请求重定向到 godot-gdextension-specialist
- [ ] 返回带有完整静态类型的结构化 GDScript 输出
- [ ] 仅使用 Godot 4 API —— 不使用已弃用的 Godot 3 模式（如 yield、字符串连接的 connect 等）
- [ ] 标记知识截止日期后的功能（4.4、4.5、4.6）并要求进行文档验证

---

## 覆盖说明
- 类型注解审查（用例 1）的输出适合作为代码审查核对清单
- 异步加载（用例 3）应产出可在 `tests/unit/` 中通过单元测试验证的可测试代码
- 截止日期后的 @abstract（用例 5）确认代理会标记版本不确定性，而非静默使用未经验证的 API
