# Story 001: 7 阶段回合状态机（advance_phase 确定性推进 + 阶段转换校验）

> **Epic**: combat-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Context

**GDD**: `design/gdd/combat-system.md`
**Requirement**: `TR-combat-001`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0008（战斗系统——7 阶段状态机 + 阶段验证 + 回合编排器）
**ADR Decision Summary**: 战斗系统实现为 Feature 层 Autoload（CombatSystem），管理 7 阶段回合状态机——`advance_phase()` 执行「验证→清理→初始化→推进」的确定性序列。阶段转换通过 `_validate_transition(from, to)` 校验前置条件，失败返回 false 不推进。

**Engine**: Godot 4.6 | **Risk**: LOW（`Node` 场景树编排、信号系统、`_process()` 帧轮询——均为 4.0+ 稳定 API）
**Engine Notes**: 核心编排逻辑不依赖 4.4+ 新 API。`advance_phase()` 每帧调用开销 <0.01ms；自动阶段 `call_deferred()` 推进在连续自动阶段间确实产生恰好 1 帧渲染间隔。

**Control Manifest Rules (Feature 层)**:
- **Required**: 7 阶段战斗状态机：准备(0)→抽牌(1)→出牌(2)→攻击声明(3)→攻击结算(4)→敌方行动(5)→结束(6) —— 来源: ADR-0008
- **Required**: `advance_phase()` 在推进前验证前置条件——不满足时返回 false —— 来源: ADR-0008
- **Required**: 手动阶段（2, 3）需要玩家输入或超时——自动阶段（0,1,4,5,6）使用 `call_deferred()` —— 来源: ADR-0008
- **Forbidden**: 绝不跳过 `advance_phase()` 验证——玩家交互阶段必须先确认再推进 —— 来源: ADR-0008
- **Forbidden**: 绝不使用全局 `randf()` 处理 PRD 效果——每个引擎实例独立 `RandomNumberGenerator` —— 来源: ADR-0009（阶段内效果结算涉及）

---

## Acceptance Criteria

*From ADR-0008 §验证标准 + §关键接口（CombatPhase 枚举 + advance_phase 核心算法）+ GDD §1 完整回合流程 + GDD §2 抽牌规则:*

- [ ] **AC-001**: `CombatPhase` 枚举包含 7 个阶段，取值 PREPARATION(0)→DRAW(1)→PLAY(2)→ATTACK_DECLARATION(3)→ATTACK_RESOLUTION(4)→ENEMY_TURN(5)→END(6)，END 之后回到 PREPARATION
- [ ] **AC-002**: `advance_phase()` 执行确定性序列：`_validate_transition(from, to)`（前置条件检查）→ `_exit_phase(current)`（当前阶段清理）→ `_enter_phase(next)`（下一阶段初始化）→ `GSM._set_battle_phase(next)`（GSM 第二层）→ 发射 `phase_changed`
- [ ] **AC-003**: `advance_phase()` 在验证失败时返回 false + `push_warning`，不推进阶段
- [ ] **AC-004**: `advance_phase()` 在非活跃战斗（`battle.is_active == false`）时返回 false + `push_error`
- [ ] **AC-005**: 阶段 0→1、1→2、4→5、5→6、6→0 无条件自动推进（`_validate_transition` 返回 true）
- [ ] **AC-006**: 阶段 2 PLAY→3 ATTACK_DECLARATION 推进条件为 `player_confirmed_end || timer_exceeded || (hand_empty && !can_afford_any)`
- [ ] **AC-007**: 阶段 3 ATTACK_DECLARATION→4 ATTACK_RESOLUTION 推进条件为 `all_characters_targeted || player_confirmed_skip || attack_queue 为空`
- [ ] **AC-008**: 自动阶段（0,1,4,5,6）通过 `call_deferred()` 下一帧推进（确保每阶段至少 1 帧渲染）
- [ ] **AC-009**: 手动阶段（2,3）不自动推进——等待玩家输入（`confirm_end_turn()` / `confirm_attack_targets()`）或超时计时器
- [ ] **AC-010**: 完整 1 回合流程通过：Phase 0→1→2（手动确认）→3（手动确认）→4→5→6→0
- [ ] **AC-011**: Phase 2 超时（`timer_exceeded`）→ `advance_phase()` 成功推进
- [ ] **AC-012**: Phase 3 空攻击队列（所有己方角色均「待命」或「已行动」）时，`all_characters_targeted()` 空真（vacuously true），系统自动推进——首回合所有角色待命时 Phase 3 自动跳过
- [ ] **AC-013**: 牌库抽空时（`需抽牌但牌库为空`），从弃牌堆随机返还 1 张到牌库底部（GDD §2 抽牌规则）

---

## Implementation Notes

*Derived from ADR-0008 §决策（7 阶段状态机 + 阶段转换验证矩阵 + 准备阶段调度模式）:*

1. **文件位置**: `src/feature/combat_system.gd`（Feature 层，Autoload #9——在 StatusEffectSystem #8 之后、CardEffectEngine #10 之前）
2. **类声明**: `extends Node`（Autoload，不声明 `class_name`——与 CostSystem/RealmSystem 等一致）
3. **CombatPhase 枚举**:
   ```gdscript
   enum CombatPhase {
       PREPARATION = 0,        # 准备阶段
       DRAW = 1,               # 抽牌阶段
       PLAY = 2,               # 出牌阶段（玩家主动）
       ATTACK_DECLARATION = 3, # 攻击声明（玩家主动）
       ATTACK_RESOLUTION = 4,  # 攻击结算（自动）
       ENEMY_TURN = 5,         # 敌方行动（自动）
       END = 6,                # 结束阶段
   }
   ```
4. **advance_phase() 确定性序列**（顺序不可更改）：
   - `_validate_transition(from, to)` → 返回 bool，失败时 `push_warning` 并返回 false，**不推进**
   - `_exit_phase(current)` → 当前阶段清理
   - `_enter_phase(next)` → 下一阶段初始化
   - `GSM._set_battle_phase(next)` → GSM 第二层方法（非直接属性赋值）
   - `_emit_signal_safe(self, &"phase_changed", [old_phase, next, battle.turn])` → Cat 2b 信号
5. **阶段转换验证矩阵**（`_validate_transition(from, to)` 实现）：
   - 0 PREP→1 DRAW、1 DRAW→2 PLAY、4 ATK_RES→5 ENEMY、5 ENEMY→6 END、6 END→0 PREP：无条件返回 true
   - 2 PLAY→3 ATK_DEC：`player_confirmed_end || timer_exceeded || (hand_empty && !can_afford_any())`
   - 3 ATK_DEC→4 ATK_RES：`all_characters_targeted() || player_confirmed_skip || _attack_queue.is_empty()`
6. **自动推进调度**: 自动阶段的 `_enter_phase()` 完成工作后通过 `advance_phase.call_deferred()` 调度下一帧推进——**不使用 while 循环**，避免单帧阻塞主线程。此 `call_deferred()` 用于编排调度（确保每阶段至少 1 帧渲染），而非打破信号链——ADR-0007 允许的合法用法
7. **手动推进**: Phase 2/3 由 UI 事件触发——`confirm_end_turn()`（玩家按「结束回合」）和 `confirm_attack_targets()`（玩家确认攻击目标）调用 `advance_phase()`
8. **编排器模式**: CombatSystem 是编排器——调用子系统（StatusEffectSystem/CardSystem/CostSystem/CardEffectEngine/RealmSystem/AISystem 等），不拥有它们的内部逻辑
9. **Autoload 初始化**: `_ready()` 检查 `GSM._initialized` 标志——未就绪时 `push_error` 并延迟初始化（CombatSystem 必须在所有依赖子系统之后注册）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: 战斗生命周期（`battle_start()` / `battle_end()` + GSM `battle.*` 域初始化与清理）——本 Story 只实现阶段状态机推进逻辑，不实现战斗启动/结束
- **Story 003**: `play_card()` 出牌流程 + 目标解析 + 伤害计算——本 Story 只实现阶段转换，不实现阶段内出牌结算
- **Story 004**: 5 个 Cat 2b 信号的完整声明与信号链深度管理——本 Story 只调用 `phase_changed` 发射点，信号路由细节由 Story 004 实现
- **CombatUI 阶段指示器**: 订阅 `phase_changed` 刷新 UI——战斗 UI Epic 职责

---

## QA Test Cases

*From ADR-0008 §验证标准 + GDD §边缘情况:*

- **AC-001**: CombatPhase 枚举 7 阶段取值
  - Given: CombatSystem 脚本已加载
  - When: 检查 `CombatPhase` 枚举常量值
  - Then: PREPARATION=0, DRAW=1, PLAY=2, ATTACK_DECLARATION=3, ATTACK_RESOLUTION=4, ENEMY_TURN=5, END=6
  - Edge cases: `current + 1` 在 END=6 时回绕到 PREPARATION=0

- **AC-002**: advance_phase 确定性序列
  - Given: 战斗活跃，当前 Phase=0
  - When: 调用 `advance_phase()`
  - Then: 依次执行 `_validate_transition` → `_exit_phase` → `_enter_phase` → `GSM._set_battle_phase(1)` → `phase_changed` 信号发射
  - Edge cases: 验证失败时后续步骤不执行

- **AC-003**: 验证失败返回 false 不推进
  - Given: 战斗活跃，当前 Phase=2（PLAY），未确认结束、未超时、手牌非空
  - When: 调用 `advance_phase()`
  - Then: 返回 false + `push_warning`，阶段仍为 PLAY
  - Edge cases: 失败时不发射 `phase_changed`

- **AC-004**: 非活跃战斗 advance_phase 报错
  - Given: `battle.is_active == false`
  - When: 调用 `advance_phase()`
  - Then: 返回 false + `push_error`（"advance_phase() called with no active battle"）
  - Edge cases: 不修改任何状态

- **AC-005**: 无条件自动推进阶段
  - Given: 战斗活跃，分别在 Phase=0/1/4/5/6
  - When: 调用 `advance_phase()`
  - Then: 均成功推进到下一阶段（0→1、1→2、4→5、5→6、6→0）
  - Edge cases: Phase=6→0 时 `_increment_battle_turn()` 被调用（回合 +1）

- **AC-006**: PLAY→ATTACK_DECLARATION 推进条件
  - Given: 战斗活跃，Phase=2
  - When: 满足 `player_confirmed_end` 或 `timer_exceeded` 或 `hand_empty && !can_afford_any` 任一条件
  - Then: `advance_phase()` 成功推进到 Phase 3
  - Edge cases: 三条件均不满足时返回 false

- **AC-007**: ATTACK_DECLARATION→ATTACK_RESOLUTION 推进条件
  - Given: 战斗活跃，Phase=3
  - When: 满足 `all_characters_targeted` 或 `player_confirmed_skip` 或 `_attack_queue.is_empty()` 任一条件
  - Then: `advance_phase()` 成功推进到 Phase 4
  - Edge cases: 有角色未分配目标且未确认跳过时返回 false

- **AC-008**: 自动阶段 call_deferred 推进
  - Given: 战斗活跃，Phase=0（自动阶段）
  - When: `_enter_phase(0)` 完成其工作
  - Then: 通过 `advance_phase.call_deferred()` 调度下一帧推进，而非同帧立即推进
  - Edge cases: 每阶段至少渲染 1 帧

- **AC-009**: 手动阶段等待输入
  - Given: 战斗活跃，Phase=2（PLAY）
  - When: `_enter_phase(2)` 完成
  - Then: 不自动推进，等待 `confirm_end_turn()` 或超时
  - Edge cases: Phase=3 同理等待 `confirm_attack_targets()`

- **AC-010**: 完整 1 回合流程
  - Given: 战斗活跃，Phase=0，双方均有存活角色
  - When: 依次推进（手动阶段通过 confirm 触发）
  - Then: Phase 0→1→2→3→4→5→6→0 完整通过，`battle.turn` 在 6→0 时递增
  - Edge cases: 任一阶段前置条件不满足时流程在该阶段暂停

- **AC-011**: Phase 2 超时推进
  - Given: 战斗活跃，Phase=2，计时器到达超时阈值
  - When: `timer_exceeded` 置真后调用 `advance_phase()`
  - Then: 成功推进到 Phase 3
  - Edge cases: 默认 PvE 无超时（计时器可配置，仅 PvP 启用）

- **AC-012**: Phase 3 空攻击队列自动跳过
  - Given: 战斗活跃，Phase=3，所有己方角色「待命」或「已行动」（无可攻击角色）
  - When: 调用 `advance_phase()`
  - Then: `all_characters_targeted()` 空真，自动推进到 Phase 4（无需玩家确认）
  - Edge cases: 首回合所有角色待命 → Phase 3 自动跳过（与 GDD §6 一致）

- **AC-013**: 抽空牌库返还
  - Given: 战斗活跃，Phase=1（DRAW），牌库为空且弃牌堆非空
  - When: 需要抽牌
  - Then: 从弃牌堆随机返还 1 张到牌库底部，再抽牌
  - Edge cases: 牌库和弃牌堆均空时不返还也不报错（跳过抽牌）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/combat_system/test_seven_phase_state_machine.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 5 个子系统依赖（CardEffectEngine ADR-0009、DeploymentSystem ADR-0016、BindingManager ADR-0013、FormationSystem ADR-0024、AISystem ADR-0017）——**⚠ 均尚未实现（对应 Epic 状态 Backlog，无 `.gd` 文件，未注册 Autoload）**。状态机 `_enter_phase`/`_exit_phase` 编排这些子系统，完整实现需等待它们就绪；本 Story 可先用桩/接口占位推进纯状态机逻辑
- Unlocks: Story 002（战斗生命周期依赖阶段状态机）、Story 003（play_card 依赖 PLAY 阶段上下文）
