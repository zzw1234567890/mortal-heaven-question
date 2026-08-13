# Story 003: 战斗结束 snapshot 导出 GSM + 暂挂/恢复排序

> **Epic**: status-effect
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 1d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-12

## Context

**GDD**: `design/gdd/status-system.md`
**Requirement**: `TR-status-002`（状态快照持久化 + 暂挂/恢复）
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: ADR-0011（状态效果系统——snapshot 导出 + 暂挂/恢复 + GSM 例外模式）
**ADR Decision Summary**: 战斗结束时 StatusEffectSystem 通过 `export_snapshot()` 导出所有活跃状态快照写入 GSM battle 域（GSM 例外——仅快照不存活跃实例）。暂挂（suspend）将状态移入 `_suspended` 注册表冻结倒计时；恢复（restore）按 priority 降序重新激活并保证与 BindingManager 排序契约一致。

**Engine**: Godot 4.6 | **Risk**: MEDIUM（涉及 GSM 第二层原子方法 + BindingManager 跨系统排序契约——需验证时序）
**Engine Notes**: snapshot 用 Array[Dictionary] 序列化（RefCounted 实例不可直接序列化）。暂挂/恢复用注册表迁移（非深拷贝——实例引用转移）。

**Control Manifest Rules (Core 层)**:
- **Required**: GSM 例外——活跃状态不存 GSM，仅战斗结束快照写入 `battle.status_snapshot`
- **Required**: 暂挂/恢复与 BindingManager 排序契约一致——同 priority 按 applied_turn 稳定排序
- **Forbidden**: snapshot 存活跃 StatusInstance 引用——必须序列化为 Dictionary（避免 RefCounted 生命周期问题）
- **Forbidden**: 恢复时重排 priority——恢复保持原 priority，仅按其排序激活

---

## Acceptance Criteria

*From ADR-0011 §snapshot 导出 §暂挂/恢复 §GSM 例外 + GDD status-system.md §验收标准:*

- [x] **AC-001**: `export_snapshot()` 返回 Array[Dictionary]，每个字典含 id/template_id/target_id/duration/applied_turn/value/current_stacks/source_card_instance_id/priority/is_hidden
- [x] **AC-002**: snapshot 仅含活跃状态（is_expired=true 的排除）
- [x] **AC-003**: snapshot 按目标分组——同 target_id 的状态连续排列
- [x] **AC-004**: `write_snapshot_to_gsm()` 调用 `GSM._set_battle_status_snapshot(snapshot)` 写入 battle 域
- [x] **AC-005**: GSM 不可用时 `write_snapshot_to_gsm` 不崩溃（`is_instance_valid` + `has_method` 守卫）
- [x] **AC-006**: `GSM._set_battle_status_snapshot(snapshot)` 通过 `_buffer_change` 管线 + 帧末 `batch_updated` 发射
- [x] **AC-007**: `batch_updated` 载荷含 `battle.status_snapshot: {old, new}` 展平字典
- [x] **AC-008**: `suspend_status(status_id)` 将实例从 `_instances`/`_by_target` 迁入 `_suspended`——倒计时冻结
- [x] **AC-009**: 暂挂状态不在 `get_active_statuses` 中返回
- [x] **AC-010**: 暂挂状态 `tick_all` 不递减 duration
- [x] **AC-011**: `restore_status(status_id)` 将实例从 `_suspended` 迁回 `_instances`/`_by_target`——倒计时恢复
- [x] **AC-012**: 恢复后状态在 `get_active_statuses` 中重新出现
- [x] **AC-013**: `restore_all_suspended(target_id)` 按 priority 降序 + applied_turn 升序恢复（稳定性保证）
- [x] **AC-014**: 恢复时若目标已达 20 上限——触发驱逐（复用 Story 002 _evict_lowest）后恢复
- [x] **AC-015**: 与 BindingManager 排序契约：恢复后的状态激活顺序与 BindingManager 计算的 effect_order 一致
- [x] **AC-016**: `get_suspended_statuses(target_id)` 返回该目标暂挂状态列表
- [x] **AC-017**: snapshot 序列化 round-trip——export 后 import（`import_snapshot(arr)`）重建状态，字段一致
- [x] **AC-018**: import_snapshot 跳过 is_expired 条目（不恢复已过期状态）

---

## Implementation Notes

*Derived from ADR-0011 §snapshot 导出 §暂挂/恢复 §GSM 例外模式:*

1. **export_snapshot 实现**: 遍历 `_instances` → 过滤 is_expired → 序列化为 Dictionary → 按 target_id 分组排序
2. **write_snapshot_to_gsm 实现**: `if is_instance_valid(GSM) and GSM.has_method("_set_battle_status_snapshot"): GSM._set_battle_status_snapshot(export_snapshot())`
3. **GSM 第二层方法**: 在 `game_state_manager.gd` 新增 `_set_battle_status_snapshot(snapshot: Array) -> void` —— 走 `_buffer_change("battle.status_snapshot", ...)` 管线
4. **suspend_status 实现**: 从 `_instances` + `_by_target` 移除 → 加入 `_suspended: Dictionary[int, StatusInstance]`（key=status_id）→ 实例引用转移（非深拷贝）
5. **restore_status 实现**: 从 `_suspended` 移除 → 重新加入 `_instances` + `_by_target` → 检查 20 上限
6. **restore_all_suspended 排序**: 取 `_suspended` 中该 target_id 的所有实例 → 排序 (priority DESC, applied_turn ASC) → 依次 restore
7. **BindingManager 契约**: 恢复顺序 = BindingManager.effect_order 计算（同 priority 按 applied_turn）——本 Story 仅保证排序一致性，BindingManager 实现属战斗 Epic
8. **import_snapshot 实现**: 遍历 snapshot 数组 → 跳过 is_expired → 重建 StatusInstance → 注册到 `_instances`/`_by_target`（分配新 status_id 或保留原 id 视语义）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: StatusTemplate/Instance 双层模型 + 8 阶段管线核心——已实现
- **Story 002**: 3 叠加规则 + 免疫 + 20 上限——已实现（本 Story 复用 _evict_lowest）
- **BindingManager 实现**: effect_order 计算——战斗 Epic（ADR-0010）职责
- **CombatSystem 战斗结束编排**: 调用 write_snapshot_to_gsm 的时机——战斗 Epic 职责
- **存档/读档集成**: snapshot 写入存档——存档 Epic（ADR-0004）职责（本 Story 仅导出到 GSM battle 域）

---

## QA Test Cases

*From QA 计划 qa-plan-sprint-3-2026-08-10.md §Story 3-6 + ADR-0011 §验证标准:*

- **AC-001**: export_snapshot 返回结构
  - Given: 目标有 3 个活跃状态
  - When: `ses.export_snapshot()`
  - Then: 返回 Array 含 3 个 Dictionary，各含 id/template_id/target_id/duration/applied_turn/value/current_stacks/source_card_instance_id/priority/is_hidden
  - Edge cases: metadata 字段可选包含

- **AC-002**: snapshot 排除过期状态
  - Given: 目标有 3 个活跃状态 + 1 个 is_expired=true 未移除
  - When: `ses.export_snapshot()`
  - Then: 返回 3 个字典（过期的不含）
  - Edge cases: 过期状态仍在 get_active_statuses 直到 remove_expired

- **AC-003**: snapshot 按目标分组
  - Given: 2 个目标各 2 个状态
  - When: `ses.export_snapshot()`
  - Then: 同 target_id 的状态连续排列
  - Edge cases: target_id 升序分组

- **AC-004**: write_snapshot_to_gsm 调用 GSM 方法
  - Given: GSM Autoload 可用
  - When: `ses.write_snapshot_to_gsm()`
  - Then: 调用 `GSM._set_battle_status_snapshot(snapshot)`
  - Edge cases: snapshot 非空时写入

- **AC-005**: GSM 不可用不崩溃
  - Given: 测试环境模拟 GSM 不可用
  - When: `ses.write_snapshot_to_gsm()`
  - Then: 不崩溃，静默跳过
  - Edge cases: `is_instance_valid(GSM)` + `has_method` 双守卫

- **AC-006**: GSM._set_battle_status_snapshot 写入 battle 域
  - Given: GSM Autoload 可用
  - When: `GSM._set_battle_status_snapshot(arr)`
  - Then: `GSM.battle.status_snapshot == arr`
  - Edge cases: 通过 `get_state("battle.status_snapshot")` 读取一致

- **AC-007**: batch_updated 载荷含 snapshot 路径
  - Given: 订阅 `GSM.batch_updated`
  - When: `GSM._set_battle_status_snapshot(arr)` 后帧末刷新
  - Then: 载荷含 `"battle.status_snapshot": {old, new}`
  - Edge cases: 展平路径字典（ADR-0001）

- **AC-008**: suspend_status 迁移到 _suspended
  - Given: 目标有 status_id=5 活跃状态
  - When: `ses.suspend_status(5)`
  - Then: `_instances` 不含 5，`_suspended` 含 5
  - Edge cases: `_by_target` 同步移除

- **AC-009**: 暂挂状态不在 get_active_statuses
  - Given: status_id=5 已暂挂
  - When: `ses.get_active_statuses(target_id)`
  - Then: 返回列表不含 5
  - Edge cases: get_active_count 也排除暂挂

- **AC-010**: 暂挂状态不倒计时
  - Given: status_id=5（duration=3）已暂挂
  - When: `ses.tick_all([character])`
  - Then: `_suspended[5].duration` 仍为 3（不递减）
  - Edge cases: 暂挂完全冻结

- **AC-011**: restore_status 迁回活跃
  - Given: status_id=5 已暂挂
  - When: `ses.restore_status(5)`
  - Then: `_suspended` 不含 5，`_instances` 含 5
  - Edge cases: `_by_target` 同步添加

- **AC-012**: 恢复后重新出现在 get_active_statuses
  - Given: status_id=5 已恢复
  - When: `ses.get_active_statuses(target_id)`
  - Then: 返回列表含 5
  - Edge cases: duration 保持暂挂前值

- **AC-013**: restore_all_suspended 排序
  - Given: 目标有 3 个暂挂状态（priority 2/5/3，applied_turn 各异）
  - When: `ses.restore_all_suspended(target_id)`
  - Then: 按 priority 降序 + applied_turn 升序恢复
  - Edge cases: 稳定排序保证确定性

- **AC-014**: 恢复时触发 20 上限驱逐
  - Given: 目标已有 20 活跃 + 2 暂挂
  - When: `ses.restore_all_suspended(target_id)`
  - Then: 恢复过程中触发驱逐，最终活跃=20
  - Edge cases: 复用 _evict_lowest（Story 002）

- **AC-015**: BindingManager 排序契约
  - Given: 恢复后的状态列表
  - When: 与 BindingManager.effect_order 对比
  - Then: 激活顺序一致（同 priority 按 applied_turn）
  - Edge cases: 本 Story 仅保证排序一致，BindingManager 实现属战斗 Epic

- **AC-016**: get_suspended_statuses 查询
  - Given: 目标有 2 个暂挂状态
  - When: `ses.get_suspended_statuses(target_id)`
  - Then: 返回 2 个 status_id
  - Edge cases: 无暂挂返回空数组

- **AC-017**: snapshot round-trip
  - Given: 3 个活跃状态
  - When: `arr = ses.export_snapshot()` → 清空 → `ses.import_snapshot(arr)`
  - Then: 重建后字段一致（id 可能重分配，其他字段一致）
  - Edge cases: template_id/duration/value/current_stacks/priority 一致

- **AC-018**: import_snapshot 跳过过期
  - Given: snapshot 数组含 1 个 is_expired=true 条目
  - When: `ses.import_snapshot(arr)`
  - Then: 过期条目不恢复
  - Edge cases: 仅恢复 is_expired=false 的条目

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/status_effect/test_snapshot_suspend.gd` — must exist and pass
**Status**: [x] Created and passing（23 个测试函数，23 passed / 0 failed / 覆盖 AC-001 到 AC-018 + 边缘情况补强）

---

## Dependencies

- Depends on: Story 001（注册表 + 实例模型）+ Story 002（_evict_lowest 复用 + 20 上限）
- Unlocks: 战斗 Epic（CombatSystem 战斗结束调用 write_snapshot_to_gsm）；存档 Epic（snapshot 持久化到存档）
