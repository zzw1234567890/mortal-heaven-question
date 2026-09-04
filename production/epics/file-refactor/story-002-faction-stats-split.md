# Story 2：faction_system.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 11
- **状态**: Done
- **预估**: 1.0d

## 目标

将 `faction_system.gd`（331 行）中的阵营关系判定逻辑（is_hostile_to / get_alignment_relation / _first_major_alignment）提取到 `faction_field_stats.gd` RefCounted 子模块，主文件降至 321 行。

## 拆分内容

| 提取到 `faction_field_stats.gd` (58 行) | 保留在 `faction_system.gd` (321 行) |
|---|---|
| `is_hostile_to` | `FactionRelation` 枚举 |
| `get_alignment_relation` | `FACTION_LIBRARY` const Dictionary（18 标签）|
| `_first_major_alignment` | 查询 API（`get_tag_info` / `get_major_alignments` / `derive_major_alignment`）|
| | `get_tags_of_character` / `belongs_to_alignment` |
| | `count_on_field` / `get_field_faction_distribution` / `check_condition` |
| | `_get_card_system` / `_get_field_characters` / `_get_instance_id` + `_get_field_stats()` 惰性初始化 + 薄委托 |

## 架构特点

- **持有 `_parent` 引用**：子模块通过 `_init(parent)` 构造注入，通过 `_parent.call()` / `_parent.get()` 访问父节点方法（`get_tags_of_character` / `derive_major_alignment`）和枚举（`FactionRelation`）。
- **惰性初始化**：`_get_field_stats()` 在首次调用时 `load().new(self)`。
- **薄委托**：主文件保留 2 个方法签名作为薄委托（`is_hostile_to` / `get_alignment_relation`）。
- **无新增 Autoload**：RefCounted 子模块。

## 验证

- faction_system 单元测试：27/27 passed
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `faction_field_stats.gd` 子模块创建（58 行）
- [x] `faction_system.gd` 主文件修改（321 行）
- [x] faction_system 单元测试全部通过（27/27）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
