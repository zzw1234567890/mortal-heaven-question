# Story 001：CombatSystem 牌库管理内建

> **Epic**: combat-wiring
> **Story**: 001
> **Type**: Logic
> **Status**: Done
> **Estimate**: 0.5d

## 描述

替换 CombatSystem 的 _deck/_discard_pile/_hand 桩数组为正式内建牌库管理 API。新增 init_deck / discard_card / shuffle_discard_into_deck 方法，使 CombatSystem 在战斗开始时能从卡组数据初始化牌库、抽牌、弃牌、洗牌。不新建 DeckSystem——战斗内牌库管理归 CombatSystem 内建。

## 验收标准

| # | AC |
|---|---|
| 1 | init_deck(card_ids: Array) 接收卡组 ID 列表并洗牌初始化 _deck |
| 2 | init_deck 后 _deck.size() == card_ids.size()，_hand 和 _discard_pile 为空 |
| 3 | _draw_cards 抽牌后手牌增加，牌库减少对应数量 |
| 4 | discard_card(card_instance_id) 将手牌中的卡牌移到弃牌堆 |
| 5 | shuffle_discard_into_deck() 将弃牌堆全部洗回牌库，弃牌堆清空 |
| 6 | 牌库+弃牌堆均空时 _draw_cards 不崩溃，静默跳过 |
| 7 | set_deck_state 保留为测试注入用（标记 deprecated） |
| 8 | get_deck / get_discard_pile / get_hand 保留为查询 API |
| 9 | init_deck 使用 _rng 洗牌，set_rng_seed 后确定性可复现 |
| 10 | 全量测试零回归 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/combat_system.gd` | 新增 init_deck / discard_card / shuffle_discard_into_deck |
| `tests/unit/combat_system/test_deck_management.gd` | 10 条 AC 测试 |
