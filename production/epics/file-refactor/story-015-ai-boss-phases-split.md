# Story 015: ai_system.gd 拆分——决策辅助方法提取

> **Epic**: file-refactor
> **Sprint**: 12
> **层级**: Feature
> **类型**: Refactor
> **状态**: Done
> **清单版本**: 2026-08-05
> **创建日期**: 2026-09-05
> **完成日期**: 2026-09-05

## 概述

将 `ai_system.gd`（466 行）中的 7 个决策引擎辅助方法提取到 `src/feature/ai/ai_helpers.gd` 纯 static 子模块，并清理主文件中无人调用的决策引擎薄委托（12 个），主文件降至 ~360 行。

## 技术需求

- **TR-ID**: TR-ai（敌方 AI 决策）
- **治理 ADR**: ADR-0017（AISystem）

## 验收标准

- [x] `ai_helpers.gd` 子模块包含 7 个 static 辅助方法（get_behavior_profile / is_alive / is_on_cooldown / get_hp_pct / is_attack_skill_by_target_type / find_taunting / compare_by_score_desc）
- [x] `ai_decision_engine.gd` 与 `ai_boss_phases.gd` 中 13 处 `_parent.call()` 辅助调用改为直接 `_Helpers.xxx()` static 调用
- [x] `ai_system.gd` 保留 6 个辅助方法薄委托（兼容测试动态分派）+ `_check_phase_transition` 委托（决策引擎经 `_parent.call` 调用）
- [x] 清理主文件 12 个无人调用的决策引擎薄委托（_decide_action/_decide_normal/_decide_elite/_decide_boss/_evaluate_skills/_calculate_skill_score/_calculate_modifier/_select_target/_select_focus_fire/_select_spread/_check_retreat/_should_transition/_do_boss_phase_transition）
- [x] 全量测试零回归：143 scripts / 2455 tests / 0 failing
- [x] 不新增 Autoload

## 拆分内容

| 提取到 `ai_helpers.gd`（static） | 保留在 `ai_system.gd` |
|---|---|
| 7 个辅助方法 static 化 | 模板注册/加载、EnemyFactory/阵位/缩放/绑定委托、决策引擎+BossPhases+RosterFactory 惰性获取、6 个辅助薄委托、_emit_safe |

## 教训

- **首次清理移除 `_check_phase_transition` 导致 5 个测试失败**——`ai_decision_engine._decide_boss_action` 经 `_parent.call("_check_phase_transition", ...)` 动态分派回主文件，静态 grep（`_parent\.` 模式）未覆盖决策引擎内的调用。恢复委托后零回归。动态分派链路必须用 `call("方法名")` 全文搜索确认。
- **决策引擎薄委托可安全移除**（测试经 `execute_turn` 公共入口），但 `_parent.call` 回调方法不可移除。

## 范围外

- 不修改 `ai_decision_engine.gd` / `ai_boss_phases.gd` / `ai_roster_factory.gd` 的业务逻辑
- 不修改信号声明
- 不拆 `enemy_battle_state.gd`（64 行，无需拆分）

## 变更文件

- `src/feature/ai/ai_helpers.gd` — 新增（~60 行）
- `src/feature/ai/ai_decision_engine.gd` — 修改（239→236 行，_parent.call → _Helpers static）
- `src/feature/ai/ai_boss_phases.gd` — 修改（130→132 行，同上）
- `src/feature/ai_system.gd` — 修改（466→~360 行）
