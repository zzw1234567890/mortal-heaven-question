# Story 3：formation_system.gd 拆分

- **Epic**: file-refactor
- **Sprint**: 9
- **状态**: Done
- **预估**: 1.0d

## 目标

将 `formation_system.gd`（682 行）中的序列化/光环查询逻辑提取到两个 RefCounted 子模块，主文件降至 535 行。

## 拆分内容

| 提取到 `formation_serializer.gd` (134 行) | 提取到 `formation_aura.gd` (118 行) | 保留在 `formation_system.gd` (535 行) |
|---|---|---|
| `serialize_all` / `_serialize_slot` | `get_aura_bonus` | 枚举 `SlotState` / `AuraScope` |
| `deserialize_all` / `_deserialize_slot` | `_calculate_gradient_aura` | 6 个 Cat 2b 信号 |
| `_validate_character_exists` | `_get_fixed_bonus` | `deploy_formation` / `overwrite_formation` |
| `write_snapshot_to_gsm` / `_get_gsm` | `_query_count_on_field` / `_get_faction_system` | 归属管理 + 查询 API |
| | | `recheck_all_conditions` / `_on_field_changed` |
| | | `_check_condition` / `_clear_affiliations_by_formation` |
| | | `_get_slot_by_formation` / `_find_empty_slot` |
| | | `_emit_safe` / `_invoke_cb` / `_clear_all` |
| | | `clear_all_formations` + 薄委托 |

## 架构特点

- **持有 `_parent` 引用**：两个子模块均持有 `_parent: Node` 引用，通过 `_parent.get()` / `_parent.call()` / `_parent.set()` 访问父节点状态。
- **惰性初始化**：`_get_serializer()` 和 `_get_aura()` 在首次调用时 `load(...).new(self)`。
- **保留原因**：`recheck_all_conditions` 和 `_on_field_changed` 被 6+ 处测试直接调用，且与内部状态紧耦合，保留在主文件。
- **无新增 Autoload**：RefCounted 子模块。

## 验证

- formation_system 单元测试：56/56 passed
- 全量测试：143 scripts / 2455 tests / 2454 passing / 1 pending / 0 failing / 9195 asserts
- 零回归 ✓

## 完成定义

- [x] `formation_serializer.gd` 子模块创建（134 行）
- [x] `formation_aura.gd` 子模块创建（118 行）
- [x] `formation_system.gd` 主文件修改（535 行）
- [x] 主文件保留枚举/信号/部署/归属/查询/条件重判 + 薄委托
- [x] formation_system 单元测试全部通过（56/56）
- [x] 全量测试零回归（2455 tests / 0 failing）
- [x] 无新增 Autoload
