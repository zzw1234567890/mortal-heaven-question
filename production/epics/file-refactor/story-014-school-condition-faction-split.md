# Story 014: school_system.gd 拆分——流派库纯数据提取

> **Epic**: file-refactor
> **Sprint**: 12
> **层级**: Core
> **类型**: Refactor
> **状态**: Done
> **清单版本**: 2026-08-05
> **创建日期**: 2026-09-05
> **完成日期**: 2026-09-05

## 概述

将 `school_system.gd`（310 行）中的 `SCHOOL_LIBRARY` 编译时常量流派库（5 流派完整定义，~130 行纯数据）提取到 `src/core/school_system/school_library.gd` 纯数据子模块，主文件降至 ~175 行。

## 技术需求

- **TR-ID**: TR-school（流派检测）
- **治理 ADR**: ADR-0025（SchoolSystem）

## 验收标准

- [x] `school_library.gd` 子模块包含 `SCHOOL_LIBRARY` const Dictionary（5 流派完整定义）
- [x] 主文件通过 `const _Library := preload(...)` 引用
- [x] 主文件保留 `const SCHOOL_LIBRARY` 兼容别名（测试直接访问 SS.SCHOOL_LIBRARY 不中断）
- [x] 检测引擎/查询 API/条件评估委托逻辑不变
- [x] 全量测试零回归：143 scripts / 2455 tests / 0 failing
- [x] 不新增 Autoload

## 拆分内容

| 提取到 `school_library.gd`（纯数据） | 保留在 `school_system.gd` |
|---|---|
| `SCHOOL_LIBRARY` const Dictionary（5 流派完整定义） | 信号 / detect / calculate_match / 查询 API / 条件评估委托 |

## 范围外

- 不修改流派数据内容（检测条件/效果定义）
- 不修改检测引擎逻辑
- 不拆 `school_conditions.gd`（408 行为纯函数引擎，职责单一）

## 变更文件

- `src/core/school_system/school_library.gd` — 新增（~139 行）
- `src/core/school_system/school_system.gd` — 修改（310→~175 行）
