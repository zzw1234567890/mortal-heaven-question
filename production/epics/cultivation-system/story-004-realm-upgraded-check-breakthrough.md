# Story 004: realm_upgraded 信号订阅 + check_breakthrough

> **Epic**: cultivation-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-29

## Context

**GDD**: `design/gdd/cultivation-system.md`
**Requirement**: `TR-cult-004`
*（需求文本见 `docs/architecture/tr-registry.yaml`——审查时读取最新版）*

**ADR Governing Implementation**: 待定（CultivationSystem ADR 尚未编写——本 Story 遵循 GDD §4-6 + GSM realm_changed 信号）
**ADR Decision Summary**: CultivationSystem 订阅 GSM realm_changed 信号，在境界变化时自动更新 max_cultivation 并触发 settle_overflow。check_breakthrough 提供突破条件检查——cultivation_full 为 true 时返回可突破。

**Engine**: Godot 4.6 | **Risk**: LOW（GSM realm_changed 信号已实现，CultivationSystem 是消费者）
**Engine Notes**: GSM realm_changed(old, new) 在 change_realm 后帧末发射。信号连接在 _ready 中建立。均为 4.0+ 稳定 API。

**Control Manifest Rules (Feature 层)**:
- **Required**: 境界变化时自动更新 max_cultivation —— 来源: GDD §6
- **Required**: 突破条件检查由 CultivationSystem 统一提供 —— 来源: GDD §4
- **Forbidden**: 绕过 CultivationSystem 直接检查突破条件 —— 来源: 统一入口原则

---

## Acceptance Criteria

*From GDD §4-6 修为满值提示 + 突破后修为处理:*

- [ ] **AC-001**: `_ready()` 中订阅 GSM realm_changed 信号
- [ ] **AC-002**: `check_breakthrough()` 返回 bool——cultivation_full 为 true 时返回 true
- [ ] **AC-003**: `on_realm_changed(old_realm, new_realm)` 回调——境界变化时调用 update_max_cultivation(new_realm)
- [ ] **AC-004**: `request_breakthrough()` 返回突破请求 Dictionary {can_breakthrough, current_realm, cultivation, overflow_pool}
- [ ] **AC-005**: 境界变化后 batch_updated 传播 max_cultivation 变更
- [ ] **AC-006**: `get_breakthrough_status()` 返回 {can_breakthrough, realm, cultivation_full, overflow_pool} 供 UI 查询

---

## Implementation Notes

*Derived from GDD §4-6 + GSM realm_changed 信号:*

1. **文件位置**: `src/feature/cultivation_system.gd` — 新增 _ready + on_realm_changed + check_breakthrough + request_breakthrough + get_breakthrough_status
2. **_ready()**: 订阅 GSM.realm_changed.connect(on_realm_changed)
3. **on_realm_changed(old, new)**: 调用 update_max_cultivation(new) [Story 5-8 已实现]
4. **check_breakthrough()**: 返回 check_cultivation_full() [Story 5-6 已实现]
5. **request_breakthrough()**: 返回完整突破信息 Dictionary
6. **get_breakthrough_status()**: 扩展查询——供 UI 显示突破按钮状态

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 5-10**: 渡劫流程编排——本 Story 只提供突破条件和请求接口
- **渡劫台节点**: exploration-system 职责——本 Story 不关心节点类型
- **突破失败**: 渡劫系统职责——本 Story 只检查条件

---

## QA Test Cases

- **AC-001**: _ready 订阅 realm_changed
- **AC-002**: check_breakthrough 返回正确 bool
- **AC-003**: on_realm_changed 更新 max_cultivation
- **AC-004**: request_breakthrough 返回完整信息
- **AC-005**: 境界变化后 batch_updated 传播
- **AC-006**: get_breakthrough_status 返回正确结构

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/cultivation_system/test_realm_upgraded_breakthrough.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 5-6（gain_cultivation, check_cultivation_full）；Story 5-8（update_max_cultivation, settle_overflow）
- Unblocks: tribulation-system Epic（渡劫流程需要 request_breakthrough）