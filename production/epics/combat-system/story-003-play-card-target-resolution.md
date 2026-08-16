# Story 003: play_card 出牌 + 目标解析 + 自动推进调度

> **Epic**: combat-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-combat-002`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0008（战斗系统——出牌结算流程 Phase 2 核心交互 + 子系统编排顺序）
**ADR Decision Summary**: `play_card(card_instance_id, target_indices)` 执行「费用验证 → 目标验证 → 扣费 → 效果结算 → 阵亡检查 → 自动推进判定」的确定性流程。伤害计算 `max(1, ATK - DEF) × realm_penalty`，realm_penalty 来自 `RealmSystem.get_suppression(attacker, defender)`。

**Engine**: Godot 4.6 | **Risk**: LOW（`CostSystem.can_afford()` O(1) 整数比较、`RealmSystem.get_suppression()` O(1) 双重字典查询——均为 4.0+ 稳定 API）
**Engine Notes**: 出牌结算在热路径（Phase 2 每次出牌）——费用校验 <0.001ms；伤害计算 <0.01ms；CardEffectEngine.resolve() <2ms（ResolutionStack + 触发链）。

**Control Manifest Rules (Feature 层)**:
- **Required**: CombatSystem 通过直接方法调用编排子系统——非信号 —— 来源: ADR-0008
- **Required**: HP/费用变化通过 GSM Cat 1 `batch_updated` 传播 —— 来源: ADR-0008
- **Required**: 所有费用检查通过 `CostSystem.can_afford(n)` —— O(1) 整数比较 —— 来源: ADR-0015
- **Forbidden**: 绝不绕过 `CostSystem.can_afford()` 进行消费 —— 来源: ADR-0015
- **Forbidden**: 绝不让 CardEffectEngine 直接写 GSM —— 所有效果通过子系统接口执行 —— 来源: ADR-0009

---

## Acceptance Criteria

*From ADR-0008 §验证标准 + §决策（出牌结算流程 Phase 2 核心交互）+ GDD §4 出牌规则 + GDD §8 境界压制规则 + GDD §公式（伤害公式 + 境界压制公式）:*

- [ ] **AC-001**: `play_card(card_instance_id, target_indices)` 在非 PLAY 阶段被调用时返回 false + `push_warning`
- [ ] **AC-002**: `play_card` 先执行费用验证——`CostSystem.can_afford(card.template.cost)` 不通过则返回 false（不扣费、不结算）
- [ ] **AC-003**: `play_card` 执行目标验证——`CardEffectEngine.validate_targets(card.template, targets)` 不通过则返回 false
- [ ] **AC-004**: `play_card` 通过验证后执行扣费——`CostSystem.spend(card.template.cost)`
- [ ] **AC-005**: `play_card` 执行效果结算——`CardEffectEngine.resolve(card, targets)`，返回结果列表
- [ ] **AC-006**: `play_card` 在效果结算后检查阵亡——`_check_and_process_deaths()` 处理角色 HP ≤ 0
- [ ] **AC-007**: `play_card` 在满足 `hand_empty && !can_afford_any` 时自动调用 `advance_phase()`（空手牌 + 无费可出 → 自动结束出牌）
- [ ] **AC-008**: 伤害计算 `max(1, attacker_ATK - target_DEF)`——最低 1 点伤害（0 防御时伤害 = ATK）
- [ ] **AC-009**: 伤害经境界压制修正 `final_damage = floor(actual_damage × realm_penalty)`——realm_penalty 来自 `RealmSystem.get_suppression(attacker, defender)`
- [ ] **AC-010**: 玩家攻击高 1 级敌人时 realm_penalty = 0.8（伤害显示 80%）
- [ ] **AC-011**: 敌人高玩家 2 级及以上时 realm_penalty = 0.5（伤害显示 50%）
- [ ] **AC-012**: 同境界或低于时 realm_penalty = 1.0（无压制）

---

## Implementation Notes

*Derived from ADR-0008 §决策（出牌结算流程 Phase 2 核心交互）+ §关键接口（play_card 核心算法）+ GDD §公式:*

1. **文件位置**: `src/feature/combat_system.gd`（与 Story 001/002 同文件——本 Story 实现 `play_card()` 方法）
2. **play_card(card_instance_id: int, target_indices: Array[int]) 确定性流程**（顺序不可更改）:
   - 阶段守卫：`battle.phase != CombatPhase.PLAY` → `push_warning` + 返回 false
   - 卡牌获取：`CardSystem.get_instance(card_instance_id)` → null 则返回 false
   - 费用验证：`CostSystem.can_afford(card.template.cost)` → false 则返回 false
   - 目标解析：`_resolve_targets(card.template, target_indices)` → `CardEffectEngine.validate_targets(card.template, targets)` → false 则返回 false
   - 扣费：`CostSystem.spend(card.template.cost)`（直接调用——需要保证）
   - 结算：`CardEffectEngine.resolve(card, targets)`（直接调用——需要结果列表）
   - 阵亡检查：`_check_and_process_deaths()`
   - 自动推进判定：`hand_empty && !can_afford_any` → `advance_phase()`
3. **伤害计算公式**（GDD §1 + §2）:
   ```gdscript
   actual_damage = max(1, attacker_ATK - target_DEF)
   final_damage = floor(actual_damage × realm_penalty)
   # realm_penalty = RealmSystem.get_suppression(attacker, defender)
   #   同境界或低于 = 1.0；敌方高 1 级 = 0.8；敌方高 2 级及以上 = 0.5
   ```
4. **直接方法调用（非信号）**:
   - `CostSystem.spend(n)` — 需要返回值（bool——费用是否足够）
   - `CardEffectEngine.resolve(card, target)` — 需要结果（效果结算结果列表）
   - `RealmSystem.get_suppression(attacker, defender)` — 需要返回值（float 系数）
5. **数据变更传播**: 费用变更通过 `GSM._set_battle_cost()` → `batch_updated({"battle.current_cost": {old, new}})`（Cat 1）；HP 变更通过 `GSM.batch_updated({"battle.player_field[2].hp": {old, new}})`（Cat 1）——非战斗系统自有信号
6. **目标解析**: 角色卡目标为己方空闲阵位；功法/法宝卡目标为场上己方角色；丹药卡目标为己方角色/全体；符箓卡目标按卡牌描述（己方/敌方）——由 CardEffectEngine 验证目标合法性
7. **境界压制只影响基础攻防和伤害计算，不影响卡牌天赋效果**（GDD §8 设计约束）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: 7 阶段状态机推进逻辑——本 Story 只实现出牌结算流程，阶段推进复用 Story 001 的 `advance_phase()`
- **Story 002**: 战斗生命周期——本 Story 不实现 battle_start/battle_end
- **Story 004**: 5 个 Cat 2b 信号（含 `attack_resolved`、`character_died`）的完整声明与信号链深度管理——本 Story 在阵亡检查时调用发射点，信号路由细节由 Story 004 实现
- **CardEffectEngine 效果解析内部逻辑**: `resolve()` 内部结算细节（ResolutionStack、触发链、优先级）——卡牌效果引擎 Epic 职责
- **CombatUI 出牌拖拽交互**: 玩家拖拽出牌的 UI 逻辑——战斗 UI Epic 职责

---

## QA Test Cases

*From ADR-0008 §验证标准 + GDD §公式（伤害示例）+ GDD §边缘情况:*

- **AC-001**: 非 PLAY 阶段调用 play_card 拒绝
  - Given: 战斗活跃，`battle.phase != PLAY`（如 DRAW 阶段）
  - When: `combat.play_card(card_id, [target])`
  - Then: 返回 false + `push_warning`（"play_card() called outside PLAY phase"）
  - Edge cases: 不扣费、不结算、不修改状态

- **AC-002**: 费用不足拒绝
  - Given: 战斗活跃，Phase=PLAY，`CostSystem.can_afford(card.cost)` 返回 false
  - When: `combat.play_card(card_id, [target])`
  - Then: 返回 false，不扣费、不结算
  - Edge cases: 费用验证在任何其他操作之前执行

- **AC-003**: 目标验证失败拒绝
  - Given: 战斗活跃，Phase=PLAY，费用充足，目标非法
  - When: `combat.play_card(card_id, [invalid_target])`
  - Then: 返回 false，`CardEffectEngine.validate_targets` 返回 false
  - Edge cases: 目标解析后验证不通过不扣费

- **AC-004**: 扣费执行
  - Given: 战斗活跃，Phase=PLAY，费用充足，目标合法
  - When: `combat.play_card(card_id, [target])`
  - Then: `CostSystem.spend(card.cost)` 被调用
  - Edge cases: 扣费通过直接方法调用（需要保证）

- **AC-005**: 效果结算执行
  - Given: 扣费成功后
  - When: 结算
  - Then: `CardEffectEngine.resolve(card, targets)` 被调用，返回结果列表
  - Edge cases: 结果列表为非空 Array[Dictionary]

- **AC-006**: 阵亡检查
  - Given: 效果结算可能导致角色 HP ≤ 0
  - When: 结算完成
  - Then: `_check_and_process_deaths()` 被调用，处理阵亡
  - Edge cases: 无阵亡时不触发死亡效果

- **AC-007**: 空手牌自动推进
  - Given: 出牌后 `hand_empty == true` 且 `can_afford_any == false`
  - When: `play_card` 完成
  - Then: `advance_phase()` 被调用（自动结束出牌）
  - Edge cases: 手牌非空或有可出牌时不自动推进

- **AC-008**: 伤害公式（0 防御）
  - Given: 攻击者 ATK=4，目标 DEF=0
  - When: 计算伤害
  - Then: `actual_damage = max(1, 4-0) = 4`
  - Edge cases: ATK - DEF < 1 时伤害 = 1（最低保底）

- **AC-009**: 境界压制伤害修正
  - Given: actual_damage 已知，realm_penalty 从 `RealmSystem.get_suppression` 返回
  - When: 计算 final_damage
  - Then: `final_damage = floor(actual_damage × realm_penalty)`
  - Edge cases: 伤害取整（floor）

- **AC-010**: 高 1 级敌人压制
  - Given: 玩家攻击高 1 级敌人，ATK=4, DEF=0
  - When: 伤害结算
  - Then: `realm_penalty = 0.8`，`final_damage = floor(4 × 0.8) = 3`（伤害显示 80%）
  - Edge cases: 取整后最低 1 点伤害

- **AC-011**: 高 2 级及以上压制
  - Given: 炼气期玩家攻击金丹期敌人（高 2 级），ATK=4, DEF=0
  - When: 伤害结算
  - Then: `realm_penalty = 0.5`，`final_damage = floor(4 × 0.5) = 2`（伤害显示 50%）
  - Edge cases: GDD 公式示例验证（4 × 0.5 = 2）

- **AC-012**: 同境界无压制
  - Given: 攻击者与目标同境界或低于
  - When: 伤害结算
  - Then: `realm_penalty = 1.0`，`final_damage = actual_damage`
  - Edge cases: 无压制系数修正

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat_system/test_play_card_target_resolution.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（7 阶段状态机——`play_card` 依赖 PLAY 阶段上下文 + 末尾调用 `advance_phase()`）；CardSystem（ADR-0006）与 CostSystem（ADR-0015）已就绪；**⚠ CardEffectEngine（ADR-0009）尚未实现（Epic Backlog）**——`validate_targets`/`resolve` 需等待；**⚠ RealmSystem（ADR-0010）有 `.gd` 文件但未注册为 Autoload**——`get_suppression` 需注册后方可调用
- Unlocks: Story 004（阶段转换信号中 `attack_resolved`/`character_died` 在出牌/攻击结算路径中发射）
