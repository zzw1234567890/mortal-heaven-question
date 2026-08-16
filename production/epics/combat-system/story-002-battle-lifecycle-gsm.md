# Story 002: 战斗生命周期编排（battle_start / battle_end + GSM battle.* 域）

> **Epic**: combat-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-combat-003`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0008（战斗系统——战斗生命周期 + GSM battle.* 域写入所有权例外）
**ADR Decision Summary**: `battle_start(config)` 初始化 battle.* 域 + 备战阶段 + 快照 + 开始回合；`battle_end(result)` 防御清理 + 发射奖励/损失结算 + 清理 battle 域 + 场景切换。CombatSystem 是 GSM `battle.*` 域的独占运行时写入者（ADR-0001 委托例外），通过 GSM 第二层方法写入。

**Engine**: Godot 4.6 | **Risk**: MEDIUM（Autoload 初始化顺序依赖 9 个子系统；战斗快照写入 <50ms 依赖 FileAccess 原子写入）
**Engine Notes**: 战斗快照用 ADR-0002 的 JSON 原子写入策略（`.tmp` 文件 → `rename_absolute()` → `.bak` 备份）；`_ready()` 检查 `GSM._initialized` 标志缓解 Autoload 顺序依赖。

**Control Manifest Rules (Feature 层)**:
- **Required**: 所有游戏状态写入必须通过 GSM 第二层原子方法 —— 来源: ADR-0001
- **Required**: HP/费用变化通过 GSM Cat 1 `batch_updated` 传播 —— 来源: ADR-0008
- **Required**: 所有场景转换必须通过 `SceneManager.request_scene_change()` —— 来源: ADR-0005
- **Required**: Cat 2 信号必须通过 `_emit_signal_safe()` 包装器路由 —— 来源: ADR-0007
- **Forbidden**: 绝不在 Phase 6 清理完成前调用 `battle_end()` —— 来源: ADR-0008

---

## Acceptance Criteria

*From ADR-0008 §验证标准 + §决策（战斗生命周期 + GSM battle.* 域写入所有权例外）+ GDD §9 战斗结束规则 + GDD §状态与转换:*

- [ ] **AC-001**: `battle_start(config)` 初始化 battle.* 域——phase=PREPARATION, turn=1, is_active=true
- [ ] **AC-002**: `battle_start(config)` 调用 `GSM._set_battle_active(true)` 创建 battle 域（而非直接写属性）
- [ ] **AC-003**: `battle_start(config)` 发射 `battle_started` 信号（Cat 2b，通过 `_emit_signal_safe`）——载荷为 config Dictionary
- [ ] **AC-004**: `battle_start(config)` 创建战斗快照——`SaveLoad.create_battle_snapshot(GSM.serialize())`
- [ ] **AC-005**: `battle_start(config)` 推入输入锁——`InputManager.push_lock(ANIMATION, &"combat_system")`
- [ ] **AC-006**: `battle_start(config)` 完成后调用 `advance_phase(PREPARATION)` 开始第一个回合
- [ ] **AC-007**: 需要新增 3 个 GSM 第二层方法：`_set_battle_phase(phase: int)`、`_increment_battle_turn()`、`_set_battle_active(active: bool)`
- [ ] **AC-008**: `battle_end(VICTORY)` 调用 `GSM.apply_battle_rewards(lingshi, cultivation, cards)`——参数正确
- [ ] **AC-009**: `battle_end(DEFEAT)` 保留 50% 资源——`GSM.add_resource("ling_shi", retain_50%)` 和 `GSM.add_cultivation(retain_50%)` 被调用且参数正确
- [ ] **AC-010**: `battle_end(RETREAT)` 语义与 DEFEAT 相同——50% 保留
- [ ] **AC-011**: `battle_end(result)` 入口处防御清理——`_attack_queue.clear()` + `InputManager.clear_locks(&"combat_system")` + `_is_active = false`
- [ ] **AC-012**: `battle_end(result)` 调用 `GSM._set_battle_active(false)` 清理 battle.* 域（设为 null）
- [ ] **AC-013**: `battle_end(result)` 发射 `battle_ended` 信号（Cat 2b）——载荷为 `(result, rewards)`，在清理 battle 域之前发射
- [ ] **AC-014**: `battle_end(VICTORY)` 调用 `SaveLoad.clear_battle_snapshot()` 清理快照
- [ ] **AC-015**: `battle_end(result)` 调用 `SceneManager.request_scene_change(COMBAT, target_scene)` 切换场景
- [ ] **AC-016**: `retreat()` 在 `battle.is_active == false` 时返回而不修改状态
- [ ] **AC-017**: `retreat()` 在 `battle.is_active == true` 时发射确认提示信号（Cat 2b）——UI 展示确认弹窗，玩家确认后调用 `battle_end(RETREAT)`

---

## Implementation Notes

*Derived from ADR-0008 §决策（战斗生命周期 + GSM battle.* 域写入所有权例外）:*

1. **文件位置**: `src/feature/combat_system.gd`（与 Story 001 同文件——本 Story 实现生命周期方法）
2. **新增 GSM 第二层方法**（在 `game_state_manager.gd` 中）:
   ```gdscript
   GSM._set_battle_phase(phase: int) → void
     # 写入 battle.phase = phase + 发射 batch_updated({"battle.phase": {old, new}})

   GSM._increment_battle_turn() → void
     # battle.turn += 1 + 发射 batch_updated({"battle.turn": {old, new}})

   GSM._set_battle_active(active: bool) → void
     # 写入 battle.is_active = active + 发射 batch_updated({"battle.is_active": {old, new}})
     # active=false 时同时清理 battle.* 域（设为 null）
   ```
3. **battle_start(config: CombatConfig) 流程**（顺序）:
   - config = `{enemy_deck_id, tribulation_level, is_tribulation}`
   - `GSM._set_battle_active(true)` → 创建 battle 域（phase=PREPARATION, turn=1, player_field=[], enemy_field=[], result=null）
   - 初始化首回合状态：上场角色标记「待命」+ 设置 `battle.max_cost`（从 RealmSystem 读境界费用上限）+ `battle.current_cost = battle.max_cost` + `battle.current_hand`（先手 4/后手 5）
   - 加载敌人卡组 → 初始化 enemy_field
   - 从 DeploymentSystem 获取上场角色 → 初始化 player_field
   - `SaveLoad.create_battle_snapshot(GSM.serialize())`
   - `InputManager.push_lock(ANIMATION, &"combat_system")`
   - 发射 `battle_started.emit(config)`（Cat 2b，通过 `_emit_signal_safe`）
   - `advance_phase(PREPARATION)`
4. **battle_end(result: CombatResult) 流程**（顺序）:
   - 入口防御清理：`_attack_queue.clear()` + `InputManager.clear_locks(&"combat_system")` + `_is_active = false`
   - VICTORY：`GSM.apply_battle_rewards(...)` + `CardRewardSystem.trigger_loot_selection()` + `SaveLoad.clear_battle_snapshot()`
   - DEFEAT：`GSM.add_resource("ling_shi", retain_50%)` + `GSM.add_cultivation(retain_50%)`（阵亡角色绑定卡永久失去已在阵亡触发时处理）
   - RETREAT：语义同 DEFEAT（50% 保留）
   - `GSM._set_battle_active(false)` → 清理 battle 域为 null
   - 发射 `battle_ended.emit(result, rewards)`（Cat 2b）——在清理 battle 域之前发射
   - `SceneManager.request_scene_change(COMBAT, target_scene)`
5. **CombatResult 枚举**:
   ```gdscript
   enum CombatResult {
       NONE = 0,
       VICTORY = 1,   # 敌方全灭
       DEFEAT = 2,    # 己方全灭
       RETREAT = 3,   # 玩家撤退（DEFEAT 语义）
   }
   ```
6. **retreat() 流程**: `battle.is_active == false` → 直接返回；否则发射确认提示信号 → UI 弹窗 → 玩家确认 → `battle_end(RETREAT)`；玩家取消 → 恢复正常游戏
7. **GSM 写入所有权**: CombatSystem 是 `GSM.battle.*` 域独占运行时写入者——所有写入通过 GSM 第二层方法（`_set_battle_phase`/`_increment_battle_turn`/`_set_battle_active`），绝不直接属性赋值
8. **信号路由**: `battle_started` 和 `battle_ended` 均通过 `_emit_signal_safe`（ADR-0007）路由

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: 7 阶段状态机 + `advance_phase()` 确定性推进 + 阶段转换校验
- **Story 003**: `play_card()` 出牌 + 目标解析 + 伤害计算——本 Story 只实现生命周期，不实现阶段内出牌结算
- **Story 004**: 5 个 Cat 2b 信号的完整声明与信号链深度管理——本 Story 只实现 `battle_started`/`battle_ended` 两个信号的发射点
- **CombatUI 初始化/结算界面**: 订阅 `battle_started`/`battle_ended` 刷新 UI——战斗 UI Epic 职责
- **CardRewardSystem 战利品三选一**: `trigger_loot_selection()` 内部实现——卡牌奖励系统职责

---

## QA Test Cases

*From ADR-0008 §验证标准 + GDD §9 战斗结束规则 + GDD §边缘情况（撤退后状态）:*

- **AC-001**: battle_start 初始化 battle 域
  - Given: 战斗未开始，所有依赖子系统已就绪
  - When: `combat.battle_start({enemy_deck_id="test_deck", tribulation_level=1, is_tribulation=false})`
  - Then: `battle.phase == PREPARATION` + `battle.turn == 1` + `battle.is_active == true`
  - Edge cases: 重复 `battle_start`（战斗已活跃）应拒绝或重置

- **AC-002**: GSM._set_battle_active 创建 battle 域
  - Given: `battle.is_active == false`
  - When: `GSM._set_battle_active(true)`
  - Then: `GSM.battle` 域非空，`is_active == true`
  - Edge cases: 通过 `_buffer_change` 管线 + `batch_updated` 发射（ADR-0001 模式）

- **AC-003**: battle_started 信号发射
  - Given: 监听 `battle_started` 信号
  - When: `combat.battle_start(config)`
  - Then: `battle_started` 发射一次，载荷为 config Dictionary
  - Edge cases: 信号通过 `_emit_signal_safe` 路由（ADR-0007）

- **AC-004**: 战斗快照创建
  - Given: SaveLoad 可用
  - When: `combat.battle_start(config)`
  - Then: `SaveLoad.create_battle_snapshot(GSM.serialize())` 被调用
  - Edge cases: 快照创建失败不阻塞战斗启动（记录错误）

- **AC-005**: 输入锁推入
  - Given: InputManager 可用
  - When: `combat.battle_start(config)`
  - Then: `InputManager.push_lock(ANIMATION, &"combat_system")` 被调用
  - Edge cases: 锁来源标识为 `&"combat_system"`（StringName）

- **AC-006**: battle_start 调用 advance_phase
  - Given: 战斗启动完成
  - When: 检查阶段
  - Then: `advance_phase(PREPARATION)` 被调用，开始第一个回合
  - Edge cases: 首次推进从 PREPARATION 开始

- **AC-007**: GSM 第二层方法存在
  - Given: `game_state_manager.gd` 已更新
  - When: 检查方法存在性
  - Then: `_set_battle_phase(phase: int)`、`_increment_battle_turn()`、`_set_battle_active(active: bool)` 均存在
  - Edge cases: 三个方法均通过 `_buffer_change` 管线发射 `batch_updated`

- **AC-008**: battle_end(VICTORY) 调用 apply_battle_rewards
  - Given: 战斗活跃，`battle_end(VICTORY)` 被调用
  - When: 检查 GSM
  - Then: `GSM.apply_battle_rewards(lingshi, cultivation, cards)` 被调用且参数正确
  - Edge cases: rewards 参数从战斗结算结果派生

- **AC-009**: battle_end(DEFEAT) 保留 50% 资源
  - Given: 战斗活跃，`battle_end(DEFEAT)` 被调用
  - When: 检查 GSM
  - Then: `GSM.add_resource("ling_shi", 50%)` + `GSM.add_cultivation(50%)` 被调用且参数为 50%
  - Edge cases: 保留比例通过探索系统公式（exploration-system.md §公式 11）

- **AC-010**: battle_end(RETREAT) 语义同 DEFEAT
  - Given: 战斗活跃，`battle_end(RETREAT)` 被调用
  - When: 检查 GSM
  - Then: 与 DEFEAT 相同——50% 保留
  - Edge cases: RETREAT 保留非绑定物品（秘境中撤退规则）

- **AC-011**: battle_end 入口防御清理
  - Given: 战斗活跃，`_attack_queue` 非空，输入锁已推入
  - When: `battle_end(result)` 被调用
  - Then: `_attack_queue` 清空 + `InputManager.clear_locks(&"combat_system")` + `_is_active == false`
  - Edge cases: 从任意阶段调用 battle_end 均执行防御清理（Phase 4/5 中途调用不残留）

- **AC-012**: GSM._set_battle_active(false) 清理 battle 域
  - Given: 战斗活跃，`battle_end(result)` 被调用
  - When: 检查 GSM
  - Then: `battle` 域设为 null，`batch_updated({"battle": {old, null}})` 发射
  - Edge cases: 清理后其他系统读取 `battle` 域返回 null

- **AC-013**: battle_ended 信号发射
  - Given: 监听 `battle_ended` 信号
  - When: `battle_end(result)` 被调用
  - Then: `battle_ended` 发射一次，载荷 `(result, rewards)`，发射时机在清理 battle 域之前
  - Edge cases: 信号通过 `_emit_signal_safe` 路由

- **AC-014**: VICTORY 清理快照
  - Given: 战斗快照已创建，`battle_end(VICTORY)` 被调用
  - When: 检查 SaveLoad
  - Then: `SaveLoad.clear_battle_snapshot()` 被调用
  - Edge cases: DEFEAT/RETREAT 不清理快照（保留用于失败分析）——按 ADR 意图

- **AC-015**: battle_end 切换场景
  - Given: 战斗结束
  - When: `battle_end(result)` 完成
  - Then: `SceneManager.request_scene_change(COMBAT, target_scene)` 被调用
  - Edge cases: 绝不直接调用 `get_tree().change_scene_to_file()`（ADR-0005）

- **AC-016**: retreat 无活跃战斗返回
  - Given: `battle.is_active == false`
  - When: `retreat()` 被调用
  - Then: 直接返回，不修改任何状态
  - Edge cases: 不发射确认提示信号

- **AC-017**: retreat 有活跃战斗发射确认
  - Given: `battle.is_active == true`
  - When: `retreat()` 被调用
  - Then: 发射确认提示信号（Cat 2b），UI 展示弹窗；确认后 `battle_end(RETREAT)` 被调用
  - Edge cases: 玩家取消 → 恢复正常游戏（不调用 battle_end）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/combat_system/test_battle_lifecycle_gsm.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（7 阶段状态机——`battle_start` 末尾调用 `advance_phase(PREPARATION)`）；GSM（ADR-0001——battle.* 域写入所有权）、SaveLoad（ADR-0002——快照）、InputManager（ADR-0004——锁）、SceneManager（ADR-0005——场景切换）均已就绪
- Unlocks: Story 004（阶段转换信号通知 CombatUI——依赖 battle 生命周期上下文）
