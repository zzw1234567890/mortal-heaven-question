# Story 001: CardTemplate Resource + 枚举定义

> **Epic**: card-system
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic（需 GUT 单元测试）
> **Estimate**: 3h
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-05

## Context

**GDD**: `design/gdd/card-system.md`
**Requirement**: `TR-card-001`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0006（卡牌数据模型——Template/Instance 分离 + Resource 序列化）
**ADR Decision Summary**: 卡牌数据采用 Template（Resource, 只读）/ Instance（RefCounted, 可变）两层分离。CardTemplate 为 Godot Resource，所有字段 @export 且类型化，存储为 `.tres` 文件供策划在 Inspector 编辑。

**Engine**: Godot 4.6.3 | **Risk**: HIGH（训练截止后 API）
**Engine Notes**: `Array[StringName]` 类型化集合（4.4+）安全；@export + .tres 是 Godot 4.6 惯用数据驱动模式。

**Control Manifest Rules (Core 层)**:
- **Required**: CardTemplate (Resource, `.tres`) 运行时只读——所有可变状态在 CardInstance (RefCounted) 上
- **Required**: 所有境界属性查询必须通过 RealmSystem（本 Story 不涉及，但模板字段设计需为下游留接口）
- **Forbidden**: 绝不运行时写 CardTemplate 字段——Resource 共享引用语义导致静默数据损坏
- **Forbidden**: 绝不在 CardTemplate 上使用 `duplicate()`
- **Forbidden**: 绝不在 `@export` 字段中使用 `Variant` 类型

---

## Acceptance Criteria

*From GDD `design/gdd/card-system.md` §详细设计 #1 CardTemplate 共有字段 + 类型专属字段:*

- [ ] **AC-001**: CardTemplate extends Resource，声明 `class_name CardTemplate`
- [ ] **AC-002**: CardType 枚举含 6 个值（CHARACTER / TECHNIQUE / ARTIFACT / FORMATION / PILL / TALISMAN）
- [ ] **AC-003**: Rarity 枚举含 5 个值（WHITE / BLUE / PURPLE / GOLD / DARK_GOLD）
- [ ] **AC-004**: 共有字段全部 @export 且类型化：`card_id: StringName`、`name: String`、`type: CardType`、`rarity: Rarity`、`cost: int`、`faction_tags: Array[StringName]`、`description: String`、`flavor_text: String`、`illustration_path: String`
- [ ] **AC-005**: 角色卡专属字段 @export 且类型化：`base_hp: int`、`base_attack: int`、`innate_skill: StringName`、`technique_slots: int`、`artifact_slots: int`
- [ ] **AC-006**: 功法/法宝卡专属字段 @export 且类型化：`effect_type: StringName`、`effect_value: int`、`native_owner: StringName`、`stack_limit: int`、`stack_multiplier: float`、`trigger_condition: StringName`、`cooldown: int`
- [ ] **AC-007**: 阵法卡专属字段 @export 且类型化：`faction_requirement: StringName`、`required_count: int`、`aura_effect: StringName`
- [ ] **AC-008**: 丹药/符箓卡专属字段 @export 且类型化：`duration_turns: int`、`target_type: StringName`、`base_fail_chance: float`
- [ ] **AC-009**: 所有 @export 字段可在 Godot Inspector 中编辑（通过 @export 反射验证——`PROPERTY_USAGE_EDITOR` 标志置位）
- [ ] **AC-010**: 模板字段禁止 Variant 类型——全部类型化，数组字段必须 `Array[StringName]` 而非裸 `Array`

### 默认值表（QA-lead 提示补充）

| 字段 | 默认值 |
|:--|:--|
| `card_id` | `&""` |
| `name` | `""` |
| `type` | `CardType.CHARACTER` |
| `rarity` | `Rarity.WHITE` |
| `cost` | `0` |
| `faction_tags` | `[]`（空 Array[StringName]） |
| `description` | `""` |
| `flavor_text` | `""` |
| `illustration_path` | `""` |
| `base_hp` / `base_attack` | `0` |
| `innate_skill` / `native_owner` / `effect_type` / `trigger_condition` / `faction_requirement` / `aura_effect` / `target_type` | `&""` |
| `technique_slots` | `3` |
| `artifact_slots` | `3` |
| `effect_value` / `required_count` / `cooldown` / `duration_turns` | `0` |
| `stack_limit` | `3` |
| `stack_multiplier` | `1.5` |
| `base_fail_chance` | `0.0` |

---

## Implementation Notes

*Derived from ADR-0006 §CardTemplate（模板层）—— Resource, `.tres` 文件:*

1. **文件位置**: `src/core/card_system/card_template.gd`
2. **类声明**: `class_name CardTemplate` + `extends Resource`
3. **枚举定义**: CardType 和 Rarity 枚举声明在 CardTemplate 脚本内（同文件，供 CardInstance 引用 `CardTemplate.CardType`）
4. **@export 规范**: 所有字段使用 `@export` 装饰器 + 类型注解。类型化数组用 `@export var faction_tags: Array[StringName] = []`
5. **类型专属字段**: 所有类型专属字段（角色/功法法宝/阵法/丹药符箓）声明在同一个 CardTemplate 类中——按 `type` 字段条件可空，非角色卡模板的角色字段保持默认值 0。策划在 Inspector 中按需填写。
6. **`illustration_path`**: 空字符串表示暂无插画——运行时使用类型默认占位图（ADR-0006 新增字段）
7. **模板只读约束**: 本 Story 仅定义数据结构，不实现运行时写入保护（Story 003 的 `_validate_template_readonly()` 调试断言可选实现）。但 @export 字段本身在运行时不应被业务代码赋值——依赖 convention + 代码审查（grep `CardTemplate` 字段写入）
8. **不声明 class_name 冲突**: CardTemplate 不是 Autoload，声明 `class_name` 安全（与 EventSystem Autoload 不同）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: CardInstance RefCounted 实例模型（成长状态字段）
- **Story 003**: CardSystem 模板注册表 + 异步加载 + `get_template()` 查询接口
- **Story 004**: CardSystem 实例工厂 + GSM 集成（create_instance / enable_validation）
- **Story 005**: 实例序列化/反序列化

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-001**: CardTemplate extends Resource，声明 class_name CardTemplate
  - Given: 项目中存在 `src/core/card_system/card_template.gd`
  - When: 执行 `var script: GDScript = load("res://src/core/card_system/card_template.gd")`
  - Then: `assert_eq(script.get_instance_base_type(), "Resource")`；`assert_true(CardTemplate.new() is Resource)`
  - Edge cases: 确认无重复 class_name 冲突；确认 `class_name` 声明在文件顶部

- **AC-002**: CardType 枚举含 6 个值
  - Given: CardTemplate 脚本已加载
  - When: 读取 CardType 枚举常量
  - Then: 断言 6 个常量存在且名称精确匹配：CHARACTER / TECHNIQUE / ARTIFACT / FORMATION / PILL / TALISMAN
  - Edge cases: 断言枚举值总数 == 6（防止误增）；断言各值唯一

- **AC-003**: Rarity 枚举含 5 个值
  - Given: CardTemplate 脚本已加载
  - When: 读取 Rarity 枚举常量
  - Then: 断言 5 个常量存在且名称精确匹配：WHITE / BLUE / PURPLE / GOLD / DARK_GOLD
  - Edge cases: 断言枚举值总数 == 5；断言各值唯一

- **AC-004**: 共有字段全部 @export 且类型化
  - Given: CardTemplate 实例 `var tpl := CardTemplate.new()`
  - When: 调用 `tpl.get_property_list()`
  - Then: 对每个字段断言：存在性、`PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE` 用法标志、类型匹配（StringName=TYPE_STRING_NAME、String=TYPE_STRING、int=TYPE_INT、CardType/Rarity=枚举类型、Array[StringName] 的 hint==PROPERTY_HINT_ARRAY_TYPE 且 hint_string=="StringName"）
  - Edge cases: 确认无多余 @export 共有字段；确认 faction_tags 是强类型数组而非裸 Array

- **AC-005**: 角色卡专属字段 @export
  - Given: CardTemplate 实例
  - When: 调用 `get_property_list()`
  - Then: 断言 5 个字段均存在且 @export 标志置位；类型化（base_hp: int、base_attack: int、innate_skill: StringName、technique_slots: int、artifact_slots: int）
  - Edge cases: 默认值验证（base_hp=0、technique_slots=3、artifact_slots=3）

- **AC-006**: 功法/法宝卡专属字段 @export
  - Given: CardTemplate 实例
  - When: 调用 `get_property_list()`
  - Then: 断言 7 个字段均存在、@export 置位、类型化（effect_type: StringName、effect_value: int、native_owner: StringName、stack_limit: int、stack_multiplier: float、trigger_condition: StringName、cooldown: int）
  - Edge cases: 默认值验证（stack_limit=3、stack_multiplier=1.5）

- **AC-007**: 阵法卡专属字段 @export
  - Given: CardTemplate 实例
  - When: 调用 `get_property_list()`
  - Then: 断言 3 个字段均存在、@export 置位、类型化（faction_requirement: StringName、required_count: int、aura_effect: StringName）
  - Edge cases: 默认值验证（required_count=0）

- **AC-008**: 丹药/符箓卡专属字段 @export
  - Given: CardTemplate 实例
  - When: 调用 `get_property_list()`
  - Then: 断言 3 个字段均存在、@export 置位、类型化（duration_turns: int、target_type: StringName、base_fail_chance: float）
  - Edge cases: 默认值验证（duration_turns=0、base_fail_chance=0.0）

- **AC-009**: CardTemplate 可在 Godot Inspector 中编辑（@export 验证）
  - Given: CardTemplate 实例
  - When: 遍历 `get_property_list()` 中所有 @export 字段
  - Then: 每个字段的 usage 包含 `PROPERTY_USAGE_EDITOR`
  - Edge cases: 反射验证等价于 Inspector 可编辑性

- **AC-010**: 模板字段禁止 Variant 类型（全部类型化）
  - Given: CardTemplate 实例
  - When: 遍历所有 @export 字段的 `type` 与 `hint_string`
  - Then: 断言无字段 `type == TYPE_NIL` 且无裸 `Array`（hint_string 为空但 type==TYPE_ARRAY）；所有数组字段必须 `hint == PROPERTY_HINT_ARRAY_TYPE` 且 `hint_string` 非空
  - Edge cases: 私有非 @export 变量不在断言范围（仅验证 @export 表面）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_system/test_card_template.gd` — must exist and pass
**Status**: [x] Created and passing (23/23 tests, 222 assertions)

---

## Dependencies

- Depends on: None（Core 层第一个 Story，Foundation 层 GSM 已在 Sprint 1 完成）
- Unlocks: Story 002（CardInstance 引用 CardType 枚举）、Story 003（CardSystem 加载 CardTemplate .tres 文件）

---

## Completion Notes

**Completed**：2026-08-05
**Criteria**：10/10 通过（所有 AC 自动化验证通过）
**Deviations**：
- ADVISORY：Rarity 枚举改为 1-based（WHITE=1...DARK_GOLD=5）——与 ResourceSystem 公式契约 `DISMANTLE_BASE[rarity-1]` 一致，Story 创建时 0-based，实现时修正。建议后续修订 ADR-0006 同步此决策。
- ADVISORY：源码路径从 `src/card_system/` 移至 `src/core/card_system/`——与其他 Core 层系统（resource/faction/realm）保持一致，5 个 card-system Story 文件路径声明已同步更新。
- ADVISORY：测试文件 312 行略超 300 行软限制——可按 AC 拆分为 enums + fields 两个文件，非阻塞。
- ADVISORY：AC-001 class_name 冲突检测难以自动化——当前仅断言 class_name 声明存在，未验证无其他 class_name CardTemplate 声明。建议未来编写 grep 静态检查脚本。
- ADVISORY：CardType 枚举可补充类似 Rarity 的"0-based——无公式依赖"文档说明，保持两个枚举文档风格一致。

**Test Evidence**：Logic — `tests/unit/card_system/test_card_template.gd`（23 测试函数，222 断言，全部通过）
**Code Review**：已完成——godot-gdscript-specialist APPROVED WITH SUGGESTIONS + qa-tester TESTABLE，无阻塞项。5 项建议已修复 2 项（PROPERTY_USAGE_STORAGE 断言 + 无多余字段反向断言），其余 3 项记录为 ADVISORY。

### 测试结果

- **23/23 测试通过**，222 断言，0.878s
- 覆盖 10 条 AC 全部
- 修复 2 项 qa-tester 建议：
  1. 补充 `PROPERTY_USAGE_STORAGE` 断言（AC-009 双标志——确保 .tres 序列化）
  2. 补充"无多余 @export 字段"反向断言（AC-004 Edge cases——声明字段数 == 27）

### 关键修正记录

1. **Rarity 1-based**（WHITE=1...DARK_GOLD=5）——匹配 ResourceSystem `dismantle_value(rarity, level)` 的 `DISMANTLE_BASE[rarity-1]` 数组索引契约
2. **路径统一**——`src/card_system/` → `src/core/card_system/`，card-system 5 个 Story 文件路径声明同步更新
3. **GUT bool 断言**——`assert_true(usage & FLAG)` 改为 `assert_true((usage & FLAG) != 0)`（Godot 4.6 严格要求 bool）
4. **类型化数组断言**——`hint_string` 实际为 `"21:"`（元素类型 ID 前缀），用 `begins_with(str(TYPE_STRING_NAME) + ":")` 动态校验
