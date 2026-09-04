# Story 7：tribulation_system.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 9
- **状态**: Done
- **预估**: 1.0d

## 目标

将 `tribulation_system.gd`（518 行）中的成功/失败结算 + 雷伤纯函数 + Boss 配置查询提取到 `tribulation_settlement.gd` RefCounted 子模块，主文件降至 437 行。

## 拆分内容

| 提取到 `tribulation_settlement.gd` (146 行) | 保留在 `tribulation_system.gd` (437 行) |
|---|---|
| `handle_success` | `TribulationState` / `TribulationType` 枚举 |
| `handle_failure` | 常量（`MAX_TRIBULATION_PILLS` 等） |
| `calculate_lightning_damage` | 5 个 Cat 2b 信号 |
| `get_lightning_layers_per_turn` | 内部状态 + `_VALID_TRANSITIONS` 白名单 |
| `get_tribulation_boss_config` | `check_tribulation_ready` / `trigger_tribulation` |
| `FAILURE_PENALTY_RATIO` / `CONSECUTIVE_FAILURE_THRESHOLD` 常量 | `cancel_tribulation` / `_set_state` / `_validate_state_transition` |
| | `get_tribulation_status` 查询 |
| | `_ready()` / `start_tribulation_combat` / `_build_tribulation_config` / `_on_battle_ended` |
| | `use_tribulation_pill` 渡劫丹管理 |
| | `_emit_safe` / `_get_gsm` / `_get_combat_system` / `_get_realm_system` |
| | `_get_settlement()` 惰性初始化 + 薄委托 |

## 架构特点

- **持有 `_parent` 引用**：子模块通过 `_parent.call("_get_gsm")` / `_parent.call("_set_state", ...)` / `_parent.call("_emit_safe", ...)` / `_parent.call("_get_realm_system")` 访问父节点状态和方法。
- **枚举值常量化**：子模块自带 `_STATE_SUCCESS` / `_STATE_FAILED` / `_TYPE_NORMAL` / `_TYPE_CROSS_REALM` 等枚举值常量，避免依赖父节点枚举声明。
- **惰性初始化**：`_get_settlement()` 在首次调用时 `load("res://src/feature/tribulation/tribulation_settlement.gd").new(self)`。
- **薄委托**：`_handle_tribulation_success` / `_handle_tribulation_failure` / `calculate_lightning_damage` / `get_lightning_layers_per_turn` / `get_tribulation_boss_config` 保留在主文件作为薄委托。测试通过 `ts.call("_handle_tribulation_success")` 等间接调用。
- **无新增 Autoload**：RefCounted 子模块。

## 验证

- tribulation_system 单元测试：94/94 passed
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `tribulation_settlement.gd` 子模块创建（146 行）
- [x] `tribulation_system.gd` 主文件修改（437 行）
- [x] 主文件保留枚举/信号/状态机/触发/战斗委托 + 薄委托
- [x] tribulation_system 单元测试全部通过（94/94）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
