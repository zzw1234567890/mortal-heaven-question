# Story 005: schema_version 迁移链 + VERSION_MISMATCH 拒绝

> **Epic**: 存档/读档系统
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-26

## 上下文

**GDD**: `design/gdd/save-load-system.md`
**需求**: `TR-save-002`

**管辖 ADR**: ADR-0002: 存档/读档系统 — JSON + schema_version 迁移链
**ADR 决策摘要**: `schema_version`（递增整数）为唯一迁移驱动字段。`version`（语义化字符串）仅用于 UI 展示，不参与任何 `if` 判断。迁移链为纯函数 `Dictionary → Dictionary` 的注册表。`save_schema > CURRENT` → 拒绝加载，返回 VERSION_MISMATCH。

**引擎**: Godot 4.6 | **风险**: MEDIUM

**控制清单规则 (Foundation 层)**:
- 必需: 存档格式必须为 JSON，以 `schema_version`（递增整数）为唯一迁移驱动字段 — ADR-0002
- 必需: 使用 `JSON.new().parse()` —— 绝不使用 `JSON.parse_string()` — ADR-0002
- 禁止: 绝不让 `schema_version > CURRENT` 的存档静默加载 — 拒绝并返回 VERSION_MISMATCH — ADR-0002

---

## 验收标准

*来自 GDD `design/gdd/save-load-system.md` 与 ADR-0002:*

- [ ] **AC-001**: `CURRENT_SCHEMA_VERSION = 1`（项目初始值）——常量定义在 `SaveLoadSystem` 中
- [ ] **AC-002**: `MIGRATIONS: Dictionary[int, Callable]` 注册表——初始为空 `{}`；首次需要升级时追加条目。每条项是纯函数 `Dictionary → Dictionary`
- [ ] **AC-003**: `_migrate_if_needed(data)` — `save_schema == CURRENT` → 直接返回 data（无迁移）
- [ ] **AC-004**: `_migrate_if_needed(data)` — `save_schema < CURRENT` → 从 `save_schema` 开始逐级执行迁移函数，每步后 `data["schema_version"]` 递增 1，直到等于 `CURRENT`
- [ ] **AC-005**: `_migrate_if_needed(data)` — 迁移链中缺少某个版本对应的函数（`MIGRATIONS.has(save_schema) == false`） → 返回 `{error: "MIGRATION_MISSING", from: save_schema}`
- [ ] **AC-006**: `_migrate_if_needed(data)` — `save_schema > CURRENT` → 返回 `{error: "VERSION_MISMATCH", save_schema: N, current_schema: CURRENT}`
- [ ] **AC-007**: `_migrate_if_needed(data)` — `data` 中无 `schema_version` 字段 → `save_schema = 0`（默认值），触发从 0→1 的迁移链（当 v0→v1 迁移函数被注册时）
- [ ] **AC-008**: 迁移函数签名统一：`func _migrate_vX_to_vY(data: Dictionary) -> Dictionary`——纯函数，无副作用，不访问 GSM，不读写磁盘
- [ ] **AC-009**: 迁移函数测试：创建历史 schema 的 fixture JSON 文件 → `_atomic_read()` → `_migrate_if_needed()` → 断言输出 Dictionary 与预期一致；`data["schema_version"]` 等于 `CURRENT_SCHEMA_VERSION`
- [ ] **AC-010**: 迁移链执行前/后 `load_game()` 流程——读档时自动执行迁移，对调用方透明（Story 004 集成点）
- [ ] **AC-011**: `save_game()` 总是以 `CURRENT_SCHEMA_VERSION` 写入——新存档的 `schema_version` 始终为当前值

---

## 实现说明

*来自 ADR-0002 实现指南:*

### 迁移链架构

```gdscript
## 当前 schema 版本——每次数据格式变更（新增必填字段、键重命名、结构变更）时递增 1
const CURRENT_SCHEMA_VERSION: int = 1

## 迁移函数注册表——键：迁移前的 schema_version，值：迁移函数
## 每个函数是纯函数 Dictionary → Dictionary
## 首次需要升级时追加条目：
##   1: _migrate_v1_to_v2,  # 例如：card_instance 新增 breakthrough_layers 字段
##   2: _migrate_v2_to_v3,  # 例如：story_flags 从 Array 改为 Dictionary
const MIGRATIONS: Dictionary[int, Callable] = {
  # 当前为初始 schema——无迁移。首次升级时取消下面注释：
  # 1: _migrate_v1_to_v2,
}

## 迁移入口——从 from_ver 链接迁移到 CURRENT
func _migrate_if_needed(data: Dictionary) -> Dictionary:
    var save_schema: int = data.get("schema_version", 0)

    # 版本高于当前——拒绝
    if save_schema > CURRENT_SCHEMA_VERSION:
        return {
            "error": "VERSION_MISMATCH",
            "save_schema": save_schema,
            "current_schema": CURRENT_SCHEMA_VERSION
        }

    # 逐级执行迁移链
    while save_schema < CURRENT_SCHEMA_VERSION:
        if not MIGRATIONS.has(save_schema):
            return {
                "error": "MIGRATION_MISSING",
                "from": save_schema
            }
        data = MIGRATIONS[save_schema].call(data)
        save_schema += 1
        data["schema_version"] = save_schema

    return data
```

### 未来迁移函数示例（首次升级时参考）

```gdscript
## 示例：v1 → v2 迁移——card_instance 新增 breakthrough_layers 字段
func _migrate_v1_to_v2(data: Dictionary) -> Dictionary:
    var gs: Dictionary = data["game_state"]
    var collection: Dictionary = gs.get("collection", {})
    var owned_cards: Array = collection.get("owned_cards", [])

    for card_dict in owned_cards:
        if not card_dict.has("breakthrough_layers"):
            card_dict["breakthrough_layers"] = []

    return data

## 示例：v2 → v3 迁移——story_flags 从 Array 改为 Dictionary
func _migrate_v2_to_v3(data: Dictionary) -> Dictionary:
    var gs: Dictionary = data["game_state"]
    var narrative: Dictionary = gs.get("narrative", {})
    var flags = narrative.get("story_flags", [])

    if typeof(flags) == TYPE_ARRAY:
        var flag_dict: Dictionary = {}
        for flag in flags:
            flag_dict[flag] = true
        narrative["story_flags"] = flag_dict

    return data
```

### 版本兼容性矩阵

| 条件 | 处理方式 | LoadResult |
|------|---------|------------|
| `save_schema > CURRENT` | **拒绝加载** | `VERSION_MISMATCH` |
| `save_schema < CURRENT` | **迁移后加载** | `SUCCESS`（若迁移成功） |
| `save_schema == CURRENT` | **直接加载** | `SUCCESS`（若解析成功） |

### 文件

| 文件 | 用途 |
|------|------|
| `src/autoload/save_load_system.gd` | 追加 `_migrate_if_needed()` + `MIGRATIONS` 注册表 + 未来的迁移函数 |
| `tests/unit/save_load/test_migration_chain.gd` | 迁移链单元测试 + fixture 文件 |
| `tests/fixtures/save_load/` | 各历史 schema_version 的测试 fixture JSON 文件 |

---

## QA 测试用例

- **AC-003**: 同版本无迁移
  - Given: 存档 `schema_version: 1`，`CURRENT_SCHEMA_VERSION: 1`
  - When: 调用 `_migrate_if_needed(data)`
  - Then: 返回原始 data（无修改），无迁移函数被调用
  - 边界情况: `data["schema_version"]` 仍为 1

- **AC-004**: 迁移链执行（模拟 v0→v1）
  - Given: `CURRENT_SCHEMA_VERSION = 2`，`MIGRATIONS = {1: _migrate_v1_to_v2}`，存档 `schema_version: 1`
  - When: 调用 `_migrate_if_needed(data)`
  - Then: `_migrate_v1_to_v2.call(data)` 被调用一次 → 返回修改后的 data → `data["schema_version"] == 2`
  - 边界情况: 多步迁移 v0→v1→v2，注册表有 `{0: m0, 1: m1}` → 两个函数依次调用

- **AC-005**: 迁移缺失
  - Given: `CURRENT_SCHEMA_VERSION = 3`，存档 `schema_version: 1`，`MIGRATIONS` 仅含 `{2: _migrate_v2_to_v3}`（缺少 `1: _migrate_v1_to_v2`）
  - When: 调用 `_migrate_if_needed(data)`
  - Then: 返回 `{error: "MIGRATION_MISSING", from: 1}`
  - 边界情况: 空 MIGRATIONS → save_schema=0, CURRENT=1 → MIGRATION_MISSING

- **AC-006**: 高版本拒绝
  - Given: `CURRENT_SCHEMA_VERSION = 1`，存档 `schema_version: 99`
  - When: 调用 `_migrate_if_needed(data)`
  - Then: 返回 `{error: "VERSION_MISMATCH", save_schema: 99, current_schema: 1}`
  - 边界情况: `data` 无 `schema_version` 字段 → `save_schema = 0` → `0 <= 1` → 触发 0→1 迁移（不拒绝）

- **AC-009**: Fixture 文件迁移测试
  - Given: `tests/fixtures/save_load/v1_fixture.json` 含 `schema_version: 1` 的存档快照；`CURRENT_SCHEMA_VERSION = 1`
  - When: 加载 → `_migrate_if_needed()` → 断言输出
  - Then: 迁移后 `data["schema_version"] == CURRENT_SCHEMA_VERSION`；所有必需字段存在；数据结构符合当前 schema
  - 边界情况: 每新增一个迁移函数时，追加对应 fixture 文件。CI 中所有 fixture 文件的迁移测试必须通过

---

## 测试证据

**Story 类型**: Logic
**需要证据**: `tests/unit/save_load/test_migration_chain.gd` — 必须存在且通过
**状态**: [ ] 尚未创建

**必需测试函数**:
- `test_migrate_if_needed_same_version_noop`
- `test_migrate_if_needed_single_step`
- `test_migrate_if_needed_multi_step`
- `test_migrate_if_needed_migration_missing`
- `test_migrate_if_needed_version_mismatch_rejected`
- `test_migrate_if_needed_missing_schema_version_defaults_to_zero`
- `test_migrate_v1_to_v2_fixture`（首次升级时取消注释）
- `test_save_game_writes_current_schema_version`
- `test_load_game_executes_migration_transparently`
- `test_migration_failure_in_chain_is_isolated`

---

## 依赖

- **依赖**: Story 001（JSON 引擎）+ Story 003（容器 schema / `_validate_version()`）— 使用 `_atomic_read()` 和 `CURRENT_SCHEMA_VERSION` 常量
- **依赖**: Story 004（公共 API / `load_game()`）— 集成点：`load_game()` 在第 3 步调用 `_migrate_if_needed()`
- **解锁**: 后续格式升级——当游戏 format 需要新增必填字段、重命名键或变更结构时，在此注册新迁移函数

## 排除范围

- ❌ 实际的迁移函数实现（`_migrate_v1_to_v2` 等）——当前 `CURRENT_SCHEMA_VERSION=1`，无迁移需求。函数仅在首次升级时追加
- ❌ GSM 状态序列化/反序列化（Story 004）
- ❌ 自动存档防抖 + 战斗快照生命周期自动触发（后续 Story）
- ❌ `version` 字符串的管理规则——`version` 仅用于 UI 展示，不参与任何逻辑判断