# Story 002: ResolutionStack 栈式结算引擎（优先级队列 + LIFO + 中断插入）

> **Epic**: 卡牌效果解析引擎 (Card Effect Engine)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Context

**GDD**: `design/gdd/card-effect-engine.md`
**Requirement**: `TR-effect-002`（栈式结算引擎——5 级优先级 + 中分辨率插入队列 + LIFO 出栈）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0009（卡牌效果引擎——Resource 模板 + RefCounted 运行时实例 + 栈式结算）
**ADR Decision Summary**: 结算使用栈式引擎——`ResolutionStack` 管理优先级队列 + LIFO 出栈 + 中分辨率插入新效果（新触发效果按优先级插入未结算队列，而非追加末尾）。5 级主排序（主动出牌 > 先发己方 > 普通己方 > 敌方 > instance_id）+ 次级 `priority:int` 决胜。CombatSystem 通过直接调用 `resolve_phase_effects(phase)` 编排（引擎不订阅 CombatSystem 信号）。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: 依赖截止后 API——类型化 `Array[EffectInstance]`（4.4+ 泛型数组）。需验证 `Array[EffectInstance].filter()` 在队列重排序（100+ 元素）中的性能、`front()`/`back()`/`pop_front()` 在 Godot 4.6 中的行为。优先级排序使用 `Array.sort_custom()`——100 元素 <0.1ms。

**Control Manifest Rules (Feature 层)**:
- **Required**: ResolutionStack——按优先级排序的队列 → LIFO 出栈 → 中分辨率插入新效果
- **Required**: 5 级优先级——主动出牌 > 先发己方 > 普通己方 > 敌方 > instance_id
- **Forbidden**: 绝不让 CardEffectEngine 直接写 GSM——所有效果通过子系统接口执行（`CombatSystem.damage_target` / `StatusSystem.apply_status` / `EventSystem.set_flag` 等）
- **Forbidden**: 绝不使用全局 `randf()` 处理 PRD 效果（PRD 独立引擎——Story 004）

---

## Acceptance Criteria

*From GDD `design/gdd/card-effect-engine.md` §验收标准 → 结算顺序:*

- [ ] **AC-001**: GIVEN 己方效果A（激活时间t=3，先发标记=关）和己方效果B（激活时间t=5，先发标记=关）在同一时机触发，WHEN 结算，THEN B先于A执行（较新的优先），最终数值反映B先于A的效果顺序
- [ ] **AC-002**: GIVEN 效果A（先发标记=开，激活时间t=1）和效果B（先发标记=关，激活时间t=10）在同一时机触发，WHEN 结算，THEN A先于B执行（先发无视激活时间优先）

---

## Implementation Notes

*Derived from ADR-0009 §决策 → 栈式结算引擎 (ResolutionStack):*

1. **文件位置**: `src/feature/card_effect_engine/resolution_stack.gd`（`class_name ResolutionStack extends RefCounted`）+ `card_effect_engine.gd`（Autoload #10，`extends Node`，不声明 class_name）。
2. **结算优先级（主排序键——从高到低）**:
   1. 主动出牌效果（当前回合方 `card_instance_id`）
   2. 标记「先发」的己方持续效果（`activation_sequence` 降序）
   3. 未标记「先发」的己方持续效果（`activation_sequence` 降序）
   4. 敌方持续效果（`activation_sequence` 降序）
   5. 同 `activation_sequence` → `card_instance_id` 升序决胜
3. **次级决胜键**: `priority: int`——仅在同主排序层级内生效。
4. **LIFO 出栈**: `_resolve_stack()` 循环 `pop()` 栈顶效果 → `_resolve()` → 触发链深度检查（Story 003）→ 中分辨率插入新效果 → 继续出栈直到栈为空。栈为空 = 阶段结算完成。
5. **中分辨率插入队列模型**: 效果 A 结算过程中触发效果 B → B 按优先级插入尚未结算的队列位置（非追加末尾）——确保 A→B 因果关系正确反映在结算顺序中，B 可能排在某些已在队列中的低优先级效果之前。
6. **与战斗系统接口**: CombatSystem（ADR-0008）在 `advance_phase()` 进入 Phase 0/1/2/3/4/5/6 时**直接调用** `CardEffectEngine.resolve_phase_effects(phase: CombatPhase)`。引擎从活跃效果中筛选该阶段应触发的效果 → 收集到 ResolutionStack → `_resolve_stack()`。引擎是响应式服务——不订阅 CombatSystem 信号。
7. **结算结果写入（不写 GSM）**: 伤害/治疗 → 直接返回给 CombatSystem 调用方（同步结算）；状态变更 → `StatusSystem.apply_status()`/`remove_status()`；费用修改 → `CostSystem.modify_temporary_cost()`；SET_FLAG → `EventSystem.set_flag()`。
8. **运行时状态（不持久化）**: `_active_effects: Dictionary[int, Array[EffectInstance]]`（key=card_instance_id）、`_effect_by_id: Dictionary[int, EffectInstance]`（key=effect_instance_id 全局递增）、`_resolution_stack: ResolutionStack`。战斗阶段结束时栈必须为空。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: EffectTemplate/EffectInstance 对象模型定义（本 Story 消费 001 的类层级）
- **Story 003**: 触发链深度 10 硬限制 + `visited_card_ids` 循环检测（本 Story 的 `_resolve_stack` 预留深度检查钩子，实现归 003）
- **Story 004**: PRD 伪随机分布引擎（概率效果结算不在此 Story）
- **CombatSystem Phase 编排**: `advance_phase()` 触发时机——combat-system Epic（ADR-0008）职责，本 Story 仅暴露 `resolve_phase_effects(phase)` 接口

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-001**: 激活时间从新到旧（先发均关）
  - Given: 己方效果 A（t=3，先发=关）和己方效果 B（t=5，先发=关）同时机触发
  - When: 结算
  - Then: B 先于 A 执行（较新的优先），最终数值反映 B 先于 A 的效果顺序
  - Edge cases: t 相同 → 按 card_instance_id 升序决胜；次级 priority 字段在同主排序层级内生效

- **AC-002**: 先发无视激活时间优先
  - Given: 效果 A（先发=开，t=1）和效果 B（先发=关，t=10）同时机触发
  - When: 结算
  - Then: A 先于 B 执行
  - Edge cases: 两个先发效果之间仍按激活时间从新到旧；两个普通效果之间按激活时间从新到旧

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_effect_engine/test_resolution_stack.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（EffectInstance 对象模型——ResolutionStack 持有 `Array[EffectInstance]`）
- Unlocks: Story 003（触发链管理——依赖 002 的 `_resolve_stack` 出栈循环作为深度计数插入点）
