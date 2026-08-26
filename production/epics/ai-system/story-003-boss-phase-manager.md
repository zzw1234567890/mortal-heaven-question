# Story 003: BossPhaseMgr 阶段转换内部状态机

> **Epic**: AI 系统（敌方 AI） (ai-system)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Context

**GDD**: `design/gdd/ai-system.md`
**Requirement**: `TR-ai-003`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0017（AI 系统 — Feature 层独立 Autoload + 效果引擎统一路径 + Boss 内部阶段状态机）
**ADR Decision Summary**: Boss 阶段转换由 AI 系统内部状态机管理——CombatSystem 仅在 Phase 6 调用 `execute_turn()`，AI 在决策前自主检查并触发阶段转换。HP 阈值触发 → 行为配置替换 → 技能解锁/锁定 → 冷却重置 → 无敌帧 → `boss_phase_transitioned` 信号。击杀优先（is_alive 才检查转换）；阶段转换回合不进行其他行动。

**Engine**: Godot 4.6 | **Risk**: LOW（内部状态机为纯逻辑，信号系统 4.x 成熟 API）
**Engine Notes**: Boss 阶段转换动画期间的 `call_deferred()` 延迟与 CombatSystem Phase 6 交互需 GUT 集成测试（ADR-0017 §需要验证）。

**Control Manifest Rules (Feature 层)**:
- **Required**: Boss 阶段转换——AISystem 内部状态机，HP 阈值触发（来源：ADR-0017）
- **Required**: `boss_phase_transitioned` 为 Cat 2b 信号，通过 `_emit_signal_safe` 路由（来源：ADR-0007, ADR-0017）
- **Forbidden**: 绝不绕过内部状态机让 CombatSystem 掌握 Boss 转换细节——信息隐藏（来源：ADR-0017 §替代方案 D 拒绝原因）
- **Guardrail**: 阶段转换在 Phase 6 单帧内完成，不额外增加帧预算（来源：ADR-0017 §性能影响）

---

## Acceptance Criteria

*From ADR-0017 §决策引擎设计 ② + GDD ai-system.md §7（Boss 阶段转换）+ §公式 4 + §边缘情况 + §验收标准:*

- [x] **AC-001**: `BossPhaseMgr` 内部状态机组件——`check()`（检测触发）、`transition()`（执行转换）、`get_phase()`（查询当前阶段索引）
- [x] **AC-002**: Boss HP 降到阈值（hp_below）以下 → 触发转换 + `behavior_profile` 替换为新阶段 `behavior_override`
- [x] **AC-003**: 转换时执行 `skill_unlock`（解锁新技能加入技能池）+ `skill_remove`（锁定旧技能从技能池移除）
- [x] **AC-004**: `reset_cooldowns=true` 时 → `skill_cooldowns.clear()`（所有技能冷却重置）
- [x] **AC-005**: `heal_percent>0` 时 → `current_hp += round(max_hp × heal_percent)`
- [x] **AC-006**: 转换完成发射 `boss_phase_transitioned(enemy_id, from_phase, to_phase)` 信号（通过 `_emit_signal_safe` 路由）
- [x] **AC-007**: 击杀优先——仅在 `is_alive` 为 true 时检查阶段转换；转换触发瞬间被击杀 → 不触发转换，Boss 正常阵亡
- [x] **AC-008**: 每个转换条件只触发一次——`triggered_transitions` 记录已触发索引，触发后锁定（防血量波动重复触发）
- [x] **AC-009**: 每个 Boss 最多 3 个阶段（起始阶段 + 2 个转换）——`phase_transitions` 数组长度上限 2
- [x] **AC-010**: `should_transition(boss, turn, hp_pct)` 公式——`(hp_below > 0 AND hp_pct <= hp_below) OR (turn_after > 0 AND turn >= turn_after)` 且 `not triggered` 时返回阶段索引，否则 -1
- [x] **AC-011**: 回合兜底触发（turn_after）——配置 `turn_after > 0` 的 Boss 回合数到达时即使血量未到阈值也触发阶段转换（OR 语义，防拖回合）；通用 Boss 配置 `turn_after=0` 时不启用回合兜底，仅按 HP 阈值转换
- [x] **AC-012**: 阶段转换回合不进行其他行动——触发转换后 return，跳过技能评估与目标选择
- [x] **AC-013**: Boss 所有阶段已触发完毕 → 保持最终阶段行为模式（不再检查转换）

---

## Implementation Notes

*Derived from ADR-0017 §决策引擎设计 ② + GDD ai-system.md §7 + §公式 4:*

1. **BossPhaseMgr 组件**（ADR-0017 §架构图）：作为 AISystem 内部组件实现（非独立 Autoload），持有当前阶段索引查询与转换执行逻辑。方法签名：`check(boss, turn, hp_pct) -> int`（返回待触发阶段索引，-1 无）、`transition(boss, phase_index) -> void`、`get_phase(boss) -> int`
2. **转换执行顺序**（ADR §决策引擎设计 ②）：
   1. 标记 `triggered_transitions` 防重复
   2. 替换 `behavior_profile = new_phase.behavior_override`
   3. 解锁/锁定技能（skill_unlock / skill_remove）
   4. `if reset_cooldowns: skill_cooldowns.clear()`
   5. `if heal_percent > 0: current_hp += round(max_hp * heal_percent)`
   6. 发射 `boss_phase_transitioned` → CombatSystem 播放转换动画
   7. return（阶段转换回合不进行其他行动）
3. **触发检测**（GDD §公式 4，OR 语义 + 显式哨兵）：遍历 `phase_transitions`，`(hp_below > 0 AND hp_pct <= hp_below) OR (turn_after > 0 AND turn >= turn_after)` 且 `not triggered` → 返回阶段索引。`0 = 禁用`哨兵防止 `turn_after=0` 时首回合误触发
4. **击杀优先**（ADR §解决的 GDD 需求）：`_check_phase_transition()` 仅在 `enemy.is_alive` 为 true 时执行——同一帧被击杀则不触发
5. **无敌帧**：转换动画期间 Boss 免疫伤害——由 CombatSystem 响应 `boss_phase_transitioned` 设置 `is_phase_transition_animating=true` 实现（本 Story 只发射信号，无敌帧锁定属战斗 Epic 职责）
6. **阶段上限**：`phase_transitions` 最多 2 项（起始阶段 + 2 转换 = 3 阶段），超出在加载/编辑时校验
7. **Cat 2b 信号路由**：`boss_phase_transitioned` 通过 `_emit_signal_safe` 包装器发射（ADR-0007）
8. **测试模式**：BossPhaseMgr 为纯逻辑状态机，用脚本内构造的 EnemyBattleState + BossPhaseTransition 直接单测，无需完整战斗

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: EnemyTemplate/EnemyBattleState 模型（含 `current_phase_index` / `triggered_transitions` 字段）——已实现
- **Story 002**: execute_turn 决策主循环——本 Story 只实现 `_check_phase_transition()` 钩子的内部逻辑，Story 002 在 Boss 分支最先调用它
- **转换动画/无敌帧表现**: CombatSystem 响应 `boss_phase_transitioned` 播放动画 + 设置无敌帧锁——战斗 Epic（ADR-0008）职责
- **CombatUI**: Boss 阶段指示器 + 全屏提示 + 阶段名显示——战斗 UI Epic 职责
- **动画/音乐资源**: 转换动画资源选择（通用模板 vs 独享）——美术/音频预生产决策（GDD §待解决问题 #3）

---

## QA Test Cases

*From ADR-0017 §验证标准 + GDD ai-system.md §7 + §边缘情况 + §验收标准:*

- **AC-001**: BossPhaseMgr 组件存在
  - Given: AISystem 已加载
  - When: 检查 BossPhaseMgr 方法
  - Then: 含 `check()` / `transition()` / `get_phase()`
  - Edge cases: get_phase 默认返回 current_phase_index=0

- **AC-002**: HP 阈值触发 + 行为替换
  - Given: Boss 有 phase_transition（hp_below=0.5, behavior_override=aggressive），current_hp/max_hp 使 hp_pct=0.4
  - When: `mgr.check(boss, turn, 0.4)`
  - Then: 返回该阶段索引；`transition()` 后 behavior_profile==aggressive
  - Edge cases: hp_pct 恰好等于 0.5 → 触发（`<=`）

- **AC-003**: 技能解锁/锁定
  - Given: phase_transition 含 skill_unlock=["夺命爪·强化"] + skill_remove=["夺命爪"]
  - When: `transition()`
  - Then: 技能池含"夺命爪·强化"，不含"夺命爪"
  - Edge cases: skill_unlock 为空数组 → 不增不减

- **AC-004**: 冷却重置
  - Given: Boss 技能有剩余冷却，reset_cooldowns=true
  - When: `transition()`
  - Then: skill_cooldowns 全部清零
  - Edge cases: reset_cooldowns=false → 冷却保持

- **AC-005**: 转换回血
  - Given: heal_percent=0.1, max_hp=100, current_hp=40
  - When: `transition()`
  - Then: current_hp == 50（40 + round(100×0.1)）
  - Edge cases: heal_percent=0 → 不回血

- **AC-006**: boss_phase_transitioned 信号
  - Given: 转换触发，监听 boss_phase_transitioned
  - When: `transition()`
  - Then: 信号发射，载荷 (enemy_id, from_phase=0, to_phase=1)
  - Edge cases: 信号通过 _emit_signal_safe 路由

- **AC-007**: 击杀优先
  - Given: Boss is_alive=false（同帧被击杀），hp_pct 已低于阈值
  - When: `_check_phase_transition()`
  - Then: 不触发转换，Boss 正常阵亡
  - Edge cases: 转换检查前先判 is_alive

- **AC-008**: 防重复触发
  - Given: 阶段 1 已触发（triggered_transitions 含索引 0）
  - When: hp_pct 反复低于阈值再次 check
  - Then: 不再返回已触发索引
  - Edge cases: 血量波动跨阈值线不重复转换

- **AC-009**: 最多 3 阶段
  - Given: Boss phase_transitions 数组
  - When: 加载/校验
  - Then: 数组长度 ≤ 2（起始阶段 + 2 转换 = 3 阶段）
  - Edge cases: 超出上限 → push_warning 或校验失败

- **AC-010**: should_transition 公式（OR + 哨兵）
  - Given: phase（hp_below=0.5, turn_after=0）
  - When: (turn=3, hp_pct=0.4) / (turn=3, hp_pct=0.7)
  - Then: 分别返回 阶段索引（HP 触发）/ -1（HP 未达标且回合兜底禁用）
  - Edge cases: hp 与 turn 条件满足其一即可（OR）；`hp_below=0` 或 `turn_after=0` 时对应触发器禁用；`hp_pct == hp_below` 时触发（`<=`）

- **AC-011**: 回合兜底触发
  - Given: phase（hp_below=0.5, turn_after=8），turn=9 但 hp_pct=0.7
  - When: `should_transition()`
  - Then: 返回阶段索引（回合兜底触发，即使血量未到阈值，防拖回合）
  - Edge cases: 触发条件为 hp OR turn（满足其一即可）；`turn_after=0` 时禁用回合兜底

- **AC-012**: 转换回合不行动
  - Given: Boss 触发阶段转换
  - When: execute_turn 中 Boss 分支
  - Then: 转换后 return，该 Boss 不产出技能行动 AIAction
  - Edge cases: 转换回合仅发射信号，无技能结算

- **AC-013**: 最终阶段保持
  - Given: Boss 所有 phase_transitions 已触发（triggered_transitions 满）
  - When: 继续战斗 check
  - Then: 保持最终阶段行为模式，不再次转换
  - Edge cases: get_phase() 返回最终阶段索引

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ai_system/test_boss_phase_manager.gd` — must exist and pass
**Status**: [x] Created — 27 tests passing (test_boss_phase_manager.gd)

---

## Dependencies

- Depends on: Story 001（EnemyBattleState.current_phase_index / triggered_transitions 字段 + BossPhaseTransition 内嵌 Resource）
- Unlocks: Story 004（难度缩放 + 绑定注册——Boss 阶段转换就绪后统一集成）；战斗 Epic（CombatSystem 响应 boss_phase_transitioned 播放动画 + 无敌帧锁）；Boss 战斗 Epic（阶段转换动画/行为切换）

---

## 说明

**AC-010/AC-011 语义已裁决（2026-08-16，game-designer）**：`should_transition()` 触发条件为 **OR 语义** + 显式禁用哨兵（`0 = 禁用`）——`(hp_below > 0 AND hp_pct <= hp_below) OR (turn_after > 0 AND turn >= turn_after)`。原 GDD §公式 4 的 `and` 为笔误（AND 语义下「即使血量未到阈值」在数学上不可能发生），已修正。§边缘情况「最高难度回合兜底」降为配置层分级：极高难度 Boss 在 `.tres` 配置 `turn_after>0`，通用 Boss 配置 `turn_after=0`（禁用）。详见 GDD §公式 4（2026-08-16 修订）。
