# Story 004: 渡劫结果 GSM 同步 + 场景恢复

> **Epic**: tribulation-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-30

## Context

**GDD**: `design/gdd/tribulation-system.md`
**Requirement**: `TR-trib-004`

**ADR Governing Implementation**: ADR-0021（渡劫突破系统——Feature Autoload 编排器 + CombatSystem 配置复用）
**ADR Decision Summary**: 渡劫结算后 GSM 状态通过 batch_updated 传播。准备阶段可取消渡劫（cancel_tribulation）。结算后 _trib_type 和 _active_pills 清理。本 Story 验证 GSM 同步 + cancel + 清理 + 最终状态正确性。

**Engine**: Godot 4.6 | **Risk**: LOW（GSM batch_updated 已实现，cancel 是纯状态操作）
**Engine Notes**: GSM _buffer_change + call_deferred(_do_flush) 帧末传播。Serializer serialize/deserialize 往返已验证。均为 4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: 渡劫状态变更通过 GSM batch_updated 传播 —— 来源: ADR-0001 + ADR-0021
- **Required**: 准备阶段可取消渡劫 —— 来源: GDD §状态与转换（PREPARING→NOT_READY/READY）
- **Forbidden**: TribulationSystem 内部持有持久状态 —— 来源: ADR-0021 §GSM 轻量状态

---

## Acceptance Criteria

*From ADR-0021 §GSM 同步 + GDD §状态与转换 + §2 渡劫准备阶段:*

- [ ] **AC-001**: 渡劫成功后 batch_updated 传播 tribulation_state 变更
- [ ] **AC-002**: 渡劫失败后 batch_updated 传播 tribulation_state + cultivation 变更
- [ ] **AC-003**: 渡劫成功后 batch_updated 传播 consecutive_tribulation_failures 重置为 0
- [ ] **AC-004**: `cancel_tribulation()` — 准备阶段取消渡劫，回到 NOT_READY
- [ ] **AC-005**: 取消渡劫后 _active_pills 清空 + _trib_type 重置
- [ ] **AC-006**: 非 PREPARING 状态调用 cancel_tribulation 被拒绝
- [ ] **AC-007**: 渡劫结算后 _trib_type 和 _active_pills 被清理
- [ ] **AC-008**: `get_tribulation_status()` 在结算后返回 NOT_READY 状态
- [ ] **AC-009**: 连续失败计数器在成功后重置为 0（batch_updated 传播）
- [ ] **AC-010**: 渡劫结算后 GSM serialize 包含正确的最终状态

---

## Implementation Notes

*Derived from ADR-0021 §GSM 同步 + GDD §状态与转换:*

1. **cancel_tribulation()**: 验证 PREPARING → _set_state(NOT_READY) → 清理 _trib_type + _active_pills
2. **batch_updated 传播**: _handle_success/failure 中的 GSM 写入通过 _buffer_change → 帧末 batch_updated
3. **场景恢复**: 桩阶段不实现 SceneManager 调用——通过信号委托（UI 监听 tribulation_succeeded/failed 自行恢复）
4. **InputManager 锁**: 桩阶段不实现——ADR-0021 提到 push_lock 但 InputManager 集成在后续 Sprint
5. **最终状态验证**: serialize 后检查 player.tribulation_state == 0 + consecutive_tribulation_failures 正确值

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **SceneManager 调用**: 场景切换——UI 层监听信号处理
- **InputManager 锁**: push_lock/pop_lock——后续 Sprint 集成
- **金卡奖励**: CardSystem 未接线
- **行动力回满**: ActionPoints 系统监听 realm_upgraded

---

## QA Test Cases

- **AC-001**: 成功后 batch_updated 含 tribulation_state 路径
- **AC-002**: 失败后 batch_updated 含 tribulation_state + cultivation 路径
- **AC-003**: 成功后 batch_updated 含 consecutive_tribulation_failures 路径
- **AC-004**: cancel_tribulation 回到 NOT_READY
- **AC-005**: cancel 后 _active_pills 空 + _trib_type=NORMAL
- **AC-006**: 非 PREPARING cancel 被拒绝
- **AC-007**: 结算后 _trib_type=NORMAL + _active_pills 空
- **AC-008**: 结算后 get_tribulation_status 返回 NOT_READY
- **AC-009**: 成功后 consecutive_tribulation_failures=0
- **AC-010**: serialize 最终状态正确

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/tribulation_system/test_gsm_sync_and_cancel.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 5-10（状态机）；Story 5-11（战斗委托）；Story 5-12（成功/失败结算）
- Unblocks: tribulation-system Epic 完成（4/4 Story）
