# Story 004: set_state() 编排与过渡矩阵

> **Epic**: 音频管理
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic + Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: §8/§9（AudioState 枚举 12 态、过渡矩阵 24 行含修为养成双向）+ AC-BGM 触发链路
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线 + GDD 边界澄清 2026-09-07
**ADR Decision Summary**: **AudioState 过渡矩阵（GDD §9，24 行）是音频行为唯一真源**。SceneManager `TRANSITION_AUDIO_PARAMS` 降级为「TransitionType→AudioState 映射 + 转场时长」引用层——本 story 须同步修正 SceneManager 侧数值与既有单测（回归影响：`tests/unit/scene_manager/test_audio_transition_matrix.gd`、`test_transition_type.gd`）。非场景级转换（商店/事件/卡组编辑/修为养成为 UI overlay）由对应 UI 系统直接调用 `set_state()`。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: SceneManager 既有信号 `pre_transition(from, to, type)`——TransitionType 5 类（MENU_TO_GAME/GAME_TO_MENU/EXPLORE_TO_COMBAT/COMBAT_TO_EXPLORE/TRIBULATION）映射到 AudioState 转换。

**Control Manifest Rules (this layer)**:
- Required: 矩阵数据驱动化（GDScript 常量或资源文件）；矩阵完整性校验单测；SceneManager 信号绑定集成测试
- Forbidden: 矩阵数值散落在 if-else 分支
- Guardrail: set_state() 幂等（同状态重复调用无副作用）

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md` §8/§9，scoped to this story:*

- [ ] AudioState 12 态枚举 + 24 行过渡矩阵（含修为养成双向、暂停双向、卡组编辑双向）数据驱动化
- [ ] `set_state(state)` 查矩阵执行音频动作（交叉淡化经 Story 002 计划器、环境音动作经 Story 006 接口、SFX 清理）
- [ ] 矩阵完整性：每态至少 1 入边或 1 出边（含 CULTIVATING）；N/A 转换不可达（商店→战斗、身份选择→战斗、战败→非主菜单）
- [ ] SceneManager `pre_transition` 信号 → TransitionType→AudioState 映射 → `set_state()` 自动触发场景级转换
- [ ] **SceneManager `TRANSITION_AUDIO_PARAMS` 数值修正**：与矩阵真源对齐（探索→战斗 0.5s 淡出、渡劫 0.3s 顺序式），同步更新其单测
- [ ] 同状态重复调用幂等（无重启/无重复淡化）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：
- `STATE_TRANSITION_MATRIX: Dictionary` 数据驱动常量——行 = (from_state, to_state)，值 = {fade_out_sec, fade_in_sec, ambient_delta_db, sequential, ...}。
- `map_transition_type(from_scene, to_scene, type) -> Dictionary`（AudioState 转换查询）纯函数。
- 矩阵完整性校验（测试中执行）：每态有边、N/A 守护、参数在调优旋钮安全范围。

- **SceneManager 修正**：`TRANSITION_AUDIO_PARAMS` 的 EXPLORE_TO_COMBAT `from_behavior` 从 `cut` 改 `fade_out`(0.5s)；TRIBULATION 从 `cut+cut` 改顺序式淡出/淡入(0.3s)；MENU_TO_GAME 时长按矩阵行（身份选择→探索 1.0s 淡出/1.5s 淡入）。**变更集必须包含两个既有单测文件的同步更新**。
- 非场景级转换：商店/事件/卡组编辑/修为养成为 UI overlay（非 SceneManager 转场）——对应 UI 系统（exploration-ui / deck-editing-ui / cultivation UI）直接调用 `set_state(IN_SHOP)` 等。本 story 提供 API，调用侧归各 UI epic（Out of Scope 声明）。
- `set_state()` 组合调用 Story 002 的 `plan_transition()` 与 Story 006 的环境音接口。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: 淡化计划器本体
- Story 006: 环境音层管理（本 story 仅调用其接口）
- 各 UI epic：非场景级状态的调用侧（商店/事件/卡组编辑 UI 调 set_state）
- Story 007: BGM 存档恢复

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/audio/test_state_matrix.gd`）

- **AC-1**: 矩阵完整性
  - Given: STATE_TRANSITION_MATRIX
  - When: 校验
  - Then: 12 态每态至少 1 入边或 1 出边（含 CULTIVATING）；行数与 GDD §9 逐行对应（时长/dB/环境音动作/顺序标记）
  - Edge cases: N/A 转换（商店→战斗等 3 项）不存在于矩阵

- **AC-2**: 每行参数完备
  - Given: 矩阵任意行
  - When: 检查键
  - Then: fade_out_sec/fade_in_sec/ambient_delta_db 键齐全且在调优旋钮安全范围内
  - Edge cases: 降低类行（无切曲）参数形态正确

- **AC-3**: TransitionType 映射
  - Given: (from_scene, to_scene, type)
  - When: `map_transition_type()`
  - Then: 返回正确 AudioState 转换（5 类 TransitionType 全覆盖）
  - Edge cases: 未映射组合返回空（防御性）

**[Integration — automated test specs]**

- **AC-4**: 场景信号驱动（`tests/integration/audio/test_scene_signal_binding.gd`）
  - Given: AudioManager 已挂载
  - When: SceneManager 发 `pre_transition(EXPLORATION, COMBAT, EXPLORE_TO_COMBAT)`
  - Then: `set_state(IN_COMBAT)` 被调用，BGM 开始按矩阵行过渡
  - Edge cases: 转场中二次 pre_transition（续接语义委托 Story 002）

- **AC-5**: SceneManager 回归（更新后的 `tests/unit/scene_manager/test_audio_transition_matrix.gd`）
  - Given: TRANSITION_AUDIO_PARAMS 修正后
  - When: 全量测试
  - Then: 探索→战斗 fade_out 0.5s、渡劫顺序式 0.3s/0.3s 断言通过；无其他 TransitionType 行为变化

**[Logic — 幂等]:**

- **AC-6**: set_state 幂等
  - Given: 当前 IN_COMBAT
  - When: 再次 set_state(IN_COMBAT)
  - Then: 无 BGM 重启、无重复淡化计划

---

## Test Evidence

**Story Type**: Logic + Integration
**Required evidence**:
- Logic: `tests/unit/audio/test_state_matrix.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/audio/test_scene_signal_binding.gd` + 更新后的 scene_manager 单测 — must exist and pass（BLOCKING）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001/002（骨架与淡化原语）、Story 006 接口（环境音动作——可先以 stub 对接）
- Unlocks: 各 UI epic 的 set_state 调用侧
