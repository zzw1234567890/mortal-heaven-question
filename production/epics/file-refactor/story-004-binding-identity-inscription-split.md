# Story 004: binding_manager.gd + ai_system.gd + identity_selection_system.gd + inscription_system.gd 拆分

> **Epic**: file-refactor
> **Sprint**: 8-10
> **状态**: Done
> **预估**: 2.5d

## 拆分内容

### binding_manager.gd（~823→755 行）— Sprint 8

| 提取到 `binding_serializer.gd` (133 行) | 保留在 `binding_manager.gd` (755 行) |
|---|---|
| `serialize_all` / `deserialize_all` / `write_snapshot_to_gsm` / `_serialize_record` / `_deserialize_record` | 枚举/信号/三索引/查询 API/绑定生命周期 API + 薄委托 |

- `deserialize_all` 保留 `_query_card_exists` 验证 + `stack_slots` → `_card_to_character` 映射。

### identity_selection_system.gd（624→556 行）— Sprint 9

| 提取到 `identity_initializer.gd` (100 行) | 保留在 `identity_selection_system.gd` (556 行) |
|---|---|
| `create_initial_cards` / `create_initial_characters` | `IDENTITY_TEMPLATES` 常量 / 查询 API / `apply_identity` 8 步编排 / `_rollback_identity` + 薄委托 |

### inscription_system.gd（427→289 行）— Sprint 10

| 提取到 `inscription_candidates.gd` (235 行) | 保留在 `inscription_system.gd` (289 行) |
|---|---|
| `generate_candidates` (6 步权重变换管线) / `_weighted_sample_without_replacement` / `get_candidate_weights` / `Direction` 枚举 / `SUBSTAT_WEIGHTS` 权重表 | `InscribeResult` 枚举 / `inscription_cost` / `dismantle_inscription_refund` / `inscribe` / `apply_inscription` 编排 + 薄委托 |

## 验证

- binding_system: 67/67；identity_selection_system: 28/28；inscription_system: 30/30
- 全量测试零回归
- 无新增 Autoload
