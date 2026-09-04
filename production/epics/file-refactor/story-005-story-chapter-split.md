# Story 5：story_system.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 10
- **状态**: Done
- **预估**: 1.0d

## 目标

将 `story_system.gd`（418 行）中的章节完成编排逻辑（complete_chapter + is_boss_unlocked + on_boss_defeated）提取到 `story_chapter_ops.gd` RefCounted 子模块，主文件降至 322 行。

## 拆分内容

| 提取到 `story_chapter_ops.gd` (166 行) | 保留在 `story_system.gd` (322 行) |
|---|---|
| `complete_chapter` | `CHAPTER_TEMPLATES` const Dictionary（5 章数据）|
| `is_boss_unlocked` | 信号声明（`chapter_completed` / `boss_unlocked` / `chapter_started` / `game_victory`）|
| `on_boss_defeated` | 模板查询 API（`get_chapter_data` / `get_all_chapter_ids`）|
| `_emit_safe`（子模块私有——信号 owner 为 `_parent`） | 章节进入条件验证（`can_enter_chapter` / `_get_prev_chapter_id`）|
| | 章节上下文查询（`get_chapter_context`）|
| | `_get_gsm` + `_get_chapter_ops()` 惰性初始化 + 薄委托 |

## 架构特点

- **持有 `_parent` 引用**：子模块通过 `_init(parent)` 构造注入，通过 `_parent.call()` / `_parent.get()` 访问父节点状态和方法。
- **信号 owner 为 `_parent`**：`_emit_safe` 在子模块中将信号 owner 设为 `_parent`（StorySystem），而非子模块自身——信号声明在父节点上。
- **惰性初始化**：`_get_chapter_ops()` 在首次调用时 `load().new(self)`。
- **薄委托**：主文件保留 3 个方法签名作为薄委托。
- **无新增 Autoload**：RefCounted 子模块。

## 验证

- story_system 单元测试：40/40 passed（4 scripts）
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `story_chapter_ops.gd` 子模块创建（166 行）
- [x] `story_system.gd` 主文件修改（322 行）
- [x] story_system 单元测试全部通过（40/40）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
