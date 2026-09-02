# Story 001：DialoguePlayer + DialogueDatabase 数据结构

> **Epic**: dialogue-system
> **Story**: 001
> **Type**: Logic
> **ADR**: ADR-0027
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 DialoguePlayer 和 DialogueDatabase 两个 RefCounted 服务类——DialogueDatabase 持有对话树定义（从 JSON 按需加载 + 内存缓存 + get_tree / has_tree 查询）、DialoguePlayer 持有播放状态（当前节点 ID + 对话历史 + 条件评估器内部类）、start_node / get_current_node / advance / select_choice 播放控制 API。本 Story 聚焦数据结构和查询，播放编排留 Story 002。

## 验收标准

| # | AC |
|---|---|
| 1 | DialogueDatabase 加载对话树 JSON 并缓存到内存 |
| 2 | get_tree("ch1_test") 返回对话树 Dictionary |
| 3 | has_tree("ch1_test") 返回 true，不存在返回 false |
| 4 | DialoguePlayer start 后 _current_node_id = start_node |
| 5 | get_current_node() 返回当前节点 Dictionary |
| 6 | DialoguePlayer 持有对话历史 _dialogue_history Array |
| 7 | advance() 无 choices 时推进到 next_node |
| 8 | advance() 到 end_node 后标记 _is_finished = true |
| 9 | DialoguePlayer 释放后状态清空（RefCounted 生命周期）|
| 10 | 对话树节点包含 speaker / text / next_node / choices 字段 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/dialogue/dialogue_database.gd` | DialogueDatabase RefCounted |
| `src/feature/dialogue/dialogue_player.gd` | DialoguePlayer RefCounted |
| `tests/unit/dialogue_system/test_data_structures.gd` | 10 条 AC 测试 |
| `tests/unit/dialogue_system/test_dialogue_data.json` | 测试用对话树 JSON |

## GDD 来源

- GDD dialogue-system.md §1 对话数据结构
- ADR-0027 §决策 1~3（RefCounted + JSON + 播放状态）
