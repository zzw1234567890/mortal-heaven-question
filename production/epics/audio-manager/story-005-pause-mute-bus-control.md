# Story 005: 暂停/静音/总线音量控制

> **Epic**: 音频管理
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic + Integration
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: AC-PAUSE-01~02 / AC-MUTE-01~04 / AC-BUS-01~02 + 边缘 #5/#6/#9
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线（§1.1 暂停）
**ADR Decision Summary**: 暂停 = 暂停菜单逻辑显式调用 `pause_all()`/`resume_all()`（音频节点 PROCESS_MODE_ALWAYS，不受 SceneTree.paused 冻结）。F1 静音 = Master `volume_db = -80dB`（边界澄清 2026-09-07 统一机制），emit `mute_state_changed` 信号供 HUD 渲染图标。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: F1 按键捕获经 InputManager（既有 `is_input_allowed(action_type, device)` 公共 API 判定放行——暂停中/弹窗中语义）。debounce 200ms 需时间注入单测。

**Control Manifest Rules (this layer)**:
- Required: MuteController 时间注入（clock: Callable）；mute_state_changed 信号
- Forbidden: F1 处理散落多个系统；静音状态经 GSM
- Guardrail: pause_all/resume_all 幂等

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`，scoped to this story:*

- [ ] `pause_all()`：BGM 在当前位置暂停（t=5.0s 处停止）（AC-PAUSE-01）
- [ ] `resume_all()`：从暂停位置继续（t=5.0s）（AC-PAUSE-02）
- [ ] F1 → Master volume_db = -80dB + `mute_state_changed` 信号（AC-MUTE-01）；再按恢复**静音前的值**（非 0dB）（AC-MUTE-02）
- [ ] 200ms debounce：窗口内重复 toggle 忽略，状态不抖动（AC-MUTE-03 / 边缘 #5）
- [ ] 静音跨场景持久（新场景 BGM 播放但保持静音）（AC-MUTE-04 / 边缘 #6）
- [ ] `set_bus_volume` 总线独立性：SFX 滑条改 -40dB 不影响 BGM/Ambient（AC-BUS-01）
- [ ] `get_bus_volume` 与设置面板显示一致（±0.5dB 精度）（AC-BUS-02）

---

## Implementation Notes

*Derived from ADR-0031 §1.1 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：`MuteController` 类——debounce 窗口判定（时间注入）、静音前值记忆、`mute_state_changed` 信号发射。

- 暂停：`pause_all()` = 全部 AudioStreamPlayer `stream_paused = true`（位置保持）；`resume_all()` 逆序恢复。与 hud story 005（暂停菜单）对接——菜单调用这两个 API（hud 侧已声明）。
- F1 捕获：InputManager `is_input_allowed()` 判定后转发 AudioManager.toggle_mute()——具体放行策略（暂停中/弹窗中是否允许 F1）按 InputManager 既有规则。
- 静音前值记忆：静音时保存 Master 当前 dB（用户设置值），取消时恢复——非硬编码 0dB。
- 图标渲染：hud epic story 008 消费 `mute_state_changed` 信号——本 story 只发信号。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- hud epic story 005: 暂停菜单（调用侧）与 story 008: 静音图标渲染
- main-menu epic story 002: 设置滑条（db_from_percent 归其所有；本 story 提供 set_bus_volume/get_bus_volume API）
- Story 004: set_state 编排

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/audio/test_mute_controller.gd`，时间注入）

- **AC-1**: debounce（AC-MUTE-03）
  - Given: clock=0 toggle（生效）
  - When: clock=150ms toggle → clock=250ms toggle
  - Then: 150ms 的被忽略（静音状态保持）；250ms 的生效
  - Edge cases: clock=199ms（忽略）与 200ms（生效）分界

- **AC-2**: 恢复值记忆（AC-MUTE-02）
  - Given: Master 用户设置为 -3dB
  - When: 静音 → 取消静音
  - Then: Master 恢复 -3dB 而非 0dB
  - Edge cases: 默认 0dB 时恢复 0dB；连续静音→取消→静音

- **AC-3**: 跨场景持久（AC-MUTE-04）
  - Given: 静音状态
  - When: set_state 场景切换（BGM 换曲）
  - Then: Master 仍 -80dB；取消静音后新 BGM 正常可听
  - Edge cases: 静音中 pause_all/resume_all 往返

**[Integration — automated test specs]**

- **AC-4**: 暂停位置保持（`tests/integration/audio/test_pause_resume_position.gd`）
  - Given: BGM 播放至 t=5.0s
  - When: `pause_all()` → 推进若干帧 → `resume_all()`
  - Then: 暂停期间位置不变；恢复后从 5.0s 继续
  - Edge cases: 暂停中请求 play_sfx（按 ADR-0031 §1.1 音频总线显式暂停——不播放）

- **AC-5**: 总线独立性（AC-BUS-01）
  - Given: 所有总线正常
  - When: `set_bus_volume(SFX, -40.0)`
  - Then: SFX Bus -40dB；BGM 保持 0dB；Ambient 保持 -10dB
  - Edge cases: get_bus_volume(SFX) 返回 -40（±0.5dB，AC-BUS-02）

---

## Test Evidence

**Story Type**: Logic + Integration
**Required evidence**:
- Logic: `tests/unit/audio/test_mute_controller.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/audio/test_pause_resume_position.gd` — must exist and pass（BLOCKING）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（骨架与总线）
- Unlocks: hud story 005 对接（暂停）、story 008（静音图标）、main-menu story 002（滑条）
