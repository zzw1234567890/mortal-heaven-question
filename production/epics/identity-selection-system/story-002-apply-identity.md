# Story 002：apply_identity 原子操作（编排现有服务 API）

> **Epic**: identity-selection-system
> **Story**: 002
> **Type**: Integration
> **ADR**: ADR-0022
> **Status**: In Progress
> **Estimate**: 0.5d
> **Dependencies**: Story 001

## 描述

实现 `apply_identity(identity_id)` 原子操作——编排 CardSystem、ResourceSystem、GSM 多系统写入初始状态。验证全部前置条件后一次性写入：identity_id、灵石、初始卡牌实例、初始角色实例、天赋键值、开局叙事文本，最后发射 identity_selected 信号。

## 验收标准

| # | AC |
|---|---|
| 1 | `apply_identity(有效ID)` 返回 true |
| 2 | apply 后 `GSM.player.identity_id` 正确写入 |
| 3 | apply 后 `GSM.player.resources.ling_shi` 正确设置 |
| 4 | apply 后 `GSM.player.talent_map[talent_id]` == magnitude |
| 5 | apply 后 `deck.current_deck` 含初始卡牌实例 ID |
| 6 | apply 后 `deck.slots` 含初始角色实例 ID |
| 7 | apply 后 `narrative.story_flags.opening_text` 写入 flavor_text |
| 8 | apply 后 `identity_selected` 信号已发射 |
| 9 | `apply_identity(无效ID)` 返回 false，GSM 不变 |
| 10 | `apply_identity(未解锁ID)` 返回 false，GSM 不变 |
| 11 | ResourceSystem 失败时 identity_id 回滚为空 |

## 实现文件

| 文件 | 说明 |
|------|------|
| `src/feature/identity_selection_system.gd` | apply_identity + _create_initial_cards + _create_initial_characters |
| `src/foundation/gsm/gsm_atomic_writes.gd` | 新增 set_talent 第二层方法 |
| `src/foundation/gsm/gsm_serializer.gd` | player 默认值新增 talent_map 字段 |
| `src/foundation/game_state_manager.gd` | 新增 set_talent 薄转发 |
| `src/core/card_system/card_system.gd` | 新增 has_template 便捷方法 |
| `tests/unit/identity_selection_system/test_apply_identity.gd` | 11 条 AC 测试 |
| `tests/unit/identity_selection_system/card_system_mock.gd` | CardSystem 测试替身 |
| `tests/unit/identity_selection_system/resource_mock.gd` | ResourceSystem 测试替身 |

## GDD 来源

- `design/gdd/identity-selection-system.md` §3 身份选择流程、§公式#1 天赋效果注册
- ADR-0022 §apply_identity 8 步原子操作序列