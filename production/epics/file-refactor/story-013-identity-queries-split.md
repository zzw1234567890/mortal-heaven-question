# Story 013: identity_selection_system.gd 拆分——身份模板表提取

> **Epic**: file-refactor
> **Sprint**: 12
> **层级**: Feature
> **类型**: Refactor
> **状态**: Done
> **清单版本**: 2026-08-05
> **创建日期**: 2026-09-05
> **完成日期**: 2026-09-05

## 概述

将 `identity_selection_system.gd`（557 行）中的 6 个身份模板 const Dictionary（~200 行纯数据）提取到 `src/feature/identity/identity_templates.gd`，主文件降至 ~360 行。

## 技术需求

- **TR-ID**: TR-identity（身份模板表——6 个身份的单一真理来源）
- **治理 ADR**: ADR-0022（IdentitySelectionSystem）

## 验收标准

- [x] `identity_templates.gd` 子模块包含 6 个身份模板 const Dictionary
- [x] `identity_selection_system.gd` 通过 `const _Templates := preload(...)` 引用
- [x] 主文件保留 `const IDENTITY_TEMPLATES` 兼容别名（测试直接访问不中断）
- [x] `_get_character_names` 委托给子模块 static 方法
- [x] 全量测试零回归：143 scripts / 2455 tests / 0 failing
- [x] 不新增 Autoload

## 拆分内容

| 提取到 `identity_templates.gd` | 保留在 `identity_selection_system.gd` |
|---|---|
| `IDENTITY_TEMPLATES` const Dictionary（6 身份完整数据）| 信号 / 查询 API / `apply_identity` 8 步编排 / `_rollback_identity` + 薄委托 |
| `get_character_names` (static) | |

## 范围外

- 不修改模板数据内容
- 不修改 `apply_identity` 编排逻辑
- 不修改 `identity_initializer.gd`

## 变更文件

- `src/feature/identity/identity_templates.gd` — 新增（~220 行）
- `src/feature/identity_selection_system.gd` — 修改（557→~360 行）