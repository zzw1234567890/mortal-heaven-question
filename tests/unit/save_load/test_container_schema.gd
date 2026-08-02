extends GutTest
## Story 003 验收测试：存档容器 schema + "complete" 标记 + 完整性校验。
##
## 覆盖 AC-001 到 AC-016（含 AC-014.5）全部验收标准。
## 此 Story 类型为 Integration——测试证据为阻塞项（BLOCKING）。
##
## 每个测试通过 preload + .new() 创建独立 SaveLoadSystem 实例。
## 测试文件写入 user:// 沙盒路径，after_each() 清理。

const SLS := preload("res://src/foundation/save_load_system.gd")

var sls: Node = null
var _test_files: Array[String] = []


func before_each() -> void:
	sls = SLS.new()
	sls._ready()
	_test_files.clear()


func after_each() -> void:
	# 清理本测试创建的临时文件及其父目录
	for path in _test_files:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		# 清理同目录下的 .tmp / .bak 残留
		if FileAccess.file_exists(path + ".tmp"):
			DirAccess.remove_absolute(path + ".tmp")
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		# 尝试删除目录（如果为空）
		var dir := path.get_base_dir()
		if DirAccess.dir_exists_absolute(dir):
			DirAccess.remove_absolute(dir)
	if sls != null:
		sls.free()
		sls = null


func _make_test_file(filename: String, content: String) -> String:
	## 在 user:// 下创建测试文件并写入内容。返回完整路径。
	var path := "user://%s" % filename
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()
	_test_files.append(path)
	return path


# ═══════════════════════════════════════════════════════════════════════════════
# AC-001 ~ AC-008: _build_save_container 构造完整存档容器
# ═══════════════════════════════════════════════════════════════════════════════

func test_build_save_container_all_fields() -> void:
	# Arrange
	var serialized_gsm := {
		"session": {"playtime_seconds": 7200},
		"player": {"hp": 100},
	}
	var meta := {
		"player_name": "测试修士",
		"realm": "金丹",
		"chapter": 3,
		"map_name": "碎星外环",
		"deck_size": 28,
		"current_scene": "exploration",
		"current_scene_id": 5,
	}

	# Act
	var container: Dictionary = sls._build_save_container(serialized_gsm, meta)

	# Assert — 7 个顶层字段均存在
	assert_eq(container.size(), 7, "存档容器应包含 7 个顶层字段")
	assert_eq(int(container["schema_version"]), SLS.CURRENT_SCHEMA_VERSION,
			"schema_version 应为 CURRENT_SCHEMA_VERSION（1）")
	assert_eq(container["version"], "1.0.0", "version 应为展示用语义化版本字符串")
	assert_true(container["timestamp"] is String, "timestamp 应为字符串")
	assert_true(container["timestamp"].length() > 0, "timestamp 不应为空")
	var regex := RegEx.new()
	regex.compile("^\\d{4}-\\d{2}-\\d{2}T\\d{2}:\\d{2}:\\d{2}")
	assert_true(regex.search(container["timestamp"]) != null,
			"timestamp 应符合 ISO-8601 格式 (YYYY-MM-DDTHH:MM:SS)")
	assert_eq(int(container["playtime_seconds"]), 7200,
			"playtime_seconds 应从 serialized_gsm.session.playtime_seconds 提取")
	assert_true(container["complete"], "complete 标记必须为 true")

	# Assert — meta 子字典
	var meta_out: Dictionary = container["meta"]
	assert_eq(meta_out["player_name"], "测试修士", "meta.player_name 应保留")
	assert_eq(meta_out["realm"], "金丹", "meta.realm 应保留")
	assert_eq(int(meta_out["chapter"]), 3, "meta.chapter 应保留")
	assert_eq(meta_out["map_name"], "碎星外环", "meta.map_name 应保留")
	assert_eq(int(meta_out["deck_size"]), 28, "meta.deck_size 应保留")
	assert_eq(meta_out["current_scene"], "exploration", "meta.current_scene 应保留")
	assert_eq(int(meta_out["current_scene_id"]), 5, "meta.current_scene_id 应保留")

	# Assert — game_state 为传入的 serialized_gsm
	var gs: Dictionary = container["game_state"]
	assert_eq(int(gs["player"]["hp"]), 100, "game_state 应为传入的 serialized_gsm")


func test_build_save_container_missing_meta_defaults() -> void:
	# Arrange — meta 为空字典，serialized_gsm 无 session 域
	var serialized_gsm := {"player": {"hp": 50}}
	var meta := {}

	# Act
	var container: Dictionary = sls._build_save_container(serialized_gsm, meta)

	# Assert — 缺失字段使用默认值
	assert_eq(int(container["playtime_seconds"]), 0,
			"playtime_seconds 缺失时应默认 0")
	var meta_out: Dictionary = container["meta"]
	assert_eq(meta_out["player_name"], "", "player_name 缺失时应默认空字符串")
	assert_eq(meta_out["realm"], "炼气", "realm 缺失时应默认 '炼气'")
	assert_eq(int(meta_out["chapter"]), 1, "chapter 缺失时应默认 1")
	assert_eq(meta_out["map_name"], "", "map_name 缺失时应默认空字符串")
	assert_eq(int(meta_out["deck_size"]), 0, "deck_size 缺失时应默认 0")
	assert_eq(meta_out["current_scene"], "main_menu",
			"current_scene 缺失时应默认 'main_menu'")
	assert_eq(int(meta_out["current_scene_id"]), 0,
			"current_scene_id 缺失时应默认 0")
	assert_true(container["complete"], "complete 标记必须为 true")
	assert_eq(int(container["schema_version"]), SLS.CURRENT_SCHEMA_VERSION)


func test_build_save_container_meta_boundary_values() -> void:
	# Arrange — meta 包含边界值：0、负数、空字符串、超长字符串
	var serialized_gsm := {
		"session": {"playtime_seconds": -1},
		"player": {"hp": 50},
	}
	var meta := {
		"player_name": "",
		"realm": "炼气",
		"chapter": -1,
		"map_name": "",
		"deck_size": -5,
		"current_scene": "",
		"current_scene_id": -1,
	}

	# Act
	var container: Dictionary = sls._build_save_container(serialized_gsm, meta)

	# Assert — _build_save_container 不负责校验，仅透传值；但应保留 get() 默认值逻辑
	assert_eq(int(container["playtime_seconds"]), -1,
			"playtime_seconds 负数应透传（校验由上层负责）")
	var meta_out: Dictionary = container["meta"]
	assert_eq(meta_out["player_name"], "", "空 player_name 应透传")
	assert_eq(meta_out["realm"], "炼气", "realm 应保留")
	assert_eq(int(meta_out["chapter"]), -1, "负数 chapter 应透传（校验由上层负责）")
	assert_eq(meta_out["map_name"], "", "空 map_name 应透传")
	assert_eq(int(meta_out["deck_size"]), -5, "负数 deck_size 应透传（校验由上层负责）")
	assert_eq(meta_out["current_scene"], "", "空 current_scene 应透传")
	assert_eq(int(meta_out["current_scene_id"]), -1, "负数 current_scene_id 应透传（校验由上层负责）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-012: _validate_save_data 全部字段合法 → 返回 true
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_save_data_all_valid() -> void:
	# Arrange — 一份合法的存档容器
	var data := {
		"schema_version": 1,
		"version": "1.0.0",
		"timestamp": "2026-07-31T12:00:00Z",
		"playtime_seconds": 3600,
		"meta": {"player_name": "test"},
		"game_state": {"player": {"hp": 100}},
		"complete": true,
	}

	# Act
	var result: bool = sls._validate_save_data(data)

	# Assert
	assert_true(result, "合法存档容器应通过校验")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-009: _validate_save_data 缺失 schema_version → push_error + 返回 false
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_save_data_missing_schema_version() -> void:
	# Arrange — 无 schema_version 字段
	var data := {
		"version": "1.0.0",
		"game_state": {},
		"complete": true,
	}

	# Act
	var result: bool = sls._validate_save_data(data)

	# Assert
	assert_false(result, "缺失 schema_version 应返回 false")
	assert_push_error_count(1, "应产生一次 push_error 报告缺失 schema_version")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-010: _validate_save_data 缺失 game_state → push_error + 返回 false
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_save_data_missing_game_state() -> void:
	# Arrange — 无 game_state 字段
	var data := {
		"schema_version": 1,
		"complete": true,
	}

	# Act
	var result: bool = sls._validate_save_data(data)

	# Assert
	assert_false(result, "缺失 game_state 应返回 false")
	assert_push_error_count(1, "应产生一次 push_error 报告缺失 game_state")


func test_validate_save_data_game_state_not_dict() -> void:
	# Arrange — game_state 存在但类型为 String（非 Dictionary）
	var data := {
		"schema_version": 1,
		"game_state": "not_a_dictionary",
		"complete": true,
	}

	# Act
	var result: bool = sls._validate_save_data(data)

	# Assert
	assert_false(result, "game_state 为 String 时应返回 false")
	assert_push_error_count(1, "应产生一次 push_error 报告 game_state 类型无效")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-011: _validate_save_data 缺失 complete 标记 → push_error + 返回 false
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_save_data_missing_complete() -> void:
	# Arrange — 无 complete 字段
	var data := {
		"schema_version": 1,
		"game_state": {},
	}

	# Act
	var result: bool = sls._validate_save_data(data)

	# Assert
	assert_false(result, "缺失 complete 字段应返回 false")
	assert_push_error_count(1, "应产生一次 push_error 报告缺失 complete 标记")


func test_validate_save_data_complete_false() -> void:
	# Arrange — complete 存在但为 false（边界情况）
	var data := {
		"schema_version": 1,
		"game_state": {},
		"complete": false,
	}

	# Act
	var result: bool = sls._validate_save_data(data)

	# Assert
	assert_false(result, "complete 为 false 时应返回 false")
	assert_push_error_count(1, "应产生一次 push_error 报告 complete 不为 true")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-013: _atomic_read 完整读取流程——存在性检查 → 读文件 → 解析 → 类型检查 → 校验
# ═══════════════════════════════════════════════════════════════════════════════

func test_atomic_read_success() -> void:
	# Arrange — 创建合法存档文件
	var json_str := JSON.stringify({
		"schema_version": 1,
		"version": "1.0.0",
		"timestamp": "2026-07-31T12:00:00Z",
		"playtime_seconds": 1800,
		"meta": {"player_name": "测试", "realm": "筑基"},
		"game_state": {"player": {"hp": 80}, "collection": {"owned_cards": []}},
		"complete": true,
	}, "\t")
	var path := _make_test_file("test_atomic_read_success.json", json_str)

	# Act
	var result: Dictionary = sls._atomic_read(path)

	# Assert
	assert_eq(result["result"], SLS.LoadResult.SUCCESS, "合法存档应返回 SUCCESS")
	var data: Dictionary = result["data"]
	assert_eq(int(data["schema_version"]), 1, "schema_version 应为 1")
	assert_eq(data["version"], "1.0.0", "version 应为 1.0.0")
	assert_eq(int(data["playtime_seconds"]), 1800, "playtime_seconds 应保留")
	assert_true(data["complete"], "complete 应为 true")
	var meta: Dictionary = data["meta"]
	assert_eq(meta["player_name"], "测试", "meta.player_name 应保留")
	assert_eq(meta["realm"], "筑基", "meta.realm 应保留")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-013: _atomic_read 文件不存在 → FILE_NOT_FOUND
# ═══════════════════════════════════════════════════════════════════════════════

func test_atomic_read_file_not_found() -> void:
	# Arrange — 不存在的文件路径
	var path := "user://nonexistent_save_003_test.json"

	# Act
	var result: Dictionary = sls._atomic_read(path)

	# Assert
	assert_eq(result["result"], SLS.LoadResult.FILE_NOT_FOUND,
			"不存在的文件应返回 FILE_NOT_FOUND")
	assert_not_null(result["data"], "data 应为非 null（空字典）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-013: _atomic_read JSON 解析成功但解析结果为非 Object → CORRUPTED
# ═══════════════════════════════════════════════════════════════════════════════

func test_atomic_read_json_array_not_object() -> void:
	# Arrange — 合法 JSON 但顶层为 Array 而非 Object（触发 stage 4 类型检查）
	var path := _make_test_file("test_json_array.json", "[1, 2, 3]")

	# Act
	var result: Dictionary = sls._atomic_read(path)

	# Assert
	assert_eq(result["result"], SLS.LoadResult.CORRUPTED,
			"顶层非 Object (Array) 应返回 CORRUPTED")


func test_atomic_read_json_string_not_object() -> void:
	# Arrange — 合法 JSON 但顶层为 String（非 Object）
	var path := _make_test_file("test_json_string.json", '"just a string"')

	# Act
	var result: Dictionary = sls._atomic_read(path)

	# Assert
	assert_eq(result["result"], SLS.LoadResult.CORRUPTED,
			"顶层非 Object (String) 应返回 CORRUPTED")


func test_atomic_read_json_number_not_object() -> void:
	# Arrange — 合法 JSON 但顶层为 Number（非 Object）
	var path := _make_test_file("test_json_number.json", "42")

	# Act
	var result: Dictionary = sls._atomic_read(path)

	# Assert
	assert_eq(result["result"], SLS.LoadResult.CORRUPTED,
			"顶层非 Object (Number) 应返回 CORRUPTED")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-013: _atomic_read JSON 解析失败 → CORRUPTED
# ═══════════════════════════════════════════════════════════════════════════════

func test_atomic_read_corrupted_json() -> void:
	# Arrange — 非法 JSON 内容
	var path := _make_test_file("test_corrupted_003.json", "{this is not json at all!!!")

	# Act
	var result: Dictionary = sls._atomic_read(path)

	# Assert
	assert_eq(result["result"], SLS.LoadResult.CORRUPTED,
			"非法 JSON 应返回 CORRUPTED")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-014.5: _atomic_read JSON 解析成功但校验失败（缺 complete）→ CORRUPTED
# ═══════════════════════════════════════════════════════════════════════════════

func test_atomic_read_valid_json_missing_complete_marker() -> void:
	# Arrange — 合法 JSON 但缺少 complete 字段
	var json_str := JSON.stringify({
		"schema_version": 1,
		"game_state": {},
	}, "\t")
	var path := _make_test_file("test_no_complete.json", json_str)

	# Act
	var result: Dictionary = sls._atomic_read(path)

	# Assert
	assert_eq(result["result"], SLS.LoadResult.CORRUPTED,
			"合法 JSON 但缺少 complete 标记应返回 CORRUPTED")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-016: _validate_version — save_schema <= CURRENT → 返回 {ok: true}
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_version_ok() -> void:
	# Arrange — schema_version == CURRENT（典型场景）
	var data := {"schema_version": SLS.CURRENT_SCHEMA_VERSION, "game_state": {}, "complete": true}

	# Act
	var result: Dictionary = sls._validate_version(data)

	# Assert
	assert_true(result.has("ok"), "版本兼容时应返回包含 ok 键的字典")
	assert_true(result["ok"], "ok 值应为 true")

	# 边界情况——schema_version < CURRENT（由迁移链处理——_validate_version 不拒绝）
	var old_data := {"schema_version": 0, "game_state": {}, "complete": true}
	var old_result: Dictionary = sls._validate_version(old_data)
	assert_true(old_result.has("ok"),
			"schema_version < CURRENT 也应返回 ok（迁移链负责升级）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-015: _validate_version — save_schema > CURRENT → VERSION_MISMATCH
# ═══════════════════════════════════════════════════════════════════════════════

func test_validate_version_mismatch() -> void:
	# Arrange — schema_version 远高于 CURRENT
	var data := {"schema_version": 99, "game_state": {}, "complete": true}

	# Act
	var result: Dictionary = sls._validate_version(data)

	# Assert
	assert_true(result.has("error"), "版本不兼容时应返回包含 error 键的字典")
	assert_eq(result["error"], "VERSION_MISMATCH",
			"error 值应为 VERSION_MISMATCH")
	assert_eq(int(result["save_schema"]), 99,
			"save_schema 应反映存档中的实际值")
	assert_eq(int(result["current_schema"]), SLS.CURRENT_SCHEMA_VERSION,
			"current_schema 应反映 CURRENT_SCHEMA_VERSION")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-014: _atomic_read 仅读取规范文件名——忽略 .tmp 和 .bak
# ═══════════════════════════════════════════════════════════════════════════════

func test_atomic_read_ignores_tmp_and_bak() -> void:
	# Arrange — 创建规范文件（合法存档）
	var canonical_path := "user://test_ignore_tmp/save.json"
	var json_str := JSON.stringify({
		"schema_version": 1,
		"game_state": {"player": {"hp": 100}},
		"complete": true,
	}, "\t")

	# 创建父目录
	DirAccess.make_dir_recursive_absolute(canonical_path.get_base_dir())
	var f := FileAccess.open(canonical_path, FileAccess.WRITE)
	f.store_string(json_str)
	f.close()
	_test_files.append(canonical_path)

	# 创建 .tmp 文件（含非法 JSON——若 _atomic_read 误读它则返回 CORRUPTED）
	var tmp_path := canonical_path + ".tmp"
	var f2 := FileAccess.open(tmp_path, FileAccess.WRITE)
	f2.store_string("{broken tmp content that should never be read")
	f2.close()
	_test_files.append(tmp_path)

	# 创建 .bak 文件（也含非法内容）
	var bak_path := canonical_path + ".bak"
	var f3 := FileAccess.open(bak_path, FileAccess.WRITE)
	f3.store_string("{broken bak content that should never be read")
	f3.close()
	_test_files.append(bak_path)

	# Act — 仅读取规范文件名（canonical_path 不含 .tmp/.bak 后缀）
	var result: Dictionary = sls._atomic_read(canonical_path)

	# Assert — 应成功从规范文件读取，无视 .tmp 和 .bak
	assert_eq(result["result"], SLS.LoadResult.SUCCESS,
			"应成功读取规范文件——忽略 .tmp 和 .bak")
	var data: Dictionary = result["data"]
	assert_eq(int(data["game_state"]["player"]["hp"]), 100,
			"读取的数据应来自规范文件")