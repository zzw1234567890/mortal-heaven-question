# Story 001：身份模板 const Dictionary（6 个）+ 查询 API

> **Epic**: identity-selection-system
> **Story**: 001
> **Type**: Logic
> **ADR**: ADR-0022
> **Status**: In Progress
> **Estimate**: 0.5d

## 描述

实现 IdentitySelectionSystem Autoload 的身份模板表（`IDENTITY_TEMPLATES` const Dictionary，6 个身份）和查询 API（`get_available_identities()` + `get_identity_preview()`）。模板为编译时常量，运行时只读。

## 验收标准

| # | AC |
|---|---|
| 1 | `IDENTITY_TEMPLATES` 常量包含恰好 6 个身份模板 |
| 2 | 每个模板含全部必需字段（name/description/flavor_text/style_tag/initial_deck/initial_resources/talent/character_details/unlock_condition） |
| 3 | `get_available_identities()` 返回 6 个条目 |
| 4 | 5 个默认身份 `is_unlocked == true`（ProgressionSystem 不可用时） |
| 5 | 阵道双杰 `is_unlocked == false`（无 `cang_xuan_walker` 天赋时） |
| 6 | 阵道双杰 `is_unlocked == true`（有 `cang_xuan_walker` 天赋时） |
| 7 | `get_identity_preview(有效ID)` 返回完整模板数据 |
| 8 | `get_identity_preview(无效ID)` 返回空字典 |
| 9 | 青云剑宗 `is_recommended == true` |
| 10 | 每个身份 `ling_shi` 符合 GDD（15/10/18/15/14/25） |
| 11 | 每个身份 `talent.id` + `magnitude` 符合 GDD |
| 12 | 每个身份 `initial_deck.cards` 符合 GDD 卡牌组成 |
| 13 | 每个身份 `character_slots` 符合 GDD 角色位配置 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/identity_selection_system.gd` | 6 身份模板 + 查询 API |
| `tests/unit/identity_selection_system/test_identity_templates.gd` | 13 条 AC 测试 |
| `tests/unit/identity_selection_system/progression_mock.gd` | ProgressionSystem 测试替身 |
| `project.godot` | 注册 IdentitySelectionSystem Autoload |

## GDD 来源

- `design/gdd/identity-selection-system.md` §1 身份定义结构、§2 六种身份详细定义、§7 身份影响范围
- ADR-0022 §关键接口 `get_available_identities()` / `get_identity_preview()`