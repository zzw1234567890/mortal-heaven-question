# Story 002: execute_turn 决策主循环（普通/精英/Boss 分支）

> **Epic**: AI 系统（敌方 AI） (ai-system)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Context

**GDD**: `design/gdd/ai-system.md`
**Requirement**: `TR-ai-001`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0017（AI 系统 — Feature 层独立 Autoload + 效果引擎统一路径 + Boss 内部阶段状态机）
**ADR Decision Summary**: `execute_turn(field_state) → Array[AIAction]` 是 Phase 6 入口——CombatSystem 直接方法调用驱动。每个存活敌人走三级智能分支 `_decide_action()`（普通简单优先级 / 精英战术+绑定+阵法 / Boss 多阶段）。技能分数 `base_weight × modifier` + 修正系数，目标选择（集火/分散/嘲讽/穿透），撤退判定。决策在主线程同步执行（最坏 6 敌人 × 5 技能 ≈ 3ms < 5ms 预算）。AI 返回行动指令数组，绝不写 GSM。

**Engine**: Godot 4.6 | **Risk**: LOW（Dictionary 操作、信号系统、纯计算决策树——4.x 成熟 API）
**Engine Notes**: 决策为纯计算，不依赖 4.4+ 新特性。同步执行预算 <5ms（6 敌人 × 5 技能 evaluate_effect ≈ 3ms）。

**Control Manifest Rules (Feature 层)**:
- **Required**: AISystem 3 级智能层级（普通/精英/Boss）+ 加权优先级决策树（来源：ADR-0017）
- **Required**: AI 评估通过不可变 `GameStateSnapshot` 上的 `evaluate_effect()` / `simulate_chain()`——不修改游戏状态（来源：ADR-0009, ADR-0017）
- **Forbidden**: 绝不让 AI 直接写 GSM——返回行动指令 `Array[AIAction]` 给 CombatSystem（来源：ADR-0017）
- **Forbidden**: 绝不使用全局 `randf()`——独立 `RandomNumberGenerator` 实例（来源：ADR-0009, ADR-0017 §RNG）
- **Guardrail**: AI `execute_turn()` <5ms（6 敌人 × 5 技能 × evaluate_effect）（来源：ADR-0017）

---

## Acceptance Criteria

*From ADR-0017 §决策引擎设计 + GDD ai-system.md §4/§5 + §公式 1/2/3 + §边缘情况 + §验收标准:*

- [ ] **AC-001**: `execute_turn(field_state)` 返回 `Array[AIAction]`——每个存活敌方角色执行至少一个可用技能或攻击（普通攻击兜底）
- [ ] **AC-002**: `_decide_action()` 三分支——`is_boss → _decide_boss_action` / `is_elite → _decide_elite_action` / 否则 `_decide_normal_action`
- [ ] **AC-003**: 技能分数 `skill_score = skill.base_weight × modifier`，按分数降序排序，在费用预算内选择 top 1~2 个技能
- [ ] **AC-004**: 修正系数 `modifier = 1.0 + 治疗(+0.5 若友方残血) + 防御(+0.3 若前排阵亡) + 攻击(+0.4 若高威胁)`；阵法部署为加法修正（+20 若阵法位空）
- [ ] **AC-005**: 技能池含治疗技能且友方残血（HP<30%）时，治疗技能分数 ≥ 攻击技能分数（修正系数 ×1.5 生效）
- [ ] **AC-006**: 集火模式（focus_fire>0.5）→ 选择可用目标中 HP% 最低的角色；同 HP% 多个目标 → 选防御最低者
- [ ] **AC-007**: 分散模式（focus_fire≤0.5）→ 加权随机选择，残血角色（HP%<0.3）权重 ×2
- [ ] **AC-008**: 玩家角色激活嘲讽 → 所有可攻击敌方强制攻击嘲讽目标（法术 debuff 非攻击效果仍可作用于其他角色）
- [ ] **AC-009**: 敌方所有技能在冷却 → 使用普通攻击（基础攻击，无技能效果，不消耗费用）
- [ ] **AC-010**: 敌方费用不足 → 跳过高费技能选最低可用；全部不足 → 仅普通攻击
- [ ] **AC-011**: 敌方前排阵亡而后排有角色 → 后排高防御角色自动补位到前排（阶段 6 自动执行，不占用出牌机会）
- [ ] **AC-012**: 撤退判定——非 Boss 敌人 `ally_hp_ratio < retreat_threshold` → 50% 概率撤退 → 发射 `enemy_retreated` 信号；撤退敌人跳过后续行动
- [ ] **AC-013**: AI 返回 `Array[AIAction]`，不持有 CombatSystem 引用、不直接写 GSM
- [ ] **AC-014**: 敌方技能效果统一走 `CardEffectEngine.resolve()` 结算路径——AI 仅用 `evaluate_effect()` / `simulate_chain()` 做决策评估（纯计算，不结算）

---

## Implementation Notes

*Derived from ADR-0017 §决策引擎设计 + §三智能层级分支 + §敌方技能效果结算路径:*

1. **决策流程顺序**（单敌人，ADR-0017 §决策引擎设计）：
   ① `_check_retreat()`（非 Boss，HP<阈值→50% 撤退→跳过后续）
   ② `_check_phase_transition()`（仅 Boss——Story 003 实现，本 Story 调用钩子）
   ③ `_evaluate_skills()`（加权分数 + 修正系数 → 选 1~2 个技能）
   ④ `_select_target()`（集火/分散/嘲讽/穿透）
   ⑤ 构建 `AIAction {enemy_id, skill_id, target_ids, is_retreat}`
2. **三级分支**（ADR-0017 §三智能层级分支）：
   - `_decide_normal_action()`：仅 `_evaluate_skills()` + `_select_target()`，无阵法/绑定/阶段
   - `_decide_elite_action()`：+ `_check_formation_deploy()`（空阵法位 + 有阵法卡 → 部署）
   - `_decide_boss_action()`：先 `_check_phase_transition()` + `_check_formation_deploy()`，再 `_evaluate_skills()` + `_select_target()`
3. **修正系数**（ADR-0017 §④）：`modifier` 乘法修正 + 阵法 `+20` 加法修正；变量定义见 GDD §公式 1（ally_low_hp_count [0,6] / ally_front_dead bool / player_high_threat bool）
4. **目标选择**（GDD §公式 2 + ADR §⑤）：集火/分散两种模式；嘲讽强制覆盖（target_score +999）；穿透攻击可选后排高威胁目标
5. **撤退**（GDD §公式 3）：`ally_hp_ratio < retreat_threshold ? 0.5 : 0.0`；撤退后战斗判玩家胜利奖励减半（由 CombatSystem 处理——本 Story 仅发射 `enemy_retreated`）
6. **RNG**：使用独立 `RandomNumberGenerator` 实例（`_rng`），种子来自 `GSM.meta.seed`（确定性——支持回归测试）；绝不全局 `randf()`
7. **普通攻击兜底**：`skill_id == "basic_attack"` 作为所有技能冷却/费用不足时的回退，无技能效果、不消耗费用（由 CombatSystem 直接结算基础伤害）
8. **不结算**：本 Story 只做决策评估，效果结算由 CombatSystem 收到 AIAction 后调用 CardEffectEngine.resolve()（ADR §敌方技能效果结算路径）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: EnemyTemplate/EnemyBattleState 模型 + create_enemy_roster（已实现，本 Story 消费其实例）
- **Story 003**: BossPhaseMgr 阶段转换内部状态机——本 Story 仅在 Boss 分支调用 `_check_phase_transition()` 钩子，阶段转换具体逻辑不在此实现
- **Story 004**: 难度缩放 + register_preconfigured_bindings——本 Story 不处理绑定注册/缩放
- **CombatSystem**: 执行 AIAction（调用 CardEffectEngine.resolve()、处理撤退流程、基础攻击结算）——战斗 Epic（ADR-0008）职责
- **CombatUI**: 订阅 `ai_action_executed` / `enemy_retreated` 播放动画 + 战斗日志——战斗 UI Epic 职责

---

## QA Test Cases

*From ADR-0017 §验证标准 + GDD ai-system.md §边缘情况 + §验收标准:*

- **AC-001**: execute_turn 每个存活敌人至少一个行动
  - Given: 场上有 3 个存活敌人（无撤退条件触发）
  - When: `ai.execute_turn(field_state)`
  - Then: 返回 Array[AIAction] 含 3 个行动，每个有 enemy_id
  - Edge cases: 敌人全部技能冷却/费用不足 → 行动为 basic_attack

- **AC-002**: 三级智能分支
  - Given: 普通模板、精英模板、Boss 模板各一个存活敌人
  - When: 检查 `_decide_action` 分派
  - Then: 分别进入 `_decide_normal_action` / `_decide_elite_action` / `_decide_boss_action`
  - Edge cases: is_elite 与 is_boss 同时为 true → Boss 分支优先（先判 is_boss）

- **AC-003**: 技能分数计算与排序
  - Given: 技能池含 base_weight=50/20/15 的技能（均可用）
  - When: `_evaluate_skills()`
  - Then: 按 base_weight×modifier 降序，选最高分技能
  - Edge cases: 分数相同 → 稳定排序保证确定性

- **AC-004**: 修正系数计算
  - Given: 友方有残血角色（HP<30%）
  - When: 评估治疗技能
  - Then: modifier = 1.5（1.0 + 0.5）
  - Edge cases: 治疗技能无残血 → modifier=1.0；阵法空位 + 阵法技能 → +20 加法修正

- **AC-005**: 治疗技能权重高于攻击
  - Given: 技能池含治疗（weight=30）+ 攻击（weight=50），友方残血
  - When: AI 决策
  - Then: 治疗 score（30×1.5=45）与攻击 score 比较——治疗修正后 ≥ 攻击（视具体权重）
  - Edge cases: 残血修正仅当 ally_low_hp_count > 0 生效

- **AC-006**: 集火模式目标选择
  - Given: focus_fire=0.6，玩家前排 2 角色 HP% 分别为 40%/80%
  - When: `_select_target()`
  - Then: 选择 HP% 40% 的角色
  - Edge cases: 两角色同 HP% → 选防御更低者

- **AC-007**: 分散模式目标选择
  - Given: focus_fire=0.4，玩家前排 2 角色（一个 HP%<0.3 残血）
  - When: `_select_target()`（多次采样）
  - Then: 残血角色被选中概率显著更高（权重 ×2）
  - Edge cases: 确定性种子下可重复验证权重分布

- **AC-008**: 嘲讽强制目标
  - Given: 玩家角色 A 有嘲讽，另一角色 B 无
  - When: 敌人选择攻击目标
  - Then: 所有可攻击敌人目标锁定为 A
  - Edge cases: 法术 debuff（非攻击）仍可作用于 B（target_type 为 debuff 的技能不受嘲讽限制）

- **AC-009**: 全技能冷却 → 普通攻击
  - Given: 敌人所有技能 skill_cooldowns > 0
  - When: `_evaluate_skills()`
  - Then: 返回 basic_attack（无技能效果、不消耗费用）
  - Edge cases: 普通攻击无冷却限制

- **AC-010**: 费用不足回退
  - Given: 技能池含 cost=3/2/1 技能，剩余费用=1
  - When: `_evaluate_skills()`
  - Then: 跳过 cost=3/2，选 cost=1；若全部超费 → basic_attack
  - Edge cases: 0 费技能始终可选

- **AC-011**: 前排阵亡后排补位
  - Given: 敌方前排全阵亡，后排有角色
  - When: 阶段 6 AI 决策
  - Then: 后排高防御角色自动补位到前排（is_front_row=true）
  - Edge cases: 补位不占用出牌机会

- **AC-012**: 撤退判定
  - Given: 非 Boss 敌人，retreat_threshold=0.2，ally_hp_ratio=0.1
  - When: `_check_retreat()`（确定性种子下多次）
  - Then: 约 50% 概率返回 true，发射 `enemy_retreated`，该敌人跳过行动
  - Edge cases: ally_hp_ratio ≥ threshold → 不撤退；Boss 绝不撤退

- **AC-013**: 不写 GSM
  - Given: AI 执行 execute_turn
  - When: 检查返回值与副作用
  - Then: 返回 Array[AIAction]，GSM 状态无 AI 直接写入，无 CombatSystem 引用
  - Edge cases: AIAction 仅含数据字段，结算由 CombatSystem 完成

- **AC-014**: 走 CardEffectEngine 统一路径
  - Given: 敌人技能含 effect_template_ids
  - When: AI 决策评估该技能
  - Then: AI 调用 evaluate_effect/simulate_chain（纯计算），不调用 resolve()、不自建结算逻辑
  - Edge cases: 实际结算路径是 CombatSystem → CardEffectEngine.resolve()（本 Story 不实现）

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/ai_system/test_execute_turn_decision.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（EnemyBattleState 模型 + create_enemy_roster）；CardEffectEngine story-005（`evaluate_effect()` / `simulate_chain()` / `GameStateSnapshot` 评估接口——ADR-0009 定义，供 AI 决策评估调用）
- Unlocks: Story 004（难度缩放 + 绑定注册——依赖 execute_turn 决策主循环就绪后统一集成）；战斗 Epic（CombatSystem Phase 6 调用 execute_turn + 执行 AIAction）
