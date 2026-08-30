# Story 002: 卡组编辑 API + GSM deck.* 存储

> **Epic**: deck-editing-system
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Estimate**: 0.5d
> **Manifest Version**: 2026-08-05
> **Last Updated**: 2026-08-30

## Context

**GDD**: `design/gdd/deck-editing-system.md`
**Requirement**: `TR-deck-002`

**ADR Governing Implementation**: ADR-0023（卡组编辑系统——Feature 层独立 Autoload + GSM deck 域存储 + 委托公式查询）
**ADR Decision Summary**: 散功/拆解通过 DeckEditingSystem 统一入口，委托 ResourceSystem 公式计算费用/价值。战利品编排由 DeckEditingSystem 生成选项+应用选择。所有操作通过 GSM 第二层写入。

**Engine**: Godot 4.6 | **Risk**: LOW（委托 ResourceSystem 已实现公式 + GSM 已实现 _set_deck_* 方法）
**Engine Notes**: ResourceSystem.delete_card_cost / dismantle_value / can_spend / spend_resource / add_resource 均已实现。

**Control Manifest Rules (Feature 层)**:
- **Required**: 散功/拆解通过 DeckEditingSystem 统一入口 —— 来源: ADR-0023 §四种渠道统一入口
- **Required**: 经济公式委托 ResourceSystem —— 来源: ADR-0023 §公式委托边界
- **Forbidden**: DeckEditingSystem 内部定义经济公式 —— 来源: ADR-0023

---

## Acceptance Criteria

*From ADR-0023 §坊市操作 + §战利品操作 + GDD §核心规则 #2/#3:*

- [ ] **AC-001**: `execute_delete(card_id)` — 散功：校验灵石 + remove_cards + session_remove_count+1 + 扣灵石
- [ ] **AC-002**: `get_delete_cost()` — 委托 ResourceSystem.delete_card_cost(session_remove_count + 1)
- [ ] **AC-003**: `execute_sell(card_id)` — 拆解：remove_cards + add_resource 灵石
- [ ] **AC-004**: `get_sell_price(card_id)` — 委托 ResourceSystem.dismantle_value（桩阶段用默认稀有度/等级）
- [ ] **AC-005**: 散功后 session_remove_count 递增（batch_updated 传播）
- [ ] **AC-006**: 散功时灵石不足被拒绝
- [ ] **AC-007**: 拆解时灵石正确增加（batch_updated 传播）
- [ ] **AC-008**: 散功低于最低张数保护时被拒绝
- [ ] **AC-009**: `generate_loot_options(enemy_data)` — 桩实现返回 3 个选项（2卡+1灵石模式）
- [ ] **AC-010**: `apply_loot_choice(option_index)` — 桩实现应用战利品选择

---

## Implementation Notes

*Derived from ADR-0023 §坊市操作 + §战利品操作:*

1. **execute_delete(card_id)**: get_delete_cost → can_spend → remove_cards_from_deck → spend_resource → _set_deck_session_remove_count+1
2. **get_delete_cost()**: 委托 ResourceSystem.delete_card_cost(session_remove_count + 1)（下次散功费用）
3. **execute_sell(card_id)**: get_sell_price → remove_cards_from_deck → ResourceSystem.add_resource
4. **get_sell_price(card_id)**: 桩阶段用默认 rarity=1, level=1 → dismantle_value × 1.0（100%回收率，GDD §3 ②拆解）
5. **generate_loot_options(enemy_data)**: 桩阶段返回固定 3 选项 [{type:card}, {type:card}, {type:lingshi}]
6. **apply_loot_choice(option_index)**: 桩阶段——card 选项 add_cards_to_deck，lingshi 选项 add_resource
7. **ResourceSystem 引用**: 通过 _get_resource_system() 动态查找 + _resource_override 注入字段
8. **GDD 注意**: GDD §3 ②拆解是 100% 回收率（非 ADR 中的 0.8 抽成——出售已移除，拆解=出售）

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 5-16**: 卡组保存/加载 + 默认卡组——本 Story 不处理 initialize_initial_deck
- **Story 5-17**: 卡组验证 UI 数据源接口——本 Story 不处理 UI
- **超限弃牌**: handle_overflow——后续 Sprint
- **角色位替换**: replace_character_slot——后续 Sprint
- **CardSystem 掉落规则**: 实际卡牌生成委托 CardSystem——本 Story 桩实现

---

## QA Test Cases

- **AC-001**: execute_delete 成功扣灵石+移除卡牌+计数+1
- **AC-002**: get_delete_cost 首次=50，第二次=75
- **AC-003**: execute_sell 成功加灵石+移除卡牌
- **AC-004**: get_sell_price 返回 dismantle_value
- **AC-005**: session_remove_count 递增
- **AC-006**: 灵石不足被拒绝
- **AC-007**: 拆解后灵石增加
- **AC-008**: 低于5张时散功被拒绝
- **AC-009**: generate_loot_options 返回 3 选项
- **AC-010**: apply_loot_choice 应用选择

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/deck_editing_system/test_deck_edit_api.gd` — must exist and pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 5-14（验证器 + _set_deck_cards + _set_deck_session_remove_count）；ResourceSystem（已实现）
- Unblocks: Story 5-16（保存/加载需要完整的 deck 操作 API）
