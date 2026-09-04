# Story 4：identity_selection_system.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 9
- **状态**: Done
- **预估**: 1.0d

## 目标

将 `identity_selection_system.gd`（624 行）中的初始卡牌/角色创建逻辑提取到 `identity_initializer.gd` RefCounted 子模块，主文件降至 556 行。

## 拆分内容

| 提取到 `identity_initializer.gd` (100 行) | 保留在 `identity_selection_system.gd` (556 行) |
|---|---|
| `create_initial_cards` | `IDENTITY_TEMPLATES` 编译时常量（6 身份模板） |
| `create_initial_characters` | `get_available_identities` / `get_identity_preview` 查询 API |
| | `is_identity_selected` / `get_current_identity` / `get_identity_talent_value` |
| | `apply_identity` 原子操作（8 步编排） |
| | `_get_character_names` / `_get_unlocked_talents` 辅助方法 |
| | `_get_card_system` / `_get_resource_system` / `_get_deck_editing_system` |
| | `_get_progression_system` / `_get_gsm` / `_emit_safe` / `_rollback_identity` |
| | `_get_initializer()` 惰性初始化 + 薄委托 |

## 架构特点

- **持有 `_parent` 引用**：子模块通过 `_parent.call("_get_gsm")` / `_parent.call("_get_card_system")` / `_parent.call("_get_deck_editing_system")` 访问父节点的系统引用获取方法。
- **惰性初始化**：`_get_initializer()` 在首次调用时 `load("res://src/feature/identity/identity_initializer.gd").new(self)`。
- **保留原因**：`apply_identity` 是 8 步原子编排，与 GSM/CardSystem/ResourceSystem/DeckEditingSystem 紧耦合，保留在主文件。测试不直接调用 `_create_initial_cards` / `_create_initial_characters`（通过 `apply_identity` 间接验证）。
- **无新增 Autoload**：RefCounted 子模块。

## 验证

- identity_selection_system 单元测试：28/28 passed
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `identity_initializer.gd` 子模块创建（100 行）
- [x] `identity_selection_system.gd` 主文件修改（556 行）
- [x] 主文件保留模板表/查询 API/apply_identity + 薄委托
- [x] identity_selection_system 单元测试全部通过（28/28）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
