# Story 005：progression_updated 信号 + batch_update + SaveLoad 集成

> **Epic**: progression-system
> **Story**: 005
> **Type**: Integration
> **ADR**: ADR-0012
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 ProgressionSystem 的信号去重机制和批量更新 API——batch_update_begin/end 嵌套计数器、_batch_pending_domains 累积域集合、batch_update_end 时一次性发射合并信号。验证 SaveLoadSystem 监听 progression_updated 信号后调用 has_unsaved_changes + serialize + mark_saved 的被动持久化集成。

## 验收标准

| # | AC |
|---|---|
| 1 | batch_update_begin() 后 _batch_depth = 1 |
| 2 | 批量期间多次 increment_stat 只在 batch_update_end 时发射一次 progression_updated |
| 3 | batch_update 嵌套 2 层，仅最外层 end 时发射信号 |
| 4 | 非批量模式下 increment_stat 每次都发射 progression_updated |
| 5 | batch_update_end 后 _batch_depth = 0 |
| 6 | progression_updated 信号携带 domain 参数 |
| 7 | SaveLoad 监听 progression_updated → 调用 has_unsaved_changes 返回 true |
| 8 | SaveLoad 调用 serialize() 获取完整数据后 mark_saved() |
| 9 | mark_saved 后 has_unsaved_changes 返回 false |
| 10 | 批量期间不同域的变更在 end 时合并发射各自 domain 信号 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/meta/progression_system.gd` | batch_update API + 信号去重 |
| `tests/unit/progression_system/test_batch_and_integration.gd` | 10 条 AC 测试 |

## GDD 来源

- ADR-0012 §批量更新 API + §progression_updated 信号设计
