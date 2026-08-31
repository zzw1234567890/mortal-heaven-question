# Story 004：is_boss_unlocked / on_boss_defeated

> **Epic**: story-system
> **Story**: 004
> **Type**: Logic
> **ADR**: ADR-0026
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 StorySystem 的 BOSS 解锁判定 `is_boss_unlocked()` ——检查当前章节所有必经事件是否完成，和 BOSS 击败处理 `on_boss_defeated()` ——设置 boss_defeated=true 并发射 boss_unlocked Cat 2b 信号。

## 验收标准

| # | AC |
|---|---|
| 1 | 必经事件全部完成时 is_boss_unlocked()=true |
| 2 | 必经事件未完成时 is_boss_unlocked()=false |
| 3 | 无必经事件（空列表）时 is_boss_unlocked()=true |
| 4 | on_boss_defeated() 设置 boss_defeated=true |
| 5 | on_boss_defeated() 发射 boss_unlocked 信号 |
| 6 | on_boss_defeated() 前置条件——is_boss_unlocked()=false 时不执行 |
| 7 | is_boss_unlocked() 读取当前章节模板的 required_events |
| 8 | on_boss_defeated() 后 complete_chapter 可正常执行 |
| 9 | 必经事件部分完成（2/5）时 is_boss_unlocked()=false |
| 10 | 当前章节为空时 is_boss_unlocked()=false |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/story_system.gd` | is_boss_unlocked + on_boss_defeated 方法 |
| `tests/unit/story_system/test_boss_unlock.gd` | 10 条 AC 测试 |

## GDD 来源

- `design/gdd/story-system.md` §公式 2 章末BOSS解锁判定
- ADR-0026 §决策 1 + §关键接口