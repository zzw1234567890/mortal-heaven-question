# Epic: 存档/读档系统 (Save/Load System)

> **Layer**: Foundation
> **GDD**: design/gdd/save-load-system.md
> **Architecture Module**: 持久化引擎 — Autoload #4
> **Status**: Ready
> **Stories**: 5 stories — see table below

## Stories

| # | Story | Type | TR-ID | Depends On | Status |
|---|-------|------|-------|------------|--------|
| 001 | JSON 序列化引擎 + SaveResult/LoadResult 枚举 | Logic | TR-save-001 | — | Ready |
| 002 | 原子写入策略 + 重入防护 + Windows 重试 | Integration | TR-save-003 | Story 001 | Ready |
| 003 | 存档容器 schema + "complete" 标记 + 完整性校验 | Integration | TR-save-001, TR-save-002 | Story 001, 002 | Ready |
| 004 | GSM 状态序列化/反序列化 + 公共 API 整合 | Integration | TR-save-001 | Story 001, 002, 003 | Ready |
| 005 | schema_version 迁移链 + VERSION_MISMATCH 拒绝 | Logic | TR-save-002 | Story 001, 003, 004 | Ready |

**实现顺序**: 001 → 002 → 003 → 004 → 005（严格线性——每 Story 依赖前一个的结果）

## Overview

实现 4 种存档类型（自动/手动/快照/元进度）+ JSON 序列化/反序列化管线 + schema_version 驱动的迁移链 + 原子双写策略（.tmp → rename_absolute → .bak） + Windows 重命名重试（3×50ms，应对防病毒/索引器锁定） + complete 标记纵深防御。使用 `JSON.new().parse()` 而非 `JSON.parse_string()` 以区分合法 null 和解析错误。

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| ADR-0002: 存档/读档 | JSON 格式 + schema_version 迁移 + 原子写入 + Windows 重试 | MEDIUM |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-save-001 | 4 种存档类型（自动/手动/快照/元进度） | ADR-0002 ✅ |
| TR-save-002 | 版本化存档格式：schema_version 驱动迁移链 | ADR-0002 ✅ |
| TR-save-003 | 写入原子性：.tmp + rename 双写策略 | ADR-0002 ✅ |

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/save-load-system.md` are verified
- All Logic and Integration stories have passing test files in `tests/`
- 存档文件可被独立验证：写入后读取返回一致数据，完整标记 `complete: true` 存在
- Windows 平台下重命名重试机制通过模拟文件锁定测试

## Next Step

Run `/create-stories save-load` to break this epic into implementable stories.