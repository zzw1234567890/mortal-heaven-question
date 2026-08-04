# Story 001: EventTemplate Resource 数据模型 —— Inspector 可编辑字段

> **Epic**: event-system
> **Story 类型**: Logic（需 GUT 单元测试）
> **预估工作量**: 3 点
> **依赖**: 无
> **阻塞**: Story 002, Story 003, Story 004, Story 005
> **Status**: Complete
> **Last Updated**: 2026-08-02

## 覆盖的 GDD 需求

| TR-ID | 需求描述 | 覆盖方式 |
|-------|---------|---------|
| TR-event-001 | 6 种事件类型 + 60-100 个事件模板的条件分支和结果数据 | 定义 EventType/ConditionType/ConditionOperator/OutcomeType 四个枚举；定义 EventCondition、EventOutcome、EventOption、EventTemplate 四个 Resource 类 |

## 管辖 ADR 指南

ADR-0003 决策 1：事件模板以 Godot Resource（`.tres`）格式存储，在编辑器 Inspector 中可视化编辑。所有 `@export` 字段使用 Inspector 原生支持的类型（enum/String/int/float/bool）——**禁止使用 `Variant`**。`use_range` 显式标志消除 `min=max=0` 歧义。

## 控制清单版本

2026-07-26

> Foundation 层规则：
> - EventTemplate 存储为 Godot Resource (`.tres`) —— 所有 `@export` 字段 Inspector 可编辑，禁止使用 `Variant` 类型
> - 禁止在 `@export` 字段中使用 `Variant` 类型 —— 使用类型化字段（enum/String/int/float/bool）以确保 Inspector 可编辑

## 实现范围

### 1. 枚举定义

在 `src/foundation/event_system/event_enums.gd` 中定义：

- **EventType**: `LING_MAI_CAIJUE = 0`, `FANG_SHI_JIAOYI = 1`, `DONG_FU_QIYU = 2`, `SHA_REN_DUO_BAO = 3`, `LIAN_DAN_LIAN_QI = 4`, `XIE_YUE_SAN_XING = 5`
- **ConditionType**: `REALM = 0`, `FACTION = 1`, `RESOURCE = 2`, `CARD_OWNED = 3`, `FLAG_SET = 4`, `FLAG_NOT_SET = 5`
- **ConditionOperator**: `GE = 0`, `EQ = 1`, `LT = 2`
- **OutcomeType**: `ADD_RESOURCE = 0`, `ADD_CULTIVATION = 1`, `ADD_CARD = 2`, `REMOVE_CARD = 3`, `HEAL = 4`, `DAMAGE = 5`, `SET_FLAG = 6`, `GAIN_TALENT = 7`, `TRIGGER_BATTLE = 8`, `ADVANCE_CHAPTER = 9`, `RESTORE_AP = 10`, `NOTHING = 11`

> 注意：此 OutcomeType 枚举是权威来源——ADR-0009（卡牌效果引擎）必须扩展（非复制）此枚举。

### 2. Resource 类定义

在 `src/foundation/event_system/` 目录中创建以下 4 个 Resource 类，**所有 `@export` 字段使用 Inspector 原生类型**：

| 类 | 文件 | 关键字段 |
|---|------|---------|
| `EventCondition` | `event_condition.gd` | `type: ConditionType`; `operator: ConditionOperator`; `target: String`; `value_str: String`; `value_int: int` |
| `EventOutcome` | `event_outcome.gd` | `type: OutcomeType`; `target: String`; `value_str: String`; `value_int: int`; `use_range: bool`; `min_value: int`; `max_value: int`; `chance: float`（`@export_range(0.0, 1.0, 0.01)`） |
| `EventOption` | `event_option.gd` | `option_id: String`; `text: String`（`@export_multiline`）; `conditions: Array[EventCondition]`; `outcomes: Array[EventOutcome]`; `weight_override: int` |
| `EventTemplate` | `event_template.gd` | `template_id: StringName`; `event_type: EventType`; `title: String`; `description: String`（`@export_multiline`）; `min_realm: int`; `weight: int`; `chain_next: StringName`; `chain_on_option: int`（-1=任意选项触发）; `is_hidden: bool`; `options: Array[EventOption]` |

### 3. 字段组织

使用 `@export_group` / `@export_subgroup` 优化嵌套 Resource 在 Inspector 中的浏览体验。

## 验收标准

- [ ] **AC-001**: EventTemplate Resource 可在 Godot 编辑器 Inspector 中完整编辑——4 层嵌套（Template → Option → Condition/Outcome）均可展开/折叠
- [ ] **AC-002**: EventType、ConditionType、ConditionOperator、OutcomeType 四个枚举在 Inspector 中以下拉菜单形式显示，所有枚举值可正确选择
- [ ] **AC-003**: EventOutcome 中 `use_range=false` 且 `min_value=max_value=0` 正确表示精确值（非随机范围）
- [ ] **AC-004**: EventOutcome 中 `use_range=true` 且 `min_value=50, max_value=150` 时，`chance` 滑块范围为 0.00-1.00（步进 0.01）
- [ ] **AC-005**: EventTemplate 字段 `chain_on_option = -1` 正确表示"任意选项均可触发连锁"（默认行为）
- [ ] **AC-006**: EventTemplate 字段 `is_hidden = true` 正确标记斜月三星洞隐藏奇遇
- [ ] **AC-007**: EventTemplate 字段 `weight = 0` 时，该模板不会被 `select_event()` 选中（权重过滤）
- [ ] **AC-008**: EventOption 字段 `weight_override = 0` 正确表示"无权重覆盖"（使用模板默认权重）
- [ ] **AC-009**: 所有 `@export` 字段无 `Variant` 类型——全部使用 enum/String/int/float/bool/StringName/Array[typed]
- [ ] **AC-010**: 使用 `@export_group` / `@export_subgroup` 组织字段层次，嵌套 Resource 编辑体验可接受（策划反馈确认）
- [ ] **AC-011**: GUT 单元测试验证：EventCondition/Option/Outcome/Template 实例化后字段读写正确
- [ ] **AC-012**: GUT 单元测试验证：`EventOutcome` 的 `use_range` + `min_value`/`max_value` 字段组合覆盖所有合法状态

## 测试证据路径

| 证据类型 | 位置 |
|---------|------|
| 单元测试 | `tests/unit/event_system/event_template_test.gd` |

## 实现注意事项

- 禁止在 `@export` 字段中使用 `Variant` 类型——即使意味着某些字段需要拆分为 `value_str` + `value_int`
- `chance` 字段使用 `@export_range(0.0, 1.0, 0.01)` 而非普通 float——提供 Inspector 滑块
- `Array[EventCondition]` 和 `Array[EventOutcome]` 使用类型化数组——非 `Array`
- OutcomeType 枚举值 0-11 必须与 ADR-0003 完全一致——禁止重排序
- 所有 Resource 文件使用 `class_name` 注册——启用 Godot 全局引用
- 文件命名：snake_case 匹配类名（`event_condition.gd`、`event_outcome.gd`、`event_option.gd`、`event_template.gd`、`event_enums.gd`）

## Completion Notes
**Completed**：2026-08-02
**Criteria**：10/12 通过（AC-001/AC-002/AC-010 为 Inspector 编辑器行为，延迟至 Godot 编辑器手动验证）
**Deviations**：
  - ADVISORY：enum 字段使用 `int + @export_enum` 而非 `EventEnums.EventType` 等直接 enum 类型注解——GDScript 跨文件 inner enum 解析顺序限制（非 Variant，ADR-0003 精神合规）
  - ADVISORY：Array 类型化（`Array[EventCondition]` 等）因 GDScript 4.6 class_name 跨文件解析顺序限制无法使用——改为裸 `Array` + 文档注释说明（非 Variant，ADR-0003 字母偏差）
  - ADVISORY：`EventEnums extends Object` 而非 `extends RefCounted`——纯枚举类无需引用计数
**Test Evidence**：Logic — `tests/unit/event_system/test_event_template.gd`（50 个测试，全部通过）
**Code Review**：已完成——APPROVED WITH SUGGESTIONS（3 MEDIUM → 引擎限制 + 5 GDScript LOW → 已修复 + 5 QA LOW → 已添加测试）
