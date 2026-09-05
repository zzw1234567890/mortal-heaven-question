# Story 003: gsm_atomic_writes.gd + formation_system.gd + deck_editing_system.gd + ending_evaluator.gd 拆分

> **Epic**: file-refactor
> **Sprint**: 8-11
> **状态**: Done
> **预估**: 3.5d

## 拆分内容

### gsm_atomic_writes.gd（921→645 行）— Sprint 8

| 提取到 `gsm_battle_writes.gd` (201 行) | 提取到 `gsm_exploration_writes.gd` (101 行) | 保留在 `gsm_atomic_writes.gd` (645 行) |
|---|---|---|
| `_set_battle_cost` / `_set_battle_status_snapshot` / `_set_battle_deployment_snapshot` / `_set_player_unavailable_characters` / `_set_battle_bindings` / `_set_battle_formation_snapshot` / `_set_battle_phase` / `_increment_battle_turn` / `_set_battle_active` / `battle_start` / `battle_end` | `set_exploration_map` / `set_exploration_position` / `add_visited_node` / `set_exploration_ap` / `update_exploration_map_state` / `clear_exploration_navigation` | 修为/资源/身份/境界/卡牌/天赋/章节写入 + 薄委托 |

- **save_load_system.gd 拆分推迟**——799 行，IO 方法被 164 处测试直接调用，拆分风险高收益低。

### formation_system.gd（682→535 行）— Sprint 9

| 提取到 `formation_serializer.gd` (134 行) | 提取到 `formation_aura.gd` (118 行) | 保留在 `formation_system.gd` (535 行) |
|---|---|---|
| `serialize_all` / `_serialize_slot` / `deserialize_all` / `_deserialize_slot` / `_validate_character_exists` / `write_snapshot_to_gsm` / `_get_gsm` | `get_aura_bonus` / `_calculate_gradient_aura` / `_get_fixed_bonus` / `_query_count_on_field` / `_get_faction_system` | 枚举/信号/部署/归属/查询/条件重判 + 薄委托 |

### deck_editing_system.gd（433→387 行）— Sprint 10

| 提取到 `deck_shop.gd` (96 行) | 提取到 `deck_summary.gd` (60 行) | 保留在 `deck_editing_system.gd` (387 行) |
|---|---|---|
| `get_delete_cost` / `execute_delete` / `get_sell_price` / `execute_sell` | `get_deck_summary` / `get_loot_options` / `get_deck_status` | 常量/状态/卡组校验/卡组操作/变更日志/战利品编排 + 薄委托 |

### ending_evaluator.gd（293→286 行）— Sprint 11

| 提取到 `ending_epilogue.gd` (93 行) | 保留在 `ending_evaluator.gd` (286 行) |
|---|---|
| `generate_epilogue` (static) / `_get_flag` (static) | `ENDING_TEMPLATES` 常量 / `evaluate` 主入口 / `_calculate_scores` / `_resolve_tie` / `_determine_variant` / `_check_run_condition` / `_get_flag` + 薄委托 |

## 验证

- formation_system: 56/56；deck_editing_system: 75/75；ending_branch_system: 30/30
- 全量测试零回归
- 无新增 Autoload
