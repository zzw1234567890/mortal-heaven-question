# Story 001：配方表（const Dictionary, 8 配方）+ 查询 API

> **Epic**: alchemy-crafting-system
> **Story**: 001
> **Type**: Logic
> **ADR**: ADR-0028
> **Status**: In Progress
> **Estimate**: 0.5d

## 描述

实现 AlchemySystem RefCounted 工具类的配方表（`ALCHEMY_RECIPES` 4 个炼丹配方 + `ARTIFACT_RECIPES` 4 个炼器配方）和查询 API。配方为编译时常量，运行时只读。

## 验收标准

| # | AC |
|---|---|
| 1 | `ALCHEMY_RECIPES` 包含恰好 4 个炼丹配方 |
| 2 | `ARTIFACT_RECIPES` 包含恰好 4 个炼器配方 |
| 3 | 每个配方含全部必需字段（name/materials/rarity/card_type/template_id/unlock_level） |
| 4 | 回春丹配方数据符合 GDD（低级×2, 蓝色, base_effect=4, unlock=0） |
| 5 | 九转金丹配方数据符合 GDD（顶级×2+高级×1, 暗金, base_effect=1, unlock=3） |
| 6 | 基础法器配方数据符合 GDD（低级×3, 蓝色, base_atk=3, unlock=0） |
| 7 | 通天灵宝配方数据符合 GDD（顶级×3+高级×1, 暗金, base_atk=10, unlock=3） |
| 8 | `has_pill_recipe(有效ID)` 返回 true |
| 9 | `has_pill_recipe(无效ID)` 返回 false |
| 10 | `get_pill_recipe(有效ID)` 返回完整配方数据 |
| 11 | `get_all_pill_recipes()` 返回 4 个条目 |
| 12 | `get_all_artifact_recipes()` 返回 4 个条目 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/alchemy_system.gd` | 配方表 + 查询 API |
| `tests/unit/alchemy_system/test_recipe_table.gd` | 12 条 AC 测试 |

## GDD 来源

- `design/gdd/alchemy-crafting-system.md` §1a 炼丹配方、§2a 炼器配方
- ADR-0028 §关键接口 ALCHEMY_RECIPES / ARTIFACT_RECIPES