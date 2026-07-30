# Story 002：TransitionType 枚举 + 音频过渡矩阵

> **Epic**: scene-manager
> **Story ID**: EPIC-001-S02
> **Story 类型**: Logic（逻辑）
> **优先级**: P1 —— 依赖 Story 001
> **预估工作量**: 2-3 小时
> **管辖 ADR**: ADR-0005
> **控制清单版本**: 2026-07-26
> **状态**: Complete
> **Last Updated**: 2026-07-30

## 概述

实现 `TransitionType` 枚举及其与音频系统的集成契约。`TransitionType` 编码场景间转换的语义类型（主菜单→游戏、游戏→主菜单、探索↔战斗、渡劫），驱动音频系统的 BGM 过渡矩阵。音频系统通过监听 SceneManager 的 `pre_transition` / `post_transition` 信号，根据 `type` 参数查表执行对应的淡入/淡出逻辑。本 Story 定义 `TransitionType` → BGM 过渡参数的映射表，并确保编译时完整覆盖——Godot 的 `match` 语句对所有枚举值的缺失分支发出编译警告。

## GDD 需求

| TR-ID | 需求 | ADR 覆盖 |
|-------|------|----------|
| TR-scene-001 | 场景转换编排者；场景树变更的唯一调用者 | ADR-0005 |

## ADR 指导

### 必须遵守（来自 ADR-0005）

- **`TransitionType` 枚举驱动音频过渡矩阵** —— 来源: ADR-0005 §TransitionType 枚举
- **枚举值定义**：`NONE = 0`、`MENU_TO_GAME = 1`、`GAME_TO_MENU = 2`、`EXPLORE_TO_COMBAT = 3`、`COMBAT_TO_EXPLORE = 4`、`TRIBULATION = 5`
- **`pre_transition` 信号携带 `type: TransitionType`** —— 音频系统监听此信号并查表
- **TransitionType 仅包含场景级转换** —— UI overlay（弹窗、菜单面板）不属于 SceneManager 职责
- **音频系统的 `match` 语句必须覆盖所有枚举值** —— 否则 Godot 编译器报 missing-branch warning

### 必须遵守（来自 Control Manifest —— Foundation 层）

- **`TransitionType` 枚举驱动音频过渡矩阵** —— 来源: ADR-0005
- **信号命名：snake_case 过去式**（pre/post 配对除外） —— 来源: ADR-0007
- **绝不发射携带指令（"该做什么"）的信号** —— 信号携带事实（"发生了什么"） —— 来源: ADR-0007

### 来自 audio-system.md（场景切换音频过渡矩阵）

| 转换类型 | BGM 过渡行为 | 过渡时长 |
|----------|-------------|----------|
| MENU_TO_GAME | 主菜单 BGM 淡出 → 游戏 BGM 淡入 | 1.5s |
| GAME_TO_MENU | 游戏 BGM 淡出 → 主菜单 BGM 淡入 | 1.5s |
| EXPLORE_TO_COMBAT | 探索 BGM 快速淡出 → 战斗 BGM 切入 | 0.5s |
| COMBAT_TO_EXPLORE | 战斗 BGM 淡出 → 探索 BGM 淡入 | 1.0s |
| TRIBULATION | 当前 BGM 淡出 → 渡劫 BGM 切入 | 0.3s |

## 验收标准

### AC-1：TransitionType 枚举定义

- [x] 枚举定义在 SceneManager 脚本中：`enum TransitionType { NONE = 0, MENU_TO_GAME = 1, GAME_TO_MENU = 2, EXPLORE_TO_COMBAT = 3, COMBAT_TO_EXPLORE = 4, TRIBULATION = 5 }`
- [x] `NONE` 为零值默认——未初始化状态的哨兵值
- [x] 枚举值可用于信号载荷（`int` 底层类型）

### AC-2：TransitionType → BGM 过渡参数映射表

- [x] `TRANSITION_AUDIO_PARAMS: Dictionary[TransitionType, Dictionary]` 为编译时常量
- [x] 每个 TransitionType 值（除 NONE）包含以下键：
  - `duration_seconds: float` —— BGM 交叉淡入淡出时长
  - `from_behavior: StringName` —— 前场景 BGM 行为（`&"fade_out"` / `&"cut"` / `&"none"`）
  - `to_behavior: StringName` —— 新场景 BGM 行为（`&"fade_in"` / `&"cut"` / `&"none"`）
- [x] 映射表值与 audio-system.md 的过渡参数严格一致：
  - MENU_TO_GAME → 1.5s fade_out + fade_in
  - GAME_TO_MENU → 1.5s fade_out + fade_in
  - EXPLORE_TO_COMBAT → 0.5s cut + fade_in
  - COMBAT_TO_EXPLORE → 1.0s fade_out + fade_in
  - TRIBULATION → 0.3s cut + cut

### AC-3：编译时覆盖验证

- [x] 音频系统（或任何消费 TransitionType 的系统）的 `match type` 语句覆盖全部 6 个枚举值
- [x] 无 `_` 万用分支掩盖缺失的枚举值处理——每个值都有显式分支
- [x] 新增 TransitionType 值后，编译器对未更新的 `match` 语句报 missing-branch warning

### AC-4：与 Story 001 管线的集成

- [x] `_transition_type` 状态字段类型为 `TransitionType`（非 `int`）
- [x] Phase 2 设置 `_transition_type = type`（在 `pre_transition` 信号发射之前）
- [x] Phase 5 设置 `_transition_type = TransitionType.NONE`
- [x] `request_scene_change()` 的 `type` 参数类型为 `TransitionType`（非 `int`）

### AC-5：信号载荷中包含类型信息

- [x] `pre_transition(from: SceneID, to: SceneID, type: TransitionType)`——type 参数在 Phase 2 发射
- [x] 音频系统可通过 `type` 参数直接查 `TRANSITION_AUDIO_PARAMS` 表——无需额外查询或猜测

### AC-6：职责边界清晰

- [x] TransitionType 枚举不包含 UI 状态标记（如 `MODAL_OPEN`、`MENU_PAUSE`）
- [x] 新增场景转换类型遵循以下流程：向 `TransitionType` 枚举添加值 → 向 `TRANSITION_AUDIO_PARAMS` 表添加条目 → 音频系统添加对应的 BGM 过渡逻辑（编译器强制覆盖）

## 故事依赖

| 依赖 | 状态 | 说明 |
|------|------|------|
| Story 001 | 阻塞 | TransitionType 嵌入在 SceneManager 中——共用同一脚本文件 |

## 禁止方法

- **绝不**在 TransitionType 中混入 UI 状态标记 —— 来源: ADR-0005 §TransitionType 枚举
- **绝不**在音频系统的 `match` 语句中使用 `_` 万用分支——每个枚举值都有显式分支以确保编译时覆盖 —— 来源: ADR-0005 §消极后果
- **绝不**发射携带指令的信号——`pre_transition` 携带事实（from、to、type），由音频系统自主决定如何处理，而非 SceneManager 告诉音频系统该做什么 —— 来源: ADR-0007

## 测试证据

| 证据类型 | 位置 | 级别 |
|----------|------|------|
| 自动化单元测试 | `tests/unit/scene_manager/test_transition_type.gd` | **阻塞** |
| 自动化单元测试 | `tests/unit/scene_manager/test_audio_transition_matrix.gd` | **阻塞** |

### 最小测试集

```
test_transition_type_enum_has_six_values
test_transition_type_none_is_zero
test_transition_audio_params_contains_all_types_except_none
test_transition_audio_params_menu_to_game_duration
test_transition_audio_params_game_to_menu_duration
test_transition_audio_params_explore_to_combat_duration
test_transition_audio_params_combat_to_explore_duration
test_transition_audio_params_tribulation_duration
test_pre_transition_signal_carries_transition_type
test_phase_5_resets_transition_type_to_none
test_request_scene_change_rejects_invalid_type (如有必要)
```

## 实现注意事项

- `TRANSITION_AUDIO_PARAMS` 为只读数据表——SceneManager 不执行音频操作，仅提供参数给消费方
- 音频系统作为独立 Story 实现——Story 002 仅定义数据契约和信号接口
- 音频系统的 `match type` 覆盖检查可通过 GUT 测试验证——测试遍历所有 TransitionType 值并断言存在对应的处理分支

## Completion Notes

**Completed**：2026-07-30
**Criteria**：6/6 通过
**Deviations**：无
**Code Review**：内联审查——实现规模小（~20行增量 + 30测试），代码无 BLOCKER 级别问题
