# Story 003：complete_chapter + GSM narrative.* 独占写入

> **Epic**: story-system
> **Story**: 003
> **Type**: Integration
> **ADR**: ADR-0026
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 StorySystem 的章节完成编排 `complete_chapter(branch_id)` 和 GSM narrative.* 域独占写入方法。StorySystem 通过 GSM 第二层原子方法写入 current_chapter_progress / completed_chapters，通过 EventSystem 委托写入 story_flags，发射 chapter_completed / game_victory Cat 2b 信号。

## 验收标准

| # | AC |
|---|---|
| 1 | `add_required_event_completion(event_id)` 将事件追加到 completed_required_events |
| 2 | `set_narrative_boss_unlocked(true)` 写入 boss_unlocked=true |
| 3 | `set_narrative_boss_defeated(true)` 写入 boss_defeated=true |
| 4 | `set_ending_chosen(branch_id)` 写入 ending_chosen 字段 |
| 5 | `complete_chapter("ch1_accept_mo")` 后 ch1 在 completed_chapters 中 |
| 6 | `complete_chapter` 后 current_chapter 推进到 ch2 |
| 7 | `complete_chapter` 后 story_flags 含结局分支 flag |
| 8 | `complete_chapter("ch5_ascend_immortal")` 发射 game_victory 而非 chapter_completed |
| 9 | `complete_chapter` 前未选择结局时返回 false |
| 10 | `complete_chapter` 前未击败 BOSS 时返回 false |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/foundation/gsm/gsm_atomic_writes.gd` | 4 个 narrative.* 第二层方法 |
| `src/foundation/game_state_manager.gd` | 4 个薄转发 wrapper |
| `src/feature/story_system.gd` | complete_chapter 编排 + Cat 2b 信号 |
| `tests/unit/story_system/test_complete_chapter.gd` | 10 条 AC 测试 |

## GDD 来源

- `design/gdd/story-system.md` §4 章节推进流程、§状态与转换
- ADR-0026 §决策 1 GSM-主存储 + §GSM 第二层新增方法 + §信号