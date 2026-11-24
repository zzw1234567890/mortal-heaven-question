extends GutTest
## SaveLoadSystem 公开面锁定 —— 拆分（按职责分成多层继承链）之前先钉死的对外契约。[br]
## [br][b]为什么先写这个[/b]：本轮要把 1027 行的 [code]save_load_system.gd[/code] 拆成
## 若干 ≤300 行的层，唯一的硬约束是「对外一个面都不许改」。既有用例只覆盖了其中一部分
## 成员（测试调用得到的），反射面本身没人钉——于是拆分完「少了一个方法 / 默认参数
## 掉了 / 枚举值漂了」这类事故只能靠事后碰运气发现。[br]
## [br][b]手法[/b]：沿脚本继承链收集 [method Script.get_script_method_list] 的
## 「名字 + 形参个数 + 默认值个数」，与硬编码快照逐项比对。方法住在哪一层不影响本用例
## ——它锁的是[b]实例解析得到的那个面[/b]，正是调用方（与既有用例）看到的面。[br]
## [br][b]为什么连私有方法一起锁[/b]：本库的用例大量直调
## [code]_atomic_write[/code] / [code]_save_path[/code] / [code]_migrate_if_needed[/code]
## 等私有面（Story 002/003/005 的验收就写在上面），它们事实上是对外契约的一部分。[br]
## [br][b]为什么参数个数也算[/b]：GDScript 重载只看名字，「默认参数掉了」不会报错——
## 只会让 [code]save_game(type, id)[/code] 这种既有写法在运行期炸。[br]
## [br]来源: .claude/docs/coding-standards.md §文件行数限制、本轮「按职责拆分
## save_load_system」任务的「对外 API 一个都不改名、不改签名、不删」硬约束。

const SLS := preload("res://src/foundation/save_load_system.gd")

## 方法快照——[code][名字, 形参个数, 带默认值的形参个数][/code]，按名字升序。[br]
## [br]改动本数组 = 改对外契约，必须是有意为之（并同步既有用例）。[br]
## 覆盖范围：4 个公开方法 + 其余全部被用例 / 产品代码触碰的成员（含私有）。
const EXPECTED_METHODS: Array = [
	["_atomic_read", 1, 0],
	["_atomic_write", 2, 0],
	["_build_save_container", 2, 0],
	["_clear_session_input_locks", 0, 0],
	["_ensure_dir", 1, 0],
	["_get_card_system", 0, 0],
	["_get_deployment_system", 0, 0],
	["_get_gsm", 0, 0],
	["_get_save_root", 0, 0],
	["_is_json_compatible", 1, 0],
	["_load_meta_json", 0, 0],
	["_mark_slot_empty", 2, 0],
	["_migrate_if_needed", 1, 0],
	["_migrate_v1_to_v2", 1, 0],
	["_migrate_v2_to_v3", 1, 0],
	["_migrate_v3_to_v4", 1, 0],
	["_migration_for", 1, 0],
	["_parse_json_file", 1, 0],
	["_ready", 0, 0],
	["_rename_with_retry", 2, 0],
	["_restore_deployment_from_gsm", 0, 0],
	["_save_path", 2, 1],
	["_serialize_to_json", 1, 0],
	["_slot_key", 2, 0],
	["_update_meta_json", 3, 0],
	["_validate_save_data", 1, 0],
	["_validate_version", 1, 0],
	["_write_meta_json", 1, 0],
	["auto_save", 0, 0],
	["build_slot_meta", 1, 1],
	["clear_battle_snapshot", 0, 0],
	["create_battle_snapshot", 1, 0],
	["delete_save", 2, 1],
	["get_slot_meta", 2, 1],
	["list_slots", 0, 0],
	["load_game", 2, 1],
	["load_progression", 0, 0],
	["restore_battle_snapshot", 0, 0],
	["save_game", 4, 3],
	["set_dependencies", 2, 2],
]

## 信号快照——[code][名字, 载荷个数][/code]，按名字升序。
const EXPECTED_SIGNALS: Array = [
	["load_completed", 1],
	["load_started", 2],
	["progression_saved", 1],
	["save_completed", 3],
	["save_corrupted", 3],
]


var _probe: Node = null


func before_each() -> void:
	# 静态 var MIGRATIONS 是共享存储——用例只在别处 clear 时读到空，
	# 本组只读不写，无需还原；但仍清一遍以保证「初始为空」的断言不受前序用例影响。
	SLS.MIGRATIONS.clear()
	# 取脚本反射面要经实例（GDScript 上的 `X.method()` 会被当成静态调用而报错）。
	_probe = SLS.new()


func after_each() -> void:
	if _probe != null:
		_probe.free()
		_probe = null


# ═══════════════════════════════════════════════════════════════════════════════
# 方法面
# ═══════════════════════════════════════════════════════════════════════════════

func test_method_face_matches_snapshot() -> void:
	# Act
	var got: Array = _collect_method_face()

	# Assert
	if got != EXPECTED_METHODS:
		# 失败时把实际值按可粘贴的形态打出来——省去手工对账
		print("=== 实际方法面（可粘贴） ===")
		for row: Array in got:
			print("\t[%s], " % str(row).replace("\"", "\""))
		fail_test("方法面与快照不符（期望 %d 项，实际 %d 项）——新增/删除/改名/参数变化"
				% [EXPECTED_METHODS.size(), got.size()])
	assert_eq(got, EXPECTED_METHODS, "方法面应与快照逐项一致（名字 + 形参个数 + 默认值个数）")


func test_method_face_has_no_duplicate_names() -> void:
	## 拆成继承链后，「同一个方法被写在两层」是最容易犯且最难发现的错——Godot 不报错，
	## 只有最派生那份生效，另一份成了死代码（改它等于没改）。
	## [br]注意：[method Script.get_script_method_list] 返回的是[b]已展平[/b]的视图
	## （含继承来的方法，覆写会出现两次），故只看叶子这一份即可，无需逐层遍历
	## ——逐层遍历会把每个方法数出「层数」次，那是假阳性。
	var counts: Dictionary = {}
	for m: Dictionary in _leaf_script().get_script_method_list():
		var n := str(m["name"])
		counts[n] = int(counts.get(n, 0)) + 1

	var duplicated: Array[String] = []
	for n: String in counts.keys():
		if int(counts[n]) > 1:
			duplicated.append("%s×%d" % [n, counts[n]])
	duplicated.sort()
	assert_eq(duplicated, [] as Array[String],
			"成员面里不应有同名方法出现两次（重复声明或覆写——两者都要显式确认）")


# ═══════════════════════════════════════════════════════════════════════════════
# 常量 / 枚举 / 静态表 / 信号
# ═══════════════════════════════════════════════════════════════════════════════

func test_constants_accessible_on_script_class() -> void:
	## 调用方（产品代码与用例）全部经 [code]SLS.XXX[/code] 取这些常量——
	## 拆分后常量可能落在任一层，脚本类上的解析必须照旧。
	assert_eq(SLS.MAX_RENAME_RETRIES, 3, "MAX_RENAME_RETRIES 应为 3")
	assert_eq(SLS.RENAME_RETRY_DELAY_MS, 50, "RENAME_RETRY_DELAY_MS 应为 50")
	assert_eq(SLS.CURRENT_SCHEMA_VERSION, 4, "CURRENT_SCHEMA_VERSION 应为 4")


func test_enums_accessible_on_script_class() -> void:
	## 枚举值本身就是存档格式的一部分（SaveResult 的码会进存档容器），逐值钉死。
	assert_eq(SLS.SaveSlotType.AUTOSAVE, 0)
	assert_eq(SLS.SaveSlotType.MANUAL, 1)
	assert_eq(SLS.SaveSlotType.SNAPSHOT, 2)
	assert_eq(SLS.SaveSlotType.size(), 3, "SaveSlotType 不应增删枚举值")

	assert_eq(SLS.SaveResult.SUCCESS, 0)
	assert_eq(SLS.SaveResult.DISK_FULL, 1)
	assert_eq(SLS.SaveResult.WRITE_ERROR, 2)
	assert_eq(SLS.SaveResult.VALIDATION_ERROR, 3)
	assert_eq(SLS.SaveResult.size(), 4, "SaveResult 不应增删枚举值")

	assert_eq(SLS.LoadResult.SUCCESS, 0)
	assert_eq(SLS.LoadResult.FILE_NOT_FOUND, 1)
	assert_eq(SLS.LoadResult.CORRUPTED, 2)
	assert_eq(SLS.LoadResult.VERSION_MISMATCH, 3)
	assert_eq(SLS.LoadResult.DESERIALIZE_ERROR, 4)
	assert_eq(SLS.LoadResult.size(), 5, "LoadResult 不应增删枚举值")


func test_static_registries_accessible_on_script_class() -> void:
	## MIGRATIONS 是 static var（用例注入迁移函数的入口），DEFAULT_MIGRATIONS 是生产链。
	## 两者都在脚本类上可取，且键集完整——拆分不许让它们变成「只有某一层看得见」。
	assert_eq(typeof(SLS.MIGRATIONS), TYPE_DICTIONARY, "MIGRATIONS 应为 Dictionary")
	assert_eq(SLS.MIGRATIONS.size(), 0, "MIGRATIONS 覆盖层初始应为空")
	assert_eq(typeof(SLS.DEFAULT_MIGRATIONS), TYPE_DICTIONARY,
			"DEFAULT_MIGRATIONS 应为 Dictionary")
	for from_version: int in range(1, SLS.CURRENT_SCHEMA_VERSION):
		assert_true(SLS.DEFAULT_MIGRATIONS.has(from_version),
				"生产链应登记 v%d→v%d" % [from_version, from_version + 1])


func test_signal_face_matches_snapshot() -> void:
	# Act
	var got: Array = _collect_signal_face()

	# Assert
	if got != EXPECTED_SIGNALS:
		print("=== 实际信号面（可粘贴） ===")
		for row: Array in got:
			print("\t[%s], " % str(row))
		fail_test("信号面与快照不符（期望 %d 项，实际 %d 项）" % [EXPECTED_SIGNALS.size(), got.size()])
	assert_eq(got, EXPECTED_SIGNALS, "信号面应与快照逐项一致（名字 + 载荷个数）")


func test_instance_state_fields_start_at_declared_defaults() -> void:
	## 实例状态字段（重入防护 / 排队标志 / 注入引用）在拆分后必须仍落在实例上——
	## 若某层误用 static var，两个实例就会共用一个标志（用例之间互相污染），
	## 这类事故在「跨层同名」时极易发生。
	var a: Node = SLS.new()
	var b: Node = SLS.new()
	a._is_writing = true
	assert_false(b._is_writing, "_is_writing 必须是实例字段，不应被 static 化跨实例共享")
	a.free()
	b.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════════════════

## 叶子脚本（[constant SLS] 指向的那一份）。
func _leaf_script() -> Script:
	return _probe.get_script()


## [code][名字, 形参个数, 默认值个数][/code]，去重（最派生优先）后按名字升序。
func _collect_method_face() -> Array:
	var by_name: Dictionary = {}
	var script: Script = _leaf_script()
	while script != null:
		for m: Dictionary in script.get_script_method_list():
			var n := str(m["name"])
			if by_name.has(n):
				continue
			by_name[n] = [n,
					(m.get("args", []) as Array).size(),
					(m.get("default_args", []) as Array).size()]
		script = script.get_base_script()

	var names: Array = by_name.keys()
	names.sort()
	var out: Array = []
	for n: String in names:
		out.append(by_name[n])
	return out


## [code][名字, 载荷个数][/code]，按名字升序。
func _collect_signal_face() -> Array:
	var by_name: Dictionary = {}
	for s: Dictionary in _leaf_script().get_script_signal_list():
		by_name[str(s["name"])] = [str(s["name"]), (s.get("args", []) as Array).size()]

	var names: Array = by_name.keys()
	names.sort()
	var out: Array = []
	for n: String in names:
		out.append(by_name[n])
	return out
