# Epic: 结局分支系统 (Ending Branch System)

> **Layer**: Feature
> **GDD**: `design/gdd/ending-branch-system.md`
> **Architecture Module**: 叙事子系统 — EndingEvaluator（嵌入 StorySystem 非 Autoload）
> **Status**: Backlog
> **Stories**: 3 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | EndingEvaluator 纯函数工具类 + evaluate_ending | Logic | Not Started | ADR-0029 |
| 002 | _calculate_scores / _resolve_tie 评分与平局 | Logic | Not Started | ADR-0029 |
| 003 | _determine_variant / _generate_epilogue 变体与尾声 | Logic | Not Started | ADR-0029 |

## Overview

实现结局分支判定——EndingEvaluator 纯函数工具类（嵌入 StorySystem，非 Autoload），通关时评估结局、解析平局、确定变体与生成尾声。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0029: 结局分支系统 | EndingEvaluator 纯函数 + 评分/平局/变体/尾声 | LOW |

## Definition of Done

This epic is complete when:
- 全部 3 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/ending-branch-system.md` 验收标准全部通过
- 评分与平局解析通过单元测试

## Next Step

Run `/dev-story production/epics/ending-branch-system/story-001-ending-evaluator.md` 逐条填充 AC 并实现。
