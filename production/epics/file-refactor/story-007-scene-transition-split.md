# Story 7：scene_manager.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 10
- **状态**: Done
- **预估**: 1.0d

## 目标

将 `scene_manager.gd`（425 行）中的异步转换管线逻辑（_execute_transition + _cleanup_on_error + _inject_loading_context + _execute_post_load）提取到 `scene_transition.gd` RefCounted 子模块，主文件降至 345 行。

## 拆分内容

| 提取到 `scene_transition.gd` (141 行) | 保留在 `scene_manager.gd` (345 行) |
|---|---|
| `_execute_transition`（Phase 3-4-5 异步管线） | `SceneID` / `TransitionType` 枚举 |
| `_cleanup_on_error`（错误恢复） | `SCENE_PATHS` / `TRANSITION_AUDIO_PARAMS` 常量 |
| `_inject_loading_context`（加载画面上下文注入） | 内部状态字段 + 依赖注入 |
| `_execute_post_load`（Phase 4-5 同步执行体） | `request_scene_change`（Phase 1-2 编排）|
| | 信号发射包装（`_emit_pre_transition` / `_emit_post_transition`）|
| | `create_fade_overlay` / `fade_out_overlay`（static 工具方法）|
| | `_get_transition()` 惰性初始化 + 薄委托 |

## 架构特点

- **持有 `_parent` 引用**：子模块通过 `_init(parent)` 构造注入，通过 `_parent.get()` / `_parent.set()` / `_parent.call()` 访问父节点状态和方法。
- **通过 `_parent.get()` 访问枚举**：子模块通过 `_parent.get("SceneID")` / `_parent.get("TransitionType")` / `_parent.get("SCENE_PATHS")` 访问父节点的枚举和常量。
- **通过 `_parent.get_tree()` 访问 SceneTree**：异步 `await get_tree().tree_changed` 改为 `await _parent.get_tree().tree_changed`。
- **惰性初始化**：`_get_transition()` 在首次调用时 `load().new(self)`。
- **薄委托**：主文件保留 4 个方法签名作为薄委托（`_execute_transition` / `_cleanup_on_error` / `_inject_loading_context` / `_execute_post_load`）——测试通过这些方法名直接调用。
- **无新增 Autoload**：RefCounted 子模块。

## 风险与处理

- **风险等级**：中——异步转换管线涉及 `await` 和 SceneTree 交互，测试直接调用 `_execute_post_load` 和 `_cleanup_on_error`。
- **处理方式**：薄委托保留在主文件，测试调用路径不变。子模块通过 `_parent` 间接访问 SceneTree 和所有状态字段。

## 验证

- scene_manager 单元测试：72/72 passed（4 scripts）
- scene_manager 集成测试：47/47 passed（4 scripts）
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `scene_transition.gd` 子模块创建（141 行）
- [x] `scene_manager.gd` 主文件修改（345 行）
- [x] scene_manager 单元测试全部通过（72/72）
- [x] scene_manager 集成测试全部通过（47/47）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
