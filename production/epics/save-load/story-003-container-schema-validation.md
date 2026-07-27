# Story 003: 存档容器 schema + "complete" 标记 + 完整性校验

> **Epic**: 存档/读档系统
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-07-26

## 上下文

**GDD**: `design/gdd/save-load-system.md`
**需求**: `TR-save-001`, `TR-save-002`

**管辖 ADR**: ADR-0002: 存档/读档系统 — JSON + schema_version 迁移链
**ADR 决策摘要**: 存档容器必须包含 `"complete": true` 标记作为纵深防御。容器结构：`schema_version`（int）/ `version`（String 展示用）/ `timestamp`/ `playtime_seconds`/ `meta` / `game_state`/ `complete`。完整性校验：`_validate_save_data()` 检查必须字段 + `"complete"` 标记。

**引擎**: Godot 4.6 | **风险**: MEDIUM

**控制清单规则 (Foundation 层)**:
- 必需: 存档格式必须为 JSON，以 `schema_version`（递增整数）为唯一迁移驱动字段 — ADR-0002
- 必需: 存档容器必须包含 `"complete": true` 标记作为纵深防御 — ADR-0002
- 禁止: 绝不让 `schema_version > CURRENT` 的存档静默加载 — ADR-0002

---

## 验收标准

*来自 GDD `design/gdd/save-load-system.md` 与 ADR-0002:*

- [ ] **AC-001**: `_build_save_container(serialized_gsm: Dictionary, meta: Dictionary) → Dictionary` — 构造完整的存档容器 Dictionary，包含全部 7 个顶层字段
- [ ] **AC-002**: 存档容器包含 `schema_version: int = CURRENT_SCHEMA_VERSION`（当前值为 1）
- [ ] **AC-003**: 存档容器包含 `version: String = "1.0.0"`（语义化版本，仅展示用途，不参与任何 if 判断）
- [ ] **AC-004**: 存档容器包含 `timestamp: String`（ISO-8601 UTC 格式，由 `Time.get_datetime_string_from_system()` 生成）
- [ ] **AC-005**: 存档容器包含 `playtime_seconds: int`（从 GSM 或 meta 中获取当前局已玩时间）
- [ ] **AC-006**: 存档容器包含 `meta: Dictionary`（含 `player_name`, `realm`, `chapter`, `map_name`, `deck_size`, `current_scene`, `current_scene_id`）
- [ ] **AC-007**: 存档容器包含 `game_state: Dictionary`（`GSM.serialize()` 的输出——battle/session 域已被 GSM 自动排除）
- [ ] **AC-008**: 存档容器包含 `complete: true`
- [ ] **AC-009**: `_validate_save_data(data)` — 缺失 `schema_version` 字段 → `push_error` + 返回 false
- [ ] **AC-010**: `_validate_save_data(data)` — 缺失 `game_state` 字段或 `game_state` 类型非 Dictionary → `push_error` + 返回 false
- [ ] **AC-011**: `_validate_save_data(data)` — 缺失 `complete` 字段或 `complete != true` → `push_error` + 返回 false
- [ ] **AC-012**: `_validate_save_data(data)` — 所有字段合法 → 返回 true
- [ ] **AC-013**: `_atomic_read(path)` — 完整读取流程：存在性检查 → `get_file_as_string` → `JSON.new().parse()` → 类型检查 → `_validate_save_data()` → 返回 `{result: LoadResult, data: Dictionary}`
- [ ] **AC-014**: `_atomic_read(path)` — 仅读取规范文件名（忽略 `.tmp` 和 `.bak` 文件）
- [ ] **AC-015**: `_validate_version(data)` — `data.schema_version > CURRENT_SCHEMA_VERSION` → 返回 `{error: "VERSION_MISMATCH", ...}`
- [ ] **AC-016**: `_validate_version(data)` — `data.schema_version <= CURRENT_SCHEMA_VERSION` → 返回 `{ok: true}`

---

## 实现说明

*来自 ADR-0002 实现指南:*

### 存档容器结构

```gdscript
const CURRENT_SCHEMA_VERSION: int = 1

## 构造存档容器
func _build_save_container(serialized_gsm: Dictionary, meta: Dictionary) -> Dictionary:
    return {
        "schema_version": CURRENT_SCHEMA_VERSION,
        "version": "1.0.0",
        "timestamp": Time.get_datetime_string_from_system(true),  # true = UTC
        "playtime_seconds": serialized_gsm.get("session", {}).get("playtime_seconds", 0),
        "meta": {
            "player_name": meta.get("player_name", ""),
            "realm": meta.get("realm", "炼气"),
            "chapter": meta.get("chapter", 1),
            "map_name": meta.get("map_name", ""),
            "deck_size": meta.get("deck_size", 0),
            "current_scene": meta.get("current_scene", "main_menu"),
            "current_scene_id": meta.get("current_scene_id", 0),
        },
        "game_state": serialized_gsm,
        "complete": true,
    }
```

### 完整性校验

```gdscript
func _validate_save_data(data: Dictionary) -> bool:
    # 1. 必须字段存在性
    if not data.has("schema_version"):
        push_error("Save file missing 'schema_version' field")
        return false
    if not data.has("game_state") or typeof(data["game_state"]) != TYPE_DICTIONARY:
        push_error("Save file missing or invalid 'game_state' field")
        return false

    # 2. 完整性标记（纵深防御——原子 rename 为主策略）
    if not data.has("complete") or data["complete"] != true:
        push_error("Save file missing 'complete' marker — possible write interruption or manual corruption")
        return false

    return true
```

### 版本校验

```gdscript
func _validate_version(data: Dictionary) -> Dictionary:
    var save_schema: int = data.get("schema_version", 0)
    if save_schema > CURRENT_SCHEMA_VERSION:
        return {
            "error": "VERSION_MISMATCH",
            "save_schema": save_schema,
            "current_schema": CURRENT_SCHEMA_VERSION
        }
    return {"ok": true}
```

### 文件

| 文件 | 用途 |
|------|------|
| `src/autoload/save_load_system.gd` | 追加 `_build_save_container()`、`_validate_save_data()`、`_validate_version()`、`_atomic_read()` |
| `tests/unit/save_load/test_container_schema.gd` | 容器 schema 结构 + 完整性校验单元测试 |

---

## QA 测试用例

- **AC-001**: 容器构造完整
  - Given: `GSM.serialize()` 输出 + meta 字典 `{player_name: "test", realm: "筑基"}`
  - When: 调用 `_build_save_container(serialized_gsm, meta)`
  - Then: 返回 Dictionary，包含全部 7 个顶层键；`schema_version == 1`；`complete == true`；`meta.player_name == "test"`
  - 边界情况: meta 缺少字段 → 使用默认值填充（`get("key", default)`）

- **AC-009**: 缺失 schema_version
  - Given: `{"version": "1.0.0", "game_state": {}, "complete": true}`（无 schema_version）
  - When: 调用 `_validate_save_data(data)`
  - Then: `push_error("Save file missing 'schema_version' field")` + 返回 false

- **AC-011**: complete 标记缺失
  - Given: `{"schema_version": 1, "game_state": {}}`（无 complete 字段）
  - When: 调用 `_validate_save_data(data)`
  - Then: `push_error("Save file missing 'complete' marker...")` + 返回 false
  - 边界情况: `complete: false` → 同样拒绝

- **AC-013**: _atomic_read 完整流程
  - Given: 合法存档文件存在于 path
  - When: 调用 `_atomic_read(path)`
  - Then: 返回 `{result: SUCCESS, data: Dictionary}`，data 包含存档容器全部字段
  - 边界情况: `.tmp` 文件存在于同目录 → _atomic_read 无视之，仅读取规范文件名

- **AC-015**: 高版本拒绝
  - Given: 存档 `schema_version: 99`，`CURRENT_SCHEMA_VERSION: 1`
  - When: 调用 `_validate_version(data)`
  - Then: 返回 `{error: "VERSION_MISMATCH", save_schema: 99, current_schema: 1}`

---

## 测试证据

**Story 类型**: Integration
**需要证据**: `tests/unit/save_load/test_container_schema.gd` — 必须存在且通过
**状态**: [ ] 尚未创建

**必需测试函数**:
- `test_build_save_container_all_fields`
- `test_build_save_container_missing_meta_defaults`
- `test_validate_save_data_all_valid`
- `test_validate_save_data_missing_schema_version`
- `test_validate_save_data_missing_game_state`
- `test_validate_save_data_game_state_not_dict`
- `test_validate_save_data_missing_complete`
- `test_validate_save_data_complete_false`
- `test_atomic_read_success`
- `test_atomic_read_file_not_found`
- `test_atomic_read_corrupted_json`
- `test_validate_version_ok`
- `test_validate_version_mismatch`
- `test_atomic_read_ignores_tmp_and_bak`

---

## 依赖

- **依赖**: Story 001（JSON 引擎） + Story 002（原子写入） — 使用 `_parse_json_file()` 和 `_atomic_write()` / `_save_path()`
- **解锁**: Story 004（GSM 状态序列化/反序列化 + reconstitute_instances） + Story 005（迁移链）

## 排除范围

- ❌ `GSM.serialize()` / `GSM.deserialize()` 调用——GSM 的序列化契约在 Story 004 中实现
- ❌ `CardSystem.reconstitute_instances()` 调用——Story 004
- ❌ schema_version 迁移链执行——Story 005
- ❌ `save_game()` / `load_game()` 公共 API——整合在 Story 004 完成后
