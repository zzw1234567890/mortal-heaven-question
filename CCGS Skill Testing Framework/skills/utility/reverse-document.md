
# 技能测试规格：/reverse-document

## 技能概述 (Skill Summary)

`/reverse-document` 根据现有源代码生成设计或架构文档。它读取指定的源文件，从类结构、方法名称、常量和注释中推断设计意图，并生成 GDD 骨架（适用于玩法系统）或架构概览（适用于技术系统）。输出是基于最佳努力的推断——魔数（magic numbers）和未记录的逻辑可能导致 PARTIAL 判定。

技能在创建文档前询问"我可以写入 [推断路径] 吗？"。不适用主管关口。判定结果：COMPLETE（推断清晰）、PARTIAL（部分字段存在歧义，需要人工审查）。

---

## 静态断言（结构性）

由 `/skill-test static` 自动验证——无需测试夹具。

- [ ] 包含必需的 frontmatter 字段：`name`、`description`、`argument-hint`、`user-invocable`、`allowed-tools`
- [ ] 包含 ≥2 个阶段标题
- [ ] 包含判定关键词：COMPLETE、PARTIAL
- [ ] 在写入文档前包含"May I write"协作协议用语
- [ ] 包含下一步交接（例如 `/design-review` 用于验证生成的文档）

---

## 主管关口检查

无。`/reverse-document` 是一个文档工具。不适用主管关口。

---

## 测试用例

### 用例 1：结构清晰的源代码——生成准确的设计文档骨架

**测试夹具：**
- `src/gameplay/health_system.gd` 存在，包含：
  - `@export var max_health: int = 100`
  - `func take_damage(amount: int)` 带钳制逻辑（clamping logic）
  - `signal health_changed(new_value: int)`
  - 所有公共方法的文档字符串

**输入：** `/reverse-document src/gameplay/health_system.gd`

**预期行为：**
1. 技能读取源文件并识别出生命值系统
2. 技能推断设计意图：最大生命值、take_damage 行为、生命值信号
3. 技能为生命值系统生成包含 8 个必需章节的 GDD 骨架：
   概述、玩家幻想、详细规则、公式、边缘情况、依赖关系、调优旋钮、验收标准
4. 公式章节包含推断的钳制公式
5. 调优旋钮将 `max_health = 100` 注明为可配置值
6. 技能询问"我可以写入 `design/gdd/health-system.md` 吗？"
7. 写入文件；判定结果为 COMPLETE

**断言：**
- [ ] 输出中包含所有 8 个必需的 GDD 章节
- [ ] `max_health = 100` 出现在调优旋钮中
- [ ] 钳制公式记录在公式章节中
- [ ] 使用推断路径询问"May I write"
- [ ] 判定结果为 COMPLETE

---

### 用例 2：歧义源代码——魔数，PARTIAL 判定

**测试夹具：**
- `src/gameplay/enemy_ai.gd` 存在，包含：
  - 内联魔数：`if distance < 150:`、`speed = 3.5`
  - 无注释或文档字符串
  - 复杂的、不易自解释的状态机逻辑

**输入：** `/reverse-document src/gameplay/enemy_ai.gd`

**预期行为：**
1. 技能读取文件并检测到无上下文的魔数
2. 技能生成 GDD 骨架，附注释："歧义值 (AMBIGUOUS VALUE)：150（未知单位——是像素、世界单位还是瓦片？）"
3. 技能标记公式和调优旋钮章节需要人工审查
4. 技能询问"我可以写入 `design/gdd/enemy-ai.md` 吗？" 并附 PARTIAL 提示
5. 写入文件并带 PARTIAL 标记；判定结果为 PARTIAL

**断言：**
- [ ] 魔数出现歧义值注释（AMBIGUOUS VALUE）
- [ ] 需要人工审查的章节被明确标记
- [ ] 判定结果为 PARTIAL（而非 COMPLETE）
- [ ] 文件仍被写入——PARTIAL 不是阻塞性失败

---

### 用例 3：多个相互依赖的文件——生成跨系统概览

**测试夹具：**
- 用户提供 2 个源文件：`combat_system.gd` 和 `damage_resolver.gd`
- 文件相互引用（combat 调用 damage_resolver）

**输入：** `/reverse-document src/gameplay/combat_system.gd src/gameplay/damage_resolver.gd`

**预期行为：**
1. 技能读取两个文件并检测依赖关系
2. 技能生成跨系统架构概览（而非单独的 GDD）
3. 概览描述：战斗系统 → 伤害解析器的交互、共享接口、两者之间的数据流
4. 技能询问"我可以写入 `docs/architecture/combat-damage-overview.md` 吗？"
5. 批准后写入概览；判定结果为 COMPLETE（若有歧义则为 PARTIAL）

**断言：**
- [ ] 两个文件一起分析（而非作为两份独立文档）
- [ ] 输出中记录了跨系统依赖关系
- [ ] 输出文件写入 `docs/architecture/`（而非 `design/gdd/`）
- [ ] 判定结果为 COMPLETE 或 PARTIAL

---

### 用例 4：源文件未找到——错误提示

**测试夹具：**
- `src/gameplay/inventory_system.gd` 不存在

**输入：** `/reverse-document src/gameplay/inventory_system.gd`

**预期行为：**
1. 技能尝试读取指定文件——未找到
2. 技能输出："源文件未找到：src/gameplay/inventory_system.gd"
3. 技能建议检查路径或运行 `/map-systems` 以识别正确的源文件
4. 不创建任何文档

**断言：**
- [ ] 错误信息包含缺失文件的完整路径
- [ ] 提供了替代建议（检查路径或 `/map-systems`）
- [ ] 未调用写入工具
- [ ] 不发出判定（错误状态）

---

### 用例 5：主管关口检查——无关卡；reverse-document 是工具

**测试夹具：**
- 存在结构清晰的源文件

**输入：** `/reverse-document src/gameplay/health_system.gd`

**预期行为：**
1. 技能生成并写入设计文档
2. 不生成任何主管智能体
3. 输出中不出现关口 ID

**断言：**
- [ ] 未调用主管关口
- [ ] 不出现关口跳过消息
- [ ] 判定结果为 COMPLETE 或 PARTIAL——不涉及任何关口判定

---

## 协议合规性

- [ ] 在生成任何内容前读取源文件
- [ ] 当目标是玩法系统时，生成全部 8 个必需的 GDD 章节
- [ ] 使用歧义值标记（AMBIGUOUS VALUE）注释歧义值
- [ ] 对于多个文件，生成跨系统概览（而非单独的 GDD）
- [ ] 在创建任何输出文件前询问"May I write"
- [ ] 判定结果为 COMPLETE（推断清晰）或 PARTIAL（字段歧义）

---

## 覆盖说明

- 架构概览格式（适用于技术/基础设施系统）与 GDD 格式不同；推断的输出类型由源文件的性质决定（玩法逻辑 → GDD；引擎/基础架构代码 → 架构文档）。
- 源文件可读但仅包含自动生成的样板代码且无有意义逻辑的情况未测试；技能可能会生成近乎空白的骨架并给出 PARTIAL 判定。
- C# 和 Blueprint 源文件遵循与 GDScript 相同的推断模式；语言特定的差异在技能主体中处理。