extends GutTest
## FormationSystem 公开面锁定守卫——拆分重构前置护栏。
##
## [b]为什么需要这条守卫[/b]：[code]src/feature/formation_system.gd[/code]（435 行，
## Autoload #23）要按职责拆成继承链。拆分的唯一硬约束是「对外 API 逐位不变」——方法名、
## 形参个数、默认参数个数[b]与值[/b]、返回值类型、信号形参、实例字段、枚举取值、常量值，
## 一个都不许改。危险在于[b]编译器不会替我们发现断链[/b]：
##   · [code]project.godot[/code] 的 [code][autoload][/code] 把 [code]FormationSystem[/code]
##     绑在 [code]*res://src/feature/formation_system.gd[/code] 这一串字符上；
##   · 四个既有测试文件按同一路径 [code]preload[/code] 取类后以[b]静态形式[/b]读枚举
##     （[code]FS_SCRIPT.SlotState.ACTIVE[/code] / [code]FS_SCRIPT.AuraScope.SAME_FACTION[/code]）；
##   · 三个惰性子模块（[code]formation_serializer.gd[/code] /
##     [code]formation_aura.gd[/code] / [code]formation_slot_ops.gd[/code]）持有父引用，
##     按[b]名字符串[/b] [code]_parent.call("_emit_safe", …)[/code] /
##     [code]_parent.get("_slots")[/code] / [code]_parent.set("_next_formation_id", …)[/code]
##     穿透继承链取 21 个去重成员；
##   · 测试直接 [code]fs.set("_affiliations", …)[/code] / [code]fs.call("_on_field_changed", …)[/code]。
##
## [b]本类的形态[/b]：[b]是 Autoload 但不带 [code]class_name[/code][/b]、[b]无 static
## 成员[/b]、[b]无 [code]@onready[/code] 与 %节点路径[/b]、[b]无 [code]_ready[/code][/b]
## （Autoload 本体不订阅信号，信号接线在战斗域做）；全部对外面都是实例成员，
## 按名分派的消费者是三个 [code]RefCounted[/code] 子模块。继承链要承载的是「一个实例上
## 解析 34 个方法、6 个信号、15 个字段、2 个枚举 + 1 个标量常量」。[b]不锁[/b]函数体、
## 注释、成员落在哪个文件——那些正是拆分要动的东西。
##
## 来源: .claude/docs/coding-standards.md §文件行数限制（300 行软上限）、
## ADR-0024 §关键接口 / §Cat 2b 信号 / §GSM 边界、GDD formation-system.md。

const FS_SCRIPT := preload("res://src/feature/formation_system.gd")

## 入口路径——外部按这一串字符 preload、Autoload 按这一串字符注册，逐字不变。
const EXPECTED_PATH: String = "res://src/feature/formation_system.gd"

## [code]project.godot[/code] 的 [code][autoload][/code] 取值（前缀 [code]*[/code] = 单例）。
const EXPECTED_AUTOLOAD_VALUE: String = "*res://src/feature/formation_system.gd"

## 原生基类——链尾必须是 [Node] 的直接后继，否则 Autoload 实例化失败。
const EXPECTED_NATIVE_BASE: StringName = &"Node"

## 全局类名——本类[b]不声明[/b] [code]class_name[/code]（Feature Autoload 惯例；
## 声明了会与全局名冲突，令 [code]FS_SCRIPT.new()[/code] 测试实例无法解析）。
const EXPECTED_GLOBAL_NAME: String = ""

## 三个惰性子模块的路径——[method _get_serializer] 等按这几个字符串 [code]load().new(self)[/code]，
## 它们同时是「组合式接缝」的契约，搬家不得顺手改路径。
const EXPECTED_SUBMODULE_PATHS: Dictionary = {
	"_get_serializer": "res://src/feature/formation/formation_serializer.gd",
	"_get_aura": "res://src/feature/formation/formation_aura.gd",
	"_get_slot_ops": "res://src/feature/formation/formation_slot_ops.gd",
}

## 方法快照——[code]{方法名: [形参个数, 默认参数类型表, 默认参数值表, 返回值类型]}[/code]，
## 按反射实测登记。返回值类型与默认参数类型都是 [enum Variant.Type] 的整数值
## （0 = NIL、1 = bool、2 = int、3 = float、24 = Object、27 = Dictionary、28 = Array）。
## [b]为什么类型与值分两栏[/b]：[code]requirement: Dictionary = {}[/code] 这类空容器默认值
## 在 [code]default_args[/code] 里报为 [code]NIL / null[/code]（探针实测），
## 只看值分不出「空 Dictionary」与「Variant = null」——故类型栏同时锁死。
const EXPECTED_METHODS: Dictionary = {
	# 初始化（_init 调 _reset_slots，_reset_slots 调 _make_empty_slot——同段内解析）
	"_init": [0, [], [], 0],
	"_reset_slots": [0, [], [], 0],
	"_make_empty_slot": [0, [], [], 27],
	"set_deploy_turn": [1, [], [], 0],
	# 惰性子模块获取（三个 RefCounted 子模块的接缝，拆分前就在）
	"_get_serializer": [0, [], [], 24],
	"_get_aura": [0, [], [], 24],
	"_get_slot_ops": [0, [], [], 24],
	# 部署 / 覆盖（默认参数含 AuraScope.AFFILIATED_CHARACTERS——解析期求值）
	"deploy_formation": [8, [2, 0, 2, 0, 2, 3], [-1, null, 1, null, 0, 0.0], 27],
	"overwrite_formation": [8, [0, 2, 0, 2, 3], [null, 1, null, 0, 0.0], 27],
	# 归属管理
	"set_character_affilation": [2, [], [], 1],
	"clear_character_affilation": [1, [], [], 0],
	# 查询 API（UI 与战斗域按名读）
	"get_formation_state": [1, [], [], 27],
	"get_active_formations": [0, [], [], 28],
	"get_slot_states": [0, [], [], 28],
	"get_character_affilation": [1, [], [], 2],
	"is_formation_active": [1, [], [], 1],
	"can_deploy": [0, [], [], 27],
	# 内部方法（子模块经 _parent.call 回取这些）
	"_check_condition": [1, [], [], 1],
	"_clear_affiliations_by_formation": [1, [], [], 0],
	"_get_slot_by_formation": [1, [], [], 27],
	"_get_slot_index_by_formation": [1, [], [], 2],
	"_find_empty_slot": [0, [], [], 2],
	"_get_faction_system": [0, [], [], 24],
	"_emit_safe": [2, [], [], 0],
	"_invoke_cb": [2, [], [], 0],
	"_clear_all": [0, [], [], 0],
	# 条件实时重判（DeploymentSystem 信号处理器按名接）
	"recheck_all_conditions": [0, [], [], 28],
	"_on_field_changed": [3, [2, 2, 0], [-1, -1, null], 0],
	# 光环查询
	"get_aura_bonus": [2, [], [], 27],
	# 序列化 / 反序列化 / 快照导出
	"serialize_all": [0, [], [], 27],
	"deserialize_all": [1, [], [], 0],
	"write_snapshot_to_gsm": [0, [], [], 0],
	"_get_gsm": [0, [], [], 24],
	# 战斗结束清理
	"clear_all_formations": [0, [], [], 0],
}

## 信号快照——[code]{信号名: [形参名...]}[/code]（UI 与战斗域按名 connect 这 6 条）。
const EXPECTED_SIGNALS: Dictionary = {
	"formation_deployed": ["formation_id", "slot_index", "template_id", "deployed_turn"],
	"formation_activated": ["formation_id", "slot_index", "template_id", "trigger_reason"],
	"formation_deactivated": ["formation_id", "slot_index", "reason"],
	"formation_overwritten": ["old_formation_id", "new_formation_id", "slot_index"],
	"character_affiliated": ["character_id", "formation_id"],
	"formation_condition_reevaluated": ["changes"],
}

## 实例字段快照——[code]{字段名: 类型整数值}[/code]。拆分后仍是[b]实例[/b]字段
## （不得因搬文件误写成 static），类型也不得变。
const EXPECTED_FIELDS: Dictionary = {
	"_slots": 27, "_affiliations": 27, "_next_formation_id": 2, "_deploy_turn": 2,
	"_pending_affiliations": 28,
	"condition_check_cb": 25, "effect_register_cb": 25, "effect_remove_cb": 25,
	"card_discard_cb": 25, "count_on_field_cb": 25, "fixed_bonus_cb": 25,
	"character_exists_cb": 25,
	"_serializer": 24, "_aura": 24, "_slot_ops": 24,
}

## 枚举快照——[code]{枚举名: {成员名: 取值}}[/code]。枚举值进制位（存档
## [code]battle.formation_snapshot[/code] 与三个子模块的私有枚举值副本都按整数比对，
## 逐位不得变——[code]formation_slot_ops.gd[/code] 里那份
## [code]_STATE_ACTIVE: int = 2[/code] 就是靠这组值对齐的）。
const EXPECTED_SLOT_STATE: Dictionary = {
	"EMPTY": 0, "DEPLOYED_UNACTIVE": 1, "ACTIVE": 2, "DISCARDED": 3,
}
const EXPECTED_AURA_SCOPE: Dictionary = {
	"GLOBAL": 0, "AFFILIATED_CHARACTERS": 1, "SAME_FACTION": 2, "FORMATION_TRIGGER": 3,
}

## 标量常量快照——[code]{常量名: 值}[/code]。
const EXPECTED_SCALAR_CONSTANTS: Dictionary = {
	"MAX_SLOTS": 3,
}

## 链上常量表应恰好 3 张（2 枚举 + 1 标量）——多了要显式更新本快照。
const EXPECTED_CONSTANT_COUNT: int = 3


# ═══════════════════════════════════════════════════════════════════════════════
# 链式反射工具——沿 [method Script.get_base_script] 合并整条继承链的面
# ═══════════════════════════════════════════════════════════════════════════════

## 走遍继承链收集脚本（链尾在前、首段在后——合并时后者覆盖前者，无重名故等价）。
func _chain() -> Array[Script]:
	var scripts: Array[Script] = []
	var cur: Script = FS_SCRIPT as Script
	while cur != null:
		scripts.append(cur)
		cur = cur.get_base_script()
	return scripts


## 合并全链方法表——[code]{方法名: 方法的反射条目}[/code]。
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
## 自己的常量（同 [code]tribulation_system[/code] / [code]scene_manager[/code] 轮结论），
## 祖先段声明的不在其中。
func _merged_constants() -> Dictionary:
	var merged: Dictionary = {}
	for sc: Script in _chain():
		var cm: Dictionary = sc.get_script_constant_map()
		for key: Variant in cm:
			merged[String(key)] = cm[key]
	return merged


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 方法面：34 个方法的形参个数 / 默认参数 / 返回值类型逐位不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_method_face_locked() -> void:
	assert_eq(EXPECTED_METHODS.size(), 34, "方法快照应 34 个")
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
		var defaults: Array = entry.get("default_args", [])
		assert_eq(defaults.size(), (expected[1] as Array).size(),
				"方法 %s 默认参数个数应不变" % method_name)
		var got_types: Array[int] = []
		for d: Variant in defaults:
			got_types.append(typeof(d))
		assert_eq(got_types, expected[1],
				"方法 %s 默认参数类型应逐位不变" % method_name)
		assert_eq(defaults, expected[2],
				"方法 %s 默认参数值应逐位不变" % method_name)
		assert_eq(int((entry.get("return", {}) as Dictionary).get("type", 0)),
				int(expected[3]), "方法 %s 返回值类型应不变" % method_name)
		checked += 1
	assert_eq(checked, EXPECTED_METHODS.size(), "方法快照应全部比对到")


func test_no_untracked_methods() -> void:
	# 面内不得出现未登记的方法——新增/改名都要显式更新本快照。
	var untracked: Array[String] = []
	for method_name: String in _merged_methods():
		if not EXPECTED_METHODS.has(method_name):
			untracked.append(method_name)
	assert_eq(untracked.size(), 0, "不应出现未登记的方法：%s" % str(untracked))


func test_no_ready_hook_introduced() -> void:
	# 本类[b]从没有[/b] _ready——Autoload 本体不订阅任何信号，接线在战斗域做。
	# 拆分时若顺手补一个 _ready，会与「谁在何时接 DeploymentSystem 信号」的既有约定打架
	# （既有集成测试自己 fs.call("_on_field_changed", …)），故钉死这条不发生。
	assert_false(_merged_methods().has("_ready"),
			"不应新增 _ready——本类历史上没有就绪钩子")


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
	# 信号必须能在[b]实例[/b]上按名 connect（UI 层走 node.connect(&"…", …)）。
	var fs: Node = FS_SCRIPT.new()
	for signal_name: String in EXPECTED_SIGNALS:
		assert_true(fs.has_signal(signal_name), "实例上应能解析信号 %s" % signal_name)
	fs.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 字段面：15 个实例字段在册、类型不变，且仍是实例字段
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
	var a: Node = FS_SCRIPT.new()
	var b: Node = FS_SCRIPT.new()
	a.set("_next_formation_id", 99)
	a.set("_affiliations", {1: 2})
	a.set("_serializer", RefCounted.new())
	assert_eq(int(b.get("_next_formation_id")), 1, "另一实例的 _next_formation_id 应为默认 1")
	assert_eq((b.get("_affiliations") as Dictionary).size(), 0,
			"另一实例的 _affiliations 应为默认空表")
	assert_null(b.get("_serializer"), "另一实例的 _serializer 应仍为 null")
	assert_not_null(a.get("_serializer"), "本实例的 _serializer 应已写入")
	a.free()
	b.free()


func test_default_state_locked() -> void:
	# 构造后的默认态（[method _init] 跑完、[method _reset_slots] 铺好 3 个空位）：
	# 3 个 EMPTY 空位 / ID 从 1 起 / 回合 0 / 延迟队列空 / 7 个存根 Callable 全无效 /
	# 3 个子模块均未建。
	var fs: Node = FS_SCRIPT.new()
	var slots: Dictionary = fs.get("_slots")
	assert_eq(slots.size(), 3, "默认应有 3 个阵位")
	for i: int in range(3):
		var slot: Dictionary = slots[i]
		assert_eq(int(slot["state"]), 0, "阵位 %d 默认应为 EMPTY(0)" % i)
		assert_eq(int(slot["formation_id"]), -1, "阵位 %d 默认 formation_id 应为 -1" % i)
		assert_eq(int(slot["card_instance_id"]), -1, "阵位 %d 默认 card_instance_id 应为 -1" % i)
		assert_eq(String(slot["template_id"]), "", "阵位 %d 默认 template_id 应为空" % i)
		assert_eq(int(slot["deployed_turn"]), -1, "阵位 %d 默认 deployed_turn 应为 -1" % i)
		assert_eq(int(slot["aura_scope"]), 1,
				"阵位 %d 默认 aura_scope 应为 AFFILIATED_CHARACTERS(1)" % i)
		assert_eq((slot["affiliated_chars"] as Array).size(), 0,
				"阵位 %d 默认无归属角色" % i)
	assert_eq(int(fs.get("_next_formation_id")), 1, "默认 ID 应从 1 起")
	assert_eq(int(fs.get("_deploy_turn")), 0, "默认回合应为 0")
	assert_eq((fs.get("_pending_affiliations") as Array).size(), 0, "默认延迟队列应为空")
	for cb_name: String in ["condition_check_cb", "effect_register_cb", "effect_remove_cb",
			"card_discard_cb", "count_on_field_cb", "fixed_bonus_cb", "character_exists_cb"]:
		assert_false((fs.get(cb_name) as Callable).is_valid(), "默认 %s 应无效" % cb_name)
	for sub_name: String in ["_serializer", "_aura", "_slot_ops"]:
		assert_null(fs.get(sub_name), "默认 %s 应为 null（惰性创建）" % sub_name)
	fs.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 常量面与入口契约：枚举 / 标量 / resource_path / Autoload 注册值
# ═══════════════════════════════════════════════════════════════════════════════

func test_slot_state_enum_locked() -> void:
	var consts: Dictionary = _merged_constants()
	assert_true(consts.has("SlotState"), "常量表应含 SlotState")
	if not consts.has("SlotState"):
		return
	assert_eq(consts["SlotState"], EXPECTED_SLOT_STATE, "SlotState 枚举取值应逐项不变")


func test_aura_scope_enum_locked() -> void:
	var consts: Dictionary = _merged_constants()
	assert_true(consts.has("AuraScope"), "常量表应含 AuraScope")
	if not consts.has("AuraScope"):
		return
	assert_eq(consts["AuraScope"], EXPECTED_AURA_SCOPE, "AuraScope 枚举取值应逐项不变")


func test_scalar_constants_locked() -> void:
	var consts: Dictionary = _merged_constants()
	for const_name: String in EXPECTED_SCALAR_CONSTANTS:
		assert_true(consts.has(const_name), "常量 %s 应存在" % const_name)
		if not consts.has(const_name):
			continue
		assert_eq(consts[const_name], EXPECTED_SCALAR_CONSTANTS[const_name],
				"常量 %s 值应不变" % const_name)


func test_no_untracked_constants() -> void:
	# 链上常量应恰好 3 张——多了/少了都要显式更新本快照。
	var consts: Dictionary = _merged_constants()
	assert_eq(consts.size(), EXPECTED_CONSTANT_COUNT,
			"链上常量应恰好 %d 张：%s" % [EXPECTED_CONSTANT_COUNT, str(consts.keys())])


func test_static_enum_access_resolves_through_chain() -> void:
	# 四个既有测试文件按路径 preload 后以[b]静态形式[/b]读枚举
	# （[code]FS_SCRIPT.SlotState.ACTIVE[/code] / [code]FS_SCRIPT.AuraScope.SAME_FACTION[/code]）
	# ——拆分后必须仍沿链解析得到，否则这些测试整体解析期失败。
	assert_eq(int(FS_SCRIPT.SlotState.ACTIVE), 2, "静态读 SlotState.ACTIVE 应成立")
	assert_eq(int(FS_SCRIPT.SlotState.DISCARDED), 3, "静态读 SlotState.DISCARDED 应成立")
	assert_eq(int(FS_SCRIPT.AuraScope.SAME_FACTION), 2, "静态读 AuraScope.SAME_FACTION 应成立")
	assert_eq(int(FS_SCRIPT.MAX_SLOTS), 3, "静态读 MAX_SLOTS 应成立")


func test_entry_path_base_type_and_autoload_registration_unchanged() -> void:
	# 外部按这一串字符 preload、引擎按这一串字符注册 Autoload——两者都是契约。
	var script: Script = FS_SCRIPT as Script
	assert_eq(script.resource_path, EXPECTED_PATH, "入口路径应逐字不变")
	assert_eq(script.get_instance_base_type(), EXPECTED_NATIVE_BASE,
			"原生基类应仍是 Node（Autoload 实例化前提）")
	assert_eq(String(script.get_global_name()), EXPECTED_GLOBAL_NAME,
			"不应新增 class_name——保持按路径取类这一条路")
	var config := ConfigFile.new()
	assert_eq(config.load("res://project.godot"), OK, "project.godot 应能被加载")
	assert_eq(String(config.get_value("autoload", "FormationSystem", "")),
			EXPECTED_AUTOLOAD_VALUE, "Autoload 注册值应逐字不变")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 面仍然可用：真实跑通部署 / 覆盖 / 归属 / 光环 / 重判 / 快照 / 清理
# ═══════════════════════════════════════════════════════════════════════════════

const REQ_3_ZHENGDAO: Dictionary = {"tag_id": &"zhengdao", "min_count": 3}
const FIXED_EFFECT: Dictionary = {"hp": 2.0, "def": 1.0}

## 本用例建出来的实例——[method after_each] 统一释放，不留孤儿。
var _nodes: Array[Node] = []
var _signal_log: Array[String] = []
var _effect_log: Array[String] = []
var _condition_result: bool = true
var _count_result: int = 0


func before_each() -> void:
	_signal_log.clear()
	_effect_log.clear()
	_condition_result = true
	_count_result = 0


func after_each() -> void:
	for n: Node in _nodes:
		if is_instance_valid(n):
			n.free()
	_nodes.clear()
	_signal_log.clear()
	_effect_log.clear()


## 建一个注好四个存根、连好六条信号探针的实例。
## [b]为什么用 lambda 而非 [method Callable.bind][/b]：[code]bind[/code] 追加到调用参数
## [b]末尾[/b]，而信号参数在最前——绑一个 String 标签会被当成第一个信号形参（实测报
## 「Cannot convert argument 1 from int to String」并把整条信号链打断）。lambda 能
## 显式吞掉任意个数的信号实参。
func _make_fs() -> Node:
	var fs: Node = FS_SCRIPT.new()
	_nodes.append(fs)
	fs.set("condition_check_cb", Callable(self, "_on_check_condition"))
	fs.set("count_on_field_cb", Callable(self, "_on_count_on_field"))
	fs.set("effect_register_cb", Callable(self, "_on_effect_register"))
	fs.set("effect_remove_cb", Callable(self, "_on_effect_remove"))
	fs.set("card_discard_cb", Callable(self, "_on_card_discard"))
	fs.formation_deployed.connect(func(_a: int, _b: int, _c: StringName,
			_d: int) -> void: _signal_log.append("d"))
	fs.formation_activated.connect(func(_a: int, _b: int, _c: StringName,
			_d: String) -> void: _signal_log.append("a"))
	fs.formation_deactivated.connect(func(_a: int, _b: int, _c: String) -> void:
		_signal_log.append("x"))
	fs.formation_overwritten.connect(func(_a: int, _b: int, _c: int) -> void:
		_signal_log.append("o"))
	fs.character_affiliated.connect(func(_a: int, _b: int) -> void:
		_signal_log.append("f"))
	fs.formation_condition_reevaluated.connect(func(_a: Array) -> void:
		_signal_log.append("r"))
	return fs


func _on_check_condition(_requirement: Dictionary) -> bool:
	return _condition_result


func _on_count_on_field(_tag_id: StringName) -> int:
	return _count_result


func _on_effect_register(card_instance_id: int, _template_id: StringName,
		_scope_context: Dictionary) -> void:
	_effect_log.append("register:%d" % card_instance_id)


func _on_effect_remove(card_instance_id: int) -> void:
	_effect_log.append("remove:%d" % card_instance_id)


func _on_card_discard(card_instance_id: int) -> void:
	_effect_log.append("discard:%d" % card_instance_id)


func test_init_and_deploy_query_path_still_wired() -> void:
	# _init → _reset_slots → _make_empty_slot 全链；部署 → 立即判定 → 查询三个出口。
	var fs: Node = _make_fs()
	var can: Dictionary = fs.can_deploy()
	assert_true(bool(can["can_deploy"]), "空阵法区应可部署")
	assert_eq(int(can["empty_slots"]), 3, "空阵法区应有 3 个空位")

	var r: Dictionary = fs.deploy_formation(100, &"formation_zhengdao_01")
	assert_true(bool(r["success"]), "空位部署成功")
	assert_eq(int(r["slot_index"]), 0, "自动分配到 slot 0")
	assert_eq(int(r["formation_id"]), 1, "首个阵法 ID 应为 1")
	assert_true(bool(r["activated"]), "条件满足（存根 true）→ 立即 ACTIVE")
	assert_eq(String(r["reason"]), "deployed_active", "reason = deployed_active")
	assert_true(_signal_log.has("d"), "应发 formation_deployed")
	assert_true(_signal_log.has("a"), "条件满足 → 应发 formation_activated")
	assert_true(_effect_log.has("register:100"), "激活 → effect_register_cb 被调用")

	var st: Dictionary = fs.get_formation_state(1)
	assert_eq(int(st["state"]), 2, "get_formation_state 应回报 ACTIVE(2)")
	assert_eq(int(st["slot_index"]), 0, "get_formation_state 应回报 slot_index")
	assert_true(bool(st["is_active"]), "is_active 应为 true")
	assert_eq((fs.get_active_formations() as Array).size(), 1, "应恰有 1 个 ACTIVE 阵法")
	assert_eq((fs.get_slot_states() as Array).size(), 3, "get_slot_states 应回报 3 个阵位")


func test_deploy_inactive_and_slots_full_path_still_wired() -> void:
	# 条件不满足 → DEPLOYED_UNACTIVE；满 3 位（含未激活）→ slots_full。
	var fs: Node = _make_fs()
	_condition_result = false
	var r0: Dictionary = fs.deploy_formation(100, &"f1", -1, REQ_3_ZHENGDAO)
	assert_false(bool(r0["activated"]), "条件不满足 → activated=false")
	assert_eq(String(r0["reason"]), "deployed_inactive", "reason = deployed_inactive")
	assert_eq(int(fs.get_slot_states()[0]["state"]), 1, "状态应为 DEPLOYED_UNACTIVE(1)")
	assert_false(_signal_log.has("a"), "未激活不应发 formation_activated")

	_condition_result = true
	fs.deploy_formation(101, &"f2", 1)
	fs.deploy_formation(102, &"f3", 2)
	var r: Dictionary = fs.deploy_formation(103, &"f4")
	assert_false(bool(r["success"]), "满位部署应失败")
	assert_eq(String(r["reason"]), "slots_full", "reason = slots_full")
	assert_eq(int(r["formation_id"]), -1, "未分配 formation_id")
	assert_false(bool(fs.can_deploy()["can_deploy"]), "满位后 can_deploy 应为 false")


func test_overwrite_path_still_wired() -> void:
	# 覆盖：旧阵 DISCARDED → 清归属 → 移旧效果 → 新阵部署 → 判定 → 注册新效果。
	var fs: Node = _make_fs()
	fs.deploy_formation(100, &"f1", 0)
	fs.set_character_affilation(200, 1)
	var r: Dictionary = fs.overwrite_formation(101, &"f2", 0)
	assert_true(bool(r["success"]), "覆盖应成功")
	assert_eq(int(fs.get_character_affilation(200)), -1, "覆盖应清除旧归属")
	assert_true(_effect_log.has("remove:100"), "覆盖应移除旧效果")
	assert_true(_effect_log.has("discard:100"), "覆盖应把旧卡进弃牌堆")
	assert_true(_signal_log.has("o"), "应发 formation_overwritten")
	assert_eq((fs.get_slot_states()[0]["template_id"] as StringName), &"f2",
			"阵位应换成新阵法模板")


func test_affiliation_path_still_wired() -> void:
	# 归属三分支：已有归属拒 / 非 ACTIVE 拒 / 正常写入并发信号。
	var fs: Node = _make_fs()
	_condition_result = false
	fs.deploy_formation(100, &"f1", 0, REQ_3_ZHENGDAO)
	assert_false(fs.set_character_affilation(200, 1), "阵法非 ACTIVE → 拒绝归属")

	_condition_result = true
	fs.deploy_formation(101, &"f2", 1)
	assert_true(fs.set_character_affilation(200, 2), "ACTIVE 阵法 → 接受归属")
	assert_true(_signal_log.has("f"), "应发 character_affiliated")
	assert_eq(int(fs.get_character_affilation(200)), 2, "归属应记在阵法 2 上")
	assert_false(fs.set_character_affilation(200, 2), "已有归属 → 再次指定应被拒")
	assert_eq(int(fs.get_slot_states()[1]["affiliated_count"]), 1, "阵位归属计数应 +1")

	fs.clear_character_affilation(200)
	assert_eq(int(fs.get_character_affilation(200)), -1, "清除后应无归属")
	assert_eq(int(fs.get_slot_states()[1]["affiliated_count"]), 0, "阵位归属计数应归零")
	fs.clear_character_affilation(999)  # 未归属角色——应为静默无操作
	assert_true(true, "清除未归属角色不应崩溃")


func test_aura_bonus_path_still_wired() -> void:
	# 固定阵法读 effect_config；梯度阵法按场上人数 × base_value 封顶。
	var fs: Node = _make_fs()
	fs.deploy_formation(100, &"cangxuan_zhengdao", 0, REQ_3_ZHENGDAO, 1,
			FIXED_EFFECT, 0, 0.0)
	fs.set_character_affilation(200, 1)
	var fixed: Dictionary = fs.get_aura_bonus(200, "hp")
	assert_eq(float(fixed["total_bonus"]), 2.0, "固定阵法 HP+2")
	assert_eq((fixed["breakdown"] as Array).size(), 1, "breakdown 应含 1 条")

	fs.deploy_formation(101, &"xuanbing_huichun", 1, REQ_3_ZHENGDAO, 2, {}, 5, 1.0)
	fs.set_character_affilation(201, 2)
	_count_result = 4
	var grad: Dictionary = fs.get_aura_bonus(201, "hp")
	assert_eq(float(grad["total_bonus"]), 3.0, "4 人 → min(4-1, 5)=3 → 3.0")
	_count_result = 1
	assert_eq(float(fs.get_aura_bonus(201, "hp")["total_bonus"]), 0.0,
			"低于 2 人门槛 → 返回 0")
	assert_eq(float(fs.get_aura_bonus(999, "hp")["total_bonus"]), 0.0,
			"未归属角色 → 返回 0")


func test_recheck_and_field_changed_path_still_wired() -> void:
	# recheck 只回报变更、不发射信号；_on_field_changed 处理副作用 + 批量发信号。
	var fs: Node = _make_fs()
	_condition_result = false
	fs.deploy_formation(100, &"f1", 0, REQ_3_ZHENGDAO)
	_condition_result = true
	var changes: Array = fs.recheck_all_conditions()
	assert_eq(changes.size(), 1, "应回报 1 条变更")
	assert_eq(int(changes[0]["old_state"]), 1, "old_state 应为 DEPLOYED_UNACTIVE")
	assert_eq(int(changes[0]["new_state"]), 2, "new_state 应为 ACTIVE")
	assert_false(_signal_log.has("a"), "recheck 本身不应发射信号")

	_condition_result = false
	_signal_log.clear()
	fs.call("_on_field_changed", 200, 0, "death")
	assert_true(_signal_log.has("x"), "失活应发 formation_deactivated")
	assert_true(_signal_log.has("r"), "应批量发 formation_condition_reevaluated")
	assert_eq(int(fs.get_slot_states()[0]["state"]), 1, "阵位应回到 DEPLOYED_UNACTIVE")


func test_serialize_deserialize_and_gsm_snapshot_path_still_wired() -> void:
	# 快照三出口：serialize_all / deserialize_all / write_snapshot_to_gsm（走 GSM battle 域）。
	# 阵法 1 须为 ACTIVE 才收得下归属（非 ACTIVE 会被 set_character_affilation 拒）。
	var fs: Node = _make_fs()
	fs.deploy_formation(100, &"f1", 0)
	fs.deploy_formation(101, &"f2", 1)
	fs.set_character_affilation(200, 1)

	var data: Dictionary = fs.serialize_all()
	assert_eq((data["slots"] as Array).size(), 3, "快照应含 3 阵位")
	assert_eq((data["affiliations"] as Dictionary).size(), 1, "快照应含 1 条归属")
	assert_eq(int(data["next_formation_id"]), 3, "next_formation_id 应为 3")
	assert_eq(String((data["slots"] as Array)[0]["template_id"]), "f1",
			"template_id 应已 StringName → String")

	fs.clear_all_formations()
	assert_eq((fs.get_active_formations() as Array).size(), 0, "清理后无 ACTIVE 阵法")
	assert_eq(int(fs.serialize_all()["next_formation_id"]), 3,
			"clear_all_formations 应保留 next_formation_id（ADR-0024 §验证标准）")

	fs.deserialize_all(data)
	assert_eq(int(fs.get_character_affilation(200)), 1, "归属应恢复")
	assert_eq(int(fs.get_slot_states()[0]["formation_id"]), 1, "阵位 formation_id 应恢复")

	GameStateManager.battle_start({})
	fs.write_snapshot_to_gsm()
	assert_true(GameStateManager.battle.has("formation_snapshot"),
			"应写入 GSM battle.formation_snapshot")
	assert_eq((GameStateManager.battle["formation_snapshot"]["affiliations"] as Dictionary).size(),
			1, "GSM 快照应含 1 条归属")
	GameStateManager.battle_end({})


func test_internal_primitives_still_wired() -> void:
	# 子模块按名回取的内部原语：_get_slot_by_formation / _get_slot_index_by_formation /
	# _find_empty_slot / _clear_affiliations_by_formation / _clear_all / _invoke_cb / set_deploy_turn。
	var fs: Node = _make_fs()
	fs.set_deploy_turn(7)
	assert_eq(int(fs.get("_deploy_turn")), 7, "set_deploy_turn 应写入")
	fs.deploy_formation(100, &"f1", 0)
	assert_eq(int(fs.get_slot_states()[0]["deployed_turn"]), 7, "部署应记录当前回合")

	assert_eq(int(fs.call("_find_empty_slot")), 1, "第一个空位应是 1")
	assert_eq(int(fs.call("_get_slot_index_by_formation", 1)), 0, "按 ID 反查阵位索引")
	assert_false((fs.call("_get_slot_by_formation", 999) as Dictionary).size() > 0,
			"未知 ID 应返回空表")
	assert_eq(int(fs.call("_get_slot_by_formation", 1)["formation_id"]), 1,
			"已知 ID 应返回该阵位")

	fs.set_character_affilation(200, 1)
	fs.call("_clear_affiliations_by_formation", 1)
	assert_eq(int(fs.get_character_affilation(200)), -1, "按阵法清归属应生效")
	assert_eq(int(fs.get_slot_states()[0]["affiliated_count"]), 0,
			"阵位 affiliated_chars 应同步清空")

	fs.set("_pending_affiliations", [{"character_id": 1}])
	fs.call("_clear_all")
	assert_eq(int(fs.get("_next_formation_id")), 1, "_clear_all 应重置 ID 为 1")
	assert_eq(int(fs.get("_deploy_turn")), 0, "_clear_all 应重置回合")
	assert_eq((fs.get("_affiliations") as Dictionary).size(), 0, "_clear_all 应清归属")

	var seen: Array = []
	fs.call("_invoke_cb", Callable(self, "_on_effect_remove"), [999])
	assert_true(_effect_log.has("remove:999"), "_invoke_cb 应转发调用")
	fs.call("_invoke_cb", Callable(), [1])  # 无效 Callable——应静默跳过
	assert_eq(seen.size(), 0, "无效 Callable 不应产生任何效果")


func test_lazy_submodules_and_autoload_accessors_still_wired() -> void:
	# 三个惰性获取器建出同一实例 + 路径逐字不变；两个 Autoload 获取器在测试态解析得到真实节点。
	var fs: Node = _make_fs()
	for getter: String in EXPECTED_SUBMODULE_PATHS:
		var sub_a: RefCounted = fs.call(getter)
		assert_not_null(sub_a, "%s 应惰性建出子模块" % getter)
		assert_eq(fs.call(getter), sub_a, "%s 应复用同一实例" % getter)
		assert_eq((sub_a.get_script() as Script).resource_path,
				String(EXPECTED_SUBMODULE_PATHS[getter]),
				"%s 建出的子模块路径应逐字不变" % getter)

	var plain: Node = FS_SCRIPT.new()
	_nodes.append(plain)
	assert_eq(plain.call("_get_faction_system"), _autoload("FactionSystem"),
			"_get_faction_system 应回退到按名查找 FactionSystem")
	assert_eq(plain.call("_get_gsm"), _autoload("GameStateManager"),
			"_get_gsm 应回退到按名查找 GameStateManager")

	# 无 condition_check_cb 时 _check_condition 走真实 FactionSystem；空 requirement 直接放行。
	assert_true(plain.call("_check_condition", {}), "空 requirement → 无条件阵法直接激活")


func test_emit_safe_routes_through_gsm() -> void:
	# _emit_safe 经 GSM._emit_signal_safe 路由（ADR-0007 深度追踪）——不改直连 emit。
	var fs: Node = FS_SCRIPT.new()
	_nodes.append(fs)
	var got: Array = []
	fs.character_affiliated.connect(func(c: int, f: int) -> void:
		got.append([c, f]))
	fs.call("_emit_safe", &"character_affiliated", [7, 9])
	assert_eq(got.size(), 1, "应收到 1 次信号")
	assert_eq(got[0], [7, 9], "载荷应逐位传递")


## 按名取 Autoload——测试态下这些单例都已注册（断言「回退路径通」而非「返回 null」）。
func _autoload(p_name: String) -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null(
			"/root/%s" % p_name)
