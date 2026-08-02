extends GutTest
## Story 001 验收测试：JSON 序列化引擎 + SaveResult/LoadResult/SaveSlotType 枚举。
##
## 覆盖 AC-001 到 AC-011 全部验收标准。
## 此 Story 类型为 Logic——测试证据为阻塞项（BLOCKING）。
##
## 每个测试通过 preload + .new() 创建独立 SaveLoadSystem 实例。
## 手动调用 _ready() 初始化。

const SLS := preload("res://src/foundation/save_load_system.gd")

var sls: Node = null
var _test_files: Array[String] = []


func before_each() -> void:
	sls = SLS.new()
	sls._ready()
	_test_files.clear()


func after_each() -> void:
	# 清理本测试创建的临时文件
	for path in _test_files:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
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
# AC-001: SaveResult 枚举完整定义
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac001_saveresult_enum_values() -> void:
	assert_eq(SLS.SaveResult.SUCCESS, 0, "SUCCESS 应为 0")
	assert_eq(SLS.SaveResult.DISK_FULL, 1, "DISK_FULL 应为 1")
	assert_eq(SLS.SaveResult.WRITE_ERROR, 2, "WRITE_ERROR 应为 2")
	assert_eq(SLS.SaveResult.VALIDATION_ERROR, 3, "VALIDATION_ERROR 应为 3")


func test_ac001_saveresult_has_four_values() -> void:
	var count := SLS.SaveResult.size()
	assert_eq(count, 4, "SaveResult 应有 4 个值")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-002: LoadResult 枚举完整定义
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac002_loadresult_enum_values() -> void:
	assert_eq(SLS.LoadResult.SUCCESS, 0, "SUCCESS 应为 0")
	assert_eq(SLS.LoadResult.FILE_NOT_FOUND, 1, "FILE_NOT_FOUND 应为 1")
	assert_eq(SLS.LoadResult.CORRUPTED, 2, "CORRUPTED 应为 2")
	assert_eq(SLS.LoadResult.VERSION_MISMATCH, 3, "VERSION_MISMATCH 应为 3")
	assert_eq(SLS.LoadResult.DESERIALIZE_ERROR, 4, "DESERIALIZE_ERROR 应为 4")


func test_ac002_loadresult_has_five_values() -> void:
	var count := SLS.LoadResult.size()
	assert_eq(count, 5, "LoadResult 应有 5 个值")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-003: SaveSlotType 枚举完整定义
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac003_saveslottype_enum_values() -> void:
	assert_eq(SLS.SaveSlotType.AUTOSAVE, 0, "AUTOSAVE 应为 0")
	assert_eq(SLS.SaveSlotType.MANUAL, 1, "MANUAL 应为 1")
	assert_eq(SLS.SaveSlotType.SNAPSHOT, 2, "SNAPSHOT 应为 2")


func test_ac003_saveslottype_has_three_values() -> void:
	var count := SLS.SaveSlotType.size()
	assert_eq(count, 3, "SaveSlotType 应有 3 个值")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-004: 合法 JSON 文件解析 → SUCCESS
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac004_parse_valid_json_returns_success() -> void:
	var path := _make_test_file("test_valid.json",
			'{"schema_version": 1, "game_state": {}, "complete": true}')
	var result: Dictionary = sls._parse_json_file(path)
	assert_eq(result["result"], SLS.LoadResult.SUCCESS, "合法 JSON 应返回 SUCCESS")
	var data: Dictionary = result["data"]
	assert_eq(int(data["schema_version"]), 1, "schema_version 应为 1")
	assert_true(data["complete"], "complete 应为 true")


func test_ac004_parse_empty_object_returns_success() -> void:
	## 空字典 {} 是合法 JSON
	var path := _make_test_file("test_empty_obj.json", "{}")
	var result: Dictionary = sls._parse_json_file(path)
	assert_eq(result["result"], SLS.LoadResult.SUCCESS, "空字典 JSON 应返回 SUCCESS")


func test_ac004_parse_deep_nested_json_returns_success() -> void:
	## 深层嵌套结构
	var path := _make_test_file("test_deep.json",
			'{"a": {"b": {"c": {"d": [1, 2, 3]}, "e": "hello"}, "f": 3.14}, "g": true}')
	var result: Dictionary = sls._parse_json_file(path)
	assert_eq(result["result"], SLS.LoadResult.SUCCESS, "深层嵌套 JSON 应返回 SUCCESS")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-005: 非法 JSON 字符串解析 → CORRUPTED
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac005_parse_invalid_json_returns_corrupted() -> void:
	var path := _make_test_file("test_broken.json", "{broken json!!!")
	var result: Dictionary = sls._parse_json_file(path)
	assert_eq(result["result"], SLS.LoadResult.CORRUPTED, "非法 JSON 应返回 CORRUPTED")
	assert_not_null(result["data"], "data 应为非 null（空字典）")


func test_ac005_parse_empty_file_returns_corrupted() -> void:
	## 空文件 → JSON.new().parse("") 返回 err != OK
	var path := _make_test_file("test_empty.json", "")
	var result: Dictionary = sls._parse_json_file(path)
	assert_eq(result["result"], SLS.LoadResult.CORRUPTED,
			"空文件应返回 CORRUPTED（parse 失败）")


func test_ac005_parse_wrong_syntax_json_returns_corrupted() -> void:
	## 缺少引号的键
	var path := _make_test_file("test_syntax.json", "{key: value}")
	var result: Dictionary = sls._parse_json_file(path)
	assert_eq(result["result"], SLS.LoadResult.CORRUPTED,
			"语法错误的 JSON 应返回 CORRUPTED")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-006: JSON null 值解析 → CORRUPTED（typeof != TYPE_DICTIONARY）
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac006_parse_null_json_returns_corrupted() -> void:
	## null 是合法 JSON，但 typeof(null) != TYPE_DICTIONARY → CORRUPTED
	var path := _make_test_file("test_null.json", "null")
	var result: Dictionary = sls._parse_json_file(path)
	assert_eq(result["result"], SLS.LoadResult.CORRUPTED,
			"JSON null 应返回 CORRUPTED（非 Object 顶层）")


func test_ac006_null_vs_parse_error_distinguished() -> void:
	## 验证 JSON.new().parse() 对 null 返回 OK
	## 这是 AC-006 的核心语义——parse_string() 无法区分此差异
	var json := JSON.new()
	var err := json.parse("null")
	assert_eq(err, OK, "JSON.new().parse('null') 应返回 OK——这是合法 JSON")
	# get_data() 返回 null，但 typeof(null) != TYPE_DICTIONARY → 被判定为 CORRUPTED
	assert_eq(json.get_data(), null, "get_data() 对 'null' 应返回 null")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-007: 顶层非 Object（数组）→ CORRUPTED
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac007_parse_array_json_returns_corrupted() -> void:
	var path := _make_test_file("test_array.json", "[1, 2, 3]")
	var result: Dictionary = sls._parse_json_file(path)
	assert_eq(result["result"], SLS.LoadResult.CORRUPTED,
			"顶层为数组的 JSON 应返回 CORRUPTED")


func test_ac007_parse_string_json_returns_corrupted() -> void:
	## 顶层为字符串——typeof != TYPE_DICTIONARY
	var path := _make_test_file("test_str.json", '"hello world"')
	var result: Dictionary = sls._parse_json_file(path)
	assert_eq(result["result"], SLS.LoadResult.CORRUPTED,
			"顶层为字符串的 JSON 应返回 CORRUPTED")


func test_ac007_parse_number_json_returns_corrupted() -> void:
	## 顶层为数字——typeof != TYPE_DICTIONARY
	var path := _make_test_file("test_num.json", "42")
	var result: Dictionary = sls._parse_json_file(path)
	assert_eq(result["result"], SLS.LoadResult.CORRUPTED,
			"顶层为数字的 JSON 应返回 CORRUPTED")


func test_ac007_parse_bool_json_returns_corrupted() -> void:
	## 顶层为布尔值——typeof != TYPE_DICTIONARY
	var path := _make_test_file("test_bool.json", "true")
	var result: Dictionary = sls._parse_json_file(path)
	assert_eq(result["result"], SLS.LoadResult.CORRUPTED,
			"顶层为布尔值的 JSON 应返回 CORRUPTED")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-008: JSON.stringify(data, "\t") 输出格式化 JSON
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac008_serialize_uses_tab_indent() -> void:
	var data: Dictionary = {"key": "value", "num": 42}
	var result: String = sls._serialize_to_json(data)
	# 应包含制表符缩进
	assert_true(result.contains("\t"), "输出应包含制表符缩进")
	assert_true(result.contains("\n"), "输出应包含换行符")


func test_ac008_serialize_deep_nested_produces_valid_json() -> void:
	var data: Dictionary = {
		"schema_version": 1,
		"game_state": {
			"player": {"name": "test", "hp": 100},
			"cards": ["card_001", "card_002"],
		},
		"complete": true,
	}
	var result: String = sls._serialize_to_json(data)
	# 验证输出是合法 JSON——能被 JSON.new().parse() 解析
	var json := JSON.new()
	var err := json.parse(result)
	assert_eq(err, OK, "序列化输出应是合法 JSON")
	var parsed = json.get_data()
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "解析结果应为字典")
	assert_eq(int(parsed["schema_version"]), 1, "schema_version 应为 1")


func test_ac008_serialize_empty_dict() -> void:
	var data: Dictionary = {}
	var result: String = sls._serialize_to_json(data)
	assert_true(result.length() > 0, "空字典序列化不应为空字符串")
	var json := JSON.new()
	assert_eq(json.parse(result), OK, "空字典序列化结果应是合法 JSON")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-009: FileAccess.file_exists 检查
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac009_file_not_exists_returns_false() -> void:
	assert_false(FileAccess.file_exists("user://nonexistent_file_xyz.json"),
			"不存在的文件应返回 false")


func test_ac009_file_exists_returns_true() -> void:
	var path := _make_test_file("test_exists.json", "{}")
	assert_true(FileAccess.file_exists(path), "刚创建的文件应返回 true")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-010: FileAccess.get_file_as_string 读取完整文件内容
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac010_get_file_as_string_reads_content() -> void:
	var path := _make_test_file("test_read.json", '{"hello": "world", "number": 123}')
	var content: String = FileAccess.get_file_as_string(path)
	assert_true(content.contains('"hello"'), "内容应包含键 'hello'")
	assert_true(content.contains('"world"'), "内容应包含值 'world'")
	assert_true(content.contains('123'), "内容应包含数字 123")


func test_ac010_get_file_as_string_empty_file() -> void:
	var path := _make_test_file("test_read_empty.json", "")
	var content: String = FileAccess.get_file_as_string(path)
	assert_eq(content, "", "空文件内容应为空字符串")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-011: JSON 序列化往返——深度相等
# ═══════════════════════════════════════════════════════════════════════════════

func test_ac011_roundtrip_flat_dict() -> void:
	var original: Dictionary = {
		"schema_version": 1,
		"version": "1.0.0",
		"complete": true,
	}
	var json_str: String = sls._serialize_to_json(original)
	var path := _make_test_file("test_roundtrip_flat.json", json_str)
	var result: Dictionary = sls._parse_json_file(path)
	assert_eq(result["result"], SLS.LoadResult.SUCCESS, "往返后应为 SUCCESS")
	var data: Dictionary = result["data"]
	# JSON 解析将所有数字转为 float——用 int() 还原比较
	assert_eq(int(data["schema_version"]), 1, "schema_version 往返后应为 1")
	assert_eq(data["version"], "1.0.0", "version 往返后应相同")
	assert_true(data["complete"], "complete 往返后应为 true")


func test_ac011_roundtrip_nested_dictionary() -> void:
	## 深层嵌套 Dictionary 的往返——含 int/float/String/bool/null/Array/Dictionary
	var original: Dictionary = {
		"schema_version": 1,
		"version": "1.0.0",
		"timestamp": "2026-07-30T15:30:00Z",
		"playtime_seconds": 3600,
		"meta": {
			"player_name": "凡人001",
			"realm": "筑基",
			"chapter": 2,
			"map_name": "碎星外环",
			"deck_size": 32,
			"current_scene": "exploration",
			"current_scene_id": 3,
		},
		"game_state": {
			"player": {
				"hp": 150,
				"max_hp": 200,
				"atk": 35.5,
				"def": 20,
			},
			"collection": {
				"owned_cards": ["card_001", "card_005", "card_012"],
			},
			"flags": {"met_elder": true, "defeated_boss_1": false},
		},
		"complete": true,
	}
	var json_str: String = sls._serialize_to_json(original)
	var path := _make_test_file("test_roundtrip_nested.json", json_str)
	var result: Dictionary = sls._parse_json_file(path)
	assert_eq(result["result"], SLS.LoadResult.SUCCESS, "往返后应为 SUCCESS")
	var data_nested: Dictionary = result["data"]
	assert_eq(int(data_nested["schema_version"]), 1, "schema_version 往返后应为 1")
	assert_eq(int(data_nested["playtime_seconds"]), 3600, "playtime_seconds 往返后应为 3600")
	assert_eq(data_nested["version"], "1.0.0", "version 往返后应相同")
	assert_true(data_nested["complete"], "complete 往返后应为 true")
	var meta: Dictionary = data_nested["meta"]
	assert_eq(meta["player_name"], "凡人001", "player_name 应保留")
	assert_eq(int(meta["chapter"]), 2, "chapter 往返后应为 2")
	assert_eq(int(meta["deck_size"]), 32, "deck_size 往返后应为 32")
	assert_eq(int(meta["current_scene_id"]), 3, "current_scene_id 往返后应为 3")
	var gs: Dictionary = data_nested["game_state"]
	var player: Dictionary = gs["player"]
	assert_eq(int(player["hp"]), 150, "hp 往返后应为 150")
	assert_eq(int(player["max_hp"]), 200, "max_hp 往返后应为 200")
	assert_almost_eq(player["atk"], 35.5, 0.001, "atk float 应保留")
	assert_eq(int(player["def"]), 20, "def 往返后应为 20")
	assert_eq(gs["collection"]["owned_cards"].size(), 3, "owned_cards 应有 3 张")
	assert_eq(gs["collection"]["owned_cards"][0], "card_001", "卡牌 ID 应保留")


func test_ac011_roundtrip_preserves_types() -> void:
	## 验证往返后所有 JSON 兼容类型被正确保留
	var original: Dictionary = {
		"int_val": 42,
		"float_val": 3.14,
		"str_val": "hello",
		"bool_true": true,
		"bool_false": false,
	}
	var json_str: String = sls._serialize_to_json(original)
	var path := _make_test_file("test_roundtrip_types.json", json_str)
	var result: Dictionary = sls._parse_json_file(path)
	var data: Dictionary = result["data"]
	## JSON 将所有数字解析为 float——用 int() 还原整数比较
	assert_eq(int(data["int_val"]), 42, "int 值应保留")
	assert_almost_eq(data["float_val"], 3.14, 0.001, "float 值应保留")
	assert_eq(data["str_val"], "hello", "字符串值应保留")
	assert_true(data["bool_true"], "true 值应保留")
	assert_false(data["bool_false"], "false 值应保留")


func test_ac011_roundtrip_array_of_dicts() -> void:
	## 验证 Dictionary 数组的往返
	var original: Dictionary = {
		"items": [
			{"id": 1, "name": "item_one"},
			{"id": 2, "name": "item_two"},
			{"id": 3, "name": "item_three"},
		],
	}
	var json_str: String = sls._serialize_to_json(original)
	var path := _make_test_file("test_roundtrip_arrays.json", json_str)
	var result: Dictionary = sls._parse_json_file(path)
	assert_eq(result["result"], SLS.LoadResult.SUCCESS, "往返后应为 SUCCESS")
	var arr_data: Dictionary = result["data"]
	var items: Array = arr_data["items"]
	assert_eq(items.size(), 3, "items 应有 3 个元素")
	for i in range(3):
		assert_eq(int(items[i]["id"]), i + 1, "item id 往返后应为 %d" % (i + 1))
		assert_eq(items[i]["name"], "item_%s" % ["one", "two", "three"][i], "item name 应保留")


# ═══════════════════════════════════════════════════════════════════════════════
# 补充：FILE_NOT_FOUND 路径测试
# ═══════════════════════════════════════════════════════════════════════════════

func test_parse_nonexistent_file_returns_file_not_found() -> void:
	var result: Dictionary = sls._parse_json_file("user://definitely_not_exists_12345.json")
	assert_eq(result["result"], SLS.LoadResult.FILE_NOT_FOUND,
			"不存在的文件应返回 FILE_NOT_FOUND")
	assert_not_null(result["data"], "data 应为非 null（空字典）")


# ═══════════════════════════════════════════════════════════════════════════════
# 补充：JSON 中使用 parse_string() 无法区分 null 和 parse error
# ═══════════════════════════════════════════════════════════════════════════════

func test_json_parse_string_loses_error_vs_null_distinction() -> void:
	## 验证 ADR-0002 为什么要禁止 parse_string()
	## JSON.parse_string() 对合法 null 返回 null——但对解析错误也返回 null
	## 这就是为什么 ADR-0002 强制使用 JSON.new().parse()
	var null_result = JSON.parse_string("null")
	assert_eq(null_result, null, "parse_string('null') 返回 null")
	# JSON.parse_string("{broken") 会触发 Godot 引擎错误——这正是 ADR-0002
	# 禁止它的原因：无法优雅区分 null 和解析错误
	# 见 test_ac006_null_vs_parse_error_distinguished —— JSON.new().parse() 可以区分
