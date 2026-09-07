# Story 008: F1 静音状态图标（HUD）

> **Epic**: HUD 系统
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/audio-system.md`（AC-MUTE-01/02 图标部分）+ `design/gdd/hud-system.md`
**Requirement**: AC-MUTE-01/02 的 HUD 图标渲染（QL-STORY-READY 2026-09-07 归属裁决：audio 发信号、HUD 渲染）
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 表现层分工——音频系统 emit `mute_state_changed` 信号，HUD 消费信号渲染静音图标（扬声器+斜线）。零状态所有权：HUD 不存储静音状态，仅按信号切换显示。

**Engine**: Godot 4.6 | **Risk**: HIGH（双焦点变更在 LLM 知识截止后，但本 story 无焦点交互）
**Engine Notes**: 图标为静态纹理显示切换，无输入交互。

**Control Manifest Rules (this layer)**:
- Required: 显示由信号驱动；不缓存静音状态
- Forbidden: HUD 查询/修改音频状态（仅消费信号）
- Guardrail: 图标渲染 0 额外动画成本（显示/隐藏切换）

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md` AC-MUTE-01/02 图标部分，scoped to this story:*

- [ ] 按下 F1 进入静音时，HUD 角落显示静音图标（扬声器+斜线）
- [ ] 取消静音后图标消失
- [ ] 图标显示由 `mute_state_changed` 信号驱动（非轮询）
- [ ] 静音跨场景持久期间图标保持显示（AC-MUTE-04 视觉侧）
- [ ] 战斗场景 HUD 整体隐藏时图标随之隐藏（随 Story 001 可见性规则）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

- HUD 场景内图标节点（建议右下或左下角落固定位置），初始隐藏。
- 订阅 AudioManager `mute_state_changed(muted: bool)` 信号——muted=true 显示、false 隐藏。
- HUD 挂载时查询一次当前静音状态（初始化显示，如游戏在静音状态中启动）——此为唯一允许的主动查询（初始化同步，非轮询）。
- 图标资产：扬声器+斜线（美术资产管线任务，占位纹理先行）。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- audio-manager story 005: 静音机制/信号发射本体
- 图标美术资产正式版：资产管线任务

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not implement new test cases during implementation.*

**[Integration — automated test specs]:**

- **AC-1**: 信号驱动显示切换
  - Given: HUD 已挂载，图标隐藏
  - When: AudioManager emit `mute_state_changed(true)` → 后 emit `(false)`
  - Then: 图标先 visible 后隐藏
  - Edge cases: HUD 挂载时已处于静音（初始化查询显示正确）；连续快速切换（最终态一致）

- **AC-2**: 战斗可见性联动
  - Given: 静音图标显示中
  - When: 进入战斗（HUD 整体隐藏）
  - Then: 图标随 HUD 隐藏；回探索后若仍静音则恢复显示
  - Edge cases: 战斗中取消静音（信号到达时 HUD 隐藏——状态更新但不可见，恢复可见后正确）

**[UI — manual verification steps]:**

- **AC-3**: 图标视觉
  - Setup: 游戏运行中按 F1
  - Verify: HUD 角落出现扬声器+斜线图标；再按 F1 消失
  - Pass condition: 图标清晰可辨、位置不遮挡关键信息、切换即时

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- Integration: 信号驱动断言并入 `tests/integration/hud/test_gsm_signal_binding.gd`（追加用例）— must pass（BLOCKING）
- UI: `production/qa/evidence/mute-icon-evidence.md` + sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（HUD 挂载）；audio-manager story 005（mute_state_changed 信号）
- Unlocks: None
