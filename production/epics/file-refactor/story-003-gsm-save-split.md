# Story 003：gsm_atomic_writes.gd + save_load_system.gd 拆分

> **Epic**: file-refactor
> **Story**: 003
> **Type**: Refactor
> **Status**: Done
> **Estimate**: 1.0d

## 描述

将 gsm_atomic_writes.gd（921 行）的战斗域写入方法提取到 `gsm_battle_writes.gd`（RefCounted 子模块），探索导航域写入方法提取到 `gsm_exploration_writes.gd`（RefCounted 子模块）。主文件保留修为/资源/身份/境界/卡牌/天赋/章节等写入，通过薄委托调用子模块。save_load_system.gd（799 行）因 IO 方法被 164 处测试直接调用，拆分风险高收益低，推迟到后续 Sprint。

## 验收标准

| # | AC |
|---|---|
| 1 | gsm_battle_writes.gd 提取战斗域写入（_set_battle_cost / _set_battle_status_snapshot / _set_battle_deployment_snapshot / _set_player_unavailable_characters / _set_battle_bindings / _set_battle_formation_snapshot / _set_battle_phase / _increment_battle_turn / _set_battle_active / battle_start / battle_end） |
| 2 | gsm_exploration_writes.gd 提取探索导航域写入（set_exploration_map / set_exploration_position / add_visited_node / set_exploration_ap / update_exploration_map_state / clear_exploration_navigation） |
| 3 | 主文件通过薄委托方法调用子模块 |
| 4 | 全量测试零回归 |
| 5 | save_load_system.gd 拆分推迟（附理由） |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/foundation/gsm/gsm_atomic_writes.gd` | 主文件 921→645 行，薄委托 |
| `src/foundation/gsm/gsm_battle_writes.gd` | 战斗域写入 201 行 |
| `src/foundation/gsm/gsm_exploration_writes.gd` | 探索域写入 101 行 |
