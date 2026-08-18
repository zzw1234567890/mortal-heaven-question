# Story 002: bind / unbind / get_bindings 查询 API

> **Epic**: 功法/法宝绑定系统 (Binding System)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-18

## Completion Notes
**Completed**：2026-08-18
**Criteria**：18/18 通过（AC-001~018 由 37 个单元测试覆盖）
**Deviations**：
1. **槽位数据扩展 RealmSystem（而非 BindingManager 内部维护）**：AC-004 要求查询 RealmSystem，原 RealmSystem 缺 `gongfa_slots`/`fabao_slots` 两键。扩展 realm_table 10→12 键（炼气1/1、筑基2/2、金丹2/2、元婴3/3、化神3/3），回写 realm-system GDD 属性表 + ADR-0010 上下文 + smoke test 10→12 keys。用户裁决确认。
2. **本命判定 / 效果引擎 / 牌库集成走注入 + 存根**：无 Character 系统、CardEffectEngine 接口未落地、CardSystem 弃牌堆未建。采用可注入 Callable 存根（effect_register/remove/suspend/restore + card_shuffle/discard/exists + stat_bonus），本命判定经 `bind_card` 注入 `native_owner`/`character_card_id` 参数（同 is_game_over roster 先例）。用户裁决确认。
**Lead-Programmer CONCERNS（已处理）**：
- C1（已修复）：`stack_card`/`overwrite_binding` 缺 `card_already_bound` 守卫——已绑定卡可静默重映射致三索引失同步。已在两方法首行加 `_card_to_character.has()` 守卫，reason 补 `card_already_bound`。
- C2（已修复）：`_native_matches` 用 `contains` 子串匹配与 ADR-0013"前缀匹配"漂移 + 误匹配风险（native_owner="lin_yu" 或 "yuan" 误配）。改为下划线分段锚定（`"_" + owner + "_"` in `"_" + card_id + "_"`），消除子串误匹配，与 card_id `{type}_{name}_{variant}` 命名对齐。
- C3（延后 Story 004，已注释）：叠加层效果注册语义不对称（`stack_card` 不逐层注册，`overwrite` 却逐层 `effect_remove_cb`）。CardEffectEngine 接口落地后统一"每绑定持 context（stack_count 动态读取）"或"逐层注册"二选一。已在 `overwrite_binding` 叠层分支加注释。
- C4（延后 Story 004，已注释）：`restore_bindings` 仅验证主实例，叠层实例逐张校验延后至 `card_exists_cb` 接 CardSystem 收藏池后。
- C5（已修复）：`_find_free_slot_index` 返回 `limit` 静默哨兵 → 改 `push_error` + 返回 -1。
- C6（延后 Story 004，已注释）：`card_name`/`card_rarity` 未填充（无模板查询）+ `invalid_character` reason 未返回（无 Character 系统）——战斗 Epic 接入后由调用方前置校验。
**QA-Lead GAPS（已补齐）**：
- G1：AC-006 主 Then（同名叠加沿用首次 is_native/native_multiplier）补 `test_native_stack_preserves_native_flag`。
- G2：AC-011 覆盖叠加回调序列补 `assert_eq(_effect_log, ["remove:102", "discard:102"])`。
- G3：AC-011 剩余层重算 + AC-009 高倍率边界补 `test_effective_value_high_multiplier_240`（240）。
- G4：AC-013 `remove_binding` 多层叠层映射清理补 `test_remove_binding_clears_all_stack_mappings`。
- G5：ADR-0013 §本命判定第 4 点（覆盖本命卡后新卡重占本命位）补 `test_overwrite_native_reclaims_native_slot`。
- G6（采纳）：`test_native_detection_truncated_name_no_match` 补分段锚定回归（C2 同源）。
**Test Evidence**：`tests/unit/binding_system/test_bind_unbind_query_api.gd`（37 测试全通过）+ `test_binding_record_model.gd`（19 测试，全量 56）；全量套件 73 scripts / 1368 tests / 1367 passing / 1 pending / 0 failing 零回归
**Code Review**：lead-programmer CONCERNS→已处理（C1/C2/C5 修复 + C3/C4/C6 延后记录）；qa-lead GAPS→已补齐（G1-G5 + 命名）

## Context

**GDD**: `design/gdd/binding-system.md`
**Requirement**: `TR-binding-002`
*(需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版)*

**ADR Governing Implementation**: ADR-0013（绑定系统 — BindingManager Autoload + RefCounted BindingRecord 实例模型 + 效果引擎集成）
**ADR Decision Summary**: 绑定生命周期（bind/stack/overwrite/remove/suspend/restore）由 BindingManager 内部管理。本命绑定通过 `native_owner` 前缀匹配自动判定，角色生命周期内不可逆。同名叠加共享槽位、`stack_count` 递增、乘法叠加公式。绑定位上限由 `RealmSystem.get_realm_property(level, "gongfa_slots"/"fabao_slots")` 提供，战斗开始缓存。

**Engine**: Godot 4.6 | **Risk**: LOW（Dictionary 键查找、整数/浮点运算——4.0+ 稳定 API）
**Engine Notes**: 不依赖 4.4+ 新特性。`bind_card()` 单次 <0.5ms（含本命判定+槽位分配+效果注册）；`can_bind()` <0.05ms。

**Control Manifest Rules (Feature 层)**:
- Required: 本命绑定通过 `native_owner` 前缀匹配自动判定——角色生命周期内不可逆（来源: ADR-0013）
- Required: 同名叠加：共享槽位、`stack_count` 递增、乘法叠加公式（来源: ADR-0013）
- Forbidden: 绝不硬编码绑定位数量——查询 `RealmSystem.get_realm_property()`（来源: ADR-0013）
- Guardrail: `bind_card()` 单次 <0.5ms（来源: ADR-0013）

---

## Acceptance Criteria

*From GDD `design/gdd/binding-system.md` §详细设计 §2/§3/§8/§10 + §公式 + §边缘情况 + ADR-0013 §验证标准:*

- [ ] **AC-001**: `bind_card(card_instance_id, template_id, character_id, slot_type)` 绑定到空位——返回 `{success: true, binding_id, reason: "bound"}`，创建 BindingRecord(stack_count=1)
- [ ] **AC-002**: `bind_card` 无空位时返回 `{success: false, reason: "slot_full"}`（不触发覆盖——覆盖走 `overwrite_binding`）
- [ ] **AC-003**: `can_bind(character_id, slot_type, template_id)` 预检查覆盖全部 4 种着色状态：灰遮罩（已满+叠加满+无空位）/ 绿叠加（同名未达上限）/ 橙覆盖（无空位但可覆盖）/ 蓝空位（有空位）
- [ ] **AC-004**: 绑定位上限通过 `RealmSystem.get_realm_property(level, "gongfa_slots"/"fabao_slots")` 查询——战斗开始缓存，绝不硬编码
- [ ] **AC-005**: 本命判定——`native_owner` 前缀匹配角色 card_id + 同类型本命位未占用 → `is_native=true, native_multiplier=1.5`；不匹配或本命位已满 → `is_native=false, native_multiplier=1.0`
- [ ] **AC-006**: 本命绑定一旦确认不可变更（角色生命周期内）——同名叠加不重新判定，沿用首次绑定的 `is_native` 和 `native_multiplier`
- [ ] **AC-007**: `stack_card(card_instance_id, template_id, character_id)` 同名叠加——`stack_count < stack_limit` 时 `stack_count += 1`、新实例加入 `stack_slots`、共享槽位（`slot_index` 不变）
- [ ] **AC-008**: `stack_card` 达上限（`stack_count >= stack_limit`）返回 `{stacked: false, reason: "stack_limit_reached"}`；无已有绑定时返回 `{stacked: false, reason: "no_existing_binding"}`
- [ ] **AC-009**: 同名叠加乘法公式 `effective_value = base_value × native_multiplier × stack_multiplier^(stack_count-1)`——由 BindingManager 内部预计算，不运行时重查
- [ ] **AC-010**: `overwrite_binding` 覆盖已有绑定位——旧卡进弃牌堆、旧效果移除（remove_effects_by_source）、新效果注册（register_persistent_effect）严格顺序
- [ ] **AC-011**: 覆盖叠加中的同名卡时只移除一层——`stack_count -= 1`、被覆盖实例从 `stack_slots` 移除进弃牌堆、剩余层效果重算（乘法叠加指数减 1）、槽位不变
- [ ] **AC-012**: `stack_count` 减至 0 时 BindingRecord 删除（等效完全解绑）、绑定位释放为空位
- [ ] **AC-013**: `remove_binding(binding_id)` 移除单个绑定；`remove_all_bindings(character_id)` 角色阵亡时清除全部条目并返回序列化数据（供 CardSystem 洗回牌库）
- [ ] **AC-014**: 角色阵亡——全部绑定卡（含所有叠加实例）洗回牌库（非永久丢失）→ 清除 BindingManager 该角色所有条目 → 通知效果引擎 remove_effects_by_source
- [ ] **AC-015**: `suspend_bindings(character_id)` 角色离场——所有 BindingRecord.is_suspended = true；`restore_bindings(character_id)` 重新上场——验证 card_instance_id 仍存在则恢复，已不存在则删除 BindingRecord 变空位（不报错）
- [ ] **AC-016**: `get_accumulated_bonus(character_id, stat_name)` 遍历角色所有绑定卡的数值加成累加——O(k)，k ≤ 6/角色，<0.01ms
- [ ] **AC-017**: 不同角色独立控制 stack_count——角色A叠加3张同名卡不影响角色B独立叠加的同名卡效果
- [ ] **AC-018**: `card_already_bound` 拒绝——同一 card_instance_id 不能重复绑定到两个角色

---

## Implementation Notes

*Derived from ADR-0013 §关键接口 / §本命绑定判定算法 / §同名叠加乘法公式:*

1. **公共 API 签名**（详见 ADR-0013 §关键接口表）:
   - `bind_card(card_instance_id: int, template_id: StringName, character_id: int, slot_type: BindingSlot) → BindResult`
   - `stack_card(card_instance_id: int, template_id: StringName, character_id: int) → StackResult`
   - `overwrite_binding(card_instance_id: int, template_id: StringName, character_id: int, slot_index: int) → BindResult`
   - `remove_binding(binding_id: int) → void`
   - `remove_all_bindings(character_id: int) → Array[Dictionary]`
   - `suspend_bindings(character_id: int) → void`
   - `restore_bindings(character_id: int) → void`
   - `can_bind(character_id: int, slot_type: BindingSlot, template_id: StringName) → CanBindResult`
   - `get_accumulated_bonus(character_id: int, stat_name: String) → float`
2. **BindResult** = `{success: bool, binding_id: int, reason: String}`——reason: 'bound' / 'slot_full' / 'invalid_character' / 'card_already_bound'
3. **StackResult** = `{stacked: bool, stack_count: int, reason: String}`——reason: 'stacked' / 'stack_limit_reached' / 'no_existing_binding'
4. **CanBindResult** = `{can_bind: bool, can_stack: bool, must_overwrite: bool, slot_index: int, reason: String}`——UI 用于着色角色选择面板
5. **本命判定算法** `determine_native(character_id, card_template, slot_type) → {is_native, native_multiplier}`:
   - `native_owner` 为空/不匹配前缀 → `{false, 1.0}`
   - 该角色同类型已存在 `is_native=true` 记录 → `{false, 1.0}`（本命位已满）
   - 本命位空闲 → `{true, 1.5}`——绑定瞬间预计算并锁定，不运行时重查
6. **同名叠加公式**（BindingManager 内部计算）: `effective = base × native × stack_multiplier^(stack_count-1)`；结果向下取整 `floor(...)`。CardEffectEngine 通过 `get_binding_context(card_instance_id)` 查询预计算的 multiplier 乘积
7. **覆盖严格顺序**: `remove_effects_by_source(old_card_instance_id)` → 旧卡进弃牌堆 → 从三索引移除旧记录 → 新卡占用槽位 → 本命判定 → `register_persistent_effect(new_card_instance_id, ...)` ——无重叠帧
8. **覆盖叠加特殊规则**: `stack_count -= 1`、被覆盖实例从 `stack_slots` 移除进弃牌堆、剩余层效果重算、槽位不变；`stack_count == 0` 时删除 BindingRecord
9. **积累数值保留**: `accumulated_bonuses` 归属于 Character（非 BindingRecord）——覆盖时旧卡积累数值保留在角色上，仅持续触发效果停止
10. **阵亡处理**: `remove_all_bindings(character_id)` 返回序列化数据 → CardSystem 洗回牌库 → 清除三索引条目 → 通知效果引擎 remove_effects_by_source（含所有叠层）
11. **绑定位上限**: 战斗开始时 `RealmSystem.get_realm_property(level, "gongfa_slots")` / `"fabao_slots"` 缓存到本地——`_ready()` 通过直接方法调用查询上游（不 await 信号，遵循 ADR-0012 模式）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: BindingRecord 类定义 + 三索引 `_register_binding`/`_unregister_binding` 原子同步（本 Story 复用）
- **Story 003**: 7 个 Cat 2b 生命周期信号（`binding_applied`/`binding_removed` 等）+ `_emit_signal_safe` 路由
- **Story 004**: `serialize_all()` / `deserialize_all()` 快照导出 + CardEffectEngine persistent effect 接口的完整实现
- **CombatSystem 编排**: 出牌阶段调用 `bind_card`/`can_bind` 的时序、角色阵亡事件驱动——战斗 Epic（ADR-0008）职责
- **CombatUI 着色**: 角色选择面板分层着色（灰遮罩>绿叠加>橙覆盖>蓝空位）——Presentation 层职责
- **反悔窗口**: 覆盖 0.8s 反悔窗口的 UI 时序——UX/UI 职责

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-001**: bind_card 绑定到空位
  - Given: 角色 char_id 有空位（gongfa_slots=1，未绑定）
  - When: `bm.bind_card(card_id, template_id, char_id, BindingSlot.GONGFA)`
  - Then: 返回 success=true + binding_id 有效 + `get_bindings_by_character(char_id).size()==1`
  - Edge cases: 绑定后 `_card_to_character[card_id] == char_id`

- **AC-002**: bind_card 无空位拒绝
  - Given: 角色 char_id 已满（gongfa_slots=1，已绑定）
  - When: `bm.bind_card(card2_id, template2_id, char_id, BindingSlot.GONGFA)`
  - Then: 返回 success=false + reason="slot_full"
  - Edge cases: 不触发覆盖——覆盖必须走 `overwrite_binding`

- **AC-003**: can_bind 四种着色状态
  - Given: 多个角色处于不同槽位状态
  - When: 分别调用 `bm.can_bind(char_id, slot_type, template_id)`
  - Then: 灰遮罩/绿叠加/橙覆盖/蓝空位四种 CanBindResult 正确返回（can_bind/can_stack/must_overwrite 标志）
  - Edge cases: 已满+叠加满+无空位 → 不可选；同名未达上限 → can_stack=true（无论是否有空位）；无空位但可覆盖 → must_overwrite=true；有空位 → can_bind=true

- **AC-004**: 绑定位上限查询
  - Given: 战斗开始（level=炼气）
  - When: 检查 gongfa_slots/fabao_slots 缓存
  - Then: 功法位=1、法宝位=1（炼气）；化神期功法位=3、法宝位=3
  - Edge cases: 硬编码槽位数 → 测试失败（必须查询 RealmSystem）

- **AC-005**: 本命判定
  - Given: 卡牌 native_owner=lin_yuan，角色林渊 card_id 前缀匹配且本命位空
  - When: `bm.bind_card(...)` 触发 determine_native
  - Then: is_native=true + native_multiplier=1.5
  - Edge cases: native_owner 不匹配 → 1.0；本命位已占用 → 1.0；native_owner 为空 → 1.0

- **AC-006**: 本命不可逆
  - Given: 林渊已本命绑定青云剑诀（×1.5）
  - When: 叠加第2张青云剑诀到林渊
  - Then: is_native/native_multiplier 沿用首次值（不重新判定），effective = base × 1.5 × 1.5
  - Edge cases: 林渊再绑定万象推衍术（native_owner=lin_yuan）→ 本命位已满 → native_multiplier=1.0

- **AC-007**: stack_card 叠加
  - Given: 角色A已绑定同名卡（stack_count=1 < stack_limit）
  - When: `bm.stack_card(card2_id, same_template_id, char_a)`
  - Then: stack_count==2 + 新实例在 stack_slots + slot_index 不变（共享槽位）
  - Edge cases: 绑定位数量不增加

- **AC-008**: stack_card 上限拒绝
  - Given: 角色A已绑定同名卡且 stack_count >= stack_limit
  - When: `bm.stack_card(card3_id, same_template_id, char_a)`
  - Then: 返回 stacked=false + reason="stack_limit_reached"
  - Edge cases: 无已有绑定 → reason="no_existing_binding"

- **AC-009**: 叠加乘法公式
  - Given: stack_multiplier=1.5, base=4
  - When: 计算 stack_count=1/2/3/4/5 的 effective
  - Then: 非本命(native=1.0) → 4/6/9/13/20；本命(native=1.5) → 6/9/13/20/30（向下取整）
  - Edge cases: stack_count=1 时 `stack_multiplier^0 = 1.0` 退化为 base × native；stack_multiplier=2.0 + stack_count=5 + base=10 + native=1.5 → 240（需 stack_limit 约束）

- **AC-010**: overwrite_binding 覆盖
  - Given: 角色 char_id 已满，玩家确认覆盖
  - When: `bm.overwrite_binding(new_card_id, template_id, char_id, slot_index)`
  - Then: 旧卡进弃牌堆 + 旧效果 remove_effects_by_source 先于新效果 register_persistent_effect + 新卡落位
  - Edge cases: 调用顺序断言（remove 先于 register）

- **AC-011**: 覆盖叠加中的一层
  - Given: 角色A绑定枯木逢春诀 stack_count=3
  - When: 覆盖该绑定位（移除一层叠加）
  - Then: stack_count==2 + 被覆盖实例进弃牌堆 + 剩余2层效果重算（指数从2降为1）+ 槽位不变
  - Edge cases: 原槽位索引不变（共享同一位）

- **AC-012**: 覆盖至 stack_count=0
  - Given: 角色A绑定枯木逢春诀 stack_count=1
  - When: 覆盖该绑定位
  - Then: BindingRecord 删除（等效完全解绑）+ 绑定位释放为空位
  - Edge cases: 三索引中该条目全部移除

- **AC-013**: remove_binding / remove_all_bindings
  - Given: 角色 char_id 有多个绑定
  - When: `bm.remove_binding(id)` 单条 / `bm.remove_all_bindings(char_id)` 全部
  - Then: 对应条目从三索引清除；remove_all_bindings 返回序列化 Array[Dictionary]（供洗回）
  - Edge cases: remove_all_bindings 后 `get_binding_ids_by_character(char_id)` 为空

- **AC-014**: 角色阵亡洗回
  - Given: 角色A绑定枯木逢春诀 stack_count=3 + 其他绑定
  - When: 触发阵亡处理 `remove_all_bindings(char_a)`
  - Then: 3张同名实例全部洗回牌库（非弃牌堆、非永久丢失）+ 清除所有条目 + remove_effects_by_source 被调用（含所有叠层）
  - Edge cases: 牌库为空时阵亡卡直接进牌库并立即可用

- **AC-015**: suspend/restore
  - Given: 角色 char_id 有绑定 + 离场
  - When: `bm.suspend_bindings(char_id)` 后检查；再 `bm.restore_bindings(char_id)`
  - Then: suspend 后所有 is_suspended=true + 不进弃牌堆；restore 后验证 card_instance_id 存在 → is_suspended=false
  - Edge cases: 离场期间 card_instance_id 被移除 → restore 时删除 BindingRecord 变空位（不报错）

- **AC-016**: get_accumulated_bonus
  - Given: 角色 char_id 有绑定卡（含数值加成）
  - When: `bm.get_accumulated_bonus(char_id, "atk")`
  - Then: 返回所有绑定卡该 stat 的加成累加
  - Edge cases: 无绑定 → 0.0；<0.01ms（遍历 ≤6 张）

- **AC-017**: 不同角色独立 stack_count
  - Given: 角色A叠加3张同名卡（stack_count=3）、角色B叠加2张同名卡
  - When: 检查两角色的 stack_count 和 effective
  - Then: 角色A stack_count=3（有效值不变）、角色B stack_count=2 独立计算、互不干扰
  - Edge cases: 覆盖角色A不影响角色B

- **AC-018**: card_already_bound 拒绝
  - Given: card_instance_id 已绑定到角色A
  - When: `bm.bind_card(同一card_id, ..., 角色B, ...)`
  - Then: 返回 reason="card_already_bound"
  - Edge cases: `_card_to_character` 反向查询阻止重复绑定

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/binding_system/test_bind_unbind_query_api.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（三索引结构 + `_register_binding`/`_unregister_binding` + BindingRecord 类）
- Unlocks: Story 003（信号总线——依赖 002 的绑定/覆盖/叠加/阵亡业务逻辑）；Story 004（序列化快照——依赖 002 的完整绑定生命周期）
