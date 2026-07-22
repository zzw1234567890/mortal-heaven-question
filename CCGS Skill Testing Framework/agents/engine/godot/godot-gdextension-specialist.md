
# 代理测试规格：godot-gdextension-specialist

## 代理摘要
领域：GDExtension API、godot-cpp C++ 绑定、godot-rust 绑定、原生库集成与原生性能优化。
不负责：GDScript 代码（gdscript-specialist）、着色器代码（godot-shader-specialist）。
模型层级：Sonnet（默认）。
未分配门禁 ID。

---

## 静态断言（结构性）

- [ ] `description:` 字段存在且与领域相关（提及 GDExtension / godot-cpp / 原生绑定）
- [ ] `allowed-tools:` 列表包含 Read、Write、Edit、Bash、Glob、Grep
- [ ] 模型层级为 Sonnet（专家代理默认值）
- [ ] 代理定义未宣称对 GDScript 或着色器编写的管辖权

---

## 测试用例

### 用例 1：领域内请求 —— 合适的输出
**输入：** "通过 GDExtension 将一个 C++ 刚体物理模拟库暴露给 GDScript。"
**预期行为：**
- 产出使用 godot-cpp 的 GDExtension 绑定模式：
  - 继承自 `godot::Object` 或合适的 Godot 基类的类
  - `GDCLASS` 宏注册
  - 向 GDScript 暴露物理 API 的 `_bind_methods()` 实现
  - `GDExtension` 入口点（`gdextension_init`）设置
- 说明所需的 `.gdextension` 清单文件格式
- 不产出 GDScript 使用代码（那属于 gdscript-specialist）

### 用例 2：领域外重定向
**输入：** "编写从用例 1 调用物理模拟的 GDScript。"
**预期行为：**
- 不产出 GDScript 代码
- 明确说明 GDScript 编写属于 `godot-gdscript-specialist`
- 重定向到 `godot-gdscript-specialist`
- 可以作为交接规格描述 GDScript 应调用的 API 表面（方法名、参数类型）

### 用例 3：ABI 兼容性风险 —— 次版本更新
**输入：** "我们要从 Godot 4.5 升级到 4.6。现有的 GDExtension 还能用吗？"
**预期行为：**
- 标记 ABI 兼容性问题：GDExtension 二进制文件在次版本之间可能不具备 ABI 兼容性
- 指引查阅 4.5→4.6 迁移指南中的 GDExtension API 变更
- 建议针对 4.6 的 godot-cpp 头文件重新编译扩展，而不是假定二进制兼容
- 说明 `.gdextension` 清单可能需要更新 `compatibility_minimum` 版本
- 提供重新编译检查清单

### 用例 4：内存管理 —— Godot 对象的 RAII
**输入：** "在 C++ GDExtension 代码中创建的 Godot 对象，生命周期该如何管理？"
**预期行为：**
- 产出 GDExtension 中 Godot 对象的 RAII 生命周期管理模式：
  - 引用计数对象使用 `Ref<T>`（Ref 离开作用域时自动释放）
  - 非引用计数对象使用 `memnew()` / `memdelete()`
  - 警告：不要对 Godot 对象使用 `new`/`delete` —— 未定义行为
- 说明对象所有权规则：谁负责释放已添加到场景树的节点
- 提供在 C++ 中管理 `CollisionShape3D` 的具体示例

### 用例 5：上下文传递 —— Godot 4.6 GDExtension API 检查
**输入：** 引擎版本上下文：Godot 4.6（从 4.5 升级）。请求："检查 4.5 到 4.6 之间是否有 GDExtension API 变更。"
**预期行为：**
- 引用 VERSION.md 已验证来源列表中的 4.5→4.6 迁移指南
- 报告 4.6 版本中所有记录在案的 GDExtension API 变更
- 如果 4.6 中没有记录在案的 GDExtension 破坏性变更，明确说明，并附加需对照官方更新日志验证的提醒
- 标记 Windows 上 D3D12 成为默认（4.6 变更）可能与 GDExtension 渲染代码相关
- 提供升级后需要验证事项的检查清单

---

## 协议合规

- [ ] 保持在声明的领域内（GDExtension、godot-cpp、godot-rust、原生绑定）
- [ ] 将 GDScript 编写重定向到 godot-gdscript-specialist
- [ ] 将着色器编写重定向到 godot-shader-specialist
- [ ] 返回结构化输出（绑定模式、RAII 示例、ABI 检查清单）
- [ ] 在次版本升级时标记 ABI 兼容性风险 —— 绝不假定二进制兼容
- [ ] 使用 Godot 特有的内存管理（`memnew`/`memdelete`、`Ref<T>`），而非原生 C++ new/delete
- [ ] 确认兼容性之前，先查阅引擎版本参考中的 GDExtension API 变更

---

## 覆盖说明
- 绑定模式（用例 1）应包含一个冒烟测试，验证扩展可加载且方法可从 GDScript 调用
- ABI 风险（用例 3）是关键升级路径 —— 代理不得批准发布未经验证的扩展二进制文件
- 内存管理（用例 4）验证代理应用的是 Godot 特有模式，而非通用 C++ RAII
