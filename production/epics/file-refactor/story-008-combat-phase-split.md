# Story 008: combat_system.gd 阶段管理深拆

> **Epic**: file-refactor
> **Sprint**: 9
> **状态**: Done
> **预估**: 1.5d

## 拆分内容

### combat_system.gd（1061→973 行）

| 提取到 `combat_phase_manager.gd` (208 行) | 保留在 `combat_system.gd` (973 行) |
|---|---|
| `compute_next_phase` / `validate_transition` / `enter_phase` / `exit_phase` / `_schedule_auto_advance` / `_tick_status_effects` / `_reset_cost_for_turn` / `_clear_standby_state` / `_execute_ai_turn` / `_build_field_state` / `_get_field_characters` / `_calculate_draw_count` | `CombatPhase` / `CombatResult` 枚举 / 6 个 Cat 2b 信号 / 内部状态字段 / 生命周期（`battle_start` / `battle_end` / `retreat`）/ `advance_phase` 核心推进 / 手动确认 API / 牌库管理 / 出牌结算委托 / 攻击结算 + 伤害计算委托 / Autoload 查找 + GSM 镜像 / `_emit_safe` + 薄委托 |

## 架构特点

- **持有 `_parent` 引用**：子模块通过 `_parent.get()` / `_parent.set()` / `_parent.call()` / `_parent.call_deferred()` 访问父节点。
- **枚举值常量化**：子模块自带 `PHASE_PREPARATION` ~ `PHASE_END` 枚举值常量。
- **惰性初始化**：`_get_phase_manager()` → `preload(...).new(self)`。
- **`advance_phase` 保留**：核心推进逻辑与内部状态紧耦合，保留在主文件。

## 验证

- combat_system: 123/123
- 全量测试零回归（143 scripts / 2455 tests / 0 failing）
- 无新增 Autoload
