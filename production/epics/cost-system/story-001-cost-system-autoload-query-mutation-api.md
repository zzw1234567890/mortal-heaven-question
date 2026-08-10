# Story 001: CostSystem Autoload + 内部状态 + 查询/变异 API

> **Epic**: cost-system
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-10

## Context

**GDD**: `design/gdd/cost-system.md`
**Requirement**: `TR-cost-001`（待 `/architecture-review` 注册——当前 tr-registry.yaml 无 cost 条目，不阻塞实现）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0015（费用系统——独立 CORE Autoload + 内部状态管理 + 直接调用查询 + 回合重置委托）
**ADR Decision Summary**: CostSystem 作为 Core 层 Autoload #7，内部管理费用状态（`_current_cost`、`_max_cost`、`_temp_bonus`、`_temp_bonus_stack`）。战斗热路径中通过直接调用查询费用（`can_afford()` O(1)），CombatSystem 通过直接调用驱动费用生命周期（`spend()`、`reset_for_turn()`、`init_for_battle()`、`add_temp_bonus()`、`clear_for_battle_end()`）。

**Engine**: Godot 4.6 | **Risk**: LOW（整数运算 + Dictionary 栈管理 + 信号系统——4.0+ 稳定 API）
**Engine Notes**: 不依赖 4.4+ 新特性。`can_afford()` 热路径 O(1) 整数比较 <0.001ms。

**Control Manifest Rules (Core 层)**:
- **Required**: CostSystem 是 Autoload —— 绝不声明 `class_name`（控制清单 2026-08-05 规则——同 RealmSystem/ResourceSystem/FactionSystem/CardSystem 模式）
- **Required**: Foundation Autoload 测试用动态分派模式（`CS_SCRIPT.new()` + `var cs: Node`）
- **Required**: 动态分派返回值必须显式类型注解
- **Forbidden**: CostSystem 不反向依赖 CombatSystem（编排器→子系统方向——ADR-0008）
- **Forbidden**: 费用状态不由 GSM 直接管理（独立 Autoload 持有内部状态——拒绝替代方案 B）

---

## Acceptance Criteria

*From ADR-0015 §验证标准 + GDD cost-system.md §验收标准 + §公式:*

- [ ] **AC-001**: `init_for_battle(max_cost)` 设置 `_max_cost = maxi(max_cost, 1)`、`_current_cost = _max_cost`、`_temp_bonus = 0`、`_temp_bonus_stack.clear()`、`_is_active = true` + 写入 GSM
- [ ] **AC-002**: `get_max_cost()` 返回境界上限（炼气=2, 筑基=5, 金丹=8, 元婴=11, 化神=14——由调用方从 RealmSystem 查询传入）
- [ ] **AC-003**: `can_afford(3)` 当 `_current_cost=5` → true；当 `_current_cost=1` → false
- [ ] **AC-004**: `can_afford(0)` 始终返回 true（0 费卡始终可用）
- [ ] **AC-005**: `spend(3)` 当 `_current_cost=5` → `_current_cost=2` + 返回 true + 发射 `cost_changed`
- [ ] **AC-006**: `spend(3)` 当 `_current_cost=1` → `_current_cost` 不变 + 返回 false + push_warning
- [ ] **AC-007**: 非活跃战斗调用 `spend(1)` → 返回 false + push_warning
- [ ] **AC-008**: `get_cost_state()` 返回 CostState 枚举：FULL（`_current_cost==_max_cost`）/ PARTIAL（`0 < _current_cost < _max_cost`）/ EMPTY（`_current_cost==0`）/ OVERLIMIT（`_current_cost > _max_cost`）
- [ ] **AC-009**: `is_overlimit()` 当超限时返回 true
- [ ] **AC-010**: `add_temp_bonus(2, "mid_pill_001")` → `_temp_bonus=2` + `_current_cost += 2`（可突破上限）+ `_temp_bonus_stack` 含 1 条目
- [ ] **AC-011**: 两次 `add_temp_bonus`（+1 + +2）→ `_temp_bonus=3` + `_temp_bonus_stack.size()==2`
- [ ] **AC-012**: `reset_for_turn(true, false)`（先手）→ `_current_cost = _max_cost` + `_temp_bonus=0` + `_temp_bonus_stack` 为空
- [ ] **AC-013**: `reset_for_turn(false, true)`（后手第 1 回合）→ `_current_cost = _max_cost + 1`
- [ ] **AC-014**: `reset_for_turn(false, false)`（后手第 2 回合）→ `_current_cost = _max_cost`（无额外 +1）
- [ ] **AC-015**: `clear_for_battle_end()` → 全部状态归零 + `_is_active = false`
- [ ] **AC-016**: `get_total_max()` 返回 `_max_cost + _temp_bonus`
- [ ] **AC-017**: CostSystem extends Node，不声明 `class_name`
- [ ] **AC-018**: `init_for_battle(5)` 完成后 GSM `battle.current_cost == 5` + `batch_updated` 信号已发射（GSM 写委托——Story 002 实现 `_set_battle_cost`，本 Story 用桩或 mock 验证调用）

---

## Implementation Notes

*Derived from ADR-0015 §关键接口:*

1. **文件位置**: `src/core/cost_system.gd`（Core 层，Autoload #7——在 CardSystem #6 之后、StatusEffectSystem #8 之前）
2. **类声明**: `extends Node`（不声明 class_name——Autoload 固有权衡）
3. **CostState 枚举**: `enum CostState { FULL = 0, PARTIAL = 1, EMPTY = 2, OVERLIMIT = 3 }`
4. **内部状态**: `_current_cost: int = 0`、`_max_cost: int = 0`、`_temp_bonus: int = 0`、`_temp_bonus_stack: Array[Dictionary] = []`、`_is_active: bool = false`
5. **查询 API**（热路径 O(1)）: `get_current_cost()`、`get_max_cost()`、`get_total_max()`、`can_afford(cost)`、`get_cost_state()`、`is_overlimit()`
6. **变异 API**: `init_for_battle(max_cost)`、`spend(amount)`、`reset_for_turn(is_first_player, is_first_turn)`、`add_temp_bonus(amount, source_id)`、`clear_for_battle_end()`
7. **后手第 1 回合补偿**: `reset_for_turn` 中 `_current_cost += 1`（直接增加，不通过 `_temp_bonus`——语义为回合级调整，非丹药临时加成）
8. **_ready 为空**: 战斗准备在 `init_for_battle()` 中执行（由 CombatSystem 调用，此时 RealmSystem 已就绪）
9. **GSM 写委托**: `_write_cost_to_gsm()` 调用 `GSM._set_battle_cost(current, max)`（若方法存在）——本 Story 实现桩，Story 002 在 GSM 中实现 `_set_battle_cost`
10. **测试模式**: `CS_SCRIPT.new()` 构造实例，`var cs: Node` 持有 + 动态分派，返回值显式类型注解

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: 双重信号路径（`cost_changed` Cat 2b + GSM `batch_updated` Cat 1 via `_set_battle_cost`）+ GSM `_set_battle_cost` 第二层方法实现
- **CombatSystem 集成**: `battle_start()` 调用 `init_for_battle()`、`play_card()` 调用 `can_afford()`+`spend()`、Phase 6 END 调用 `reset_for_turn()` ——战斗 Epic（ADR-0008）职责
- **CombatUI 费用栏**: 订阅 `cost_changed` 刷新显示 ——战斗 UI Epic 职责
- **境界实时变更费用上限**: 当前设计战斗中 `_max_cost` 锁定，境界提升在战斗结算后生效（GDD 未定义战斗中突破场景）

---

## QA Test Cases

*From QA 计划 qa-plan-sprint-3-2026-08-10.md §Story 3-2 + ADR-0015 §验证标准:*

- **AC-001**: `init_for_battle(max_cost)` 初始化全部状态
  - Given: CostSystem 实例已创建
  - When: `cs.init_for_battle(5)`
  - Then: `_max_cost==5` + `_current_cost==5` + `_temp_bonus==0` + `_temp_bonus_stack` 为空 + `_is_active==true`
  - Edge cases: max_cost=0 → `maxi(0,1)=1`（防御性下限）；max_cost 负数同上

- **AC-002**: 境界费用上限公式验证
  - Given: cs 已创建
  - When: 依次 `init_for_battle(2/5/8/11/14)`
  - Then: `get_max_cost()` 分别返回 2/5/8/11/14
  - Edge cases: 5 个境界基准值（由调用方从 RealmSystem 查询传入）

- **AC-003**: `can_afford` 费用校验
  - Given: `cs.init_for_battle(5)`
  - When: `cs.can_afford(3)` / `cs.can_afford(6)`
  - Then: true / false
  - Edge cases: `_current_cost=1` 时 `can_afford(3)` → false

- **AC-004**: 0 费卡始终可用
  - Given: `cs.init_for_battle(0)`（防御性变 1）
  - When: `cs.can_afford(0)`
  - Then: true（即使空费也返回 true）
  - Edge cases: 负数 cost 视为 ≤0 → true

- **AC-005**: `spend` 扣费成功
  - Given: `cs.init_for_battle(5)`
  - When: `cs.spend(3)`
  - Then: `get_current_cost()==2` + 返回 true + `cost_changed` 信号已发射
  - Edge cases: 载荷 `(current=2, max=5, total_max=5)`

- **AC-006**: `spend` 费用不足拒绝
  - Given: `cs.init_for_battle(1)`
  - When: `cs.spend(3)`
  - Then: `get_current_cost()==1`（不变）+ 返回 false + push_warning
  - Edge cases: 不发射 `cost_changed`（状态未变）

- **AC-007**: 非活跃战斗 spend 拒绝
  - Given: cs 未 `init_for_battle`
  - When: `cs.spend(1)`
  - Then: 返回 false + push_warning（"spend() called outside active battle"）
  - Edge cases: `clear_for_battle_end()` 后再 spend 同样拒绝

- **AC-008**: CostState 枚举判定
  - Given: `cs.init_for_battle(5)`（FULL）
  - When: `cs.spend(2)`（PARTIAL）/ `cs.spend(3)`（EMPTY）/ `cs.add_temp_bonus(3)` 后（OVERLIMIT）
  - Then: `get_cost_state()` 分别返回 FULL/PARTIAL/EMPTY/OVERLIMIT
  - Edge cases: OVERLIMIT 优先于其他判定（`_current_cost > _max_cost` 首检查）

- **AC-009**: `is_overlimit` 超限判定
  - Given: `cs.init_for_battle(5)` + `cs.add_temp_bonus(3)`（_current_cost=8）
  - When: `cs.is_overlimit()`
  - Then: true
  - Edge cases: 无临时加成时 false

- **AC-010**: `add_temp_bonus` 临时费用加成
  - Given: `cs.init_for_battle(5)`
  - When: `cs.add_temp_bonus(2, "mid_pill_001")`
  - Then: `_temp_bonus==2` + `get_current_cost()==7`（突破上限）+ `_temp_bonus_stack.size()==1`
  - Edge cases: amount≤0 时忽略（直接 return）；非活跃战斗 push_warning + return

- **AC-011**: 多丹药临时费用叠加
  - Given: `cs.init_for_battle(5)`
  - When: `cs.add_temp_bonus(1, "low_pill_001")` + `cs.add_temp_bonus(2, "mid_pill_001")`
  - Then: `_temp_bonus==3` + `get_current_cost()==8` + `_temp_bonus_stack.size()==2`
  - Edge cases: `get_total_max()==8`

- **AC-012**: `reset_for_turn` 先手全额恢复
  - Given: `cs.init_for_battle(5)` + `cs.add_temp_bonus(2)` + `cs.spend(3)`
  - When: `cs.reset_for_turn(true, false)`
  - Then: `get_current_cost()==5` + `_temp_bonus==0` + `_temp_bonus_stack` 为空
  - Edge cases: 临时加成清除不累积

- **AC-013**: `reset_for_turn` 后手第 1 回合额外 +1
  - Given: `cs.init_for_battle(5)`
  - When: `cs.reset_for_turn(false, true)`
  - Then: `get_current_cost()==6`（5+1）
  - Edge cases: 额外 +1 不计入 `_temp_bonus`（下回合重置自然回归）

- **AC-014**: `reset_for_turn` 后手第 2 回合无额外 +1
  - Given: `cs.init_for_battle(5)`
  - When: `cs.reset_for_turn(false, false)`
  - Then: `get_current_cost()==5`
  - Edge cases: 后手补偿仅第 1 回合生效

- **AC-015**: `clear_for_battle_end` 战斗清理
  - Given: `cs.init_for_battle(5)` + 操作若干
  - When: `cs.clear_for_battle_end()`
  - Then: `_current_cost==0` + `_max_cost==0` + `_temp_bonus==0` + `_temp_bonus_stack` 为空 + `_is_active==false`
  - Edge cases: 清理后再调用任何变异 API 应拒绝

- **AC-016**: `get_total_max` 总上限
  - Given: `cs.init_for_battle(5)` + `cs.add_temp_bonus(3)`
  - When: `cs.get_total_max()`
  - Then: 返回 8（5+3）
  - Edge cases: 无临时加成时等于 `get_max_cost()`

- **AC-017**: extends Node + 不声明 class_name
  - Given: CostSystem 脚本已加载
  - When: 检查 `CS_SCRIPT.get_instance_base_type()` 和 `get_global_name()`
  - Then: base type == "Node" + global_name == &""
  - Edge cases: 动态分派 `var cs: Node = CS_SCRIPT.new()`

- **AC-018**: GSM 写委托调用
  - Given: `cs.init_for_battle(5)` + GSM 可用
  - When: 检查 `_write_cost_to_gsm()` 是否调用 `GSM._set_battle_cost(5, 5)`
  - Then: GSM `battle.current_cost == 5`（若 `_set_battle_cost` 已实现）或 `_write_cost_to_gsm` 用 `has_method` 守卫跳过（本 Story 桩模式）
  - Edge cases: GSM 不可用时 `_write_cost_to_gsm` 不崩溃（`is_instance_valid` 守卫）

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/cost_system/test_cost_system_basic.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: 无（CostSystem 仅依赖 GSM + RealmSystem 查询，均已就绪；RealmSystem 查询由调用方 CombatSystem 完成，传入 max_cost）
- Unlocks: Story 002（双重信号路径——依赖 001 的内部状态和变异 API）；战斗 Epic（CombatSystem 集成）；卡牌效果 Epic（`can_afford`/`add_temp_bonus`）
