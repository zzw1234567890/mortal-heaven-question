extends GutTest
## BindingManager 公开面锁定守卫——拆分重构前置护栏。
##
## [b]为什么需要这条守卫[/b]：[code]binding_manager.gd[/code]（732 行）要按职责拆成继承链。
## 拆分的唯一硬约束是「对外 API 逐位不变」——方法名、形参个数、默认参数个数[b]与值[/b]、
## 信号载荷个数、常量值、实例字段，一个都不许改。危险在于[b]编译器不会替我们发现断链[/b]：
## 产品代码与既有 7 个测试文件全靠动态分派访问这个面——[code]bm.call("bind_card", ...)[/code] /
## [code]bm.get("_bindings")[/code] / [code]bm.set("stat_bonus_cb", ...)[/code]，名字打错或漏拆
## 只是运行时 push_error / 静默返回 null，不报语法错。故先把「面」钉成反射快照，拆完复跑。
##
## [b]锁什么[/b]：
##   · 20 个公开方法 + 25 个私有方法的[形参个数 / 默认参数个数 / 默认参数值]
##   · 7 个 Cat 2b 信号的载荷参数个数
##   · 4 个脚本常量可取值（[constant NATIVE_MULTIPLIER] 被 [BindingSlotOps] 经
##     [code]_parent.get("NATIVE_MULTIPLIER")[/code] 取值——拆分后常量仍须沿链解析）
##   · 16 个实例字段存在且[b]未被 static 化[/b]（两个实例互不影响）
##   · 面内不得出现未登记的方法（新增/改名都要显式更新本快照）
##   · 面仍然可调用（bind → 查询 → 序列化 一趟真行为）
##
## [b]不锁什么[/b]：函数体实现、注释、成员落在哪个文件——这些正是拆分要动的东西。
##
## 来源: .claude/docs/coding-standards.md §文件行数限制（300 行软上限）、ADR-0013 §关键接口。

const BM_SCRIPT := preload("res://src/feature/binding/binding_manager.gd")
const BRClass := preload("res://src/feature/binding/binding_record.gd")
const BindingSlot := preload("res://src/feature/binding/binding_record.gd").BindingSlot

const GONGFA: int = BindingSlot.GONGFA

## 公开方法快照——{方法名: [形参个数, [默认参数值...]]}。
const EXPECTED_PUBLIC: Dictionary = {
	"get_binding_ids_by_character": [1, []],
	# 2026-11-28 新增：UI 画功法/法宝栏要一个跨层可调用的只读计数（原先只有下划线私有版）。
	"count_bound_slots": [2, []],
	"get_bindings_by_character": [1, []],
	"get_character_by_card": [1, []],
	"get_binding": [1, []],
	"cache_slot_limits": [1, []],
	"bind_card": [6, [&"", &""]],
	"stack_card": [4, [3]],
	"overwrite_binding": [6, [&"", &""]],
	"can_bind": [4, [3]],
	"remove_binding": [1, []],
	"remove_all_bindings": [1, []],
	"suspend_bindings": [1, []],
	"restore_bindings": [1, []],
	"get_accumulated_bonus": [2, []],
	"get_damage_reduction_pcts": [1, []],
	"compute_effective_value": [4, []],
	"serialize_all": [0, []],
	"deserialize_all": [1, []],
	"write_snapshot_to_gsm": [0, []],
	"get_binding_context": [1, []],
}

## 私有方法快照——测试与三个子模块（BindingSlotOps / BindingDamageReduction /
## BindingSerializer）经 [code].call("_xxx")[/code] / [code].get("_xxx")[/code] 访问，
## 同属「面」，一并锁。
const EXPECTED_PRIVATE: Dictionary = {
	"_ready": [0, []],
	"_inject_callbacks": [0, []],
	"_register_binding": [1, []],
	"_unregister_binding": [1, []],
	"_query_realm_slots": [2, []],
	"_get_slot_limit": [1, []],
	"_get_slot_ops": [0, []],
	"_get_damage_reduction": [0, []],
	"_make_record": [5, []],
	"_determine_native": [4, []],
	"_native_matches": [2, []],
	"_has_native_binding": [2, []],
	"_count_bound_slots": [2, []],
	"_find_same_template_binding": [2, []],
	"_find_binding_at_slot": [2, []],
	"_find_free_slot_index": [3, []],
	"_serialize_record": [1, []],
	"_invoke_cb": [2, []],
	"_emit_safe": [2, []],
	"_query_card_exists": [1, []],
	"_query_stat_bonus": [2, []],
	"_deserialize_record": [1, []],
	"_clear_all": [0, []],
	"_get_gsm": [0, []],
	"_get_serializer": [0, []],
}

## 信号载荷参数个数快照。
const EXPECTED_SIGNALS: Dictionary = {
	"binding_applied": 6,
	"binding_removed": 4,
	"binding_overwritten": 4,
	"binding_stacked": 4,
	"binding_suspended": 2,
	"binding_restored": 2,
	"native_activated": 3,
}

## 脚本常量快照——值即契约（NATIVE_MULTIPLIER 被 slot_ops 经 get 取值）。
const EXPECTED_CONSTANTS: Dictionary = {
	"NATIVE_MULTIPLIER": 1.5,
	"DEFAULT_STACK_MULTIPLIER": 1.5,
	"DEFAULT_SLOT_LIMIT": 1,
}

## 实例字段快照——拆分后仍是[b]实例[/b]字段（不得因搬文件误写成 static）。
const EXPECTED_FIELDS: Array[String] = [
	"_bindings", "_by_character", "_card_to_character",
	"_slot_ops", "_damage_reduction",
	"_next_binding_id", "_slot_limits", "_serializer",
	"effect_register_cb", "effect_remove_cb", "effect_suspend_cb", "effect_restore_cb",
	"card_shuffle_cb", "card_discard_cb", "card_exists_cb", "stat_bonus_cb",
]

var bm: Node = null


func before_each() -> void:
	bm = BM_SCRIPT.new()


func after_each() -> void:
	if bm != null:
		bm.free()
		bm = null


## 反射收集方法表——[code]name -> {args, default_args}[/code]。
func _method_table() -> Dictionary:
	var table: Dictionary = {}
	for m: Dictionary in bm.get_method_list():
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


# ============================================================================
# 1. 方法面：20 公开 + 25 私有，签名逐位不变
# ============================================================================

func test_public_methods_locked() -> void:
	assert_eq(EXPECTED_PUBLIC.size(), 20, "公开方法快照应 20 个")
	_assert_methods(EXPECTED_PUBLIC, "公开")


func test_private_methods_locked() -> void:
	assert_eq(EXPECTED_PRIVATE.size(), 25, "私有方法快照应 25 个")
	_assert_methods(EXPECTED_PRIVATE, "私有")


func test_no_untracked_script_methods() -> void:
	# 面内不得出现未登记的方法——新增/改名都要显式更新本快照。
	# 判据：get_method_list() 减去 Node 及其祖先的内建方法，再减去已登记快照。
	var builtin: Dictionary = {}
	for m: Dictionary in ClassDB.class_get_method_list(&"Node"):
		builtin[String(m["name"])] = true
	var untracked: Array[String] = []
	for m: Dictionary in bm.get_method_list():
		var method_name: String = String(m["name"])
		if builtin.has(method_name):
			continue
		if EXPECTED_PUBLIC.has(method_name) or EXPECTED_PRIVATE.has(method_name):
			continue
		untracked.append(method_name)
	assert_eq(untracked.size(), 0, "不应出现未登记的方法：%s" % str(untracked))


# ============================================================================
# 2. 信号面：7 个 Cat 2b 信号，载荷个数逐位不变
# ============================================================================

func test_signals_locked() -> void:
	var table: Dictionary = {}
	for s: Dictionary in bm.get_signal_list():
		table[String(s["name"])] = s
	for signal_name: String in EXPECTED_SIGNALS:
		assert_true(table.has(signal_name), "信号 %s 应存在" % signal_name)
		if not table.has(signal_name):
			continue
		var args: Array = table[signal_name].get("args", [])
		assert_eq(args.size(), int(EXPECTED_SIGNALS[signal_name]),
			"信号 %s 载荷个数应不变" % signal_name)


# ============================================================================
# 3. 常量面：值即契约（含 slot_ops 经 Object.get 取的那一个）
# ============================================================================

func test_constants_locked() -> void:
	for const_name: String in EXPECTED_CONSTANTS:
		assert_eq(bm.get(const_name), EXPECTED_CONSTANTS[const_name],
			"常量 %s 应可取值且值不变" % const_name)
	# 直接经脚本类访问（产品代码写法）——拆分后仍须解析
	assert_eq(BM_SCRIPT.NATIVE_MULTIPLIER, 1.5, "BM_SCRIPT.NATIVE_MULTIPLIER 直接访问仍为 1.5")
	assert_eq(BM_SCRIPT.DEFAULT_SLOT_LIMIT, 1, "BM_SCRIPT.DEFAULT_SLOT_LIMIT 直接访问仍为 1")
	assert_true(BM_SCRIPT.StackFactor != null, "BM_SCRIPT.StackFactor 常量仍可解析")


# ============================================================================
# 4. 字段面：16 个实例字段在册，且仍是实例字段（未被 static 化）
# ============================================================================

func test_instance_fields_locked() -> void:
	var found: Dictionary = {}
	for p: Dictionary in bm.get_property_list():
		if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE != 0:
			found[String(p["name"])] = true
	for field_name: String in EXPECTED_FIELDS:
		assert_true(found.has(field_name), "实例字段 %s 应存在" % field_name)
	assert_eq(found.size(), EXPECTED_FIELDS.size(),
		"脚本实例字段应恰好 16 个：%s" % str(found.keys()))


func test_fields_not_staticized() -> void:
	# 两个实例互不影响——若拆分时把 var 误写成 static var，此处立刻变红。
	var other: Node = BM_SCRIPT.new()
	bm.set("_next_binding_id", 99)
	assert_eq(other.get("_next_binding_id"), 1, "另一实例的 _next_binding_id 不受影响")

	var mine: Dictionary = bm.get("_bindings")
	mine[4242] = BRClass.new()
	var theirs: Dictionary = other.get("_bindings")
	assert_false(theirs.has(4242), "另一实例的 _bindings 不受影响")

	var mine_chars: Dictionary = bm.get("_by_character")
	mine_chars[7] = true
	assert_false((other.get("_by_character") as Dictionary).has(7), "另一实例的 _by_character 不受影响")

	var mine_cards: Dictionary = bm.get("_card_to_character")
	mine_cards[7] = 8
	assert_false((other.get("_card_to_character") as Dictionary).has(7),
		"另一实例的 _card_to_character 不受影响")

	var cb: Callable = func() -> void: pass
	bm.set("stat_bonus_cb", cb)
	assert_false(other.get("stat_bonus_cb").is_valid(), "另一实例的存根回调不受影响")

	mine.erase(4242)
	other.free()


# ============================================================================
# 5. 面仍然可调用：bind → 查询 → 序列化 一趟真行为
# ============================================================================

func test_face_still_callable_end_to_end() -> void:
	bm.call("cache_slot_limits", GameStateManager.RealmLevel.QI_REFINING)
	var bound: Dictionary = bm.call("bind_card", 100, &"tech_sword_01", 200, GONGFA)
	assert_true(bound["success"], "bind_card 仍返回 success")
	assert_eq(bound["reason"], "bound", "reason 仍为 bound")

	assert_eq((bm.call("get_binding_ids_by_character", 200) as Array).size(), 1, "按角色查询仍可用")
	assert_eq(bm.call("get_character_by_card", 100), 200, "反向查询仍可用")
	assert_eq((bm.call("get_bindings_by_character", 200) as Array).size(), 1, "记录查询仍可用")
	assert_not_null(bm.call("get_binding", int(bound["binding_id"])), "单条查询仍可用")

	var stacked: Dictionary = bm.call("stack_card", 101, &"tech_sword_01", 200, 3)
	assert_true(stacked["stacked"], "stack_card 仍可用")
	var plan: Dictionary = bm.call("can_bind", 200, GONGFA, &"tech_sword_01", 3)
	assert_eq(plan["reason"], "can_stack", "can_bind 仍可用")

	var snapshot: Dictionary = bm.call("serialize_all")
	assert_eq((snapshot["bindings"] as Array).size(), 1, "serialize_all 仍可用")

	bm.call("remove_all_bindings", 200)
	assert_eq((bm.call("get_binding_ids_by_character", 200) as Array).size(), 0, "remove_all_bindings 仍可用")
