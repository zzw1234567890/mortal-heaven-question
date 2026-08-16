# Story 004: 阶段转换 Cat 2b 信号通知 CombatUI

> **Epic**: combat-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-combat-001`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0008（战斗系统——信号分类 Cat 2b + 信号链深度分析）+ ADR-0007（信号分类——Cat 2b 通过 `_emit_signal_safe` 路由）
**ADR Decision Summary**: 5 个 Cat 2b 信号（`phase_changed`、`battle_started`、`battle_ended`、`attack_resolved`、`character_died`）通知 UI/Audio/SaveLoad 等消费者。所有 Cat 2b 信号通过 `_emit_signal_safe` 包装器路由——信号链深度追踪。HP/费用数据变更通过 GSM Cat 1 `batch_updated` 传播——无自有数据信号重复。

**Engine**: Godot 4.6 | **Risk**: LOW（信号系统 4.0+ 稳定 API）
**Engine Notes**: 5 个 Cat 2b 信号链预估深度 1-2 层，不超过 4 层硬限制（ADR-0007）。信号处理器必须捕获异常（ADR-0007 禁止模式 #8）。

**Control Manifest Rules (Feature 层 + 全局)**:
- **Required**: Cat 2 信号必须通过 `_emit_signal_safe()` 包装器路由 —— 来源: ADR-0007
- **Required**: 信号命名：snake_case 过去式 —— 来源: ADR-0007
- **Required**: 信号载荷：≤3 参数优先；>3 → 具名字典 —— 来源: ADR-0007
- **Required**: 信号声明在语义归属系统——禁止 SignalBus Autoload —— 来源: ADR-0007
- **Forbidden**: 绝不超出信号链深度 4 —— 截断 + `push_error` —— 来源: ADR-0007
- **Forbidden**: 绝不发射携带指令（"该做什么"）的信号——信号携带事实（"发生了什么"） —— 来源: ADR-0007

---

## Acceptance Criteria

*From ADR-0008 §验证标准 + §决策（信号分类 Cat 2b）+ GDD §与其他系统的交互（战斗UI系统交互）:*

- [ ] **AC-001**: 声明 5 个 Cat 2b 信号在 CombatSystem（语义归属系统）：`phase_changed`、`battle_started`、`battle_ended`、`attack_resolved`、`character_died`
- [ ] **AC-002**: `phase_changed(old_phase: int, new_phase: int, turn: int)` 在 `advance_phase()` 成功后发射，通过 `_emit_signal_safe`
- [ ] **AC-003**: `battle_started(config: Dictionary)` 在 `battle_start()` 完成后发射，通过 `_emit_signal_safe`
- [ ] **AC-004**: `battle_ended(result: CombatResult, rewards: Dictionary)` 在 `battle_end()` 完成后、清理 battle 域之前发射，通过 `_emit_signal_safe`
- [ ] **AC-005**: `attack_resolved(attacker_id, target_id, damage, is_kill)` 在每次攻击结算完毕发射——4 参数使用具名字典格式（ADR-0007），通过 `_emit_signal_safe`
- [ ] **AC-006**: `character_died(character_id: int, side: Side, binding_card_ids: Array[int])` 在角色 HP ≤ 0 时发射——携带正确的 `binding_card_ids`，通过 `_emit_signal_safe`
- [ ] **AC-007**: CombatUI 监听 `phase_changed` → 阶段指示器随 `advance_phase()` 更新
- [ ] **AC-008**: 信号链深度不超过 4 层硬限制——`character_died` → BindingSystem 解绑 → GSM `batch_updated` → HUD 刷新 = 3 层
- [ ] **AC-009**: 信号处理器捕获异常（ADR-0007 禁止模式 #8）——异常逃逸导致的深度计数器泄漏通过 GSM 帧级重置恢复
- [ ] **AC-010**: HP/费用变更不通过战斗系统自有信号——通过 GSM Cat 1 `batch_updated` 传播（无自有数据信号重复）

---

## Implementation Notes

*Derived from ADR-0008 §决策（信号分类 Cat 2b）+ ADR-0007（信号分类法）:*

1. **文件位置**: `src/feature/combat_system.gd`（与 Story 001/002/003 同文件——本 Story 实现信号声明与发射路由）
2. **信号声明**（语义归属系统 CombatSystem——禁止 SignalBus Autoload）:
   ```gdscript
   signal phase_changed(old_phase: int, new_phase: int, turn: int)
   signal battle_started(config: Dictionary)
   signal battle_ended(result: CombatResult, rewards: Dictionary)
   signal attack_resolved(attack_data: Dictionary)  # 4 参数使用具名字典（ADR-0007）
   signal character_died(character_id: int, side: Side, binding_card_ids: Array[int])
   ```
3. **5 个 Cat 2b 信号发射时机与载荷**（ADR-0008 §信号分类表）:
   | 信号 | 发射时机 | 载荷 | 消费者 | 信号链预估深度 |
   |------|---------|------|--------|--------------|
   | `phase_changed` | `advance_phase()` 成功后 | `(old_phase, new_phase, turn)` | CombatUI（阶段指示器）、AudioSystem（阶段音效） | 1 层 |
   | `battle_started` | `battle_start()` 完成后 | `(config)` | CombatUI（初始化 UI）、AudioSystem（BGM）、SceneManager | 1 层 |
   | `battle_ended` | `battle_end()` 完成后、清理 battle 域之前 | `(result, rewards)` | SceneManager（切场景）、SaveLoad（自动存档）、ExplorationSystem | 2 层 |
   | `attack_resolved` | 每次攻击结算完毕 | `{attacker_id, target_id, damage, is_kill}`（具名字典） | CombatUI（攻击动画+伤害数字）、AudioSystem | 1 层 |
   | `character_died` | 角色 HP ≤ 0 | `(character_id, side, binding_card_ids)` | CombatUI（阵亡动画）、BindingSystem（解绑）、DeploymentSystem | 2 层 |
4. **信号路由**: 所有 5 个 Cat 2b 信号通过 `_emit_signal_safe(self, &"signal_name", args)` 发射（ADR-0007 包装器——信号链深度追踪 + 截断保护）
5. **信号链深度分析**: 最深路径 `character_died` → BindingSystem 解绑 → GSM `batch_updated` → HUD 刷新 = 3 层（用户输入[0]→出牌结算[0]→character_died 发射[1]→BindingSystem 处理器[1]→GSM batch_updated[2]→HUD 处理器[2]）——安全位于 4 层硬限制内
6. **非信号——直接方法调用**（战斗系统内部编排，不发射信号）:
   - `CostSystem.spend(n)`、`CardEffectEngine.resolve(card, target)`、`AISystem.get_next_action(enemy, field)`、`StatusEffectSystem.tick_all()`、`RealmSystem.get_suppression(attacker, defender)`、`GSM.apply_battle_rewards(...)`
7. **战斗数据变更 → GSM Cat 1 信号**（非战斗系统自有信号）:
   - HP 变更 → `GSM.batch_updated({"battle.player_field[2].hp": {old, new}})`
   - 费用变更 → `GSM.batch_updated({"battle.current_cost": {old, new}})`
   - 状态效果变更 → `GSM.batch_updated({"battle.player_field[1].statuses": {old, new}})`
8. **信号处理器异常处理**: 信号处理器必须捕获异常（ADR-0007 禁止模式 #8）——未捕获异常逃逸导致的深度计数器泄漏通过 GSM 帧级重置恢复
9. **信号载荷命名约束**: 信号命名 snake_case 过去式；≤3 参数优先，`attack_resolved` 4 参数用具名字典

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: 7 阶段状态机推进逻辑——本 Story 只实现信号声明与路由，不实现推进逻辑
- **Story 002**: 战斗生命周期——本 Story 只实现 `battle_started`/`battle_ended` 信号的路由，不实现生命周期编排
- **Story 003**: 出牌结算流程——本 Story 只实现 `attack_resolved`/`character_died` 信号在攻击/阵亡路径的路由，不实现出牌结算逻辑
- **CombatUI 订阅端实现**: 阶段指示器、阵亡动画、伤害数字的实际 UI 渲染——战斗 UI Epic 职责
- **AudioSystem 音效**: 阶段音效、BGM、命中音效的实际音频实现——音频系统职责
- **BindingSystem 解绑逻辑**: `character_died` 信号的消费者侧处理——绑定系统 Epic 职责

---

## QA Test Cases

*From ADR-0008 §验证标准 + §信号链深度分析:*

- **AC-001**: 5 个 Cat 2b 信号声明在 CombatSystem
  - Given: CombatSystem 脚本已加载
  - When: `CS_SCRIPT.get_script_signal_list()`
  - Then: 含 `phase_changed`、`battle_started`、`battle_ended`、`attack_resolved`、`character_died` 5 个信号
  - Edge cases: 信号声明在 CombatSystem 而非 SignalBus

- **AC-002**: phase_changed 信号发射
  - Given: 战斗活跃，监听 `phase_changed`
  - When: `advance_phase()` 成功推进
  - Then: `phase_changed` 发射一次，载荷 `(old_phase, new_phase, turn)`，通过 `_emit_signal_safe`
  - Edge cases: 验证失败时不发射 `phase_changed`

- **AC-003**: battle_started 信号发射
  - Given: 监听 `battle_started`
  - When: `battle_start(config)` 完成
  - Then: `battle_started` 发射一次，载荷为 config Dictionary，通过 `_emit_signal_safe`
  - Edge cases: 消费者为初始化操作，不发射下游信号

- **AC-004**: battle_ended 信号发射
  - Given: 监听 `battle_ended`
  - When: `battle_end(result)` 完成
  - Then: `battle_ended` 发射一次，载荷 `(result, rewards)`，发射时机在清理 battle 域之前，通过 `_emit_signal_safe`
  - Edge cases: 信号链 2 层（SaveLoad auto_save → save_completed）

- **AC-005**: attack_resolved 信号发射
  - Given: 监听 `attack_resolved`
  - When: 每次攻击结算完毕
  - Then: `attack_resolved` 发射一次，载荷 `{attacker_id, target_id, damage, is_kill}` 具名字典，通过 `_emit_signal_safe`
  - Edge cases: 4 参数使用具名字典格式（ADR-0007）

- **AC-006**: character_died 信号发射
  - Given: 监听 `character_died`
  - When: 角色 HP ≤ 0
  - Then: `character_died` 发射一次，载荷 `(character_id, side, binding_card_ids)`，`binding_card_ids` 正确，通过 `_emit_signal_safe`
  - Edge cases: BindingSystem 可据此解绑

- **AC-007**: CombatUI 监听 phase_changed 更新
  - Given: 模拟 CombatUI 订阅 `phase_changed`
  - When: `advance_phase()` 推进
  - Then: 阶段指示器随推进更新（UI 收到通知）
  - Edge cases: 信号链 1 层（CombatUI/AudioSystem 直接消费，不触发下游）

- **AC-008**: 信号链深度不超 4 层
  - Given: `character_died` 发射
  - When: 追踪信号链
  - Then: `character_died` → BindingSystem 解绑 → GSM `batch_updated` → HUD 刷新 = 3 层（≤4 层硬限制）
  - Edge cases: 超过 4 层时截断 + `push_error`（ADR-0007）

- **AC-009**: 信号处理器异常捕获
  - Given: 信号处理器可能抛异常
  - When: 处理器抛出未捕获异常
  - Then: 深度计数器通过 GSM 帧级重置恢复（不泄漏）
  - Edge cases: 信号处理器必须包裹异常处理（ADR-0007 禁止模式 #8）

- **AC-010**: HP/费用变更不通过自有信号
  - Given: HP 变更、费用变更发生
  - When: 检查信号
  - Then: 通过 GSM Cat 1 `batch_updated` 传播（`battle.player_field[2].hp` / `battle.current_cost` 路径），非战斗系统自有信号
  - Edge cases: 无自有数据信号重复（复用 Cat 1）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat_system/test_phase_transition_signals.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（战斗生命周期——`battle_started`/`battle_ended` 信号在生命周期方法中发射）；Story 001（阶段状态机——`phase_changed` 在 `advance_phase()` 中发射）；Story 003（出牌结算——`attack_resolved`/`character_died` 在攻击/阵亡路径中发射）；ADR-0007（信号分类法——`_emit_signal_safe` 包装器）
- Unlocks: 战斗 UI Epic（CombatUI 订阅 5 个信号刷新）；音频系统（阶段音效/BGM/命中音效）；存档系统（`battle_ended` 触发自动存档）
