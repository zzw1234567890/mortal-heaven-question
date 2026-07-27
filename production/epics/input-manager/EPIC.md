# Epic: 输入管理器 (Input Manager)

> **Layer**: Foundation
> **GDD**: design/gdd/systems-mapping-2026-07-24.md（附录 B）
> **Architecture Module**: 输入仲裁器 — Autoload #2
> **Status**: In Progress
> **Stories**: 4 stories created — See below

## Overview

实现四级输入锁栈（DIALOGUE=0 → ANIMATION=1 → MODAL=2 → TRANSITION=3） + Godot 4.6 双焦点模式下的独立判定逻辑（鼠标和键盘焦点分别管理） + MODAL 层在紧急情况下的强制覆盖机制 + 白名单语义（锁类型而非键位，例如"战斗期间锁定除 ESC 外的所有键"而非"锁定 1-7"） + 投递前查询 GSM.session.input_locks。输入管理器是输入锁的单一仲裁者——所有其他系统通过它查询和请求锁变更。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0004: 输入管理器 | 四级锁栈 + 4.6 双焦点独立判定 + 白名单语义 + MODAL 覆盖机制 | HIGH |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-input-001 | 输入锁的单一仲裁者；在投递前查询 GSM.session.input_locks | ADR-0004 ✅ |
| TR-input-002 | 四级锁栈 (dialogue=0, animation=1, modal=2, transition=3) + 4.6 双焦点独立判定 | ADR-0004 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- 4.6 双焦点测试通过：鼠标焦点和键盘焦点可独立管理，互不干扰
- MODAL 覆盖机制通过紧急场景测试（例如战斗中 ESC 打开暂停菜单不受战斗锁影响）
- 白名单语义验证：锁定义使用语义名称而非硬编码键位列表

## Stories

| # | Story | 类型 | 预估 | 依赖 |
|---|-------|------|------|------|
| 001 | [四级锁栈核心实现](story-001-lock-stack-core.md) | Logic | 3 | 无 |
| 002 | [双焦点输入判定](story-002-dual-focus-judgment.md) | Logic | 5 | Story 001 |
| 003 | [GSM 同步、信号传播与输入分发](story-003-gsm-sync-signal-routing.md) | Integration | 4 | Story 001 + 002 |
| 004 | [MODAL 覆盖机制与边缘情况](story-004-modal-override-edge-cases.md) | Logic + Integration | 5 | Story 001 + 002 + 003 |

## Next Step

Run `/story-readiness story-001-lock-stack-core` to validate the first story, then `/dev-story` to implement.