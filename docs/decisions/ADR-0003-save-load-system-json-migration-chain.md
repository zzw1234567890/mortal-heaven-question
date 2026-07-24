# ADR-0003：存档/读档系统 — JSON 格式 + 迁移链 + 原子写入

## 状态
Proposed

## 日期
2026-07-24

## 引擎兼容性

| 字段 | 值 |
|-------|-------|
| **引擎** | Godot 4.6 |
| **领域** | Foundation / Save-Load |
| **知识风险** | MEDIUM（FileAccess 返回类型变更在 4.4，LLM 训练截止 2025-05 后） |
| **查阅的参考** | `docs/engine-reference/godot/VERSION.md`、`docs/engine-reference/godot/breaking-changes.md`（4.4 FileAccess）、`docs/engine-reference/godot/deprecated-apis.md` |
| **使用的截止后 API** | `FileAccess.store_*` 返回 `bool`（4.4+ 破坏性变更——原返回 `void`）、`FileAccess.get_file_as_string()`（4.x 稳定） |
| **需要验证** | `FileAccess.store_string()` 写入 1MB JSON 的磁盘 I/O 耗时（预计 <50ms）；`DirAccess.rename_absolute` 在 Windows 上的重试策略有效性（防病毒扫描锁定）；`user://` 路径在 Steam 环境下的实际映射行为；Steam Cloud 自动同步对 `.tmp`/`.bak` 文件的处理 |

## ADR 依赖关系

| 字段 | 值 |
|-------|-------|
| **依赖** | ADR-0001（GSM——`serialize() → Dictionary`、`deserialize(Dictionary) → bool`；battle 和 session 域排除规则；`gsm_initialized` 信号保证初始化顺序）；ADR-0002（CardSystem——读档后需调用 `CardSystem.reconstitute_instances()` 将序列化字典重构为 CardInstance 对象） |
| **关联的 ADR** | ADR-0004（事件系统——story_flags 持久化到存档中）、ADR-0005（输入管理器——input_locks 不持久化，属于 session 域）、ADR-0006（场景管理器——存档恢复后通过 `request_scene_change` 切换场景）、ADR-0010（境界系统——境界数据通过 GSM 序列化持久化）、ADR-0012（跨局元进度——`progression.dat` 独立存储） |
| **阻塞** | **所有需要持久化进度的史诗**（战斗 Epic、探索 Epic、卡组编辑 Epic、修为养成 Epic、轮回天赋 Epic、成就 Epic）——在这些系统可以端到端测试前必须接受本 ADR |
| **排序说明** | Foundation 层第二个 ADR（在 ADR-0001 之后）。必须在任何需要存档功能的系统编码前被接受。SaveLoadSystem 在 Autoload 初始化顺序中位于第 4 位（GSM → InputManager → SceneManager → SaveLoad → EventSystem）。**关联的 ADR**（ADR-0004~0012）在 ADR 编号上排在 SaveLoad 之后，但它们不在运行时依赖 SaveLoad——SaveLoad 通过 GSM 的信号被动响应，不主动调用关联 ADR 的模块 |

## 上下文

### 问题陈述

游戏需要将玩家进度持久化到磁盘，支持中途退出后恢复、战败回退、以及跨局元进度的累积。这要求：

1. **全量状态序列化**：通过 GSM 的 `serialize()` 接口获取运行时状态的完整快照，写入磁盘文件
2. **多槽位管理**：1 个自动存档 + 3 个手动存档 + 1 个战斗前快照 + 1 个跨局元进度文件
3. **版本兼容**：游戏更新后旧存档仍需可读——字段新增时用默认值填充，结构变更时通过迁移函数转换
4. **写入安全性**：存档写入过程中游戏崩溃不得导致存档文件完全损坏——需保证原子性

Godot 4.4 引入了关键变更：`FileAccess.store_*` 系列方法从返回 `void` 改为返回 `bool`。这意味着每次写入调用都必须检查返回值——静默忽略返回值将在 4.6 中产生运行时警告并可能丢失数据。

架构层面需要做出一个关键决策：「存档模式版本控制」在 `architecture.md` 中被列为独立 Foundation 模块，拥有独立的 `schema_version` 和迁移函数链。本 ADR 决定将该模块**吸收进 SaveLoadSystem 内部**——迁移链和版本管理作为 SaveLoadSystem 的内部职责，而非独立的 Autoload 模块。这避免了两个版本字段（语义化版本 `"1.0.0"` vs 整数 `schema_version: 1`）之间的职责混淆。

### 约束

- **GSM 契约**：存档系统不得直接访问 GSM 内部字典——仅通过 `GSM.serialize()` / `GSM.deserialize()` 接口（ADR-0001）
- **battle 和 session 域排除**：这两个域在序列化时被 GSM 自动排除（ADR-0001 §序列化合约）——存档系统无需感知此规则
- **FileAccess 返回值**：所有 `store_*` 调用必须检查 `bool` 返回值（4.4+ 破坏性变更）
- **FileAccess/DirAccess 非线程安全**：Godot 4.x 中这两个类不是线程安全的——所有 I/O 操作必须在主线程执行
- **单线程 + 重入防护**：GDScript 无并发写入风险，但信号驱动的自动存档可能与手动存档在同一帧内触发——需通过 `_is_writing` 标志防止重入写入
- **磁盘空间**：单存档文件预计 <1MB（JSON 未压缩），最坏情况下 6 个文件（1 自动 + 3 手动 + 1 快照 + 1 progression + 1 meta）约 6MB
- **Steam Deck / 低端设备**：文件 I/O 必须在 HDD 上也能在 100ms 内完成
- **JSON 类型兼容性约束**：`save_game()` 接收的 `data` Dictionary 必须仅包含 JSON 兼容类型（String 键、int/float/String/bool/null 值、嵌套 Array/Dictionary 的原语）。`StringName`、`Vector2`、`Color`、`Resource` 引用等在传入前由 GSM `serialize()` 负责转换为兼容类型

### 需求

- 4 种存档类型：自动存档、手动存档（3 槽位）、战斗前快照、跨局元进度
- 版本化存档格式：`schema_version`（递增整数）驱动迁移链；`version`（语义化字符串）仅用于面向用户的展示
- 向前兼容：minor 版本增加时缺失字段用默认值填充
- 写入原子性：通过先写 `.tmp` 文件再 `rename` 的双写策略保证；Windows 上 `rename_absolute` 失败时最多重试 3 次（每次 50ms 延迟）
- 完整性校验：JSON 解析前先校验结构（`JSON.new().parse()` 检查 `Error` 返回值），辅以 `"complete": true` 标记作为纵深防御
- 自动存档防抖：同场景 10 秒间隔，跨场景立即保存
- 战斗快照生命周期：战斗开始写入 → 战斗胜利/撤退删除 → 战败可选"读档重来"
- 读档后 CardSystem 实例重构：`GSM.deserialize()` 成功后调用 `CardSystem.reconstitute_instances()`（ADR-0002 契约）
- Progression 信号驱动自动保存：SaveLoadSystem 监听 GSM 的 `progression_updated` 信号自动触发保存（不暴露为公共 API 由特性系统直接调用）

## 决策

**存档系统将以 JSON 作为序列化格式，通过 Godot `FileAccess` API 进行文件 I/O，以 `schema_version`（递增整数）作为唯一的迁移驱动字段，并通过纯函数迁移链处理版本升级。**

**「存档模式版本控制」模块被吸收进 SaveLoadSystem 内部——不再作为独立的 Foundation 层 Autoload。** `architecture.md` 的 Foundation 层模块表移除该独立行。

### 架构图

```
┌──────────────────────────────────────────────────────────────────┐
│                    SaveLoadSystem (Autoload #4)                   │
│                                                                   │
│  ┌─ 公共 API ───────────────────────────────────────────┐        │
│  │ save_game(SaveSlot, Dictionary) → SaveResult          │        │
│  │ load_game(SaveSlot) → Dictionary                      │        │
│  │   # 返回 {"result": LoadResult, "data": Dictionary}    │        │
│  │ delete_save(SaveSlot) → bool                          │        │
│  │ get_slot_meta(SaveSlot) → Dictionary                  │        │
│  │ list_slots() → Array[Dictionary]                      │        │
│  │ load_progression() → Dictionary                       │        │
│  │ create_battle_snapshot(Dictionary) → bool             │        │
│  │ restore_battle_snapshot() → Dictionary                │        │
│  │ clear_battle_snapshot() → void                        │        │
│  └───────────────────────────────────────────────────────┘        │
│                                                                   │
│  ┌─ 信号 ───────────────────────────────────────────────┐        │
│  │ save_completed(slot_type, slot_id, success)           │        │
│  │   # UI 提示保存成功/失败                               │        │
│  │ load_started(slot_type, slot_id)                      │        │
│  │   # 触发加载画面                                       │        │
│  │ load_completed(success: bool)                         │        │
│  │   # 触发场景切换或错误弹窗                              │        │
│  │ save_corrupted(slot_type, slot_id, reason)            │        │
│  │   # 存档损坏提示 UI                                    │        │
│  │ progression_saved(success: bool)                      │        │
│  │   # 静默日志（可选监听的 UI 提示）                      │        │
│  └───────────────────────────────────────────────────────┘        │
│                                                                   │
│  ┌─ 内部 — 写入路径 ────────────────────────────────────┐        │
│  │ _atomic_write(path, data) → bool                      │        │
│  │   ├→ 检查 _is_writing 防重入——已在写入中则 queue 或 skip│        │
│  │   ├→ 设置 _is_writing = true                          │        │
│  │   ├→ f = FileAccess.open(path + ".tmp", WRITE)        │        │
│  │   │   if f == null → 返回 false                        │        │
│  │   ├→ json_str = JSON.stringify(data, "\t")            │        │
│  │   ├→ if not f.store_string(json_str):  # ⚠️ 4.4+ bool │        │
│  │   │   f.close(); _is_writing = false; 返回 false      │        │
│  │   ├→ f.close()                                        │        │
│  │   ├→ if FileAccess.file_exists(path):                 │        │
│  │   │    备份旧文件 → path + ".bak"（rename，失败可接受） │        │
│  │   ├→ rename = retry(rename_absolute, 3次, 50ms)       │        │
│  │   │   # Windows: 防病毒/索引器短暂锁定文件              │        │
│  │   ├→ rename 成功 → remove_absolute(path + ".bak")     │        │
│  │   │   失败则记录日志（.bak 残留无害，下次写入覆盖）       │        │
│  │   ├→ rename 失败 → 恢复 .bak → 返回 false              │        │
│  │   └→ _is_writing = false; 返回 true                   │        │
│  └───────────────────────────────────────────────────────┘        │
│                                                                   │
│  ┌─ 内部 — 读取路径 ────────────────────────────────────┐        │
│  │ _atomic_read(path) → Dictionary                        │        │
│  │   ├→ 仅读取规范文件名（忽略 .tmp 和 .bak 文件）         │        │
│  │   ├→ if not FileAccess.file_exists(path):              │        │
│  │   │    返回 {"result": FILE_NOT_FOUND}                 │        │
│  │   ├→ raw = FileAccess.get_file_as_string(path)         │        │
│  │   ├→ json = JSON.new()                                │        │
│  │   ├→ err = json.parse(raw)  # ⚠️ 不用 parse_string() │        │
│  │   │   # parse_string() 对 null 和 error 均返回 null   │        │
│  │   ├→ if err != OK: 返回 {"result": CORRUPTED}         │        │
│  │   ├→ data = json.get_data()                            │        │
│  │   ├→ if not _validate_save_data(data):                 │        │
│  │   │    返回 {"result": CORRUPTED}                      │        │
│  │   └→ 返回 {"result": SUCCESS, "data": data}           │        │
│  └───────────────────────────────────────────────────────┘        │
│                                                                   │
│  ┌─ 内部 — 迁移链 ──────────────────────────────────────┐        │
│  │ const CURRENT_SCHEMA_VERSION: int = 1                  │        │
│  │ const MIGRATIONS: Dictionary[int, Callable] = {       │        │
│  │   # 1: _migrate_v1_to_v2,  # 首次需要升级时取消注释    │        │
│  │ }                                                      │        │
│  │                                                        │        │
│  │ _migrate_if_needed(data) → Dictionary                  │        │
│  │   ├→ save_schema = data.get("schema_version", 0)      │        │
│  │   ├→ save_schema > CURRENT → VERSION_MISMATCH          │        │
│  │   ├→ while save_schema < CURRENT:                      │        │
│  │   │     migrate_fn = MIGRATIONS[save_schema]           │        │
│  │   │     data = migrate_fn.call(data)                   │        │
│  │   │     save_schema += 1                               │        │
│  │   └→ 返回迁移后的 data                                 │        │
│  └───────────────────────────────────────────────────────┘        │
│                                                                   │
│  ┌─ 内部 — 自动存档触发 ────────────────────────────────┐        │
│  │ _ready():                                                │        │
│  │   GSM.scene_changed.connect(_on_autosave_trigger)       │        │
│  │   GSM.battle_ended.connect(_on_battle_ended)            │        │
│  │   GSM.battle_started.connect(_on_battle_started_snapshot)│       │
│  │   GSM.progression_updated.connect(_on_progression_changed)│      │
│  │                                                        │        │
│  │ _on_progression_changed(_key, _value):                  │        │
│  │   # 被动响应——不暴露 save_progression() 公共 API        │        │
│  │   _write_progression(GSM.progression)                   │        │
│  └───────────────────────────────────────────────────────┘        │
└──────────────────────────────────────────────────────────────────┘
         │                              │
         │ GSM.serialize()              │ FileAccess / DirAccess
         │ GSM.deserialize()            │
         ▼                              ▼
    ┌──────────┐              ┌──────────────────────────┐
    │   GSM    │              │  _get_save_root() 返回     │
    │ (ADR-1)  │              │  "user://saves/"           │
    └──────────┘              │  ├─ autosave/save.json     │
                              │  ├─ manual/save_{N}.json   │
                              │  ├─ snapshot/pre_battle.json│
                              │  ├─ progression.dat        │
                              │  └─ meta.json              │
                              └──────────────────────────┘
```

### 关键接口

#### SaveLoadSystem API

```gdscript
## 存档槽位枚举
enum SaveSlotType { AUTOSAVE, MANUAL, SNAPSHOT }
enum SaveResult { SUCCESS, DISK_FULL, WRITE_ERROR, VALIDATION_ERROR }
enum LoadResult { SUCCESS, FILE_NOT_FOUND, CORRUPTED, VERSION_MISMATCH, DESERIALIZE_ERROR }

## 保存游戏
## data 必须仅包含 JSON 兼容类型（GSM.serialize() 的输出满足此约束）
## meta 为展示用元信息（player_name, realm, chapter, map_name, deck_size）
## 内部自动防重入——若已有写入进行中则 queue（同一槽位覆盖旧的排队请求）
func save_game(slot_type: SaveSlotType, slot_id: int = 0,
               data: Dictionary, meta: Dictionary = {}) -> SaveResult

## 读取游戏
## 返回 {"result": LoadResult, "data": Dictionary}
## 调用方在 result == SUCCESS 后须调用 CardSystem.reconstitute_instances(data.game_state.collection.owned_cards)
func load_game(slot_type: SaveSlotType, slot_id: int = 0) -> Dictionary

## 删除存档
func delete_save(slot_type: SaveSlotType, slot_id: int = 0) -> bool

## 获取槽位元信息（不读取完整存档——仅解析 meta 容器字段）
func get_slot_meta(slot_type: SaveSlotType, slot_id: int = 0) -> Dictionary

## 列出所有槽位状态（从 meta.json 读取，含 exists/name/timestamp/realm/playtime）
func list_slots() -> Array[Dictionary]

## 跨局元进度——仅读取（写入由 SaveLoadSystem 内部通过 GSM 信号自动触发）
func load_progression() -> Dictionary  # 空文件返回默认值

## 战斗快照生命周期
func create_battle_snapshot(data: Dictionary) -> bool
func restore_battle_snapshot() -> Dictionary  # {"result": LoadResult, "data": Dictionary}
func clear_battle_snapshot() -> void
```

#### 存档容器格式

```gdscript
## 写入磁盘的完整存档结构
## SaveContainer 为纯 Dictionary——非 Godot Resource，无 @export 字段约束
{
  "schema_version": 1,         # 递增整数——**唯一**的迁移驱动字段
  "version": "1.0.0",          # 语义化版本——**仅用于面向用户的展示**，不参与迁移逻辑
  "timestamp": "2026-07-24T15:30:00Z",  # ISO-8601 UTC
  "playtime_seconds": 3600,
  "meta": {                    # 展示用元信息（不参与 game_state 逻辑）
    "player_name": "凡人001",
    "realm": "筑基",
    "chapter": 2,
    "map_name": "碎星外环",
    "deck_size": 32
  },
  "game_state": { ... },       # GSM.serialize() 输出（battle/session 域已被 GSM 排除）
  "complete": true             # 完整性标记——纵深防御。原子 rename 是主策略。
}
```

**版本字段职责划分**：

| 字段 | 类型 | 职责 | 变更规则 |
|------|------|------|---------|
| `schema_version` | `int` | **驱动迁移逻辑**——决定执行哪些迁移函数 | 每次需要数据迁移（新增必填字段、重命名键、结构变更）时递增 1 |
| `version` | `String` | **仅用于面向用户的展示**——存档列表显示"存档版本" | 跟随游戏版本号（`MAJOR.MINOR.PATCH`），不参与任何逻辑判断 |

#### 读档完整流程（含 CardSystem 重构）

```
load_game(slot_type, slot_id):
  1. _atomic_read(path) → 读取 + JSON 解析 + 完整性校验
  2. _validate_version(data) → schema_version ≤ CURRENT → 继续
     schema_version > CURRENT → 返回 VERSION_MISMATCH
  3. _migrate_if_needed(data) → 按需执行迁移链
  4. GSM.deserialize(data["game_state"]) → 逐域恢复游戏状态
  5. GSM.deserialize() 失败 → 返回 DESERIALIZE_ERROR
  6. ⚠️ CardSystem.reconstitute_instances(data["game_state"]["collection"]["owned_cards"])
     → 将 GSM 中的 Array[Dictionary] 重构为 Array[CardInstance] 对象（ADR-0002 契约）
  7. 发射 load_completed(true) 信号
  8. 返回 {"result": SUCCESS, "data": data}
```

#### 版本兼容性矩阵

| 条件 | 处理方式 | 示例 |
|------|---------|------|
| `save_schema > CURRENT` | **拒绝加载**，返回 VERSION_MISMATCH | 存档来自更新版本的游戏 |
| `save_schema < CURRENT` | **迁移后加载** | 执行迁移链 `save_schema → save_schema+1 → ... → CURRENT` |
| `save_schema == CURRENT` | **直接加载** | 无版本差异 |

注意：版本兼容性**仅由 `schema_version`（整数）驱动**。`version`（字符串）在加载时不参与任何 `if` 判断——它只在存档列表 UI 中展示。

#### JSON 解析路径（强制使用 JSON.new().parse()）

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

#### 迁移链

```gdscript
## 迁移函数注册表——键类型显式声明为 int
const CURRENT_SCHEMA_VERSION: int = 1

## 首次需要升级时追加条目。每个函数是纯函数：Dictionary → Dictionary
const MIGRATIONS: Dictionary[int, Callable] = {
  # 1: _migrate_v1_to_v2,  # 例如：card_instance 新增 breakthrough_layers 字段
  # 2: _migrate_v2_to_v3,  # 例如：story_flags 从 Array 改为 Dictionary
}

## 迁移入口——从 from_ver 链接迁移到 CURRENT
func _migrate_if_needed(data: Dictionary) -> Dictionary:
    var save_schema: int = data.get("schema_version", 0)
    if save_schema > CURRENT_SCHEMA_VERSION:
        return {"error": "VERSION_MISMATCH",
                "save_schema": save_schema,
                "current_schema": CURRENT_SCHEMA_VERSION}

    while save_schema < CURRENT_SCHEMA_VERSION:
        if not MIGRATIONS.has(save_schema):
            return {"error": "MIGRATION_MISSING", "from": save_schema}
        data = MIGRATIONS[save_schema].call(data)
        save_schema += 1
        data["schema_version"] = save_schema

    return data
```

#### 路径抽象（Steam 就绪）

```gdscript
## 存档根目录——当前返回 user://，发布前验证 Steam 环境映射
func _get_save_root() -> String:
    return "user://saves/"

func _save_path(slot_type: SaveSlotType, slot_id: int = 0) -> String:
    var root := _get_save_root()
    match slot_type:
        SaveSlotType.AUTOSAVE:
            return root + "autosave/save.json"
        SaveSlotType.MANUAL:
            return root + "manual/save_%d.json" % slot_id
        SaveSlotType.SNAPSHOT:
            return root + "snapshot/pre_battle.json"
    return root
```

**Steam Cloud 配置要求（发布前）：**
- Steam Cloud 同步路径配置为 `user://saves/`
- 排除文件模式：`*.tmp`、`*.bak`
- 发布前验证：`user://` 在 Steam 客户端启动的 Godot 进程中是否直接映射到 `%APPDATA%/Godot/app_userdata/<project>/`（标准行为），或是否需要 `ISteamRemoteStorage` API

### 重入防护

```gdscript
var _is_writing: bool = false
var _pending_autosave: bool = false

func _atomic_write(path: String, data: Dictionary) -> bool:
    if _is_writing:
        # 手动存档优先——若当前是手动保存，丢弃自动存档请求
        # 若当前是自动存档中且新请求是手动存档 → 排队等待当前写入完成后执行
        push_warning("SaveLoadSystem: Write already in progress, queuing request")
        _pending_autosave = true
        return false  # 调用方收到 false 后可重试或丢弃
    _is_writing = true
    # ... 写入逻辑 ...
    _is_writing = false
    return true
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
    #    在极端文件系统损坏或手动编辑后，此标记可能挽救检测
    if not data.has("complete") or data["complete"] != true:
        push_error("Save file missing 'complete' marker — possible write interruption or manual corruption")
        return false

    return true
```

### 自动存档与 Progression 信号订阅

```gdscript
## SaveLoadSystem._ready() 中连接
func _ready():
    # 自动存档触发
    GSM.scene_changed.connect(_on_autosave_trigger)
    GSM.battle_ended.connect(_on_battle_ended)
    # 战斗快照
    GSM.battle_started.connect(_on_battle_started_snapshot)
    # Progression 被动保存——特性系统只通过 GSM 写入，不直接调用 SaveLoadSystem
    GSM.progression_updated.connect(_on_progression_changed)

func _on_autosave_trigger(_old_scene: String, _new_scene: String):
    if _can_autosave():
        var data = GSM.serialize()
        save_game(SaveSlotType.AUTOSAVE, 0, data)

func _on_battle_ended(_result: Dictionary):
    clear_battle_snapshot()
    var data = GSM.serialize()
    save_game(SaveSlotType.AUTOSAVE, 0, data)

func _on_battle_started_snapshot(_enemy_id: String):
    var data = GSM.serialize()
    create_battle_snapshot(data)

## Progression 信号驱动——SaveLoadSystem 是被动响应者
func _on_progression_changed(_key: String, _value: Variant):
    _write_progression(GSM.progression)
```

## 考虑的替代方案

### 替代方案 A：Godot ConfigFile（.ini 格式）
- **描述**：使用 Godot 内置的 `ConfigFile` API 存储存档。每个 section 对应一个 GSM 域，key-value 对存储属性值。
- **优点**：类型安全（`get_value()` 带类型提示）、Godot 原生 API 无需手动解析、编辑器内可读
- **缺点**：嵌套结构支持差——`Dictionary` 和 `Array` 需序列化为字符串再手动解析；迁移函数需操作 `.ini` section/key 而非直接操作字典；手动修复困难
- **拒绝原因**：GSM 的 `serialize()` 返回深度嵌套的 Dictionary。ConfigFile 的扁平 key-value 模型与此不匹配——将不得不为每个嵌套层级发明自己的序列化格式，实际上就是在 ConfigFile 内部重新实现 JSON。

### 替代方案 B：Godot ResourceSaver/ResourceLoader（.tres/.res 二进制）
- **描述**：游戏状态存储为 Godot Resource 文件，通过 `ResourceSaver.save()` 和 `ResourceLoader.load()` 读写。
- **优点**：与 Godot 编辑器深度集成、编辑器内可直接查看 `.tres` 文件、`ResourceLoader` 支持异步加载
- **缺点**：版本兼容性极差——字段重命名或类型变更会导致 `ResourceLoader.load()` 直接失败，无法执行迁移逻辑；`.res` 二进制格式不可手动修复；Resource 的 `@export` 字段必须在类定义中预先声明——动态状态（`story_flags` 运行时增删键）无法表达
- **拒绝原因**：存档需要跨版本的向前兼容和迁移能力。ResourceLoader 在遇到未知字段时直接报错，无法插入迁移逻辑。JSON 的"解析为字典→检查和迁移→传给 GSM"流水线在 Resource 格式下根本不存在。

### 替代方案 C：二进制序列化（`var_to_bytes` / `bytes_to_var`）
- **描述**：使用 Godot 的 `var_to_bytes()` 将 Dictionary 编码为二进制，通过 `FileAccess.store_buffer()` 写入 `.sav` 文件。
- **优点**：文件体积小（约为 JSON 的 1/3-1/2）、读写速度快（无需解析文本）、`store_buffer()` 也返回 `bool`（4.4+）检查写入成功
- **缺点**：完全不可手动检查和修复——损坏的存档无法恢复；跨版本兼容性为零——`bytes_to_var()` 对类型变化敏感；调试困难
- **拒绝原因**：单机游戏存档文件 <1MB，JSON 的 I/O 开销可以忽略（<50ms）。二进制格式节省的几十毫秒不值得放弃手动修复和调试可见性。JSON 的可读性对开发和玩家支持至关重要。

## 后果

### 积极的
- **手动可修复**：JSON 格式允许开发者和高级玩家直接查看/编辑存档文件，用于调试和恢复损坏的存档
- **迁移链清晰**：每个迁移函数是纯函数 `Dictionary → Dictionary`，可独立测试，可组合。每个历史 schema_version 需有对应的测试 fixture 文件
- **写入原子性**：`.tmp` + `rename` 双写策略 + Windows 重试（3 次 × 50ms）保证崩溃时至少保留旧版本或 `.tmp` 文件——不会出现半写文件
- **与 GSM 解耦**：存档系统不关心 `game_state` 的内部结构——它只是透明的数据管道。GSM 序列化格式的变更不强制修改存档系统
- **版本管理单一职责**：`schema_version`（整数）唯一定义迁移逻辑。`version`（字符串）仅用于 UI 展示——消除双重定义混淆
- **Foundation 层简化**：吸收独立的「存档模式版本控制」模块——减少 1 个 Autoload，降低初始化顺序复杂度
- **Progression 被动保存**：SaveLoadSystem 监听 GSM 信号自动触发 progression 写入——特性系统只通过 GSM 写入，不直接依赖 SaveLoadSystem，符合 Foundation 层原则 #3
- **重入安全**：`_is_writing` 标志 + 排队机制防止信号触发的自动存档与手动保存冲突

### 消极的
- **无压缩**：1MB 纯文本 JSON 文件在 Steam Cloud 同步时可能比二进制格式慢——但单机游戏存档通常 <100KB
- **无加密/混淆**：玩家可以轻易修改存档（作弊）。解决方案：单机游戏无排行榜——作弊只影响玩家自身。`progression.dat` 简单混淆即可防止误修改
- **启动时 I/O**：`load_progression()` 在 SaveLoadSystem._ready() 时执行——增加启动时间约 10-20ms
- **JSON 解析开销**：`JSON.new().parse()` 处理嵌套 Dictionary 约需 5-10ms——远低于 16.6ms 帧预算

### 风险
- **JSON 写入中断导致存档损坏**：缓解措施——双写策略（`.tmp` → `rename`，`rename` 前备份为 `.bak`）。最坏情况：保留 `.tmp` + `.bak` 两个文件，下次启动时检测并忽略 `.tmp`，从规范文件加载
- **`DirAccess.rename_absolute` 跨文件系统失败**：缓解措施——`.tmp` 文件写入目标目录同一路径（`user://saves/{type}/`），而非系统 `/tmp`，确保 rename 在同一文件系统内完成
- **`rename_absolute` 在 Windows 上被防病毒/索引器短暂锁定**：缓解措施——最多重试 3 次，每次间隔 50ms。3 次均失败后返回 `WRITE_ERROR`（不静默跳过）
- **`schema_version` 回退**：开发分支切换导致 `CURRENT_SCHEMA_VERSION` 变小。缓解措施——加载时检测 `save_schema > CURRENT` 并拒绝加载（而非崩溃），提示"存档来自更新版本"
- **JSON.stringify 对循环引用栈溢出**：缓解措施——GSM `serialize()` 负责确保输出为平坦的纯数据字典。存档系统在开发构建中添加 `JSON.stringify()` 的 `try/catch` 并记录详细错误
- **Steam Cloud 同步 `.tmp`/`.bak` 文件**：缓解措施——Steam Cloud 配置排除 `*.tmp` 和 `*.bak`。发布前在 Steamworks 设置中验证
- **迁移函数 bug 静默损坏玩家存档**：缓解措施——每个迁移函数必须有对应单元测试（加载历史 fixture → 执行迁移 → 断言输出匹配预期）。CI 中迁移失败则阻塞合并

## 解决的 GDD 需求

| GDD 系统 | 需求 | 本 ADR 如何解决 |
|------------|-------------|--------------------------|
| save-load-system.md | §核心规则 #1：4 种存档类型（自动/手动/快照/元进度） | 确立 SaveSlotType 枚举 + 独立 API：`save_game()`、`create_battle_snapshot()`、`load_progression()` |
| save-load-system.md | §文件结构：`user://saves/{type}/{id}.json` + `meta.json` + `progression.dat` | 确立目录布局 + `_get_save_root()` 路径抽象 + `_save_path()` 解析规则 |
| save-load-system.md | §存档数据格式 §3：version + timestamp + playtime + meta + game_state | 确立 SaveContainer 字典结构，`version` 降级为展示字段，新增 `schema_version` 为迁移驱动 |
| save-load-system.md | §存档流程 §4：5 步保存流程 | 确立 `save_game()` 的完整执行流程，含重入防护和原子写入 |
| save-load-system.md | §读档流程 §5：10 步读档流程 | 确立 `load_game()` 的完整执行流程，含 JSON 解析 → 版本检查 → 迁移 → GSM.deserialize → CardSystem.reconstitute_instances |
| save-load-system.md | §版本兼容策略 §6：MAJOR.MINOR.PATCH + 兼容性矩阵 | 确立 `schema_version` 迁移链 + 版本兼容性矩阵——`version` 字符串仅作展示 |
| save-load-system.md | §跨局元进度 §7：独立 `progression.dat` 读写 | 确立 GSM 信号驱动的被动保存——`load_progression()` 公共 API + 内部 `_write_progression()` |
| save-load-system.md | §自动存档防抖 §9：10 秒间隔 + 跨场景跳过限制 | 确立 `_can_autosave()` 防抖逻辑 |
| save-load-system.md | §边界情况：写入中断完整性 | 确立 `.tmp` + `.bak` 双写策略 + `"complete": true` 纵深防御标记 + 原子 rename 主策略 |
| save-load-system.md | §验收标准：16 个 GIVEN/WHEN/THEN 场景 | 全部 16 个场景均可映射到本 ADR 的 API 调用流程 |
| architecture.md | §路径 C：存档/读档数据流 + CardSystem 重构 | 确立与 architecture.md 路径 C 一致的流水线，**补充** `CardSystem.reconstitute_instances()` 步骤 |
| architecture.md | §初始化顺序 T+2：SaveLoad._ready() | 确立 Autoload 初始化顺序第 4 位 + GSM 信号连接时机 |
| architecture.md | Foundation 层模块表 | **移除**「存档模式版本控制」独立行——合并入 SaveLoadSystem 内部 |

## 性能影响
- **CPU**：`JSON.stringify()` 处理 <1MB 字典约 5-10ms；`JSON.new().parse()` 约 5-10ms。均在非热路径中执行（存档/读档是偶发事件）
- **内存**：`save_game()` 期间字典在内存中短暂存在两份（原始 + JSON 字符串），峰值约 2MB——可接受
- **加载时间**：`load_progression()` 在 `_ready()` 中执行——增加启动时间约 10-20ms。`load_game()` 仅在玩家主动读档时执行——非启动路径
- **磁盘 I/O**：`FileAccess.store_string()` 写入 1MB 约 30-50ms（SSD）/ 50-100ms（HDD）。`DirAccess.rename_absolute()` 约 <1ms（同目录内 inode 操作）。Windows 重试最坏情况：3 × 50ms = 150ms 额外延迟
- **网络**：不适用（纯单机游戏）

## 迁移计划
无现有代码需迁移——这是 Foundation 层决策，所有后续实现将以此为基础构建。

初始 `CURRENT_SCHEMA_VERSION = 1`。迁移链为空（`MIGRATIONS = {}`），在首次需要格式升级时追加第一个迁移函数。

## 验证标准
- 通过 GUT：`SaveLoadSystem` 测试套件覆盖：
  - `save_game()` + `load_game()` 往返——加载的数据与保存的数据一致
  - `save_game()` 写入失败 → 返回 `SaveResult.WRITE_ERROR`
  - 写入中断模拟——`.tmp` 文件存在但 `"complete"` 缺失 → `_validate_save_data()` 返回 false
  - `JSON.new().parse()` 解析错误 → 返回 `LoadResult.CORRUPTED`（非 null 静默通过）
  - `schema_version` 低于 CURRENT → 迁移函数被执行 → `data["schema_version"]` 递增到 CURRENT
  - `schema_version` 高于 CURRENT → 返回 `LoadResult.VERSION_MISMATCH`
  - `delete_save()` 后 `get_slot_meta()` 返回 `exists: false`
  - `create_battle_snapshot()` → 文件存在 → `restore_battle_snapshot()` 成功 → 文件被清除
  - 自动存档防抖——同场景 5 秒内第二次触发被跳过；跨场景立即保存
  - `load_progression()` 文件不存在 → 返回默认值字典（非 null）
  - 重入防护——`_is_writing == true` 期间第二次 `save_game()` 调用被排队（非静默丢弃）
  - Windows `rename_absolute` 失败 3 次 → 返回 `WRITE_ERROR`（非无限等待）
  - 迁移函数测试——每个历史 schema_version 有对应 fixture 文件，迁移后输出匹配预期
  - `load_game()` 成功后 `CardSystem.reconstitute_instances()` 被调用——验证 CardInstance 对象已重构

## 相关决策
- ADR-0001（GSM——提供 `serialize()`/`deserialize()` 接口，battle 和 session 域排除规则，`progression_updated` 信号）
- ADR-0002（卡牌数据模型——`CardSystem.reconstitute_instances()` 读档后重构 CardInstance 对象的契约）
- ADR-0004（事件系统——`story_flags` 通过 GSM 持久化，由存档系统写入磁盘）
- ADR-0005（输入管理器——`session.input_locks` 不持久化，属于 session 域）
- ADR-0006（场景管理器——存档恢复后通过 `request_scene_change` 切换场景）
- ADR-0012（跨局元进度——`progression.dat` 独立存储，本 ADR 的 GSM 信号驱动写入是其 Foundation 层支撑）
