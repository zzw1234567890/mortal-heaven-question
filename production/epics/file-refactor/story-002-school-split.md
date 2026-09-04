# Story 2：school_system.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 9
- **状态**: Done
- **预估**: 1.0d

## 目标

将 `school_system.gd`（688 行）中的 10 个条件评估器 + 分派器 + 辅助方法提取到 `school_conditions.gd` RefCounted 子模块，主文件降至 ~311 行。

## 拆分内容

| 提取到 `school_conditions.gd` (~409 行) | 保留在 `school_system.gd` (~311 行) |
|---|---|
| `check_all_conditions` / `evaluate_condition` 分派器 | `SCHOOL_LIBRARY` 编译时常量（5 流派完整定义） |
| 10 个 `_eval_*` 评估器 | `detect()` / `calculate_match()` 公共 API |
| `_char_matches_tags` / `_is_tag_under_alignment` / `_get_tag_display_name` / `_tags_display` 辅助方法 | `get_school_info` / `get_school_effects` / `get_all_schools` 查询 API |
| | `_get_conditions()` 惰性初始化 + `_check_all_conditions` / `_evaluate_condition` 薄委托 |

## 架构特点

- **纯函数类**：`school_conditions.gd` 不持有 `_parent` 引用（与 Sprint 8 其他子模块不同），因为所有评估器是无状态纯函数，接收 `(cond, state)` 返回统一结构 `{satisfied, weight, score, missing_text, skipped}`。
- **惰性初始化**：`_get_conditions()` → `load("res://src/core/school_system/school_conditions.gd").new()`，首次调用时创建实例。
- **薄委托**：`_check_all_conditions` 和 `_evaluate_condition` 在主文件保留为薄委托方法，调用子模块同名方法。
- **无新增 Autoload**：RefCounted 子模块，不注册全局名。

## 评估器清单（10 个）

| 类型 | 评估器 | 权重 | 硬性 |
|---|---|---|---|
| `faction_count` | `_eval_faction_count` | 40 | 否 |
| `faction_ratio` | `_eval_faction_ratio` | 40 | 否 |
| `excluded_faction` | `_eval_excluded_faction` | 0 | 是（skipped） |
| `card_type_ratio` | `_eval_card_type_ratio` | 20 | 否 |
| `min_realm` | `_eval_min_realm` | 10 | 否 |
| `min_alchemy_count` | `_eval_min_alchemy_count` | 10 | 否 |
| `required_characters` | `_eval_required_characters` | 30 | 否 |
| `avg_card_cost` | `_eval_avg_card_cost` | 20 | 否 |
| `min_rarity` | `_eval_min_rarity` | 0 | 是（skipped） |
| `max_dark_gold_count` | `_eval_max_dark_gold_count` | 0 | 是（skipped） |

## 验证

- school_system 单元测试：53/53 passed
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `school_conditions.gd` 子模块创建（~409 行）
- [x] `school_system.gd` 主文件修改（~311 行）
- [x] 主文件保留常量/信号/公共 API + 薄委托
- [x] school_system 单元测试全部通过（53/53）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
