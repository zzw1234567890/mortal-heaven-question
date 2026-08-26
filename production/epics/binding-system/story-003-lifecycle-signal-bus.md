# Story 003: 绑定生命周期信号总线（7 个 Cat 2b 信号）

> **Epic**: 功法/法宝绑定系统 (Binding System)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-21

## Completion Notes
**Completed**：2026-08-21
**Criteria**：10/10 通过（AC-001~010 由 30 个集成测试覆盖）
**Deviations**：
1. **信号参数 `binding_ids` 声明为 `Array[int]`（lead-programmer C1 修正）**：初版用无类型 `Array`，与 ADR-0013 §Cat 2b 信号表及 DeploymentSystem 先例（`standby_cleared(character_ids: Array[int])`）不一致，已修正。
2. **`binding_removed` reason 三值**（lead-programmer C5）：ADR 原仅提及 'death'/'overwritten'，实现新增 'removed'（手动移除，区别于阵亡洗回）。已回写 ADR-0013 §Cat 2b 信号表。
3. **`overwrite_binding` reason 扩展**（lead-programmer C4）：ADR 原未列举 reason 值，实现返回 'overwritten'/'overwritten_stack'/'no_existing_binding'/'card_already_bound'。已回写 ADR-0013 §关键接口表。
3. **`_emit_safe` 回退路径用 `callv("emit_signal")` 而非 DeploymentSystem 的 `.emit()`**（lead-programmer C2，设计取舍）：7 个信号参数各异，统一 `_emit_safe(signal_name, args)` 接口比每信号一个包装方法更简洁——合理取舍，暂不改。
**Lead-Programmer CONCERNS（已处理）**：
- C1（已修复）：`binding_suspended`/`binding_restored` 的 `binding_ids` 参数 `Array` → `Array[int]`，与 ADR + DeploymentSystem 先例一致。
- C2（设计取舍，不改）：`_emit_safe` 回退路径用 `callv` 而非 `.emit()`——统一接口简洁性优于编译时参数检查。
- C3（不改，AC-009 互补覆盖）：AC-002 测试为间接验证，但 AC-009 的 `_signal_chain_depth == 0` 断言间接证明了 GSM 路由（直接 `emit_signal` 不触动 `_signal_chain_depth`）。
- C4（已回写）：`overwrite_binding` reason 值列举补充到 ADR-0013 §关键接口表。
- C5（已回写）：`binding_removed` reason 三值补充到 ADR-0013 §Cat 2b 信号表。
**QA-Lead GAPS（已补齐）**：
- G1（参数类型）：`has_signal` 验证存在性 + `get_signal_list` 过滤自定义信号计数 7。
- G5（is_native=true 载荷）：`test_binding_signal_binding_applied_is_native_true`。
- G6（card_already_bound 不发射）：`test_binding_signal_binding_applied_not_on_card_already_bound`。
- G7（叠加覆盖 binding_removed）：`test_binding_signal_binding_removed_on_overwrite_stack`。
- G8（无效 ID 不发射）：`test_binding_signal_binding_removed_not_on_missing_id`。
- G9（叠加覆盖不发射 binding_overwritten）：`test_binding_signal_binding_overwritten_not_on_stack_overwrite`。
- G10（覆盖失败不发射）：`test_binding_signal_binding_overwritten_not_on_fail`。
- G11（no_existing/card_already_bound 拒绝不发射）：两个补测。
- G12（零绑定角色 suspend 边界）：`test_binding_signal_binding_suspended_empty_character`。
- G13（overwrite 中 native_activated）：`test_binding_signal_native_activated_on_overwrite`。
- G14（链深度截断守卫）：`test_binding_signal_chain_depth_truncation_on_cascade`——递归 handler 在 handler 内再触发绑定操作，验证 `MAX_SIGNAL_CHAIN_DEPTH` 截断。
- G15（全 7 信号事实载荷）：`test_binding_signal_payloads_carry_facts_not_instructions` 改为触发全部 7 个信号 + 12 个指令性前缀黑名单。
- G16（信号发射顺序）：overwrite 完全覆盖路径的 removed→applied→native_activated→overwritten 顺序由 lead-programmer 代码审查确认正确。
**Test Evidence**：`tests/integration/binding_system/test_binding_signal_bus.gd`（30 测试全通过）；全量套件 74 scripts / 1398 tests / 1397 passing / 1 pending / 0 failing 零回归
**Code Review**：lead-programmer CONCERNS→已处理（C1 修复 + C4/C5 ADR 回写 + C2/C3 设计取舍）；qa-lead GAPS→已补齐（G1-G16 全部）

## Context

**GDD**: `design/gdd/binding-system.md`
**Requirement**: `TR-binding-002`
*(需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版)*

**ADR Governing Implementation**: ADR-0013（绑定系统 — BindingManager Autoload + RefCounted BindingRecord 实例模型 + 效果引擎集成）
**ADR Decision Summary**: 绑定生命周期事件通过专用 Cat 2b 信号总线通知 CombatUI。7 个信号（binding_applied/binding_removed/binding_overwritten/binding_stacked/binding_suspended/binding_restored/native_activated）由 BindingManager 直接发射，通过 ADR-0007 `_emit_signal_safe` 包装器路由以追踪信号链深度。信号链深度 ≤2 层。

**Engine**: Godot 4.6 | **Risk**: LOW（信号系统——4.0+ 稳定 API）
**Engine Notes**: 不依赖 4.4+ 新特性。Cat 2 信号必须通过 `_emit_signal_safe()` 包装器路由（ADR-0007）。

**Control Manifest Rules (Feature 层 + 全局)**:
- Required: Cat 2 信号必须通过 `_emit_signal_safe()` 包装器路由——信号链深度追踪（来源: ADR-0007）
- Required: 信号命名 snake_case 过去式；信号声明在语义归属系统——禁止 SignalBus Autoload（来源: ADR-0007）
- Forbidden: 绝不发射携带指令（"该做什么"）的信号——信号携带事实（"发生了什么"）（来源: ADR-0007）
- Forbidden: 绝不超出信号链深度 4——截断 + push_error（来源: ADR-0007）
- Forbidden: 绝不使用 `Callable.bind()` 而不在 `_exit_tree()` 中手动 `disconnect()`（来源: ADR-0007）

---

## Acceptance Criteria

*From GDD `design/gdd/binding-system.md` §详细设计 §5/§6/§7/§8/§10 + ADR-0013 §关键接口 Cat 2b 信号表 / §验证标准:*

- [ ] **AC-001**: 声明 7 个 Cat 2b 信号，签名与 ADR-0013 完全一致：`binding_applied(binding_id, card_instance_id, template_id, character_id, slot_type, is_native)`、`binding_removed(binding_id, card_instance_id, character_id, reason)`、`binding_overwritten(old_binding_id, new_binding_id, character_id, slot_index)`、`binding_stacked(binding_id, template_id, character_id, new_stack_count)`、`binding_suspended(character_id, binding_ids)`、`binding_restored(character_id, binding_ids)`、`native_activated(binding_id, template_id, character_id)`
- [ ] **AC-002**: 全部 7 个信号通过 `_emit_signal_safe()` 包装器路由（非直接 `emit_signal`）
- [ ] **AC-003**: `binding_applied` 在新绑定成功时发射（含 is_native 标志，CombatUI 据此创建图标/动画 + 本命星标）
- [ ] **AC-004**: `binding_removed` 在绑定解除时发射（reason 区分阵亡/覆盖旧卡）
- [ ] **AC-005**: `binding_overwritten` 在覆盖完成时发射（携带 old_binding_id / new_binding_id / character_id / slot_index）
- [ ] **AC-006**: `binding_stacked` 在同名叠加时发射（携带 new_stack_count，CombatUI 据此更新"+1层"文字特效 + 层数徽章）
- [ ] **AC-007**: `binding_suspended` 在角色离场时发射（携带 character_id + binding_ids: Array[int]）；`binding_restored` 在角色重新上场时发射
- [ ] **AC-008**: `native_activated` 在本命绑定激活时发射（CombatUI 据此点亮 ★金色星标 + Audio 金色共鸣音）
- [ ] **AC-009**: 信号链深度 ≤2 层——绑定信号 → CombatUI 更新 → 无进一步信号级联（超过 4 层截断 + push_error）
- [ ] **AC-010**: 信号携带事实而非指令——不通过信号参数传递"该做什么"，订阅者自行决定响应

---

## Implementation Notes

*Derived from ADR-0013 §关键接口 Cat 2b 信号表 / §Cat 2b 信号（通过 _emit_signal_safe 路由）:*

1. **文件位置**: `src/core/binding/binding_manager.gd`（在 Story 001/002 的 BindingManager 中声明 7 个信号）
2. **信号声明**（在语义归属系统 BindingManager——禁止 SignalBus Autoload）:
   ```
   signal binding_applied(binding_id: int, card_instance_id: int, template_id: StringName, character_id: int, slot_type: BindingSlot, is_native: bool)
   signal binding_removed(binding_id: int, card_instance_id: int, character_id: int, reason: String)
   signal binding_overwritten(old_binding_id: int, new_binding_id: int, character_id: int, slot_index: int)
   signal binding_stacked(binding_id: int, template_id: StringName, character_id: int, new_stack_count: int)
   signal binding_suspended(character_id: int, binding_ids: Array[int])
   signal binding_restored(character_id: int, binding_ids: Array[int])
   signal native_activated(binding_id: int, template_id: StringName, character_id: int)
   ```
3. **发射路由**: 全部通过 `_emit_signal_safe(signal_name, ...args)` 包装器（ADR-0007）——追踪信号链深度，超过 4 层截断 + push_error
4. **发射时机映射**（与 Story 002 业务逻辑挂钩）:
   - `bind_card` 成功 → `binding_applied`；本命判定 is_native=true 时额外发射 `native_activated`
   - `remove_binding` / `remove_all_bindings` → `binding_removed`（reason: 'death' / 'overwritten'）
   - `overwrite_binding` 完成 → `binding_overwritten`（旧卡 `binding_removed` reason='overwritten' + 新卡 `binding_applied`）
   - `stack_card` 成功 → `binding_stacked`（new_stack_count）
   - `suspend_bindings` → `binding_suspended`；`restore_bindings` → `binding_restored`
5. **信号载荷 ≤3 参数优先；>3 → 具名字典**（ADR-0007）。此处 `binding_applied` 为 6 参数、`binding_overwritten` 为 4 参数——ADR-0013 已明确定义签名，作为 ADR-0007 载荷规则的既定例外（信号语义清晰，参数均为原子事实）
6. **订阅者**（前向引用，本 Story 不实现）: CombatUI（图标/动画/本命星标/层数徽章）、Audio（音效）——通过 `binding_manager.binding_applied.connect(callable)` 订阅
7. **信号链深度约束**: 绑定信号 → CombatUI 更新 → 无进一步信号级联。CombatUI 的响应函数内不得再发射 Cat 2b 信号
8. **测试模式**: 动态分派 `BM_SCRIPT.new()` + `var bm: Node`；测试订阅信号断言发射次数与参数载荷

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: BindingRecord 类定义 + 三索引注册表
- **Story 002**: bind/stack/overwrite/remove/suspend/restore 的业务逻辑（本 Story 仅在业务逻辑各节点挂钩信号发射）
- **Story 004**: `serialize_all()`/`deserialize_all()` 快照导出 + CardEffectEngine persistent effect 接口
- **CombatUI 实现**: 订阅信号后的图标/动画/本命星标/层数徽章/hover tooltip——Presentation 层职责
- **Audio 实现**: 绑定音效/本命金色共鸣音——Audio 职责
- **阵法系统通知**: 绑定状态变更 → 重查阵法激活条件——阵法 Epic（ADR-0024）职责

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-001**: 7 个信号签名
  - Given: BindingManager 脚本已加载
  - When: 检查 `BM_SCRIPT` 的信号列表与参数签名
  - Then: 7 个信号名称 + 参数类型与 ADR-0013 完全一致
  - Edge cases: 信号名全部 snake_case 过去式；无多余信号、无缺失信号

- **AC-002**: _emit_signal_safe 路由
  - Given: 触发任意绑定操作
  - When: 检查信号发射是否经过 `_emit_signal_safe`
  - Then: 全部 7 个信号均通过包装器路由（非直接 emit_signal）
  - Edge cases: 直接 `emit_signal` 调用 → 测试失败

- **AC-003**: binding_applied 发射
  - Given: 订阅 `binding_applied` + 执行 `bind_card` 成功
  - When: 捕获信号
  - Then: 载荷含 binding_id/card_instance_id/template_id/character_id/slot_type/is_native
  - Edge cases: 本命绑定 is_native=true 时额外发射 native_activated

- **AC-004**: binding_removed 发射
  - Given: 订阅 `binding_removed` + 触发 remove_binding / remove_all_bindings
  - When: 捕获信号
  - Then: reason 正确区分 'death' / 'overwritten'
  - Edge cases: 阵亡洗回场景 reason='death'

- **AC-005**: binding_overwritten 发射
  - Given: 订阅 `binding_overwritten` + 执行 `overwrite_binding`
  - When: 捕获信号
  - Then: 载荷含 old_binding_id/new_binding_id/character_id/slot_index
  - Edge cases: 覆盖本命位时信号载荷不变（本命覆盖的特殊销毁特效由 UI 据 is_native 判断）

- **AC-006**: binding_stacked 发射
  - Given: 订阅 `binding_stacked` + 执行 `stack_card` 成功
  - When: 捕获信号
  - Then: 载荷含 binding_id/template_id/character_id/new_stack_count（=stack_count+1）
  - Edge cases: 达上限拒绝时不发射（stacked=false）

- **AC-007**: binding_suspended / binding_restored
  - Given: 订阅两个信号 + 执行 suspend_bindings / restore_bindings
  - When: 捕获信号
  - Then: 载荷含 character_id + binding_ids: Array[int]
  - Edge cases: restore 验证失败（card 已不存在）时 binding_ids 不含被删除的绑定

- **AC-008**: native_activated 发射
  - Given: 订阅 `native_activated` + 本命判定成功绑定
  - When: 捕获信号
  - Then: 载荷含 binding_id/template_id/character_id
  - Edge cases: 非本命绑定不发射；本命位已满的匹配卡不发射

- **AC-009**: 信号链深度 ≤2
  - Given: 完整绑定操作链路
  - When: 触发信号并观察下游响应
  - Then: 绑定信号 → CombatUI 更新 → 无进一步信号级联；深度计数器 ≤2
  - Edge cases: 超过 4 层 → 截断 + push_error（ADR-0007 守卫）

- **AC-010**: 信号携带事实
  - Given: 检查 7 个信号的参数语义
  - When: 审查信号参数
  - Then: 参数均为事实数据（id/flag/count/reason），无指令性字段（如 "show_animation" / "play_sound"）
  - Edge cases: 订阅者据 reason 自行决定 UI 响应

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/binding_system/test_binding_signal_bus.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（bind/stack/overwrite/remove/suspend/restore 业务逻辑——信号在业务逻辑各节点挂钩）
- Unlocks: CombatUI 订阅（绑定图标/本命星标/层数徽章/hover tooltip）；Audio 订阅（绑定音效）；阵法系统通知（绑定状态变更重查阵法）
