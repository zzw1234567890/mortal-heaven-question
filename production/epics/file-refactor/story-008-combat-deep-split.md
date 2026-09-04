# Story 8：combat_system.gd 阶段管理深拆

- **Epic**: file-refactor
- **Sprint**: 9
- **状态**: Done
- **预估**: 1.5d

## 目标

将 `combat_system.gd`（1061 行）中的阶段编排逻辑（_enter_phase / _exit_phase / _validate_transition / _compute_next_phase / _schedule_auto_advance + 子系统编排辅助）提取到 `combat_phase_manager.gd` RefCounted 子模块，主文件降至 973 行。

## 拆分内容

| 提取到 `combat_phase_manager.gd` (208 行) | 保留在 `combat_system.gd` (973 行) |
|---|---|
| `compute_next_phase` | `CombatPhase` / `CombatResult` 枚举 |
| `validate_transition` | 6 个 Cat 2b 信号 |
| `enter_phase` | 内部状态字段 + 生命周期（`battle_start` / `battle_end` / `retreat`） |
| `exit_phase` | `advance_phase` 核心推进逻辑 |
| `_schedule_auto_advance` | 手动确认 API（`confirm_end_turn` / `confirm_attack_targets`） |
| `_tick_status_effects` / `_reset_cost_for_turn` / `_clear_standby_state` | 牌库管理（`_draw_cards` / `init_deck` / `discard_card` 等） |
| `_execute_ai_turn` / `_build_field_state` / `_get_field_characters` | 出牌结算（`play_card` + 薄委托） |
| `_calculate_draw_count` | 攻击结算 + 伤害计算委托 |
| | Autoload 查找 + GSM 镜像 + `_emit_safe` |
| | `_get_phase_manager()` 惰性初始化 + 薄委托 |

## 架构特点

- **持有 `_parent` 引用**：子模块通过 `_parent.get()` / `_parent.set()` / `_parent.call()` / `_parent.call_deferred()` 访问父节点状态字段和方法。
- **枚举值常量化**：子模块自带 `PHASE_PREPARATION` ~ `PHASE_END` 枚举值常量，避免依赖父节点枚举声明。
- **惰性初始化**：`_get_phase_manager()` 在首次调用时 `preload("res://src/feature/combat/combat_phase_manager.gd").new(self)`。
- **薄委托**：13 个方法保留在主文件作为薄委托（`_compute_next_phase` / `_validate_transition` / `_enter_phase` / `_exit_phase` / `_schedule_auto_advance` / `_tick_status_effects` / `_reset_cost_for_turn` / `_clear_standby_state` / `_execute_ai_turn` / `_build_field_state` / `_get_field_characters` / `_calculate_draw_count`）。测试通过 `cs.call("_draw_cards", n)` 等间接调用，`_draw_cards` 保留在主文件。
- **advance_phase 保留**：核心推进逻辑（含 GSM 镜像 + 信号发射）与内部状态紧耦合，保留在主文件。
- **preload 引用**：使用 `preload` 而非 `load`（同 Sprint 8 combat_damage_calculator / combat_card_resolver 先例）。
- **无新增 Autoload**：RefCounted 子模块。

## 风险与处理

- **风险等级**：高——combat_system.gd 是战斗核心编排器，与内部状态紧耦合。
- **处理方式**：仅提取阶段编排逻辑（enter/exit/validate/schedule + 子系统 tick/reset/clear/execute 辅助），保留 advance_phase 核心推进和所有牌库管理在主文件。修复了重复函数声明（`_calculate_draw_count` 被误留两份）。

## 验证

- combat_system 单元测试：123/123 passed
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `combat_phase_manager.gd` 子模块创建（208 行）
- [x] `combat_system.gd` 主文件修改（973 行）
- [x] 主文件保留枚举/信号/生命周期/advance_phase/牌库/出牌 + 薄委托
- [x] combat_system 单元测试全部通过（123/123）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
