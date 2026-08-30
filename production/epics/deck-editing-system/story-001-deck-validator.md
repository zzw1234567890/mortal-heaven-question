# Story 001: 卡组验证器（卡组上限/添加/移除校验）

> **Epic**: deck-editing-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-30

## Context

**GDD**: `design/gdd/deck-editing-system.md`
**Requirement**: `TR-deck-001`

**ADR Governing Implementation**: ADR-0023（卡组编辑系统——Feature 层独立 Autoload + GSM deck 域存储 + 委托公式查询）
**ADR Decision Summary**: DeckEditingSystem 作为 Feature 层 Autoload（#22），持有卡组校验逻辑（上限/下限）和四种渠道的统一增删入口。卡组数据存储在 GSM `player.deck` 域中。上限委托 RealmSystem.get_current_property(&"deck_limit") 查询。

**Engine**: Godot 4.6 | **Risk**: LOW（Dictionary 操作 + GSM 写入 + RealmSystem 查询，均为 4.0+ 稳定 API）
**Engine Notes**: GSM 第二层写入模式遵循 _set_battle_phase 先例。RealmSystem.get_current_property 已实现 deck_limit 查询。

**Control Manifest Rules (Feature 层)**:
- **Required**: 卡组上限根据当前境界动态查询 —— 来源: GDD §核心规则 #7 + ADR-0023
- **Required**: 所有卡组增删通过 DeckEditingSystem 统一入口 —— 来源: ADR-0023 §四种渠道统一入口
- **Required**: 最低 5 张保护 —— 来源: GDD §核心规则 #3
- **Forbidden**: 绕过 DeckEditingSystem 直接操作 GSM.player.deck —— 来源: ADR-0023

---

## Acceptance Criteria

*From ADR-0023 §公共 API + GDD §核心规则 #3/#7 + §公式 #1/#4:*

- [ ] **AC-001**: `can_add_to_deck(count)` — 境界上限查询 + deck_limit_modifier + 当前张数比较，返回 `{allowed: bool, reason: String}`
- [ ] **AC-002**: `can_remove_from_deck(count)` — 最低 5 张保护，返回 `{allowed: bool, reason: String}`
- [ ] **AC-003**: `get_deck_limit()` — 委托 RealmSystem.get_current_property(&"deck_limit") + deck_limit_modifier
- [ ] **AC-004**: `add_cards_to_deck(card_ids, source, detail)` — 统一添加入口，校验 + GSM 第二层写入 + 变更日志
- [ ] **AC-005**: `remove_cards_from_deck(card_ids, source, detail)` — 统一删除入口，校验 + GSM 第二层写入 + 变更日志
- [ ] **AC-006**: `_append_change_log(card_ids, action, source, detail)` — 变更日志追加到 GSM player.deck.change_log
- [ ] **AC-007**: GSM serializer deck 域扩展为 ADR-0023 结构（current_deck / slots / change_log / session_remove_count / deck_limit_modifier）
- [ ] **AC-008**: GSM 第二层新增 `_set_deck_cards` / `_set_deck_session_remove_count` 原子写入方法
- [ ] **AC-009**: DeckEditingSystem Autoload 骨架（extends Node，不注册 project.godot）
- [ ] **AC-010**: `get_deck_cards()` 查询接口（返回 current_deck 副本）

---

## Implementation Notes

*Derived from ADR-0023 §GSM 数据模型 + §公共 API:*

1. **文件位置**: `src/feature/deck_editing_system.gd` — 新建 DeckEditingSystem Autoload 骨架
2. **extends Node 不声明 class_name** — 同 ExplorationSystem/CultivationSystem/TribulationSystem 先例
3. **不注册进 project.godot** — 待各系统接线后统一注册
4. **GSM serializer deck 域** — 从旧 `{character_slots, current_deck, presets}` 改为 ADR-0023 规范的 `{current_deck, slots, change_log, session_remove_count, deck_limit_modifier}`
5. **GSM 第二层** — `_set_deck_cards` / `_set_deck_session_remove_count` 遵循 `_set_battle_phase` 先例（null 守卫 + 去重 + _buffer_change）
6. **RealmSystem 引用** — 通过 _get_realm_system() 动态查找 + _realm_override 注入字段
7. **变更日志** — `_append_change_log` 写入 GSM player.deck.change_log 数组
8. **MINIMUM_DECK_SIZE** — 常量 = 5（GDD §核心规则 #3）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 5-15**: 卡组编辑 API + GSM deck.* 存储——本 Story 只实现验证器和基础增删
- **Story 5-16**: 卡组保存/加载 + 默认卡组——本 Story 不处理 serialize 往返
- **Story 5-17**: 卡组验证 UI 数据源接口——本 Story 不处理 UI
- **战利品编排**: generate_loot_options / apply_loot_choice——后续 Story
- **坊市操作**: execute_delete / execute_sell——后续 Story

---

## QA Test Cases

- **AC-001**: can_add_to_deck 满时拒绝，未满时允许
- **AC-002**: can_remove_from_deck 低于5张时拒绝
- **AC-003**: get_deck_limit 返回境界对应上限
- **AC-004**: add_cards_to_deck 成功写入 + 变更日志
- **AC-005**: remove_cards_from_deck 成功写入 + 变更日志
- **AC-006**: _append_change_log 追加日志条目
- **AC-007**: serializer deck 域含 ADR-0023 结构
- **AC-008**: _set_deck_cards / _set_deck_session_remove_count 写入 + batch_updated
- **AC-009**: DeckEditingSystem 实例化无报错
- **AC-010**: get_deck_cards 返回 current_deck 副本

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/deck_editing_system/test_deck_validator.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: GSM（已实现）；RealmSystem.get_current_property（已实现 deck_limit 查询）
- Unblocks: Story 5-15（卡组编辑 API 需要 _set_deck_cards）；Story 5-16（serialize 需要新 deck 结构）
