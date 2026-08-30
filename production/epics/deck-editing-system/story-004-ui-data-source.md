# Story 004: 卡组验证 UI 数据源接口

> **Epic**: deck-editing-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-30

## Context

**GDD**: `design/gdd/deck-editing-system.md`
**Requirement**: `TR-deck-004`

**ADR Governing Implementation**: ADR-0023（卡组编辑系统——Feature 层独立 Autoload + GSM deck 域存储 + 委托公式查询）
**ADR Decision Summary**: DeckEditingSystem 暴露只读查询接口供 UI 消费——get_deck_summary / get_deck_status / get_loot_options。所有接口为纯查询，不修改 GSM 状态。

**Engine**: Godot 4.6 | **Risk**: LOW（只读查询 + 聚合现有接口）
**Engine Notes**: 所有底层查询接口已在 Story 5-14/5-15 实现。本 Story 聚合为 UI 友好的摘要。

**Control Manifest Rules (Feature 层)**:
- **Required**: UI 数据源接口为只读查询 —— 来源: ADR-0023 §查询接口
- **Forbidden**: UI 数据源接口修改 GSM 状态 —— 来源: ADR-0023

---

## Acceptance Criteria

*From ADR-0023 §查询接口 + GDD §核心规则 #5/#7:*

- [ ] **AC-001**: `get_deck_summary()` — 返回 `{total, limit, is_full, is_minimal}` 供 UI 显示
- [ ] **AC-002**: `get_change_log()` — 返回变更日志副本（已在 5-14 实现，本 Story 验证）
- [ ] **AC-003**: `get_deck_limit()` — 返回当前境界上限（已在 5-14 实现，本 Story 验证）
- [ ] **AC-004**: `get_session_remove_count()` — 返回散功次数（已在 5-14 实现，本 Story 验证）
- [ ] **AC-005**: `get_delete_cost()` — 返回下次散功费用（已在 5-15 实现，本 Story 验证）
- [ ] **AC-006**: `can_add_to_deck()` 返回的 reason 可供 UI 直接显示
- [ ] **AC-007**: `can_remove_from_deck()` 返回的 reason 可供 UI 直接显示
- [ ] **AC-008**: `get_loot_options()` — 返回当前缓存的战利品选项（供 UI 展示）
- [ ] **AC-009**: `get_deck_status()` — 综合状态 `{deck_count, deck_limit, remove_count, can_delete}` 供 UI 刷新
- [ ] **AC-010**: UI 数据源接口全部为只读查询（不修改 GSM 状态）

---

## Implementation Notes

*Derived from ADR-0023 §查询接口 + GDD §核心规则 #5:*

1. **get_deck_summary()**: 聚合 get_deck_cards().size() + get_deck_limit() + is_full + is_minimal
2. **get_deck_status()**: 聚合 deck_count + deck_limit + remove_count + can_delete（=can_remove_from_deck.allowed）
3. **get_loot_options()**: 返回 _loot_options 副本
4. **只读验证**: 所有接口调用前后 GSM 状态不变

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*
- **UI 实现**: 本 Story 只提供数据源接口，不实现 UI 面板
- **卡牌详情**: CardSystem.get_template 查询——后续 Sprint 接线
- **角色位 UI**: slots 查询——后续 Sprint

---

## QA Test Cases

- **AC-001**: get_deck_summary 返回正确摘要
- **AC-002**: get_change_log 返回日志副本
- **AC-003**: get_deck_limit 返回境界上限
- **AC-004**: get_session_remove_count 返回散功次数
- **AC-005**: get_delete_cost 返回散功费用
- **AC-006**: can_add_to_deck reason 可显示
- **AC-007**: can_remove_from_deck reason 可显示
- **AC-008**: get_loot_options 返回缓存选项
- **AC-009**: get_deck_status 返回综合状态
- **AC-010**: 只读接口不修改 GSM 状态

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/deck_editing_system/test_ui_data_source.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 5-14（验证器）；Story 5-15（散功/拆解+战利品）；Story 5-16（默认卡组）
- Unblocks: deck-editing-system Epic 完成（4/4 Story）；Sprint 5 完成（17/17 Story）
