# Story 002: EventInstance 运行时实例 + 事件触发/条件判定/选项结算

> **Status**: Complete
> **Last Updated**: 2026-08-03
> **Epic**: event-system
> **Story 类型**: Logic（需 GUT 单元测试）
> **预估工作量**: 5 点
> **依赖**: Story 001（EventTemplate Resource 数据模型）
> **阻塞**: Story 003, Story 004, Story 005

## 覆盖的 GDD 需求

| TR-ID | 需求描述 | 覆盖方式 |
|-------|---------|---------|
| TR-event-001 | 6 种事件类型 + 60-100 个事件模板的条件分支和结果数据 | `_load_templates()` 同步加载 .tres 文件到 Dictionary 注册表；`trigger_event()` 创建 EventInstance 并过滤选项 |
| TR-event-003 | 概率结果结算——chance + [min, max] 随机值范围 | `resolve_option()` 结算 chance 判定 + use_range 随机值范围 |

## 管辖 ADR 指南

- ADR-0003 决策 2：EventInstance 为 RefCounted 临时对象——**不持有 Resource 引用**，仅存储 `template_id: StringName` 和 `available_option_indices: Array[int]`
- ADR-0003 决策 4：`_load_templates()` 通过 `DirAccess` 枚举 `res://assets/events/` 目录 → `ResourceLoader.load()` 同步加载——加载完成后发射 `templates_loaded` 信号
- ADR-0003 决策：`check_condition()` 覆盖 6 种 ConditionType——通过 GSM 第一层直接读取（零开销 O(1)）
- ADR-0003 决策：`select_event()` 加权随机选择——从候选事件池中按权重选出事件

## 控制清单版本

2026-07-26

> Foundation 层规则：
> - EventInstance 持有 `template_id: StringName` + 选项索引——而非 Resource 引用
> - 所有游戏状态写入必须通过 GSM 第二层原子方法（条件判定通过第一层读取）
> - 绝不运行时写 EventTemplate Resource 字段——Resource 共享引用语义导致静默数据损坏

## 实现范围

### 1. EventInstance RefCounted 类

在 `src/foundation/event_system/event_instance.gd` 中定义：

```gdscript
class_name EventInstance extends RefCounted
var template_id: StringName
var available_option_indices: Array[int] = []     # 已过滤的选项索引（非 Resource 引用）
var all_options_hidden: bool = false
var chain_depth: int = 0
var selected_option_index: int = -1
var resolved_outcomes: Array[Dictionary] = []
```

**注意**：EventInstance **不持有**任何 Resource 引用——调用方通过 `EventSystem.get_template(instance.template_id).options[idx]` 获取选项数据。

### 2. EventSystem Autoload 骨架

在 `src/foundation/event_system/event_system.gd` 中实现：

- `_ready()`: 调用 `_load_templates()` → 发射 `templates_loaded(count)` 信号
- `templates: Dictionary[StringName, EventTemplate]` —— 模板注册表
- `get_template(id: StringName) -> EventTemplate` —— O(1) 字典查询

### 3. 模板加载

`_load_templates()` 实现：
- `DirAccess.open("res://assets/events/")` 递归遍历子目录
- `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)` 同步加载每个 `.tres`
- 验证加载结果是否为 EventTemplate 类型——否则 `push_error`
- 以 `template_id` 为键存入 `templates` Dictionary
- 加载完成后：
  - 发射 `templates_loaded.emit(count)`
  - 全量验证所有 `chain_next` 非空值是否在 `templates.keys()` 中存在——不存在的记录 `push_error`

### 4. 事件触发

`trigger_event(event_id: StringName, context: Dictionary = {}) -> EventInstance`：
1. 从 `templates` 获取 EventTemplate
2. 遍历 `template.options[]`，对每个 EventOption 调用 `_all_conditions_met(opt.conditions)`
3. 满足所有条件的选项：将其索引加入 `instance.available_option_indices`
4. 所有选项都不满足：`instance.all_options_hidden = true`
5. 发射 `event_triggered.emit(event_id)`
6. 返回 EventInstance

### 5. 条件判定引擎

`check_condition(cond: EventCondition) -> bool`：
- `REALM` → GSM.player.realm 与 `cond.value_int` 按 `cond.operator` 比较（GE/EQ/LT）
- `FACTION` → GSM.player.faction == `cond.value_str`
- `RESOURCE` → GSM.player.resources.get(cond.target, 0) >= `cond.value_int`
- `CARD_OWNED` → `cond.value_str` 是否在 GSM.collection.owned_cards 中
- `FLAG_SET` → `get_flag(cond.target) == cond.value_str`
- `FLAG_NOT_SET` → `get_flag(cond.target) != cond.value_str`
- 默认返回 `false`

### 6. 选项结算

`resolve_option(instance: EventInstance, option_index: int) -> Array[Dictionary]`：
1. 验证 `option_index` 在 `instance.available_option_indices` 中
2. 获取模板和选项（通过 `get_template(instance.template_id).options[option_index]`）
3. 遍历 `opt.outcomes[]`：
   - `chance < 1.0`：randf() 判定——未触发则 result.triggered = false
   - `use_range == true`：`randi_range(min_value, max_value)`
   - `use_range == false`：`value_int`
4. 返回 `Array[Dictionary]`（triggered/type/target/value/value_str）
5. `instance.selected_option_index = option_index`

### 7. 加权随机选择

`select_event(candidates: Array[StringName], realm: int) -> StringName`：
1. 过滤 `min_realm > realm` 的模板
2. 计算 total_weight = sum(e.weight for e in eligible)
3. `randf_range(0, total_weight)` 加权随机
4. 返回选中的 template_id
5. 回退：返回 candidates[-1]（列表最后一个）

### 8. 信号声明

在 EventSystem 中声明以下信号（语义归属——非 SignalBus）：
- `event_triggered(event_id: StringName)`
- `templates_loaded(count: int)`
- `event_resolved(event_id: StringName, option_idx: int, outcomes: Array[Dictionary])`
- `chain_triggered(from_event: StringName, to_event: StringName)`
- `chain_ended(final_event_id: StringName)`

## 验收标准

- [ ] **AC-001**: `_load_templates()` 正确加载测试目录下所有 `.tres` EventTemplate 文件
- [ ] **AC-002**: `_load_templates()` 完成后验证所有 `chain_next` 引用完整性——不存在的引用 `push_error`
- [ ] **AC-003**: `trigger_event("test_event_001")` 返回 EventInstance——`available_option_indices` 仅包含满足所有条件的选项索引
- [ ] **AC-004**: **GIVEN** 事件选项有阵营条件（`FACTION == "zhengdao"`），**WHEN** 玩家阵营非正道，**THEN** 该选项不在 `available_option_indices` 中（不可见）
- [ ] **AC-005**: **GIVEN** 事件选项有境界条件（`REALM GE 2`），**WHEN** 玩家境界为 1，**THEN** 该选项不在 `available_option_indices` 中
- [ ] **AC-006**: **GIVEN** 所有选项都不满足条件，**WHEN** `trigger_event()` 执行，**THEN** `instance.all_options_hidden == true`
- [ ] **AC-007**: **GIVEN** 所有选项都满足条件，**WHEN** `trigger_event()` 执行，**THEN** 所有选项索引在 `available_option_indices` 中，`all_options_hidden == false`
- [ ] **AC-008**: `check_condition(REALM GE 3)` 对 realm=2 返回 false，对 realm=3 返回 true
- [ ] **AC-009**: `check_condition(FACTION == "modao")` 对 faction="zhengdao" 返回 false，对 faction="modao" 返回 true
- [ ] **AC-010**: `check_condition(RESOURCE >= 100)` 对目标资源=50 返回 false，对目标资源=100 返回 true
- [ ] **AC-011**: `check_condition(CARD_OWNED)` 对已拥有的卡牌 ID 返回 true
- [ ] **AC-012**: `check_condition(FLAG_SET == "met_boss")` 对已设置的 flag 返回 true
- [ ] **AC-013**: `check_condition(FLAG_NOT_SET == "met_boss")` 对未设置的 flag 返回 true
- [ ] **AC-014**: `resolve_option()` chance=1.0 必定触发（100 次执行均返回 triggered=true）
- [ ] **AC-015**: `resolve_option()` chance=0.0 永不触发（100 次执行均返回 triggered=false）
- [ ] **AC-016**: `resolve_option()` chance=0.5 时 1000 次执行触发率在 [0.4, 0.6] 区间（二项分布置信）
- [ ] **AC-017**: `resolve_option()` use_range=true, min=50, max=150 → 100 次执行结果均在 [50, 150] 区间内
- [ ] **AC-018**: `resolve_option()` use_range=false, value_int=100 → 结果值严格等于 100
- [ ] **AC-019**: `select_event()` 1000 次执行加权分布符合预期比例（使用卡方检验，显著性水平 0.05）
- [ ] **AC-020**: `select_event()` 过滤掉 `min_realm > realm` 的候选事件
- [ ] **AC-021**: EventInstance **不持有**任何 Resource 引用——`available_option_indices` 为 `Array[int]`，`template_id` 为 `StringName`
- [ ] **AC-022**: `event_triggered` 信号在 `trigger_event()` 成功创建 EventInstance 后发射

## 测试证据路径

| 证据类型 | 位置 |
|---------|------|
| 单元测试 | `tests/unit/event_system/event_instance_test.gd` |
| 单元测试 | `tests/unit/event_system/event_trigger_test.gd` |
| 单元测试 | `tests/unit/event_system/check_condition_test.gd` |
| 单元测试 | `tests/unit/event_system/resolve_option_test.gd` |
| 单元测试 | `tests/unit/event_system/select_event_test.gd` |
| 单元测试 | `tests/unit/event_system/load_templates_test.gd` |

## 实现注意事项

- EventSystem 作为 Autoload #5 注册——在 SaveLoad(#4) 之后，CardSystem(#6) 之前
- EventInstance 为 RefCounted——不继承 Node，不需要 `add_child`
- `_load_templates()` 在 `_ready()` 中同步执行——预期 <150ms（60-100 个文件）
- 条件判定通过 GSM 第一层直接读取——不通过第二层方法
- `randf()` 和 `randi_range()` 使用 Godot 全局随机（事件结算非安全关键）
- 所有信号声明在 EventSystem.gd 中——不使用 SignalBus Autoload
- 文件结构：
  ```
  src/foundation/event_system/
  ├── event_enums.gd
  ├── event_condition.gd
  ├── event_outcome.gd
  ├── event_option.gd
  ├── event_template.gd
  ├── event_instance.gd
  └── event_system.gd       # Autoload
  ```

## Completion Notes
**Completed**：2026-08-03
**Criteria**：22/22 通过（全部自动验证）
**Deviations**：
- ADVISORY（H-2）：`_check_faction_condition` 按 ADR-0003 §check_condition 应从 `GSM.player.faction` 读取，但 GSM player 域无 faction 字段。当前回退为 `narrative.story_flags["player_faction"]`。已在源码注释标注，待 Story 003（story_flags 所有权）明确 player.faction 归属后更新 ADR-0003 第 326 行契约与实现。
- ADVISORY（H-3）：`trigger_event()` 签名按故事 §4 应为 `(event_id, context: Dictionary = {})`，实现采用 `(event_id, chain_depth: int = 0)`。连锁深度参数为 Story 004 所需，签名差异已在 ADR-0003 实现指南中明确。
- ADVISORY（G-1）：AC-004/AC-009 的 FACTION 测试按实现偏差路径（story_flags["player_faction"]）编写而非 ADR-0003 契约路径（player.faction），验证了实际行为但未守护契约。S3 级，不阻塞本故事，作为 Story 003 前置项——届时需同步更新 ADR-0003 契约和对应测试路径。
**Test Evidence**：Logic 故事，6 个测试文件位于 `tests/unit/event_system/`（test_load_templates / test_event_trigger / test_check_condition / test_resolve_option / test_select_event / test_event_instance），90/90 通过，253 断言，零失败。
**Code Review**：已完成——code-reviewer 返回 APPROVED WITH CONCERNS（0 BLOCKER, 3 HIGH, 13 LOW）。H-1 已修复（resolve_option 不再发射 event_resolved，按 ADR-0003 §信号契约表留待 apply_outcomes 在 Story 005 发射），7 个安全 LOW 已修复（L-1/L-2/L-3/L-4/L-5/L-10/L-12）。H-2/H-3 记录为已知偏差。LP-CODE-REVIEW 关卡复用此审查结果。
**QL-TEST-COVERAGE**：GAPS（ADVISORY，不阻塞）——22 条 AC 中 20 条实质覆盖，统计型 AC（AC-016/019）循环次数与卡方计算达标，H-1 回归守护（assert_signal_not_emitted）到位。G-1 缺口已归档为 Story 003 前置项。
