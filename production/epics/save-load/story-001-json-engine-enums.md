# Story 001: JSON 序列化引擎 + SaveResult/LoadResult 枚举

> **Epic**: 存档/读档系统
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-07-26

## 上下文

**GDD**: `design/gdd/save-load-system.md`
**需求**: `TR-save-001`

**管辖 ADR**: ADR-0002: 存档/读档系统 — JSON + schema_version 迁移链
**ADR 决策摘要**: 存档格式为 JSON，使用 `JSON.new().parse()` 而非 `JSON.parse_string()`，通过 Error 返回值区分合法 null 和解析错误。JSON.stringify 使用 `"\t"` 缩进输出人类可读文件。

**引擎**: Godot 4.6 | **风险**: MEDIUM

**控制清单规则 (Foundation 层)**:
- 必需: 使用 `JSON.new().parse()` —— 绝不使用 `JSON.parse_string()`（无法区分合法 null 和解析错误）— ADR-0002
- 禁止: 绝不使用 `JSON.parse_string()` 读取存档 — ADR-0002
- 护栏: 存档 I/O: <50ms SSD / <100ms HDD 每次写入 — ADR-0002

---

## 验收标准

*来自 GDD `design/gdd/save-load-system.md` 与 ADR-0002:*

- [ ] **AC-001**: `SaveResult` 枚举完整定义：`SUCCESS`, `DISK_FULL`, `WRITE_ERROR`, `VALIDATION_ERROR`
- [ ] **AC-002**: `LoadResult` 枚举完整定义：`SUCCESS`, `FILE_NOT_FOUND`, `CORRUPTED`, `VERSION_MISMATCH`, `DESERIALIZE_ERROR`
- [ ] **AC-003**: `SaveSlotType` 枚举完整定义：`AUTOSAVE`, `MANUAL`, `SNAPSHOT`
- [ ] **AC-004**: `JSON.new().parse(raw_string)` 解析合法 JSON → 返回 `{result: SUCCESS, data: Dictionary}`
- [ ] **AC-005**: `JSON.new().parse("不是json")` 解析非法字符串 → `err != OK`，返回 `{result: CORRUPTED, data: {}}`
- [ ] **AC-006**: `JSON.new().parse("null")` 解析 JSON null 值 → `err == OK` 且 `json.get_data() == null`，`typeof(data) != TYPE_DICTIONARY` → 返回 `{result: CORRUPTED}`
- [ ] **AC-007**: 合法 JSON 但顶层非 Object（如 `[1, 2, 3]` 数组） → `typeof(data) != TYPE_DICTIONARY` → 返回 `{result: CORRUPTED}`
- [ ] **AC-008**: `JSON.stringify(data, "\t")` 输出格式化 JSON（含制表符缩进），data 为深层嵌套 Dictionary → 输出合法 JSON 字符串
- [ ] **AC-009**: `FileAccess.file_exists(path)` → 文件不存在时返回 false；文件存在时返回 true
- [ ] **AC-010**: `FileAccess.get_file_as_string(path)` 读取完整文件内容 → 返回 String
- [ ] **AC-011**: JSON 序列化往返：`data` Dictionary → `JSON.stringify()` → `JSON.new().parse()` → `json.get_data()` → 与原始 data 深度相等

---

## 实现说明

*来自 ADR-0002 实现指南:*

### JSON 解析路径（强制使用 JSON.new().parse()）

```gdscript
## ⚠️ 正确方式——检查 Error 返回值区分"合法 null"和"解析错误"
func _parse_json_file(path: String) -> Dictionary:
    if not FileAccess.file_exists(path):
        return {"result": LoadResult.FILE_NOT_FOUND, "data": {}}

    var raw: String = FileAccess.get_file_as_string(path)
    var json := JSON.new()
    var err := json.parse(raw)
    if err != OK:
        push_error("Save file parse error at line %d: %s" % [json.get_error_line(), json.get_error_message()])
        return {"result": LoadResult.CORRUPTED, "data": {}}

    var data = json.get_data()
    if typeof(data) != TYPE_DICTIONARY:
        return {"result": LoadResult.CORRUPTED, "data": {}}

    return {"result": LoadResult.SUCCESS, "data": data}

## ❌ 禁止使用 JSON.parse_string()——对 null 合法值和解析错误均返回 null，无法区分
```

### 枚举定义

```gdscript
enum SaveSlotType { AUTOSAVE, MANUAL, SNAPSHOT }
enum SaveResult { SUCCESS, DISK_FULL, WRITE_ERROR, VALIDATION_ERROR }
enum LoadResult { SUCCESS, FILE_NOT_FOUND, CORRUPTED, VERSION_MISMATCH, DESERIALIZE_ERROR }
```

### 文件

| 文件 | 用途 |
|------|------|
| `src/autoload/save_load_system.gd` | SaveLoadSystem Autoload #4 — 枚举定义 + `_parse_json_file()` + `_serialize_to_json()` |
| `tests/unit/save_load/test_json_engine.gd` | JSON 序列化/反序列化单元测试 |

### 引擎特定注意事项

- `FileAccess.store_string()` 在 Godot 4.4+ 返回 `bool`（破坏性变更——原返回 `void`）。必须检查返回值。但本 Story 仅实现 JSON 序列化/反序列化，写入操作在 Story 002 实现
- `JSON.new()` 在 Godot 4.x 中为标准 API；无需 `RefCounted` 包装——创建后直接使用
- `JSON.stringify()` 第二个参数为缩进字符串；Godot 4.6 中保留 `"\t"` 参数

---

## QA 测试用例

- **AC-004**: 合法 JSON 文件解析
  - Given: 文件包含 `{"schema_version": 1, "game_state": {}, "complete": true}`
  - When: 调用 `_parse_json_file(path)`
  - Then: 返回 `{result: SUCCESS, data: Dictionary}`，`data.schema_version == 1`
  - 边界情况: 空字典 `{}` → 合法，result=SUCCESS

- **AC-005**: 非法 JSON 解析
  - Given: 文件包含 `{broken json!!!`
  - When: 调用 `_parse_json_file(path)`
  - Then: 返回 `{result: CORRUPTED, data: {}}`
  - 边界情况: 空文件 → CORRUPTED

- **AC-006**: JSON null vs 解析错误区分
  - Given: 文件包含字面量 `null`
  - When: 调用 `_parse_json_file(path)`
  - Then: `json.parse(raw)` 返回 OK（Godot 4.x 行为）；`json.get_data()` 返回 `null`；由于 `typeof(null) != TYPE_DICTIONARY`，返回 CORRUPTED
  - 边界情况: 如果使用 `JSON.parse_string()` → 对 `null` 和非法 JSON 均返回 null——无法区分。本 Story 禁止使用

- **AC-011**: 往返一致性
  - Given: 深层嵌套 Dictionary（模拟 game_state 结构，含 int/float/String/bool/null/Array/Dictionary）
  - When: `_serialize_to_json(data)` → 写入 → `_parse_json_file()` → 读取
  - Then: 读出的 Dictionary 与原始 data 深度相等
  - 边界情况: 包含特殊浮点值（NaN, INF）——JSON 不原生支持，Godot 行为需验证

---

## 测试证据

**Story 类型**: Logic
**需要证据**: `tests/unit/save_load/test_json_engine.gd` — 必须存在且通过
**状态**: [ ] 尚未创建

**必需测试函数**:
- `test_parse_valid_json_file`
- `test_parse_invalid_json_returns_corrupted`
- `test_parse_null_json_returns_corrupted`
- `test_parse_array_json_returns_corrupted`
- `test_parse_file_not_found`
- `test_serialize_json_stringify`
- `test_roundtrip_nested_dictionary`
- `test_enums_defined`

---

## 依赖

- **依赖**: GSM (Autoload #1) 必须已存在——SaveLoadSystem 通过 `GSM.serialize()` / `GSM.deserialize()` 接口读写状态
- **解锁**: Story 002（原子写入策略 + Windows 重试）

---

## 排除范围

- ❌ 文件写入/读取的原子性策略（Story 002）
- ❌ 存档容器的 schema 定义（Story 003）
- ❌ GSM 状态序列化/反序列化调用（Story 004）
- ❌ schema_version 迁移链逻辑（Story 005）
- ❌ 自动存档防抖、战斗快照生命周期、信号连接（后续 Story）