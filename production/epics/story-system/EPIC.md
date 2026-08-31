# Epic: 剧情系统（章节推进） (Story System)

> **Layer**: Feature
> **GDD**: `design/gdd/story-system.md`
> **Architecture Module**: 叙事子系统 — StorySystem Autoload #25
> **Status**: Backlog
> **Stories**: 4 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | CHAPTER_TEMPLATES 5 章静态定义（const Dictionary） | Logic | Done | ADR-0026 |
| 002 | can_enter_chapter / get_chapter_context | Logic | Done | ADR-0026 |
| 003 | complete_chapter + GSM narrative.* 独占写入 | Integration | Done | ADR-0026 |
| 004 | is_boss_unlocked / on_boss_defeated | Logic | Done | ADR-0026 |

## Overview

实现章节推进——5 章静态定义 const Dictionary，运行时叙事状态通过 GSM narrative.* 域存储（StorySystem 是 current_chapter/chapter_progress/completed_chapters 的独占运行时写入者，story_flags 除外——委托 EventSystem）。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0026: 剧情系统 | 5 章 const 定义 + GSM 主存储 + 独占写入 | LOW |

## Definition of Done

This epic is complete when:
- 全部 4 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/story-system.md` 验收标准全部通过
- 章节判定通过单元测试；GSM narrative 集成通过集成测试

## Next Step

Run `/dev-story production/epics/story-system/story-001-chapter-templates.md` 逐条填充 AC 并实现。
