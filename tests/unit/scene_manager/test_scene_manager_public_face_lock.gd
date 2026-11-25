extends GutTest
## SceneManager 公开面锁定守卫——拆分重构前置护栏。
##
## [b]为什么需要这条守卫[/b]：[code]src/foundation/scene_manager.gd[/code]（430 行）要按
## 职责拆成继承链。拆分的唯一硬约束是「对外 API 逐位不变」——方法名、形参个数、
## 默认参数个数[b]与值[/b]、返回值类型、信号、实例字段、常量，一个都不许改。危险在于
## [b]编译器不会替我们发现断链[/b]：
##   · 全工程 16 处 [code]preload("res://src/foundation/scene_manager.gd")[/code] 按[b]路径[/b]
##     取这个类，再以 [code]SceneManagerScript.SceneID.COMBAT[/code] 这种[b]静态形式[/b]
##     取枚举 / 常量 / 静态方法；
##   · [code]project.godot[/code] 的 [code][autoload][/code] 把 [code]SceneManager[/code]
##     绑在这一串路径上，30+ 处调用点直接以 Autoload 全局名发起
##     [code]SceneManager.request_scene_change(...)[/code]——[b]按名动态分派[/b]；
##   · [code]scene_transition.gd[/code] 用 [code]_parent.get("_test_mode")[/code] /
##     [code]_parent.set("_phase3_in_progress", ...)[/code] / [code]_parent.call("_get_gsm")[/code]
##     跨文件按字符串取字段与方法。
##
## [b]与前几轮（[code]combat_system[/code] / [code]gsm_atomic_writes[/code] /
## [code]settlement_panel[/code]）的形态差异[/b]：本类[b]是 Autoload 且不带
## [code]class_name[/code][/b]（Foundation Autoload 固有权衡，见
## [code]game_state_manager.gd[/code] 头注释），并额外带[b]两个 static 方法[/b]
## （[method create_fade_overlay] / [method fade_out_overlay]）与[b]两张 const 表[/b]。
## 继承链是否仍能承载「静态形式取祖先段枚举/常量/静态方法」「Autoload 注册路径指向
## 链尾时实例化」这两件事，本文件用真实调用形态逐一断言（探针实测结论见
## [code]tools/probe_sm_split.gd[/code]）。
##
## [b]锁什么[/b]：
##   · 23 个方法的[形参个数 / 默认参数个数 / 默认参数值 / 返回值类型]
##   · 2 个信号的名字与形参名（[code]pre_transition[/code] / [code]post_transition[/code]）
##   · 11 个实例字段存在、类型不变、且[b]未被 static 化[/b]（两个实例互不影响）
##   · 5 个常量（SceneID 12 项 / TransitionType 6 项 / SCENE_PATHS 12 项 /
##     TRANSITION_AUDIO_PARAMS 5 项 / _AUDIO_MANAGER_SCRIPT 指向 audio_manager.gd）值逐位不变
##   · [code]resource_path[/code] / 原生基类 / [code]project.godot[/code] 的 Autoload 注册值
##   · 面内不得出现未登记的方法 / 信号 / 字段（新增或改名都要显式更新本快照）
##   · 真实跑一趟转场：静态形式取枚举 → [method request_scene_change] 校验与 Phase 2 →
##     [method _execute_post_load] 的 Phase 4-5（GSM 写入 / 解锁 / 信号 / 状态复位）
##
## [b]怎么锁「整条继承链的面」[/b]：反射沿 [method Script.get_base_script] 走遍全链再合并
## ——拆分前链长 1（单文件），拆分后链长 N，两种形态下合并结果必须逐位相同。[b]不锁[/b]
## 函数体实现、注释、成员落在哪个文件——这些正是拆分要动的东西。
##
## 来源: .claude/docs/coding-standards.md §文件行数限制（300 行软上限）、
## ADR-0005 §5 阶段异步转换管线、ADR-0031 §1.2（PersistentLayer 挂载）。

const SM_SCRIPT := preload("res://src/foundation/scene_manager.gd")
const MockFactory := preload("res://tests/integration/scene_manager/mocks/mock_factory.gd")

## 入口路径——外部按这一串字符 load、Autoload 按这一串字符注册，逐字不变。
const EXPECTED_PATH: String = "res://src/foundation/scene_manager.gd"

## [code]project.godot[/code] 的 [code][autoload][/code] 取值（前缀 [code]*[/code] = 单例）。
const EXPECTED_AUTOLOAD_VALUE: String = "*res://src/foundation/scene_manager.gd"

## 原生基类——链尾必须是 [Node] 的直接后继，否则 Autoload 实例化失败。
const EXPECTED_NATIVE_BASE: StringName = &"Node"

## 方法快照——[code]{方法名: [形参个数, [默认参数值...] 或 null（另测）, 返回值类型]}[/code]，
## 按反射实测登记。返回值类型是 [enum Variant.Type] 的整数值（0 = NIL/void、1 = bool、
## 2 = int、3 = float、24 = Object、28 = Array）。
## [method verify_scene_paths] 的默认值是整张 SCENE_PATHS 表（12 项），单独在
## [method test_verify_scene_paths_default_is_scene_paths_table] 里逐项比对。
const EXPECTED_METHODS: Dictionary = {
	# 装配（[method _ready] 靠后——它要调全部惰性获取器，链序由「谁调谁靠后」定死）
	"_ready": [0, [], 0],
	# 依赖注入（[code]scene_transition.gd[/code] 按名字符串调这三个）
	"set_dependencies": [3, [null, null, null], 0],
	"_get_gsm": [0, [], 24],
	"_get_im": [0, [], 24],
	"_get_save_load": [0, [], 24],
	# 子模块惰性获取（返回 RefCounted / 类型化引用）
	"_get_transition": [0, [], 24],
	"_get_persistent_layer": [0, [], 24],
	"_get_audio_manager": [0, [], 24],
	# 音频门面（4 处外部调用点）
	"get_audio_manager": [0, [], 24],
	"set_audio_manager": [1, [], 0],
	# 公共 API（Autoload 全局名 + 测试按名直呼）
	"register_persistent": [1, [], 0],
	"request_scene_change": [3, [], 1],
	"get_current_scene_id": [0, [], 2],
	"is_transitioning": [0, [], 1],
	"verify_scene_paths": [1, null, 28],
	# 信号发射包装（[code]scene_transition.gd[/code] 按名调 _emit_post_transition）
	"_emit_pre_transition": [3, [], 0],
	"_emit_post_transition": [2, [], 0],
	# 异步转换管线（[code]scene_transition.gd[/code] 经 _get_transition 委托进来的四个口）
	"_execute_transition": [2, [], 0],
	"_cleanup_on_error": [1, [], 0],
	"_inject_loading_context": [2, [], 0],
	"_execute_post_load": [3, [], 0],
	# 静态工具（[code]loading_screen.gd[/code] 按路径 preload 后静态调用）
	"create_fade_overlay": [0, [], 24],
	"fade_out_overlay": [2, [0.25], 0],
}

## 信号快照——[code]{信号名: [形参名...]}[/code]（audio_manager 按名 connect 这两条）。
const EXPECTED_SIGNALS: Dictionary = {
	"pre_transition": ["from", "to", "type"],
	"post_transition": ["from", "to"],
}

## 实例字段快照——[code]{字段名: 类型整数值}[/code]。拆分后仍是[b]实例[/b]字段
## （不得因搬文件误写成 static），类型也不得变。
const EXPECTED_FIELDS: Dictionary = {
	"_transitioning": 1, "_transition_type": 2, "_current_scene_id": 2,
	"_test_mode": 1, "_phase3_in_progress": 1,
	"_transition": 24, "_persistent_layer": 24, "_audio_manager": 24,
	"_gsm": 24, "_im": 24, "_save_load": 24,
}

## SceneID 枚举全 12 项——外部按 [code]SceneManagerScript.SceneID.XXX[/code] 取，
## 值就是 .tscn 的注册键，改一个就是断链。
const EXPECTED_SCENE_ID: Dictionary = {
	"MAIN_MENU": 0, "IDENTITY_SELECT": 1, "DECK_EDITING": 2, "EXPLORATION": 3,
	"COMBAT": 4, "TRIBULATION": 5, "SHOP": 6, "EVENT_PANEL": 7,
	"RESULT_SCREEN": 8, "DEFEAT_SCREEN": 9, "CULTIVATION": 10, "LOADING": 99,
}

## TransitionType 枚举全 6 项——驱动音频 BGM 过渡矩阵（audio Story 004）。
const EXPECTED_TRANSITION_TYPE: Dictionary = {
	"NONE": 0, "MENU_TO_GAME": 1, "GAME_TO_MENU": 2,
	"EXPLORE_TO_COMBAT": 3, "COMBAT_TO_EXPLORE": 4, "TRIBULATION": 5,
}

## SCENE_PATHS 注册表全 12 项——[method verify_scene_paths] 的默认参数就是这张表。
const EXPECTED_SCENE_PATHS: Dictionary = {
	0: "res://src/ui/main_menu/MainMenu.tscn",
	1: "res://src/ui/identity_select/identity_select.tscn",
	2: "res://src/ui/deck_editing/deck_editing.tscn",
	3: "res://src/feature/exploration/exploration_scene.tscn",
	4: "res://src/feature/combat/combat_scene.tscn",
	5: "res://src/feature/tribulation/tribulation_scene.tscn",
	6: "res://src/feature/shop/shop_scene.tscn",
	7: "res://src/ui/event_panel/event_panel.tscn",
	8: "res://src/ui/result_screen/result_screen.tscn",
	9: "res://src/ui/defeat_screen/defeat_screen.tscn",
	10: "res://src/feature/cultivation/cultivation_scene.tscn",
	99: "res://src/ui/loading/loading_screen.tscn",
}

## TRANSITION_AUDIO_PARAMS 全 5 项——数值已与 audio-manager 的状态矩阵对齐
## （探索→战斗 0.5s 淡出、渡劫 0.3s 顺序式）。
const EXPECTED_AUDIO_PARAMS: Dictionary = {
	1: {"duration_seconds": 1.5, "from_behavior": &"fade_out", "to_behavior": &"fade_in"},
	2: {"duration_seconds": 1.5, "from_behavior": &"fade_out", "to_behavior": &"fade_in"},
	3: {"duration_seconds": 0.5, "from_behavior": &"fade_out", "to_behavior": &"fade_in"},
	4: {"duration_seconds": 1.0, "from_behavior": &"fade_out", "to_behavior": &"fade_in"},
	5: {"duration_seconds": 0.3, "from_behavior": &"fade_out", "to_behavior": &"fade_in",
			"sequential": true},
}

## preload 常量——[method _get_audio_manager] 靠它静态解析 AudioManager 脚本。
const EXPECTED_AUDIO_SCRIPT_PATH: String = "res://src/ui/audio/audio_manager.gd"

## 转场锁 source 字面量——与 [code]input_lock_stack.gd[/code] 的
## [code]SCENE_TRANSITION_SOURCE[/code] 及 [code]tests/integration/input/test_lock_reentry.gd[/code]
## 三处一致（本文件是第三处，守拆分后 push/pop 仍在同一条路径上）。
const SM_LOCK_SOURCE: StringName = &"scene_manager"


# ═══════════════════════════════════════════════════════════════════════════════
# 链式反射工具——沿 [method Script.get_base_script] 合并整条继承链的面
# ═══════════════════════════════════════════════════════════════════════════════

## 走遍继承链收集脚本（链尾在前、首段在后——合并时后者覆盖前者，无重名故等价）。
func _chain() -> Array[Script]:
	var scripts: Array[Script] = []
	var cur: Script = SM_SCRIPT as Script
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
## 自己的常量，祖先段声明的不在其中（[code]tools/probe_sm_split.gd[/code] C 段实测）。
func _merged_constants() -> Dictionary:
	var merged: Dictionary = {}
	for sc: Script in _chain():
		for key: Variant in sc.get_script_constant_map():
			merged[String(key)] = sc.get_script_constant_map()[key]
	return merged


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 方法面：23 个方法的形参个数 / 默认参数 / 返回值类型逐位不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_method_face_locked() -> void:
	assert_eq(EXPECTED_METHODS.size(), 23, "方法快照应 23 个")
	var table: Dictionary = _merged_methods()
	var checked: int = 0
	for method_name: String in EXPECTED_METHODS:
		var expected: Array = EXPECTED_METHODS[method_name]
		assert_true(table.has(method_name),
				"方法 %s 应存在（拆分后不得丢）" % method_name)
		if not table.has(method_name):
			continue
		var entry: Dictionary = table[method_name]
		var args: Array = entry.get("args", [])
		var defaults: Array = entry.get("default_args", [])
		assert_eq(args.size(), int(expected[0]), "方法 %s 形参个数应不变" % method_name)
		if expected[1] != null:
			var want_defaults: Array = expected[1]
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


func test_static_methods_stay_callable_from_path_script() -> void:
	# 两个 static 是唯一「不经实例」的对外出口（loading_screen.gd 按路径 preload 后静态调）。
	# 走链后它们必须仍在链尾脚本上可按静态形式解析。
	assert_eq(String(SM_SCRIPT.create_fade_overlay().get_class()), "ColorRect",
			"链尾静态形式调 create_fade_overlay 应返回 ColorRect")
	var overlay: ColorRect = null
	for child: Node in get_tree().root.get_children():
		if child is ColorRect and child.name == "FadeOverlay":
			overlay = child
			break
	assert_not_null(overlay, "create_fade_overlay 应把叠加层挂进 SceneTree 根")
	if overlay != null:
		# null 安全路径（AC-8）——不应崩
		SM_SCRIPT.fade_out_overlay(null, 0.0)
		overlay.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 信号面：2 个出口信号的名字与形参名逐位不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_signal_face_locked() -> void:
	assert_eq(EXPECTED_SIGNALS.size(), 2, "信号快照应 2 个")
	var table: Dictionary = _merged_signals()
	assert_eq(table.size(), EXPECTED_SIGNALS.size(),
			"信号表应恰好 %d 个：%s" % [EXPECTED_SIGNALS.size(), str(table.keys())])
	for signal_name: String in EXPECTED_SIGNALS:
		assert_true(table.has(signal_name),
				"信号 %s 应存在（audio_manager 按名 connect）" % signal_name)
		if not table.has(signal_name):
			continue
		assert_eq(table[signal_name], EXPECTED_SIGNALS[signal_name],
				"信号 %s 形参名应逐位不变" % signal_name)


func test_signals_connectable_on_instance() -> void:
	# 信号必须能在[b]实例[/b]上按名 connect（audio_manager 走 node.connect(&"pre_transition", ...)）。
	var sm: Node = SM_SCRIPT.new()
	for signal_name: String in EXPECTED_SIGNALS:
		assert_true(sm.has_signal(signal_name), "实例上应能解析信号 %s" % signal_name)
	sm.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 字段面：11 个实例字段在册、类型不变，且仍是实例字段
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
	# （[_transitioning] / [_current_scene_id] 是全局单例语义，static 化会跨实例串味。）
	var a: Node = SM_SCRIPT.new()
	var b: Node = SM_SCRIPT.new()
	a.set("_transitioning", true)
	a.set("_current_scene_id", 99)
	a.set("_test_mode", true)
	assert_false(bool(b.get("_transitioning")), "另一实例的 _transitioning 不受影响")
	assert_eq(int(b.get("_current_scene_id")), 0, "另一实例的 _current_scene_id 应为默认 0")
	assert_false(bool(b.get("_test_mode")), "另一实例的 _test_mode 应为默认 false")
	a.free()
	b.free()


func test_default_state_locked() -> void:
	# 构造后的默认态（[method _ready] 前后都依赖）：非转场 / 类型 NONE / 场景主菜单 /
	# 非测试模式 / Phase 3 未启动 / 三个子模块引用为 null（惰性）。
	var sm: Node = SM_SCRIPT.new()
	assert_false(sm.is_transitioning(), "默认不应在转场中")
	assert_eq(int(sm.get("_transition_type")), 0, "默认 _transition_type 应为 NONE")
	assert_eq(sm.get_current_scene_id(), 0, "默认场景应为主菜单")
	assert_false(bool(sm.get("_test_mode")), "默认不应是测试模式")
	assert_false(bool(sm.get("_phase3_in_progress")), "默认 Phase 3 未启动")
	assert_null(sm.get("_transition"), "默认转场子模块应惰性未建")
	assert_null(sm.get("_persistent_layer"), "默认持久层子模块应惰性未建")
	assert_null(sm.get("_audio_manager"), "默认音频门面应惰性未建")
	assert_null(sm.get("_gsm"), "默认不应注入 GSM")
	assert_null(sm.get("_im"), "默认不应注入 InputManager")
	assert_null(sm.get("_save_load"), "默认不应注入 SaveLoad")
	sm.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 常量面与入口契约：五张常量表、resource_path、Autoload 注册值、原生基类
# ═══════════════════════════════════════════════════════════════════════════════

func test_enum_constants_locked() -> void:
	var consts: Dictionary = _merged_constants()
	assert_true(consts.has("SceneID"), "常量表应含 SceneID")
	assert_true(consts.has("TransitionType"), "常量表应含 TransitionType")
	if not consts.has("SceneID") or not consts.has("TransitionType"):
		return
	var scene_id: Dictionary = consts["SceneID"]
	var trans: Dictionary = consts["TransitionType"]
	assert_eq(scene_id.size(), EXPECTED_SCENE_ID.size(),
			"SceneID 应 %d 项：%s" % [EXPECTED_SCENE_ID.size(), str(scene_id.keys())])
	for key: String in EXPECTED_SCENE_ID:
		assert_true(scene_id.has(key), "SceneID 应含 %s" % key)
		if scene_id.has(key):
			assert_eq(int(scene_id[key]), int(EXPECTED_SCENE_ID[key]),
					"SceneID.%s 值应不变" % key)
	assert_eq(trans.size(), EXPECTED_TRANSITION_TYPE.size(),
			"TransitionType 应 %d 项：%s" % [EXPECTED_TRANSITION_TYPE.size(), str(trans.keys())])
	for key: String in EXPECTED_TRANSITION_TYPE:
		assert_true(trans.has(key), "TransitionType 应含 %s" % key)
		if trans.has(key):
			assert_eq(int(trans[key]), int(EXPECTED_TRANSITION_TYPE[key]),
					"TransitionType.%s 值应不变" % key)


func test_scene_paths_table_locked() -> void:
	var consts: Dictionary = _merged_constants()
	assert_true(consts.has("SCENE_PATHS"), "常量表应含 SCENE_PATHS")
	if not consts.has("SCENE_PATHS"):
		return
	var paths: Dictionary = consts["SCENE_PATHS"]
	assert_eq(paths.size(), EXPECTED_SCENE_PATHS.size(),
			"SCENE_PATHS 应 %d 项：%s" % [EXPECTED_SCENE_PATHS.size(), str(paths.keys())])
	for key: int in EXPECTED_SCENE_PATHS:
		assert_true(paths.has(key), "SCENE_PATHS 应含键 %d" % key)
		if paths.has(key):
			assert_eq(String(paths[key]), String(EXPECTED_SCENE_PATHS[key]),
					"SCENE_PATHS[%d] 路径应逐字不变" % key)


func test_audio_params_table_locked() -> void:
	var consts: Dictionary = _merged_constants()
	assert_true(consts.has("TRANSITION_AUDIO_PARAMS"), "常量表应含 TRANSITION_AUDIO_PARAMS")
	if not consts.has("TRANSITION_AUDIO_PARAMS"):
		return
	var params: Dictionary = consts["TRANSITION_AUDIO_PARAMS"]
	assert_eq(params.size(), EXPECTED_AUDIO_PARAMS.size(),
			"TRANSITION_AUDIO_PARAMS 应 %d 项：%s" % [EXPECTED_AUDIO_PARAMS.size(),
					str(params.keys())])
	for key: int in EXPECTED_AUDIO_PARAMS:
		assert_true(params.has(key), "参数表应含过渡类型 %d" % key)
		if not params.has(key):
			continue
		var got: Dictionary = params[key]
		var want: Dictionary = EXPECTED_AUDIO_PARAMS[key]
		assert_eq(float(got.get("duration_seconds", -1.0)), float(want["duration_seconds"]),
				"过渡类型 %d 时长应不变" % key)
		assert_eq(StringName(got.get("from_behavior", &"")), StringName(want["from_behavior"]),
				"过渡类型 %d from_behavior 应不变" % key)
		assert_eq(StringName(got.get("to_behavior", &"")), StringName(want["to_behavior"]),
				"过渡类型 %d to_behavior 应不变" % key)
		assert_eq(bool(got.get("sequential", false)), bool(want.get("sequential", false)),
				"过渡类型 %d sequential 标记应不变" % key)


func test_audio_script_preload_constant_locked() -> void:
	var consts: Dictionary = _merged_constants()
	assert_true(consts.has("_AUDIO_MANAGER_SCRIPT"), "常量表应含 _AUDIO_MANAGER_SCRIPT")
	if not consts.has("_AUDIO_MANAGER_SCRIPT"):
		return
	var script: Variant = consts["_AUDIO_MANAGER_SCRIPT"]
	assert_true(script is GDScript, "_AUDIO_MANAGER_SCRIPT 应是 GDScript 资源")
	if script is GDScript:
		assert_eq(String((script as GDScript).resource_path), EXPECTED_AUDIO_SCRIPT_PATH,
				"AudioManager 脚本路径应逐字不变")


func test_verify_scene_paths_default_is_scene_paths_table() -> void:
	# [method verify_scene_paths] 的默认参数是整张注册表——不是 12 个 null，
	# 也不是空表。拆分时若默认值走样，调用点的「不传参即全表自检」语义就断了。
	var entry: Dictionary = _merged_methods()["verify_scene_paths"]
	var defaults: Array = entry.get("default_args", [])
	assert_eq(defaults.size(), 1, "verify_scene_paths 应有 1 个默认参数")
	if defaults.is_empty():
		return
	assert_true(defaults[0] is Dictionary, "默认参数应是 Dictionary")
	if not (defaults[0] is Dictionary):
		return
	var got: Dictionary = defaults[0]
	assert_eq(got.size(), EXPECTED_SCENE_PATHS.size(),
			"默认参数应是 %d 项注册表：%s" % [EXPECTED_SCENE_PATHS.size(), str(got.keys())])
	for key: int in EXPECTED_SCENE_PATHS:
		assert_true(got.has(key), "默认参数应含键 %d" % key)
		if got.has(key):
			assert_eq(String(got[key]), String(EXPECTED_SCENE_PATHS[key]),
					"默认参数[%d] 应逐字等于 SCENE_PATHS[%d]" % [key, key])


func test_entry_path_base_type_and_autoload_registration_unchanged() -> void:
	# 外部按这一串字符 load、引擎按这一串字符注册 Autoload——两者都是契约。
	var script: Script = SM_SCRIPT as Script
	assert_eq(script.resource_path, EXPECTED_PATH, "入口路径应逐字不变")
	assert_eq(script.get_instance_base_type(), EXPECTED_NATIVE_BASE,
			"原生基类应仍是 Node（Autoload 实例化前提）")
	var config := ConfigFile.new()
	assert_eq(config.load("res://project.godot"), OK, "project.godot 应能被加载")
	assert_eq(String(config.get_value("autoload", "SceneManager", "")),
			EXPECTED_AUTOLOAD_VALUE, "Autoload 注册值应逐字不变")


func test_static_enum_and_const_access_from_path_script() -> void:
	# 这是全工程 16 处调用点的[b]真实写法[/b]（[code]SceneManagerScript.SceneID.COMBAT[/code]）。
	# 枚举若被拆到祖先段而链尾脚本解析不到，这一行就是编译期/运行期断链。
	assert_eq(int(SM_SCRIPT.SceneID.COMBAT), 4, "静态形式应取到 SceneID.COMBAT")
	assert_eq(int(SM_SCRIPT.SceneID.LOADING), 99, "静态形式应取到 SceneID.LOADING")
	assert_eq(int(SM_SCRIPT.TransitionType.COMBAT_TO_EXPLORE), 4,
			"静态形式应取到 TransitionType.COMBAT_TO_EXPLORE")
	assert_eq(String(SM_SCRIPT.SCENE_PATHS[SM_SCRIPT.SceneID.COMBAT]),
			"res://src/feature/combat/combat_scene.tscn",
			"静态形式应取到 SCENE_PATHS 表")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 面仍然可用：真实跑一趟转场（校验 → Phase 2 → Phase 4-5）
# ═══════════════════════════════════════════════════════════════════════════════

## 本用例建出来的 mock 依赖——[method after_each] 统一释放，不留孤儿。
var _mocks: Array[Node] = []


func after_each() -> void:
	for m: Node in _mocks:
		if is_instance_valid(m):
			m.free()
	_mocks.clear()


## 建一个注入了 mock 依赖、已 [method _ready] 的 SceneManager 实例。[br]
## [b]形态对齐先例[/b] [code]tests/integration/input/test_lock_reentry.gd[/code]：
## 先显式 [method _ready]（[method _get_persistent_layer] / [method _get_audio_manager]
## 均为幂等惰性创建），再入树——两次初始化结果相同，不产生额外副作用。[br]
## [param test_mode] 恒为 [code]true[/code]：本用例是单元层，任何真实
## [code]change_scene_to_file[/code] 都会把宿主的当前场景换掉并留下孤儿场景节点。
func _build_injected(test_mode: bool) -> Dictionary:
	var sm: Node = SM_SCRIPT.new()
	var gsm: Node = MockFactory.build_gsm()
	var im: Node = MockFactory.build_im()
	var sl: Node = MockFactory.build_sl()
	_mocks.append(gsm)
	_mocks.append(im)
	_mocks.append(sl)
	sm.set_dependencies(gsm, im, sl)
	sm._ready()
	add_child_autofree(sm)
	sm.set("_test_mode", test_mode)
	return {"sm": sm, "gsm": gsm, "im": im, "sl": sl}


func test_request_scene_change_validation_paths_locked() -> void:
	var ctx: Dictionary = _build_injected(true)
	var sm: Node = ctx["sm"]
	# 未注册的 to → 返回 false 且不推锁
	assert_false(sm.request_scene_change(0, 12345, 1),
			"未注册场景 ID 应被拒绝")
	# 注入的 mock 未被推锁
	assert_eq(int(ctx["im"].get("push_calls")), 0, "被拒绝的请求不应推锁")
	# 合法请求 → 受理
	assert_true(sm.request_scene_change(SM_SCRIPT.SceneID.MAIN_MENU,
			SM_SCRIPT.SceneID.EXPLORATION, SM_SCRIPT.TransitionType.MENU_TO_GAME),
			"合法请求应被受理")
	assert_true(sm.is_transitioning(), "受理后应进入转场态")
	# 并发守卫：转场中再发 → 拒绝
	assert_false(sm.request_scene_change(SM_SCRIPT.SceneID.EXPLORATION,
			SM_SCRIPT.SceneID.COMBAT, SM_SCRIPT.TransitionType.EXPLORE_TO_COMBAT),
			"转场中应拒绝并发请求")


func test_verify_scene_paths_returns_empty_on_real_registry() -> void:
	# 启动自检：真实注册表里 12 条路径都应存在——返回空数组。
	var sm: Node = SM_SCRIPT.new()
	var missing: Array = sm.verify_scene_paths()
	assert_eq(missing.size(), 0, "真实注册表不应有缺失路径：%s" % str(missing))
	# 假表返回缺失项（测试可传参）
	var fake: Dictionary = {0: "res://definitely_missing_scene.tscn"}
	var fake_missing: Array = sm.verify_scene_paths(fake)
	assert_eq(fake_missing.size(), 1, "假表应报 1 条缺失")
	sm.free()


func test_full_transition_pipeline_still_wired() -> void:
	# Phase 2（推锁 + 自动存档 + pre_transition）→ Phase 4-5（GSM 写入 + 解锁 +
	# post_transition + 状态复位）。任一环断在拆分里，本用例变红。
	var ctx: Dictionary = _build_injected(true)  # _test_mode：跳过真实异步加载
	var sm: Node = ctx["sm"]
	var im: Node = ctx["im"]
	var sl: Node = ctx["sl"]
	var gsm: Node = ctx["gsm"]

	var pre_hits: Array = []
	var post_hits: Array = []
	sm.connect(&"pre_transition",
			func(from: int, to: int, type: int) -> void: pre_hits.append([from, to, type]))
	sm.connect(&"post_transition",
			func(from: int, to: int) -> void: post_hits.append([from, to]))

	var from_id: int = SM_SCRIPT.SceneID.MAIN_MENU
	var to_id: int = SM_SCRIPT.SceneID.EXPLORATION
	var type_id: int = SM_SCRIPT.TransitionType.MENU_TO_GAME
	assert_true(sm.request_scene_change(from_id, to_id, type_id), "请求应被受理")

	# —— Phase 2 成果
	assert_eq(pre_hits.size(), 1, "Phase 2 应发一次 pre_transition")
	assert_eq(pre_hits[0], [from_id, to_id, type_id], "pre_transition 载荷应逐位不变")
	assert_eq(int(im.get("push_calls")), 1, "Phase 2 应推一次转场锁")
	assert_eq(str(im.get("_call_log")[0]["source"]), String(SM_LOCK_SOURCE),
			"推锁 source 应逐字不变")
	var push_entry: Dictionary = im.get("_call_log")[0]
	assert_eq(int(push_entry["type"]), 3, "推锁类型应为 TRANSITION（3）")
	assert_true(bool(sl.get("auto_save_called")), "Phase 2 应触发一次自动存档")

	# —— Phase 4-5（测试路径：测试模式跳过了异步段，手动推进同步段）
	var target_path: String = String(SM_SCRIPT.SCENE_PATHS[to_id])
	sm._execute_post_load(from_id, to_id, target_path)

	assert_eq(post_hits.size(), 1, "Phase 4 应发一次 post_transition")
	assert_eq(post_hits[0], [from_id, to_id], "post_transition 载荷应逐位不变")
	assert_eq(int(im.get("pop_calls")), 1, "Phase 4 应解锁一次")
	assert_eq(String(gsm.get("session")["current_scene"]), target_path,
			"Phase 4 应把目标路径写进 GSM")
	assert_eq(int(gsm.get("session")["scene_id"]), to_id, "Phase 4 应把目标 ID 写进 GSM")
	assert_eq(sm.get_current_scene_id(), to_id, "Phase 5 应更新当前场景 ID")
	assert_false(sm.is_transitioning(), "Phase 5 应复位转场态")
	assert_eq(int(sm.get("_transition_type")), 0, "Phase 5 应复位转换类型为 NONE")
	assert_false(bool(sm.get("_phase3_in_progress")), "Phase 5 应复位 Phase 3 标志")


func test_cleanup_on_error_resets_state_and_releases_lock() -> void:
	# 错误恢复入口：三处状态复位 + 强制释放 TRANSITION 锁（防死锁 / 锁泄漏）。
	var ctx: Dictionary = _build_injected(true)
	var sm: Node = ctx["sm"]
	var im: Node = ctx["im"]
	sm.request_scene_change(SM_SCRIPT.SceneID.MAIN_MENU, SM_SCRIPT.SceneID.SHOP,
			SM_SCRIPT.TransitionType.MENU_TO_GAME)
	assert_true(sm.is_transitioning(), "前置：应进入转场态")
	assert_eq(int(im.get("push_calls")), 1, "前置：已推锁")

	sm._cleanup_on_error(&"probe_failure")

	assert_false(sm.is_transitioning(), "清理后应退出转场态")
	assert_eq(int(sm.get("_transition_type")), 0, "清理后转换类型应回 NONE")
	assert_false(bool(sm.get("_phase3_in_progress")), "清理后 Phase 3 标志应回 false")
	assert_eq(int(im.get("pop_calls")), 1, "清理应强制释放一次锁")


func test_audio_manager_facade_and_persistent_layer_still_wired() -> void:
	# 两条惰性子模块入口 + 音频门面：拆分若把惰性获取器与调用方分到相反方向，这里变红。
	var sm: Node = SM_SCRIPT.new()
	add_child_autofree(sm)
	sm._ready()
	assert_not_null(sm.get("_persistent_layer"), "_ready 应建好持久层子模块")
	assert_not_null(sm.get("_audio_manager"), "_ready 应建好音频门面")
	assert_not_null(sm.get_audio_manager(), "get_audio_manager 应返回非 null")
	assert_eq(sm.get_audio_manager(), sm.get("_audio_manager"),
			"get_audio_manager 应返回同一实例（防 RefCounted 提前释放）")
	var layer: Node = sm.get_node_or_null(NodePath("PersistentLayer"))
	assert_not_null(layer, "PersistentLayer 应挂为 SceneManager 子节点")
	# 注入替换（测试专用入口）
	var fake_am: Variant = sm.get("_audio_manager")
	sm.set_audio_manager(fake_am)
	assert_eq(sm.get_audio_manager(), fake_am, "set_audio_manager 应替换门面实例")
