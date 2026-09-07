# Story 002: BGM 通道——双播放器交叉淡化

> **Epic**: 音频管理
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: AC-BGM-01~10 + 边缘 #1/#3/#12
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线
**ADR Decision Summary**: 双 AudioStreamPlayer（bgm_player_a/b）交叉淡化；`finished` 信号循环模式不触发——Tween+计时器编排；异步加载（`load_threaded_request`）；零状态所有权（BGM 播放状态归 AudioManager 自身，非 GSM 游戏状态）。

**Engine**: Godot 4.6 | **Risk**: HIGH（Tween/音频 API 在知识截止后有变更可能）
**Engine Notes**: **R-06 spike（Ogg 循环间隙实测）为本 story 前置**——产出格式裁决（WAV loop_begin/loop_end vs Ogg 接受 <30ms 间隙）。本 story 支持两种格式的循环配置，听感验证归 spike 记录。

**Control Manifest Rules (this layer)**:
- Required: 淡化编排提取为纯计划器函数 `plan_transition()`（BLOCKING 单测）；Tween 为薄执行层
- Forbidden: 依赖 `finished` 信号做循环切换；主线程同步加载 BGM
- Guardrail: 内存常驻 ≤2 首 BGM（当前+预加载下一首）

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`，scoped to this story:*

- [ ] 启动进主菜单 `bgm_main_menu` 播放，BGM Bus 0dB，循环（AC-BGM-01）
- [ ] 身份选择→探索：主菜单 BGM 1.0s 淡出 + 探索 BGM 1.5s 淡入（平行交叉淡化）（AC-BGM-02）
- [ ] 探索→战斗 0.5s/0.5s 交叉淡化（AC-BGM-03）；战斗→胜利 0.3s/0.5s（AC-BGM-04）；战斗→战败 0.5s/0.3s（AC-BGM-05）
- [ ] 商店：BGM Bus 0.5s 降至 -10dB 不断播（AC-BGM-06）；离开恢复（AC-BGM-07）
- [ ] 渡劫 BGM 独立播放，0.3s 顺序式过渡（先淡出完成再淡入）（AC-BGM-08，边界澄清 2026-09-07）
- [ ] 同 bgm_id 重复请求忽略（AC-BGM-09）；过渡期间二次切换中断 Tween 从当前 dB 续接（AC-BGM-10）
- [ ] BGM 文件损坏/缺失：记录错误、保持上一首继续播放、不崩溃（边缘 #1）
- [ ] 异步加载 + 预加载下一首；不再需要的 BGM 释放

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：`plan_transition(current_id, target_id, current_db, params) -> Array[Dictionary]` 纯计划器——返回淡化指令集（目标播放器/起止 dB/时长/曲线/顺序标记）。全部数值决策（平行 vs 顺序、降低 vs 切曲、中断续接起点）在此函数内，Tween 只执行。

- Tween 执行层：TRANS_SINE + EASE_IN_OUT（GDD 公式 1）；Boss/渡劫例外 sequential=true。
- 中断续接：新计划以**当前实际 dB**为起点（非 -80）。
- 同 id 忽略：计划器返回空集。
- 降低类（商店/事件/修为养成）：单条 Bus 音量指令，无播放器切换。
- 循环：WAV 用 loop_begin/loop_end（R-06 裁决后）；不依赖 `finished`。
- 异步加载：`ResourceLoader.load_threaded_request()`；常驻 2 首；损坏时保留旧曲。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: set_state() 编排与场景信号绑定（本 story 只提供 play_bgm/stop_bgm/plan 原语）
- Story 007: BGM 存档恢复
- R-06 spike 本体（独立前置任务）
- 环境音叠加：Story 006

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/audio/test_bgm_fade_planner.gd`）

- **AC-1**: 平行交叉淡化计划
  - Given: bgm_a 播放中 db=0，请求 bgm_b（fade_out 1.0 / fade_in 1.5）
  - When: 调用 `plan_transition()`
  - Then: 2 条平行指令——a: 0→-80dB/1.0s；b: -80→0dB/1.5s；trans=SINE, ease=EASE_IN_OUT
  - Edge cases: 双方时长相同；目标 dB 非零（如身份选择 -6dB）

- **AC-2**: 渡劫顺序例外
  - Given: 请求渡劫 BGM
  - When: 计划
  - Then: sequential=true——先 a 淡出完成(0.3s)再 b 淡入(0.3s)
  - Edge cases: 渡劫→胜利/战败出口是否顺序（按矩阵行，非顺序）

- **AC-3**: 中断续接（AC-BGM-10）
  - Given: a→b 淡入进行中，b 当前 db=-35
  - When: 请求 bgm_c
  - Then: 新计划中 b 的起点为 -35（非 -80），旧 Tween 标记 kill
  - Edge cases: 恰在边界时刻中断

- **AC-4**: 同 id 忽略（边缘 #12）
  - Given: bgm_b 当前播放中
  - When: `play_bgm("bgm_b")`
  - Then: 计划为空，不重启

- **AC-5**: 降低类不切曲
  - Given: 探索 BGM 播放中
  - When: 请求降至 -10dB（商店类）
  - Then: 计划为单条 BGM Bus 指令 0→-10dB/0.5s，无播放器切换

**[Integration — automated test specs]**（`tests/integration/audio/test_bgm_crossfade.gd`）

- **AC-6**: 真实交叉淡化（时长缩至 0.05s + await）
  - Given: 双 AudioStreamPlayer + 程序生成的静音 AudioStreamWAV
  - When: 执行过渡计划
  - Then: 终值 volume_db 与 playing 状态正确；中途二次切换从当前 dB 继续
  - Edge cases: 损坏文件路径→旧曲继续（边缘 #1）

**[Manual — ADVISORY]**

- **AC-7**: 听感验证（随 R-06 spike 记录）
  - Setup: 目标硬件播放过渡
  - Verify: 无爆音、交叉淡化自然、循环无显著间隙
  - Pass condition: spike 记录归档于 epic 证据目录

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/audio/test_bgm_fade_planner.gd` — must exist and pass（BLOCKING）
- Integration: `tests/integration/audio/test_bgm_crossfade.gd` — must exist and pass（BLOCKING）
- 听感：R-06 spike 记录（ADVISORY）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（骨架与总线）；R-06 spike（前置）
- Unlocks: Story 004（set_state 消费淡化原语）
