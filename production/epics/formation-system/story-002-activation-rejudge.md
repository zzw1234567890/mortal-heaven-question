# Story 002: 激活条件实时重判（订阅 deployment 信号）

> **Epic**: 阵法系统 (Formation System)
> **Status**: Complete
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-22

## Context

**GDD**: `design/gdd/formation-system.md`
**Requirement**: `TR-formation-002`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0024（阵法系统 — Feature 层 Autoload + 内部条件状态机 + GSM 快照持久化）
**ADR Decision Summary**: 阵法激活条件通过订阅 DeploymentSystem 的 `character_deployed` / `character_removed` 信号实时重判——收到信号后对全部 3 个阵法位重新调用 `FactionSystem.check_condition()`，条件变化时更新状态。重判不直接发射信号，返回变更列表由调用方批量发射，避免信号级联。

**Engine**: Godot 4.6 | **Risk**: LOW（信号系统 + Dictionary 遍历均为 4.x 成熟 API）
**Engine Notes**: 不依赖 4.4+ 新增 API。`signal` 连接/发射、`Dictionary` 遍历为 4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: 场上状态变更时实时重判条件（ADR-0024）
- **Forbidden**: 绝不缓存阵法激活状态——场上变更时通过 `FactionSystem.check_condition()` 重判（ADR-0024）
- **Forbidden**: 绝不超出信号链深度 4——截断 + `push_error`（ADR-0007）

---

## Acceptance Criteria

*From GDD `design/gdd/formation-system.md` §3 激活与失效 §6 阵眼角色阵亡 + §边界情况，scoped to this story:*

- [x] **AC-001**: 阵法未激活时场上状态变更（角色上场补足条件），自动判定 → 阵法激活
- [x] **AC-002**: 阵眼角色阵亡（特定角色在场条件），自动判定 → 依赖该角色的阵法立即失效
- [x] **AC-003**: 场上正道角色从 3 人降到 2 人（阵营人数条件），自动判定 → 阵法失效
- [x] **AC-004**: 阵眼角色被复活后重新上场，自动判定 → 阵法条件重新满足 → 可重新激活
- [x] **AC-005**: `recheck_all_conditions()` 不直接发射信号——返回变更列表 `Array[Dictionary]`，由调用方批量发射 `formation_condition_reevaluated`

---

## Implementation Notes

*Derived from ADR-0024 §关键接口 §阵法条件判定管线 §风险（信号重入）:*

1. **文件位置**: `src/feature/formation_system.gd`（扩展 Story 001——新增 `recheck_all_conditions()` + 信号处理器）
2. **`recheck_all_conditions() → Array[Dictionary]`**（ADR-0024 §关键接口）:
   - 遍历 3 个阵法位 → 对每个非 EMPTY 阵法调用 `FactionSystem.check_condition(requirement)`
   - 条件变化时更新状态（UNACTIVE → ACTIVE 或 ACTIVE → UNACTIVE）
   - 返回变更列表 `[{formation_id, old_state, new_state, reason}]`
   - **不发射信号**——由调用方在信号处理器中遍历完所有阵位后批量发射 `formation_condition_reevaluated(changes)`（避免信号级联 / 重入，ADR-0024 §风险）
3. **信号订阅**（ADR-0024 §Autoload 初始化，`_ready()` 中连接）:
   - `DeploymentSystem.character_deployed → _on_field_changed`
   - `DeploymentSystem.character_removed → _on_field_changed`
   - 阵亡场景由 `character_removed` 覆盖，无需额外连接 `character_died`（重叠）
4. **信号处理器 `_on_field_changed()` 流程**:
   1. `var changes: Array[Dictionary] = recheck_all_conditions()`
   2. 遍历 changes，逐个处理状态变更的副作用（ACTIVE→注册 persistent effect；UNACTIVE→移除 persistent effect；归属清除）
   3. 若 `not changes.is_empty()` → `_emit_signal_safe("formation_condition_reevaluated", changes)`
5. **条件变化时的状态机联动**（复用 Story 001 状态机）:
   - UNACTIVE → ACTIVE：发射 `formation_activated`（trigger_reason 记录触发变更，如 "character_deployed"）+ CardEffectEngine.register_persistent_effect
   - ACTIVE → UNACTIVE：发射 `formation_deactivated`（reason 记录条件失去原因，如 "character_removed" / "count_below_threshold"）+ CardEffectEngine.remove_effects_by_source + 清除该阵法全部归属
6. **阵位保留语义**（GDD §6）:
   - 阵眼角色阵亡 → 阵法变 UNACTIVE，但阵位保留（占用 1/3），可被覆盖或条件恢复后重新激活
   - 后续角色上场补足条件 → 重新 ACTIVE（无需重新打出）
7. **敌方回合时序安全**（ADR-0024 §风险——延迟归属队列）:
   - 敌方回合触发的条件重判中，若新阵法激活需要归属选择 → 压入 `_pending_affiliations` 队列 → 己方回合 Phase 1 DRAW 开始时弹出
   - 本 story 实现队列数据结构 + 压入逻辑；弹出时机由 CombatSystem 编排（下游集成）
8. **性能预算**（ADR-0024 §性能影响）:
   - `recheck_all_conditions()` <0.02ms（3 阵法 × FactionSystem O(6×3)）
   - 每次角色上场/阵亡/离场信号触发一次，非每帧调用

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: 状态机转换、deploy/overwrite 流程、归属管理 API——本 story 只调用已实现的状态机
- **Story 003**: 光环效果值计算——本 story 只负责激活/失效的注册/注销触发，不计算效果数值
- **Story 004**: serialize_all 快照导出
- **CombatSystem Epic**: 延迟归属队列的弹出时机编排（己方回合 Phase 1 DRAW）

---

## QA Test Cases

*Derived from ADR-0024 §验证标准 + GDD §边界情况:*

- **AC-001**: 角色上场补足条件 → 阵法激活
  - Given: 阵法 UNACTIVE（requirement `{tag_id: "zhengdao", min_count: 3}`）；场上 2 正道角色
  - When: 第 3 个正道角色上场 → `character_deployed` 信号触发 `_on_field_changed`
  - Then: `recheck_all_conditions()` 返回该阵法变更 `{old_state: UNACTIVE, new_state: ACTIVE}`；阵法变 ACTIVE；批量发射 `formation_condition_reevaluated`
  - Edge cases: 上场角色与阵法条件无关时，changes 列表为空

- **AC-002**: 阵眼角色阵亡 → 阵法失效
  - Given: 阵法 ACTIVE（requirement `{character_id: X}` 特定角色在场）；角色 X 在场
  - When: 角色 X 阵亡 → `character_removed` 信号触发重判
  - Then: 阵法变 UNACTIVE；发射 `formation_deactivated`；阵位保留（占用 1/3）
  - Edge cases: 阵亡角色不满足条件时不触发失效

- **AC-003**: 阵营人数下降 → 阵法失效
  - Given: 阵法 ACTIVE（requirement `{tag_id: "zhengdao", min_count: 3}`）；场上 3 正道
  - When: 1 个正道角色阵亡 → 场上剩 2 正道 → 信号触发重判
  - Then: 阵法变 UNACTIVE（`check_condition` 返回 false）；归属清除
  - Edge cases: 从 3 降到 2 但门槛为 2 时不应失效（门槛本身满足）

- **AC-004**: 阵眼复活重新上场 → 重新激活
  - Given: 阵法 UNACTIVE（requirement `{character_id: X}`）；角色 X 阵亡后复活重新上场
  - When: 角色 X 重新上场 → `character_deployed` 信号触发重判
  - Then: 阵法重新变 ACTIVE（无需重新打出）
  - Edge cases: 复活上场补足条件后立即激活

- **AC-005**: recheck_all_conditions 不发射信号
  - Given: 阵法区有阵法；直接调用 `recheck_all_conditions()`
  - When: 观察该方法是否直接发射 `formation_condition_reevaluated` 等信号
  - Then: 方法本身不发射任何信号；仅返回变更列表；批量发射由 `_on_field_changed` 处理器完成
  - Edge cases: 空变更列表时不发射 `formation_condition_reevaluated`

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/formation_system/test_activation_rejudge.gd` — must exist and pass
**Status**: [x] Created — 15 tests, all passing (AC-001~005 全覆盖 + 性能断言 + reason/changes 载荷验证)

---

## Dependencies

- Depends on: Story 001（状态机 + 阵法位数据 + 归属管理）；跨 Epic 依赖 deployment-system Story 002（`character_deployed` / `character_removed` 信号）——**deployment-system 尚未创建 story 文件，`/story-readiness` 会标记此依赖为 BLOCKED**
- Unlocks: Story 004（serialize_all 需在重判稳定后导出完整状态）
