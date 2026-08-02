extends GutTest
## Story 004 验收测试：公共 API + GSM 集成。
##
## 覆盖 AC-001 到 AC-016 全部验收标准。
## 此 Story 类型为 Integration——测试证据为阻塞项（BLOCKING）。
##
## 每个测试通过 preload + .new() 创建独立 SaveLoadSystem 实例。
## GSM/CardSystem mock 通过 set_dependencies() 注入。
## 测试文件写入 user:// 沙盒路径，after_each() 清理。

const SLS := preload("res://src/foundation/save_load_system.gd")

var sls: Node = null
var _test_files: Array[String] = []
var _mock_nodes: Array[Node] = []


func before_each() -> void:
	sls = SLS.new()
	sls._ready()
	_test_files.clear()


func after_each() -> void:
	# 清理本测试创建的临时文件及其父目录
	for path: String in _test_files:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
		if FileAccess.file_exists(path + ".tmp"):
			DirAccess.remove_absolute(path + ".tmp")
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		# 清理 meta.json（如果存在）
		var meta_path: String = path.get_base_dir() + "/meta.json"
		if FileAccess.file_exists(meta_path):
			DirAccess.remove_absolute(meta_path)
		# 尝试删除目录
		var dir: String = path.get_base_dir()
		if DirAccess.dir_exists_absolute(dir):
			DirAccess.remove_absolute(dir)
		var saves_dir: String = dir.get_base_dir()
		if dir.ends_with("saves") and DirAccess.dir_exists_absolute(dir):
			DirAccess.remove_absolute(dir)
	if sls != null:
		sls.free()
		sls = null
	# 清理 mock 节点——防止孤儿节点泄漏
	for mock in _mock_nodes:
		if is_instance_valid(mock):
			mock.free()
	_mock_nodes.clear()


func _make_test_file(filename: String, content: String) -> String:
	## 在 user:// 下创建测试文件并写入内容。返回完整路径。
	var path: String = "user://%s" % filename
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(content)
		f.close()
	_test_files.append(path)
	return path


func _make_mock_gsm(serialize_result: Dictionary = {},
		deserialize_result: bool = true) -> Node:
	## 创建轻量 GSM mock——使用 GDScript.new() + 附加字段模拟 serialize/deserialize。
	var mock: Node = Node.new()
	mock.set_meta("serialize_result", serialize_result)
	mock.set_meta("deserialize_result", deserialize_result)
	mock.set_meta("deserialize_called_with", null)
	mock.set_script(_make_mock_gsm_script())
	_mock_nodes.append(mock)
	return mock


func _make_mock_gsm_script() -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = """extends Node
var _meta_data: Dictionary = {}

func serialize() -> Dictionary:
	return get_meta("serialize_result", {})

func deserialize(data) -> bool:
	set_meta("deserialize_called_with", data)
	return get_meta("deserialize_result", true)
"""
	script.reload()
	return script


func _make_mock_card_system(has_reconstitute: bool = true) -> Node:
	## 创建轻量 CardSystem mock。
	var mock: Node = Node.new()
	mock.set_meta("reconstitute_called_with", null)
	mock.set_meta("has_reconstitute", has_reconstitute)
	mock.set_script(_make_mock_card_system_script())
	_mock_nodes.append(mock)
	return mock


func _make_mock_card_system_script() -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = """extends Node

func reconstitute_instances(owned_cards: Array) -> void:
	set_meta("reconstitute_called_with", owned_cards)
"""
	script.reload()
	return script


# ═══════════════════════════════════════════════════════════════════════════════
# AC-001 + AC-014: save_game 成功 → 返回 SUCCESS + 发射 save_completed 信号
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_game_success() -> void:
	# Arrange
	var serialized_data: Dictionary = {
		"session": {"playtime_seconds": 3600},
		"player": {"hp": 100},
	}
	var meta: Dictionary = {"player_name": "测试修士", "realm": "金丹", "playtime_seconds": 3600}

	watch_signals(sls)

	# Act
	var result: int = sls.save_game(SLS.SaveSlotType.AUTOSAVE, 0, serialized_data, meta)

	# Assert
	assert_eq(result, SLS.SaveResult.SUCCESS, "save_game 应返回 SUCCESS")
	# AC-014: save_completed 信号——success=true
	assert_signal_emitted_with_parameters(sls, "save_completed",
		[SLS.SaveSlotType.AUTOSAVE, 0, true])

	# 验证存档文件存在
	var path: String = sls._save_path(SLS.SaveSlotType.AUTOSAVE, 0)
	assert_true(FileAccess.file_exists(path), "存档文件应被创建")
	_test_files.append(path)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-002: save_game 非 JSON 兼容类型 → VALIDATION_ERROR
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_game_non_json_type_returns_validation_error() -> void:
	# Arrange —— data 中包含 Vector2（Godot 4.6 的 typeof 为 TYPE_VECTOR2）
	var bad_data: Dictionary = {"player": {"position": Vector2(1, 2)}}
	watch_signals(sls)

	# Act
	var result: int = sls.save_game(SLS.SaveSlotType.AUTOSAVE, 0, bad_data, {})

	# Assert
	assert_eq(result, SLS.SaveResult.VALIDATION_ERROR,
		"包含 Vector2 的数据应返回 VALIDATION_ERROR")
	assert_signal_emitted_with_parameters(sls, "save_completed",
		[SLS.SaveSlotType.AUTOSAVE, 0, false])
	assert_push_error_count(1, "应产生一次 push_error 报告类型校验失败")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-003: load_game 成功——完整管线：atomic_read → validate → deserialize → reconstitute
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_game_success() -> void:
	# Arrange —— 先构建合法存档文件
	var game_state: Dictionary = {
		"player": {"hp": 80, "realm": 2},
		"collection": {"owned_cards": [{"id": "card_001", "count": 2}]},
	}
	var container: Dictionary = {
		"schema_version": SLS.CURRENT_SCHEMA_VERSION,
		"version": "1.0.0",
		"timestamp": "2026-07-31T12:00:00Z",
		"playtime_seconds": 1800,
		"meta": {"player_name": "测试", "realm": "筑基"},
		"game_state": game_state,
		"complete": true,
	}
	var json_str: String = JSON.stringify(container, "\t")
	var path: String = _make_test_file("saves/manual/save_1.json", json_str)

	# 注入 mock GSM 和 CardSystem
	var mock_gsm: Node = _make_mock_gsm(game_state, true)
	var mock_cs: Node = _make_mock_card_system(true)
	sls.set_dependencies(mock_gsm, mock_cs)

	watch_signals(sls)

	# Act
	var result: Dictionary = sls.load_game(SLS.SaveSlotType.MANUAL, 1)

	# Assert
	assert_eq(result["result"], SLS.LoadResult.SUCCESS, "load_game 应返回 SUCCESS")
	assert_signal_emitted_with_parameters(sls, "load_started",
		[SLS.SaveSlotType.MANUAL, 1])
	assert_signal_emitted_with_parameters(sls, "load_completed", [true])

	# 验证 GSM.deserialize 被调用
	var called_with: Dictionary = mock_gsm.get_meta("deserialize_called_with", {})
	assert_eq(int(called_with["player"]["hp"]), 80, "GSM.deserialize 应收到 game_state 数据")

	# 验证 CardSystem.reconstitute_instances 被调用（AC-003 ADR-0006 契约）
	var reconstitute_called: Array = mock_cs.get_meta("reconstitute_called_with", [])
	assert_eq(reconstitute_called.size(), 1,
		"reconstitute_instances 应收到 owned_cards 数据")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-004: GSM.deserialize 返回 false → DESERIALIZE_ERROR + save_corrupted 信号
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_game_deserialize_error() -> void:
	# Arrange —— 合法存档文件，但 mock GSM 的 deserialize 返回 false
	var game_state: Dictionary = {"player": {"hp": 100}}
	var container: Dictionary = {
		"schema_version": SLS.CURRENT_SCHEMA_VERSION,
		"version": "1.0.0",
		"timestamp": "2026-07-31T12:00:00Z",
		"playtime_seconds": 0,
		"meta": {"player_name": "test"},
		"game_state": game_state,
		"complete": true,
	}
	var json_str: String = JSON.stringify(container, "\t")
	var path: String = _make_test_file("saves/manual/save_2.json", json_str)

	var mock_gsm: Node = _make_mock_gsm(game_state, false)  # deserialize → false
	sls.set_dependencies(mock_gsm)

	watch_signals(sls)

	# Act
	var result: Dictionary = sls.load_game(SLS.SaveSlotType.MANUAL, 2)

	# Assert
	assert_eq(result["result"], SLS.LoadResult.DESERIALIZE_ERROR,
		"deserialize 失败应返回 DESERIALIZE_ERROR")
	assert_signal_emitted_with_parameters(sls, "save_corrupted",
		[SLS.SaveSlotType.MANUAL, 2, "DESERIALIZE_ERROR"])
	assert_signal_emitted_with_parameters(sls, "load_completed", [false])


# ═══════════════════════════════════════════════════════════════════════════════
# AC-005: delete_save 删除文件 + 标记 meta.json 槽位为空
# ═══════════════════════════════════════════════════════════════════════════════

func test_delete_save_marks_empty() -> void:
	# Arrange —— 先创建一个存档文件
	var serialized_data: Dictionary = {"session": {"playtime_seconds": 0}, "player": {"hp": 50}}
	var meta: Dictionary = {"player_name": "删除测试", "realm": "筑基"}
	sls.save_game(SLS.SaveSlotType.MANUAL, 3, serialized_data, meta)

	var path: String = sls._save_path(SLS.SaveSlotType.MANUAL, 3)
	assert_true(FileAccess.file_exists(path), "存档应存在")

	# Act
	var result: bool = sls.delete_save(SLS.SaveSlotType.MANUAL, 3)

	# Assert
	assert_true(result, "delete_save 应返回 true")
	assert_false(FileAccess.file_exists(path), "存档文件应被删除")

	# AC-005: 文件不存在也返回 true（幂等）
	var result2: bool = sls.delete_save(SLS.SaveSlotType.MANUAL, 3)
	assert_true(result2, "文件不存在时 delete_save 应返回 true")

	_test_files.append(path)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-006: get_slot_meta 仅返回 meta 子字典——不读取 game_state
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_slot_meta_returns_meta_only() -> void:
	# Arrange —— 创建存档文件
	var game_state: Dictionary = {"player": {"hp": 100}, "collection": {"owned_cards": [1, 2, 3]}}
	var container: Dictionary = {
		"schema_version": SLS.CURRENT_SCHEMA_VERSION,
		"version": "1.0.0",
		"timestamp": "2026-07-31T14:30:00Z",
		"playtime_seconds": 5400,
		"meta": {"player_name": "元数据测试", "realm": "元婴"},
		"game_state": game_state,
		"complete": true,
	}
	var json_str: String = JSON.stringify(container, "\t")
	var path: String = _make_test_file("saves/manual/save_1.json", json_str)

	# Act
	var meta: Dictionary = sls.get_slot_meta(SLS.SaveSlotType.MANUAL, 1)

	# Assert
	assert_true(meta["exists"], "槽位应存在")
	assert_eq(meta["name"], "元数据测试", "应返回 player_name")
	assert_eq(meta["realm"], "元婴", "应返回 realm")
	assert_eq(int(meta["playtime"]), 5400, "应返回 playtime")
	assert_false(meta.has("game_state"), "不应包含 game_state（AC-006）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-007: list_slots 从 meta.json 读取全部槽位状态
# ═══════════════════════════════════════════════════════════════════════════════

func test_list_slots_after_save() -> void:
	# Arrange —— 保存一个手动存档以填充 meta.json
	var serialized_data: Dictionary = {"session": {"playtime_seconds": 0}, "player": {"hp": 50}}
	var meta: Dictionary = {"player_name": "列表测试", "realm": "筑基", "playtime_seconds": 900}
	sls.save_game(SLS.SaveSlotType.MANUAL, 1, serialized_data, meta)

	var path: String = sls._save_path(SLS.SaveSlotType.MANUAL, 1)
	_test_files.append(path)

	# Act
	var slots: Array = sls.list_slots()

	# Assert
	assert_true(slots.size() >= 1, "list_slots 应返回至少一个槽位")
	# 查找 manual_1
	var found: bool = false
	for s in slots:
		var slot: Dictionary = s as Dictionary
		if slot["slot_type"] == SLS.SaveSlotType.MANUAL and slot["slot_id"] == 1:
			found = true
			assert_true(slot["exists"], "manual_1 应标记为 exists: true")
			assert_eq(slot["name"], "列表测试", "应包含正确的 name")
			assert_eq(slot["realm"], "筑基", "应包含正确的 realm")
			break
	assert_true(found, "list_slots 应包含 manual_1 槽位")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-008: load_progression 首次启动——文件不存在返回默认值
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_progression_first_time_defaults() -> void:
	# Arrange —— 确保 progression.dat 不存在（默认状态）

	# Act
	var prog: Dictionary = sls.load_progression()

	# Assert
	assert_eq(prog["highest_realm"], "", "默认 highest_realm 应为空字符串")
	assert_eq(int(prog["total_playtime_seconds"]), 0, "默认 total_playtime_seconds 应为 0")
	assert_eq(prog["unlocked_cards"].size(), 0, "默认 unlocked_cards 应为空数组")
	assert_eq(prog["unlocked_talents"].size(), 0, "默认 unlocked_talents 应为空数组")
	assert_eq(prog["achievements"].size(), 0, "默认 achievements 应为空字典")
	var stats: Dictionary = prog["statistics"]
	assert_eq(int(stats["total_battles"]), 0)
	assert_eq(int(stats["total_victories"]), 0)
	assert_eq(int(stats["total_deaths"]), 0)
	assert_eq(int(stats["highest_damage"]), 0)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-009: load_progression 损坏（非法 JSON）→ push_error + 默认值 + 信号
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_progression_corrupted_resets() -> void:
	# Arrange —— 创建损坏的 progression.dat（非法 JSON）
	var path: String = _make_test_file("saves/progression.dat", "{this is not valid json!!!")

	watch_signals(sls)

	# Act
	var prog: Dictionary = sls.load_progression()

	# Assert
	# 应返回默认值
	assert_eq(prog["highest_realm"], "", "损坏文件应返回默认值")
	assert_eq(int(prog["total_playtime_seconds"]), 0)

	# AC-009: 损坏时应发射 progression_saved(false) 信号
	assert_signal_emitted_with_parameters(sls, "progression_saved", [false])

	# 应产生 push_error
	# _parse_json_file 内部 push_error + load_progression 自身 push_error = 2 次
	assert_push_error_count(2, "损坏 progression.dat 应产生 push_error（_parse_json_file + load_progression）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-010 + AC-011: create_battle_snapshot → restore_battle_snapshot 往返
# ═══════════════════════════════════════════════════════════════════════════════

func test_create_and_restore_battle_snapshot() -> void:
	# Arrange
	var serialized_data: Dictionary = {
		"session": {"playtime_seconds": 7200},
		"player": {"hp": 75, "realm": 3},
		"exploration": {"map_id": "star_sea", "position": {"x": 12, "y": 8}},
	}

	# Act —— 创建快照
	var created: bool = sls.create_battle_snapshot(serialized_data)
	var snap_path: String = sls._save_path(SLS.SaveSlotType.SNAPSHOT)
	_test_files.append(snap_path)

	# Assert —— 创建成功
	assert_true(created, "create_battle_snapshot 应返回 true")
	assert_true(FileAccess.file_exists(snap_path), "快照文件应存在")

	# Act —— 恢复快照
	var result: Dictionary = sls.restore_battle_snapshot()

	# Assert —— AC-011: 恢复成功 → SUCCESS + 文件已删除
	assert_eq(result["result"], SLS.LoadResult.SUCCESS, "恢复快照应返回 SUCCESS")
	assert_false(FileAccess.file_exists(snap_path),
		"恢复后快照文件应被自动清除（AC-011）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-012: restore_battle_snapshot 文件不存在 → FILE_NOT_FOUND
# ═══════════════════════════════════════════════════════════════════════════════

func test_restore_battle_snapshot_not_found() -> void:
	# Arrange —— 确保快照文件不存在

	# Act
	var result: Dictionary = sls.restore_battle_snapshot()

	# Assert
	assert_eq(result["result"], SLS.LoadResult.FILE_NOT_FOUND,
		"文件不存在应返回 FILE_NOT_FOUND（AC-012）")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-013: clear_battle_snapshot 静默执行——文件不存在不报错、无信号
# ═══════════════════════════════════════════════════════════════════════════════

func test_clear_battle_snapshot_idempotent() -> void:
	# Arrange —— 确保快照文件不存在
	var snap_path: String = sls._save_path(SLS.SaveSlotType.SNAPSHOT)
	if FileAccess.file_exists(snap_path):
		DirAccess.remove_absolute(snap_path)

	# Act + Assert —— 不报错即通过
	sls.clear_battle_snapshot()

	# 创建快照后再清除——验证正常路径
	var serialized_data: Dictionary = {"player": {"hp": 100}}
	sls.create_battle_snapshot(serialized_data)
	_test_files.append(snap_path)
	assert_true(FileAccess.file_exists(snap_path), "快照文件应存在")

	sls.clear_battle_snapshot()
	assert_false(FileAccess.file_exists(snap_path),
		"clear_battle_snapshot 应删除文件")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-014: save_game 成功后发射 save_completed(slot_type, slot_id, true)
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_completed_signal_emitted() -> void:
	# Arrange
	var serialized_data: Dictionary = {"session": {"playtime_seconds": 0}, "player": {"hp": 50}}
	var meta: Dictionary = {"player_name": "信号测试"}

	watch_signals(sls)

	# Act
	var result: int = sls.save_game(SLS.SaveSlotType.AUTOSAVE, 0, serialized_data, meta)

	# Assert
	assert_eq(result, SLS.SaveResult.SUCCESS)
	assert_signal_emitted_with_parameters(sls, "save_completed",
		[SLS.SaveSlotType.AUTOSAVE, 0, true])

	var path: String = sls._save_path(SLS.SaveSlotType.AUTOSAVE, 0)
	_test_files.append(path)


# ═══════════════════════════════════════════════════════════════════════════════
# AC-015: save_game 失败后发射 save_completed(slot_type, slot_id, false)
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_completed_signal_on_failure() -> void:
	# Arrange —— 通过同时触发 _is_writing 制造写入冲突
	var serialized_data: Dictionary = {"player": {"hp": 50}}
	sls._is_writing = true  # 模拟写入进行中

	watch_signals(sls)

	# Act
	var result: int = sls.save_game(SLS.SaveSlotType.MANUAL, 1, serialized_data, {})

	# Assert
	assert_eq(result, SLS.SaveResult.WRITE_ERROR, "写入冲突应返回 WRITE_ERROR")
	assert_signal_emitted_with_parameters(sls, "save_completed",
		[SLS.SaveSlotType.MANUAL, 1, false])


# ═══════════════════════════════════════════════════════════════════════════════
# AC-016: save_game 成功后更新 meta.json
# ═══════════════════════════════════════════════════════════════════════════════

func test_save_game_updates_meta_json() -> void:
	# Arrange
	var serialized_data: Dictionary = {"session": {"playtime_seconds": 1200}, "player": {"hp": 60}}
	var meta: Dictionary = {"player_name": "Meta更新", "realm": "炼气", "playtime_seconds": 1200}

	watch_signals(sls)

	# Act
	var result: int = sls.save_game(SLS.SaveSlotType.MANUAL, 2, serialized_data, meta)

	# Assert —— 保存成功
	assert_eq(result, SLS.SaveResult.SUCCESS)
	assert_signal_emitted_with_parameters(sls, "save_completed",
		[SLS.SaveSlotType.MANUAL, 2, true])

	# 验证 meta.json 被创建（AC-016）
	var meta_path: String = sls._get_save_root() + "meta.json"
	assert_true(FileAccess.file_exists(meta_path), "meta.json 应被创建")
	_test_files.append(meta_path)

	# 读取 meta.json 验证内容
	var f: FileAccess = FileAccess.open(meta_path, FileAccess.READ)
	var raw: String = f.get_as_text()
	f.close()
	var json: JSON = JSON.new()
	json.parse(raw)
	var meta_data: Dictionary = json.get_data()
	var slot_key: String = sls._slot_key(SLS.SaveSlotType.MANUAL, 2)
	assert_true(meta_data["slots"].has(slot_key), "meta.json 应包含 %s" % slot_key)
	assert_true(meta_data["slots"][slot_key]["exists"], "槽位应标记为 exists: true")
	assert_eq(meta_data["slots"][slot_key]["name"], "Meta更新", "应包含正确的 name")

	var save_path: String = sls._save_path(SLS.SaveSlotType.MANUAL, 2)
	_test_files.append(save_path)


# ═══════════════════════════════════════════════════════════════════════════════
# 额外测试：get_slot_meta 文件不存在时返回 exists: false
# ═══════════════════════════════════════════════════════════════════════════════

func test_get_slot_meta_file_not_found() -> void:
	# Arrange —— 确保文件不存在

	# Act
	var meta: Dictionary = sls.get_slot_meta(SLS.SaveSlotType.MANUAL, 3)

	# Assert
	assert_false(meta["exists"], "槽位不存在时应返回 exists: false")


# ═══════════════════════════════════════════════════════════════════════════════
# 额外测试：load_game 文件不存在
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_game_file_not_found() -> void:
	# Arrange —— 确保文件不存在

	# Act
	var result: Dictionary = sls.load_game(SLS.SaveSlotType.MANUAL, 1)

	# Assert
	assert_eq(result["result"], SLS.LoadResult.FILE_NOT_FOUND,
		"文件不存在应返回 FILE_NOT_FOUND")


# ═══════════════════════════════════════════════════════════════════════════════
# 额外测试：load_game 版本不兼容 → VERSION_MISMATCH
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_game_version_mismatch() -> void:
	# Arrange —— 存档 schema_version 远高于当前版本
	var container: Dictionary = {
		"schema_version": 999,
		"version": "999.0.0",
		"timestamp": "2026-07-31T12:00:00Z",
		"playtime_seconds": 0,
		"meta": {"player_name": "未来版本"},
		"game_state": {"player": {"hp": 50}},
		"complete": true,
	}
	var json_str: String = JSON.stringify(container, "\t")
	var path: String = _make_test_file("saves/manual/save_5.json", json_str)

	watch_signals(sls)

	# Act
	var result: Dictionary = sls.load_game(SLS.SaveSlotType.MANUAL, 5)

	# Assert
	assert_eq(result["result"], SLS.LoadResult.VERSION_MISMATCH,
		"schema_version 过高应返回 VERSION_MISMATCH")
	assert_signal_emitted_with_parameters(sls, "load_completed", [false])


# ═══════════════════════════════════════════════════════════════════════════════
# 额外测试：load_game 存档损坏（缺少 complete） → CORRUPTED
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_game_corrupted_missing_complete() -> void:
	# Arrange —— 合法 JSON 但缺少 complete 字段
	var container: Dictionary = {
		"schema_version": SLS.CURRENT_SCHEMA_VERSION,
		"game_state": {"player": {"hp": 50}},
	}
	var json_str: String = JSON.stringify(container, "\t")
	var path: String = _make_test_file("saves/manual/save_6.json", json_str)

	# Act
	var result: Dictionary = sls.load_game(SLS.SaveSlotType.MANUAL, 6)

	# Assert
	assert_eq(result["result"], SLS.LoadResult.CORRUPTED,
		"缺少 complete 标记应返回 CORRUPTED")


# ═══════════════════════════════════════════════════════════════════════════════
# 额外测试：load_game 无 CardSystem——前向兼容静默跳过
# ═══════════════════════════════════════════════════════════════════════════════

func test_load_game_success_without_card_system() -> void:
	# Arrange —— 合法存档，注入 GSM 但不注入 CardSystem
	var game_state: Dictionary = {"player": {"hp": 50}}
	var container: Dictionary = {
		"schema_version": SLS.CURRENT_SCHEMA_VERSION,
		"version": "1.0.0",
		"timestamp": "2026-07-31T12:00:00Z",
		"playtime_seconds": 0,
		"meta": {"player_name": "无CS测试"},
		"game_state": game_state,
		"complete": true,
	}
	var json_str: String = JSON.stringify(container, "\t")
	var path: String = _make_test_file("saves/manual/save_7.json", json_str)

	var mock_gsm: Node = _make_mock_gsm(game_state, true)
	sls.set_dependencies(mock_gsm)  # 不传 card_system——前向兼容路径

	watch_signals(sls)

	# Act
	var result: Dictionary = sls.load_game(SLS.SaveSlotType.MANUAL, 7)

	# Assert —— 不崩溃，正常返回 SUCCESS
	assert_eq(result["result"], SLS.LoadResult.SUCCESS,
		"无 CardSystem 时 load_game 应正常完成")
	assert_signal_emitted_with_parameters(sls, "load_completed", [true])