# Story 001：DialoguePlayer 条件评估器接线

> **Epic**: misc-wiring
> **Story**: 001
> **Type**: Logic
> **Status**: Done
> **Estimate**: 0.5d

## 描述

将 DialoguePlayer `_evaluate_condition` 中的 8 种桩条件类型接线到 GSM 查询，替换 `return true` 桩代码。同时新增 `_compare_numeric` 辅助方法支持数值比较运算符。

## 验收标准

| # | AC |
|---|---|
| 1 | story_flag 条件通过 EventSystem.get_flag 查询（已有实现，保持不变） |
| 2 | identity 条件通过 GSM player.identity_id 查询 |
| 3 | realm 条件通过 GSM player.realm 查询，支持 >=, <=, ==, !=, >, < 运算符 |
| 4 | faction 条件通过 GSM narrative.story_flags["player_faction"] 查询 |
| 5 | card_owned 条件通过 GSM collection.owned_cards 查询 template_id 匹配 |
| 6 | chapter_completed 条件通过 GSM narrative.completed_chapters 查询 |
| 7 | has_item 条件通过 GSM player.resources 查询资源数量 >= 阈值（ling_cai 求四品质总和） |
| 8 | combat_result 条件通过 GSM battle.last_result 查询 |
| 9 | always 条件始终返回 true（不变） |
| 10 | 未知条件类型默认返回 true（不变） |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/dialogue/dialogue_player.gd` | `_evaluate_condition` 接线 8 种条件类型 + 新增 `_compare_numeric` |
| `tests/unit/dialogue_system/test_condition_evaluator.gd` | 10 AC 验收测试（17 个测试用例） |

## 测试结果

- 单系统测试：dialogue_system 47/47 通过（含新增 17 个）
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing
- 零回归
