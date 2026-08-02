extends Node
## SaveLoadSystem (Autoload #4) —— 存档/读档系统的持久化引擎。
##
## 提供 JSON 序列化/反序列化管线——所有存档文件的读写均通过本系统。[br]
## [b]枚举[/b]: SaveSlotType（槽位类型）、SaveResult（保存结果）、LoadResult（读取结果）[br]
## [b]JSON 引擎[/b]: [method _parse_json_file]（读取 + Error 检查）+
## [method _serialize_to_json]（格式化写入）[br]
## [br]
## [b]⚠️ ADR-0002 强制规则[/b]: 解析存档必须使用 [method JSON.new].parse()——
## 绝不使用 [method JSON.parse_string]（无法区分合法 null 和解析错误）。[br]
## [br]
## [b]Story 001 范围[/b]: 枚举定义 + JSON 引擎核心。[br]
## [b]Story 002 范围[/b]: 原子写入管线 + Windows 重试 + 重入防护 + 路径解析。

## === 写入控制常量 ============================================================

## Windows 平台 rename_absolute 最大重试次数——应对防病毒/索引器文件锁定。
const MAX_RENAME_RETRIES: int = 3
## Windows 平台 rename_absolute 重试间隔（毫秒）。
const RENAME_RETRY_DELAY_MS: int = 50

## === 写入状态字段 ============================================================

## 写入进行中标志——防止并发写入导致存档损坏。
var _is_writing: bool = false
## 自动存档排队标志——写入进行中触发自动存档时不丢弃，写入完成后重试。
var _pending_autosave: bool = false

## === 存档槽位类型 ==============================================================

## 存档槽位类型——驱动文件路径解析和 UI 展示。
enum SaveSlotType {
	AUTOSAVE = 0,  ## 自动存档——固定 autosave 槽位，每局唯一，自动覆盖
	MANUAL = 1,    ## 手动存档——3 个槽位（save_1/save_2/save_3），玩家可命名/覆盖/删除
	SNAPSHOT = 2,  ## 战斗前快照——固定 pre_battle 槽位，战斗胜利/撤退后自动清除
}

## === 保存结果 ==================================================================

## 保存操作的结果码。
enum SaveResult {
	SUCCESS = 0,          ## 保存成功
	DISK_FULL = 1,        ## 磁盘空间不足
	WRITE_ERROR = 2,      ## 写入错误（含 Windows rename 重试 3 次均失败）
	VALIDATION_ERROR = 3, ## 数据校验失败——data 不符合存档格式约束
}

## === 读取结果 ==================================================================

## 读取操作的结果码。
enum LoadResult {
	SUCCESS = 0,           ## 读取成功
	FILE_NOT_FOUND = 1,    ## 文件不存在——槽位为空或路径无效
	CORRUPTED = 2,         ## 存档损坏——JSON 解析失败、顶层非 Object、缺少必填字段
	VERSION_MISMATCH = 3,  ## 版本不兼容——存档的 schema_version 高于当前游戏版本
	DESERIALIZE_ERROR = 4, ## 反序列化错误——GSM.deserialize() 返回 false
}

## === 内置虚方法 ================================================================

func _ready() -> void:
	pass

## === 内部 JSON 引擎 ============================================================

## 解析 JSON 存档文件——使用 [method JSON.new].parse() 区分合法 null 和解析错误。
##
## [b]返回值[/b]: [code]{ "result": LoadResult, "data": Dictionary }[/code][br]
## [param result] 为 [enum LoadResult.SUCCESS] 时 [param data] 包含解析后的字典。[br]
## [param result] 为其他值时 [param data] 为空字典。[br]
## [br][b]⚠️ ADR-0002 规则[/b]: 绝不使用 [method JSON.parse_string]——
## 它对 null 合法值和解析错误均返回 null，无法区分两种语义。
func _parse_json_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"result": LoadResult.FILE_NOT_FOUND, "data": {}}

	var raw: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	var err := json.parse(raw)
	if err != OK:
		push_error("存档文件解析错误 第 %d 行: %s" % [json.get_error_line(), json.get_error_message()])
		return {"result": LoadResult.CORRUPTED, "data": {}}

	var data: Variant = json.get_data()
	if typeof(data) != TYPE_DICTIONARY:
		return {"result": LoadResult.CORRUPTED, "data": {}}

	return {"result": LoadResult.SUCCESS, "data": data}


## 将 Dictionary 序列化为 JSON 字符串——使用制表符缩进输出人类可读文件。
##
## [b]参数[/b]: [param data] 必须仅包含 JSON 兼容类型（String 键、
## int/float/String/bool/null 值、嵌套 Array/Dictionary 的原语）。[br]
## [b]返回[/b]: 格式化 JSON 字符串——可直接写入存档文件。
func _serialize_to_json(data: Dictionary) -> String:
	return JSON.stringify(data, "\t")


## 递归检查值是否仅包含 JSON 兼容类型——类型安全校验。
##
## JSON 兼容类型包括：nil、bool、int、float、String、Array（元素也兼容）、
## Dictionary（String 键 + 兼容值）。[br]
## 非 JSON 兼容类型：Vector2/3/4、Color、StringName、NodePath、Object 等。[br]
## [br][b]注意[/b]: Godot 4.6 的 [method JSON.stringify] 会静默将 Vector2 转为
## 字符串 "(x, y)" 而非返回空字符串——故此方法通过 [method typeof] 逐层校验。
static func _is_json_compatible(value: Variant) -> bool:
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING:
			return true
		TYPE_ARRAY:
			for item: Variant in value:
				if not _is_json_compatible(item):
					return false
			return true
		TYPE_DICTIONARY:
			for key: Variant in value.keys():
				if typeof(key) != TYPE_STRING:
					return false
				if not _is_json_compatible(value[key]):
					return false
			return true
		_:
			return false


## === 路径解析 ==================================================================

## 返回存档根目录——可被子类或测试 mock 覆盖。
func _get_save_root() -> String:
	return "user://saves/"


## 根据槽位类型和槽位 ID 解析存档文件完整路径。
##
## [param slot_type] 槽位类型——AUTOSAVE/MANUAL/SNAPSHOT。[br]
## [param slot_id] 槽位编号——MANUAL 时为 1-3，其他类型忽略。[br]
## [b]返回[/b]: 存档文件的完整 `user://` 路径。
func _save_path(slot_type: SaveSlotType, slot_id: int = 0) -> String:
	var root := _get_save_root()
	match slot_type:
		SaveSlotType.AUTOSAVE:
			return root + "autosave/save.json"
		SaveSlotType.MANUAL:
			return root + "manual/save_%d.json" % slot_id
		SaveSlotType.SNAPSHOT:
			return root + "snapshot/pre_battle.json"
		_:
			push_error("SaveLoadSystem: 未知槽位类型: %d" % slot_type)
			assert(false, "SaveLoadSystem._save_path: 不可达——SaveSlotType 枚举值非法")
			return ""


## 确保目录存在——不存在时递归创建目录树。
##
## [b]参数[/b]: [param path] 完整文件路径——自动提取目录部分。[br]
## [b]返回[/b]: 目录存在或创建成功时返回 true，创建失败时返回 false。
func _ensure_dir(path: String) -> bool:
	var dir := path.get_base_dir()
	if DirAccess.dir_exists_absolute(dir):
		return true
	var err := DirAccess.make_dir_recursive_absolute(dir)
	if err != OK:
		push_error("SaveLoadSystem: 无法创建目录: %s (err=%d)" % [dir, err])
		return false
	return true


## === Windows 重试逻辑 =========================================================

## 带重试的 rename_absolute——Windows 平台文件锁定应对策略。
##
## 防病毒/索引器可能短暂锁定文件——最多重试 [member MAX_RENAME_RETRIES] 次，
## 每次间隔 [member RENAME_RETRY_DELAY_MS] 毫秒。[br]
## [b]返回[/b]: rename 成功时返回 true，全部重试失败时返回 false。
func _rename_with_retry(from_path: String, to_path: String) -> bool:
	for attempt in range(1, MAX_RENAME_RETRIES + 1):
		var err := DirAccess.rename_absolute(from_path, to_path)
		if err == OK:
			return true
		if attempt < MAX_RENAME_RETRIES:
			push_warning("SaveLoadSystem: rename 第 %d 次尝试失败，%dms 后重试..."
					% [attempt, RENAME_RETRY_DELAY_MS])
			OS.delay_msec(RENAME_RETRY_DELAY_MS)
	return false


## === 原子写入管线 ==============================================================

## 原子写入——.tmp 双写 + rename + .bak 备份 + Windows 重试。
##
## 写入流程（5 阶段）：[br]
## 1. 重入防护——写入进行中时拒绝，自动存档排队而非丢弃。[br]
## 2. 确保目录存在 → 创建 .tmp 文件 → store_string() 写 JSON。[br]
## 3. 旧文件存在时 rename → .bak 备份。[br]
## 4. rename_absolute(.tmp → 规范文件名) 带重试，失败恢复 .bak。[br]
## 5. 删除 .bak（失败仅记录日志），处理排队的自动存档。[br]
## [br]
## [b]参数[/b]: [param path] 目标文件完整路径。[br]
## [b]参数[/b]: [param data] 待序列化的 Dictionary——必须仅含 JSON 兼容类型。[br]
## [b]返回[/b]: [enum SaveResult]——SUCCESS 或错误码。[br]
## [br][b]偏离 ADR-0002[/b]: ADR 架构图中返回值标注为 bool——Story 002 设计评审
## 决定细化为 [enum SaveResult] 枚举，使调用方可区分 WRITE_ERROR / DISK_FULL /
## VALIDATION_ERROR 等具体失败原因。非静默失败——符合 ADR 意图。
func _atomic_write(path: String, data: Dictionary) -> int:
	if _is_writing:
		push_warning("SaveLoadSystem: 写入进行中——自动存档排队等待")
		_pending_autosave = true
		return SaveResult.WRITE_ERROR

	_is_writing = true

	# 阶段 2：确保目录 + 写入 .tmp
	if not _ensure_dir(path):
		_is_writing = false
		return SaveResult.WRITE_ERROR

	var tmp_path := path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveLoadSystem: 无法打开 .tmp 文件: %s" % tmp_path)
		_is_writing = false
		return SaveResult.WRITE_ERROR

	var json_str := _serialize_to_json(data)
	if not f.store_string(json_str):
		push_error("SaveLoadSystem: store_string 写入失败: %s" % tmp_path)
		f.close()
		_is_writing = false
		return SaveResult.WRITE_ERROR
	f.close()

	# 阶段 3：备份旧文件
	var bak_path := path + ".bak"
	if FileAccess.file_exists(path):
		# rename_absolute 旧→.bak，失败可接受（旧文件仍在）
		DirAccess.rename_absolute(path, bak_path)

	# 阶段 4：原子 rename .tmp → 规范文件名（带 Windows 重试）
	if not _rename_with_retry(tmp_path, path):
		# 清理残留 .tmp 文件
		if FileAccess.file_exists(tmp_path):
			DirAccess.remove_absolute(tmp_path)
		# 恢复 .bak（如果存在）
		if FileAccess.file_exists(bak_path):
			DirAccess.rename_absolute(bak_path, path)
		push_error("SaveLoadSystem: rename_absolute 全部重试失败: %s → %s" % [tmp_path, path])
		_is_writing = false
		return SaveResult.WRITE_ERROR

	# 阶段 5：删除 .bak
	if FileAccess.file_exists(bak_path):
		var rm_err := DirAccess.remove_absolute(bak_path)
		if rm_err != OK:
			push_warning("SaveLoadSystem: 无法删除 .bak: %s（无害——下次写入覆盖）" % bak_path)

	_is_writing = false

	# 处理排队的自动存档
	if _pending_autosave:
		_pending_autosave = false
		# Story 004 实现——自动存档触发回调，当前仅重置标志位

	return SaveResult.SUCCESS


## === Story 003: 存档容器 schema + 完整性校验 =====================================

## 当前存档格式版本——递增整数，唯一驱动迁移链的字段。
## 引入 ADR-0002 定义的第 1 版存档容器格式。
const CURRENT_SCHEMA_VERSION: int = 1

## 迁移函数注册表——键为迁移前的 schema_version，值为迁移函数（纯函数 Dictionary → Dictionary）。
## [br]每个函数是纯函数：接收完整存档容器，返回修改后的存档容器。[br]
## [br]使用 [code]static var[/code]（非 const）以允许测试注入迁移函数。[br]
## 当前为初始 schema——无迁移。首次需要升级时追加条目：[br]
## [code]  1: _migrate_v1_to_v2,[/code]  # 例如：card_instance 新增 breakthrough_layers 字段[br]
## [code]  2: _migrate_v2_to_v3,[/code]  # 例如：story_flags 从 Array 改为 Dictionary[br]
## [br][b]⚠️ 测试[/b]: 通过 [code]SaveLoadSystem.MIGRATIONS[0] = some_func[/code] 注入测试用迁移函数。
static var MIGRATIONS: Dictionary[int, Callable] = {}


## 构造完整存档容器——包含全部 7 个顶层字段。
##
## [b]参数[/b]: [param serialized_gsm] GSM.serialize() 的输出（Dictionary）。[br]
## [b]参数[/b]: [param meta] 展示用元信息——缺失字段以默认值填充。[br]
## [b]返回[/b]: 完整存档容器 Dictionary，含 schema_version / version / timestamp /
##          playtime_seconds / meta / game_state / complete。[br]
## [br][b]⚠️ ADR-0002 规则[/b]: [code]version[/code] 为语义化版本字符串——仅用于
## 面向用户的展示，不参与任何迁移逻辑判断。[br][b]playtime_seconds[/b] 从
## [code]serialized_gsm.session.playtime_seconds[/code] 提取，缺失时默认 0。
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


## 完整性校验——检查存档容器是否包含全部必填字段和完整性标记。
##
## 三项检查（短路求值）：[br]
## 1. [code]schema_version[/code] 字段必须存在。[br]
## 2. [code]game_state[/code] 字段必须存在且类型为 Dictionary。[br]
## 3. [code]complete[/code] 标记必须存在且为 true——纵深防御，原子 rename 的主策略
##    补充。[br]
## [br][b]返回[/b]: 全部检查通过时返回 true，任一项失败时调用 [method push_error] 并返回 false。
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


## 版本校验——检查存档的 schema_version 是否与当前版本兼容。
##
## [b]规则[/b]: [code]save_schema > CURRENT_SCHEMA_VERSION[/code] →
## 返回 VERSION_MISMATCH 错误。[br]
## [code]save_schema <= CURRENT_SCHEMA_VERSION[/code] → 返回 ok。[br]
## [br][b]⚠️ ADR-0002 禁止[/b]: 绝不让 [code]schema_version > CURRENT[/code] 的存档
## 静默加载——必须拒绝并返回 VERSION_MISMATCH。[br]
## [br][b]注意[/b]: [method _migrate_if_needed] 中也包含 VERSION_MISMATCH 检查（L525-L530）——
## 作为纵深防御的第二道防线，以防调用方绕过本方法直接调用迁移入口。
## 两处的错误字典结构必须保持同步。修改一处时务必同步另一处。[br]
## [br][b]返回[/b]: [code]{"ok": true}[/code] 或
## [code]{"error": "VERSION_MISMATCH", "save_schema": int, "current_schema": int}[/code]
func _validate_version(data: Dictionary) -> Dictionary:
	var save_schema: int = data.get("schema_version", 0)
	if save_schema > CURRENT_SCHEMA_VERSION:
		return {
			"error": "VERSION_MISMATCH",
			"save_schema": save_schema,
			"current_schema": CURRENT_SCHEMA_VERSION
		}
	return {"ok": true}


## 完整读取管线——委托 [method _parse_json_file] 处理 JSON 解析，追加 [method _validate_save_data]。
##
## 仅读取规范文件名（忽略同目录下的 .tmp 和 .bak 文件）。[br]
## 读取流程（3 阶段）：[br]
## 1. [method _parse_json_file] → 存在性检查 + 读取 + JSON 解析 + 类型检查。[br]
## 2. [method _validate_save_data] → 完整性校验。[br]
## 3. 校验通过 → 返回存档数据。[br]
## [br]
## [b]参数[/b]: [param path] 规范文件完整路径——调用方负责构造正确路径。[br]
## [b]返回[/b]: [code]{"result": LoadResult, "data": Dictionary}[/code]。[br]
## [param result] 为 [enum LoadResult.SUCCESS] 时 [param data] 包含存档容器全部字段。
func _atomic_read(path: String) -> Dictionary:
	# 阶段 1：委托 _parse_json_file 处理读取 + JSON 解析（复用 Story 001 管线）
	var parsed := _parse_json_file(path)
	if parsed["result"] != LoadResult.SUCCESS:
		return parsed

	# 阶段 2：完整性校验
	if not _validate_save_data(parsed["data"]):
		return {"result": LoadResult.CORRUPTED, "data": {}}

	# 阶段 3：返回校验通过的存档数据
	return parsed


## === Story 004: 信号声明 =========================================================

## 存档完成信号——保存成功或失败后发射。
## [br][param slot_type] 槽位类型；[param slot_id] 槽位编号；
## [param success] true 表示保存成功。
signal save_completed(slot_type: SaveSlotType, slot_id: int, success: bool)

## 读档开始信号——在读档流程启动前发射，供 UI 显示加载提示。
signal load_started(slot_type: SaveSlotType, slot_id: int)

## 读档完成信号——成功或失败后发射。[br]
## [param success] true 表示读档成功。
signal load_completed(success: bool)

## 存档损坏信号——读档时检测到存档数据不可恢复时发射。
## [br][param reason] 损坏原因（DESERIALIZE_ERROR / CORRUPTED 等字符串）。
signal save_corrupted(slot_type: SaveSlotType, slot_id: int, reason: String)

## 跨局进度保存信号——[method load_progression] 因文件损坏重置默认值后发射。
## [br][param success] false 表示 progression.dat 损坏已重置为默认值。
signal progression_saved(success: bool)


## === Story 004: 依赖注入 ==========================================================

## 游戏状态管理器引用——通过 [method set_dependencies] 注入，或 Autoload #1 回退。
var _gsm: Node = null

## 卡牌系统引用——通过 [method set_dependencies] 注入，CardSystem 未实现时为 null。
var _card_system: Node = null


## 设置依赖引用——注入 GSM 和 CardSystem 以便测试 mock。
## [br]不传参数则保留已有引用（测试中可多次调用覆盖）。
func set_dependencies(gsm: Node = null, card_system: Node = null) -> void:
	if gsm != null:
		_gsm = gsm
	if card_system != null:
		_card_system = card_system


## 获取当前使用的 GSM 引用——注入对象优先，否则回退到 Autoload #1 GameStateManager。
func _get_gsm() -> Node:
	if _gsm != null:
		return _gsm
	return GameStateManager


## 获取当前使用的 CardSystem 引用——注入对象优先，未注入时返回 null（前向兼容）。
func _get_card_system() -> Node:
	if _card_system != null:
		return _card_system
	return null


## === Story 004: meta.json 管理 ====================================================

## 由槽位类型和编号生成唯一键——用于 meta.json 中 slots 字典的键。
##
## [b]格式[/b]: [code]"autosave_0"[/code] / [code]"manual_1"[/code] / [code]"snapshot_0"[/code]。[br]
## 注意：MANUAL 使用 slot_id 区分 3 个槽位（1/2/3）。
func _slot_key(slot_type: SaveSlotType, slot_id: int) -> String:
	match slot_type:
		SaveSlotType.AUTOSAVE:
			return "autosave_0"
		SaveSlotType.MANUAL:
			return "manual_%d" % slot_id
		SaveSlotType.SNAPSHOT:
			return "snapshot_0"
		_:
			return "unknown"


## 加载 meta.json——文件不存在或解析失败时返回带空 slots 字典的默认值。
func _load_meta_json() -> Dictionary:
	var meta_path := _get_save_root() + "meta.json"
	var result := _parse_json_file(meta_path)
	if result["result"] != LoadResult.SUCCESS:
		return {"slots": {}}
	return result["data"]


## 写入 meta.json——直接覆盖（非关键数据，不使用原子写入管线）。
## [br]失败时调用 [method push_error] 记录。
func _write_meta_json(data: Dictionary) -> void:
	var meta_path := _get_save_root() + "meta.json"
	_ensure_dir(meta_path)
	var f := FileAccess.open(meta_path, FileAccess.WRITE)
	if f == null:
		push_error("SaveLoadSystem: 无法写入 meta.json")
		return
	var json_str := _serialize_to_json(data)
	f.store_string(json_str)
	f.close()


## 更新 meta.json 中指定槽位的元信息——加载 → 修改 → 写回。
func _update_meta_json(slot_type: SaveSlotType, slot_id: int, meta: Dictionary) -> void:
	var meta_data := _load_meta_json()
	if not meta_data.has("slots"):
		meta_data["slots"] = {}
	var key := _slot_key(slot_type, slot_id)
	meta_data["slots"][key] = {
		"name": meta.get("player_name", ""),
		"timestamp": Time.get_datetime_string_from_system(true),
		"realm": meta.get("realm", ""),
		"playtime": meta.get("playtime_seconds", 0),
		"exists": true,
	}
	_write_meta_json(meta_data)


## 标记槽位为空——删除存档后更新 meta.json 对应条目。
func _mark_slot_empty(slot_type: SaveSlotType, slot_id: int) -> void:
	var meta_data := _load_meta_json()
	if not meta_data.has("slots"):
		meta_data["slots"] = {}
	var key := _slot_key(slot_type, slot_id)
	meta_data["slots"][key] = {"exists": false}
	_write_meta_json(meta_data)


## === Story 005: 迁移链 ============================================================

## 存档迁移入口——基于 [member CURRENT_SCHEMA_VERSION] 和 [member MIGRATIONS] 注册表
## 执行逐级迁移链。
##
## 迁移规则（ADR-0002）：[br]
## - [code]save_schema == CURRENT[/code] → 直接返回 data（无迁移）。[br]
## - [code]save_schema < CURRENT[/code] → 从 save_schema 开始逐级执行迁移函数，每步后
##   [code]data["schema_version"][/code] 递增 1，直到等于 CURRENT。[br]
## - [code]save_schema > CURRENT[/code] → 返回 [code]{"error": "VERSION_MISMATCH", ...}[/code]。[br]
## - 迁移链中缺少某版本对应函数 → 返回 [code]{"error": "MIGRATION_MISSING", ...}[/code]。[br]
## - data 中无 [code]schema_version[/code] 字段 → [code]save_schema = 0[/code]（默认值）。[br]
## [br]
## [b]参数[/b]: [param data] 已读入并通过校验的存档容器。[br]
## [b]返回[/b]: 迁移后的存档容器——或包含 error 键的错误字典。[br]
## [br][b]⚠️ ADR-0002 规则[/b]: 迁移函数必须是纯函数 [code]Dictionary → Dictionary[/code]——
## 不访问 GSM、不读写磁盘、无副作用。
func _migrate_if_needed(data: Dictionary) -> Dictionary:
	var save_schema: int = data.get("schema_version", 0)

	# AC-006：版本高于当前——拒绝加载
	if save_schema > CURRENT_SCHEMA_VERSION:
		return {
			"error": "VERSION_MISMATCH",
			"save_schema": save_schema,
			"current_schema": CURRENT_SCHEMA_VERSION
		}

	# AC-003/AC-004：逐级执行迁移链
	while save_schema < CURRENT_SCHEMA_VERSION:
		if not MIGRATIONS.has(save_schema):
			# AC-005：迁移链中缺少对应版本函数
			return {
				"error": "MIGRATION_MISSING",
				"from": save_schema
			}
		data = MIGRATIONS[save_schema].call(data)
		assert(typeof(data) == TYPE_DICTIONARY, "迁移函数 %d 必须返回 Dictionary" % save_schema)
		save_schema += 1
		data["schema_version"] = save_schema

	return data


## === Story 004: 公共 API ==========================================================

## [b]保存游戏[/b]——将已序列化的 GSM 数据封装为存档容器并原子写入。
##
## [b]参数[/b]: [br]
##   [param slot_type] 槽位类型——AUTOSAVE / MANUAL / SNAPSHOT。[br]
##   [param slot_id] 槽位编号——MANUAL 时为 1-3，其他类型忽略。[br]
##   [param data] 调用方已序列化的 GSM 数据——必须是 [method GameStateManager.serialize] 的输出。
##     必须仅包含 JSON 兼容类型（String 键、int/float/String/bool/null 值、嵌套 Array/Dictionary）。[br]
##   [param meta] 展示用元信息字典——参见 [method _build_save_container]。[br]
## [b]返回[/b]: [enum SaveResult]——SUCCESS 或错误码。[br]
## [br][b]信号[/b]: 保存完成后发射 [signal save_completed]。[br]
## [br][b]⚠️ AC-002[/b]: data 中包含非 JSON 兼容类型（Vector2/Color 等）→
## [method JSON.stringify] 会失败 → 返回 [enum SaveResult.VALIDATION_ERROR]。
func save_game(slot_type: SaveSlotType, slot_id: int = 0,
               data: Dictionary = {}, meta: Dictionary = {}) -> int:
	# AC-002：类型校验——data 必须仅含 JSON 兼容类型
	if not data.is_empty() and not _is_json_compatible(data):
		push_error("SaveLoadSystem: save_game 数据类型校验失败——data 包含非 JSON 兼容类型")
		save_completed.emit(slot_type, slot_id, false)
		return SaveResult.VALIDATION_ERROR

	var container := _build_save_container(data, meta)
	var path := _save_path(slot_type, slot_id)
	var result := _atomic_write(path, container)

	# AC-014/AC-015：发射 save_completed 信号
	save_completed.emit(slot_type, slot_id, result == SaveResult.SUCCESS)

	# AC-016：保存成功后更新 meta.json
	if result == SaveResult.SUCCESS:
		_update_meta_json(slot_type, slot_id, meta)

	return result


## [b]读取游戏[/b]——从指定槽位读取存档并恢复完整游戏状态。
##
## 完整流程（5 阶段）：[br]
##   1. 发射 [signal load_started] 信号。[br]
##   2. [method _atomic_read] 读取 + 完整性校验。[br]
##   3. [method _validate_version] 版本校验 + [method _migrate_if_needed] 迁移。[br]
##   4. [method GameStateManager.deserialize] 反序列化 game_state。[br]
##   5. [method CardSystem.reconstitute_instances] 重构 CardInstance（前向兼容）。[br]
## [br]
## [b]返回[/b]: [code]{"result": LoadResult, "data": Dictionary}[/code]。成功时 data 包含存档容器全部字段。[br]
## [br][b]信号[/b]: [signal load_started] + [signal load_completed]。[br]
## [b]信号（错误路径）[/b]: [signal save_corrupted]（DESERIALIZE_ERROR 时）。
func load_game(slot_type: SaveSlotType, slot_id: int = 0) -> Dictionary:
	# AC-003：发射 load_started 信号
	load_started.emit(slot_type, slot_id)

	var path := _save_path(slot_type, slot_id)
	var read_result := _atomic_read(path)
	if read_result["result"] != LoadResult.SUCCESS:
		load_completed.emit(false)
		return read_result

	var data: Dictionary = read_result["data"]

	# 版本校验
	var version_result := _validate_version(data)
	if version_result.has("error"):
		load_completed.emit(false)
		return {"result": LoadResult.VERSION_MISMATCH, "data": data}

	# 迁移
	data = _migrate_if_needed(data)
	if data.has("error"):
		push_error("SaveLoadSystem: 迁移失败——%s (from=%d)" % [data["error"], data.get("from", data.get("save_schema", -1))])
		save_corrupted.emit(slot_type, slot_id, data.get("error", "MIGRATION_ERROR"))
		load_completed.emit(false)
		return {"result": LoadResult.DESERIALIZE_ERROR, "data": data}

	# AC-003：GSM 反序列化
	var gsm: Node = _get_gsm()
	if gsm == null or not gsm.has_method("deserialize"):
		push_error("SaveLoadSystem: GSM 不可用——无法反序列化")
		save_corrupted.emit(slot_type, slot_id, "DESERIALIZE_ERROR")
		load_completed.emit(false)
		return {"result": LoadResult.DESERIALIZE_ERROR, "data": {}}
	if not gsm.deserialize(data["game_state"]):
		# AC-004：GSM.deserialize 返回 false
		save_corrupted.emit(slot_type, slot_id, "DESERIALIZE_ERROR")
		load_completed.emit(false)
		return {"result": LoadResult.DESERIALIZE_ERROR, "data": {}}

	# CardInstance 重构（ADR-0006 契约）——前向兼容空检查
	var cs: Node = _get_card_system()
	if cs != null and cs.has_method("reconstitute_instances"):
		var owned_cards: Array = data["game_state"].get("collection", {}).get("owned_cards", [])
		cs.reconstitute_instances(owned_cards)

	# 清理旧战斗快照
	clear_battle_snapshot()

	load_completed.emit(true)
	return {"result": LoadResult.SUCCESS, "data": data}


## [b]删除存档[/b]——删除指定槽位的存档文件并更新 meta.json。
##
## [b]返回[/b]: [code]true[/code]——文件不存在也返回 true（幂等：视同"已删除"）。[br]
## [br][b]⚠️ AC-005[/b]: 文件不存在 → 返回 true（不视为错误）；文件存在但删除失败 → 返回 false。
func delete_save(slot_type: SaveSlotType, slot_id: int = 0) -> bool:
	var path := _save_path(slot_type, slot_id)
	if not FileAccess.file_exists(path):
		_mark_slot_empty(slot_type, slot_id)
		return true

	var err := DirAccess.remove_absolute(path)
	if err != OK:
		push_error("SaveLoadSystem: 删除存档失败: %s (err=%d)" % [path, err])
		return false

	_mark_slot_empty(slot_type, slot_id)
	return true


## [b]获取槽位元信息[/b]——仅读取存档容器的 meta 子字典，不读取 game_state。
##
## [b]参数[/b]: [param slot_type] 槽位类型；[param slot_id] 槽位编号。[br]
## [b]返回[/b]: 短格式 Dictionary——[code]{"exists": true/false, "name": "...",
##          "timestamp": "...", "realm": "...", "playtime": ...}[/code]。[br]
## 文件不存在时返回 [code]{"exists": false}[/code]。[br]
## [br][b]⚠️ AC-006[/b]: 不读取 game_state——仅解析存档容器的 meta 和顶层元数据。
func get_slot_meta(slot_type: SaveSlotType, slot_id: int = 0) -> Dictionary:
	var path := _save_path(slot_type, slot_id)
	var read_result := _atomic_read(path)
	if read_result["result"] != LoadResult.SUCCESS:
		return {"exists": false}

	var data: Dictionary = read_result["data"]
	var meta: Dictionary = data.get("meta", {})
	return {
		"exists": true,
		"name": meta.get("player_name", ""),
		"timestamp": data.get("timestamp", ""),
		"realm": meta.get("realm", ""),
		"playtime": data.get("playtime_seconds", 0),
	}


## [b]列出所有槽位[/b]——从 meta.json 读取全部槽位状态。
##
## [b]返回[/b]: [code]Array[Dictionary][/code]，每项含 [code]slot_type[/code] / [code]slot_id[/code] /
##          [code]exists[/code] / [code]name[/code] / [code]timestamp[/code] /
##          [code]realm[/code] / [code]playtime[/code]。[br]
## [br][b]⚠️ AC-007[/b]: 从 meta.json 而非扫描文件系统读取——仅返回已知槽位。
func list_slots() -> Array[Dictionary]:
	var meta_data := _load_meta_json()
	var slots: Dictionary = meta_data.get("slots", {})
	var result: Array[Dictionary] = []

	# 遍历所有已知槽位：autosave_0, manual_1-3, snapshot_0
	var known_keys := ["autosave_0", "manual_1", "manual_2", "manual_3", "snapshot_0"]
	for key in known_keys:
		var slot_info: Dictionary = slots.get(key, {"exists": false})
		var slot_type: int = SaveSlotType.AUTOSAVE
		var slot_id: int = 0
		if key.begins_with("manual_"):
			slot_type = SaveSlotType.MANUAL
			slot_id = int(key.trim_prefix("manual_"))
		elif key == "snapshot_0":
			slot_type = SaveSlotType.SNAPSHOT

		result.append({
			"slot_type": slot_type,
			"slot_id": slot_id,
			"exists": slot_info.get("exists", false),
			"name": slot_info.get("name", ""),
			"timestamp": slot_info.get("timestamp", ""),
			"realm": slot_info.get("realm", ""),
			"playtime": slot_info.get("playtime", 0),
		})

	return result


## [b]加载跨局元进度[/b]——读取 progression.dat 获取跨存档的持久进度数据。
##
## [b]返回[/b]: 进度 Dictionary。[br]
## 文件不存在时返回默认值字典（全部域从零初始化）——不报错。[br]
## [br][b]⚠️ AC-008[/b]: 首次启动 progression.dat 不存在 → 返回默认值。
## [br][b]⚠️ AC-009[/b]: progression.dat 损坏（非法 JSON）→ [method push_error] + 返回默认值 +
## 发射 [signal progression_saved](false) 信号。
func load_progression() -> Dictionary:
	const DEFAULTS := {
		"highest_realm": "",
		"total_playtime_seconds": 0,
		"unlocked_cards": [],
		"unlocked_talents": [],
		"achievements": {},
		"statistics": {
			"total_battles": 0,
			"total_victories": 0,
			"total_deaths": 0,
			"highest_damage": 0,
		},
	}

	var path := _get_save_root() + "progression.dat"
	var read_result := _parse_json_file(path)
	if read_result["result"] == LoadResult.FILE_NOT_FOUND:
		return DEFAULTS.duplicate(true)

	if read_result["result"] != LoadResult.SUCCESS:
		# AC-009：损坏 JSON → push_error + 默认值 + 信号
		push_error("SaveLoadSystem: progression.dat 损坏——重置为默认值")
		progression_saved.emit(false)
		return DEFAULTS.duplicate(true)

	return read_result["data"]


## [b]创建战斗快照[/b]——在进入战斗前保存当前游戏状态。
##
## [b]参数[/b]: [param data] 已序列化的 GSM 数据（由调用方调用 [method GameStateManager.serialize] 获得）。[br]
## [b]返回[/b]: [code]true[/code] 表示快照保存成功。[br]
## [br][b]⚠️ AC-010[/b]: 内部调用 [method _build_save_container] + [method _atomic_write]。
func create_battle_snapshot(data: Dictionary) -> bool:
	var path := _save_path(SaveSlotType.SNAPSHOT)
	var container := _build_save_container(data, {})
	var result := _atomic_write(path, container)
	return result == SaveResult.SUCCESS


## [b]恢复战斗快照[/b]——读入战斗前保存的状态并立即清除快照文件。
##
## [b]返回[/b]: [code]{"result": LoadResult, "data": Dictionary}[/code]。[br]
## 文件存在且校验通过 → 返回 SUCCESS + 调用 [method clear_battle_snapshot] 删除文件。[br]
## [br][b]⚠️ AC-011[/b]: 成功后自动清除快照文件（防止重复恢复）。
## [br][b]⚠️ AC-012[/b]: 文件不存在 → 返回 [code]{"result": FILE_NOT_FOUND}[/code]。
func restore_battle_snapshot() -> Dictionary:
	var path := _save_path(SaveSlotType.SNAPSHOT)
	var read_result := _atomic_read(path)
	if read_result["result"] != LoadResult.SUCCESS:
		return read_result

	clear_battle_snapshot()
	return read_result


## [b]清除战斗快照[/b]——删除 snapshot/pre_battle.json 文件。
##
## [b]⚠️ AC-013[/b]: 静默执行——文件不存在时不报错，不发射信号。
func clear_battle_snapshot() -> void:
	var path := _save_path(SaveSlotType.SNAPSHOT)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)