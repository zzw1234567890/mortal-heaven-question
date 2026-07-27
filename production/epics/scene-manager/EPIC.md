# Epic: 场景管理器 (Scene Manager)

> **Layer**: Foundation
> **GDD**: design/gdd/systems-mapping-2026-07-24.md（附录 C）
> **Architecture Module**: 场景转换编排者 — Autoload #3
> **Status**: In Progress
> **Stories**: 4 stories created — 2026-07-27

| # | Story | 类型 | 优先级 | 状态 |
|---|-------|------|--------|------|
| S01 | [5 阶段转换管线核心](story-001-five-phase-pipeline-core.md) | Logic | P0 | Ready |
| S02 | [TransitionType 枚举 + 音频过渡矩阵](story-002-transition-type-audio-matrix.md) | Logic | P1 | Ready |
| S03 | [转场前自动存档 + 输入锁定集成](story-003-autosave-input-lock-integration.md) | Integration | P1 | Ready |
| S04 | [加载画面 + 异步加载 + 错误恢复](story-004-loading-screen-async-error-recovery.md) | Integration | P2 | Ready |

## Overview

实现 5 阶段场景转换管线——(1) 转场前触发自动存档、(2) TRANSITION 级别锁定输入、(3) 显示加载画面（水墨过渡动画）、(4) 场景树原子替换、(5) 发射 post_transition 信号并解锁输入。SceneManager 是场景树变更的唯一调用者——所有其他系统通过它委托场景切换，不得直接操作 `get_tree().change_scene()`。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0005: 场景管理器 | 5 阶段转换管线 + 转场前自动存档 + 输入锁 + 加载画面 + 场景树唯一调用者 | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-scene-001 | 场景转换编排者；场景树变更的唯一调用者 | ADR-0005 ✅ |
| TR-scene-002 | 5 阶段转换管线——转场前自动存档+锁定输入+加载画面+转场后信号+解锁 | ADR-0005 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- 场景转换管线通过 5 阶段集成测试
- 自动存档在每次转换前触发（可验证：存档文件时间戳在场景切换前更新）
- 所有场景切换统一通过 SceneManager——grep 验证代码库中无直接的 `get_tree().change_scene()` 调用

## Next Step

Run `/create-stories scene-manager` to break this epic into implementable stories.