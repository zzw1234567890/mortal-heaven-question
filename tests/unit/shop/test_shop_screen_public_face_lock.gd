extends GutTest
## ShopScreen 公开面锁定守卫 —— 拆分重构前置护栏。
##
## [b]为什么需要这条守卫[/b]：[code]src/ui/shop/shop_screen.gd[/code]（415 行，全仓第二长）
## 要按职责拆成继承链。拆分唯一硬约束是「对外 API 逐位不变」——方法名、形参个数、
## 默认参数[b]与值[/b]、返回值类型、信号形参、实例字段、常量值、脚本路径，一个都不许改。
## 危险在于[b]编译器不会替我们发现断链[/b]：
##   · [code]src/feature/shop/shop_scene.tscn[/code] 的 [code]ext_resource[/code]
##     把脚本绑在 [code]res://src/ui/shop/shop_screen.gd[/code] 这一串字符上
##     （链尾文件名与路径逐字不动，见 [method test_entry_path_and_scene_reference_unchanged]）；
##   · 集成用例 [code]tests/integration/shop/test_shop_scene.gd[/code] 经
##     [code]ScreenScene.instantiate()[/code] 拿实例后[b]按名字[/b]注入
##     （[code]instance.set("scene_manager", …)[/code] /
##     [code]instance.set("shop_logic", …)[/code]），并按名调用
##     [code]item_count[/code] / [code]item_texts[/code] / [code]balance_text[/code] /
##     [code]message_text[/code] / [code]focused_index[/code] / [code]is_item_focused[/code] /
##     [code]is_item_enabled[/code] / [code]is_leave_focused[/code] /
##     [code]press_item[/code] / [code]press_leave[/code] / [code]_input[/code]；
##     [code]tests/integration/scene_manager/test_placeholder_scenes.gd[/code] 断言
##     [code]get_script().resource_path[/code] 与 [code]has_method("item_count")[/code]
##     / [code]has_method("refresh")[/code]；
##   · 三个协作模块按[b]实例[/b]接进来（[code]ShopPanelNavigator[/code] 的
##     [code]bind[/code]/[code]reset[/code]/[code]handle_event[/code]/[code]focus_index[/code]
##     由本屏经 [code]call(&"…")[/code] 按名分派），故「这些名字解析得到」也是契约。
##
## [b]本类的形态（拆分前四项实测）[/b]：[b]不是 Autoload[/b]（[code]project.godot[/code]
## 的 [code][autoload][/code] 里没有任何一项指向本文件——实测按串扫描命中 0 条）、
## [b]不带 [code]class_name[/code][/b]（[code]get_global_name()[/code] 为空）、
## [b]无 static 成员[/b]（全文 0 处 [code]static[/code]，静态形式取用全在
## [code]ShopPanelLayout[/code] 那一侧的既有模块里）、[b]无 [code]@onready[/code]
## 与 [code]%节点路径[/code][/b]（控件树在 [code]_init[/code] 里纯代码搭建，
## 引用由 [member _title_label] 等字段持有；全文唯一的 [code]%[/code] 是
## [constant TEXT_BALANCE] 里的格式化占位符）。继承链要承载的是「一个实例上解析
## 29 个方法、1 个信号、15 个字段、12 张常量」。[b]不锁[/b]函数体、注释、
## 成员落在哪个文件——那些正是拆分要动的东西。
##
## 来源: .claude/docs/coding-standards.md §文件行数限制（300 行软上限）、
## ADR-0031 §1/§2、design/ux/deck-editing-ui.md §坊市-买卡、
## 先例 tests/unit/formation_system/test_formation_public_face_lock.gd。

const ScreenScript := preload("res://src/ui/shop/shop_screen.gd")

## 入口路径——[code]shop_scene.tscn[/code] 按这一串字符挂脚本，逐字不变。
const EXPECTED_PATH: String = "res://src/ui/shop/shop_screen.gd"

## 宿主场景路径——链尾改名/挪目录会让这条 [code]ext_resource[/code] 断掉。
const EXPECTED_SCENE_PATH: String = "res://src/feature/shop/shop_scene.tscn"

## 原生基类——链尾必须仍是 [Control] 血统（场景根节点是 [Control]，
## 挂载时 [code]instantiate() as Control[/code] 才成立）。
const EXPECTED_NATIVE_BASE: StringName = &"Control"

## 全局类名——本类[b]不声明[/b] [code]class_name[/code]（场景脚本惯例，
## 取类一律走路径 [code]preload[/code]）。
const EXPECTED_GLOBAL_NAME: String = ""

## 方法快照——[code]{方法名: [形参个数, 默认参数类型表, 默认参数值表, 返回值类型]}[/code]。
## 返回值/默认参数类型都是 [enum Variant.Type] 的整数值（0 = NIL、1 = bool、
## 2 = int、4 = String、24 = Object、27 = Dictionary、28 = Array）。
## [b]本类 29 个方法一律无默认参数[/b]（探针实测 [code]default_args[/code] 全空）
## ——故「默认参数值」两栏是空表，一栏变空为不空即红。
const EXPECTED_METHODS: Dictionary = {
	# 构造与生命周期
	"_init": [0, [], [], 0],
	"_ready": [0, [], [], 0],
	"_exit_tree": [0, [], [], 0],
	# 对外：刷新入口 + 货架读数（集成用例按名调用）
	"refresh": [0, [], [], 0],
	"item_count": [0, [], [], 2],
	"item_texts": [0, [], [], 28],
	"is_item_enabled": [1, [], [], 1],
	"message_text": [0, [], [], 4],
	"balance_text": [0, [], [], 4],
	"focused_index": [0, [], [], 2],
	"is_item_focused": [1, [], [], 1],
	"is_leave_focused": [0, [], [], 1],
	"press_item": [1, [], [], 0],
	"press_leave": [0, [], [], 0],
	# 导航（_input 排在 GUI 派发之前——见类文档「事件层级 = _input」）
	"_input": [1, [], [], 0],
	"_on_focus_changed": [1, [], [], 0],
	# 购买路径
	"_on_row_pressed": [1, [], [], 0],
	"_on_row_gui_input": [3, [], [], 0],
	"_purchase": [1, [], [], 0],
	"_refusal_for": [1, [], [], 4],
	# 进出
	"_request_leave": [0, [], [], 0],
	# 控件树与上架
	"_build_layout": [0, [], [], 0],
	"_present": [2, [], [], 0],
	"_focus_fallback": [0, [], [], 0],
	"_clear_items": [0, [], [], 0],
	"_rows_of": [0, [], [], 28],
	"_activate_row": [1, [], [], 0],
	"_connect_templates_loaded": [0, [], [], 0],
	"_show_message": [1, [], [], 0],
}

## 信号快照——[code]{信号名: [形参名...]}[/code]。链上[b]恰好一条[/b]：
## [code]ShopPanelLayout.build[/code] 把「离开」按钮的 [signal Button.pressed]
## 转发到这个信号名上，本屏自己 [code]connect(_request_leave)[/code] 消费它。
const EXPECTED_SIGNALS: Dictionary = {
	"leave_requested": [],
}

## 实例字段快照——[code]{字段名: 类型整数值}[/code]。拆分后仍是[b]实例[/b]字段
## （不得因搬文件误写成 static），类型也不得变。
const EXPECTED_FIELDS: Dictionary = {
	"resource_system": 24, "card_system": 24, "gsm": 24, "scene_manager": 24,
	"shop_logic": 24, "_watch": 24, "_logic_": 24, "_navigator": 24,
	"_item_count": 2, "_row_to_goods": 28,
	"_title_label": 24, "_balance_label": 24, "_item_box": 24,
	"_message_label": 24, "_leave_button": 24,
}

## 面向玩家的词条快照——[code]{常量名: 值}[/code]。文案本地化豁免（项目暂无
## 本地化系统），故这里是本屏[s]唯一[/s]的措辞真理来源，逐字不得变。
const EXPECTED_TEXT_CONSTANTS: Dictionary = {
	"TEXT_TITLE": "🏪 坊市",
	"TEXT_EMPTY": "货架空空——坊市今日无货可售。",
	"TEXT_HINT": "↑ ↓ 选货，回车买入，Esc 或「离开」返回主菜单。",
	"TEXT_LEAVE_HAS_FOCUS": "按回车离开坊市。",
	"TEXT_BALANCE": "灵石：%d",
}

## 协作模块常量快照——[code]{常量名: 被 preload 的脚本路径}[/code]。
## 这七条是「本屏只调既有模块、一个字都不重造」的接缝，搬家不得顺手改路径。
const EXPECTED_SCRIPT_CONSTANTS: Dictionary = {
	"LayoutScript": "res://src/ui/exploration/shop_panel_layout.gd",
	"NavScript": "res://src/ui/exploration/shop_panel_navigator.gd",
	"LogicScript": "res://src/feature/shop/shop_logic.gd",
	"SourcesScript": "res://src/ui/hud/deck_view_sources.gd",
	"WatchScript": "res://src/ui/deck_editing/deck_editing_template_watch.gd",
	"SceneManagerScript": "res://src/foundation/scene_manager.gd",
	"ConsumeScript": "res://src/ui/shared/ui_input_consume.gd",
}

## 链上常量应恰好 12 张（7 协作模块 + 5 词条）——多了要显式更新本快照。
const EXPECTED_CONSTANT_COUNT: int = 12

## 买不起段的标记（[code]ShopPanelLayout.TEXT_UNAFFORDABLE[/code]）——行为用例断言用。
const TEXT_UNAFFORDABLE: String = "灵石不足"


# ═══════════════════════════════════════════════════════════════════════════════
# 链式反射工具——沿 [method Script.get_base_script] 合并整条继承链的面
# ═══════════════════════════════════════════════════════════════════════════════

## 走遍继承链收集脚本（链尾在前、首段在后——合并时后者覆盖前者，无重名故等价）。
func _chain() -> Array[Script]:
	var scripts: Array[Script] = []
	var cur: Script = ScreenScript as Script
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
## 自己的常量，祖先段声明的不在其中。
func _merged_constants() -> Dictionary:
	var merged: Dictionary = {}
	for sc: Script in _chain():
		var cm: Dictionary = sc.get_script_constant_map()
		for key: Variant in cm:
			merged[String(key)] = cm[key]
	return merged


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 方法面：29 个方法的形参个数 / 默认参数 / 返回值类型逐位不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_method_face_locked() -> void:
	assert_eq(EXPECTED_METHODS.size(), 29, "方法快照应 29 个")
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


func test_no_autoload_hook_introduced() -> void:
	# 本屏是场景脚本、[b]不是[/b] Autoload——拆段时若顺手补 _enter_tree /
	# _notification 这类钩子，会与「控件树在 _init 里搭好、_ready 只刷一次」
	# 的既有约定打架（集成用例按同一时序断言）。
	for hook: String in ["_enter_tree", "_notification", "_process", "_unhandled_input"]:
		assert_false(_merged_methods().has(hook),
				"不应新增 %s——本屏历史上没有这类钩子" % hook)


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 信号面：leave_requested 的名字与形参逐位不变，且链上恰好一条
# ═══════════════════════════════════════════════════════════════════════════════

func test_signal_face_locked() -> void:
	assert_eq(EXPECTED_SIGNALS.size(), 1, "信号快照应 1 条")
	var table: Dictionary = _merged_signals()
	assert_eq(table.size(), EXPECTED_SIGNALS.size(),
			"信号表应恰好 %d 条：%s" % [EXPECTED_SIGNALS.size(), str(table.keys())])
	for signal_name: String in EXPECTED_SIGNALS:
		assert_true(table.has(signal_name), "信号 %s 应存在" % signal_name)
		if not table.has(signal_name):
			continue
		assert_eq(table[signal_name], EXPECTED_SIGNALS[signal_name],
				"信号 %s 形参名应逐位不变" % signal_name)


func test_signal_connectable_on_instance() -> void:
	# 信号必须能在[b]实例[/b]上按名 connect——[code]ShopPanelLayout.build[/code]
	# 走 [method Object.emit_signal]（对未声明的信号名只在运行时静默失败，
	# 届时「离开」按钮点了没反应），故实例上解析得到才算数。
	var screen: Control = ScreenScript.new() as Control
	assert_not_null(screen, "本屏应可实例化")
	assert_true(screen.has_signal(&"leave_requested"),
			"实例上应能解析 leave_requested")
	screen.free()


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
	var a: Control = ScreenScript.new() as Control
	var b: Control = ScreenScript.new() as Control
	a.set("_item_count", 7)
	a.set("_row_to_goods", [3, 4])
	assert_eq(int(b.get("_item_count")), 0, "另一实例的 _item_count 应为默认 0")
	assert_eq((b.get("_row_to_goods") as Array).size(), 0,
			"另一实例的 _row_to_goods 应为默认空表")
	assert_eq(int(a.get("_item_count")), 7, "本实例的 _item_count 应已写入")
	a.free()
	b.free()


func test_default_state_locked() -> void:
	# 构造（[method _init]）之后的默认态：四个注入位全空 / 逻辑层与守望待建 /
	# 游标已就绪 / 行数为 0 / 五个控件引用已持有（控件树在 _init 里搭好）。
	var screen: Control = ScreenScript.new() as Control
	for slot: String in ["resource_system", "card_system", "gsm", "scene_manager",
			"shop_logic", "_watch", "_logic_"]:
		assert_null(screen.get(slot), "默认 %s 应为 null" % slot)
	assert_not_null(screen.get("_navigator"), "默认应已建出游标（_init 里 new）")
	assert_eq(int(screen.get("_item_count")), 0, "默认行数应为 0")
	assert_eq((screen.get("_row_to_goods") as Array).size(), 0, "默认行映射应为空")
	for control: String in ["_title_label", "_balance_label", "_item_box",
			"_message_label", "_leave_button"]:
		assert_not_null(screen.get(control), "默认应已持有控件 %s" % control)
	assert_eq(screen.item_count(), 0, "未上架时 item_count 应为 0")
	assert_eq(screen.item_texts().size(), 0, "未上架时无行控件")
	assert_eq(screen.focused_index(), -1, "未上架时游标应无落点")
	assert_eq(screen.balance_text(), "", "未上架时余额行应为空串")
	assert_eq(screen.message_text(), "", "提示行不可见时应返回空串")
	screen.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 常量面与入口契约：词条 / 协作模块路径 / resource_path / 场景引用 / 非 Autoload
# ═══════════════════════════════════════════════════════════════════════════════

func test_text_constants_locked() -> void:
	var consts: Dictionary = _merged_constants()
	for const_name: String in EXPECTED_TEXT_CONSTANTS:
		assert_true(consts.has(const_name), "常量 %s 应存在" % const_name)
		if not consts.has(const_name):
			continue
		assert_eq(String(consts[const_name]), String(EXPECTED_TEXT_CONSTANTS[const_name]),
				"词条常量 %s 应逐字不变" % const_name)


func test_script_constants_paths_locked() -> void:
	# 七条协作模块常量必须仍指向同一份既有模块——搬段时顺手改路径会让本屏
	# 悄悄换一套控件树 / 游标 / 结算实现。
	var consts: Dictionary = _merged_constants()
	for const_name: String in EXPECTED_SCRIPT_CONSTANTS:
		assert_true(consts.has(const_name), "常量 %s 应存在" % const_name)
		if not consts.has(const_name):
			continue
		var script: Script = consts[const_name] as Script
		assert_not_null(script, "%s 应是脚本常量" % const_name)
		if script == null:
			continue
		assert_eq(script.resource_path, String(EXPECTED_SCRIPT_CONSTANTS[const_name]),
				"常量 %s 指向的脚本路径应逐字不变" % const_name)


func test_no_untracked_constants() -> void:
	# 链上常量应恰好 12 张——多了/少了都要显式更新本快照。
	var consts: Dictionary = _merged_constants()
	assert_eq(consts.size(), EXPECTED_CONSTANT_COUNT,
			"链上常量应恰好 %d 张：%s" % [EXPECTED_CONSTANT_COUNT, str(consts.keys())])


func test_entry_path_and_scene_reference_unchanged() -> void:
	# 路径即契约：[code]shop_scene.tscn[/code] 按这一串字符挂脚本，
	# [code]test_placeholder_scenes.gd[/code] 也断言同一个 [code]resource_path[/code]。
	var script: Script = ScreenScript as Script
	assert_eq(script.resource_path, EXPECTED_PATH, "入口路径应逐字不变")
	assert_eq(script.get_instance_base_type(), EXPECTED_NATIVE_BASE,
			"原生基类应仍是 Control（[code]instantiate() as Control[/code] 前提）")
	assert_eq(String(script.get_global_name()), EXPECTED_GLOBAL_NAME,
			"不应新增 class_name——保持按路径取类这一条路")

	var packed: PackedScene = load(EXPECTED_SCENE_PATH)
	assert_not_null(packed, "宿主场景应能加载")
	var screen: Control = packed.instantiate() as Control
	assert_not_null(screen, "宿主场景应能实例化出 Control")
	if screen != null:
		assert_eq((screen.get_script() as Script).resource_path, EXPECTED_PATH,
				"场景挂的脚本应是本文件（链尾路径不得变）")
		screen.free()


func test_not_registered_as_autoload() -> void:
	# 本屏是[b]场景脚本[/b]不是 Autoload——实测 [code]project.godot[/code] 的
	# [code][autoload][/code] 里没有任何一项指向本文件。若哪天有人顺手加进去，
	# 「一个实例」的前提就变了（全局单例 + 场景实例并存），本用例红。
	var config := ConfigFile.new()
	assert_eq(config.load("res://project.godot"), OK, "project.godot 应能被加载")
	var hits: Array[String] = []
	for key: String in config.get_section_keys("autoload"):
		if String(config.get_value("autoload", key, "")).contains("shop_screen"):
			hits.append("%s=%s" % [key, String(config.get_value("autoload", key, ""))])
	assert_eq(hits.size(), 0, "本项目不应把 ShopScreen 注册成 Autoload：%s" % str(hits))


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 面仍然可用：挂进树 + 注入替身逻辑，真实跑通上架 / 读数 / 拒绝路径
# ═══════════════════════════════════════════════════════════════════════════════

## 定值逻辑替身——只提供界面用到的三个方法（[method ShopLogic] 的公开面）。
class StubLogic extends RefCounted:
	var _balance: int = 42
	var _rows: Array[Dictionary] = []

	func balance() -> int:
		return _balance

	func rows() -> Array[Dictionary]:
		return _rows

	func purchase(p_index: int) -> Dictionary:
		return {"ok": false, "reason": "替身拒绝 %d" % p_index, "name": "", "price": 0}


## 造一份两行货架：第 0 行买得起（可点），第 1 行买不起（[code]disabled[/code]）。
func _stub_with_rows() -> StubLogic:
	var logic := StubLogic.new()
	logic._rows = [
		{"index": 0, "name": "培元丹", "price": 10, "rarity": 1,
			"sold": false, "affordable": true},
		{"index": 1, "name": "回气散", "price": 99, "rarity": 2,
			"sold": false, "affordable": false},
	]
	return logic


func test_mounted_screen_still_presents_rows_and_reads_back() -> void:
	# Arrange——替身逻辑必须在进树前注入（[method _ready] 只在它为 null 时自建）
	var screen: Control = ScreenScript.new() as Control
	screen.set("shop_logic", _stub_with_rows())
	add_child_autofree(screen)
	# Assert——行数与替身给出的行数一致（不多不少），读数口逐条对上
	assert_eq(screen.item_count(), 2, "应有 2 行")
	assert_eq(screen.item_texts().size(), 2, "应有两个行控件")
	assert_true(String(screen.item_texts()[0]).contains("培元丹"),
			"首行文案应含卡名：%s" % str(screen.item_texts()[0]))
	assert_true(String(screen.item_texts()[1]).contains(TEXT_UNAFFORDABLE),
			"买不起的行应写明原因：%s" % str(screen.item_texts()[1]))
	assert_eq(screen.balance_text(), "灵石：42", "余额行应写替身给的余额")
	assert_true(screen.is_item_enabled(0), "买得起的行应可点")
	assert_false(screen.is_item_enabled(1), "买不起的行应禁用")
	assert_eq(screen.focused_index(), 0, "游标应落在首个可买行")
	assert_true(screen.is_item_focused(0), "首行应真的持有键盘焦点")


func test_disabled_row_press_still_explains_via_public_face() -> void:
	# 买不起的行点下去仍给中文原因（禁用行不发 pressed，故走 gui_input 那条路）。
	var screen: Control = ScreenScript.new() as Control
	screen.set("shop_logic", _stub_with_rows())
	add_child_autofree(screen)
	# Act——按第 1 行（禁用）
	screen.press_item(1)
	# Assert——提示行出现替身给的拒绝原因
	assert_true(String(screen.message_text()).contains("替身拒绝"),
			"禁用行应给出原因：%s" % str(screen.message_text()))


func test_press_leave_still_emits_leave_requested() -> void:
	# 「离开」的唯一出口是 [signal leave_requested]（本屏自己消费它去请求转场）。
	var screen: Control = ScreenScript.new() as Control
	screen.set("shop_logic", _stub_with_rows())
	add_child_autofree(screen)
	var got: Array[int] = []
	screen.leave_requested.connect(func() -> void: got.append(1))
	# Act
	screen.press_leave()
	# Assert——信号照旧发出（转场由 [method _request_leave] 负责，此处只钉信号本身）
	assert_eq(got.size(), 1, "按「离开」应发出一次 leave_requested")
