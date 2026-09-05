# Story 002: ai_system.gd + school_system.gd + combat_system.gd + faction_system.gd 拆分

> **Epic**: file-refactor
> **Sprint**: 9-11
> **状态**: Done
> **预估**: 3.0d

## 拆分内容

### ai_system.gd（769→583 行）— Sprint 8

| 提取到 `ai_decision_engine.gd` (239 行) | 提取到 `ai_boss_phases.gd` (130 行) | 保留在 `ai_system.gd` (583 行) |
|---|---|---|
| `execute_turn` / `_decide_*` / `_evaluate_skills` / `_calculate_*` / `_select_*` / `_check_retreat` | `check_phase_transition` / `should_transition` / `do_boss_phase_transition` / `get_phase` / `check` / `transition` | 信号/常量/状态/查询 API + 薄委托 |

### school_system.gd（688→311 行）— Sprint 9

| 提取到 `school_conditions.gd` (~409 行) | 保留在 `school_system.gd` (~311 行) |
|---|---|
| `check_all_conditions` / `evaluate_condition` 分派器 + 10 个 `_eval_*` 评估器 + `_char_matches_tags` / `_is_tag_under_alignment` / `_get_tag_display_name` / `_tags_display` | `SCHOOL_LIBRARY` 常量 + `detect()` / `calculate_match()` + 查询 API + 薄委托 |

### combat_system.gd（1061→973 行）— Sprint 9

| 提取到 `combat_phase_manager.gd` (208 行) | 保留在 `combat_system.gd` (973 行) |
|---|---|
| `compute_next_phase` / `validate_transition` / `enter_phase` / `exit_phase` / `_schedule_auto_advance` / `_tick_status_effects` / `_reset_cost_for_turn` / `_clear_standby_state` / `_execute_ai_turn` / `_build_field_state` / `_get_field_characters` / `_calculate_draw_count` | 枚举/信号/生命周期/`advance_phase`/牌库/出牌 + 薄委托 |

### ai_system.gd 二次拆分（583→466 行）— Sprint 10

| 提取到 `ai_roster_factory.gd` (236 行) | 保留在 `ai_system.gd` (466 行) |
|---|---|
| `create_state` / `_create_by_id` / `create_enemy_roster` / `_assign_positions` / `_apply_difficulty_scaling` / `register_preconfigured_bindings` / `remove_enemy_bindings` | 信号/常量/模板加载/查询 API/决策引擎委托/BossPhaseMgr 委托 + 薄委托 |

### faction_system.gd（331→321 行）— Sprint 11

| 提取到 `faction_field_stats.gd` (58 行) | 保留在 `faction_system.gd` (321 行) |
|---|---|
| `is_hostile_to` / `get_alignment_relation` / `_first_major_alignment` | `FactionRelation` 枚举 / `FACTION_LIBRARY` / 查询 API / `count_on_field` / `check_condition` + 薄委托 |

## 验证

- ai_system: 101/101；school_system: 53/53；combat_system: 123/123；faction_system: 27/27
- 全量测试零回归
- 无新增 Autoload
