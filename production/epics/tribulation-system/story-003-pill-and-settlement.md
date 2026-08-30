# Story 003: 渡劫丹辅助 + 成功/失败分支处理

> **Epic**: tribulation-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-30

## Context

**GDD**: `design/gdd/tribulation-system.md`
**Requirement**: `TR-trib-003`

**ADR Governing Implementation**: ADR-0021（渡劫突破系统——Feature Autoload 编排器 + CombatSystem 配置复用）
**ADR Decision Summary**: 渡劫丹在准备阶段使用（最多 2 枚，同种不叠加取最高稀有度）。渡劫成功调用 RealmSystem.realm_up + 重置失败计数 + 发射信号。渡劫失败扣除 max_cult × 0.15 修为 + 失败计数+1 + 连续 3 次解锁保护。

**Engine**: Godot 4.6 | **Risk**: LOW（纯逻辑 + GSM 写入 + 信号发射）
**Engine Notes**: RealmSystem.realm_up 已实现。GSM _set_consecutive_tribulation_failures 已实现（Story 5-10）。修为扣除通过 GSM.add_cultivation 负值（需验证）或直接 player.cultivation 操作。

**Control Manifest Rules (Feature 层)**:
- **Required**: 渡劫丹总上限 2 枚 —— 来源: GDD §边缘情况 + ADR-0021
- **Required**: 同种不叠加取最高稀有度 —— 来源: GDD §2 渡劫准备阶段
- **Required**: 渡劫成功调用 RealmSystem.realm_up —— 来源: ADR-0021 §_handle_tribulation_success
- **Required**: 连续失败计数持久化 —— 来源: ADR-0021 §consecutive_tribulation_failures
- **Forbidden**: 绕过 GSM 直接修改 consecutive_tribulation_failures —— 来源: ADR-0001

---

## Acceptance Criteria

*From ADR-0021 §use_tribulation_pill + §_handle_tribulation_success/failure + GDD §2/§4/§5/§7:*

- [ ] **AC-001**: `use_tribulation_pill(pill_data)` — 准备阶段使用渡劫丹，返回 true/false
- [ ] **AC-002**: 渡劫丹总上限 2 枚——第 3 枚被拒绝 + push_warning
- [ ] **AC-003**: 同种不叠加——取最高稀有度版本（替换低版本）
- [ ] **AC-004**: 非 PREPARING 状态使用渡劫丹被拒绝
- [ ] **AC-005**: `_handle_tribulation_success()` — 调用 realm_up + 重置失败计数 + 发射 tribulation_succeeded 信号
- [ ] **AC-006**: `_handle_tribulation_failure()` — 修为扣除（max_cult × 0.15，兜底≥0）+ 失败计数+1 + 发射 tribulation_failed
- [ ] **AC-007**: 连续失败 ≥3 时发射 tribulation_protection_unlocked 信号
- [ ] **AC-008**: `_on_battle_ended` 扩展——VICTORY 调用 _handle_success，DEFEAT 调用 _handle_failure
- [ ] **AC-009**: 渡劫成功后状态回到 NOT_READY（SUCCESS → NOT_READY）
- [ ] **AC-010**: 渡劫失败后状态回到 NOT_READY（FAILED → NOT_READY）

---

## Implementation Notes

*Derived from ADR-0021 §use_tribulation_pill + §_handle_tribulation_success/failure:*

1. **use_tribulation_pill(pill_data)**: 接受 Dictionary（含 type + rarity_tier）→ 检查 PREPARING → 检查上限 → 同种替换/追加
2. **_handle_tribulation_success()**: 调用 RealmSystem.realm_up → GSM._set_consecutive_tribulation_failures(0) → _set_state(SUCCESS) → 发射 tribulation_succeeded → _set_state(NOT_READY)
3. **_handle_tribulation_failure()**: 计算 penalty = floor(max_cult × 0.15) → 扣除修为 → 失败计数+1 → _set_state(FAILED) → 发射 tribulation_failed → 检查保护 → _set_state(NOT_READY)
4. **_on_battle_ended 扩展**: 从纯状态转换改为调用 _handle_success/failure
5. **修为扣除**: 直接操作 gsm.player.cultivation + _buffer_change（GSM.add_cultivation 不支持负值扣除）
6. **RealmSystem 引用**: 通过 _get_realm_system() 动态查找 + _realm_override 注入字段
7. **金卡奖励**: 桩阶段不实现——CardSystem 未接线，_handle_success 中留 TODO 标记

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 5-13**: 渡劫结果 GSM 同步 + 场景恢复——本 Story 只处理结算逻辑
- **InputManager 锁**: push_lock/pop_lock——Story 5-13
- **金卡奖励**: CardSystem 未接线——_handle_success 中留 TODO
- **行动力回满**: ActionPoints 系统监听 realm_upgraded 自动处理

---

## QA Test Cases

- **AC-001**: use_tribulation_pill 返回 true
- **AC-002**: 第 3 枚被拒绝
- **AC-003**: 同种取最高稀有度
- **AC-004**: 非 PREPARING 被拒绝
- **AC-005**: _handle_success 调用 realm_up + 重置计数 + 发射信号
- **AC-006**: _handle_failure 修为扣除 + 失败计数+1 + 发射信号
- **AC-007**: 连续 3 次失败发射 protection_unlocked
- **AC-008**: _on_battle_ended VICTORY→_handle_success，DEFEAT→_handle_failure
- **AC-009**: 成功后状态回到 NOT_READY
- **AC-010**: 失败后状态回到 NOT_READY

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/tribulation_system/test_pill_and_settlement.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 5-10（状态机）；Story 5-11（战斗委托 + _on_battle_ended）；RealmSystem.realm_up（已实现）
- Unblocks: Story 5-13（GSM 同步需要结算完成）
