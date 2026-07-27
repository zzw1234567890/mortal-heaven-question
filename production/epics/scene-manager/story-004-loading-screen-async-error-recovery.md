# Story 004：加载画面 + 异步加载 + 错误恢复

> **Epic**: scene-manager
> **Story ID**: EPIC-001-S04
> **Story 类型**: Integration（集成）
> **优先级**: P2 —— 依赖 Story 001；与 Story 002/003 可并行
> **预估工作量**: 4-5 小时
> **管辖 ADR**: ADR-0005
> **控制清单版本**: 2026-07-26
> **状态**: Ready

## 概述

实现 Phase 3（LOAD → CHANGE）的完整加载画面系统。SceneManager 使用**专用加载场景**（`loading_screen.tscn`）——独立场景而非 CanvasLayer overlay，防止旧场景状态泄漏并利用 Godot 的 `change_scene_to_file()` 异步特性。加载画面场景体积小（<2MB），切换几乎是即时的，且根节点为全屏 `ColorRect`（纯黑色）以遮挡 D3D12 渲染器释放旧场景渲染目标时的单帧白闪/黑闪。目标场景的首个 Control 节点在 `_ready()` 中以全屏不透明 ColorRect 开始，在 `_process()` 首帧淡出——双重保护渲染器级闪烁。

## GDD 需求

| TR-ID | 需求 | ADR 覆盖 |
|-------|------|----------|
| TR-scene-002 | 5 阶段转换管线——转场前自动存档+锁定输入+加载画面+转场后信号+解锁 | ADR-0005 |

## ADR 指导

### 必须遵守（来自 ADR-0005）

- **加载画面是独立场景**（`loading_screen.tscn`）——非 CanvasLayer overlay —— 来源: ADR-0005 §加载画面策略
- **Phase 3 两步切换**：先切加载画面场景 → await `tree_changed` → 传递上下文 → 切目标场景
- **上下文传递必须同步**——`set_context(from, to, type)` 在首次 `_ready()` 渲染前调用
- **D3D12 白闪/黑闪缓解**：`loading_screen.tscn` 根节点为全屏 `ColorRect`（纯黑色）
- **目标场景双重保护**：目标场景的第一个 Control 节点在 `_ready()` 中以全屏不透明 ColorRect 开始 → `_process()` 首帧淡出
- **Phase 4 防御性校验**：`tree_changed` 到达后确认 `current_scene.scene_file_path == SCENE_PATHS[to]`——不匹配时不执行 post-load 步骤

### 必须遵守（来自 Control Manifest —— Foundation 层）

- **绝不直接调用 `get_tree().change_scene_to_file()`** —— 使用 `SceneManager.request_scene_change()` —— 来源: ADR-0005
- **`change_scene_to_file()` 为异步方法** —— 不在同一帧等待其完成
- **D3D12 为 Windows 上默认渲染器** —— 来源: Control Manifest §引擎特定约束

### 引擎特定约束（Godot 4.6）

- Godot 4.6 在 Windows 上默认使用 D3D12 渲染器——`change_scene_to_file()` 释放旧场景并实例化新场景时，D3D12 需要刷新并重新分配渲染目标——可能产生单帧白闪或黑闪 —— 来源: ADR-0005 §风险 #5
- 4.6 双焦点系统（鼠标/键盘焦点分离）——TRANSITION 锁依赖 InputManager 同时拦截两种焦点。若 InputManager 仅拦截 Input Map 动作而允许鼠标 hover 焦点变更，加载画面可能收到 `mouse_entered`/`mouse_exited` 信号——视觉焦点闪烁。缓解：`loading_screen.tscn` 不在 `_ready()` 中调用 `grab_focus()` —— 来源: ADR-0005 §输入管理器集成
- 禁止在加载画面中调用 `grab_focus()`——4.6 双焦点下可能出现鼠标焦点与键盘焦点不一致

## 验收标准

### AC-1：loading_screen.tscn 场景结构

- [ ] 根节点为 `Control`（全屏锚定：`anchor_left = 0, anchor_right = 1, anchor_top = 0, anchor_bottom = 1`）
- [ ] 根 Control 的直接子节点为全屏 `ColorRect`（纯黑色 `Color.BLACK`）——遮挡 D3D12 渲染器级闪烁
- [ ] 场景体积 <2MB（仅 UI Control + 背景图片 + 水墨过渡动画素材）
- [ ] 场景路径：`res://src/ui/loading/loading_screen.tscn`（匹配 ADR-0005 §SCENE_PATHS 中 `SceneID.LOADING` 的值）

### AC-2：上下文传递——同步方法

- [ ] `loading_screen.gd` 脚本定义 `set_context(from: SceneID, to: SceneID, type: TransitionType)` 方法
- [ ] 方法为**同步**方法——不 `await`、不依赖 `_ready()`
- [ ] 上下文传递时机：Phase 3 中 `await tree_changed`（加载画面场景就绪）之后、`change_scene_to_file(target)` 之前
- [ ] SceneManager 通过 `get_tree().current_scene.set_context(from, to, type)` 调用

### AC-3：Phase 3 完整流程

- [ ] 第 1 步：`change_scene_to_file(SCENE_PATHS[SceneID.LOADING])` → 异步切换到加载画面场景
- [ ] 第 2 步：设置 `_phase3_in_progress = true`
- [ ] 第 3 步：`await get_tree().tree_changed` → 加载画面场景就绪
- [ ] 第 4 步：`get_tree().current_scene.set_context(_current_scene_id, to, _transition_type)` → 同步传递上下文
- [ ] 第 5 步：`change_scene_to_file(SCENE_PATHS[to])` → 异步切换到目标场景
- [ ] 第 6 步：`await get_tree().tree_changed` → 目标场景就绪
- [ ] 第 7 步：进入 Phase 4（`_phase3_in_progress = false` 在 Phase 4 正常到达时清除）

### AC-4：加载画面显示内容（最小集）

- [ ] 水墨风格的背景图案（静态图片或简单动画）
- [ ] "加载中……"文字提示（可选：旋转的加载指示器）
- [ ] 无交互元素——加载画面不是菜单
- [ ] 不在 `_ready()` 中调用 `grab_focus()`——避免 4.6 双焦点闪烁

### AC-5：目标场景淡入保护（D3D12 双重保护）

- [ ] 目标场景的第一个 Control 节点（或 `CanvasLayer`）在 `_ready()` 中设置全屏不透明 `ColorRect`（`modulate.a = 1.0`）
- [ ] `_process()` 首帧开始淡出——`modulate.a` 线性递减至 `0.0`（建议时长：0.2-0.3s）
- [ ] 淡出完成后禁用 `_process()` 中的淡出逻辑（`set_process(false)` 或标志位）
- [ ] 此保护由目标场景各自实现——SceneManager 提供约定和辅助方法（`SceneManager.create_fade_overlay() -> ColorRect` 供目标场景在 `_ready()` 中调用）

### AC-6：Phase 4 tree_changed 校验

- [ ] Phase 4 验证：`get_tree().current_scene.scene_file_path == SCENE_PATHS[to]`
- [ ] 不匹配时：
  - 记录 `push_error("场景路径不匹配：预期 {expected}，实际 {actual}")`
  - 设置 `_transitioning = false` + `pop_lock(&"scene_manager")`
  - 不更新 GSM、不发射 `post_transition`、不执行 FINALIZE
- [ ] 使用 `if` 而非 `assert`——确保发布构建中也执行此防御逻辑

### AC-7：加载画面场景缺失时的优雅降级

- [ ] `change_scene_to_file(SCENE_PATHS[SceneID.LOADING])` 返回错误时（场景文件不存在或损坏）：
  - 记录 `push_error("无法加载 loading_screen.tscn：{error}")`
  - 跳过加载画面——直接执行 `change_scene_to_file(SCENE_PATHS[to])`
  - 不设置 `_phase3_in_progress`（加载画面从未开始）
  - 正常进入 Phase 4——`tree_changed` 直接对应目标场景就绪
  - 此降级为应急容错——加载画面缺失不应阻止游戏运行

### AC-8：辅助方法 —— 目标场景淡入保护

- [ ] `SceneManager.create_fade_overlay() -> ColorRect` —— 创建全屏不透明 ColorRect 供目标场景使用
- [ ] `SceneManager.fade_out_overlay(overlay: ColorRect, duration: float)` ——异步淡出（Tween `modulate.a: 1.0 → 0.0`）
- [ ] 目标场景调用模式：`_ready()` 中 `var overlay = SceneManager.create_fade_overlay()` → `SceneManager.fade_out_overlay(overlay, 0.25)`

### AC-9：性能约束

- [ ] 加载画面场景加载时间 <100ms（场景体积小，主要是 `change_scene_to_file()` 的引擎底层开销）
- [ ] 加载画面场景不触发任何 `_process()` 中的重计算——纯静态 UI
- [ ] 对 2D 卡牌游戏可接受——实际体验中加载画面背景在此期间显示

## 故事依赖

| 依赖 | 状态 | 说明 |
|------|------|------|
| Story 001（5 阶段管线核心） | 阻塞 | Phase 3 的入口框架必须就位 |
| Story 003（自动存档 + 输入锁） | 不阻塞 | 加载画面系统的实现和测试不依赖 InputManager/SaveLoad 的真实集成——可独立开发 |
| 美术资源（水墨背景） | 不阻塞 MVP | 可先用纯色黑底占位——加载画面功能不依赖美术资源完成 |

## 禁止方法

- **绝不**将加载画面实现为 CanvasLayer overlay —— 独立场景防止旧场景状态泄漏 —— 来源: ADR-0005 §加载画面策略
- **绝不**在 `set_context()` 中使用 `await`——上下文传递必须同步以确保在加载画面渲染前就绪 —— 来源: ADR-0005 §加载画面策略
- **绝不**在 loading_screen.tscn 的 `_ready()` 中调用 `grab_focus()`——4.6 双焦点下导致视觉焦点闪烁 —— 来源: ADR-0005 §输入管理器集成
- **绝不**在 Phase 4 使用 `assert` 校验场景路径——使用 `if` 确保发布构建也执行 —— 来源: ADR-0005 §Phase 4

## 测试证据

| 证据类型 | 位置 | 级别 |
|----------|------|------|
| 集成测试 | `tests/integration/scene_manager/test_loading_screen.gd` | **阻塞** |
| 手动测试截图 | `production/qa/evidence/loading-screen-screenshot.png` | **建议** |

### 最小测试集

```
# loading_screen.tscn 功能测试
test_loading_screen_scene_exists
test_loading_screen_has_fullscreen_colorrect_root
test_set_context_stores_from_scene_id
test_set_context_stores_to_scene_id
test_set_context_stores_transition_type
test_set_context_is_synchronous

# Phase 3 管线集成测试
test_phase_3_switches_to_loading_screen_first
test_phase_3_switches_to_target_after_loading
test_phase_3_sets_phase3_in_progress_flag
test_phase_4_clears_phase3_in_progress_flag

# 错误恢复测试
test_graceful_degradation_when_loading_scene_missing
test_phase_4_path_mismatch_aborts_post_load
test_phase_4_path_mismatch_logs_error
test_phase_4_path_mismatch_unlocks_input

# 淡出保护测试
test_create_fade_overlay_returns_fullscreen_colorrect
test_fade_out_overlay_tweens_alpha_to_zero
```

## 实现注意事项

- `loading_screen.tscn` 为独立场景——`SCENE_PATHS[SceneID.LOADING]` 指向它
- `loading_screen.gd` 附加脚本：`class_name LoadingScreen extends Control`
- `set_context()` 为同步方法——内部仅存储上下文数据，不启动动画（动画在 `_ready()` 后自动开始）
- `SceneManager.create_fade_overlay()` 返回预配置的 `ColorRect`——目标场景将其添加为 `CanvasLayer` 的直接子节点
- `fade_out_overlay()` 使用 `create_tween()`（Godot 4.0+ Tween API）而非已废弃的 `Tween` 节点
- 水墨过渡动画（Story 004 可选扩展）：当前 MVP 阶段加载画面为静态黑底 + 文字——后续可扩展为水墨扩散/收拢动画，无需修改 SceneManager 核心管线
