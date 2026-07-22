# 技能测试规格：/setup-engine


## 技能概要

`/setup-engine` 通过填充 `technical-preferences.md` 来配置项目的引擎、语言、渲染后端、物理引擎、专家智能体分配以及命名规范。它接受一个可选的引擎参数（例如 `/setup-engine godot`）以跳过引擎选择步骤。对于 `technical-preferences.md` 的每个章节，该技能会呈现一份草稿并在更新前询问"我可以写入 `technical-preferences.md` 吗？"。

该技能还会根据所选引擎填充专家路由表（文件扩展名到智能体的映射）。它没有主管闸门（director gates）——配置是一项技术性实用任务。当文件完全写入后，判定结果始终为 COMPLETE。

---

## 静态断言（结构性）

由 `/skill-test static` 自动验证——无需测试夹具（fixture）。

- [ ] 包含必需的元数据字段（frontmatter fields）：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键字：COMPLETE
- [ ] 在更新 technical-preferences.md 前包含"我可以写入"（May I write）协作协议语言
- [ ] 包含下一步交接（next-step handoff）（例如 `/brainstorm` 或 `/start`，取决于流程）

---

## 主管闸门检查

无。`/setup-engine` 是一项技术配置技能。不适用任何主管闸门。

---

## 测试用例

### 用例 1：Godot 4 + GDScript —— 完整引擎配置

**测试夹具：**
- `technical-preferences.md` 仅包含占位符
- 引擎参数已提供：`godot`

**输入：** `/setup-engine godot`

**预期行为：**
1. 技能跳过引擎选择步骤（参数已提供）
2. 技能展示 Godot 的语言选项：GDScript 或 C#
3. 用户选择 GDScript
4. 技能起草所有引擎章节：引擎/语言/渲染/物理字段、命名约定（GDScript 使用 snake_case）、专家分配（godot-specialist、gdscript-specialist、godot-shader-specialist 等）
5. 技能填充路由表：`.gd` → gdscript-specialist、`.gdshader` → godot-shader-specialist、`.tscn` → godot-specialist
6. 技能询问"我可以写入 `technical-preferences.md` 吗？"
7. 批准后写入文件；判定结果为 COMPLETE

**断言：**
- [ ] 引擎字段已设置为 Godot 4（非占位符）
- [ ] 语言字段已设置为 GDScript
- [ ] 命名规范适用于 GDScript（snake_case）
- [ ] 路由表包含 `.gd`、`.gdshader` 和 `.tscn` 条目
- [ ] 专家分配已完成（非占位符）
- [ ] 写入前询问了"我可以写入"
- [ ] 判定结果为 COMPLETE

---

### 用例 2：Unity + C# —— Unity 特定配置

**测试夹具：**
- `technical-preferences.md` 仅包含占位符
- 引擎参数已提供：`unity`

**输入：** `/setup-engine unity`

**预期行为：**
1. 技能将引擎设置为 Unity，语言设置为 C#
2. 命名规范适用于 C#（类使用 PascalCase，字段使用 camelCase）
3. 专家分配引用 unity-specialist、csharp-specialist
4. 路由表：`.cs` → csharp-specialist、`.asmdef` → unity-specialist、`.unity`（场景）→ unity-specialist
5. 技能询问"我可以写入 `technical-preferences.md` 吗？"并在批准后写入

**断言：**
- [ ] 引擎字段已设置为 Unity（非 Godot 或 Unreal）
- [ ] 语言字段已设置为 C#
- [ ] 命名规范反映 C# 约定
- [ ] 路由表包含 `.cs` 和 `.unity` 条目
- [ ] 判定结果为 COMPLETE

---

### 用例 3：Unreal + Blueprint —— Unreal 特定配置

**测试夹具：**
- `technical-preferences.md` 仅包含占位符
- 引擎参数已提供：`unreal`

**输入：** `/setup-engine unreal`

**预期行为：**
1. 技能将引擎设置为 Unreal Engine 5，主要语言设置为 Blueprint（可视化脚本）
2. 专家分配引用 unreal-specialist、blueprint-specialist
3. 路由表：`.uasset` → blueprint-specialist 或 unreal-specialist、`.umap` → unreal-specialist
4. 性能预算预设为 Unreal 默认值（例如，更高的绘制调用预算）
5. 技能询问"我可以写入"并在批准后写入；判定结果为 COMPLETE

**断言：**
- [ ] 引擎字段已设置为 Unreal Engine 5
- [ ] 路由表包含 `.uasset` 和 `.umap` 条目
- [ ] Blueprint 专家已分配
- [ ] 判定结果为 COMPLETE

---

### 用例 4：引擎已配置 —— 提供重新配置特定章节的选项

**测试夹具：**
- `technical-preferences.md` 已将引擎设置为 Godot 4，所有字段已填充
- 未提供引擎参数

**输入：** `/setup-engine`

**预期行为：**
1. 技能读取 `technical-preferences.md` 并检测到引擎已完全配置（Godot 4）
2. 技能报告："引擎已配置为 Godot 4 + GDScript"
3. 技能提供选项：全部重新配置、仅重新配置特定章节（引擎/语言、命名规范、专家、性能预算）
4. 用户选择"仅重新配置性能预算"
5. 仅更新性能预算章节；所有其他字段保持不变
6. 技能询问"我可以写入 `technical-preferences.md` 吗？"并在批准后写入

**断言：**
- [ ] 技能在仅请求章节更新时不会覆盖所有字段
- [ ] 用户被提供章节特定的重新配置选项
- [ ] 写入的文件中仅修改了所选章节
- [ ] 判定结果为 COMPLETE

---

### 用例 5：主管闸门检查 —— 无闸门；setup-engine 是实用技能

**测试夹具：**
- 新项目，未配置引擎

**输入：** `/setup-engine godot`

**预期行为：**
1. 技能完成完整的引擎配置
2. 任何时候都不生成主管智能体
3. 输出中不出现闸门 ID

**断言：**
- [ ] 未调用主管闸门
- [ ] 无闸门跳过消息出现
- [ ] 判定结果为 COMPLETE，无闸门检查

---

## 协议合规性

- [ ] 在询问写入前呈现草稿配置
- [ ] 在写入前询问"我可以写入 `technical-preferences.md` 吗？"
- [ ] 在提供引擎参数时予以尊重（跳过选择步骤）
- [ ] 检测现有配置并提供部分重新配置
- [ ] 为所选引擎的所有关键文件类型填充路由表
- [ ] 文件写入后判定结果为 COMPLETE

---

## 覆盖说明

- Godot 4 + C#（而非 GDScript）遵循与用例 1 相同的流程，但使用不同的命名规范和 godot-csharp-specialist 分配。此变体未单独测试。
- 引擎版本特定的指导（例如，来自 VERSION.md 的 Godot 4.6 知识空白警告）由技能呈现，但此处不进行断言测试。
- 各引擎的性能预算默认值被注明为引擎特定，但未对确切默认值进行断言测试。
