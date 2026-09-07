# Story 006: 环境音层与无障碍音频

> **Epic**: 音频管理
> **Status**: Ready
> **Layer**: Presentation
> **Type**: Logic + UI
> **Estimate**: [待 sprint 排期填写]
> **Manifest Version**: 2026-09-07
> **Last Updated**: [由 /dev-story 设置]

## Context

**GDD**: `design/gdd/audio-system.md`
**Requirement**: AC-AMBIENT-01~03 + AC-ACCESS-02~03 + 边缘 #13
*(Requirement text lives in GDD 验收标准——TR 注册表暂无表现层条目)*

**ADR Governing Implementation**: ADR-0031: 表现层架构基线 + GDD 边界澄清 2026-09-07
**ADR Decision Summary**: 环境音层管理（3 层上限/淘汰最旧/预设切换淡化）归本 story；状态切换时的 Ambient Bus dB 调整**归 Story 004 的矩阵执行**（本 story 提供接口）。字幕渲染（AC-ACCESS-01）deferred 至对话系统 epic——本 story 仅保留字幕开关设置位。

**Engine**: Godot 4.6 | **Risk**: HIGH
**Engine Notes**: 单声道输出验证方式（QL-STORY-READY 裁决）：AudioEffect 层实现 + 手动听觉测试（headless 无法自动化听感）。

**Control Manifest Rules (this layer)**:
- Required: 层管理/淘汰逻辑可单测；环境音预设数据驱动
- Forbidden: 环境音状态写入 GSM
- Guardrail: 环境音淡入淡出不阻塞主线程

---

## Acceptance Criteria

*From GDD `design/gdd/audio-system.md`，scoped to this story:*

- [ ] 进入探索地图加载完成后对应环境音预设播放（Ambient Bus -10dB，与 BGM 叠加）（AC-AMBIENT-01）
- [ ] 进入战斗 Ambient Bus 0.5s 降至 -18dB（-10 - 8），环境音继续播放不停止——dB 动作由 Story 004 矩阵执行（AC-AMBIENT-02）
- [ ] 战斗结束回探索 Ambient Bus 恢复 -10dB（AC-AMBIENT-03）
- [ ] 最多 3 层环境音叠加，第 4 层进入时淘汰最旧层
- [ ] 地图间切换：环境音淡出 1.0s → 淡入 1.5s（GDD §6）
- [ ] 环境音预设缺失：静默失败 + 日志警告，不影响 BGM/SFX（边缘 #13）
- [ ] 单声道开关：开启后左右声道输出相同信号（AC-ACCESS-02——AudioEffect 实现 + 手动听感验证）
- [ ] 字幕开关设置位（默认开）——渲染行为归对话系统 epic（AC-ACCESS-01 deferred）
- [ ] 所有音量滑条 0% → 对应总线 -80dB 无输出（AC-ACCESS-03 行为侧；滑条 UI 归 main-menu story 002）

---

## Implementation Notes

*Derived from ADR-0031 Implementation Guidelines:*

**Logic 内核（BLOCKING 单测目标）**：`AmbientLayerManager` 类——层注册/3 层上限/最旧淘汰/预设查询，纯逻辑可单测（节点引用注入）。

- dB 调整划界（QL-STORY-READY 2026-09-07）：状态切换的 Ambient Bus dB 动作（战斗 -8dB/事件商店 -6dB/恢复）**在 Story 004 的矩阵行内**——本 story 只暴露 `set_ambient_delta(db)` 接口与层管理。
- 单声道：AudioEffect（如 Panner/Mono 转换）挂在 Master 或各总线——设置位写入持久设置文件（main-menu 设置面板消费）。
- 字幕开关：设置位定义 + 读写接口；渲染 deferred。
- 预设：每地图环境音预设（风/水/鸟鸣组合）数据驱动。

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 004: 状态切换的 Ambient dB 动作执行
- 对话系统 epic（未建）: 字幕渲染（AC-ACCESS-01）
- main-menu story 002: 音量滑条 UI 与 0% 行为的用户侧
- 音频资产（环境音 OGG）：资产管线任务

---

## QA Test Cases

*Written by qa-lead at story creation. The developer implements against these — do not invent new test cases during implementation.*

**[Logic 内核 — automated test specs]**（`tests/unit/audio/test_ambient_layers.gd`）

- **AC-1**: 3 层上限与淘汰
  - Given: 已有 3 层环境音（t=0/100/200ms 进入）
  - When: 第 4 层请求
  - Then: t=0 的最旧层被淘汰，新层进入，总数仍 3
  - Edge cases: 恰 3 层时同 id 重复请求（刷新还是忽略——按实现定义锁定）

- **AC-2**: 预设缺失静默失败（边缘 #13）
  - When: `play_ambient("missing_preset")`
  - Then: 无崩溃、日志警告、BGM/SFX 播放不受影响
  - Edge cases: 部分层有效部分缺失的混合请求

**[Integration — automated test specs]:**

- **AC-3**: Ambient dB 动作（配合 Story 004）
  - Given: 探索环境音播放中（Ambient -10dB）
  - When: set_state(IN_COMBAT) 经矩阵触发
  - Then: Ambient Bus 0.5s 内降至 -18dB；环境音 playing 保持 true
  - Edge cases: 回探索恢复 -10dB

**[UI — manual verification steps]:**

- **AC-4**: 环境音听感与切换
  - Setup: 进入地图 A→切换地图 B
  - Verify: 环境音淡出 1.0s → 新预设淡入 1.5s；战斗中环境音明显降低但不停
  - Pass condition: 过渡无爆音、层次清晰

- **AC-5**: 单声道与 0% 静音
  - Setup: 设置开启单声道；某总线滑条拖 0%
  - Verify: 单侧听力可听全部内容；对应总线无输出
  - Pass condition: 左右声道内容一致（手动听感）；0% 完全无声

---

## Test Evidence

**Story Type**: Logic + UI
**Required evidence**:
- Logic: `tests/unit/audio/test_ambient_layers.gd` — must exist and pass（BLOCKING）
- Integration: Ambient dB 断言并入 `tests/integration/audio/test_scene_signal_binding.gd`（追加用例）— must pass（BLOCKING）
- UI: `production/qa/evidence/ambient-accessibility-evidence.md` + sign-off（听感/单声道/静音手动验证）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001（骨架）
- Unlocks: Story 004（环境音接口消费方）
