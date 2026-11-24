extends "res://src/foundation/save_load/contract.gd"
## SaveLoadSystem 原子 IO 层 —— [b]JSON 引擎 + 路径解析 + 原子写盘[/b]。[br]
## [br][b]本层职责[/b]：把「一份 Dictionary 怎么安全地变成一个存档文件」这件事做完整——
## JSON 解析（区分合法 null 与解析错误）、类型兼容校验、路径解析、目录确保、
## Windows 重试与 5 阶段原子写盘（.tmp 双写 + rename + .bak 备份）。[br]
## [br][b]为什么单独一层[/b]：这段是全库唯一的落盘实现，与「容器长什么样」（上层）、
## 「什么时候该自动存」（链尾）是两件事；原文件 1027 行严重超 300 行软上限
## （.claude/docs/coding-standards.md）。[br]
## [br][b]成员名逐字保留[/b]：Story 002 的验收（AC-001 ~ AC-011）直接写在
## [method _atomic_write] / [method _rename_with_retry] / [method _ensure_dir] /
## [method _is_writing] 这些私有面上，探针实测私有面经继承链与 [method Object.get] /
## [method Object.set] 都照旧解析，故用例无感。[br]
## [br][b]⚠️ ADR-0002 强制规则[/b]：解析存档必须使用 [method JSON.new].parse()——
## 绝不使用 [method JSON.parse_string]（无法区分合法 null 和解析错误）。[br]
## [br]来源: ADR-0002 §JSON + 原子写入、.claude/docs/coding-standards.md §文件行数限制。

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
