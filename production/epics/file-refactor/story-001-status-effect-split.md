# Story 1：status_effect_system.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 10
- **状态**: Done
- **预估**: 1.0d

## 目标

将 `status_effect_system.gd`（572 行）中的快照导出/导入/序列化逻辑提取到 `status_effect_snapshot.gd`，暂挂/恢复逻辑提取到 `status_effect_suspend.gd`，主文件降至 484 行。

## 拆分内容

| 提取到 `status_effect_snapshot.gd` (114 行) | 提取到 `status_effect_suspend.gd` (91 行) | 保留在 `status_effect_system.gd` (484 行) |
|---|---|---|
| `export_snapshot` | `suspend_status` | 信号声明 + 常量 |
| `write_snapshot_to_gsm` | `restore_status` | `_instances` / `_by_target` / `_suspended` 状态字段 |
| `import_snapshot` | `restore_all_suspended` | `apply_status` / `remove_status` / `tick_all` 核心生命周期 |
| `_serialize_status` | `get_suspended_statuses` | `_register_instance` / `_remove_instance` / `_evict_lowest` |
| `_get_gsm`（子模块私有） | | `_check_immunity` / `_find_existing` / `_extract_target_id` |
| | | `_load_templates_from` + `_get_snapshot()` / `_get_suspend()` 惰性初始化 + 薄委托 |

## 架构特点

- **持有 `_parent` 引用**：两个子模块通过 `_init(parent)` 构造注入，通过 `_parent.get()` / `_parent.call()` / `_parent.set()` 访问父节点状态。
- **惰性初始化**：`_get_snapshot()` 和 `_get_suspend()` 在首次调用时 `load("res://src/core/status_effect/status_effect_snapshot.gd").new(self)` / `load("res://src/core/status_effect/status_effect_suspend.gd").new(self)`。
- **薄委托**：主文件保留 7 个方法签名作为薄委托（`export_snapshot` / `write_snapshot_to_gsm` / `import_snapshot` / `suspend_status` / `restore_status` / `restore_all_suspended` / `get_suspended_statuses`）。
- **无新增 Autoload**：RefCounted 子模块。

## 风险与处理

- **风险等级**：低——快照导出/导入和暂挂/恢复逻辑相对独立，测试调用公共方法。
- **处理方式**：纯结构变更，不修改逻辑。`_serialize_status` 和 `_get_gsm` 移入子模块，主文件删除原有实现。

## 验证

- status_effect 单元测试：25/25 passed
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `status_effect_snapshot.gd` 子模块创建（114 行）
- [x] `status_effect_suspend.gd` 子模块创建（91 行）
- [x] `status_effect_system.gd` 主文件修改（484 行）
- [x] status_effect 单元测试全部通过（25/25）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
