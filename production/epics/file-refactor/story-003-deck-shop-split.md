# Story 3：deck_editing_system.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 10
- **状态**: Done
- **预估**: 0.5d

## 目标

将 `deck_editing_system.gd`（433 行）中的坊市操作逻辑提取到 `deck_shop.gd`，摘要/状态查询逻辑提取到 `deck_summary.gd`，主文件降至 387 行。

## 拆分内容

| 提取到 `deck_shop.gd` (96 行) | 提取到 `deck_summary.gd` (60 行) | 保留在 `deck_editing_system.gd` (387 行) |
|---|---|---|
| `get_delete_cost` / `execute_delete` | `get_deck_summary` | 常量 + 状态字段 |
| `get_sell_price` / `execute_sell` | `get_loot_options` | 卡组校验 API（`can_add_to_deck` / `can_remove_from_deck` / `get_deck_limit`）|
| | `get_deck_status` | 卡组操作 API（`add_cards_to_deck` / `remove_cards_from_deck`）|
| | | 变更日志 + 查询接口 + 开局初始化 |
| | | 战利品编排（`generate_loot_options` / `apply_loot_choice`）|
| | | `_get_gsm` / `_get_realm_system` / `_get_resource_system` + 惰性初始化 + 薄委托 |

## 架构特点

- **持有 `_parent` 引用**：两个子模块通过 `_init(parent)` 构造注入，通过 `_parent.call()` 访问父节点方法。
- **惰性初始化**：`_get_shop()` 和 `_get_summary()` 在首次调用时 `load().new(self)`。
- **薄委托**：主文件保留 7 个方法签名作为薄委托。
- **`MINIMUM_DECK_SIZE` 镜像**：`deck_summary.gd` 自带常量避免运行时 `_parent.get()` 开销。
- **无新增 Autoload**：RefCounted 子模块。

## 验证

- deck_editing_system 单元测试：75/75 passed（4 scripts）
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `deck_shop.gd` 子模块创建（96 行）
- [x] `deck_summary.gd` 子模块创建（60 行）
- [x] `deck_editing_system.gd` 主文件修改（387 行）
- [x] deck_editing_system 单元测试全部通过（75/75）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
