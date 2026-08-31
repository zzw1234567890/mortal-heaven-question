# Story 002：can_enter_chapter / get_chapter_context

> **Epic**: story-system
> **Story**: 002
> **Type**: Logic
> **ADR**: ADR-0026
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 StorySystem 的章节进入条件验证 `can_enter_chapter(chapter_id)` ——境界+前置章节+flag 三重校验，和章节上下文查询 `get_chapter_context(map_id)` ——供 ExplorationSystem 获取当前章节的必经事件列表。

## 验收标准

| # | AC |
|---|---|
| 1 | `can_enter_chapter("ch1")` 无前置章节要求时 allowed=true |
| 2 | `can_enter_chapter("ch2")` 未完成 ch1 时 allowed=false, reason 含前置章节名 |
| 3 | `can_enter_chapter("ch2")` 完成 ch1 且境界≥2 时 allowed=true |
| 4 | `can_enter_chapter("ch3")` 境界=2（金丹=3）时 allowed=false, reason 含境界要求 |
| 5 | `can_enter_chapter("ch1")` 新游戏（无前置）且境界=1 时 allowed=true |
| 6 | `get_chapter_context("未知地图")` 返回空字典 |
| 7 | `get_chapter_context("qing_yun_jian_zong")` 返回 ch1 上下文含 required_events |
| 8 | `get_chapter_context` 返回的 context 含 chapter_id 字段 |
| 9 | `get_chapter_context` 返回的 context 含 maps 列表 |
| 10 | `can_enter_chapter("无效ID")` 返回 allowed=false |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/story_system.gd` | can_enter_chapter + get_chapter_context 方法 |
| `tests/unit/story_system/test_chapter_context.gd` | 10 条 AC 测试 |

## GDD 来源

- `design/gdd/story-system.md` §公式 1 章节进入条件验证、§6 剧情与探索地图的绑定
- ADR-0026 §决策 4 自包含纯函数 + §关键接口