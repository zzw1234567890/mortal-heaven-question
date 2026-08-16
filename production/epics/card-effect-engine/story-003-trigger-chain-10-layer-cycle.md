# Story 003: 触发链硬限制 10 层 + visited_card_ids 循环检测

> **Epic**: 卡牌效果解析引擎 (Card Effect Engine)
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**:

## Context

**GDD**: `design/gdd/card-effect-engine.md`
**Requirement**: `TR-effect-003`（触发链管理——深度 10 层 + 循环检测 + PRD 伪随机分布）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0009（卡牌效果引擎——Resource 模板 + RefCounted 运行时实例 + 栈式结算）
**ADR Decision Summary**: 触发链硬限制 10 层 + `visited_card_ids: Dictionary[int, bool]` 循环检测（GDScript 4.x 无内置 `Set` 类型，使用字典键 O(1) 查找）。第 11 层截断 + WARN 日志。扇出分支（A 同时触发 B1 和 B2）共享同一深度计数器——总节点数达到 11 即截断。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: 依赖截止后 API——`@abstract`（EffectBase `_resolve()` 虚函数派发）。`Dictionary[int, bool]` 为 Godot 4.x 稳定类型（非截止后风险）。栈式递归截断逻辑不依赖新 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: 触发链硬限制——10 层 + `visited_card_ids: Dictionary[int, bool]` 循环检测
- **Forbidden**: 绝不让触发链超出深度 10——截断并记录 WARN 日志
- **Required**: 信号载荷 ≤3 参数优先；>3 → 具名字典（`stack_overflow_warning` 载荷 `{root_card_id, depth, chain}` 为具名字典）

---

## Acceptance Criteria

*From GDD `design/gdd/card-effect-engine.md` §验收标准 → 触发链:*

- [ ] **AC-001**: GIVEN 效果A→B→C触发链（深度3），WHEN 结算，THEN C先结算完，B其次，A最后（栈式LIFO）
- [ ] **AC-002**: GIVEN 同一 card_instance_id 已经在触发链中出现过，WHEN 该实例的效果再次被触发，THEN 跳过不重复触发（循环检测），记录DEBUG日志
- [ ] **AC-003**: GIVEN 触发链达到10层深度，WHEN 第11层试图触发，THEN 第11层终止，前10层正常结算，输出WARN级别日志：`"[CardEffectEngine] Trigger chain depth exceeded: max=10, root_card_id=<ID>, chain=<A→B→...→K>"`

---

## Implementation Notes

*Derived from ADR-0009 §决策 → 触发链管理:*

1. **文件位置**: `src/feature/card_effect_engine/trigger_chain_manager.gd`（或作为 `ResolutionStack` 的深度追踪状态——实现时选择单一归属，建议独立 `TriggerChainState` RefCounted 辅助类承载三个字段）。
2. **触发链深度追踪状态**:
   - `root_card_instance_id: int`——触发链的根卡牌（玩家打出的第一张卡）
   - `current_depth: int`——当前深度（从 1 开始计）
   - `visited_card_ids: Dictionary`——`Dictionary[int, bool]`，key = card_instance_id（GDScript 4.x 无 Set 类型，字典键 O(1) 查找）
3. **`_resolve_stack()` 每次出栈的处理顺序**:
   1. `current_depth += 1`
   2. `if current_depth > 10:` → 效果不结算，记录 WARN `"[CardEffectEngine] Trigger chain depth exceeded: max=10, root=<ID>, chain=<A→B→...→K>"`，`continue`（跳过该效果——队列中剩余效果继续结算）
   3. `if card_instance_id in visited_card_ids:` → 效果不结算（循环检测），记录 DEBUG 日志，`continue`
   4. `visited_card_ids[card_instance_id] = true`
   5. `_resolve(effect_instance)` → 可能产生新效果 → 中分辨率插入队列（Story 002）
   6. 出栈下一个效果（递归直到栈为空）
4. **扇出分支共享深度计数器**: 效果 A 同时触发 B1 和 B2 → B1 和 B2 都在深度+1 层，共享同一深度计数器——总节点数（非最深分支）达到 11 即截断。
5. **`stack_overflow_warning` 信号**: 第 11 层截断时发射——载荷 `{root_card_id, depth: int, chain: Array[int]}`（具名字典，>3 参数合规）。订阅者：DebugOverlay、CombatUI（可选——开发模式溢出指示器）。
6. **循环检测语义**: 同一 `card_instance_id` 不重复触发——防止 2 卡无限循环。扇出中 B1 和 B2 各自独立判断 visited，但都共享 visited 字典（一旦某 card_instance_id 触发过，扇出另一分支不再触发同一实例）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: ResolutionStack 的 LIFO 出栈 + 优先级排序（本 Story 只在出栈循环中插入深度/visited 检查）
- **Story 004**: PRD 伪随机分布（TR-effect-003 也涵盖 PRD，但 PRD 独立成 Story 004——触发链管理 Story 不实现概率）
- **Story 005**: `simulate_chain(max_depth=10)` AI 干跑触发链模拟（本 Story 是运行时真实结算，005 是纯计算模拟）

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

- **AC-001**: 栈式 LIFO（深度 3）
  - Given: 效果 A→B→C 触发链（深度 3）
  - When: 结算
  - Then: C 先结算完，B 其次，A 最后（栈式 LIFO）
  - Edge cases: 结算顺序记录需按完成时间（非开始时间）判定——C 先完成

- **AC-002**: 循环检测跳过重复触发
  - Given: 同一 card_instance_id 已在触发链中出现过
  - When: 该实例的效果再次被触发
  - Then: 跳过不重复触发，记录 DEBUG 日志
  - Edge cases: 两卡 A↔B 无限循环场景——visited 字典在第二次遇到时终止

- **AC-003**: 深度 10 硬限制 + WARN 日志
  - Given: 触发链达到 10 层深度
  - When: 第 11 层试图触发
  - Then: 第 11 层终止，前 10 层正常结算，输出 WARN 日志 `"[CardEffectEngine] Trigger chain depth exceeded: max=10, root_card_id=<ID>, chain=<A→B→...→K>"`
  - Edge cases: 扇出分支共享深度计数器——总节点数达 11 即截断；第 1-10 层必须完整结算完毕

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/card_effect_engine/test_trigger_chain_10_layer_cycle.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002（ResolutionStack 的 `_resolve_stack` 出栈循环——深度计数与 visited 检查的插入点）
- Unlocks: Story 005（`simulate_chain` 复用触发链深度 10 限制的语义——`would_overflow` 判定）
