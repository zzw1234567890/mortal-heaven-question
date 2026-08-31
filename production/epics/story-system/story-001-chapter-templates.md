# Story 001：CHAPTER_TEMPLATES 5 章静态定义（const Dictionary）

> **Epic**: story-system
> **Story**: 001
> **Type**: Logic
> **ADR**: ADR-0026
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 StorySystem Autoload 的 5 章静态定义 const Dictionary（CHAPTER_TEMPLATES），包含每章的 chapter_number / title / subtitle / entry_conditions / required_events / chapter_boss / ending_branches / completion / maps 字段。同时更新 GSM narrative 域默认值以包含 current_chapter_progress。

## 验收标准

| # | AC |
|---|---|
| 1 | `CHAPTER_TEMPLATES` 包含 5 个章节 |
| 2 | ch1 chapter_number=1, title="第一话：青云入世", min_realm=1 |
| 3 | ch1 required_events 含 5 个事件 |
| 4 | ch1 ending_branches 含 2 个分支（接受/拒绝墨渊） |
| 5 | ch2 chapter_number=2, min_realm=2（筑基期） |
| 6 | ch2 required_events 含 8 个事件（最长章节） |
| 7 | ch5 chapter_number=5, min_realm=5（化神期） |
| 8 | ch5 ending_branches 含 3 个分支（飞升/守护/回归） |
| 9 | 每章 completion.unlock_next_chapter 指向下一章（ch5 除外，为空） |
| 10 | GSM narrative 域默认值包含 current_chapter_progress 子字典 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/story_system.gd` | StorySystem Autoload + CHAPTER_TEMPLATES const Dictionary |
| `src/foundation/gsm/gsm_serializer.gd` | narrative 域默认值补充 current_chapter_progress |
| `project.godot` | 注册 StorySystem Autoload |
| `tests/unit/story_system/test_chapter_templates.gd` | 10 条 AC 测试 |

## GDD 来源

- `design/gdd/story-system.md` §2 五章详细定义
- ADR-0026 §决策 2 const Dictionary + §GSM 第二层新增方法