# Story 6：progression_system.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 9
- **状态**: Done
- **预估**: 1.0d

## 目标

将 `progression_system.gd`（520 行）中的序列化/初始化逻辑提取到 `progression_serializer.gd` RefCounted 子模块，主文件降至 456 行。

## 拆分内容

| 提取到 `progression_serializer.gd` (124 行) | 保留在 `progression_system.gd` (456 行) |
|---|---|
| `init_empty_stores` | 信号声明（`progression_initialized` / `progression_updated` 等） |
| `load_progression_data` | 6 个域存储字段 + 内部标志 |
| `initialize` | `_ready()` 生命周期 |
| `serialize` | achievements / talents / endings / gallery / stats / meta 领域 API |
| `deserialize` | 批量更新 API（`batch_update_begin` / `batch_update_end`） |
| `_safe_dict` / `_safe_str` / `_safe_int` 静态辅助 | 脏标志 API（`has_unsaved_changes` / `mark_saved`） |
| | `_mark_dirty_and_emit` / `_get_save_load_system` |
| | `_get_serializer()` 惰性初始化 + 薄委托 |

## 架构特点

- **持有 `_parent` 引用**：子模块通过 `_parent.get()` / `_parent.set()` / `_parent.call()` 访问父节点域存储和系统引用。
- **惰性初始化**：`_get_serializer()` 在首次调用时 `load("res://src/meta/progression/progression_serializer.gd").new(self)`。
- **静态安全辅助迁移**：`_safe_dict` / `_safe_str` / `_safe_int` 作为 static 方法移入子模块，主文件不再保留。
- **保留原因**：6 个领域 API（achievements/talents/endings/gallery/stats/meta）和批量更新逻辑与域存储紧耦合，保留在主文件。
- **无新增 Autoload**：RefCounted 子模块。

## 验证

- progression_system 单元测试：50/50 passed
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `progression_serializer.gd` 子模块创建（124 行）
- [x] `progression_system.gd` 主文件修改（456 行）
- [x] 主文件保留域存储/领域 API/批量更新 + 薄委托
- [x] progression_system 单元测试全部通过（50/50）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
