# Story 003：is_identity_selected / get_current_identity

> **Epic**: identity-selection-system
> **Story**: 003
> **Type**: Logic
> **ADR**: ADR-0022
> **Status**: In Progress
> **Estimate**: 0.5d
> **Dependencies**: Story 001

## 描述

实现身份选择状态查询 API——`is_identity_selected()` 和 `get_current_identity()`。这两个方法读取 GSM `player.identity_id` 判断身份是否已选择，用于读档跳过身份选择流程。

## 验收标准

| # | AC |
|---|---|
| 1 | `is_identity_selected()` 未选择时返回 false |
| 2 | `is_identity_selected()` 已选择时返回 true |
| 3 | `get_current_identity()` 返回当前身份 ID |
| 4 | 读档后（identity_id 非空）`is_identity_selected()` 返回 true——跳过身份选择 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/identity_selection_system.gd` | 已在 Story 6-1 实现 |
| `tests/unit/identity_selection_system/test_identity_query.gd` | 4 条 AC 测试 |

## GDD 来源

- `design/gdd/identity-selection-system.md` §6 身份重选/读档
- ADR-0022 §is_identity_selected / §get_current_identity / §读档行为