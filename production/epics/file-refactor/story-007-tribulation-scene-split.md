# Story 007: tribulation_system.gd + scene_manager.gd 拆分

> **Epic**: file-refactor
> **Sprint**: 9-10
> **状态**: Done
> **预估**: 2.0d

## 拆分内容

### tribulation_system.gd（518→437 行）— Sprint 9

| 提取到 `tribulation_settlement.gd` (146 行) | 保留在 `tribulation_system.gd` (437 行) |
|---|---|
| `handle_success` / `handle_failure` / `calculate_lightning_damage` / `get_lightning_layers_per_turn` / `get_tribulation_boss_config` / `FAILURE_PENALTY_RATIO` / `CONSECUTIVE_FAILURE_THRESHOLD` 常量 | `TribulationState` / `TribulationType` 枚举 / 常量 / 5 个 Cat 2b 信号 / 内部状态 + `_VALID_TRANSITIONS` / `check_tribulation_ready` / `trigger_tribulation` / `cancel_tribulation` / `_set_state` / `_validate_state_transition` / `get_tribulation_status` / `_ready()` / `start_tribulation_combat` / `_build_tribulation_config` / `_on_battle_ended` / `use_tribulation_pill` + 薄委托 |

### scene_manager.gd（425→345 行）— Sprint 10

| 提取到 `scene_transition.gd` (141 行) | 保留在 `scene_manager.gd` (345 行) |
|---|---|
| `_execute_transition`（Phase 3-4-5 异步管线） / `_cleanup_on_error` / `_inject_loading_context` / `_execute_post_load` | `SceneID` / `TransitionType` 枚举 / `SCENE_PATHS` / `TRANSITION_AUDIO_PARAMS` 常量 / 内部状态 + 依赖注入 / `request_scene_change`（Phase 1-2 编排）/ 信号发射包装 / `create_fade_overlay` / `fade_out_overlay` (static) + 薄委托 |

## 验证

- tribulation_system: 94/94；scene_manager 单元: 72/72；scene_manager 集成: 47/47
- 全量测试零回归
- 无新增 Autoload
