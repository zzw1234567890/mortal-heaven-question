# Epic: 游戏状态管理器 (Game State Manager)

> **Layer**: Foundation
> **GDD**: design/gdd/game-state-manager.md
> **Architecture Module**: 运行时数据中心 — Autoload #1
> **Status**: Ready
> **Stories**: 5 created (2026-07-27)

## Overview

实现 GSM 三层 API——第一层 O(1) 属性直读、第二层原子写入方法（24 个域方法）、第三层信号订阅层。提供 batch_updated 信号携带 `{path: {old, new}}` 展平字典、启动时校验跳过模式（validation_enabled=false）、以及 CardSystem 模板加载后的 enable_validation(db) 激活流程。GSM 必须占据 Autoload #1 位置以保证 `_ready()` 先于任何消费者读取完成。

## Stories

| # | Story | Type | ACs | Status |
|---|-------|------|-----|--------|
| 001 | [Autoload 基础结构与第一层属性读取](./story-001-autoload-structure-and-tier1-read.md) | Logic | 2 | Ready |
| 002 | [第二层原子写入方法](./story-002-atomic-write-methods.md) | Logic | 10 | Ready |
| 003 | [第三层信号订阅层 + batch_updated 展平字典](./story-003-signal-layer-batch-updated.md) | Logic | 4 | Ready |
| 004 | [序列化与反序列化](./story-004-serialize-deserialize.md) | Logic | 3 | Ready |
| 005 | [启动校验跳过模式 + enable_validation 激活流程](./story-005-validation-skip-enable.md) | Integration | 4 | Ready |

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0001: 游戏状态管理器 | 三层 API + 原子方法 + batch_updated 展平字典 + 启动校验跳过 | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-gsm-001 | GSM 为运行时单一数据源，通过 Autoload 常驻内存 | ADR-0001 ✅ |
| TR-gsm-002 | 读写接口规范：通用 get(path)、批量设置、类型安全读取 | ADR-0001 ✅ |
| TR-gsm-003 | 信号广播机制：13 个命名事件，同帧去重，batch_updated 用于批量变更 | ADR-0001 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/game-state-manager.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- Initialization sequence validated: GSM `_ready()` completes before any consumer in Autoload chain

## Next Step

Run `/create-stories gsm` to break this epic into implementable stories.