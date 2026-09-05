# Story 009: alchemy_system.gd 拆分——配方表提取

> **Epic**: file-refactor
> **Sprint**: 12
> **层级**: Feature
> **类型**: Refactor
> **状态**: Done
> **清单版本**: 2026-08-05
> **创建日期**: 2026-09-05
> **完成日期**: 2026-09-05

## 概述

将 `alchemy_system.gd` 中的炼丹配方表与配方查询 API 提取到 `src/feature/alchemy/alchemy_recipes.gd` 纯数据子模块（Sprint 12 首个拆分 Story，代码随 3bd47f8 提交）。

## 技术需求

- **TR-ID**: TR-alchemy（炼丹炼器系统）
- **治理 ADR**: ADR-0020（AlchemySystem）

## 验收标准

- [x] `alchemy_recipes.gd` 子模块包含配方表 const Dictionary + 配方查询 API
- [x] 主文件通过 preload 引用子模块
- [x] 炼制编排/品质滚动逻辑不变（品质滚动已在 Sprint 9 拆至 alchemy_quality_roller.gd）
- [x] 全量测试零回归：143 scripts / 2455 tests / 0 failing
- [x] 不新增 Autoload

## 拆分内容

| 提取到 `alchemy_recipes.gd`（纯数据） | 保留在 `alchemy_system.gd` |
|---|---|
| 配方表 const Dictionary / 配方查询 API | 品质常量/枚举/炼制编排/查询 API 委托 |

## 范围外

- 不修改配方数据内容
- 不修改品质滚动子模块（alchemy_quality_roller.gd）

## 变更文件

- `src/feature/alchemy/alchemy_recipes.gd` — 新增
- `src/feature/alchemy_system.gd` — 修改（379 行）
