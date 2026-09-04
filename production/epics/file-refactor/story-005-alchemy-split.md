# Story 5：alchemy_system.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 9
- **状态**: Done
- **预估**: 1.0d

## 目标

将 `alchemy_system.gd`（552 行）中的品质掷骰纯函数提取到 `alchemy_quality_roller.gd` RefCounted 子模块，主文件降至 ~500 行。

## 拆分内容

| 提取到 `alchemy_quality_roller.gd` (113 行) | 保留在 `alchemy_system.gd` (~500 行) |
|---|---|
| `quality_roll` | 灵材品质/稀有度常量 |
| `quality_reroll` | `QualityOutcome` / `CraftResult` 枚举 |
| `resolve_final_rarity` | `QUALITY_MOD` 常量 |
| `quality_mod_from_outcome` | `ALCHEMY_RECIPES` / `ARTIFACT_RECIPES` 配方表 |
| `pill_effect` | 配方查询 API（`has_pill_recipe` 等 6 个） |
| `forge_artifact_stat` | 炼制编排（`craft_pill` / `craft_artifact`） |
| `jindan_cumulative_threshold` | `apply_reroll` 品质重掷 |
| | 系统引用辅助（`_get_alchemy_level` 等 5 个） |
| | 薄委托（7 个 static 方法） |

## 架构特点

- **纯函数类**：`alchemy_quality_roller.gd` 为 static 纯函数类，不持有状态，所有方法接收参数返回结果。
- **常量委托**：子模块自带 `QUALITY_MOD` 映射，使用 int key（-1/0/1），主文件的 `QualityOutcome` 枚举通过 `int(outcome)` 转换后委托。
- **preload 引用**：主文件通过 `const _QualityRoller := preload("...")` 引用子模块，避免依赖 `class_name` 全局注册（兼容测试环境 `preload` 方式）。
- **薄委托**：7 个 static 方法保留在主文件作为薄委托，调用 `_QualityRoller` 同名方法。
- **无新增 Autoload**：RefCounted 子模块。

## 验证

- alchemy_system 单元测试：39/39 passed
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `alchemy_quality_roller.gd` 子模块创建（113 行）
- [x] `alchemy_system.gd` 主文件修改（~500 行）
- [x] 主文件保留配方表/查询 API/炼制编排 + 薄委托
- [x] alchemy_system 单元测试全部通过（39/39）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
