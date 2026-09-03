# Story 002：combat_system.gd 拆分

> **Epic**: file-refactor
> **Story**: 002
> **Type**: Refactor
> **Status**: Done
> **Estimate**: 1.0d

## 描述

将 combat_system.gd（1183 行）的伤害计算+攻击结算提取到 `combat_damage_calculator.gd`（RefCounted 子模块），出牌结算提取到 `combat_card_resolver.gd`（RefCounted 子模块）。主文件保留枚举/信号/状态/阶段管理/牌库/生命周期/GSM 镜像，通过薄委托方法调用子模块。

## 验收标准

| # | AC |
|---|---|
| 1 | combat_damage_calculator.gd 提取伤害计算+攻击结算（calculate_damage / _resolve_attack_queue / _get_realm_penalty） |
| 2 | combat_card_resolver.gd 提取出牌结算（play_card / _get_card_instance / _get_card_cost / _can_afford / _spend / _resolve_targets / _validate_targets / _resolve_effects / _check_and_process_deaths / _remove_card_from_hand） |
| 3 | 主文件通过薄委托方法调用子模块 |
| 4 | 全量测试零回归 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/combat_system.gd` | 主文件 1183→1061 行，薄委托 |
| `src/feature/combat/combat_damage_calculator.gd` | 伤害计算 83 行 |
| `src/feature/combat/combat_card_resolver.gd` | 出牌结算 185 行 |
