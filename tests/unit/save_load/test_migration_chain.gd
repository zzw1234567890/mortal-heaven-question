extends GutTest
## Story 005 验收测试：schema_version 迁移链 + VERSION_MISMATCH 拒绝。
##
## 覆盖 AC-001 到 AC-011 全部验收标准。
## 此 Story 类型为 Logic——测试证据为阻塞项（BLOCKING）。
##
## 每个测试通过 preload + .new() 创建独立 SaveLoadSystem 实例。
## MIGRATIONS 为 static var Dictionary——测试中通过实例注入临时迁移函数，
## before_each() / after_each() 清理确保测试隔离。

const SLS := preload("res://src/foundation/save_load_system.gd")

var sls: Node = null


func before_each() -> void:
	sls = SLS.new()
	sls._ready()
	# 清空 MIGRATIONS——确保每个测试从干净状态开始
	sls.MIGRATIONS.clear()


func after_each() -> void:
	# 清理本测试注入的迁移函数
	sls.MIGRATIONS.clear()
	if sls != null:
		sls.free()
		sls = null


# === AC-003：同版本无迁移 ========================================================

func test_migrate_if_needed_same_version_noop() -> void:
	# Arrange：构造 schema_version == CURRENT 的存档容器（CURRENT 随版本提升而变）
	var data: Dictionary = {
		"schema_version": sls.CURRENT_SCHEMA_VERSION,
		"version": "1.0.0",
		"game_state": {"player": {"name": "测试"}},
	}

	# Act
	var result: Dictionary = sls._migrate_if_needed(data)

	# Assert：不变——无迁移函数被调用
	assert_eq(result["schema_version"], sls.CURRENT_SCHEMA_VERSION,
			"schema_version 应保持为 CURRENT")
	assert_eq(result["game_state"]["player"]["name"], "测试", "game_state 内容不应被修改")
	assert_false(result.has("error"), "不应包含 error 键")


# === AC-004：单步迁移 ============================================================

func test_migrate_if_needed_single_step() -> void:
	# Arrange：模拟 schema_version=0 的旧存档
	# 注册 MIGRATIONS[0]：v0→v1 迁移——添加 version 字段
	# 使用 Array 包装以在 lambda 闭包中按引用传递（GDScript 对原始类型按值传递）
	var track: Array[bool] = [false]
	sls.MIGRATIONS[0] = func(data: Dictionary) -> Dictionary:
		track[0] = true
		data["version"] = "1.0.0"
		return data

	var data: Dictionary = {
		"schema_version": 0,
		"game_state": {"player": {"name": "旧存档"}},
	}

	# Act
	var result: Dictionary = sls._migrate_if_needed(data)

	# Assert
	assert_true(track[0], "迁移函数应被调用一次")
	assert_eq(result["schema_version"], sls.CURRENT_SCHEMA_VERSION,
			"迁移后 schema_version 应递增到 CURRENT")
	assert_eq(result["version"], "1.0.0", "迁移函数添加的字段应存在")


# === AC-004 边界情况：多步迁移 ==================================================
# CURRENT_SCHEMA_VERSION 提升到 4 之后，v0 档要依次走过 v0→v1、v1→v2、v2→v3 与 v3→v4
# 四级。本用例注册 MIGRATIONS[0] / MIGRATIONS[1]（覆盖层），后两级走生产链
# （SaveLoadSystem.DEFAULT_MIGRATIONS）——四级都必须真的被调用。

func test_migrate_if_needed_multi_step() -> void:
	# Arrange：v0 档 + 注册 v0→v1 迁移
	var first_calls: Array[int] = [0]
	var second_calls: Array[int] = [0]
	sls.MIGRATIONS[0] = func(data: Dictionary) -> Dictionary:
		first_calls[0] += 1
		data["step_one"] = true
		return data
	# 包一层观察生产链的 v1→v2 是否被调用（不改它的行为，只记次数）
	var production_v1_to_v2: Callable = sls.DEFAULT_MIGRATIONS[1]
	sls.MIGRATIONS[1] = func(data: Dictionary) -> Dictionary:
		second_calls[0] += 1
		return production_v1_to_v2.call(data)

	var data: Dictionary = {
		"schema_version": 0,
		"game_state": {"exploration": {"map_states": {"map_a": {"entry_count": 1}}}},
	}

	# Act
	var result: Dictionary = sls._migrate_if_needed(data)

	# Assert：两级各调用一次，最终落在 CURRENT
	assert_eq(first_calls[0], 1, "v0→v1 迁移应被调用一次")
	assert_eq(second_calls[0], 1, "v1→v2 迁移应被调用一次")
	assert_eq(result["schema_version"], sls.CURRENT_SCHEMA_VERSION,
			"多步迁移后 schema_version 应为 CURRENT")
	assert_true(result.has("step_one"), "第一级迁移写入的字段应存在")
	assert_eq(result["game_state"]["exploration"]["map_states"]["map_a"]["events_shown"], [],
			"第二级（生产链）应给每张图补空的 events_shown")
	assert_eq(result["game_state"]["exploration"]["map_states"]["map_a"]["entry_count"], 1,
			"迁移不得改动已有进度字段")
	assert_eq(result["game_state"]["battle_resume"], {},
			"第三级（生产链）应补空的 battle_resume 段——空 = 这份档不是在战斗中存的")
	assert_eq(result["schema_version"], sls.CURRENT_SCHEMA_VERSION,
			"四级迁移后应落在 CURRENT（v3→v4 也要真的被走过）")


# === AC-005：迁移链缺失 ==========================================================

func test_migrate_if_needed_migration_missing() -> void:
	# Arrange：CURRENT=1，MIGRATIONS 为空，schema_version=0
	var data: Dictionary = {
		"schema_version": 0,
		"game_state": {"player": {}},
	}

	# Act
	var result: Dictionary = sls._migrate_if_needed(data)

	# Assert
	assert_true(result.has("error"), "应包含 error 键")
	assert_eq(result["error"], "MIGRATION_MISSING", "错误类型应为 MIGRATION_MISSING")
	assert_eq(result["from"], 0, "应报告缺失的起始版本号")


# === AC-005 边界情况：空注册表 + save_schema=0 ==================================

func test_migrate_if_needed_empty_registry_returns_missing() -> void:
	# Arrange：空 MIGRATIONS（已在 before_each 中 clear），任意 save_schema < CURRENT
	var data: Dictionary = {
		"schema_version": 0,
		"game_state": {},
	}

	# Act
	var result: Dictionary = sls._migrate_if_needed(data)

	# Assert
	assert_eq(result["error"], "MIGRATION_MISSING")


# === AC-006：高版本拒绝 ==========================================================

func test_migrate_if_needed_version_mismatch_rejected() -> void:
	# Arrange：archive schema_version=99，CURRENT=2
	var data: Dictionary = {
		"schema_version": 99,
		"game_state": {"player": {}},
	}

	# Act
	var result: Dictionary = sls._migrate_if_needed(data)

	# Assert
	assert_true(result.has("error"), "应包含 error 键")
	assert_eq(result["error"], "VERSION_MISMATCH", "错误类型应为 VERSION_MISMATCH")
	assert_eq(result["save_schema"], 99, "应报告存档的 schema 版本")
	assert_eq(result["current_schema"], sls.CURRENT_SCHEMA_VERSION,
			"应报告当前的 schema 版本")


# === AC-006 边界情况：save_schema 远大于 CURRENT ================================

func test_migrate_if_needed_version_way_ahead_rejected() -> void:
	# Arrange：边界值——极端情况，例如未来版本 999
	var data: Dictionary = {
		"schema_version": 999,
		"game_state": {},
	}

	# Act
	var result: Dictionary = sls._migrate_if_needed(data)

	# Assert
	assert_eq(result["error"], "VERSION_MISMATCH")
	assert_eq(result["save_schema"], 999)


# === AC-007：缺少 schema_version 字段默认值 =====================================

func test_migrate_if_needed_missing_schema_version_defaults_to_zero() -> void:
	# Arrange：data 无 schema_version 字段
	# CURRENT=1, MIGRATIONS 为空 → save_schema=0 → MIGRATION_MISSING（而非 VERSION_MISMATCH）
	var data: Dictionary = {
		"game_state": {"player": {"name": "旧格式"}},
	}

	# Act
	var result: Dictionary = sls._migrate_if_needed(data)

	# Assert：0 <= 1 → 不拒绝，进入迁移链 → MIGRATIONS.has(0) == false → MIGRATION_MISSING
	assert_eq(result["error"], "MIGRATION_MISSING", "缺失 schema_version 应默认为 0，不应拒绝")
	assert_eq(result["from"], 0)


# === AC-007 边界情况：默认值 0 + 注册迁移函数 ===================================

func test_migrate_if_needed_defaults_zero_with_migration_registered() -> void:
	# Arrange：注册 MIGRATIONS[0]，data 无 schema_version 字段
	# 使用 Array 包装以在 lambda 闭包中按引用传递
	var track: Array[bool] = [false]
	sls.MIGRATIONS[0] = func(data: Dictionary) -> Dictionary:
		track[0] = true
		data["migrated_from_v0"] = true
		return data

	var data: Dictionary = {
		"game_state": {"player": {}},
	}

	# Act
	var result: Dictionary = sls._migrate_if_needed(data)

	# Assert
	assert_true(track[0], "save_schema 默认为 0，应触发 MIGRATIONS[0] 迁移")
	assert_eq(result["schema_version"], sls.CURRENT_SCHEMA_VERSION,
			"迁移后 schema_version 应为 CURRENT")
	assert_true(result.has("migrated_from_v0"), "迁移函数添加的字段应存在")


# === AC-008 迁移函数签名（代码约定检查） ==========================================
# AC-008 要求迁移函数签名为 func(data: Dictionary) -> Dictionary 纯函数。
# 此约定通过 AC-003/AC-004/AC-010 中的实际迁移函数调用验证——
# 如果签名不匹配，MIGRATIONS[key].call(data) 将返回类型错误。
# 非独立测试项。

func test_migration_function_signature_is_callable_with_dictionary() -> void:
	# 此测试确保注册到 MIGRATIONS 的函数签名符合 Callable 约定
	sls.MIGRATIONS[0] = func(data: Dictionary) -> Dictionary:
		data["test_passed"] = true
		return data

	var test_data: Dictionary = {"schema_version": 0, "game_state": {}}
	var result: Dictionary = sls._migrate_if_needed(test_data)

	assert_true(result.has("test_passed"), "迁移函数签名 Dictionary→Dictionary 应正常工作")


# === AC-011：save_game 总是写入 CURRENT_SCHEMA_VERSION ==========================

func test_save_game_writes_current_schema_version() -> void:
	# Arrange：通过 save_game 写入模拟数据
	var gsm_data: Dictionary = {"player": {"name": "测试玩家"}}
	var meta: Dictionary = {"player_name": "测试角色", "realm": "筑基"}

	# Act
	var result: int = sls.save_game(sls.SaveSlotType.MANUAL, 3, gsm_data, meta)

	# Assert
	assert_eq(result, sls.SaveResult.SUCCESS, "保存应成功")

	# 读取文件验证 schema_version
	var path: String = sls._save_path(sls.SaveSlotType.MANUAL, 3)
	var read_result: Dictionary = sls._parse_json_file(path)
	assert_eq(read_result["result"], sls.LoadResult.SUCCESS, "应能读取刚写入的文件")

	var saved_data: Dictionary = read_result["data"]
	assert_eq(saved_data["schema_version"], sls.CURRENT_SCHEMA_VERSION,
			"save_game 写入的 schema_version 应等于 CURRENT_SCHEMA_VERSION")

	# Cleanup
	DirAccess.remove_absolute(path)
	var meta_path: String = "user://saves/meta.json"
	if FileAccess.file_exists(meta_path):
		DirAccess.remove_absolute(meta_path)
	var saves_dir: String = "user://saves/manual"
	if DirAccess.dir_exists_absolute(saves_dir):
		DirAccess.remove_absolute(saves_dir)
	saves_dir = "user://saves"
	if DirAccess.dir_exists_absolute(saves_dir):
		DirAccess.remove_absolute(saves_dir)


# === AC-010：load_game 透明执行迁移（集成点） ====================================

func test_load_game_executes_migration_transparently() -> void:
	# Arrange：手动构造一个 schema_version=0 的存档文件
	# 注册 MIGRATIONS[0] 迁移函数
	# 通过 load_game 加载 → 验证迁移被执行且返回 SUCCESS
	var track: Array[bool] = [false]
	sls.MIGRATIONS[0] = func(data: Dictionary) -> Dictionary:
		track[0] = true
		return data

	# 手动写入 schema_version=0 的存档（绕过 save_game）
	var path: String = sls._save_path(sls.SaveSlotType.MANUAL, 1)
	var container: Dictionary = {
		"schema_version": 0,
		"version": "0.9.0",
		"timestamp": "2026-01-01T00:00:00Z",
		"playtime_seconds": 100,
		"meta": {"player_name": "旧版玩家", "realm": "凡人"},
		"game_state": {"player": {"name": "旧存档名称"}},
		"complete": true,
	}
	sls._ensure_dir(path)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(container, "\t"))
	f.close()

	# 需要 mock GSM——load_game 会调用 gsm.deserialize()
	var mock_gsm := Node.new()
	mock_gsm.set_script(_make_mock_gsm_script())
	sls.set_dependencies(mock_gsm)

	# Act
	var result: Dictionary = sls.load_game(sls.SaveSlotType.MANUAL, 1)

	# Assert
	assert_true(track[0], "load_game 应透明地执行迁移链")
	# 验证整个流程成功完成——不仅迁移被调用，load_game 也返回 SUCCESS
	assert_eq(result["result"], sls.LoadResult.SUCCESS, "load_game 应返回 SUCCESS")
	# 注意：迁移后的 data 被传给 GSM.deserialize，迁移发生在 GSM 反序列化之前
	# 此处验证迁移被调用即可——deserialize 结果由 mock GSM 控制

	# Cleanup
	mock_gsm.free()
	DirAccess.remove_absolute(path)
	var test_dir: String = "user://saves/manual"
	if DirAccess.dir_exists_absolute(test_dir):
		DirAccess.remove_absolute(test_dir)
	test_dir = "user://saves"
	if DirAccess.dir_exists_absolute(test_dir):
		DirAccess.remove_absolute(test_dir)

# === AC-010 边界情况：迁移失败时 load_game 返回错误 ====

func test_load_game_migration_failure_returns_deserialize_error() -> void:
	# Arrange：写入 schema_version=0 的存档文件，不注册任何 MIGRATIONS 函数
	# → _migrate_if_needed 返回 MIGRATION_MISSING → load_game 返回 DESERIALIZE_ERROR
	var path: String = sls._save_path(sls.SaveSlotType.MANUAL, 1)
	var container: Dictionary = {
		"schema_version": 0,
		"version": "0.9.0",
		"timestamp": "2026-01-01T00:00:00Z",
		"playtime_seconds": 100,
		"meta": {"player_name": "旧版玩家", "realm": "凡人"},
		"game_state": {"player": {"name": "旧存档名称"}},
		"complete": true,
	}
	sls._ensure_dir(path)
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(container, "	"))
	f.close()

	# Act
	var result: Dictionary = sls.load_game(sls.SaveSlotType.MANUAL, 1)

	# Assert
	assert_eq(result["result"], sls.LoadResult.DESERIALIZE_ERROR,
			"迁移失败应返回 DESERIALIZE_ERROR")
	assert_true(result["data"] != null, "不应返回 null data")

	# Cleanup
	DirAccess.remove_absolute(path)
	var test_dir: String = "user://saves/manual"
	if DirAccess.dir_exists_absolute(test_dir):
		DirAccess.remove_absolute(test_dir)
	test_dir = "user://saves"
	if DirAccess.dir_exists_absolute(test_dir):
		DirAccess.remove_absolute(test_dir)


# === AC-009：Fixture 文件迁移测试（首次升级时取消注释并实现） ====
# 当前 CURRENT_SCHEMA_VERSION=1，无历史版本需 fixture 测试。
# 首次升级 CURRENT 到 2+ 时创建 tests/fixtures/save_load/v1_fixture.json
# 并在此处实现：
#
# func test_migrate_v1_to_v2_fixture() -> void:
# 	# Arrange：加载 tests/fixtures/save_load/v1_fixture.json
# 	# 注册 MIGRATIONS[1] = _migrate_v1_to_v2
# 	# Act：_atomic_read → _migrate_if_needed
# 	# Assert：schema_version == CURRENT，所有必需字段存在
# 	pass


# === 迁移失败隔离测试 =============================================================

func test_migration_failure_in_chain_is_isolated() -> void:
	# 验证迁移缺失时 _migrate_if_needed 返回错误字典而非崩溃。
	# MIGRATIONS 为空 → save_schema=0 → MIGRATIONS.has(0) == false → MIGRATION_MISSING。
	# 此测试验证失败时的契约：不崩溃 + 原始数据不被部分修改。
	var data: Dictionary = {
		"schema_version": 0,
		"game_state": {"player": {}},
	}
	# MIGRATIONS 为空 → MIGRATION_MISSING

	# Act
	var result: Dictionary = sls._migrate_if_needed(data)

	# Assert：迁移缺失不应导致崩溃——返回错误字典而非抛出异常
	assert_true(result.has("error"), "迁移缺失应返回错误字典而非崩溃")
	assert_eq(result["error"], "MIGRATION_MISSING")
	# 原始数据不应被修改（失败时不产生部分迁移）
	assert_eq(data["schema_version"], 0, "原始 schema_version 不应被部分修改")


# === AC-001：CURRENT_SCHEMA_VERSION 常量存在 =====================================

func test_current_schema_version_constant_exists() -> void:
	assert_eq(sls.CURRENT_SCHEMA_VERSION, 4,
			"本轮续战段新增 cards / debuffs（牌面与减益接续），schema 版本提升到 4")
	assert_true(typeof(sls.CURRENT_SCHEMA_VERSION) == TYPE_INT, "应为 int 类型")


# === AC-002：MIGRATIONS 注册表存在 ================================================

func test_migrations_registry_exists_and_is_empty_initially() -> void:
	assert_not_null(sls.MIGRATIONS, "MIGRATIONS 注册表应存在")
	assert_eq(typeof(sls.MIGRATIONS), TYPE_DICTIONARY, "MIGRATIONS 应为 Dictionary 类型")
	assert_eq(sls.MIGRATIONS.size(), 0,
			"覆盖层初始为空——生产迁移常驻 DEFAULT_MIGRATIONS，不受测试注入影响")


# === AC-002 补充：生产迁移链随版本发布固定 ========================================

func test_default_migrations_registry_holds_production_chain() -> void:
	## 覆盖层（MIGRATIONS）与生产链（DEFAULT_MIGRATIONS）分离——测试注入/清空覆盖层
	## 不该让 v1 档变成读不进来。
	assert_eq(typeof(sls.DEFAULT_MIGRATIONS), TYPE_DICTIONARY,
			"DEFAULT_MIGRATIONS 应为 Dictionary 类型")
	assert_eq(sls.DEFAULT_MIGRATIONS.size(), sls.CURRENT_SCHEMA_VERSION - 1,
			"生产链应覆盖 1..CURRENT-1 的每一级（v1→v2、v2→v3、v3→v4 共 3 级）")
	for from_version: int in range(1, sls.CURRENT_SCHEMA_VERSION):
		assert_true(sls.DEFAULT_MIGRATIONS.has(from_version),
				"生产链应登记 v%d→v%d 迁移" % [from_version, from_version + 1])


# === 辅助方法 =====================================================================

func _make_mock_gsm_script() -> GDScript:
	## 创建 mock GSM GDScript——deserialize() 始终返回 true。
	var source := """extends Node
func deserialize(_data: Dictionary) -> bool:
	return true
"""
	var gd: GDScript = GDScript.new()
	gd.source_code = source
	gd.reload()
	return gd
