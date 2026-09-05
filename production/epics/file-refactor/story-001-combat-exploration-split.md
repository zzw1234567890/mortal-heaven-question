# Story 001: combat_system.gd + exploration_system.gd 拆分

> **Epic**: file-refactor
> **Sprint**: 8
> **状态**: Done
> **预估**: 2.0d

## 拆分内容

### combat_system.gd（1183→1061 行）

| 提取到 `combat_damage_calculator.gd` (83 行) | 提取到 `combat_card_resolver.gd` (185 行) | 保留在 `combat_system.gd` (1061 行) |
|---|---|---|
| `calculate_damage` / `_resolve_attack_queue` / `_get_realm_penalty` | `play_card` / `_get_card_instance` / `_get_card_cost` / `_can_afford` / `_spend` / `_resolve_targets` / `_validate_targets` / `_resolve_effects` / `_check_and_process_deaths` / `_remove_card_from_hand` | 枚举/信号/状态/阶段管理/牌库/生命周期/GSM 镜像 + 薄委托 |

### exploration_system.gd（1009→680 行）

| 提取到 `exploration_dag_builder.gd` (328 行) | 提取到 `exploration_economy.gd` (90 行) | 保留在 `exploration_system.gd` (680 行) |
|---|---|---|
| `generate_map` / `_build_edges` / `_add_cross_edges` / `_count_vertex_disjoint_paths` / `_bfs_path` / `_assign_node_types` / `_fill_node_content` | `calculate_reentry_cost` / `calculate_map_clear_rewards` / `realm_gap_penalty` / `_get_difficulty_from_config` | 枚举/常量/导航/GSM 状态管理/结算 + 薄委托 |

## 验证

- combat 单元测试：通过；exploration 单元测试：通过
- 全量测试零回归
- 无新增 Autoload
