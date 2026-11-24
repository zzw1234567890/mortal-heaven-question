extends GutTest
## DeploymentSystem 公开面锁定守卫——拆分重构前置护栏。
##
## [b]为什么需要这条守卫[/b]：[code]src/feature/deployment_system.gd[/code]（596 行）要按职责
## 拆成继承链。拆分的唯一硬约束是「对外 API 逐位不变」——方法名、形参个数、默认参数个数[b]与值[/b]、
## 枚举取值、信号载荷、脚本常量、实例字段，一个都不许改。危险在于[b]编译器不会替我们发现断链[/b]：
## 产品代码（战斗域 24 个文件 + UI/存档域）、约 20 个既有测试文件、以及 3 个 RefCounted 子模块
## 全靠动态分派访问这个面——[code]ds.call("setup_field", ...)[/code] /
## [code]ds.get("_field")[/code] / [code]DS_SCRIPT.FieldState.EMPTY[/code] /
## [code]_parent.get("SLOT_COUNT")[/code] / [code]_parent.call("_state_to_string", ...)[/code]，
## 名字打错或漏拆只是运行时 push_error / 静默返回 null，不报语法错。
## 故先把「面」钉成反射快照，拆完复跑。
##
## [b]锁什么[/b]：
##   · 22 个公开方法 + 18 个私有方法的[形参个数 / 默认参数个数 / 默认参数值]
##   · [enum FieldState] 5 项取值 + 项数（产品代码按名直取：[code]DS_SCRIPT.FieldState.DEAD[/code]）
##   · 6 个 Cat 2b 信号的载荷[个数 + 名字]（[code]deploy_panel[/code] 按名 connect）
##   · 3 个脚本常量仍可解析且值不变（子模块经 [code]_parent.get("SLOT_COUNT")[/code] 取用）
##   · 6 个实例字段存在且[b]未被 static 化[/b]（两个实例互不影响）
##   · 面内不得出现未登记的方法（新增/改名都要显式更新本快照）
##   · 面仍然可调用（setup_field → 查询 → 回合推进 → 序列化 → 阵亡清位 一趟真行为）
##
## [b]不锁什么[/b]：函数体实现、注释、成员落在哪个文件——这些正是拆分要动的东西。
##
## 来源: .claude/docs/coding-standards.md §文件行数限制（300 行软上限）、ADR-0016 §关键接口。

const DS_SCRIPT := preload("res://src/feature/deployment_system.gd")

## 公开方法快照——{方法名: [形参个数, [默认参数值...]]}。
const EXPECTED_PUBLIC: Dictionary = {
	"can_deploy": [0, []], "clear_standby_state": [0, []],
	"deploy": [3, [-1]], "deserialize_field": [1, []],
	"get_character_slot": [1, []], "get_empty_slots": [0, []],
	"get_field": [0, []], "get_front_count": [1, [true]],
	"get_unavailable_characters": [0, []], "is_game_over": [1, []],
	"is_standby": [1, []], "is_targetable": [2, [false]],
	"load_unavailable_from_gsm": [1, []], "mark_unavailable": [2, []],
	"remove_character": [2, ["died"]], "restore_unavailable_from_storage": [0, []],
	"revive_character": [1, []], "serialize_field": [0, []],
	"set_acted": [1, []], "setup_field": [2, [null]],
	"sync_unavailable_to_gsm": [0, []], "write_snapshot_to_gsm": [0, []],
}

## 私有方法快照——3 个 RefCounted 子模块经 [code]_parent.call("_xxx")[/code] /
## [code]_parent.get("_xxx")[/code] 访问，同属「面」，一并锁。
const EXPECTED_PRIVATE: Dictionary = {
	"_assign_slots": [2, []], "_emit_character_deployed": [4, []],
	"_emit_character_removed": [3, []], "_emit_character_revived": [1, []],
	"_emit_character_unavailable": [1, []], "_emit_front_line_breached": [0, []],
	"_emit_standby_cleared": [1, []], "_get_emitter": [0, []],
	"_get_gsm": [0, []], "_get_serializer": [0, []],
	"_get_slot_allocator": [0, []], "_init": [0, []],
	"_is_front": [1, []], "_push_unavailable_to_gsm": [0, []],
	"_query_max_deploy": [0, []], "_reset_field": [0, []],
	"_state_from_string": [1, []], "_state_to_string": [1, []],
}

## 信号载荷快照——[code]{信号名: [载荷名...]}[/code]（个数与名字逐位不变）。
const EXPECTED_SIGNALS: Dictionary = {
	"character_deployed": ["character_id", "slot_index", "is_front", "deploy_turn"],
	"character_removed": ["character_id", "slot_index", "reason"],
	"front_line_breached": [],
	"standby_cleared": ["character_ids"],
	"character_unavailable": ["character_id"],
	"character_revived": ["character_id"],
}

## 脚本常量快照——值即契约（子模块按名直取）。
const EXPECTED_CONSTANTS: Dictionary = {
	"SLOT_COUNT": 6, "FRONT_SLOTS": 3,
}

## 境界→前排配额映射快照（阵位分布规则，GDD §2）。
const EXPECTED_FRONT_CAPACITY: Dictionary = {2: 2, 3: 2, 4: 2, 5: 3, 6: 3}

## 实例字段快照——拆分后仍是[b]实例[/b]字段（不得因搬文件误写成 static）。
const EXPECTED_FIELDS: Array[String] = [
	"_emitter", "_field", "_front_line_breached_emitted",
	"_serializer", "_slot_allocator", "_unavailable_characters",
]

## FieldState 枚举快照——成员名 → 取值。
const EXPECTED_FIELD_STATE: Dictionary = {
	"EMPTY": 0, "STANDBY": 1, "READY": 2, "ACTED": 3, "DEAD": 4,
}

var ds: Node = null


func before_each() -> void:
	ds = DS_SCRIPT.new()


func after_each() -> void:
	GameStateManager.player.realm = GameStateManager.RealmLevel.QI_REFINING
	if ds != null:
		ds.free()
		ds = null


## 反射收集方法表——[code]name -> {args, default_args}[/code]。
func _method_table() -> Dictionary:
	var table: Dictionary = {}
	for m: Dictionary in ds.get_method_list():
		table[String(m["name"])] = m
	return table


## 逐一比对快照中的方法：存在 + 形参个数 + 默认参数个数 + 默认参数值。
func _assert_methods(snapshot: Dictionary, label: String) -> void:
	var table: Dictionary = _method_table()
	var checked: int = 0
	for method_name: String in snapshot:
		var expected: Array = snapshot[method_name]
		assert_true(table.has(method_name), "%s方法 %s 应存在（拆分后不得丢）" % [label, method_name])
		if not table.has(method_name):
			continue
		var entry: Dictionary = table[method_name]
		var args: Array = entry.get("args", [])
		var defaults: Array = entry.get("default_args", [])
		var want_defaults: Array = expected[1]
		assert_eq(args.size(), int(expected[0]),
			"%s方法 %s 形参个数应不变" % [label, method_name])
		assert_eq(defaults.size(), want_defaults.size(),
			"%s方法 %s 默认参数个数应不变" % [label, method_name])
		assert_eq(defaults, want_defaults,
			"%s方法 %s 默认参数值应逐位不变" % [label, method_name])
		checked += 1
	assert_eq(checked, snapshot.size(), "%s方法快照应全部比对到" % label)


## 逐名取 FieldState 的成员名列表（脚本级直取——外部 [code]DS_SCRIPT.FieldState.X[/code] 的形态）。
func _enum_member_names() -> Array:
	var names: Array = (DS_SCRIPT.FieldState as Dictionary).keys()
	names.sort()
	return names


# ============================================================================
# 1. 方法面：22 公开 + 18 私有，签名逐位不变
# ============================================================================

func test_public_methods_locked() -> void:
	assert_eq(EXPECTED_PUBLIC.size(), 22, "公开方法快照应 22 个")
	_assert_methods(EXPECTED_PUBLIC, "公开")


func test_private_methods_locked() -> void:
	assert_eq(EXPECTED_PRIVATE.size(), 18, "私有方法快照应 18 个")
	_assert_methods(EXPECTED_PRIVATE, "私有")


func test_no_untracked_script_methods() -> void:
	# 面内不得出现未登记的方法——新增/改名都要显式更新本快照。
	# 判据：get_method_list() 减去 Node 及其祖先的内建方法，再减去已登记快照。
	var builtin: Dictionary = {}
	for m: Dictionary in ClassDB.class_get_method_list(&"Node"):
		builtin[String(m["name"])] = true
	var untracked: Array[String] = []
	for m: Dictionary in ds.get_method_list():
		var method_name: String = String(m["name"])
		if builtin.has(method_name):
			continue
		if EXPECTED_PUBLIC.has(method_name) or EXPECTED_PRIVATE.has(method_name):
			continue
		if untracked.has(method_name):
			continue
		untracked.append(method_name)
	assert_eq(untracked.size(), 0, "不应出现未登记的方法：%s" % str(untracked))


# ============================================================================
# 2. 枚举面：FieldState 5 项，取值即契约（产品代码按名直取）
# ============================================================================

func test_field_state_enum_locked() -> void:
	assert_eq(DS_SCRIPT.FieldState.EMPTY, 0, "EMPTY=0")
	assert_eq(DS_SCRIPT.FieldState.STANDBY, 1, "STANDBY=1")
	assert_eq(DS_SCRIPT.FieldState.READY, 2, "READY=2")
	assert_eq(DS_SCRIPT.FieldState.ACTED, 3, "ACTED=3")
	assert_eq(DS_SCRIPT.FieldState.DEAD, 4, "DEAD=4")
	assert_eq(_enum_member_names().size(), 5, "FieldState 应恰好 5 项")
	assert_eq(EXPECTED_FIELD_STATE.size(), 5, "FieldState 快照应 5 项")
	# 经实例的 Object.get 取同名枚举——外部「先 new 再取」的形态也须解析
	assert_not_null(ds.get("FieldState"), "实例 get(\"FieldState\") 仍可解析")


# ============================================================================
# 3. 信号面：6 个 Cat 2b 信号，载荷名字与个数逐位不变
# ============================================================================

func test_signals_locked() -> void:
	var table: Dictionary = {}
	for s: Dictionary in ds.get_signal_list():
		table[String(s["name"])] = s
	for signal_name: String in EXPECTED_SIGNALS:
		assert_true(table.has(signal_name), "信号 %s 应存在" % signal_name)
		if not table.has(signal_name):
			continue
		var args: Array = table[signal_name].get("args", [])
		var want: Array = EXPECTED_SIGNALS[signal_name]
		var got_names: Array[String] = []
		for a: Dictionary in args:
			got_names.append(String(a.get("name", "")))
		assert_eq(args.size(), want.size(), "信号 %s 载荷个数应不变" % signal_name)
		assert_eq(got_names, want, "信号 %s 载荷名字应逐位不变" % signal_name)
	assert_eq(EXPECTED_SIGNALS.size(), 6, "信号快照应 6 个")


# ============================================================================
# 4. 常量面：SLOT_COUNT / FRONT_SLOTS / FRONT_CAPACITY_BY_MAX_DEPLOY 值不变
# ============================================================================

func test_constants_locked() -> void:
	# 逐名直取（产品代码与子模块的写法）——常量沿继承链解析。
	# [b]不用[/b] [method Script.get_script_constant_map]：它只列出[b]本文件[/b]声明的常量，
	# 拆分后返回子集（探针实测：枚举会消失），会把「常量搬到了祖先段」误判成「常量丢了」
	# ——而沿链直取恰恰是拆分要保住的那个行为。
	assert_eq(DS_SCRIPT.SLOT_COUNT, EXPECTED_CONSTANTS["SLOT_COUNT"], "SLOT_COUNT 应不变")
	assert_eq(DS_SCRIPT.FRONT_SLOTS, EXPECTED_CONSTANTS["FRONT_SLOTS"], "FRONT_SLOTS 应不变")
	assert_eq(DS_SCRIPT.FRONT_CAPACITY_BY_MAX_DEPLOY, EXPECTED_FRONT_CAPACITY,
		"FRONT_CAPACITY_BY_MAX_DEPLOY 应不变")
	assert_eq(EXPECTED_CONSTANTS.size(), 2, "常量快照应 2 个标量")
	# 实例经 Object.get 取同名常量——子模块的取用方式，也须解析
	assert_eq(ds.get("SLOT_COUNT"), 6, "实例 get(\"SLOT_COUNT\") 仍可解析")
	assert_not_null(ds.get("FRONT_CAPACITY_BY_MAX_DEPLOY"), "实例 get 映射表仍可解析")
	# 空位 is_front 哨兵：slot 0/1/2 前排、3/4/5 后排——_is_front 的边界
	assert_true(ds.call("_is_front", 0), "slot 0 属前排")
	assert_true(ds.call("_is_front", 2), "slot 2 属前排")
	assert_false(ds.call("_is_front", 3), "slot 3 属后排")
	assert_false(ds.call("_is_front", 6), "越界 slot 不属前排")


# ============================================================================
# 5. 字段面：6 个实例字段在册，且仍是实例字段（未被 static 化）
# ============================================================================

func test_instance_fields_locked() -> void:
	var found: Dictionary = {}
	for p: Dictionary in ds.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			found[String(p["name"])] = true
	for field_name: String in EXPECTED_FIELDS:
		assert_true(found.has(field_name), "实例字段 %s 应存在" % field_name)
	assert_eq(found.size(), EXPECTED_FIELDS.size(),
		"脚本实例字段应恰好 %d 个：%s" % [EXPECTED_FIELDS.size(), str(found.keys())])


func test_fields_not_staticized() -> void:
	# 两个实例互不影响——若拆分时把 var 误写成 static var，此处立刻变红。
	var other: Node = DS_SCRIPT.new()
	ds.set("_front_line_breached_emitted", true)
	assert_false(other.get("_front_line_breached_emitted"), "另一实例的破防标志不受影响")

	ds.set("_field", {})
	assert_eq((other.get("_field") as Dictionary).size(), 6, "另一实例的阵位表不受影响")

	var mine_unavailable: Dictionary = ds.get("_unavailable_characters")
	mine_unavailable[999] = {"death_turn": 1}
	assert_false((other.get("_unavailable_characters") as Dictionary).has(999),
		"另一实例的不可用名单不受影响")

	ds.set("_serializer", ds)
	assert_null(other.get("_serializer"), "另一实例的子模块缓存不受影响")
	ds.set("_slot_allocator", ds)
	assert_null(other.get("_slot_allocator"), "另一实例的分配器缓存不受影响")
	ds.set("_emitter", ds)
	assert_null(other.get("_emitter"), "另一实例的发射器缓存不受影响")

	other.free()


# ============================================================================
# 6. 面仍然可调用：备战 → 查询 → 回合推进 → 序列化 → 阵亡清位 一趟真行为
# ============================================================================

func test_face_still_callable_end_to_end() -> void:
	GameStateManager.player.realm = GameStateManager.RealmLevel.GOLDEN_CORE  # max_deploy=4

	assert_true(ds.call("setup_field", [201, 202], {}), "setup_field 仍可用")
	var field: Array = ds.call("get_field")
	assert_eq(field.size(), 6, "get_field 仍返回 6 槽")
	assert_eq(ds.call("get_character_slot", 201), 0, "get_character_slot 仍可用")
	assert_true(ds.call("is_standby", 201), "上场角色应为 STANDBY")
	assert_eq(ds.call("get_front_count", true), 2, "get_front_count 仍可用")
	assert_eq((ds.call("get_empty_slots") as Array).size(), 4, "get_empty_slots 仍可用")
	var cd: Dictionary = ds.call("can_deploy")
	assert_true(cd.has("can_deploy"), "can_deploy 仍返回具名字典")

	ds.call("clear_standby_state")           # STANDBY → READY
	assert_false(ds.call("is_standby", 201), "clear_standby_state 仍可用")
	ds.call("set_acted", 201)                # READY → ACTED
	assert_eq((ds.call("get_field") as Array)[0]["state"], DS_SCRIPT.FieldState.ACTED,
		"set_acted 仍可用")
	assert_true(ds.call("is_targetable", 201), "前排角色始终可被攻击")

	var snap: Dictionary = ds.call("serialize_field")
	assert_true(snap.has(0), "serialize_field 仍返回逐槽快照")
	ds.call("deserialize_field", snap)
	assert_eq(ds.call("get_character_slot", 202), 1, "deserialize_field 仍可恢复阵位")

	ds.call("mark_unavailable", 201, {"death_turn": 3, "death_battle_id": "b1"})
	assert_eq((ds.call("get_unavailable_characters") as Array).size(), 1,
		"mark_unavailable / get_unavailable_characters 仍可用")
	assert_false(ds.call("is_game_over", [201, 202]), "202 仍可用——不判负")
	assert_true(ds.call("revive_character", 201), "revive_character 仍可用")
	assert_eq((ds.call("get_unavailable_characters") as Array).size(), 0, "复活后名单清空")

	ds.call("remove_character", 201, "died")
	assert_eq(ds.call("get_character_slot", 201), -1, "remove_character 仍可用")
	assert_null(ds.call("sync_unavailable_to_gsm"), "sync_unavailable_to_gsm 仍可调用")
	ds.call("write_snapshot_to_gsm")
	ds.call("restore_unavailable_from_storage")
	ds.call("load_unavailable_from_gsm", {})
	assert_eq((ds.call("get_unavailable_characters") as Array).size(), 0,
		"load_unavailable_from_gsm 仍可用（整表替换为空）")
