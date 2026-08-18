# Story 001: BindingRecord RefCounted 实例模型 + 内部注册表

> **Epic**: 功法/法宝绑定系统 (Binding System)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-18

## Completion Notes
**Completed**：2026-08-18
**Criteria**：8/8 通过（AC-001~008 由 19 个单元测试覆盖）
**Deviations**：
1. **文件位置修正**（story 实现注过时）：story Implementation Note #1 写 `src/core/binding/`，实际落地 `src/feature/binding/`。原因：ADR-0013 明确 BindingManager 是 **Feature 层** Autoload #13，且现有 Feature 层代码在 `src/feature/`（card_effect_engine/、deployment_system.gd）。ADR 权威，story 路径为过时错误——无需回写 ADR。
2. **`_by_character` 声明为无类型 `Dictionary`**：ADR-0013 §需求 字面类型 `Dictionary[int, Array[int]]` 是嵌套类型化集合，Godot 4.6 GDScript 不支持（"Nested typed collections are not supported" 解析错误）。值仍为 `Array[int]`，类型保证由 `_register_binding` 构造路径维护。已回写 ADR-0013 §需求 一行 retrofit 注。
3. **`get_binding` assert 守卫重构（lead-programmer C1）**：原实现 `var record: BindingRecord = _bindings[binding_id]` 的类型化赋值本身在运行时做类型校验，使后续 assert 对"非 null 非法注入"成为死代码。改为 `Variant` 读入 → null 检查 → assert → cast，使 assert 成为类型化赋值之前的第一道运行时守卫。注意：`_bindings` 为类型化 Dictionary，非 null 非法类型在写入侧即被拦截，唯一可存入的非法值是 null（提前返回）——故 assert 对非法注入运行时不可达，实为纵深防御层（覆盖未来 deserialize 非类型化写入路径）。
4. **`_unregister_binding` 反查真实 character_id（lead-programmer C4）**：优先从 `_card_to_character`（权威映射）反查 character_id，而非信任 `record.bound_character_id` 快照——调用方若在 register 后修改 record 字段，信任快照会导致 `_by_character` 擦除静默 no-op、留下孤儿条目。缺失时回退到 record 快照。
**Test Evidence**：`tests/unit/binding_system/test_binding_record_model.gd`（19 测试全通过）；全量套件 72 scripts / 1330 tests / 1329 passing / 1 pending / 0 failing 零回归
**Code Review**：lead-programmer CONCERNS→已采纳（C1 assert 死代码 + C2 内部引用只读文档 + C3 _by_character 无类型 ADR 回写 + C4 反查 character_id + C5 孤儿跳过注释）；qa-lead GAPS→已补齐（G1 AC-005 语义 + G2 删最后一条清键 + G3 unregister 幂等 + G4 未绑定路径新分配语义 + G5 测试命名 system 前缀）

## Context

**GDD**: `design/gdd/binding-system.md`
**Requirement**: `TR-binding-001`
*(需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版)*

**ADR Governing Implementation**: ADR-0013（绑定系统 — BindingManager Autoload + RefCounted BindingRecord 实例模型 + 效果引擎集成）
**ADR Decision Summary**: BindingRecord 使用 RefCounted（非 Resource、非 Dictionary），对齐 ADR-0002/0009/0011 的 Template/Instance 模式。运行时实例存于 BindingManager 内部三个同步索引（`_bindings` + `_by_character` + `_card_to_character`），非 GSM。战斗热路径 O(1) 查询，战斗结束 `serialize_all()` 导出快照。

**Engine**: Godot 4.6 | **Risk**: LOW（Dictionary 操作、RefCounted 实例管理均为 4.x 成熟 API）
**Engine Notes**: 不依赖 4.4+ 新特性。`Dictionary[int, BindingRecord]` 键类型提示在 GDScript 中非编译器强制——需 `assert(_bindings[id] is BindingRecord)` 运行时守卫。

**Control Manifest Rules (Feature 层)**:
- Required: BindingRecord (RefCounted) —— 非 Resource，非 Dictionary（来源: ADR-0013）
- Required: BindingManager 持有三个同步索引：`_bindings`、`_by_character`、`_card_to_character`（来源: ADR-0013）
- Forbidden: 绝不将绑定运行时实例存储在 GSM 中——仅内部 Dictionary（来源: ADR-0013，对齐 ADR-0011）
- Guardrail: `get_binding_ids_by_character()` 零分配（CombatUI 每帧调用）；`get_bindings_by_character()` 每次分配新数组（非热路径）

---

## Acceptance Criteria

*From GDD `design/gdd/binding-system.md` §详细设计 §1 数据结构 + ADR-0013 §需求/§验证标准:*

- [ ] **AC-001**: BindingRecord 为 RefCounted 子类（非 Resource、非 Dictionary）——与 ADR-0002 CardInstance / ADR-0009 EffectInstance / ADR-0011 StatusInstance 的 Template/Instance 模式一致
- [ ] **AC-002**: BindingRecord 含全部字段：`binding_id: int`、`card_instance_id: int`、`card_template_id: StringName`、`card_name: String`、`card_rarity`、`slot_type: BindingSlot`、`slot_index: int`、`bound_character_id: int`、`is_native: bool`、`native_multiplier: float`、`activated_turn: int`、`is_suspended: bool`、`stack_slots: Array[int]`、`stack_count: int`
- [ ] **AC-003**: BindingManager 内部三个同步索引：`_bindings: Dictionary[int, BindingRecord]` + `_by_character: Dictionary[int, Array[int]]` + `_card_to_character: Dictionary[int, int]`
- [ ] **AC-004**: 绑定变更集中在 `_register_binding()` / `_unregister_binding()` 两个私有方法中——同时原子更新三个索引；任一索引遗漏更新即视为失败
- [ ] **AC-005**: `_bindings[id]` 访问处附加 `assert(_bindings[id] is BindingRecord)` 运行时守卫（键类型提示非编译器强制）
- [ ] **AC-006**: `get_binding_ids_by_character(character_id) → Array[int]` 零分配查询（O(1) Dictionary 键查找 + 返回已有 Array[int]，不构造新数组）
- [ ] **AC-007**: `get_bindings_by_character(character_id) → Array[BindingRecord]` 每次调用分配新数组——文档标注"非热路径，CombatUI 不应每帧调用"
- [ ] **AC-008**: `get_character_by_card(card_instance_id) → int` O(1) 反向查询（`_card_to_character` Dictionary 键查找）

---

## Implementation Notes

*Derived from ADR-0013 §对象模型 / §关键接口 / §需求:*

1. **文件位置**: `src/core/binding/binding_record.gd`（BindingRecord RefCounted 类，声明 `class_name BindingRecord`）+ `src/core/binding/binding_manager.gd`（BindingManager Autoload #13，`extends Node`，不声明 `class_name`——Autoload 固有权衡）
2. **BindingRecord**: `extends RefCounted` + `class_name BindingRecord`。轻量级 ~15 字段，无 Resource 引用——引用计数开销小（化神期峰值 ~180 实例 × ~200 bytes ≈ 36KB）
3. **三个索引结构**（战斗期间——不通过 GSM 存储）:
   - `_bindings: Dictionary[int, BindingRecord]` —— key=binding_id
   - `_by_character: Dictionary[int, Array[int]]` —— key=character_id → binding_id 列表
   - `_card_to_character: Dictionary[int, int]` —— key=card_instance_id → character_id
4. **`_register_binding(record: BindingRecord) -> void`**: 同时写入 `_bindings[record.binding_id]` + `_by_character[record.bound_character_id].append(record.binding_id)` + `_card_to_character[record.card_instance_id] = record.bound_character_id`
5. **`_unregister_binding(record: BindingRecord) -> void`**: 从三个索引同步移除；`_by_character` 数组移除后若为空则删除该 character_id 键
6. **零分配热路径**: `get_binding_ids_by_character()` 返回 `_by_character` 中已有的 `Array[int]` 引用（不 duplicate）；`get_bindings_by_character()` 遍历 binding_id 构造新 `Array[BindingRecord]`（非热路径）
7. **BindingSlot 枚举**: `enum BindingSlot { GONGFA, FABAO }`（功法/法宝）——在 BindingRecord 或 BindingManager 中定义
8. **`get_binding(binding_id: int) → BindingRecord`**: O(1) Dictionary 查找，供 CombatUI 按需逐条获取详情
9. **测试模式**: BindingRecord 直接 `BindingRecord.new()` 构造；BindingManager 用动态分派 `BM_SCRIPT.new()` + `var bm: Node`（Autoload 不声明 class_name，同 CostSystem/RealmSystem 模式）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: bind / stack / overwrite / remove 的完整业务逻辑（本命判定、叠加判定、覆盖流程、阵亡洗回）
- **Story 003**: 7 个 Cat 2b 生命周期信号 + `_emit_signal_safe` 路由
- **Story 004**: `serialize_all()` / `deserialize_all()` 快照导出 + CardEffectEngine persistent effect 接口调用
- **CardEffectEngine 集成**: 绑定成功/覆盖/阵亡时的效果注册/移除——Story 004 职责
- **CombatUI 消费**: 订阅信号更新绑定图标/本命标记/层数徽章——Presentation 层职责

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-001**: BindingRecord 类型为 RefCounted
  - Given: `binding_record.gd` 已加载
  - When: `var r = BindingRecord.new()` 并检查 `r is RefCounted` / `r is Resource` / `r is Dictionary`
  - Then: `r is RefCounted == true` + `r is Resource == false` + `r is Dictionary == false`
  - Edge cases: 不得继承 Resource；不得以 Dictionary 表示

- **AC-002**: BindingRecord 字段完整
  - Given: `var r = BindingRecord.new()`
  - When: 逐字段赋值并读取全部 14 个字段
  - Then: 每个字段类型匹配声明（binding_id/card_instance_id/slot_index/bound_character_id/activated_turn/stack_count 为 int；native_multiplier 为 float；is_native/is_suspended 为 bool；stack_slots 为 Array[int]；slot_type 为 BindingSlot）
  - Edge cases: `stack_slots[0]` 为自身 card_instance_id；`stack_count >= 1`

- **AC-003**: 三个索引结构存在
  - Given: BindingManager 实例已创建
  - When: 检查 `_bindings` / `_by_character` / `_card_to_character` 三个 Dictionary
  - Then: 三个 Dictionary 均存在且初始为空
  - Edge cases: 战斗开始时索引为空（battle_start 时从 RealmSystem 缓存槽位，但索引本身无预置条目）

- **AC-004**: 三索引原子同步
  - Given: BindingManager 实例 + 一个 BindingRecord
  - When: 调用 `_register_binding(record)` 后检查三索引；再调用 `_unregister_binding(record)` 后检查
  - Then: register 后 `_bindings[id]` 存在 + `_by_character[char_id]` 含 binding_id + `_card_to_character[card_id] == char_id`；unregister 后三索引全部移除该条目
  - Edge cases: 连续 register 3 条后 `_by_character[char_id].size() == 3`；unregister 最后一条后 `_by_character` 删除该 character_id 键

- **AC-005**: assert 守卫
  - Given: BindingManager + `_bindings[id]` 赋值为非 BindingRecord（非法注入）
  - When: 通过 `get_binding(id)` 访问
  - Then: `assert(_bindings[id] is BindingRecord)` 触发（debug 构建下断言失败）
  - Edge cases: 正常 BindingRecord 值通过断言不触发

- **AC-006**: 零分配热路径查询
  - Given: BindingManager + 角色 char_id 已注册 3 条绑定
  - When: `var ids: Array[int] = bm.get_binding_ids_by_character(char_id)` 两次调用
  - Then: 返回的 Array[int] 含 3 个 binding_id，且两次返回同一引用（`is_same` 语义——不构造新数组）
  - Edge cases: 未绑定角色返回空 Array[int]（或 null——实现需明确其一）

- **AC-007**: 非热路径分配查询
  - Given: BindingManager + 角色 char_id 已注册 3 条绑定
  - When: `bm.get_bindings_by_character(char_id)`
  - Then: 返回 `Array[BindingRecord]`，size==3，元素均为 BindingRecord 类型
  - Edge cases: 每次调用返回新数组实例（不共享可变状态）

- **AC-008**: O(1) 反向查询
  - Given: 已 register 绑定（card_instance_id → character_id）
  - When: `bm.get_character_by_card(card_instance_id)`
  - Then: 返回正确 character_id
  - Edge cases: 未绑定 card_instance_id 返回无效值（-1 或 0，实现需明确约定）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/binding_system/test_binding_record_model.gd` — must exist and pass
**Status**: [x] Created and passing (19 tests)

---

## Dependencies

- Depends on: 无（BindingRecord 为独立 RefCounted 类；BindingManager 骨架仅依赖自身内部 Dictionary 结构）
- Unlocks: Story 002（bind/unbind/query API——依赖 001 的三索引结构和 `_register_binding`/`_unregister_binding`）；Story 003（信号总线）；Story 004（序列化快照）
