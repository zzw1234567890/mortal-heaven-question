extends GutTest
## TribulationSystem 公开面锁定守卫——拆分重构前置护栏。
##
## [b]为什么需要这条守卫[/b]：[code]src/feature/tribulation_system.gd[/code]（429 行，
## Autoload #22）要按职责拆成继承链。拆分的唯一硬约束是「对外 API 逐位不变」——方法名、
## 形参个数、默认参数个数[b]与值[/b]、返回值类型、信号形参、实例字段、枚举取值、常量值，
## 一个都不许改。危险在于[b]编译器不会替我们发现断链[/b]：
##   · [code]project.godot[/code] 的 [code][autoload][/code] 把 [code]TribulationSystem[/code]
##     绑在 [code]*res://src/feature/tribulation_system.gd[/code] 这一串字符上；
##   · 三处 UI / 剧情件按同一路径 [code]preload[/code] 取类后以[b]静态形式[/b]读枚举
##     （[code]tribulation_launch.gd[/code] / [code]cultivation_actions.gd[/code] /
##     [code]cultivation_tribulation_gate.gd[/code] 的
##     [code]TribulationScript.TribulationState.PREPARING[/code]）；
##   · 两个惰性子模块（[code]tribulation_combat.gd[/code] /
##     [code]tribulation_settlement.gd[/code]）持有父引用，按[b]名字符串[/b]
##     [code]_parent.call("_set_state", …)[/code] / [code]_parent.get("_trib_type")[/code]
##     / [code]_parent.call("_get_card_system")[/code] 穿透继承链取成员；
##   · 集成测试直接 [code]TribulationSystem.set("_combat_override", …)[/code] /
##     [code].call(&"_on_battle_ended", …)[/code] / [code].get("_trib_type")[/code]。
##
## [b]本类的形态[/b]：[b]是 Autoload 但不带 [code]class_name[/code][/b]、[b]无 static
## 成员[/b]、[b]无 [code]@onready[/code] 与 %节点路径[/b]、[b]无子模块外置的类名引用[/b]；
## 全部对外面都是实例成员，且唯一的按名分派消费者是两个 [code]RefCounted[/code] 子模块。
## 继承链要承载的是「一个实例上解析 24 个方法、5 个信号、7 个字段、
## 2 个枚举 + 4 张常量表」。[b]不锁[/b]函数体、注释、成员落在哪个文件——
## 那些正是拆分要动的东西。
##
## 来源: .claude/docs/coding-standards.md §文件行数限制（300 行软上限）、
## ADR-0021 §关键接口 / §信号分类 / §状态与转换、GDD tribulation-system.md §1-7。

const TS_SCRIPT := preload("res://src/feature/tribulation_system.gd")
const REALM_MOCK := preload("res://tests/unit/tribulation_system/realm_mock.gd")
const COMBAT_SCRIPT := preload("res://src/feature/combat_system.gd")

## 入口路径——外部按这一串字符 preload、Autoload 按这一串字符注册，逐字不变。
const EXPECTED_PATH: String = "res://src/feature/tribulation_system.gd"

## [code]project.godot[/code] 的 [code][autoload][/code] 取值（前缀 [code]*[/code] = 单例）。
const EXPECTED_AUTOLOAD_VALUE: String = "*res://src/feature/tribulation_system.gd"

## 原生基类——链尾必须是 [Node] 的直接后继，否则 Autoload 实例化失败。
const EXPECTED_NATIVE_BASE: StringName = &"Node"

## 全局类名——本类[b]不声明[/b] [code]class_name[/code]（Feature Autoload 惯例），
## 拆分后也不得顺手加上（加了会让按路径 preload 与全局名两条路并存，徒增一处真理来源）。
const EXPECTED_GLOBAL_NAME: String = ""

## 方法快照——[code]{方法名: [形参个数, 默认参数值, 返回值类型]}[/code]，按反射实测登记。
## 返回值类型是 [enum Variant.Type] 的整数值（0 = void、1 = bool、2 = int、
## 24 = Object、27 = Dictionary）。
const EXPECTED_METHODS: Dictionary = {
	# 惰性子模块获取（拆分前就在，拆分后仍须在链上解析得到）
	"_get_settlement": [0, [], 24],
	"_get_combat_delegation": [0, [], 24],
	# 渡劫触发与状态机（UI 经 cultivation_actions 按名调）
	"check_tribulation_ready": [0, [], 1],
	"trigger_tribulation": [1, [0], 0],
	"cancel_tribulation": [0, [], 0],
	"_set_state": [1, [], 0],
	"_validate_state_transition": [2, [], 1],
	"get_tribulation_status": [0, [], 27],
	# 内部辅助（_emit_safe 走 ADR-0007 信号链深度追踪路由）
	"_emit_safe": [2, [], 0],
	"_get_gsm": [0, [], 24],
	# 渡劫战斗委托（_ready 订阅 CombatSystem.battle_ended）
	"_ready": [0, [], 0],
	"start_tribulation_combat": [0, [], 0],
	"_build_tribulation_config": [0, [], 27],
	"_on_battle_ended": [2, [], 0],
	# 渡劫丹管理（Story 5-12）
	"use_tribulation_pill": [1, [], 1],
	# 成功 / 失败结算（tribulation_settlement.gd 按名调）
	"_handle_tribulation_success": [0, [], 27],
	"_handle_tribulation_failure": [0, [], 0],
	# 雷伤纯函数与 Boss 配置查询（tribulation_combat.gd 按名调 get_tribulation_boss_config）
	"calculate_lightning_damage": [2, [], 2],
	"get_lightning_layers_per_turn": [1, [], 2],
	"get_tribulation_boss_config": [1, [], 27],
	# Autoload 引用获取（注入优先、否则回退单例）
	"_get_combat_system": [0, [], 24],
	"_get_realm_system": [0, [], 24],
	"_get_ai_system": [0, [], 24],
	"_get_card_system": [0, [], 24],
}

## 信号快照——[code]{信号名: [形参名...]}[/code]（UI 与存档链路按名 connect 这 5 条）。
const EXPECTED_SIGNALS: Dictionary = {
	"tribulation_triggered": ["realm_level"],
	"tribulation_preparation_started": [],
	"tribulation_succeeded": ["old_realm", "new_realm", "is_cross_realm"],
	"tribulation_failed": ["penalty", "realm_level"],
	"tribulation_protection_unlocked": [],
}

## 实例字段快照——[code]{字段名: 类型整数值}[/code]。拆分后仍是[b]实例[/b]字段
## （不得因搬文件误写成 static），类型也不得变。
const EXPECTED_FIELDS: Dictionary = {
	"_trib_type": 2, "_active_pills": 28,
	"_combat_override": 24, "_realm_override": 24, "_card_override": 24,
	"_settlement": 24, "_combat_delegation": 24,
}

## 枚举快照——[code]{枚举名: {成员名: 取值}}[/code]。枚举值进制位（GSM
## [code]player.tribulation_state[/code] 与存档都按整数落盘，逐位不得变）。
const EXPECTED_TRIBULATION_STATE: Dictionary = {
	"NOT_READY": 0, "READY": 1, "PREPARING": 2,
	"IN_COMBAT": 3, "SUCCESS": 4, "FAILED": 5,
}
const EXPECTED_TRIBULATION_TYPE: Dictionary = {
	"NORMAL": 0, "CROSS_REALM": 1,
}

## 标量常量快照——[code]{常量名: 值}[/code]。
const EXPECTED_SCALAR_CONSTANTS: Dictionary = {
	"MAX_TRIBULATION_PILLS": 2,
	"FAILURE_PENALTY_RATIO": 0.15,
	"CONSECUTIVE_FAILURE_THRESHOLD": 3,
}

## [constant _VALID_TRANSITIONS] 白名单——[method _set_state] 的唯一准入依据，
## 逐键逐序逐项不变（状态机的行为契约就长在这张表上）。
const EXPECTED_VALID_TRANSITIONS: Dictionary = {
	0: [2],
	1: [2],
	2: [3, 0, 1],
	3: [4, 5],
	4: [0],
	5: [0, 1],
}

## 链上常量表应恰好 6 张（2 枚举 + 3 标量 + _VALID_TRANSITIONS）——多了要显式更新本快照。
const EXPECTED_CONSTANT_COUNT: int = 6


# ═══════════════════════════════════════════════════════════════════════════════
# 链式反射工具——沿 [method Script.get_base_script] 合并整条继承链的面
# ═══════════════════════════════════════════════════════════════════════════════

## 走遍继承链收集脚本（链尾在前、首段在后——合并时后者覆盖前者，无重名故等价）。
func _chain() -> Array[Script]:
	var scripts: Array[Script] = []
	var cur: Script = TS_SCRIPT as Script
	while cur != null:
		scripts.append(cur)
		cur = cur.get_base_script()
	return scripts


## 合并全链方法表。
func _merged_methods() -> Dictionary:
	var merged: Dictionary = {}
	for sc: Script in _chain():
		for m: Dictionary in sc.get_script_method_list():
			merged[String(m["name"])] = m
	return merged


## 合并全链信号表——[code]{信号名: [形参名...]}[/code]。
func _merged_signals() -> Dictionary:
	var merged: Dictionary = {}
	for sc: Script in _chain():
		for s: Dictionary in sc.get_script_signal_list():
			var args: Array[String] = []
			for a: Dictionary in (s.get("args", []) as Array):
				args.append(String(a["name"]))
			merged[String(s["name"])] = args
	return merged


## 合并全链实例字段表——[code]{字段名: 类型整数值}[/code]。
func _merged_fields() -> Dictionary:
	var merged: Dictionary = {}
	for sc: Script in _chain():
		for p: Dictionary in sc.get_script_property_list():
			if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			merged[String(p["name"])] = int(p.get("type", 0))
	return merged


## 合并全链脚本常量表——[code]{常量名: 值}[/code]。
## [b]必须走链[/b]：链尾脚本的 [code]get_script_constant_map()[/code] 只返回[b]本段[/b]
## 自己的常量（同 [code]scene_manager[/code] / [code]progression_system[/code] 轮结论），
## 祖先段声明的不在其中。
func _merged_constants() -> Dictionary:
	var merged: Dictionary = {}
	for sc: Script in _chain():
		for key: Variant in sc.get_script_constant_map():
			merged[String(key)] = sc.get_script_constant_map()[key]
	return merged


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 方法面：24 个方法的形参个数 / 默认参数值 / 返回值类型逐位不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_method_face_locked() -> void:
	assert_eq(EXPECTED_METHODS.size(), 24, "方法快照应 24 个")
	var table: Dictionary = _merged_methods()
	var checked: int = 0
	for method_name: String in EXPECTED_METHODS:
		var expected: Array = EXPECTED_METHODS[method_name]
		assert_true(table.has(method_name),
				"方法 %s 应存在（拆分后不得丢）" % method_name)
		if not table.has(method_name):
			continue
		var entry: Dictionary = table[method_name]
		assert_eq((entry.get("args", []) as Array).size(), int(expected[0]),
				"方法 %s 形参个数应不变" % method_name)
		var want_defaults: Array = expected[1]
		var defaults: Array = entry.get("default_args", [])
		assert_eq(defaults.size(), want_defaults.size(),
				"方法 %s 默认参数个数应不变" % method_name)
		assert_eq(defaults, want_defaults,
				"方法 %s 默认参数值应逐位不变" % method_name)
		assert_eq(int((entry.get("return", {}) as Dictionary).get("type", 0)),
				int(expected[2]), "方法 %s 返回值类型应不变" % method_name)
		checked += 1
	assert_eq(checked, EXPECTED_METHODS.size(), "方法快照应全部比对到")


func test_no_untracked_methods() -> void:
	# 面内不得出现未登记的方法——新增/改名都要显式更新本快照。
	var untracked: Array[String] = []
	for method_name: String in _merged_methods():
		if not EXPECTED_METHODS.has(method_name) and not untracked.has(method_name):
			untracked.append(method_name)
	assert_eq(untracked.size(), 0, "不应出现未登记的方法：%s" % str(untracked))


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 信号面：5 个出口信号的名字与形参名逐位不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_signal_face_locked() -> void:
	assert_eq(EXPECTED_SIGNALS.size(), 5, "信号快照应 5 个")
	var table: Dictionary = _merged_signals()
	assert_eq(table.size(), EXPECTED_SIGNALS.size(),
			"信号表应恰好 %d 个：%s" % [EXPECTED_SIGNALS.size(), str(table.keys())])
	for signal_name: String in EXPECTED_SIGNALS:
		assert_true(table.has(signal_name), "信号 %s 应存在" % signal_name)
		if not table.has(signal_name):
			continue
		assert_eq(table[signal_name], EXPECTED_SIGNALS[signal_name],
				"信号 %s 形参名应逐位不变" % signal_name)


func test_signals_connectable_on_instance() -> void:
	# 信号必须能在[b]实例[/b]上按名 connect（UI 层走 node.connect(&"…", …)）。
	var ts: Node = TS_SCRIPT.new()
	for signal_name: String in EXPECTED_SIGNALS:
		assert_true(ts.has_signal(signal_name), "实例上应能解析信号 %s" % signal_name)
	ts.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 字段面：7 个实例字段在册、类型不变，且仍是实例字段
# ═══════════════════════════════════════════════════════════════════════════════

func test_instance_fields_locked() -> void:
	var found: Dictionary = _merged_fields()
	for field_name: String in EXPECTED_FIELDS:
		assert_true(found.has(field_name), "实例字段 %s 应存在" % field_name)
		if not found.has(field_name):
			continue
		assert_eq(int(found[field_name]), int(EXPECTED_FIELDS[field_name]),
				"实例字段 %s 类型应不变" % field_name)
	assert_eq(found.size(), EXPECTED_FIELDS.size(),
			"脚本实例字段应恰好 %d 个：%s" % [EXPECTED_FIELDS.size(), str(found.keys())])


func test_fields_not_staticized() -> void:
	# 两个实例互不影响——若拆分时把 var 误写成 static var，此处立刻变红。
	var a: Node = TS_SCRIPT.new()
	var b: Node = TS_SCRIPT.new()
	a.set("_trib_type", 1)
	a.set("_active_pills", [{"type": "x", "rarity_tier": 3}])
	a.set("_settlement", RefCounted.new())
	assert_eq(int(b.get("_trib_type")), 0, "另一实例的 _trib_type 应为默认 NORMAL")
	assert_eq((b.get("_active_pills") as Array).size(), 0,
			"另一实例的 _active_pills 应为默认空表")
	assert_null(b.get("_settlement"), "另一实例的 _settlement 应仍为 null")
	assert_not_null(a.get("_settlement"), "本实例的 _settlement 应已写入")
	a.free()
	b.free()


func test_default_state_locked() -> void:
	# 构造后的默认态（[method _ready] 前后都依赖）：类型 NORMAL / 丹表空 /
	# 四个注入与两个惰性子模块均未建。
	var ts: Node = TS_SCRIPT.new()
	assert_eq(int(ts.get("_trib_type")), 0, "默认 _trib_type 应为 NORMAL(0)")
	assert_eq((ts.get("_active_pills") as Array).size(), 0, "默认 _active_pills 应为空")
	for field_name: String in ["_combat_override", "_realm_override", "_card_override",
			"_settlement", "_combat_delegation"]:
		assert_null(ts.get(field_name), "默认 %s 应为 null" % field_name)
	ts.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 常量面与入口契约：枚举 / 标量 / 转换表 / resource_path / Autoload 注册值
# ═══════════════════════════════════════════════════════════════════════════════

func test_tribulation_state_enum_locked() -> void:
	var consts: Dictionary = _merged_constants()
	assert_true(consts.has("TribulationState"), "常量表应含 TribulationState")
	if not consts.has("TribulationState"):
		return
	assert_eq(consts["TribulationState"], EXPECTED_TRIBULATION_STATE,
			"TribulationState 枚举取值应逐项不变")


func test_tribulation_type_enum_locked() -> void:
	var consts: Dictionary = _merged_constants()
	assert_true(consts.has("TribulationType"), "常量表应含 TribulationType")
	if not consts.has("TribulationType"):
		return
	assert_eq(consts["TribulationType"], EXPECTED_TRIBULATION_TYPE,
			"TribulationType 枚举取值应逐项不变")


func test_scalar_constants_locked() -> void:
	var consts: Dictionary = _merged_constants()
	for const_name: String in EXPECTED_SCALAR_CONSTANTS:
		assert_true(consts.has(const_name), "常量 %s 应存在" % const_name)
		if not consts.has(const_name):
			continue
		assert_eq(consts[const_name], EXPECTED_SCALAR_CONSTANTS[const_name],
				"常量 %s 值应不变" % const_name)


func test_valid_transitions_table_locked() -> void:
	var consts: Dictionary = _merged_constants()
	assert_true(consts.has("_VALID_TRANSITIONS"), "常量表应含 _VALID_TRANSITIONS")
	if not consts.has("_VALID_TRANSITIONS"):
		return
	assert_eq(consts["_VALID_TRANSITIONS"], EXPECTED_VALID_TRANSITIONS,
			"合法转换白名单应逐键逐项不变")


func test_no_untracked_constants() -> void:
	# 链上常量应恰好 6 张——多了/少了都要显式更新本快照。
	var consts: Dictionary = _merged_constants()
	assert_eq(consts.size(), EXPECTED_CONSTANT_COUNT,
			"链上常量应恰好 %d 张：%s" % [EXPECTED_CONSTANT_COUNT, str(consts.keys())])


func test_entry_path_base_type_and_autoload_registration_unchanged() -> void:
	# 外部按这一串字符 preload、引擎按这一串字符注册 Autoload——两者都是契约。
	var script: Script = TS_SCRIPT as Script
	assert_eq(script.resource_path, EXPECTED_PATH, "入口路径应逐字不变")
	assert_eq(script.get_instance_base_type(), EXPECTED_NATIVE_BASE,
			"原生基类应仍是 Node（Autoload 实例化前提）")
	assert_eq(String(script.get_global_name()), EXPECTED_GLOBAL_NAME,
			"不应新增 class_name——保持按路径取类这一条路")
	var config := ConfigFile.new()
	assert_eq(config.load("res://project.godot"), OK, "project.godot 应能被加载")
	assert_eq(String(config.get_value("autoload", "TribulationSystem", "")),
			EXPECTED_AUTOLOAD_VALUE, "Autoload 注册值应逐字不变")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 面仍然可用：真实跑通触发 / 转换表守卫 / 丹规 / 雷伤 / 结算出口
# ═══════════════════════════════════════════════════════════════════════════════

## 本用例建出来的实例与替身——[method after_each] 统一释放，不留孤儿。
var _nodes: Array[Node] = []
var _succeeded: Array = []
var _failed: Array = []
var _protection: int = 0


func before_each() -> void:
	_reset_gsm()


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	_succeeded.clear()
	_failed.clear()
	_protection = 0
	_reset_gsm()


func _reset_gsm() -> void:
	var gsm: Node = _gsm()
	if gsm == null:
		return
	gsm.player.cultivation = 0
	gsm.player.max_cultivation = 1000
	gsm.player.cultivation_full = false
	gsm.player.realm = 1
	gsm.player.tribulation_state = 0
	gsm.player.consecutive_tribulation_failures = 0
	gsm.set("_signal_chain_depth", 0)
	gsm.get("_signal_router").set("_pending_changes", [])


func _gsm() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")


## 建一个挂了真实 RealmSystem 替身、已订好信号探针的实例。
func _make_ts() -> Node:
	var ts: Node = TS_SCRIPT.new()
	_nodes.append(ts)
	var mock: Node = Node.new()
	mock.set_script(REALM_MOCK)
	_nodes.append(mock)
	mock.set("_realm_up_calls", [])
	ts.set("_realm_override", mock)
	ts.tribulation_succeeded.connect(func(o: int, n: int, c: bool) -> void:
		_succeeded.append({"old": o, "new": n, "is_cross": c}))
	ts.tribulation_failed.connect(func(p: int, r: int) -> void:
		_failed.append({"penalty": p, "realm": r}))
	ts.tribulation_protection_unlocked.connect(func() -> void:
		_protection += 1)
	return ts


func test_trigger_and_cancel_path_still_wired() -> void:
	# 真实触发 → 准备阶段 → 取消 → 回到 NOT_READY（GSM 状态与私有类型都跟着走）。
	var ts: Node = _make_ts()
	var gsm: Node = _gsm()
	assert_false(ts.check_tribulation_ready(), "修为未满不应可渡劫")
	ts.trigger_tribulation()
	assert_eq(int(gsm.player.tribulation_state), 0, "未满时触发应被拒绝")

	gsm.player.cultivation = 1000
	assert_true(ts.check_tribulation_ready(), "修为满应可渡劫")
	ts.trigger_tribulation(1)
	assert_eq(int(gsm.player.tribulation_state), 2, "触发后应进 PREPARING")
	assert_eq(int(ts.get("_trib_type")), 1, "越阶类型应记在实例上")
	var status: Dictionary = ts.get_tribulation_status()
	assert_eq(int(status["state"]), 2, "查询接口应回报 PREPARING")
	assert_eq(int(status["trib_type"]), 1, "查询接口应回报越阶类型")

	ts.cancel_tribulation()
	assert_eq(int(gsm.player.tribulation_state), 0, "取消后应回 NOT_READY")
	assert_eq(int(ts.get("_trib_type")), 0, "取消应复位类型为 NORMAL")


func test_illegal_transition_guarded_by_whitelist() -> void:
	# 白名单是行为契约而非装饰：表中没有的转换写不进 GSM。
	var ts: Node = _make_ts()
	var gsm: Node = _gsm()
	ts.call("_set_state", 3)  # NOT_READY → IN_COMBAT 不在白名单
	assert_eq(int(gsm.player.tribulation_state), 0, "非法转换不应落盘")
	assert_true(ts.call("_validate_state_transition", 0, 2), "NOT_READY → PREPARING 合法")
	assert_false(ts.call("_validate_state_transition", 0, 3),
			"NOT_READY → IN_COMBAT 非法")
	assert_true(ts.call("_validate_state_transition", 3, 4), "IN_COMBAT → SUCCESS 合法")


func test_pill_rules_still_wired() -> void:
	# 三条规定：仅 PREPARING 可用 / 最多 2 枚 / 同种取高稀有度。
	var ts: Node = _make_ts()
	var gsm: Node = _gsm()
	assert_false(ts.use_tribulation_pill({"type": "a", "rarity_tier": 1}),
			"非 PREPARING 应拒绝")
	gsm.player.cultivation = 1000
	ts.trigger_tribulation()
	assert_true(ts.use_tribulation_pill({"type": "a", "rarity_tier": 1}),
			"PREPARING 应接受")
	assert_false(ts.use_tribulation_pill({"type": "a", "rarity_tier": 1}),
			"同种同稀有度应拒绝")
	assert_true(ts.use_tribulation_pill({"type": "a", "rarity_tier": 3}),
			"同种更高稀有度应替换")
	assert_eq(int((ts.get("_active_pills") as Array)[0]["rarity_tier"]), 3,
			"替换后应是高稀有度那份")
	assert_true(ts.use_tribulation_pill({"type": "b", "rarity_tier": 1}),
			"第二种应接受")
	assert_eq((ts.get("_active_pills") as Array).size(), 2, "应恰好 2 枚")
	assert_false(ts.use_tribulation_pill({"type": "c", "rarity_tier": 1}),
			"超过上限应拒绝")
	assert_false(ts.use_tribulation_pill({"rarity_tier": 1}), "缺 type 应拒绝")


func test_lightning_and_boss_queries_still_wired() -> void:
	# 两条纯函数出口 + Boss 配置查询（走惰性子模块，验证链上转发仍通）。
	var ts: Node = _make_ts()
	var dmg_1: int = ts.calculate_lightning_damage(1, 20)
	var dmg_3: int = ts.calculate_lightning_damage(3, 20)
	assert_gt(dmg_3, dmg_1, "层数越多雷伤应越高")
	assert_eq(dmg_1, ts.calculate_lightning_damage(1, 20), "纯函数应确定性")
	assert_eq(ts.calculate_lightning_damage(0, 20), 0, "回合 < 1 应归零")
	assert_eq(ts.get_lightning_layers_per_turn(4), 2, "元婴劫（realm=4）应 2 层/回合")
	assert_eq(ts.get_lightning_layers_per_turn(1), 1, "其余境界应 1 层/回合")
	var boss: Dictionary = ts.get_tribulation_boss_config(1)
	assert_false(boss.is_empty(), "一境界天劫 Boss 配置应存在")
	for key: String in ["realm", "hp", "atk", "enemy_roster"]:
		assert_true(boss.has(key), "Boss 配置应含键 %s：%s" % [key, str(boss.keys())])
	assert_eq(int(boss["realm"]), 1, "Boss 配置应回报查询的境界")
	assert_gt((boss["enemy_roster"] as Array).size(), 0, "一境界应至少有一档雷灵")


func test_success_settlement_path_still_wired() -> void:
	# 真实成功结算：GSM 状态推进 + RealmSystem 升级 + 信号 + 状态回转。
	var ts: Node = _make_ts()
	var gsm: Node = _gsm()
	gsm.player.realm = 1
	gsm.player.tribulation_state = 3  # IN_COMBAT
	ts.set("_trib_type", 1)
	ts.call("_handle_tribulation_success")
	assert_eq(_succeeded.size(), 1, "应发一次 tribulation_succeeded")
	assert_eq(int(_succeeded[0]["old"]), 1, "载荷应带旧境界")
	assert_eq(int(_succeeded[0]["new"]), 2, "载荷应带新境界")
	assert_true(bool(_succeeded[0]["is_cross"]), "载荷应标记越阶")
	assert_eq(int(gsm.player.realm), 2, "RealmSystem 替身应把境界 +1")
	assert_eq(int(gsm.player.tribulation_state), 0, "结算后应回 NOT_READY")
	assert_eq(int(ts.get("_trib_type")), 0, "结算后应复位类型")


func test_failure_settlement_path_still_wired() -> void:
	# 真实失败结算：扣修为 + 计失败 + 达阈值发庇护解锁。
	var ts: Node = _make_ts()
	var gsm: Node = _gsm()
	gsm.player.max_cultivation = 1000
	gsm.player.cultivation = 1000
	gsm.player.realm = 1
	gsm.player.consecutive_tribulation_failures = 0
	gsm.player.tribulation_state = 3  # IN_COMBAT
	ts.call("_handle_tribulation_failure")
	assert_eq(_failed.size(), 1, "应发一次 tribulation_failed")
	assert_eq(int(_failed[0]["penalty"]), 150, "罚金应为 max_cult × 0.15")
	assert_eq(int(gsm.player.consecutive_tribulation_failures), 1, "失败计数应 +1")
	assert_eq(int(gsm.player.tribulation_state), 0, "结算后应回 NOT_READY")

	# 连败到阈值 → 解锁天劫庇护
	gsm.player.consecutive_tribulation_failures = 2
	gsm.player.cultivation = 1000
	gsm.player.tribulation_state = 3
	ts.call("_handle_tribulation_failure")
	assert_eq(_protection, 1, "第 3 次失败应发一次庇护解锁")


func test_ready_subscribes_battle_ended_still_wired() -> void:
	# 真实 _ready()：把 battle_ended 挂到注入的 CombatSystem 替身上（幂等）。
	var ts: Node = TS_SCRIPT.new()
	_nodes.append(ts)
	var combat: Node = COMBAT_SCRIPT.new()
	_nodes.append(combat)
	ts.set("_combat_override", combat)
	ts._ready()
	assert_true(combat.battle_ended.is_connected(ts.get("_on_battle_ended")),
			"_ready 应把自己接到 battle_ended")
	ts._ready()
	assert_eq(combat.battle_ended.get_connections().size(), 1, "重复 _ready 不应重复接线")


func test_lazy_submodules_and_autoload_accessors_still_wired() -> void:
	# 两个惰性获取器建出同一实例；四个 Autoload 获取器在有注入时返回替身、
	# 无注入时回退按名查找（四个 Autoload 在测试态都真实注册着，故解析得到节点）。
	var ts: Node = _make_ts()
	var settlement: RefCounted = ts.call("_get_settlement")
	assert_not_null(settlement, "_get_settlement 应惰性建出子模块")
	assert_eq(ts.call("_get_settlement"), settlement, "应复用同一实例")
	var delegation: RefCounted = ts.call("_get_combat_delegation")
	assert_not_null(delegation, "_get_combat_delegation 应惰性建出子模块")
	assert_eq(ts.call("_get_combat_delegation"), delegation, "应复用同一实例")

	var combat_stub: Node = Node.new()
	_nodes.append(combat_stub)
	ts.set("_combat_override", combat_stub)
	assert_eq(ts.call("_get_combat_system"), combat_stub, "应优先返回注入的覆盖引用")
	assert_eq(ts.call("_get_realm_system"), ts.get("_realm_override"),
			"有注入时应返回 RealmSystem 替身")

	var plain: Node = TS_SCRIPT.new()
	_nodes.append(plain)
	assert_eq(plain.call("_get_realm_system"), _autoload("RealmSystem"),
			"无注入时应回退到按名查找 RealmSystem")
	assert_eq(plain.call("_get_ai_system"), _autoload("AISystem"),
			"无注入时应回退到按名查找 AISystem")
	assert_eq(plain.call("_get_card_system"), _autoload("CardSystem"),
			"无注入时应回退到按名查找 CardSystem")
	assert_eq(plain.call("_get_combat_system"), _autoload("CombatSystem"),
			"无注入时应回退到按名查找 CombatSystem")
	assert_eq(ts.call("_get_gsm"), _gsm(), "_get_gsm 应解析到真实 GSM")


## 按名取 Autoload——测试态下这些单例都已注册（断言「回退路径通」而非「返回 null」）。
func _autoload(p_name: String) -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null(
			"/root/%s" % p_name)
