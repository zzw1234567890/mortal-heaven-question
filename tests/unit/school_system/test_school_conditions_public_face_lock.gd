extends GutTest
## SchoolConditions 公开面锁定守卫——拆分重构前置护栏。
##
## [b]为什么需要这条守卫[/b]：[code]src/core/school_system/school_conditions.gd[/code]（408 行）
## 要按职责拆成继承链。拆分的唯一硬约束是「对外面逐位不变」——方法名、形参个数与[b]名字[/b]、
## 默认参数、返回值类型、信号、类级字段、类级常量、入口路径。危险在于[b]编译器不会替我们
## 发现断链[/b]：消费者只有一处、且是按字符串 [code]load()[/code] 的弱引用
## （[code]school_system.gd:_get_conditions[/code]）。
##
## [b]拆前四项判定（本轮反射实测，非推断）[/b]：
##   · [b]不是 Autoload[/b]——[code]project.godot[/code] 的 [code][autoload][/code] 段
##     只有 [code]SchoolSystem[/code] 一条（[code]*res://src/core/school_system/school_system.gd[/code]），
##     按 [code]school_conditions[/code] 扫描命中 0 条；
##   · [b]不带 [code]class_name[/code][/b]——[code]get_global_name()[/code] 返回空串；
##   · [b]无 static 成员[/b]——全文 0 处 [code]static[/code]，类级字段 0 个（见下条）；
##   · [b]按名分派存在但不越链[/b]——消费者 [code]school_system.gd[/code] 只用
##     [code]check_all_conditions[/code] / [code]evaluate_condition[/code] 两个公开名，
##     无 [code]call()[/code] / [code]get()[/code] / [code]set()[/code] 按名穿透，
##     非节点类故无 [code]@onready[/code] 与 [code]%[/code] 节点路径。
##
## [b]本类的形态[/b]：[b]纯函数 [RefCounted][/b]——[b]0 信号 / 0 类级字段 / 0 类级常量 /
## 0 默认参数[/b]，15 个方法全部是实例方法（[code]get_script_method_list()[/code] 实测
## [code]default_args[/code] 全为空数组，[code]get_script_property_list()[/code] 实测
## 无 [code]PROPERTY_USAGE_SCRIPT_VARIABLE[/code] 项）。两个 [code]Dictionary[/code] 常量
## （[code]TAG_TO_MAJOR[/code] / [code]TAG_NAMES[/code]）是[b]方法内局部 const[/b]，
## 不是类级常量——所以「默认参数引用的枚举/常量须落链首」这条解析期约束在本类[b]为空约束[/b]。
## 继承链要承载的是「一个实例上解析 15 个方法」，[b]不锁[/b]函数体、注释、成员落在哪个文件
## ——那些正是拆分要动的东西。
##
## 来源: .claude/docs/coding-standards.md §文件行数限制（300 行软上限）、
## ADR-0025 §关键接口 + GDD school-system.md §公式#1。

const SC_SCRIPT := preload("res://src/core/school_system/school_conditions.gd")

## 入口路径——消费者按这一串字符 [code]load().new()[/code]，逐字不变。
const EXPECTED_PATH: String = "res://src/core/school_system/school_conditions.gd"

## 原生基类——链尾必须是 [RefCounted] 的直接后继。
const EXPECTED_NATIVE_BASE: StringName = &"RefCounted"

## 全局类名——本类[b]不声明[/b] [code]class_name[/code]（惰性子模块惯例）。
const EXPECTED_GLOBAL_NAME: String = ""

## 消费者接缝——[code]school_system.gd[/code] 源码里必须仍含这一行字面量。
const CONSUMER_PATH: String = "res://src/core/school_system/school_system.gd"
const CONSUMER_SEAM_LITERAL: String = 'load("res://src/core/school_system/school_conditions.gd").new()'

## 方法快照——[code]{方法名: [形参个数, [形参名], [形参类型], 默认参数, 返回值类型]}[/code]，
## 按反射实测登记。类型都是 [enum Variant.Type] 的整数值
## （1 = bool、4 = String、21 = StringName、27 = Dictionary、28 = Array）。
## [b]为什么形参名也锁[/b]：调用点按位置传参，但子模块/测试可能按名 [code]call()[/code]；
## 名字是最廉价、最容易被顺手改掉的公开面。
const EXPECTED_METHODS: Dictionary = {
	# 公开入口（消费者 school_system.gd 只用这两个名字）
	"check_all_conditions": [2, ["school", "state"], [27, 27], [], 1],
	"evaluate_condition": [3, ["cond", "state", "_school_id"], [27, 27, 21], [], 27],
	# 加权条件评估器（7 个）
	"_eval_faction_count": [2, ["cond", "state"], [27, 27], [], 27],
	"_eval_faction_ratio": [2, ["cond", "state"], [27, 27], [], 27],
	"_eval_card_type_ratio": [2, ["cond", "state"], [27, 27], [], 27],
	"_eval_min_realm": [2, ["cond", "state"], [27, 27], [], 27],
	"_eval_min_alchemy_count": [2, ["cond", "state"], [27, 27], [], 27],
	"_eval_required_characters": [2, ["cond", "state"], [27, 27], [], 27],
	"_eval_avg_card_cost": [2, ["cond", "state"], [27, 27], [], 27],
	# 硬性条件评估器（3 个——weight 0 / skipped true）
	"_eval_excluded_faction": [2, ["cond", "state"], [27, 27], [], 27],
	"_eval_min_rarity": [2, ["cond", "state"], [27, 27], [], 27],
	"_eval_max_dark_gold_count": [2, ["cond", "state"], [27, 27], [], 27],
	# 辅助方法（3 个）
	"_char_matches_tags": [2, ["char", "tags"], [27, 28], [], 1],
	"_is_tag_under_alignment": [2, ["tag", "alignment"], [21, 21], [], 1],
	"_get_tag_display_name": [1, ["tag"], [21], [], 4],
	"_tags_display": [1, ["tags"], [28], [], 4],
}

## 方法标志位：METHOD_FLAG_STATIC = 32、METHOD_FLAG_NORMAL = 1（探针实测）。
const METHOD_FLAG_STATIC: int = 32

var _sc: Script = null


func before_all() -> void:
	_sc = SC_SCRIPT as Script


# ============================================================================
# 全链合并工具
# ============================================================================

## 沿 [method Script.get_base_script] 遍历全链，收集各段路径（尾 → 首）。
func _chain_paths() -> Array[String]:
	var out: Array[String] = []
	var cur: Script = _sc
	while cur != null:
		out.append(cur.resource_path)
		cur = cur.get_base_script()
	return out


## 全链合并的方法表——[code]{方法名: method_dict}[/code]（派生段优先）。
func _merged_methods() -> Dictionary:
	var out: Dictionary = {}
	var cur: Script = _sc
	while cur != null:
		for m in cur.get_script_method_list():
			if not out.has(m.name):
				out[m.name] = m
		cur = cur.get_base_script()
	return out


## 全链合并的字段表（只取脚本变量）。
func _merged_properties() -> Dictionary:
	var out: Dictionary = {}
	var cur: Script = _sc
	while cur != null:
		for p in cur.get_script_property_list():
			if p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
				out[p.name] = p
		cur = cur.get_base_script()
	return out


## 全链合并的常量表（[method Script.get_script_constant_map] 只返回本段）。
func _merged_constants() -> Dictionary:
	var out: Dictionary = {}
	var cur: Script = _sc
	while cur != null:
		for k in cur.get_script_constant_map():
			out[k] = cur.get_script_constant_map()[k]
		cur = cur.get_base_script()
	return out


## 全链合并的信号名列表。
func _merged_signals() -> Array[String]:
	var out: Array[String] = []
	var cur: Script = _sc
	while cur != null:
		for s in cur.get_script_signal_list():
			if not out.has(s.name):
				out.append(s.name)
		cur = cur.get_base_script()
	return out


func _read_source(path: String) -> String:
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()


# ============================================================================
# 入口与链形态
# ============================================================================

func test_entry_path_native_base_and_global_name_unchanged() -> void:
	assert_not_null(_sc, "school_conditions.gd 必须可 preload")
	assert_eq(_sc.resource_path, EXPECTED_PATH, "入口路径是消费者的接缝字面量，不得变")
	assert_eq(_sc.get_instance_base_type(), EXPECTED_NATIVE_BASE,
		"链尾必须仍是 RefCounted 的直接后继")
	assert_eq(_sc.get_global_name(), EXPECTED_GLOBAL_NAME,
		"本类不声明 class_name")


func test_all_chain_segments_live_in_school_system_dir() -> void:
	var paths: Array[String] = _chain_paths()
	assert_gt(paths.size(), 0, "链至少一段")
	for p in paths:
		assert_true(p.begins_with("res://src/core/school_system/school_conditions"),
			"每段都必须落在同目录且以 school_conditions 开头，实测: %s" % p)
		assert_true(FileAccess.file_exists(p), "段文件必须存在: %s" % p)


func test_consumer_seam_literal_unchanged() -> void:
	var src: String = _read_source(CONSUMER_PATH)
	assert_ne(src, "", "必须能读到消费者源码")
	assert_true(src.contains(CONSUMER_SEAM_LITERAL),
		"school_system.gd 仍须按这一行字面量装配子模块: 实测缺失 [%s]" % CONSUMER_SEAM_LITERAL)


# ============================================================================
# 声明面
# ============================================================================

func test_no_signals_in_whole_chain() -> void:
	assert_eq(_merged_signals(), [] as Array[String],
		"本类 0 信号——拆分不得凭空多出信号")


func test_no_class_level_fields_in_whole_chain() -> void:
	assert_eq(_merged_properties().keys(), [],
		"本类 0 类级字段（实例字段与 static var 都不得有）")


func test_no_class_level_constants_in_whole_chain() -> void:
	assert_eq(_merged_constants().keys(), [],
		"两个 Dictionary 常量是方法内局部 const，不得被提升为类级常量/枚举")


# ============================================================================
# 方法面
# ============================================================================

func test_method_surface_exactly_matches_snapshot() -> void:
	var actual: Dictionary = _merged_methods()
	var actual_names: Array = actual.keys()
	actual_names.sort()
	var expected_names: Array = EXPECTED_METHODS.keys()
	expected_names.sort()
	assert_eq(actual_names, expected_names, "方法名集合必须逐字一致（多一个少一个都算断链）")

	for name in EXPECTED_METHODS:
		var exp: Array = EXPECTED_METHODS[name]
		var m: Dictionary = actual[name]
		var arg_names: Array = []
		var arg_types: Array = []
		for a in m.args:
			arg_names.append(a.name)
			arg_types.append(a.type)
		assert_eq(m.args.size(), exp[0], "%s 形参个数" % name)
		assert_eq(arg_names, exp[1], "%s 形参名（按名分派的调用点靠它）" % name)
		assert_eq(arg_types, exp[2], "%s 形参类型" % name)
		assert_eq(m.default_args, exp[3], "%s 默认参数（本类应全为空）" % name)
		assert_eq(m["return"].type, exp[4], "%s 返回值类型" % name)


func test_all_methods_remain_instance_methods() -> void:
	var actual: Dictionary = _merged_methods()
	for name in actual:
		var flags: int = actual[name].flags
		assert_eq(flags & METHOD_FLAG_STATIC, 0,
			"%s 必须是实例方法——static 化会让按实例的分派与测试探针失效" % name)


func test_no_static_declaration_in_any_segment_source() -> void:
	# 反射看不见 static var，故补一层源码扫描：本类不允许出现任何 static 类级声明。
	for p in _chain_paths():
		var text: String = _read_source(p)
		assert_ne(text, "", "必须能读到段源码: %s" % p)
		var lines: PackedStringArray = text.split("\n")
		for i in lines.size():
			var stripped: String = lines[i].strip_edges()
			assert_false(stripped.begins_with("static "),
				"%s:%d 出现 static 类级声明: %s" % [p, i + 1, stripped])


# ============================================================================
# 功能性烟测——形状锁不住「拆完还能算」
# ============================================================================

## 合成一个只含 faction_count 条件的流派，走 [code]load().new()[/code] 的真实消费路径。
func _make_instance() -> RefCounted:
	var inst: RefCounted = (SC_SCRIPT as Script).new() as RefCounted
	return inst


func test_check_all_conditions_behavior_unchanged() -> void:
	var inst: RefCounted = _make_instance()
	var school: Dictionary = {
		id = &"synthetic",
		detection = { conditions = [{ type = "faction_count", tags = [&"zhengdao"], min = 1 }] },
	}
	var hit: Dictionary = { field_characters = [{ faction_tags = [&"qixuanmen"] }], deck_cards = [] }
	var miss: Dictionary = { field_characters = [], deck_cards = [] }
	assert_true(inst.call("check_all_conditions", school, hit), "满足条件须为 true")
	assert_false(inst.call("check_all_conditions", school, miss), "不满足条件须为 false")
	assert_false(inst.call("check_all_conditions", { detection = {} }, hit),
		"无条件流派须为 false（conditions 为空短路）")
	assert_false(inst.call("check_all_conditions", { detection = { conditions = [] } }, hit),
		"空条件列表须为 false")
	# RefCounted 由引用计数回收——不得 free()（会报 Attempted to free a RefCounted object）。


func test_evaluate_condition_fallback_and_weighting_unchanged() -> void:
	var inst: RefCounted = _make_instance()
	var unknown: Dictionary = inst.call("evaluate_condition", { type = "no_such_type" }, {}, &"x")
	assert_false(unknown.get("satisfied", true), "未知条件类型须 satisfied=false")
	assert_true(String(unknown.get("missing_text", "")).contains("未知条件类型"),
		"未知条件类型须带中文原因，实测: %s" % str(unknown.get("missing_text")))
	assert_false(unknown.get("skipped", true), "未知条件类型不得被当作硬性条件跳过")

	var weighted: Dictionary = inst.call("evaluate_condition",
		{ type = "min_realm", value = 3 }, { player_realm = 1 }, &"x")
	assert_eq(weighted.get("weight", 0.0), 10.0, "境界条件权重 10（GDD §公式#1）")
	assert_eq(weighted.get("score", -1.0), 0.0, "不满足时得分为 0")
	assert_false(weighted.get("skipped", true), "加权条件 skipped 必须为 false")

	var hard: Dictionary = inst.call("evaluate_condition",
		{ type = "max_dark_gold_count", value = 1 }, { deck_cards = [] }, &"x")
	assert_eq(hard.get("weight", -1.0), 0.0, "硬性条件权重 0")
	assert_true(hard.get("skipped", false), "硬性条件 skipped 必须为 true")
