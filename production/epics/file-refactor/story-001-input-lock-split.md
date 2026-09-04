# Story 1：input_manager.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 11
- **状态**: Done
- **预估**: 1.0d

## 目标

将 `input_manager.gd`（394 行）中的锁栈管理逻辑（push_lock / pop_lock / clear_locks / get_lock_stack / has_lock / _on_tree_changed / _sync_to_gsm）提取到 `input_lock_stack.gd` RefCounted 子模块，主文件降至 346 行。

## 拆分内容

| 提取到 `input_lock_stack.gd` (130 行) | 保留在 `input_manager.gd` (346 行) |
|---|---|
| `push_lock` / `pop_lock` / `clear_locks` | `LockType` / `ActionType` / `DeviceType` 枚举 |
| `get_lock_stack` / `has_lock` | `LockEntry` 内部类 |
| `on_tree_changed`（_on_tree_changed 的委托） | `_ACTION_CLASSIFICATION` 常量 |
| `_sync_to_gsm`（委托回父节点） | `is_input_allowed` / `is_action_blocked` 输入判定 |
| | `get_current_lock` / `_check_device_allowed` / `_get_highest_lock` |
| | `_classify_action` / `_classify_device` |
| | `_process` / `_input` 输入分发 + `_get_lock_stack_module()` 惰性初始化 + 薄委托 |

## 架构特点

- **持有 `_parent` 引用**：子模块通过 `_init(parent)` 构造注入，通过 `_parent.get()` / `_parent.set()` 访问父节点状态。
- **`_sync_to_gsm` 委托回父节点**：子模块的 `_sync_to_gsm` 调用 `_parent.call("_sync_to_gsm")`，因为该方法依赖 `GameStateManager` Autoload 全局名——在 RefCounted 子模块中无法直接引用 Autoload 全局名。
- **`_exit_tree` 保留原始 `_sync_to_gsm` 调用**：退出时直接调用主文件的 `_sync_to_gsm`（仍在主文件中），避免子模块在退出时可能未初始化的竞态。
- **惰性初始化**：`_get_lock_stack_module()` 在首次调用时 `load().new(self)`。
- **薄委托**：主文件保留 6 个方法签名作为薄委托。
- **无新增 Autoload**：RefCounted 子模块。

## 风险与处理

- **风险等级**：低——锁栈管理逻辑相对独立。
- **处理方式**：纯结构变更，不修改逻辑。`_sync_to_gsm` 在子模块中委托回父节点（因 Autoload 全局名引用限制），`_exit_tree` 保留直接调用主文件的 `_sync_to_gsm`。

## 验证

- input 单元测试：110/110 passed（6 scripts）
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `input_lock_stack.gd` 子模块创建（130 行）
- [x] `input_manager.gd` 主文件修改（346 行）
- [x] input 单元测试全部通过（110/110）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
