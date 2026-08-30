# Story 001: 渡劫流程编排 + TribulationState 状态机

> **Epic**: tribulation-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 1.0d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-30

## Context

**GDD**: `design/gdd/tribulation-system.md`
**Requirement**: `TR-trib-001`（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）

**ADR Governing Implementation**: ADR-0021（渡劫突破系统——Feature Autoload 编排器 + CombatSystem 配置复用）
**ADR Decision Summary**: TribulationSystem 作为 Feature 层 Autoload（#24），拥有渡劫生命周期状态机。状态枚举存入 GSM `player.tribulation_state`，连续失败计数存入 `player.consecutive_tribulation_failures`（持久化）。本 Story 实现状态机骨架 + GSM 域扩展 + 触发条件检查 + 信号声明——不实现战斗委托和结算。

**Engine**: Godot 4.6 | **Risk**: LOW（状态机 + GSM 写入 + 信号声明，均为 4.0+ 稳定 API）
**Engine Notes**: GSM 第二层写入模式遵循 _set_battle_phase 先例。信号遵循 ADR-0007 Cat 2b + _emit_safe 路由。

**Control Manifest Rules (Feature 层)**:
- **Required**: 渡劫状态机存入 GSM player.tribulation_state —— 来源: ADR-0021 §GSM 轻量状态
- **Required**: 连续失败计数持久化到存档 —— 来源: ADR-0021 §consecutive_tribulation_failures
- **Forbidden**: 绕过 GSM 直接修改 player.tribulation_state —— 来源: ADR-0001
- **Forbidden**: TribulationSystem 内部持有战斗逻辑 —— 来源: ADR-0021 §编排器职责

---

## Acceptance Criteria

*From ADR-0021 §TribulationState 枚举 + §GSM 新增域与方法 + §信号分类:*

- [ ] **AC-001**: `TribulationState` 枚举（6 值：NOT_READY=0, READY=1, PREPARING=2, IN_COMBAT=3, SUCCESS=4, FAILED=5）+ `TribulationType` 枚举（2 值：NORMAL=0, CROSS_REALM=1）
- [ ] **AC-002**: TribulationSystem Autoload 骨架（`src/feature/tribulation_system.gd`，extends Node，不注册 project.godot）
- [ ] **AC-003**: GSM serializer player 域新增 `tribulation_state: int`（默认 NOT_READY=0）+ `consecutive_tribulation_failures: int`（默认 0）
- [ ] **AC-004**: GSM 第二层新增 `_set_tribulation_state(state: int)` + `_set_consecutive_tribulation_failures(count: int)` 原子写入方法（null 守卫 + 去重 + _buffer_change）
- [ ] **AC-005**: `check_tribulation_ready()` 返回 bool——tribulation_state == NOT_READY 且 cultivation >= max_cultivation 时 true
- [ ] **AC-006**: `trigger_tribulation(trib_type)` 验证条件 → 越阶验证 → 进入 PREPARING → 发射 `tribulation_triggered` 信号
- [ ] **AC-007**: 5 个 Cat 2b 信号声明：`tribulation_triggered(realm_level)` / `tribulation_preparation_started()` / `tribulation_succeeded(old, new, is_cross)` / `tribulation_failed(penalty, realm_level)` / `tribulation_protection_unlocked()`
- [ ] **AC-008**: 状态转换验证——非法转换被拒绝（如 NOT_READY 不可直接到 IN_COMBAT）
- [ ] **AC-009**: `get_tribulation_status()` 返回 {state, consecutive_failures, trib_type} Dictionary
- [ ] **AC-010**: `consecutive_tribulation_failures` 通过 serializer 持久化（出现在默认值 + serialize/deserialize 往返）

---

## Implementation Notes

*Derived from ADR-0021 §关键接口 + GSM 现有模式:*

1. **文件位置**: `src/feature/tribulation_system.gd` — 新建 TribulationSystem Autoload 骨架
2. **extends Node 不声明 class_name** — 同 ExplorationSystem/CultivationSystem 先例
3. **不注册进 project.godot** — 待各系统接线后统一注册
4. **GSM serializer** — player 域默认值新增 `tribulation_state: 0` + `consecutive_tribulation_failures: 0`
5. **GSM 第二层** — `_set_tribulation_state` / `_set_consecutive_tribulation_failures` 遵循 `_set_battle_phase` 先例
6. **信号声明** — 5 个 Cat 2b 信号，通过 `_emit_safe` 路由（同 CombatSystem 模式）
7. **状态转换** — `_validate_state_transition` 验证矩阵（合法转换白名单）
8. **越阶验证** — CROSS_REALM 时检查 next_realm <= realm_table.size()
9. **MAX_TRIBULATION_PILLS** — 常量声明为 2（供 Story 5-12 使用，本 Story 仅声明）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 5-11**: 渡劫战斗委托 CombatSystem + 天雷 debuff——本 Story 只声明信号和状态机骨架
- **Story 5-12**: 渡劫丹辅助 + 成功/失败分支处理——本 Story 只声明 MAX_PILLS 常量
- **Story 5-13**: 渡劫结果 GSM 同步 + 场景恢复——本 Story 不处理场景恢复
- **InputManager 锁**: ADR-0021 提到 push_lock——本 Story 不实现（InputManager 集成在 5-13）
- **金卡奖励**: 渡劫成功后的金卡发放——Story 5-12

---

## QA Test Cases

- **AC-001**: 枚举值正确
- **AC-002**: TribulationSystem 实例化无报错
- **AC-003**: serializer 默认值包含新字段
- **AC-004**: _set_tribulation_state / _set_consecutive_tribulation_failures 写入 + batch_updated 传播
- **AC-005**: check_tribulation_ready 满值时 true，未满或已在流程中时 false
- **AC-006**: trigger_tribulation 进入 PREPARING + 发射信号；未满时 push_warning + 不进入
- **AC-007**: 5 个信号声明存在
- **AC-008**: 非法状态转换被拒绝
- **AC-009**: get_tribulation_status 返回正确结构
- **AC-010**: consecutive_tribulation_failures serialize/deserialize 往返

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tribulation_system/test_tribulation_state_machine.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 5-9（CultivationSystem check_breakthrough——渡劫触发条件查询）；GSM add_cultivation / change_realm（已实现）
- Unblocks: Story 5-11（渡劫战斗委托需要状态机 + 信号）；Story 5-12（渡劫丹需要 PREPARING 状态）；Story 5-13（GSM 同步需要状态字段）