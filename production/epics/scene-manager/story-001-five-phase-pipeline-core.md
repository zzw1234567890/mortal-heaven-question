# Story 001：5 阶段转换管线核心

> **Epic**: scene-manager
> **Story ID**: EPIC-001-S01
> **Story 类型**: Logic（逻辑）
> **优先级**: P0 —— 阻塞所有后续 Story
> **预估工作量**: 4-6 小时
> **管辖 ADR**: ADR-0005
> **控制清单版本**: 2026-07-26
> **状态**: Complete
> **Last Updated**: 2026-07-30

## 概述

实现 SceneManager Autoload（#3 位置，GSM → InputManager → **SceneManager** → SaveLoad → EventSystem），包括 `SceneID` 枚举、`SCENE_PATHS` 编译时常量字典、`request_scene_change()` 公共入口以及 5 阶段异步转换管线。SceneManager 是场景树变更的**唯一调用者**——所有其他系统通过它委托场景切换，不得直接操作 `get_tree().change_scene_to_file()`。

## GDD 需求

| TR-ID | 需求 | ADR 覆盖 |
|-------|------|----------|
| TR-scene-001 | 场景转换编排者；场景树变更的唯一调用者 | ADR-0005 |
| TR-scene-002 | 5 阶段转换管线——转场前自动存档+锁定输入+加载画面+转场后信号+解锁 | ADR-0005 |

## ADR 指导

### 必须遵守（来自 ADR-0005）

- **所有场景转换必须通过 `SceneManager.request_scene_change()`** —— 禁止任何系统直接调用 `get_tree().change_scene_to_file()`
- **5 阶段管线顺序**：VALIDATE → PRE-TRANSITION → LOAD → POST-LOAD → FINALIZE —— 不可跳过或重排
- **Phase 1 并发守卫**：`_transitioning == true` 时拒绝新请求（返回 `false`）
- **Phase 1 场景 ID 校验**：`to` 必须在 `SCENE_PATHS` 中存在，不存在则返回 `false`
- **Phase 4 GSM 写入**：仅 SceneManager 写入 `GSM.session.current_scene` 和 `GSM.session.scene_id`——其他系统不得写入
- **Phase 5 收尾**：`_transitioning = false`、`_transition_type = NONE`

### 必须遵守（来自 Control Manifest —— Foundation 层）

- **所有场景转换必须通过 `SceneManager.request_scene_change()`** —— 来源: ADR-0005
- **5 阶段转换管线**：验证 → 转场前（锁输入 + 自动存档）→ 加载（加载画面 → 目标场景）→ 加载后（GSM 更新 + 解锁）→ 收尾 —— 来源: ADR-0005
- **绝不直接调用 `get_tree().change_scene_to_file()`** —— 使用 `SceneManager.request_scene_change()` —— 来源: ADR-0005
- **绝不在 SceneManager 之外写 `GSM.session.current_scene`** —— 来源: ADR-0005
- **信号命名：snake_case 过去式**（pre/post 配对除外） —— 来源: ADR-0007
- **Cat 2 信号必须通过 `_emit_signal_safe()` 包装器路由** —— 信号链深度追踪 —— 来源: ADR-0007
- **绝不使用基于字符串的 `connect()`** —— 类型化信号连接 —— 来源: Control Manifest §禁止 API

### 引擎特定约束（Godot 4.6）

- **D3D12 为 Windows 默认渲染器** —— `change_scene_to_file()` 在释放旧场景时可能产生单帧白闪/黑闪 —— 来源: ADR-0005 §风险 #5
- **`await` 用于 `SceneTree.tree_changed` 信号** —— 4.0+ 稳定 API（`yield()` 已废弃） —— 来源: Control Manifest §禁止 API
- **`change_scene_to_file()` 为异步方法** —— 调用立即返回，新场景在下一帧就绪 —— 来源: ADR-0005 §约束

## 验收标准

### AC-1：SceneManager Autoload 正确初始化

- [x] SceneManager 作为 Autoload #3 注册（在 InputManager 之后、SaveLoad 之前）
- [x] `_ready()` 初始化 `_transitioning = false`、`_transition_type = TransitionType.NONE`
- [x] `SCENE_PATHS` 常数字典包含全部 12 个 SceneID 条目（MAIN_MENU 到 CULTIVATION + LOADING）

### AC-2：SceneID 枚举 + 路径注册表

- [x] `SceneID` 枚举定义全部 12 个值（含 LOADING = 99）
- [x] `SCENE_PATHS: Dictionary[SceneID, String]` 为编译时常量
- [x] 所有路径以 `res://` 开头

### AC-3：request_scene_change() 入口

- [x] 签名：`request_scene_change(from: SceneID, to: SceneID, type: TransitionType) -> bool`
- [x] `_transitioning == true` 时立即返回 `false`（拒绝并发请求）
- [x] `to` 不在 `SCENE_PATHS` 中时返回 `false`
- [x] `from != _current_scene_id` 时记录警告但继续执行（防御性检查）
- [x] 正常情况返回 `true`——转换被接受并异步执行

### AC-4：Phase 1 —— VALIDATE

- [x] 第 1 步：检查 `_transitioning` 标志
- [x] 第 2 步：检查 `to` 在 `SCENE_PATHS.has(to)` 中存在
- [x] 第 3 步：防御性检查 `from == _current_scene_id`（不匹配时记录 `push_warning`）
- [x] 任何一步失败 → 返回 `false` 且不修改任何状态

### AC-5：Phase 2 —— PRE-TRANSITION

- [x] 设置 `_transitioning = true`
- [x] 存储 `_transition_type = type`
- [x] 发射 `pre_transition(from, to, type)` 信号（通过 `_emit_signal_safe()`）

### AC-6：Phase 5 —— FINALIZE

- [x] 设置 `_transitioning = false`
- [x] 设置 `_transition_type = TransitionType.NONE`

### AC-7：公共查询方法

- [x] `get_current_scene_id() -> SceneID`：返回 `_current_scene_id`
- [x] `is_transitioning() -> bool`：返回 `_transitioning`

### AC-8：信号

- [x] `pre_transition(from: SceneID, to: SceneID, type: TransitionType)` —— Phase 2 发射
- [x] `post_transition(from: SceneID, to: SceneID)` —— Phase 4 发射
- [x] 信号声明在 SceneManager 中（非 SignalBus Autoload） —— 来源: ADR-0007
- [x] 信号通过 `_emit_signal_safe()` 包装器路由 —— 来源: ADR-0007

### AC-9：GSM 集成（Phase 4 写入）

- [x] Phase 4 更新 `GSM.session.current_scene` 为目标场景文件路径（String）
- [x] Phase 4 更新 `GSM.session.scene_id` 为目标 SceneID（int）
- [x] 通过 GSM `batch_updated` 传播 `scene_changed`（格式：`{"session.current_scene": {old, new}}`）
- [x] SceneManager 是这两个字段的**唯一写入者**——其他系统写入时 GSM 记录警告

### AC-10：防御性 tree_changed 校验

- [x] Phase 4 中 `get_tree().current_scene.scene_file_path` 与 `SCENE_PATHS[to]` 不匹配时：
  - 不执行 GSM 写入
  - 不发射 `post_transition`
  - 记录 `push_error` 日志
  - 恢复 `_transitioning = false` + 解锁
- [x] 此防御逻辑在发布构建中也执行（使用 `if` 而非 `assert`）

## 故事依赖

| 依赖 | 状态 | 说明 |
|------|------|------|
| GSM（游戏状态管理器） | 不阻塞 Story 001 | 测试中可 mock——`session.current_scene` / `session.scene_id` 写入 + `batch_updated` 信号发射 |
| InputManager | 不阻塞 Story 001 | 测试中可 mock——Phase 2/4 的 `push_lock`/`pop_lock` 调用 |
| SaveLoad | 不阻塞 Story 001 | 测试中可 mock——Phase 2 的 `auto_save()` 调用 |

> **注**：Story 001 的核心管线逻辑（Phase 1、3、4、5）可在不依赖兄弟 Foundation Autoload 真实实现的情况下完成和测试——对 GSM/InputManager/SaveLoad 的调用使用 mock 对象注入。实际集成在 Story 003 中验证。

## 禁止方法

- **绝不**直接调用 `get_tree().change_scene_to_file()` —— 使用 `SceneManager.request_scene_change()` —— 来源: ADR-0005
- **绝不**在 SceneManager 之外写 `GSM.session.current_scene` 或 `GSM.session.scene_id` —— 来源: ADR-0005
- **绝不**使用基于字符串的 `connect()` —— 类型化信号连接 —— 来源: Control Manifest §禁止 API
- **绝不**声明 SignalBus Autoload —— 信号属于其语义所有者（SceneManager） —— 来源: ADR-0007

## 测试证据

| 证据类型 | 位置 | 级别 |
|----------|------|------|
| 自动化单元测试 | `tests/unit/scene_manager/test_scene_manager_pipeline.gd` | **阻塞** |
| 自动化单元测试 | `tests/unit/scene_manager/test_scene_manager_validation.gd` | **阻塞** |

### 最小测试集

```
test_request_scene_change_returns_false_when_transitioning
test_request_scene_change_returns_false_for_invalid_scene_id
test_request_scene_change_returns_true_in_normal_state
test_request_scene_change_sets_transitioning_true
test_request_scene_change_warns_on_from_mismatch
test_phase_5_finalize_sets_transitioning_false
test_phase_5_finalize_sets_transition_type_none
test_get_current_scene_id_returns_internal_state
test_is_transitioning_returns_internal_flag
test_phase_4_writes_gsm_current_scene
test_phase_4_writes_gsm_scene_id
test_phase_4_emits_post_transition_signal
test_phase_2_emits_pre_transition_signal
test_phase_4_handles_tree_changed_mismatch
test_scene_paths_has_12_entries
```

## 实现注意事项

- SceneManager 为 Godot Autoload（`extends Node`）
- `SCENE_PATHS` 为 `const Dictionary`——编译时常量，无运行时文件 I/O
- 使用 `await get_tree().tree_changed` 等待场景就绪（4.6 标准方式，已废弃 `yield()`）
- Phase 3（加载画面切入 + 目标场景加载）的具体实现在 Story 004 中完成——Story 001 仅在 Phase 3 中调用 `change_scene_to_file(SCENE_PATHS[to])` 并 await `tree_changed`
- 对 GSM / InputManager / SaveLoad 的调用通过依赖注入接口进行——便于单元测试 mock

## Completion Notes

**Completed**：2026-07-30
**Criteria**：10/10 通过
**Deviations**：
- ADVISORY：`src/foundation/game_state_manager.gd` 被额外触及（+~50 行）——`_emit_signal_safe()` 静态方法、`set_session_scene()` 原子方法、`scene_id` 初始化、`_signal_chain_depth` 每帧重置——均为 ADR-0007 和 Control Manifest Foundation 层合规要求
- ADVISORY：故事 AC-2 原文写"13 个 SceneID 值"——实际枚举 12 个值（`MAIN_MENU=0` 到 `CULTIVATION=10` + `LOADING=99`）。故事文件已更正为 12。
**Code Review**：已完成（GDScript 专家 + QA 测试员双审查，5 项 BLOCKER 全部修复）
