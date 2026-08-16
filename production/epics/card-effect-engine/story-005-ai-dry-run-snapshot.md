# Story 005: AI 干跑评估接口（GameStateSnapshot 不可变纯计算）

> **Epic**: 卡牌效果解析引擎 (Card Effect Engine)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Context

**GDD**: `design/gdd/card-effect-engine.md`
**Requirement**: `TR-effect-004`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0009（卡牌效果引擎——Resource 模板 + RefCounted 运行时实例 + 栈式结算）
**ADR Decision Summary**: AI 接口暴露干跑评估能力——`create_evaluation_snapshot() → GameStateSnapshot`（不可变浅拷贝）、`evaluate_effect()`、`evaluate_effect_probabilistic()`、`simulate_chain(max_depth=10)`、`get_effect_categories()`——纯计算，不修改游戏状态。此能力是 ADR-0017（AI 系统）的前置依赖。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: 依赖截止后 API——`@abstract`（EffectBase 虚函数派发）、类型化 `Array[ProbabilityOutcome]`（4.4+ 泛型数组）。性能目标：`evaluate_effect()` 单次 <100μs（纯计算——无信号/无对象分配）；`simulate_chain()` 深度 5 <500μs；快照创建 1-2ms（一次性成本）。

**Control Manifest Rules (Feature 层)**:
- **Required**: AI 评估通过不可变 `GameStateSnapshot` 上的 `evaluate_effect()`——不修改游戏状态
- **Forbidden**: 绝不让 CardEffectEngine 直接写 GSM——评估路径同样只读
- **Guardrail**: `evaluate_effect()` 单次 <100μs（纯计算，无信号，无对象分配）

---

## Acceptance Criteria

*From GDD `design/gdd/card-effect-engine.md` §验收标准 → AI 评估接口 + 性能:*

- [ ] **AC-001**: GIVEN 调用 `evaluate_effect(card_id, target_id, snapshot)` 对伤害型卡牌，WHEN 检查返回值，THEN `EffectEvaluation.damage` 与 `get_accumulated_value()` 计算结果一致
- [ ] **AC-002**: GIVEN 调用 `simulate_chain(card_id, target_id, snapshot, max_depth=5)`，WHEN 该卡会触发连锁效果，THEN 返回的 `ChainPreview.chain` 包含每一步的触发来源和效果评估
- [ ] **AC-003**: GIVEN AI评估288次 effect 调用（6敌 ×8技 ×6目标），WHEN 连续执行，THEN 总耗时 < 30ms（不含快照创建的一次性成本约1-2ms）

---

## Implementation Notes

*Derived from ADR-0009 §决策 → AI 评估接口:*

1. **文件位置**: `src/feature/card_effect_engine/game_state_snapshot.gd`（`class_name GameStateSnapshot extends RefCounted`）+ 评估方法在 `card_effect_engine.gd`（Autoload #10）。
2. **`create_evaluation_snapshot() → GameStateSnapshot`**: 浅拷贝当前机制数据——角色、状态、绑定、阵法、GSM 快照；不含动画/UI/音效/VFX 数据。单次 AI 回合只创建一次，所有评估共用。
3. **`evaluate_effect(card_id, target_id, snapshot) → EffectEvaluation`**: 纯计算——不修改任何状态。返回 `{damage, healing, stat_changes: Dictionary, statuses_applied: Array, is_overkill: bool, is_overheal: bool}`。
4. **`evaluate_effect_probabilistic(card_id, target_id, snapshot) → Array[ProbabilityOutcome]`**: 含 RNG 效果的完整概率分布。每项 `{outcome: EffectEvaluation, probability: float}`——复用 PRD 分布逻辑（Story 004）。
5. **`simulate_chain(card_id, target_id, snapshot, max_depth=10) → ChainPreview`**: 模拟打出此卡后的完整触发链（含概率）。返回 `{chain: [{step, source, effect, probability}], would_overflow: bool}`——`would_overflow` 复用触发链深度 10 语义（Story 003）。
6. **`get_effect_categories(card_id) → Array[EffectCategory]`**: 效果类型标签 `DAMAGE, HEAL, BUFF, DEBUFF, CONTROL, DRAW, BIND, FORMATION, UNEVALUABLE`。`UNEVALUABLE` = 依赖隐藏信息的效果（如偷牌）——AI 使用模板 base_weight 作后备。
7. **性能预算**: 单次 `evaluate_effect()` <100μs；`simulate_chain()` 深度 5 <500μs；AI 回合总评估 288 次 × 100μs ≈ 29ms（跨帧分摊——每帧评估部分候选，3 帧完成全部 288 次）；快照创建 1-2ms（一次性成本）。实际通过分帧评估分摊，在 16.6ms 帧预算之外异步运行。
8. **确定性契约**: `evaluate_effect()` 与 `resolve_card()` 在同一输入下的结果完全一致（确定性预测）——这是 ADR-0009 §验证标准要求的核心保证。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: 运行时真实触发链结算（`visited_card_ids` 循环检测 + 深度 10 截断）——本 Story 的 `simulate_chain` 是纯计算模拟，不改真实状态
- **Story 004**: PRD 运行时结算引擎——本 Story 的 `evaluate_effect_probabilistic` 消费 PRD 分布逻辑，不实现运行时掷骰
- **AISystem 决策树**: 加权优先级决策树、敌方出牌意图——ai-system Epic（ADR-0017）职责，本 Story 仅提供评估 API

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-001**: evaluate_effect 与 get_accumulated_value 一致
  - Given: 调用 `evaluate_effect(card_id, target_id, snapshot)` 对伤害型卡牌
  - When: 检查返回值
  - Then: `EffectEvaluation.damage` 与 `get_accumulated_value()` 计算结果一致
  - Edge cases: 有本命绑定（×1.5）时 floor 取整一致；评估后 snapshot 不被修改（不可变浅拷贝验证）

- **AC-002**: simulate_chain 返回完整触发链
  - Given: 调用 `simulate_chain(card_id, target_id, snapshot, max_depth=5)`，该卡会触发连锁效果
  - When: 检查返回值
  - Then: `ChainPreview.chain` 包含每一步的触发来源和效果评估
  - Edge cases: 链长超 max_depth 时 `would_overflow=true`；无连锁时 chain 只含根效果

- **AC-003**: AI 评估性能预算
  - Given: AI 评估 288 次 effect 调用（6敌 ×8技 ×6目标）
  - When: 连续执行
  - Then: 总耗时 < 30ms（不含快照创建的一次性成本约 1-2ms）
  - Edge cases: 单次 `evaluate_effect()` < 100μs（纯计算，无信号无对象分配）；`simulate_chain` 深度 5 < 500μs

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_effect_engine/test_ai_dry_run_snapshot.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003（`simulate_chain` 复用触发链深度 10 语义——`would_overflow` 判定）+ Story 004（`evaluate_effect_probabilistic` 复用 PRD 分布逻辑）
- Unlocks: AI 系统 Epic（ADR-0017——敌方出牌决策的评估接口）
