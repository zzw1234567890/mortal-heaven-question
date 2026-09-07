# Epic: 音频管理

> **Layer**: Presentation
> **GDD**: design/gdd/audio-system.md
> **Architecture Module**: 音频管理系统（AudioBus 配置、对象池——`play_sfx(id)` / `play_bgm(id)` / `set_volume(bus, db)`）
> **Status**: Ready
> **Stories**: 7 stories — see below

## Overview

音频管理实现 BGM/SFX/环境音/UI 音效的加载、播放、混音与场景切换过渡：AudioBusLayout（dB 值）、双 AudioStreamPlayer 交叉淡化、分层 SFX 加载（T1/T2/T3）、ducking、24 条 BGM 过渡矩阵。按 ADR-0031 §1.2，AudioManager（RefCounted 控制类）启动时将 AudioStreamPlayer 节点池挂入 SceneManager PersistentLayer；暂停时音频总线显式暂停（与 pause-menu.md AC 一致）。

**R-06 关卡**：Ogg Vorbis 循环间隙在目标硬件实测（独立 spike，Sprint 13 开始前）——可听见则 BGM 改 WAV 或确认交叉淡化方案。

**边界澄清落地（2026-09-07，QL-STORY-READY）**：AudioState 过渡矩阵为唯一真源（SceneManager TRANSITION_AUDIO_PARAMS 降级为映射层并同步修正单测，story 004）；总线一律按名称访问；Boss 过渡统一顺序式；F1 静音=Master -80dB；F1 图标归 hud epic story 008；字幕渲染 deferred 对话系统；BGM 存档恢复新增 story 007；UI 音效 80ms 规则扩入 story 003。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0031: 表现层架构基线 | §1.2 PersistentLayer 挂载结构（定死）；§1.1 暂停音频总线显式暂停 | HIGH（4.6 双焦点） |
| ADR-0005: 场景管理器 | `pre_transition` 信号驱动音频过渡 | LOW |

## GDD Requirements

TR 注册表暂无表现层条目——需求以 GDD 验收标准编号占位：

| AC 编号 | Requirement | ADR Coverage |
|-------|-------------|--------------|
| AC-audio-001~031 | audio-system.md §验收标准（31 条，2026-07-23 full 审查修订版） | ADR-0031 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/audio-system.md` are verified（31 条）
- **R-06 关卡：Ogg 循环间隙实测结论 + 方案记录（WAV 或交叉淡化）**
- 24 条 BGM 过渡矩阵（含修为养成/暂停/卡组编辑双向）全部可验证
- SceneManager TRANSITION_AUDIO_PARAMS 已对齐矩阵真源（含其单测更新）
- All Logic stories have passing test files in `tests/`

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | AudioBusLayout 与 AudioManager 骨架（PersistentLayer） | Integration | Ready | ADR-0031 |
| 002 | BGM 通道——双播放器交叉淡化 | Logic | Ready | ADR-0031 |
| 003 | SFX 池——16 节点池与淘汰/冷却/随机化 | Logic | Ready | ADR-0031 |
| 004 | set_state() 编排与过渡矩阵（含 SceneManager 对齐） | Logic + Integration | Ready | ADR-0031 |
| 005 | 暂停/静音/总线音量控制 | Logic + Integration | Ready | ADR-0031 |
| 006 | 环境音层与无障碍音频 | Logic + UI | Ready | ADR-0031 |
| 007 | BGM 存档恢复（save-load 对接） | Integration | Ready | ADR-0031 |

**前置任务（非 story）**：R-06 Ogg 循环间隙 spike——Sprint 13 开始前 0.5-1 天，产出实测记录 + WAV/Ogg 格式裁决（关闭风险项），story 002 依赖其结论。

## Next Step

Run `/create-stories audio-manager` to break this epic into implementable stories.

**排期提示**（PR-EPIC 2026-09-07）：Sprint 13 可进前半（总线+通道架构）——独立轨道，无 UI 依赖。
