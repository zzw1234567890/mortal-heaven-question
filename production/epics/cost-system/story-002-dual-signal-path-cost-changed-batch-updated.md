# Story 002: 双重信号路径（cost_changed Cat 2b + GSM batch_updated Cat 1）

> **Epic**: cost-system
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-10

## Context

**GDD**: `design/gdd/cost-system.md`
**Requirement**: `TR-cost-001`（待 `/architecture-review` 注册）

**ADR Governing Implementation**: ADR-0015（费用系统——双重信号路径 cost_changed Cat 2b + GSM batch_updated Cat 1）
**ADR Decision Summary**: 费用变更同时通过 `CostSystem.cost_changed`（Cat 2b 系统信号——高效直达路径，载荷结构化）和 `GSM.batch_updated`（Cat 1 状态广播——CombatUI 统一刷新源）传播。`GSM._set_battle_cost(current, max)` 第二层原子方法写入 `battle.current_cost`/`battle.max_cost` 并发射 batch_updated。

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: 信号系统 4.0+ 稳定 API。双信号路径时序：CostSystem 先发射 Cat 2b，再写 GSM 触发 Cat 1。

**Control Manifest Rules (Core 层)**:
- **Required**: GSM 第二层原子方法 `_set_battle_cost` —— 通过 `_buffer_change` 管线 + `batch_updated` 发射
- **Required**: Cat 2b 信号 `cost_changed` 声明在 CostSystem（语义归属系统——ADR-0007）
- **Forbidden**: 禁止 SignalBus Autoload——信号声明在归属系统
- **Forbidden**: 信号用于逻辑而非通知——费用逻辑通过原子方法完成，信号仅刷新钩子

---

## Acceptance Criteria

*From ADR-0015 §关键接口 §Cat 2b 信号 + §GSM 第二层扩展 + §验证标准:*

- [ ] **AC-001**: `signal cost_changed(current: int, max: int, total_max: int)` 声明在 CostSystem
- [ ] **AC-002**: `spend()` 成功后发射 `cost_changed(current, max, total_max)` ——current 为扣费后值
- [ ] **AC-003**: `add_temp_bonus()` 后发射 `cost_changed` ——total_max 包含临时加成
- [ ] **AC-004**: `reset_for_turn()` 后发射 `cost_changed` ——current 为重置后值（含后手 +1）
- [ ] **AC-005**: `init_for_battle()` 后发射 `cost_changed` ——初始满费状态
- [ ] **AC-006**: `spend()` 失败（费用不足）时不发射 `cost_changed`（状态未变）
- [ ] **AC-007**: `GSM._set_battle_cost(current_cost, max_cost)` 写入 `battle.current_cost` + `battle.max_cost` + 发射 `batch_updated`
- [ ] **AC-008**: `batch_updated` 载荷含 `battle.current_cost: {old, new}` 和 `battle.max_cost: {old, new}` 展平字典
- [ ] **AC-009**: CostSystem `_write_cost_to_gsm()` 调用 `GSM._set_battle_cost(current, total_max)` ——total_max 作为 max 参数（含临时加成）
- [ ] **AC-010**: 双信号时序：`cost_changed`（Cat 2b）先发射，`batch_updated`（Cat 1）后发射
- [ ] **AC-011**: CombatUI 订阅 `batch_updated`（Cat 1）作为统一刷新源时正常工作
- [ ] **AC-012**: GSM 不可用时 `_write_cost_to_gsm` 不崩溃（`is_instance_valid` 守卫）

---

## Implementation Notes

*Derived from ADR-0015 §关键接口 §Cat 2b 信号 + §GSM 第二层扩展:*

1. **信号声明**: `signal cost_changed(current: int, max: int, total_max: int)`（3 参数 ≤3 优先——ADR-0007）
2. **GSM 第二层方法**: 在 `game_state_manager.gd` 新增 `_set_battle_cost(current_cost: int, max_cost: int) -> void` —— 走 `_buffer_change("battle.current_cost", ...)` + `_buffer_change("battle.max_cost", ...)` 管线，帧末 `batch_updated` 发射
3. **_write_cost_to_gsm 实现**: `if is_instance_valid(GSM) and GSM.has_method("_set_battle_cost"): GSM._set_battle_cost(_current_cost, _max_cost + _temp_bonus)`
4. **时序保证**: 变异 API 中先 `_write_cost_to_gsm()`（触发 Cat 1 帧末）再 `cost_changed.emit()`（Cat 2b 即时）——或反过来，本 Story 确定一致顺序并文档化
5. **Story 001 桩替换**: Story 001 的 `_write_cost_to_gsm` 桩（`has_method` 守卫）在本 Story 实现真实 GSM 方法后自然生效

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: CostSystem 内部状态 + 查询/变异 API（已实现）
- **CombatUI 费用栏实现**: 订阅信号刷新 UI ——战斗 UI Epic 职责
- **CombatSystem 集成**: 调用变异 API 触发信号 ——战斗 Epic 职责

---

## QA Test Cases

*From QA 计划 qa-plan-sprint-3-2026-08-10.md §Story 3-3 + ADR-0015 §验证标准:*

- **AC-001**: cost_changed 信号声明
  - Given: CostSystem 脚本已加载
  - When: `CS_SCRIPT.get_script_signal_list()`
  - Then: 含 `cost_changed` 信号，3 个 int 参数
  - Edge cases: 信号声明在 CostSystem 而非 GSM

- **AC-002**: spend 成功后发射 cost_changed
  - Given: `cs.init_for_battle(5)` + 信号监听已连接
  - When: `cs.spend(3)`
  - Then: `cost_changed` 发射一次，载荷 `(current=2, max=5, total_max=5)`
  - Edge cases: 监听器接收到的参数值正确

- **AC-003**: add_temp_bonus 后发射 cost_changed
  - Given: `cs.init_for_battle(5)` + 监听
  - When: `cs.add_temp_bonus(2, "mid_pill")`
  - Then: `cost_changed` 载荷 `(current=7, max=5, total_max=7)`
  - Edge cases: total_max 含临时加成

- **AC-004**: reset_for_turn 后发射 cost_changed
  - Given: `cs.init_for_battle(5)` + `cs.spend(3)` + 监听
  - When: `cs.reset_for_turn(true, false)`
  - Then: `cost_changed` 载荷 `(current=5, max=5, total_max=5)`
  - Edge cases: 后手第 1 回合 current=6

- **AC-005**: init_for_battle 后发射 cost_changed
  - Given: cs 已创建 + 监听
  - When: `cs.init_for_battle(5)`
  - Then: `cost_changed` 载荷 `(current=5, max=5, total_max=5)`
  - Edge cases: 初始满费状态

- **AC-006**: spend 失败不发射 cost_changed
  - Given: `cs.init_for_battle(1)` + 监听
  - When: `cs.spend(3)`（失败）
  - Then: `cost_changed` 不发射（状态未变）
  - Edge cases: push_warning 但无信号

- **AC-007**: GSM._set_battle_cost 写入 battle 域
  - Given: GSM Autoload 可用
  - When: `GSM._set_battle_cost(3, 5)`
  - Then: `GSM.battle.current_cost == 3` + `GSM.battle.max_cost == 5`
  - Edge cases: 通过 `get_state("battle.current_cost")` 读取一致

- **AC-008**: batch_updated 载荷含费用路径
  - Given: 订阅 `GSM.batch_updated`
  - When: `GSM._set_battle_cost(3, 5)` 后帧末刷新
  - Then: 载荷含 `"battle.current_cost": {old, new}` 和 `"battle.max_cost": {old, new}`
  - Edge cases: 展平路径字典（ADR-0001）

- **AC-009**: _write_cost_to_gsm 调用 GSM 方法
  - Given: `cs.init_for_battle(5)` + `cs.add_temp_bonus(2)`
  - When: 检查 GSM battle 域
  - Then: `battle.current_cost == 7` + `battle.max_cost == 7`（total_max 传入）
  - Edge cases: `_set_battle_cost(current, _max_cost + _temp_bonus)`

- **AC-010**: 双信号时序
  - Given: 同时监听 `cost_changed` 和 `batch_updated`
  - When: `cs.spend(1)`
  - Then: `cost_changed` 先触发，`batch_updated` 后触发（帧末）
  - Edge cases: 文档化时序，CombatUI 统一监听 Cat 1 避免时序问题

- **AC-011**: CombatUI 订阅 batch_updated 正常工作
  - Given: 模拟 CombatUI 订阅 `GSM.batch_updated` 过滤 `battle.current_cost`
  - When: `cs.spend(2)`
  - Then: 帧末后 UI 收到刷新通知
  - Edge cases: 仅过滤费用路径前缀

- **AC-012**: GSM 不可用时不崩溃
  - Given: 测试环境模拟 GSM 不可用（或 `_set_battle_cost` 方法不存在）
  - When: `cs.init_for_battle(5)` + `cs.spend(1)`
  - Then: 不崩溃，`cost_changed` 仍正常发射（Cat 2b 不依赖 GSM）
  - Edge cases: `is_instance_valid(GSM)` + `has_method` 双守卫

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/cost_system/test_cost_signals.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（CostSystem 内部状态 + 变异 API + `_write_cost_to_gsm` 桩）
- Unlocks: 战斗 UI Epic（CombatUI 费用栏订阅信号刷新）
