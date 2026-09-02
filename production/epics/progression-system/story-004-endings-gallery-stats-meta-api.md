# Story 004：endings + gallery + stats + meta 领域 API

> **Epic**: progression-system
> **Story**: 004
> **Type**: Logic
> **ADR**: ADR-0012
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 ProgressionSystem 剩余 4 个领域 API——endings（unlock_ending 内置 total_completions 递增 + get_unlocked_endings / has_ending / get_ending_detail）、gallery（mark_card_discovered 去重 + is_card_discovered / get_card_gallery_stats）、stats（increment_stat 跨局累计 + set_stat 仅增不降）、meta（get_meta / set_meta 受限 key）。

## 验收标准

| # | AC |
|---|---|
| 1 | unlock_ending("ascension_solo", path, identity, realm) → {success: true}，写入 endings + 递增 total_completions |
| 2 | unlock_ending 重复解锁 → {success: false, reason: "already_unlocked"} |
| 3 | get_unlocked_endings() 返回已解锁 ending_id 数组 |
| 4 | mark_card_discovered("card_001") 首次标记 true，重复标记不发射信号 |
| 5 | is_card_discovered("card_001") 返回 true |
| 6 | get_card_gallery_stats() 返回 {total_discovered, total_cards=222, completion_pct} |
| 7 | increment_stat("total_battles", 1) 递增统计值 |
| 8 | set_stat("highest_damage", 999) 仅在 > 当前值时写入 |
| 9 | get_meta("total_completions") 返回值 |
| 10 | set_meta("total_playtime_seconds", 3600) 写入受限 key |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/meta/progression_system.gd` | endings/gallery/stats/meta 领域 API |
| `tests/unit/progression_system/test_remaining_domains_api.gd` | 10 条 AC 测试 |

## GDD 来源

- ADR-0012 §关键接口（endings/gallery/stats/meta 领域）
- GDD ending-branch-system.md §5 结局图鉴
- GDD card-system.md 卡牌图鉴
