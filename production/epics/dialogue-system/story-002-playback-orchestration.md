# Story 002：start_dialogue / select_option / advance 播放编排

> **Epic**: dialogue-system
> **Story**: 002
> **Type**: Logic
> **ADR**: ADR-0027
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 DialoguePlayer 的播放编排——条件可见性判定（ConditionEvaluator 内部类，10 种条件类型）、选项条件灰色显示 + 提示、outcomes 收集 + 委托 EventSystem.set_flag 写入、对话开始/结束信号、allow_skip 跳过逻辑、end_action 触发。

## 验收标准

| # | AC |
|---|---|
| 1 | start_dialogue 后发射 dialogue_started(tree_id) 信号 |
| 2 | select_option("resist") 返回 outcomes 列表 |
| 3 | select_option 后推进到选项的 next_node |
| 4 | 条件可见性：story_flag=true 的节点可见，false 的节点跳过 |
| 5 | 选项条件不满足时返回 {visible: false, reason: ...} |
| 6 | advance 到无 next_node 的节点发射 dialogue_finished 信号 |
| 7 | allow_skip=true 时 skip() 直接跳到 end_action |
| 8 | select_option 的 outcomes 中 set_flag 委托 EventSystem.set_flag |
| 9 | 对话结束后 get_end_action() 返回 end_action 字符串 |
| 10 | 条件 always=true 的节点始终可见 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/dialogue/dialogue_player.gd` | 播放编排 + 条件评估 |
| `tests/unit/dialogue_system/test_playback_orchestration.gd` | 10 条 AC 测试 |

## GDD 来源

- GDD dialogue-system.md §3 条件系统、§4 对话播放引擎
- ADR-0027 §决策 4（条件评估器嵌入 DialoguePlayer）
