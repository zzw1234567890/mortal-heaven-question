# Story 003：BarkManager + play_bark + get_bark_history

> **Epic**: dialogue-system
> **Story**: 003
> **Type**: Logic
> **ADR**: ADR-0027
> **Status**: Done
> **Estimate**: 0.5d

## 描述

实现 BarkManager RefCounted 服务类——bark（短对话气泡）的播放编排。核心功能：bark 池管理（每角色一个 bark 池，触发时随机抽取，同一局不重复，池耗尽后重置并选择与上一句不同的 bark）、play_bark 触发播放、get_bark_history 查询历史记录。BarkManager 为 RefCounted 服务类（ADR-0027），不注册 Autoload。

## 验收标准

| # | AC |
|---|---|
| 1 | BarkManager 实例化后持有 bark 池字典（_bark_pools: Dict[character_id → Array[String]]） |
| 2 | register_bark_pool("lin_yuan", ["文本A", "文本B", "文本C"]) 注册角色 bark 池 |
| 3 | play_bark("lin_yuan") 从池中随机抽取一条 bark 文本返回 |
| 4 | 连续 play_bark("lin_yuan") 5 次（池大小=3），前 3 次各不相同 |
| 5 | 池耗尽后第 4 次 play_bark 重置池并选择与上一句不同的 bark |
| 6 | play_bark 后发射 bark_played(character_id, text) 信号 |
| 7 | get_bark_history() 返回已播放记录列表（含 character_id + text + 顺序） |
| 8 | play_bark 未注册角色返回空字符串，不崩溃 |
| 9 | 空池角色 play_bark 返回空字符串，不崩溃 |
| 10 | BarkManager 为 RefCounted（非 Node），通过 new() 实例化 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/dialogue/bark_manager.gd` | BarkManager RefCounted |
| `tests/unit/dialogue_system/test_bark_manager.gd` | 10 条 AC 测试 |

## GDD 来源

- GDD dialogue-system.md §7 bark 池机制、§5 边缘情况（bark池耗尽）、§6 验收标准（bark 不重复+重置）
- ADR-0027 §决策 5（BarkManager RefCounted）
