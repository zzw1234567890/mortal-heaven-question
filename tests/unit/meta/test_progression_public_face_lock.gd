extends GutTest
## ProgressionSystem 公开面锁定守卫——拆分重构前置护栏。
##
## [b]为什么需要这条守卫[/b]：[code]src/meta/progression_system.gd[/code]（456 行，Autoload #12）
## 要按职责拆成继承链。拆分的唯一硬约束是「对外 API 逐位不变」——方法名、形参个数、
## 默认参数个数[b]与值[/b]、返回值类型、信号、实例字段、常量，一个都不许改。危险在于
## [b]编译器不会替我们发现断链[/b]：
##   · [code]project.godot[/code] 的 [code][autoload][/code] 把 [code]ProgressionSystem[/code]
##     绑在 [code]*res://src/meta/progression_system.gd[/code] 这一串字符上，全工程 31 处
##     调用点（achievement_system / reincarnation_talent_system / identity_selection_system
##     + 存档链路）以 Autoload 全局名直呼——[b]按名动态分派[/b]；
##   · 5 个单元测试文件按路径 [code]preload[/code] 取类后 [code]PS.new()[/code] 实例化，
##     并直接读写 [code]_batch_depth[/code] / [code]_initialized_and_loaded[/code] /
##     [code]_save_load_override[/code] 等实例字段；
##   · [code]tests/integration/identity_selection_system/test_identity_start_flow.gd[/code]
##     用 [code]ProgressionSystem.get("_talent_defs")[/code] /
##     [code].set("_talent_defs", …)[/code] [b]按字符串[/b]取字段；
##   · [code]progression_serializer.gd[/code] 子模块同样按名取
##     [code]_parent.get("_save_load_override")[/code] / [code]_parent.call("_get_save_load_system")[/code]
##     并 [code]_parent.set("_achievements", …)[/code] 写 6 个域存储。
##
## [b]与前几轮（[code]combat_system[/code] / [code]gsm_atomic_writes[/code] /
## [code]settlement_panel[/code] / [code]scene_manager[/code]）的形态差异[/b]：本类
## [b]是 Autoload 但不带 [code]class_name[/code][/b]、[b]无 static 成员[/b]、[b]无
## [code]@onready[/code] 与 [code]%节点路径[/code][/b]；全部对外面都是实例成员，
## 且唯一的按名分派消费者（[code]progression_serializer.gd[/code]）走
## [code]get/set/call[/code] 而非静态解析。继承链要承载的是「一个实例上解析 38 个方法、
## 6 个信号、14 个字段、1 张常量表」。[b]不锁[/b]函数体、注释、成员落在哪个文件——
## 那些正是拆分要动的东西。
##
## 来源: .claude/docs/coding-standards.md §文件行数限制（300 行软上限）、
## ADR-0012 §决策（域存储声明 + 关键接口 + 初始化策略）。

const PS := preload("res://src/meta/progression_system.gd")
const MOCK_SCRIPT := preload("res://tests/unit/progression_system/save_load_mock.gd")

## 入口路径——外部按这一串字符 preload、Autoload 按这一串字符注册，逐字不变。
const EXPECTED_PATH: String = "res://src/meta/progression_system.gd"

## [code]project.godot[/code] 的 [code][autoload][/code] 取值（前缀 [code]*[/code] = 单例）。
const EXPECTED_AUTOLOAD_VALUE: String = "*res://src/meta/progression_system.gd"

## 原生基类——链尾必须是 [Node] 的直接后继，否则 Autoload 实例化失败。
const EXPECTED_NATIVE_BASE: StringName = &"Node"

## 全局类名——本类[b]不声明[/b] [code]class_name[/code]（Foundation/Meta Autoload 惯例），
## 拆分后也不得顺手加上（加了会让按路径 preload 与全局名两条路并存，徒增一处真理来源）。
const EXPECTED_GLOBAL_NAME: String = ""

## 方法快照——[code]{方法名: [形参个数, [默认参数值...] 或 null, 返回值类型]}[/code]，
## 按反射实测登记。返回值类型是 [enum Variant.Type] 的整数值（0 = NIL/void 或 Variant、
## 1 = bool、2 = int、24 = Object、27 = Dictionary、28 = Array）。
const EXPECTED_METHODS: Dictionary = {
	# 生命周期与序列化（SaveLoadSystem 被动持久化链路按名调用）
	"_ready": [0, [], 0],
	"_get_serializer": [0, [], 24],
	"_init_empty_stores": [0, [], 0],
	"_load_progression_data": [0, [], 27],
	"initialize": [1, [], 0],
	"serialize": [0, [], 27],
	"deserialize": [1, [], 1],
	"has_unsaved_changes": [0, [], 1],
	"mark_saved": [0, [], 0],
	# achievements 领域（AchievementSystem 静态初始化时逐个注册 62 条定义）
	"register_achievement": [2, [], 0],
	"unlock_achievement": [1, [], 27],
	"get_achievement": [1, [], 27],
	"get_achievements": [1, [""], 28],
	"update_achievement_progress": [2, [], 0],
	# talents 领域（ReincarnationTalentSystem 消费）
	"register_talent": [2, [], 0],
	"get_talent_points": [0, [], 2],
	"add_talent_points": [1, [], 0],
	"purchase_talent": [1, [], 27],
	"grant_talent": [1, [], 27],
	"get_talent_tree_state": [0, [], 27],
	"set_equipped_talents": [1, [], 27],
	"get_active_slot_count": [0, [], 2],
	# 批量更新（结算链路：一次事务只发一次 progression_updated）
	"batch_update_begin": [0, [], 0],
	"batch_update_end": [0, [], 0],
	# endings / gallery 领域（GalleryUI 消费）
	"unlock_ending": [4, [], 27],
	"get_unlocked_endings": [0, [], 28],
	"has_ending": [1, [], 1],
	"get_ending_detail": [1, [], 27],
	"mark_card_discovered": [1, [], 0],
	"is_card_discovered": [1, [], 1],
	"get_card_gallery_stats": [0, [], 27],
	# stats / meta 领域（统计面板与跨局元信息）
	"increment_stat": [2, [1], 0],
	"set_stat": [2, [], 0],
	"get_stat": [1, [], 2],
	"get_meta_value": [1, [], 0],
	"set_meta_value": [2, [], 0],
	# 内部辅助（progression_serializer.gd 按名字符串调 _get_save_load_system）
	"_mark_dirty_and_emit": [1, [], 0],
	"_get_save_load_system": [0, [], 24],
}

## 信号快照——[code]{信号名: [形参名...]}[/code]（UI 与存档链路按名 connect 这 6 条）。
const EXPECTED_SIGNALS: Dictionary = {
	"progression_initialized": [],
	"progression_updated": ["domain"],
	"achievement_unlocked": ["ach_id"],
	"talent_purchased": ["talent_id", "points_remaining"],
	"ending_unlocked_signal": ["ending_id", "total"],
	"card_discovered": ["card_id", "total"],
}

## 实例字段快照——[code]{字段名: 类型整数值}[/code]。拆分后仍是[b]实例[/b]字段
## （不得因搬文件误写成 static），类型也不得变。
const EXPECTED_FIELDS: Dictionary = {
	"_achievements": 27, "_talents": 27, "_card_gallery": 27,
	"_endings": 27, "_stats": 27, "_meta": 27,
	"_dirty": 1, "_batch_depth": 2, "_batch_pending_domains": 27,
	"_initialized_and_loaded": 1,
	"_serializer": 24, "_achievement_defs": 27, "_talent_defs": 27,
	"_save_load_override": 24,
}

## [constant _META_KEYS] 白名单——[method set_meta_value] 的唯一准入依据，逐项值不变。
## 链上唯一的常量（本类无枚举、无其他 const）。
const EXPECTED_META_KEYS: Array = [
	"highest_realm_ever",
	"total_reincarnations",
	"total_playtime_seconds",
	"total_completions",
]


# ═══════════════════════════════════════════════════════════════════════════════
# 链式反射工具——沿 [method Script.get_base_script] 合并整条继承链的面
# ═══════════════════════════════════════════════════════════════════════════════

## 走遍继承链收集脚本（链尾在前、首段在后——合并时后者覆盖前者，无重名故等价）。
func _chain() -> Array[Script]:
	var scripts: Array[Script] = []
	var cur: Script = PS as Script
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


## 合并全链脚本变量表——[code]{字段名: 类型整数值}[/code]（只收 SCRIPT_VARIABLE）。
func _merged_fields() -> Dictionary:
	var merged: Dictionary = {}
	for sc: Script in _chain():
		for p: Dictionary in sc.get_script_property_list():
			if int(p["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE == 0:
				continue
			merged[String(p["name"])] = int(p.get("type", 0))
	return merged


## 合并全链常量表——[code]{常量名: 值}[/code]。
## [b]必须走链[/b]：实测链尾脚本的 [code]get_script_constant_map()[/code] 只返回[b]本段[/b]
## 自己的常量（同 [code]scene_manager[/code] 轮结论），祖先段声明的不在其中。
func _merged_constants() -> Dictionary:
	var merged: Dictionary = {}
	for sc: Script in _chain():
		for key: Variant in sc.get_script_constant_map():
			merged[String(key)] = sc.get_script_constant_map()[key]
	return merged


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 方法面：38 个方法的形参个数 / 默认参数值 / 返回值类型逐位不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_method_face_locked() -> void:
	assert_eq(EXPECTED_METHODS.size(), 38, "方法快照应 38 个")
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
		if expected[1] != null:
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
# 2. 信号面：6 个出口信号的名字与形参名逐位不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_signal_face_locked() -> void:
	assert_eq(EXPECTED_SIGNALS.size(), 6, "信号快照应 6 个")
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
	# 信号必须能在[b]实例[/b]上按名 connect（GalleryUI / UI 层走 node.connect(&"…", …)）。
	var ps: Node = PS.new()
	for signal_name: String in EXPECTED_SIGNALS:
		assert_true(ps.has_signal(signal_name), "实例上应能解析信号 %s" % signal_name)
	ps.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 字段面：14 个实例字段在册、类型不变，且仍是实例字段
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
	var a: Node = PS.new()
	var b: Node = PS.new()
	a.set("_dirty", true)
	a.set("_batch_depth", 7)
	a.set("_achievement_defs", {"x": {}})
	assert_false(bool(b.get("_dirty")), "另一实例的 _dirty 不受影响")
	assert_eq(int(b.get("_batch_depth")), 0, "另一实例的 _batch_depth 应为默认 0")
	assert_eq((b.get("_achievement_defs") as Dictionary).size(), 0,
			"另一实例的 _achievement_defs 应为默认空表")
	a.free()
	b.free()


func test_default_state_locked() -> void:
	# 构造后的默认态（[method _ready] 前后都依赖）：6 域空表 / 脏标志 false /
	# 批量深度 0 / 未初始化 / 序列化子模块惰性未建 / 无注入。
	var ps: Node = PS.new()
	for field_name: String in ["_achievements", "_talents", "_card_gallery",
			"_endings", "_stats", "_meta", "_achievement_defs", "_talent_defs",
			"_batch_pending_domains"]:
		assert_eq((ps.get(field_name) as Dictionary).size(), 0,
				"默认 %s 应为空表" % field_name)
	assert_false(ps.has_unsaved_changes(), "默认 _dirty 应为 false")
	assert_eq(int(ps.get("_batch_depth")), 0, "默认 _batch_depth 应为 0")
	assert_false(bool(ps.get("_initialized_and_loaded")), "默认应未初始化")
	assert_null(ps.get("_serializer"), "默认序列化子模块应惰性未建")
	assert_null(ps.get("_save_load_override"), "默认不应有 SaveLoad 注入")
	ps.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 常量面与入口契约：_META_KEYS、resource_path、Autoload 注册值、原生基类
# ═══════════════════════════════════════════════════════════════════════════════

func test_meta_keys_constant_locked() -> void:
	var consts: Dictionary = _merged_constants()
	assert_true(consts.has("_META_KEYS"), "常量表应含 _META_KEYS")
	if not consts.has("_META_KEYS"):
		return
	assert_eq(consts["_META_KEYS"], EXPECTED_META_KEYS,
			"_META_KEYS 白名单应逐项逐序不变")


func test_no_untracked_constants() -> void:
	# 链上常量只有 _META_KEYS 一张（本类无枚举）——多了要显式更新本快照。
	var consts: Dictionary = _merged_constants()
	assert_eq(consts.size(), 1, "链上常量应恰好 1 张：%s" % str(consts.keys()))


func test_meta_keys_whitelist_enforced_at_runtime() -> void:
	# 白名单是行为契约而非装饰：表外的 key 写不进去。
	var ps: Node = _make_ps()
	ps.set_meta_value("highest_realm_ever", "金丹")
	assert_eq(str(ps.get_meta_value("highest_realm_ever")), "金丹", "白名单内应写成功")
	ps.set_meta_value("not_a_real_key", 1)
	assert_null(ps.get_meta_value("not_a_real_key"), "白名单外应被拒绝")
	ps.free()


func test_entry_path_base_type_and_autoload_registration_unchanged() -> void:
	# 外部按这一串字符 preload、引擎按这一串字符注册 Autoload——两者都是契约。
	var script: Script = PS as Script
	assert_eq(script.resource_path, EXPECTED_PATH, "入口路径应逐字不变")
	assert_eq(script.get_instance_base_type(), EXPECTED_NATIVE_BASE,
			"原生基类应仍是 Node（Autoload 实例化前提）")
	assert_eq(String(script.get_global_name()), EXPECTED_GLOBAL_NAME,
			"不应新增 class_name——保持按路径取类这一条路")
	var config := ConfigFile.new()
	assert_eq(config.load("res://project.godot"), OK, "project.godot 应能被加载")
	assert_eq(String(config.get_value("autoload", "ProgressionSystem", "")),
			EXPECTED_AUTOLOAD_VALUE, "Autoload 注册值应逐字不变")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 面仍然可用：真实跑通六条域读写路径与批量去重
# ═══════════════════════════════════════════════════════════════════════════════

## 本用例建出来的实例与替身——[method after_each] 统一释放，不留孤儿。
var _nodes: Array[Node] = []


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()


## 建一个注入了 SaveLoad 替身、已初始化的实例（形态对齐既有 5 个单测文件的
## [code]PS.new()[/code] + [code]_save_load_override[/code] + [code]initialize({})[/code]）。
func _make_ps() -> Node:
	var mock: Node = Node.new()
	mock.set_script(MOCK_SCRIPT)
	_nodes.append(mock)
	var ps: Node = PS.new()
	_nodes.append(ps)
	ps.set("_save_load_override", mock)
	ps.initialize({})
	return ps


func test_achievements_path_still_wired() -> void:
	var ps: Node = _make_ps()
	var hits: Array = []
	ps.connect(&"achievement_unlocked",
			func(ach_id: String) -> void: hits.append(ach_id))
	ps.register_achievement("ach_1", {"category": "combat", "target": 3})
	assert_false(bool(ps.get_achievement("ach_1")["unlocked"]), "仅注册不应解锁")
	ps.update_achievement_progress("ach_1", 1)
	assert_eq(int(ps.get_achievement("ach_1")["progress"]["current"]), 1, "进度应累计")
	assert_eq(hits.size(), 0, "未达标不应发解锁信号")
	ps.update_achievement_progress("ach_1", 2)
	assert_true(bool(ps.get_achievement("ach_1")["unlocked"]), "达标应自动解锁")
	assert_eq(hits, ["ach_1"], "解锁应发一次信号")
	assert_true(ps.has_unsaved_changes(), "写入后脏标志应置位")
	assert_eq(ps.get_achievements("combat").size(), 1, "按类别过滤应命中")
	assert_eq(ps.get_achievements("narrative").size(), 0, "不匹配类别应为空")


func test_talents_path_still_wired() -> void:
	var ps: Node = _make_ps()
	ps.register_talent("t_a", {"cost": 1})
	ps.register_talent("t_b", {"cost": 2, "prerequisite": "t_a"})
	assert_eq(ps.get_talent_points(), 0, "初始轮回点应为 0")
	assert_eq(str(ps.purchase_talent("t_a")["reason"]), "insufficient_points",
			"点数不足应拒绝")
	ps.add_talent_points(3)
	assert_eq(ps.get_talent_points(), 3, "加点后应可读")
	assert_eq(str(ps.purchase_talent("t_b")["reason"]), "prerequisite_locked",
			"前置未解锁应拒绝")
	assert_true(bool(ps.purchase_talent("t_a")["success"]), "购买应成功")
	assert_eq(ps.get_talent_points(), 2, "应扣点")
	assert_eq(ps.get_active_slot_count(), 5, "槽位基数应为 5")
	var state: Dictionary = ps.get_talent_tree_state()
	assert_eq((state["unlocked"] as Array).size(), 1, "树状态应含已解锁项")


func test_batch_update_dedupes_signal() -> void:
	var ps: Node = _make_ps()
	var domains: Array = []
	ps.connect(&"progression_updated",
			func(domain: String) -> void: domains.append(domain))
	ps.batch_update_begin()
	ps.increment_stat("kills", 1)
	ps.mark_card_discovered("card_1")
	ps.increment_stat("kills", 1)
	assert_eq(domains.size(), 0, "批量期间不应发信号")
	ps.batch_update_end()
	assert_eq(domains.size(), 2, "批量结束应按域去重各发一次：%s" % str(domains))
	assert_true(domains.has("stats") and domains.has("gallery"), "应含 stats 与 gallery")
	assert_eq(ps.get_stat("kills"), 2, "统计应累计")


func test_endings_gallery_stats_paths_still_wired() -> void:
	var ps: Node = _make_ps()
	assert_true(bool(ps.unlock_ending("e_1", {"ch": 1}, "identity_a", "金丹")["success"]),
			"解锁结局应成功")
	assert_false(ps.has_ending("e_2"), "未解锁结局应报 false")
	assert_eq(ps.get_unlocked_endings(), ["e_1"], "已解锁列表应命中")
	assert_eq(int(ps.get_meta_value("total_completions")), 1, "通关数应递增")
	assert_eq(str(ps.get_ending_detail("e_1")["realm"]), "金丹", "结局详情应可读")

	ps.mark_card_discovered("card_1")
	ps.mark_card_discovered("card_1")
	assert_true(ps.is_card_discovered("card_1"), "重复标记应幂等")
	var gallery: Dictionary = ps.get_card_gallery_stats()
	assert_eq(int(gallery["total_discovered"]), 1, "图鉴计数应为 1")
	assert_eq(int(gallery["total_cards"]), 222, "图鉴总数应为 222")

	ps.set_stat("best", 5)
	ps.set_stat("best", 2)
	assert_eq(ps.get_stat("best"), 5, "set_stat 只升不降")


func test_serialize_roundtrip_and_subsystem_access_still_wired() -> void:
	# 序列化链路（SaveLoadSystem 被动持久化）+ 惰性获取器 + 按名取 SaveLoad。
	var ps: Node = _make_ps()
	ps.increment_stat("runs", 4)
	ps.mark_card_discovered("card_9")
	ps.unlock_ending("e_9", {}, "identity_b", "筑基")
	var data: Dictionary = ps.serialize()
	assert_eq(data.size(), 6, "序列化应含 6 个域：%s" % str(data.keys()))
	assert_eq(int((data["statistics"] as Dictionary)["runs"]), 4, "统计域应落盘")
	assert_false(data.has("_dirty"), "不应序列化内部标志")

	var restored: Node = PS.new()
	_nodes.append(restored)
	var mock: Node = Node.new()
	mock.set_script(MOCK_SCRIPT)
	_nodes.append(mock)
	restored.set("_save_load_override", mock)
	assert_true(restored.deserialize(data), "反序列化应成功")
	assert_eq(restored.get_stat("runs"), 4, "往返后统计应一致")
	assert_true(restored.has_ending("e_9"), "往返后结局应一致")
	assert_false(restored.has_unsaved_changes(), "initialize 后脏标志应复位")

	# 惰性获取器 + 按名取 SaveLoad（progression_serializer 的两条入口）
	var serializer: RefCounted = ps.call("_get_serializer")
	assert_not_null(serializer, "_get_serializer 应惰性建出子模块")
	assert_eq(ps.call("_get_serializer"), serializer, "应复用同一实例")
	assert_true(mock.has_method("load_progression"), "替身应提供 load_progression")
	assert_eq(ps.call("_get_save_load_system"), ps.get("_save_load_override"),
			"_get_save_load_system 应优先返回注入的替身")


func test_init_empty_stores_and_mark_saved_still_wired() -> void:
	var ps: Node = _make_ps()
	ps.increment_stat("runs", 1)
	assert_true(ps.has_unsaved_changes(), "写入后应为脏")
	ps.mark_saved()
	assert_false(ps.has_unsaved_changes(), "mark_saved 后应不脏")
	ps.call("_init_empty_stores")
	assert_eq(ps.get_stat("runs"), 0, "_init_empty_stores 应清空统计域")
	assert_eq(ps.get_talent_points(), 0, "天赋点应回到默认 0")
	assert_eq((ps.get("_talents") as Dictionary)["unlocked"], [], "解锁表应清空")


func test_ready_loads_from_save_load_and_emits_signal() -> void:
	# 真实 _ready()：从（替身）SaveLoad 拉开局数据 → 填充 6 域 → 发初始化信号。
	var mock: Node = Node.new()
	mock.set_script(MOCK_SCRIPT)
	_nodes.append(mock)
	mock.set("_progression_data", {
		"achievements": {"ach_x": {"id": "ach_x", "unlocked": true, "unlocked_at": "t"}},
		"statistics": {"runs": 7},
	})
	var ps: Node = PS.new()
	_nodes.append(ps)
	ps.set("_save_load_override", mock)
	var fired: Array = []
	ps.connect(&"progression_initialized", func() -> void: fired.append(true))
	# 手动调 _ready()（不入树——入树会再触发一次真实 _ready，读档计数翻倍）
	ps._ready()
	assert_eq(fired.size(), 1, "_ready 应发一次 progression_initialized")
	assert_eq(ps.get_stat("runs"), 7, "_ready 应把存档数据填进统计域")
	assert_true(bool(ps.get_achievement("ach_x")["unlocked"]), "成就域应载入")
	assert_true(bool(ps.get("_initialized_and_loaded")), "应置初始化标志")
	assert_eq(int(mock.get("load_call_count")), 1, "应恰好读一次存档")
