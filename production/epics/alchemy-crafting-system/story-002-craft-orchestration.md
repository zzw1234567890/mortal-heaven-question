# Story 002：craft_pill / craft_artifact 炼制编排

> **Epic**: alchemy-crafting-system
> **Story**: 002
> **Type**: Logic
> **ADR**: ADR-0028
> **Status**: In Progress
> **Estimate**: 0.5d
> **Dependencies**: Story 001

## 描述

实现 `craft_pill()` 和 `craft_artifact()` 炼制编排——校验灵材余额→扣减灵材→品质掷骰→生成卡牌实例→写入卡组。通过 ResourceSystem 消费灵材，通过 CardSystem 创建卡牌实例，通过 DeckEditingSystem 写入卡组。

## 验收标准

| # | AC |
|---|---|
| 1 | `craft_pill(有效配方, 灵材充足)` 返回 `result=SUCCESS` |
| 2 | craft_pill 成功后灵材已扣减 |
| 3 | craft_pill 成功后 `card_instance_id` 非零 |
| 4 | `craft_pill(灵材不足)` 返回 `result=INSUFFICIENT_MATERIALS`，灵材不变 |
| 5 | `craft_pill(无效配方ID)` 返回 `result=INVALID_RECIPE` |
| 6 | `craft_pill(等级不足)` 返回 `result=RECIPE_LOCKED` |
| 7 | `craft_artifact(有效配方, 灵材充足)` 返回 `result=SUCCESS` |
| 8 | `craft_pill(is_dadao_active=true)` 返回 `first_roll=UPGRADE` |
| 9 | craft_pill 成功后卡组新增 1 张卡牌 |
| 10 | craft_pill 返回包含 `final_rarity` + `quality_mod` |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/alchemy_system.gd` | craft_pill + craft_artifact + 辅助方法 |
| `tests/unit/alchemy_system/test_craft_orchestration.gd` | 10 条 AC 测试 |
| `tests/unit/alchemy_system/resource_mock.gd` | ResourceSystem 测试替身 |
| `tests/unit/alchemy_system/card_system_mock.gd` | CardSystem 测试替身 |
| `tests/unit/alchemy_system/deck_mock.gd` | DeckEditingSystem 测试替身 |

## GDD 来源

- `design/gdd/alchemy-crafting-system.md` §1b 品质浮动机器、§2b 炼器品质机制
- ADR-0028 §关键接口 craft_pill / craft_artifact