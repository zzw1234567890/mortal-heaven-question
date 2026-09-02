# Epic: 对话系统 (Dialogue System)

> **Layer**: Feature
> **GDD**: `design/gdd/dialogue-system.md`
> **Architecture Module**: 叙事子系统 — DialogueSystem（RefCounted 服务类 非 Autoload）
> **Status**: Backlog
> **Stories**: 3 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | DialoguePlayer + DialogueDatabase 数据结构 | Logic | Done | ADR-0027 |
| 002 | start_dialogue / select_option / advance 播放编排 | Logic | Done | ADR-0027 |
| 003 | BarkManager + play_bark + get_bark_history | Logic | Done | ADR-0027 |

## Overview

实现对话播放——DialoguePlayer/DialogueDatabase/BarkManager（RefCounted 服务类非 Autoload），对话选项选择、节点可见性/可用性判定、气泡对白与历史记录。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0027: 对话系统 | RefCounted 服务类 + DialoguePlayer/BarkManager | LOW |

## Definition of Done

This epic is complete when:
- 全部 3 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/dialogue-system.md` 验收标准全部通过
- 对话树播放与条件判定通过单元测试

## Next Step

Run `/dev-story production/epics/dialogue-system/story-001-dialogue-player.md` 逐条填充 AC 并实现。
