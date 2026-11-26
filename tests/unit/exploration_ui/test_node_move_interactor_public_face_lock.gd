extends GutTest
## NodeMoveInteractor 公开面锁定守卫——拆分重构前置护栏。
##
## [b]为什么需要这条守卫[/b]：[code]src/ui/exploration/node_move_interactor.gd[/code]（401 行）
## 要按职责拆成继承链。拆分的唯一硬约束是「对外 API 逐位不变」——方法名、形参个数与
## 形参名、默认参数个数[b]与值[/b]、返回值类型、信号名与形参名、实例字段类型与
## 「非 static」，一个都不许改。危险在于[b]编译器不会替我们发现断链[/b]：
##   · 外部按[b]路径[/b]取这个类（[code]node_graph_interaction_mount.gd[/code] 的
##     [code]NodeMoveInteractorScript.new()[/code]、四个集成测试与两个单元测试的
##     [code]preload[/code]）；
##   · 宿主用 [code]screen.get_node(NodePath("NodeMoveInteractor"))[/code] 按[b]节点名[/b]
##     取它（四个 fixture + 三个集成测试）——名字由挂载点决定，与文件名同源；
##   · 集成测试直接读 [code]interactor._snapshot[/code]、[code]_click_buffer[/code]
##     等瞬态字段（[code]get()[/code] 穿透继承链）。
##
## [b]与前几轮的形态差异[/b]：本类[b]无 [code]_init[/code]、无 static 成员、不是 Autoload[/b]
## （实测三空），但有 [b]5 个信号 + 4 个 preload 常量 + 4 张数据表常量[/b]，且
## [code]request_move[/code] / [code]_submit_move[/code] 的[b]默认参数取祖先段常量[/b]
## （[code]InputManagerScript.DeviceType.MOUSE[/code]）——按链序硬约束，这些声明必须
## 落在链首段，故本用例额外锁[b]默认参数值 [/b][code]1[/code]（= DeviceType.MOUSE）与
## 信号形参名（信号只能声明在链首，派生段 emit）。
##
## [b]锁什么[/b]：
##   · 27 个方法的[形参个数 / 形参名 / 默认参数个数 / 默认参数值 / 返回值类型]
##   · 5 个信号的名字与形参名
##   · 10 个实例字段存在、类型不变、且[b]未被 static 化[/b]（两个实例互不影响）
##   · 3 个文案常量 + [constant KEY_DIRECTIONS] 逐键逐项 + [constant REASON_TEXTS]
##     逐键逐项（含 [code]"已访问" → ""[/code] 这条「静默」语义）
##   · 4 个 preload 常量仍解析到同一批路径
##   · [code]resource_path[/code] / [code]class_name[/code] / 原生基类逐字不变
##   · [b]全链任一段都不得出现 [code]static[/code] [/b]（源码行扫描——反射看不见
##     [code]static var[/code]，见下）
##   · 面内不得出现未登记的方法（新增或改名都要显式更新本快照）
##
## [b]怎么锁「整条继承链的面」[/b]：反射沿 [method Script.get_base_script] 走遍全链再合并
## ——拆分前链长 1（单文件），拆分后链长 N，两种形态下合并结果必须逐位相同。[b]不锁[/b]
## 函数体实现、注释、成员落在哪个文件——这些正是拆分要动的东西。
##
## [b]为什么字段的 static 化必须靠源码扫描[/b]：[method Script.get_script_property_list]
## [b]看不见[/b] [code]static var[/code]（实测只列实例字段），故
## [method test_no_static_members_in_any_segment] 逐段读文件、断言无行以
## [code]static [/code] 开头——这条与两条实例独立性断言缺一不可。
##
## 来源: .claude/docs/coding-standards.md §文件行数限制（300 行软上限）、
## ADR-0031 §2（零状态所有权）/ §3（Tween 为输入驱动视觉变换）/ §4（单一视觉来源）、
## ADR-0014 §决策 3（点击一律委托系统）、ADR-0004（双焦点按设备独立判定）、
## exploration-ui Story S17-005。

const INTERACTOR_SCRIPT := preload("res://src/ui/exploration/node_move_interactor.gd")
const INPUT_MANAGER_SCRIPT := preload("res://src/foundation/input_manager.gd")

## 入口路径——外部按这一串字符 [code]preload[/code]，逐字不变。
const EXPECTED_PATH: String = "res://src/ui/exploration/node_move_interactor.gd"

## 全局类名——两个单元测试按此名标注类型，拆到哪个文件都得留着它。
const EXPECTED_GLOBAL_NAME: StringName = &"NodeMoveInteractor"

## 形参表——[code]{方法名: [形参名...]}[/code]，按反射实测登记。
## 形参名是 ADR 层面的契约：[code]node_moved[/code] 转发、[code]device[/code] 锁栈
## 判定、[code]dir[/code] 方向跳转都靠名字读语义，改名即改契约。
const EXPECTED_ARGS: Dictionary = {
	"setup": ["p_renderer", "p_system"],
	"teardown": [],
	"set_reduce_motion": ["value"],
	"apply_snapshot": ["snapshot"],
	"_on_system_node_moved": ["from_node", "to_node", "ap_remaining"],
	"_on_renderer_input": ["event"],
	"request_move": ["node_id", "device"],
	"_has_buffered": ["node_id"],
	"_submit_move": ["node_id", "device"],
	"_play_failure_feedback": ["reason", "node_id"],
	"_play_move_animation": ["from_node", "to_node"],
	"_finish_move_animation": ["to_node"],
	"_unhandled_key_input": ["event"],
	"navigate_focus": ["dir"],
	"confirm_keyboard_selection": [],
	"_bind_system_signals": [],
	"_on_combat_reached": ["roster", "combat_type"],
	"_on_boss_reached": ["boss_data"],
	"_on_node_interaction": ["node_id", "interaction_type", "payload"],
	"_defer_or_forward": ["forward"],
	"_flush_pending_arrival": [],
	"_connect_if_present": ["signal_name", "handler"],
	"_is_input_allowed": ["device"],
	"_hit_test": ["point"],
	"_is_reachable_node": ["node_id"],
	"_sync_marker_to_current": [],
	"_notification": ["what"],
}

## 方法快照——[code]{方法名: [默认参数值, 返回值类型]}[/code]，按反射实测登记。
## 返回值类型是 [enum Variant.Type] 的整数值（0 = void、1 = bool、2 = int、
## 24 = Object、25 = Callable、27 = Dictionary、28 = Array）。
## [b]默认参数值 [/b][code]1[/code] = [code]InputManagerScript.DeviceType.MOUSE[/code]
## ——常量必须随声明落链首段，否则派生段解析不到。
const EXPECTED_METHODS: Dictionary = {
	# 生命周期（宿主挂载 / 重建时调用——公开面）
	"setup": [[], 0],
	"teardown": [[], 0],
	"set_reduce_motion": [[], 0],
	"apply_snapshot": [[], 0],
	# 点击路径（manifest Forbidden 红线——一律委托系统判定）
	"_on_renderer_input": [[], 0],
	"request_move": [[1], 0],
	"_has_buffered": [[], 1],
	"_submit_move": [[1], 0],
	# 失败反馈（系统 reason 驱动）
	"_play_failure_feedback": [[], 0],
	# 移动动画（node_moved 驱动）
	"_on_system_node_moved": [[], 0],
	"_play_move_animation": [[], 0],
	"_finish_move_animation": [[], 0],
	# 键盘路径（A3——方向键跳转 + Enter 确认）
	"_unhandled_key_input": [[], 0],
	"navigate_focus": [[], 2],
	"confirm_keyboard_selection": [[], 0],
	# 系统信号转发（到达通知——006/007 消费点）
	"_bind_system_signals": [[], 0],
	"_on_combat_reached": [[], 0],
	"_on_boss_reached": [[], 0],
	"_on_node_interaction": [[], 0],
	"_defer_or_forward": [[], 0],
	"_flush_pending_arrival": [[], 0],
	"_connect_if_present": [[], 0],
	# 内部辅助
	"_is_input_allowed": [[], 1],
	"_hit_test": [[], 2],
	"_is_reachable_node": [[], 1],
	"_sync_marker_to_current": [[], 0],
	"_notification": [[], 0],
}

## 信号快照——[code]{信号名: [形参名...]}[/code]。
## 信号只能声明在[b]链首段[/b]（派生段 [method Object.emit_signal] 解析期找不到祖先
## 未声明的名字），故链首段的这 5 行一个都不能动。
const EXPECTED_SIGNALS: Dictionary = {
	"combat_arrival_forwarded": ["enemy_roster", "combat_type"],
	"boss_arrival_forwarded": ["boss_data"],
	"node_interaction_forwarded": ["node_id", "interaction_type", "payload"],
	"move_feedback_requested": ["toast_text", "node_id"],
	"keyboard_focus_changed": ["node_id"],
}

## 实例字段快照——[code]{字段名: 类型整数值}[/code]。拆分后仍是[b]实例[/b]字段
## （不得因搬文件误写成 [code]static var[/code]），类型也不得变
## （[Node] 句柄与 [Control] 句柄都挂 24 = Object、[Callable] 挂 25）。
const EXPECTED_FIELDS: Dictionary = {
	"exploration_system": 24,
	"renderer": 24,
	"_snapshot": 27,
	"_click_buffer": 28,
	"_animating": 1,
	"_keyboard_node": 2,
	"_pending_arrival": 25,
	"_animator": 24,
	"_reduce_motion": 1,
	"_bound_signals": 28,
}

## 文案常量（本地化豁免——S16/S17 各 story 同源口径，待 localization epic）。
const EXPECTED_TEXT_CONSTANTS: Dictionary = {
	"TEXT_AP_INSUFFICIENT": "行动力不足",
	"TEXT_UNREACHABLE": "路径不可达",
	"TEXT_MOVE_FAILED": "无法移动",
}

## [constant REASON_TEXTS]——系统 reason → toast 文案。逐键逐项锁死，
## 尤其 [code]"已访问" → ""[/code]（AC-4 静默语义靠这个空串实现）。
const EXPECTED_REASON_TEXTS: Dictionary = {
	"行动力不足": "行动力不足",
	"不可达": "路径不可达",
	"已访问": "",
	"DAG 缓存未就绪": "无法移动",
	"GSM 不可用": "无法移动",
}

## [constant KEY_DIRECTIONS]——方向键 → 方向向量（A3 数据表）。
const EXPECTED_KEY_DIRECTIONS: Dictionary = {
	KEY_UP: Vector2i(0, -1),
	KEY_DOWN: Vector2i(0, 1),
	KEY_LEFT: Vector2i(-1, 0),
	KEY_RIGHT: Vector2i(1, 0),
}

## preload 常量——[code]{常量名: 期望资源路径}[/code]。方法体全靠它们取值，
## 拆到哪一段都得在链上任一处解析得到，且路径不得漂移。
const EXPECTED_PRELOAD_CONSTANTS: Dictionary = {
	"InputManagerScript": "res://src/foundation/input_manager.gd",
	"Animator": "res://src/ui/exploration/node_move_animator.gd",
	"Navigator": "res://src/ui/exploration/node_keyboard_navigator.gd",
	"NodeStateLogicScript": "res://src/ui/exploration/node_state_logic.gd",
}

## 链上常量总数——4 个 preload + 1 张方向表 + 3 条文案 + 1 张 reason 表 = 9。
const EXPECTED_CONSTANT_COUNT: int = 9


## 测试用最小系统桩——只提供交互组件消费的信号与 [method move_to_node]。
class MockSystem extends Node:
	signal node_moved(from_node: int, to_node: int, ap_remaining: int)
	signal combat_node_reached(enemy_roster: Array, combat_type: StringName)
	signal boss_node_reached(boss_data: Dictionary)
	signal node_interaction_triggered(node_id: int, interaction_type: StringName,
			payload: Dictionary)

	var move_result: Dictionary = {"success": true, "reason": "", "ap_remaining": 2}
	var move_calls: Array = []

	func move_to_node(from_node: int, to_node: int) -> Dictionary:
		move_calls.append([from_node, to_node])
		if bool(move_result.get("success", false)):
			node_moved.emit(from_node, to_node, int(move_result.get("ap_remaining", 0)))
		return move_result


# ═══════════════════════════════════════════════════════════════════════════════
# 链式反射工具——沿 [method Script.get_base_script] 合并整条继承链的面
# ═══════════════════════════════════════════════════════════════════════════════

## 走遍继承链收集脚本（链尾在前、首段在后——合并时后者覆盖前者，无重名故等价）。
func _chain() -> Array[Script]:
	var scripts: Array[Script] = []
	var cur: Script = INTERACTOR_SCRIPT as Script
	while cur != null:
		scripts.append(cur)
		cur = cur.get_base_script()
	return scripts


## 合并全链方法表——[code]{方法名: 方法字典}[/code]。
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
			for a: Dictionary in s.get("args", []) as Array:
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
func _merged_constants() -> Dictionary:
	var merged: Dictionary = {}
	for sc: Script in _chain():
		for key: Variant in sc.get_script_constant_map():
			merged[String(key)] = sc.get_script_constant_map()[key]
	return merged


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 方法面：27 个方法的形参名 / 形参个数 / 默认参数值 / 返回值类型逐位不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_method_face_locked() -> void:
	assert_eq(EXPECTED_METHODS.size(), 27, "方法快照应 27 个")
	assert_eq(EXPECTED_ARGS.size(), EXPECTED_METHODS.size(),
		"形参快照应与方法快照同尺寸")
	var table: Dictionary = _merged_methods()
	var checked: int = 0
	for method_name: String in EXPECTED_METHODS:
		var expected: Array = EXPECTED_METHODS[method_name]
		var want_defaults: Array = expected[0]
		assert_true(table.has(method_name),
			"方法 %s 应存在（拆分后不得丢）" % method_name)
		if not table.has(method_name):
			continue
		var entry: Dictionary = table[method_name]
		var args: Array = entry.get("args", [])
		var defaults: Array = entry.get("default_args", [])
		var arg_names: Array[String] = []
		for a: Dictionary in args:
			arg_names.append(String(a["name"]))
		assert_eq(arg_names, EXPECTED_ARGS[method_name],
			"方法 %s 形参名应逐位不变" % method_name)
		assert_eq(args.size(), (EXPECTED_ARGS[method_name] as Array).size(),
			"方法 %s 形参个数应不变" % method_name)
		assert_eq(defaults.size(), want_defaults.size(),
			"方法 %s 默认参数个数应不变" % method_name)
		assert_eq(defaults, want_defaults,
			"方法 %s 默认参数值应逐位不变（1 = DeviceType.MOUSE）" % method_name)
		assert_eq(int((entry.get("return", {}) as Dictionary).get("type", 0)),
			int(expected[1]), "方法 %s 返回值类型应不变" % method_name)
		checked += 1
	assert_eq(checked, EXPECTED_METHODS.size(), "方法快照应全部比对到")


func test_no_untracked_methods() -> void:
	# 面内不得出现未登记的方法——新增或改名都要显式更新本快照。
	var untracked: Array[String] = []
	for method_name: String in _merged_methods():
		if not EXPECTED_METHODS.has(method_name) and not untracked.has(method_name):
			untracked.append(method_name)
	assert_eq(untracked.size(), 0, "不应出现未登记的方法：%s" % str(untracked))


func test_no_untracked_signals_or_fields() -> void:
	# 信号与字段同理：多一个少一个都要显式改快照。
	var extra_signals: Array[String] = []
	for signal_name: String in _merged_signals():
		if not EXPECTED_SIGNALS.has(signal_name):
			extra_signals.append(signal_name)
	assert_eq(extra_signals.size(), 0, "不应出现未登记的信号：%s" % str(extra_signals))
	var extra_fields: Array[String] = []
	for field_name: String in _merged_fields():
		if not EXPECTED_FIELDS.has(field_name):
			extra_fields.append(field_name)
	assert_eq(extra_fields.size(), 0, "不应出现未登记的字段：%s" % str(extra_fields))


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 信号面：5 个出口信号的名字与形参名逐位不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_signal_face_locked() -> void:
	assert_eq(EXPECTED_SIGNALS.size(), 5, "信号快照应 5 个")
	var table: Dictionary = _merged_signals()
	assert_eq(table.size(), EXPECTED_SIGNALS.size(),
		"信号表应恰好 %d 个：%s" % [EXPECTED_SIGNALS.size(), str(table.keys())])
	for signal_name: String in EXPECTED_SIGNALS:
		assert_true(table.has(signal_name),
			"信号 %s 应存在（宿主按名 connect）" % signal_name)
		if not table.has(signal_name):
			continue
		assert_eq(table[signal_name], EXPECTED_SIGNALS[signal_name],
			"信号 %s 形参名应逐位不变" % signal_name)


func test_signals_connectable_on_instance() -> void:
	# 信号必须能在[b]实例[/b]上按名 connect（宿主走 [code]node.connect(&"move_feedback_requested", ...)[/code]，
	# 信号若被搬丢或改名，这里立刻变红）。
	var inst: Control = INTERACTOR_SCRIPT.new()
	add_child_autofree(inst)
	for signal_name: String in EXPECTED_SIGNALS:
		assert_true(inst.has_signal(signal_name),
			"实例上应能解析信号 %s" % signal_name)


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 字段面：10 个实例字段在册、类型不变、默认值不变，且仍是实例字段
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


func test_default_state_locked() -> void:
	# 构造后的默认态（宿主与集成测试都依赖）：无注入、空快照、无游标、无暂存。
	var inst: Control = INTERACTOR_SCRIPT.new()
	add_child_autofree(inst)
	assert_null(inst.exploration_system, "默认无探索系统注入")
	assert_null(inst.renderer, "默认无渲染器注入")
	assert_true((inst.get("_snapshot") as Dictionary).is_empty(), "默认快照应为空")
	assert_true((inst.get("_click_buffer") as Array).is_empty(), "默认缓冲队列应为空")
	assert_false(bool(inst.get("_animating")), "默认不应处于动画中")
	assert_eq(int(inst.get("_keyboard_node")), -1, "默认键盘游标应为 -1（无）")
	assert_false((inst.get("_pending_arrival") as Callable).is_valid(),
		"默认不应有暂存到达通知")
	assert_null(inst.get("_animator"), "setup 前不应有动画编排器")
	assert_false(bool(inst.get("_reduce_motion")), "默认不做动态削减")
	assert_true((inst.get("_bound_signals") as Array).is_empty(), "默认无已绑信号")


func test_fields_not_staticized() -> void:
	# 两个实例互不影响——若拆分时把 var 误写成 static var，此处立刻变红。
	var a: Control = INTERACTOR_SCRIPT.new()
	add_child_autofree(a)
	var b: Control = INTERACTOR_SCRIPT.new()
	add_child_autofree(b)
	a.set("_keyboard_node", 101)
	a.set("_animating", true)
	a.set("_reduce_motion", true)
	(a.get("_click_buffer") as Array).append([101, INPUT_MANAGER_SCRIPT.DeviceType.MOUSE])
	assert_eq(int(b.get("_keyboard_node")), -1, "另一实例的 _keyboard_node 不受影响")
	assert_false(bool(b.get("_animating")), "另一实例的 _animating 不受影响")
	assert_false(bool(b.get("_reduce_motion")), "另一实例的 _reduce_motion 不受影响")
	assert_true((b.get("_click_buffer") as Array).is_empty(),
		"另一实例的 _click_buffer 不受影响")


func test_no_static_members_in_any_segment() -> void:
	# 反射看不见 static var（实测 get_script_property_list 只列实例字段），
	# 故 static 化只能靠逐段读源码行来抓——这条与上一条缺一不可。
	for sc: Script in _chain():
		var path: String = sc.resource_path
		assert_ne(path, "", "链上每一段都应有 resource_path")
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		assert_not_null(f, "应能打开链上脚本 %s" % path)
		if f == null:
			continue
		var offenders: Array[String] = []
		var lineno: int = 0
		while not f.eof_reached():
			var raw: String = f.get_line()
			lineno += 1
			var line: String = raw.strip_edges()
			if line.begins_with("static ") or line.contains(" static var ") \
					or line.begins_with("static\t"):
				offenders.append("%s:%d %s" % [path, lineno, line])
		f.close()
		assert_eq(offenders.size(), 0,
			"链上不得出现 static 成员：%s" % str(offenders))


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 常量与入口契约：文案表 / 方向表 / reason 表 / preload 常量 / resource_path
# ═══════════════════════════════════════════════════════════════════════════════

func test_text_constants_locked() -> void:
	var consts: Dictionary = _merged_constants()
	for const_name: String in EXPECTED_TEXT_CONSTANTS:
		assert_true(consts.has(const_name), "常量 %s 应存在" % const_name)
		if not consts.has(const_name):
			continue
		assert_eq(str(consts[const_name]), str(EXPECTED_TEXT_CONSTANTS[const_name]),
			"常量 %s 值应不变" % const_name)


func test_reason_texts_table_locked() -> void:
	var consts: Dictionary = _merged_constants()
	assert_true(consts.has("REASON_TEXTS"), "REASON_TEXTS 应存在")
	if not consts.has("REASON_TEXTS"):
		return
	var table: Dictionary = consts["REASON_TEXTS"]
	assert_eq(table, EXPECTED_REASON_TEXTS, "REASON_TEXTS 应逐键逐项不变")
	# 「已访问」静默语义（AC-4）单列一条硬断言——空串丢了就会弹「无法移动」。
	assert_eq(str(table.get("已访问", "<缺失>")), "", "「已访问」应映射为空文案（静默）")


func test_key_directions_table_locked() -> void:
	var consts: Dictionary = _merged_constants()
	assert_true(consts.has("KEY_DIRECTIONS"), "KEY_DIRECTIONS 应存在")
	if not consts.has("KEY_DIRECTIONS"):
		return
	assert_eq(consts["KEY_DIRECTIONS"], EXPECTED_KEY_DIRECTIONS,
		"KEY_DIRECTIONS 应逐键逐项不变（四方向全覆盖）")


func test_preload_constants_locked() -> void:
	var consts: Dictionary = _merged_constants()
	for const_name: String in EXPECTED_PRELOAD_CONSTANTS:
		assert_true(consts.has(const_name), "preload 常量 %s 应存在" % const_name)
		if not consts.has(const_name):
			continue
		var dep: Script = consts[const_name] as Script
		assert_not_null(dep, "常量 %s 应仍是 Script" % const_name)
		if dep == null:
			continue
		assert_eq(dep.resource_path, str(EXPECTED_PRELOAD_CONSTANTS[const_name]),
			"常量 %s 应仍指向同一脚本" % const_name)
	assert_eq(consts.size(), EXPECTED_CONSTANT_COUNT,
		"链上常量应恰好 %d 个：%s" % [EXPECTED_CONSTANT_COUNT, str(consts.keys())])


func test_entry_path_and_class_name_unchanged() -> void:
	# 外部按这一串字符 load、按全局名引用——两者都是契约。
	assert_eq((INTERACTOR_SCRIPT as Script).resource_path, EXPECTED_PATH,
		"入口路径应逐字不变")
	assert_eq((INTERACTOR_SCRIPT as Script).get_global_name(), EXPECTED_GLOBAL_NAME,
		"class_name 应保留")
	assert_eq((INTERACTOR_SCRIPT as Script).get_instance_base_type(), &"Control",
		"原生基类应仍是 Control")
	# 挂载点按节点名取它——名字由 [code]node_graph_interaction_mount.gd[/code] 设定，
	# 该字符串与文件名同源，改名会连带四个 fixture 一起红。
	assert_true(EXPECTED_PATH.ends_with("/node_move_interactor.gd"),
		"链尾文件名不得变（挂载点 NodePath(\"NodeMoveInteractor\") 与四个 fixture 依赖它）")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 面仍然可用：走一趟真实委托流（真实 setup——信号绑定 + 依赖接线）
# ═══════════════════════════════════════════════════════════════════════════════

## 走一趟真实 setup（renderer 传 null——overlay 与 Tween 全跳过，只测委托流本身）。
func _make_setup_interactor(p_mock: Node) -> Control:
	var inst: Control = INTERACTOR_SCRIPT.new()
	add_child_autofree(inst)
	inst.setup(null, p_mock)
	return inst


func test_move_delegation_still_works_end_to_end() -> void:
	# 真实调用链：request_move → _submit_move → 桩 move_to_node → node_moved
	# → _on_system_node_moved → 快照更新 + 动画完成 → 缓冲推进。
	# 拆段若把任一环落到「祖先段引用不到」的位置，脚本创建期就红；把逻辑搬丢
	# 则在运行期红。renderer 传 null（reduce_motion 路径无需 overlay）。
	var mock: Node = MockSystem.new()
	add_child_autofree(mock)
	var inst: Control = _make_setup_interactor(mock)
	inst.apply_snapshot({"graph": {}, "nodes": {0: {}, 101: {}}, "visited": [0],
			"current_node": 0, "ap_remaining": 3})

	inst.request_move(101)

	assert_eq(mock.move_calls.size(), 1, "move_to_node 应恰好调用一次")
	assert_eq(mock.move_calls[0], [0, 101], "调用参数应为 (当前 0, 目标 101)")
	var snapshot: Dictionary = inst.get("_snapshot")
	assert_eq(int(snapshot.get("current_node", -1)), 101, "快照当前节点应随信号更新")
	assert_eq(int(snapshot.get("ap_remaining", -1)), 2, "AP 应随系统返回值更新")
	assert_true((snapshot.get("visited", []) as Array).has(101),
		"目标节点应记入已访问")
	assert_false(bool(inst.get("_animating")), "无编排器时动画应即刻完成")


func test_failure_feedback_still_works_end_to_end() -> void:
	# 失败路径：系统返回 reason → 映射文案 → 发 move_feedback_requested。
	var mock: Node = MockSystem.new()
	add_child_autofree(mock)
	mock.move_result = {"success": false, "reason": "不可达", "ap_remaining": 3}
	var inst: Control = _make_setup_interactor(mock)
	inst.apply_snapshot({"graph": {}, "nodes": {0: {}, 102: {}}, "visited": [0],
			"current_node": 0, "ap_remaining": 3})

	var toasts: Array = []
	inst.move_feedback_requested.connect(func(text: String, node_id: int) -> void:
		toasts.append([text, node_id]))
	inst.request_move(102)
	assert_eq(toasts.size(), 1, "失败应发一条反馈")
	if toasts.size() == 1:
		assert_eq(toasts[0], ["路径不可达", 102], "reason 应映射为文案并带上节点 ID")

	# 「已访问」静默（AC-4）——空文案不发反馈。
	mock.move_result = {"success": false, "reason": "已访问", "ap_remaining": 3}
	inst.request_move(102)
	assert_eq(toasts.size(), 1, "「已访问」应静默（不新增反馈）")


func test_arrival_notification_still_works_end_to_end() -> void:
	# 到达通知转发：非动画态下立即转发（B4 的「动画完成再转发」另由集成测试覆盖）。
	var mock: Node = MockSystem.new()
	add_child_autofree(mock)
	var inst: Control = _make_setup_interactor(mock)
	inst.apply_snapshot({"graph": {}, "nodes": {0: {}}, "visited": [0],
			"current_node": 0, "ap_remaining": 3})

	var hits: Array = []
	inst.combat_arrival_forwarded.connect(func(roster: Array, combat_type: StringName) -> void:
		hits.append([roster, combat_type]))
	mock.combat_node_reached.emit([{"id": 7}], &"normal")
	assert_eq(hits.size(), 1, "非动画态下到达通知应立即转发")
	if hits.size() == 1:
		assert_eq(hits[0][1], &"normal", "combat_type 应逐字转发")


func test_teardown_is_idempotent_on_clean_instance() -> void:
	# 未 setup 过的实例上 teardown 不得报错（宿主重建路径会无条件调用）。
	var inst: Control = INTERACTOR_SCRIPT.new()
	add_child_autofree(inst)
	inst.teardown()
	inst.teardown()
	assert_eq(int(inst.get("_keyboard_node")), -1, "teardown 不应改动键盘游标默认值")
	assert_true((inst.get("_bound_signals") as Array).is_empty(),
		"teardown 后已绑信号表应为空")
