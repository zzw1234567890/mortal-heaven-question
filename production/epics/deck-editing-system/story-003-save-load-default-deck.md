# Story 003: 卡组保存/加载 + 默认卡组

> **Epic**: deck-editing-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-30

## Context

**GDD**: `design/gdd/deck-editing-system.md`
**Requirement**: `TR-deck-003`

**ADR Governing Implementation**: ADR-0023（卡组编辑系统——Feature 层独立 Autoload + GSM deck 域存储 + 委托公式查询）
**ADR Decision Summary**: initialize_initial_deck 写入身份绑定的初始卡组，不受境界上限约束。deck 域通过 GSM serialize/deserialize 往返完整恢复。

**Engine**: Godot 4.6 | **Risk**: LOW（GSM serializer 已支持 deck 域，initialize 是纯写入操作）
**Engine Notes**: GSM serialize/deserialize 已实现。deck 域默认值已在 Story 5-14 扩展为 ADR-0023 结构。

**Control Manifest Rules (Feature 层)**:
- **Required**: 初始卡组不受境界上限约束 —— 来源: ADR-0023 §initialize_initial_deck
- **Required**: 卡组变更日志持久化到存档 —— 来源: GDD §核心规则 #8
- **Forbidden**: 绕过 DeckEditingSystem 初始化卡组 —— 来源: ADR-0023 §统一入口

---

## Acceptance Criteria

*From ADR-0023 §initialize_initial_deck + GDD §核心规则 #1/#8:*

- [ ] **AC-001**: `initialize_initial_deck(identity_preset)` — 写入初始卡组到 GSM，不受境界上限约束
- [ ] **AC-002**: 初始化后 deck 域全部重置（current_deck=预设, slots=默认, change_log=[], session_remove_count=0）
- [ ] **AC-003**: serialize/deserialize 往返——deck 域 current_deck 完整保留
- [ ] **AC-004**: deserialize 后 session_remove_count 正确恢复
- [ ] **AC-005**: deserialize 后 change_log 完整恢复
- [ ] **AC-006**: deserialize 后 deck_limit_modifier 正确恢复
- [ ] **AC-007**: 默认卡组常量（6 个身份的初始卡组 ID 列表）
- [ ] **AC-008**: `get_default_deck(identity_id)` — 根据身份 ID 返回初始卡组
- [ ] **AC-009**: 初始化卡组不受上限约束（6-7 张远低于 20 上限）
- [ ] **AC-010**: 重复初始化覆盖旧卡组

---

## Implementation Notes

*Derived from ADR-0023 §initialize_initial_deck + GDD §核心规则 #1:*

1. **initialize_initial_deck(identity_preset)**: 直接写入 GSM deck.current_deck + 重置 slots/change_log/session_remove_count
2. **默认卡组**: GDD §核心规则 #1 定义了 6 个身份的初始卡组——桩阶段用 card_instance_id 占位
3. **get_default_deck(identity_id)**: 返回 DEFAULT_DECKS 字典中对应身份的卡组
4. **serialize 往返**: 已由 GSM serializer 实现——本 Story 验证 deck 域往返正确性
5. **不受上限约束**: initialize 直接写入，不调用 can_add_to_deck
6. **重置**: 初始化时清空 change_log + session_remove_count + deck_limit_modifier

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 5-17**: 卡组验证 UI 数据源接口——本 Story 不处理 UI
- **角色位初始化**: slots 写入默认 [null×6]——角色绑定由 DeploymentSystem 处理
- **CardSystem 实例创建**: 初始卡组的 card_instance_id 由身份选择系统调用 CardSystem.create_instance 生成——本 Story 接受预设数组

---

## QA Test Cases

- **AC-001**: initialize 写入卡组
- **AC-002**: 初始化重置 deck 域
- **AC-003**: serialize 往返 current_deck
- **AC-004**: serialize 往返 session_remove_count
- **AC-005**: serialize 往返 change_log
- **AC-006**: serialize 往返 deck_limit_modifier
- **AC-007**: 默认卡组常量存在
- **AC-008**: get_default_deck 返回正确卡组
- **AC-009**: 初始化不受上限约束
- **AC-010**: 重复初始化覆盖

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/deck_editing_system/test_save_load_default_deck.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 5-14（验证器 + deck 域）；GSM serializer（已实现）
- Unblocks: Story 5-17（UI 数据源需要查询接口）
