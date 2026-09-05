# Story 005: alchemy_system.gd + story_system.gd 拆分

> **Epic**: file-refactor
> **Sprint**: 9-10
> **状态**: Done
> **预估**: 2.0d

## 拆分内容

### alchemy_system.gd（552→~500 行）— Sprint 9

| 提取到 `alchemy_quality_roller.gd` (113 行) | 保留在 `alchemy_system.gd` (~500 行) |
|---|---|
| `quality_roll` / `quality_reroll` / `resolve_final_rarity` / `quality_mod_from_outcome` / `pill_effect` / `forge_artifact_stat` / `jindan_cumulative_threshold` | 灵材品质/稀有度常量 / `QualityOutcome` / `CraftResult` 枚举 / `QUALITY_MOD` / 配方表 / 查询 API / 炼制编排 / `apply_reroll` + 薄委托 |

- 纯函数 static 类，不持有状态。`const _QualityRoller := preload(...)` 引用。

### story_system.gd（418→322 行）— Sprint 10

| 提取到 `story_chapter_ops.gd` (166 行) | 保留在 `story_system.gd` (322 行) |
|---|---|
| `complete_chapter` / `is_boss_unlocked` / `on_boss_defeated` / `_emit_safe`（子模块私有——信号 owner 为 `_parent`） | `CHAPTER_TEMPLATES` 常量 / 信号声明 / 模板查询 API / 章节进入条件验证 / 章节上下文查询 + 薄委托 |

## 验证

- alchemy_system: 39/39；story_system: 40/40
- 全量测试零回归
- 无新增 Autoload
