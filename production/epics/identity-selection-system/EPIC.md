# Epic: 开局身份选择系统 (Identity Selection System)

> **Layer**: Feature
> **GDD**: `design/gdd/identity-selection-system.md`
> **Architecture Module**: 探索与经济子系统 — IdentitySelectionSystem Autoload #21
> **Status**: Backlog
> **Stories**: 3 stories（标题级预创建——AC 待 `/dev-story` 填充）

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 身份模板 const Dictionary（6 个）+ 查询 API | Logic | Not Started | ADR-0022 |
| 002 | apply_identity 原子操作（编排现有服务 API） | Integration | Not Started | ADR-0022 |
| 003 | is_identity_selected / get_current_identity | Logic | Not Started | ADR-0022 |

## Overview

实现开局身份选择——6 个身份模板 const Dictionary，apply_identity 原子操作通过现有服务 API 编排状态写入（不持有运行时可变状态，身份选择完成后所有状态存 GSM），天赋键值注册表。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0022: 开局身份选择系统 | 身份模板 + apply_identity 原子编排 + GSM 存储 | LOW |

## Definition of Done

This epic is complete when:
- 全部 3 个 story 经 `/dev-story` 实现、经 `/story-done` 关闭
- `design/gdd/identity-selection-system.md` 验收标准全部通过
- 身份查询通过单元测试；apply_identity 编排通过集成测试

## Next Step

Run `/dev-story production/epics/identity-selection-system/story-001-identity-templates.md` 逐条填充 AC 并实现。
