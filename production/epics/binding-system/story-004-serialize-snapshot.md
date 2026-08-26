# Story 004: serialize_all 快照导出 + persistent effect 接口

> **Epic**: 功法/法宝绑定系统 (Binding System)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-22

## Context

**GDD**: `design/gdd/binding-system.md`
**Requirement**: `TR-binding-002`
*(需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版)*

**ADR Governing Implementation**: ADR-0013（绑定系统 — BindingManager Autoload + RefCounted BindingRecord 实例模型 + 效果引擎集成）
**ADR Decision Summary**: 战斗期间绑定数据由 BindingManager 内部注册表管理（非 GSM）；战斗结束 `serialize_all()` 导出快照至 `GSM.battle.bindings`，`deserialize_all()` 从快照恢复（读档/战斗快照恢复）。绑定生命周期各节点调用 CardEffectEngine 的 persistent effect 接口（register/remove/suspend/restore）。

**Engine**: Godot 4.6 | **Risk**: LOW（Dictionary 序列化 + 接口调用——4.0+ 稳定 API）
**Engine Notes**: `serialize_all()` 在 battle_end 时的性能（序列化全部 BindingRecord → Dictionary）需验证；`deserialize_all()` 采用"尽力而为"策略——逐条验证 card_instance_id，失败跳过 + WARN 日志。

**Control Manifest Rules (Feature 层)**:
- Required: 战斗中绑定数据由 BindingManager 内部管理——仅战斗结束导出快照至 GSM（来源: ADR-0013，对齐 ADR-0011 例外模式）
- Required: 角色阵亡 → 所有绑定卡洗回牌库——非永久丢失（来源: ADR-0013）
- Forbidden: 绝不将绑定运行时实例存储在 GSM 中（来源: ADR-0013）

---

## Acceptance Criteria

*From GDD `design/gdd/binding-system.md` §与其他系统的交互 + ADR-0013 §关键接口 CardEffectEngine 集成点 / §GSM 边界 / §验证标准 / §风险:*

- [x] **AC-001**: `serialize_all() → Dictionary` 序列化全部活跃绑定记录（含 binding_id/card_instance_id/slot_type/is_native/native_multiplier/stack_slots/stack_count/is_suspended 等全部字段）
- [x] **AC-002**: `serialize_all()` 导出快照至 `GSM.battle.bindings`——用于存档/战斗快照持久化（战斗期间不写入 GSM，仅战斗结束时导出）
- [x] **AC-003**: `deserialize_all(data: Dictionary)` 从快照恢复 BindingRecord——逐条验证 card_instance_id 是否仍存在于 CardSystem
- [x] **AC-004**: `deserialize_all` 部分恢复策略——验证失败的 card_instance_id 跳过 + WARN 日志，其余正常恢复（"尽力而为"，不阻塞整体恢复）
- [x] **AC-005**: 绑定成功时调用 `CardEffectEngine.register_persistent_effect(card_instance_id, template_id, character_id, context: BindingContext)`——BindingContext 含 native_multiplier 和 stack_count
- [x] **AC-006**: 覆盖旧卡时 `remove_effects_by_source(old_card_instance_id)` 先于 `register_persistent_effect(new_card_instance_id, ...)`——严格顺序、无重叠帧
- [x] **AC-007**: 角色离场时 `suspend_effects_by_source(all_binding_card_ids)`；角色上场时 `restore_effects_by_source(valid_binding_card_ids)`（仅恢复验证通过的绑定卡）
- [x] **AC-008**: 角色阵亡时 `remove_effects_by_source(all_binding_card_ids)`（含所有叠层实例）
- [x] **AC-009**: `get_binding_context(card_instance_id)` 提供预计算的 multiplier 乘积（`native_multiplier × stack_multiplier^(stack_count-1)`）——CardEffectEngine 结算时查询，不在引擎中重复计算
- [x] **AC-010**: 同名叠加非数值效果按类型分支处理（二元/概率触发/持续回合/条件触发/抽牌资源生成）——由效果引擎在运行时按效果类型分支（本 Story 提供 stack_count 上下文）
- [x] **AC-011**: 覆盖时旧卡已积累的数值加成（`Character.accumulated_bonuses`）保留在角色上——仅持续触发效果停止（不通过 remove_effects_by_source 清除累积值）
- [x] **AC-012**: `serialize_all()` × N 次调用性能可接受（化神期峰值 ~180 BindingRecord）；`get_accumulated_bonus()` × 1000 次 <10ms

---

## Implementation Notes

*Derived from ADR-0013 §关键接口 CardEffectEngine 集成点 / §GSM 边界 / §风险 / §验证标准:*

1. **文件位置**: `src/core/binding/binding_manager.gd`（在 Story 001/002/003 的 BindingManager 中实现 serialize/deserialize + 效果引擎集成）
2. **`serialize_all() → Dictionary`**: 遍历 `_bindings` 全部 BindingRecord → 序列化为 Dictionary 列表（含全部字段）。写入 `GSM.battle.bindings`（第二层写委托——本 Story 需确认 GSM battle.bindings 域写入方法，同 CostSystem `_set_battle_cost` 模式）
3. **`deserialize_all(data: Dictionary) → void`**: 逐条读取 Dictionary → 验证 `card_instance_id` 在 CardSystem 中仍存在（`CardSystem.get_instance(card_instance_id)` 或等价查询）→ 验证通过则重建 BindingRecord + 三索引注册；验证失败则跳过 + `push_warning`（WARN 日志）
4. **GSM 边界**: 战斗期间 BindingManager 内部注册表管理——不写 GSM；战斗结束 `serialize_all()` 导出快照。GSM 只读访问 `player.realm_level`（第一层只读，不调用第二层写入）
5. **CardEffectEngine 集成点**（调用方向 BindingManager → CardEffectEngine）:
   - 绑定成功 → `register_persistent_effect(card_instance_id, template_id, character_id, context)`
   - 覆盖旧卡 → `remove_effects_by_source(old_card_instance_id)`（先）→ `register_persistent_effect(new_card_instance_id, ...)`（后）
   - 离场 → `suspend_effects_by_source(all_binding_card_ids)`
   - 上场 → `restore_effects_by_source(valid_binding_card_ids)`
   - 阵亡 → `remove_effects_by_source(all_binding_card_ids)`（含所有叠层）
6. **BindingContext**: 含 `native_multiplier: float` + `stack_count: int`——由 BindingManager 在绑定/叠加时构造，供 CardEffectEngine 结算时读取
7. **`get_binding_context(card_instance_id)`**: 返回预计算 multiplier 乘积 = `native_multiplier × stack_multiplier^(stack_count-1)`——CardEffectEngine 查询此值，不在引擎中重复计算乘法公式
8. **积累数值保留**: `Character.accumulated_bonuses` 归属于 Character（非 BindingRecord）——覆盖时旧卡积累数值保留在角色上，`remove_effects_by_source` 仅停止持续触发效果、不清除角色累积值
9. **暂挂/恢复排序契约**: 角色离场/上场时先 BindingManager、后 StatusEffectSystem——绑定效果可能依赖状态修正值（CombatSystem 编排，本 Story 仅实现 BindingManager 侧接口调用）
10. **测试模式**: 动态分派 + mock CardEffectEngine（记录 register/remove/suspend/restore 调用序列）+ mock GSM（验证 battle.bindings 写入）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: BindingRecord 类定义 + 三索引注册表
- **Story 002**: bind/stack/overwrite/remove/suspend/restore 业务逻辑（本 Story 在各节点挂接 CardEffectEngine 调用 + 序列化）
- **Story 003**: 7 个 Cat 2b 信号发射
- **CardEffectEngine 内部实现**: `register_persistent_effect`/`remove_effects_by_source`/`suspend_effects_by_source`/`restore_effects_by_source` 的效果实例管理——卡牌效果 Epic（ADR-0009）职责
- **非数值叠加效果分支**: 效果引擎运行时按效果类型分支处理叠加行为——效果引擎职责（本 Story 仅提供 stack_count 上下文）
- **CombatSystem 编排**: battle_end 时调用 `serialize_all()`、battle_start 时调用 `deserialize_all()` 的时序——战斗 Epic（ADR-0008）职责
- **GSM battle.bindings 第二层写入方法**: 若 GSM 尚缺该域写入方法，需协调 GSM 层实现（本 Story 用 has_method 守卫或桩）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-001**: serialize_all 完整序列化
  - Given: BindingManager 有 3 条绑定记录（含 1 条叠加 stack_count=2、1 条本命 is_native=true、1 条 is_suspended=true）
  - When: `var data = bm.serialize_all()`
  - Then: 返回 Dictionary 含 3 条记录，每条含全部字段（binding_id/card_instance_id/slot_type/is_native/native_multiplier/stack_slots/stack_count/is_suspended）
  - Edge cases: stack_slots 数组完整序列化（含所有叠层实例）

- **AC-002**: serialize_all 导出到 GSM.battle.bindings
  - Given: GSM 可用 + BindingManager 有绑定记录
  - When: 战斗结束触发 `bm.serialize_all()`
  - Then: `GSM.battle.bindings` 含序列化快照
  - Edge cases: 战斗期间 `GSM.battle.bindings` 不被写入（仅战斗结束）

- **AC-003**: deserialize_all 恢复
  - Given: 一份合法快照 Dictionary + CardSystem 中存在对应 card_instance_id
  - When: `bm.deserialize_all(data)`
  - Then: 三索引重建 + `get_bindings_by_character()` 返回正确记录
  - Edge cases: 快照为空 → 三索引为空，不报错

- **AC-004**: deserialize_all 部分恢复
  - Given: 快照含 3 条记录，其中 1 条 card_instance_id 在 CardSystem 中已不存在
  - When: `bm.deserialize_all(data)`
  - Then: 2 条恢复 + 1 条跳过 + WARN 日志（push_warning）
  - Edge cases: 跳过的记录不阻塞整体恢复

- **AC-005**: register_persistent_effect 绑定成功调用
  - Given: mock CardEffectEngine 记录调用 + 执行 bind_card 成功
  - When: 检查 mock 调用序列
  - Then: `register_persistent_effect(card_instance_id, template_id, character_id, context)` 被调用，context 含 native_multiplier 和 stack_count
  - Edge cases: 非本命绑定 context.native_multiplier=1.0；本命绑定 context.native_multiplier=1.5

- **AC-006**: 覆盖严格顺序
  - Given: mock CardEffectEngine 记录调用序列 + 执行 overwrite_binding
  - When: 检查 mock 调用序列
  - Then: `remove_effects_by_source(old)` 先于 `register_persistent_effect(new)` 调用，无重叠帧
  - Edge cases: 序列断言 remove 索引 < register 索引

- **AC-007**: suspend/restore 效果调用
  - Given: mock CardEffectEngine + 角色有绑定
  - When: `bm.suspend_bindings(char_id)` 后 `bm.restore_bindings(char_id)`
  - Then: suspend 时 `suspend_effects_by_source(all_ids)` 被调用；restore 时 `restore_effects_by_source(valid_ids)` 被调用（仅验证通过的 id）
  - Edge cases: restore 验证失败（card 已不存在）→ valid_ids 不含该 id

- **AC-008**: 阵亡 remove_effects_by_source
  - Given: mock CardEffectEngine + 角色有 3 张绑定卡（含叠层）
  - When: 触发阵亡 `remove_all_bindings(char_id)`
  - Then: `remove_effects_by_source(all_binding_card_ids)` 被调用（含所有叠层实例）
  - Edge cases: 叠层 stack_slots 中所有实例 id 均传给 remove_effects_by_source

- **AC-009**: get_binding_context 预计算乘积
  - Given: 本命绑定 stack_count=2, stack_multiplier=1.5, native_multiplier=1.5
  - When: `bm.get_binding_context(card_instance_id)`
  - Then: 返回 multiplier 乘积 = 1.5 × 1.5^1 = 2.25（native × stack^(count-1)）
  - Edge cases: stack_count=1 时乘积 = native × 1.0；向下取整语义由消费方处理

- **AC-010**: 非数值叠加上下文
  - Given: 叠加绑定 stack_count=3
  - When: CardEffectEngine 查询 `get_binding_context(card_instance_id)`
  - Then: 返回 stack_count=3 上下文，供效果引擎按类型分支处理（二元/概率/持续回合/条件触发/抽牌）
  - Edge cases: 无 base_value 的效果叠加由引擎分支——本 Story 仅提供 stack_count，不实现分支逻辑

- **AC-011**: 覆盖积累数值保留
  - Given: 旧卡有积累数值（Character.accumulated_bonuses["atk"]=5）+ 执行覆盖
  - When: 检查覆盖后 Character.accumulated_bonuses
  - Then: `accumulated_bonuses["atk"]==5` 保留（remove_effects_by_source 不清除累积值）+ 旧卡持续触发效果停止
  - Edge cases: 新卡自动继承角色累积值（无需"转移"操作）

- **AC-012**: serialize_all 性能
  - Given: 化神期峰值 ~180 BindingRecord
  - When: `bm.serialize_all()` 执行
  - Then: 无显著帧卡顿（battle_end 非热路径，一次性执行）
  - Edge cases: `get_accumulated_bonus()` × 1000 次 <10ms（ADR-0013 性能护栏）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/binding_system/test_serialize_snapshot_effect_integration.gd` — must exist and pass
**Status**: [x] Created — 20 tests, all passing (AC-001~AC-012 全覆盖)

---

## Dependencies

- Depends on: Story 002（完整绑定生命周期——serialize/deserialize 依赖 BindingRecord 实例；效果引擎集成在各生命周期节点挂钩）
- Unlocks: 战斗 Epic（CombatSystem 在 battle_start/battle_end 编排 serialize/deserialize）；卡牌效果 Epic（CardEffectEngine 消费 get_binding_context）
