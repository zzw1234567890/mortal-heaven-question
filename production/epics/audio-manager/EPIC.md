# Epic: 音频管理

> **Layer**: Presentation
> **GDD**: design/gdd/audio-system.md
> **Architecture Module**: 音频管理系统（AudioBus 配置、对象池——`play_sfx(id)` / `play_bgm(id)` / `set_volume(bus, db)`）
> **Status**: Ready
> **Stories**: Not yet created — run `/create-stories audio-manager`

## Overview

音频管理实现 BGM/SFX/环境音/UI 音效的加载、播放、混音与场景切换过渡：AudioBusLayout（dB 值）、双 AudioStreamPlayer 交叉淡化、分层 SFX 加载（T1/T2/T3）、ducking、20 条 BGM 过渡矩阵。按 ADR-0031 §1.2，AudioManager（RefCounted 控制类）启动时将 AudioStreamPlayer 节点池挂入 SceneManager PersistentLayer；暂停时音频总线显式暂停（与 pause-menu.md AC 一致）。

**R-06 关卡**：Ogg Vorbis 循环间隙在目标硬件实测——可听见则 BGM 改 WAV 或确认交叉淡化方案。

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
- 20 条 BGM 过渡矩阵全部可验证
- All Logic stories have passing test files in `tests/`

## Next Step

Run `/create-stories audio-manager` to break this epic into implementable stories.

**排期提示**（PR-EPIC 2026-09-07）：Sprint 13 可进前半（总线+通道架构）——独立轨道，无 UI 依赖。
