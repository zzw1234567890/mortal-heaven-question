extends GutTest
## SettlementPanel 公开面锁定守卫——拆分重构前置护栏。
##
## [b]为什么需要这条守卫[/b]：[code]src/ui/combat/settlement/settlement_panel.gd[/code]（350 行）
## 要按职责拆成继承链。拆分的唯一硬约束是「对外 API 逐位不变」——方法名、形参个数、
## 默认参数个数[b]与值[/b]、返回值类型、信号、实例字段，一个都不许改。危险在于
## [b]编译器不会替我们发现断链[/b]：
##   · 外部按[b]路径[/b]取这个类（[code]settlement_host_panels.gd[/code] 的
##     [code]PanelScript.new()[/code]、三个集成测试的 preload）；
##   · [code]settlement_host.gd[/code] 把面板存在 [code]Control[/code] 类型的
##     [code]settlement_panel[/code] 字段上，按名直呼 [code]show_victory[/code] /
##     [code]show_defeat[/code] / [code]show_grant_summary[/code]——[b]按名动态分派[/b]，
##     名字打错或漏拆只是运行时 [code]push_error[/code]，不报语法错；
##   · 测试直接读 [code]confirm_button[/code] / [code]reward_lines_label[/code] /
##     [code]loot_delay_timer[/code] 等控件字段。
##
## [b]与前几轮（[code]combat_system[/code] / [code]binding_manager[/code] /
## [code]gsm_atomic_writes[/code]）的形态差异[/b]：本类[b]有 [code]class_name[/code]
## 且是 [Control] 子类[/b]，且[b]构造期就按名接线[/b]（[code]_build()[/code] 里
## [code]confirm_button.pressed.connect(_on_confirm_pressed)[/code] 等三处），故本用例
## 除了锁面，还额外锁[b]四个按名接线的回调名[/b]（拆段时祖先段引用不到后代段的方法会
## 直接解析错）。
##
## [b]锁什么[/b]：
##   · 21 个方法（[method _init] / [method _build] / 三块面板入口 / 八个查询 / 八个私有）
##     的[形参个数 / 默认参数个数 / 默认参数值 / 返回值类型]
##   · 5 个信号的名字与形参名（[code]loot_selected[/code] / [code]loot_confirmed[/code] /
##     [code]loot_skipped[/code] / [code]defeat_confirmed[/code] / [code]closed[/code]）
##   · 20 个实例字段存在、类型不变、且[b]未被 static 化[/b]（两个实例互不影响）
##   · 三个尺寸常量与四个 preload 常量在册且值不变
##   · [code]resource_path[/code] / [code]class_name[/code] / 原生基类逐字不变
##   · 构造默认态与 [method _build] 的接线成果（控件句柄全非 null）
##   · 面内不得出现未登记的方法 / 信号 / 字段（新增或改名都要显式更新本快照）
##
## [b]怎么锁「整条继承链的面」[/b]：反射沿 [method Script.get_base_script] 走遍全链再合并
## ——拆分前链长 1（单文件），拆分后链长 N，两种形态下合并结果必须逐位相同。[b]不锁[/b]
## 函数体实现、注释、成员落在哪个文件——这些正是拆分要动的东西。
##
## 来源: .claude/docs/coding-standards.md §文件行数限制（300 行软上限）、
## ADR-0031（结算面板零状态所有权 / 零轮询 / 不自动关闭）、
## combat-ui-layout Story 008（AC-1~AC-5/AC-10）、DEBT-CUI-008-3。

const PANEL_SCRIPT := preload("res://src/ui/combat/settlement/settlement_panel.gd")
const RULES := preload("res://src/ui/combat/shared/settlement_rules.gd")

## 入口路径——外部按这一串字符 load，逐字不变。
const EXPECTED_PATH: String = "res://src/ui/combat/settlement/settlement_panel.gd"

## 全局类名——文档与调用侧按此名引用，拆到哪个文件都得留着它。
const EXPECTED_GLOBAL_NAME: StringName = &"SettlementPanel"

## 方法快照——[code]{方法名: [形参个数, [默认参数值...], 返回值类型]}[/code]，按反射实测登记。
## 返回值类型是 [enum Variant.Type] 的整数值（0 = NIL/void、1 = bool、2 = int、
## 3 = float、5 = Vector2、21 = StringName、24 = Object、27 = Dictionary、28 = Array）。
const EXPECTED_METHODS: Dictionary = {
	# 构造与装配（私有，但被引擎与自身按名调用）
	"_init": [0, [], 0],
	"_build": [0, [], 0],
	"_notification": [1, [], 0],
	# 三块面板入口（宿主按名直呼——公开面）
	"show_victory": [4, [null], 0],
	"show_defeat": [1, [], 0],
	"show_grant_summary": [1, [], 0],
	# 关闭与查询（测试与宿主按名直呼）
	"close_panel": [0, [], 0],
	"is_open": [0, [], 1],
	"get_kind": [0, [], 21],
	"get_cards": [0, [], 28],
	"get_selected_index": [0, [], 2],
	"is_loot_clickable": [0, [], 1],
	"get_loot_cell_width": [0, [], 3],
	"is_showing_grant_summary": [0, [], 1],
	"get_frame_size": [0, [], 5],
	# 内部（[method _build] 按名接线 + 卡片 / 计时器回调）
	"_on_loot_delay_timeout": [0, [], 0],
	"_rebuild_loot_cards": [2, [], 0],
	"_on_option_pressed": [1, [], 0],
	"_on_confirm_pressed": [0, [], 0],
	"_on_skip_pressed": [0, [], 0],
	"_clear_loot_cards": [0, [], 0],
}

## [method _build] 按名接线的四个回调——这四个名字必须仍在整条链上可按名解析。
const EXPECTED_WIRED_CALLBACKS: Array[String] = [
	"_on_confirm_pressed", "_on_skip_pressed", "_on_loot_delay_timeout",
	"_on_option_pressed",
]

## 信号快照——[code]{信号名: [形参名...]}[/code]。
const EXPECTED_SIGNALS: Dictionary = {
	"loot_selected": ["option_index"],
	"loot_confirmed": ["option_index"],
	"loot_skipped": [],
	"defeat_confirmed": [],
	"closed": [],
}

## 实例字段快照——[code]{字段名: 类型整数值}[/code]。拆分后仍是[b]实例[/b]字段
## （不得因搬文件误写成 static），类型也不得变（[Control] 句柄仍挂 24 = Object）。
const EXPECTED_FIELDS: Dictionary = {
	"kind": 21, "loot_options": 28, "selected_index": 2, "loot_ready": 1,
	"_elapsed_sec": 3, "reduce_motion": 1,
	"loot_delay_timer": 24, "title_label": 24, "hint_label": 24, "body_box": 24,
	"loot_grid": 24, "confirm_button": 24, "skip_button": 24,
	"defeat_lines_label": 24, "reward_lines_label": 24, "pick_title_label": 24,
	"frame": 24, "_cards": 28, "_parts": 27, "_fade": 24,
}

## 常量快照——三个面板尺寸值（px，1920×1080 基准）。
const EXPECTED_SIZE_CONSTANTS: Dictionary = {
	"PANEL_WIDTH": 720.0,
	"VICTORY_PANEL_HEIGHT": 520.0,
	"DEFEAT_PANEL_HEIGHT": 320.0,
}

## preload 常量（拆到哪一段都得在链上任一处解析得到——方法体全靠它们取值）。
const EXPECTED_PRELOAD_CONSTANTS: Array[String] = ["Rules", "View", "Frame", "Fade"]

var panel: Control = null


func before_each() -> void:
	panel = PANEL_SCRIPT.new()
	# 入树（与既有集成测试同一处置）：[method show_victory] 会 [code]loot_delay_timer.start()[/code]，
	# 未入树的 Timer 起不来（引擎报 !is_inside_tree）；动画则靠 reduce_motion 直跳终态。
	add_child_autofree(panel)
	panel.reduce_motion = true


func after_each() -> void:
	# [method show_grant_summary] 走 [code]View.clear_grid[/code]（remove_child + queue_free
	# ——延迟释放），推进一帧让队列走完，否则行容器会以孤儿形式挂到本用例账上。
	if panel != null:
		await get_tree().process_frame
	panel = null  # 释放交给 add_child_autofree


# ═══════════════════════════════════════════════════════════════════════════════
# 链式反射工具——沿 [method Script.get_base_script] 合并整条继承链的面
# ═══════════════════════════════════════════════════════════════════════════════

## 走遍继承链收集脚本（链尾在前、首段在后——合并时后者覆盖前者，无重名故等价）。
func _chain() -> Array[Script]:
	var scripts: Array[Script] = []
	var cur: Script = PANEL_SCRIPT as Script
	while cur != null:
		scripts.append(cur)
		cur = cur.get_base_script()
	return scripts


## 合并全链方法表——[code]{方法名: {args, default_args, return}}[/code]。
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
# 1. 方法面：21 个方法的形参个数 / 默认参数 / 返回值类型逐位不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_method_face_locked() -> void:
	assert_eq(EXPECTED_METHODS.size(), 21, "方法快照应 21 个")
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
		var want_defaults: Array = expected[1]
		assert_eq(args.size(), int(expected[0]),
			"方法 %s 形参个数应不变" % method_name)
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


func test_scripted_callbacks_reachable_by_name() -> void:
	# [method _build] 里三处 connect 与本类内部按名调用的回调——拆段时祖先段引用不到
	# 后代段的方法会直接解析错，故这四个名字必须在整条链上可按名解析。
	var missing: Array[String] = []
	for method_name: String in EXPECTED_WIRED_CALLBACKS:
		if not panel.has_method(method_name):
			missing.append(method_name)
	assert_eq(missing.size(), 0, "按名接线的回调应全部可按名解析，缺失：%s" % str(missing))


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
	# 信号必须能在[b]实例[/b]上按名 connect（宿主走 [code]node.connect(&"closed", ...)[/code]，
	# 信号若被搬丢或改名，这里立刻变红）。
	for signal_name: String in EXPECTED_SIGNALS:
		assert_true(panel.has_signal(signal_name),
			"实例上应能解析信号 %s" % signal_name)


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 字段面：20 个实例字段在册、类型不变，且仍是实例字段
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
	var other: Control = PANEL_SCRIPT.new()
	panel.set("kind", RULES.KIND_VICTORY)
	panel.set("selected_index", 2)
	assert_eq(other.get("kind"), RULES.KIND_NONE, "另一实例的 kind 不受影响")
	assert_eq(int(other.get("selected_index")), -1, "另一实例的 selected_index 不受影响")
	other.free()


func test_default_state_locked() -> void:
	# 构造后的默认态（宿主与测试都依赖）：未打开 / 未选中 / 未到点 / 隐藏。
	assert_eq(panel.get_kind(), RULES.KIND_NONE, "默认应为未打开")
	assert_false(panel.is_open(), "默认 is_open 应为 false")
	assert_eq(panel.get_selected_index(), -1, "默认应未选中")
	assert_false(panel.is_loot_clickable(), "默认应未到 0.5s")
	assert_false(panel.visible, "默认应隐藏")
	assert_true(panel.loot_options.is_empty(), "默认战利品选项应为空")
	assert_true(panel.get_cards().is_empty(), "默认战利品卡应为空")
	assert_false(panel.is_showing_grant_summary(), "未打开时不应是汇总视图")


func test_build_wired_controls() -> void:
	# [method _init] → [method _build] 的接线成果：控件与计时器字段全部就位。
	# 拆段时若把 [method _build] 与控件字段分到两处、又漏了某条赋值，这里立刻变红。
	assert_not_null(panel.title_label, "标题标签应建好")
	assert_not_null(panel.hint_label, "提示标签应建好")
	assert_not_null(panel.body_box, "内容容器应建好")
	assert_not_null(panel.loot_grid, "战利品网格应建好")
	assert_not_null(panel.confirm_button, "确认按钮应建好")
	assert_not_null(panel.skip_button, "跳过按钮应建好")
	assert_not_null(panel.defeat_lines_label, "战败摘要标签应建好")
	assert_not_null(panel.reward_lines_label, "奖励汇总标签应建好")
	assert_not_null(panel.pick_title_label, "选择段标题应建好")
	assert_not_null(panel.frame, "外框应建好")
	assert_not_null(panel.loot_delay_timer, "0.5s 延迟计时器应建好")
	assert_not_null(panel.get("_fade"), "开合动画驱动应建好")
	assert_true(panel.loot_delay_timer.one_shot, "延迟计时器应为一次性")
	assert_eq(panel.loot_delay_timer.wait_time, RULES.LOOT_CLICK_DELAY_SEC,
		"延迟时长应取自内核常量（0.5s 语义不在面板内重写）")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 常量与入口契约：尺寸常量、preload 常量、resource_path、class_name
# ═══════════════════════════════════════════════════════════════════════════════

func test_constants_locked() -> void:
	var consts: Dictionary = _merged_constants()
	for const_name: String in EXPECTED_SIZE_CONSTANTS:
		assert_true(consts.has(const_name), "常量 %s 应存在" % const_name)
		if not consts.has(const_name):
			continue
		assert_eq(float(consts[const_name]), float(EXPECTED_SIZE_CONSTANTS[const_name]),
			"常量 %s 值应不变" % const_name)
	for const_name: String in EXPECTED_PRELOAD_CONSTANTS:
		assert_true(consts.has(const_name), "preload 常量 %s 应存在" % const_name)


func test_entry_path_and_class_name_unchanged() -> void:
	# 外部按这一串字符 load、按全局名引用——两者都是契约。
	assert_eq((PANEL_SCRIPT as Script).resource_path, EXPECTED_PATH,
		"入口路径应逐字不变")
	assert_eq((PANEL_SCRIPT as Script).get_global_name(), EXPECTED_GLOBAL_NAME,
		"class_name 应保留")
	assert_eq((PANEL_SCRIPT as Script).get_instance_base_type(), &"Control",
		"原生基类应仍是 Control")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 面仍然可用：走一趟三类面板（真实调用，非只看反射表）
# ═══════════════════════════════════════════════════════════════════════════════

func test_face_still_works_end_to_end() -> void:
	var options: Array = [
		{"kind": RULES.OPTION_KIND_CARD, "name": "青云剑诀", "rarity": "蓝",
				"school": "功法"},
		{"kind": RULES.OPTION_KIND_LINGSHI, "amount": 25},
	]
	panel.show_victory(options, 5, 20, ["灵石 +10"])
	assert_eq(panel.get_kind(), RULES.KIND_VICTORY, "胜利面板应打开")
	assert_true(panel.is_open(), "is_open 应为 true")
	assert_eq(panel.get_cards().size(), 2, "两张选项卡应建好")
	assert_true(panel.confirm_button.disabled, "未选中时应不可确认")
	assert_true(panel.get_loot_cell_width() > 0.0, "卡片等宽值应为正")

	# 0.5s 到点（确定性接缝——非真实等待）后仍不可确认（仍未选中）
	panel.loot_delay_timer.timeout.emit()
	assert_true(panel.is_loot_clickable(), "到点后应可点")
	assert_true(panel.confirm_button.disabled, "到点但未选中仍不可确认")

	# 选中一张后确认按钮解禁（选中态是瞬态交互状态，ADR-0031 §2.1 豁免）
	(panel.get_cards()[0] as Object).emit_signal(&"pressed", 0)
	assert_eq(panel.get_selected_index(), 0, "应记下选中下标")
	assert_false(panel.confirm_button.disabled, "选中且到点后应可确认")

	# 关闭出口（唯一关闭入口，幂等）
	var closed_hits: Array[int] = []
	panel.closed.connect(func() -> void: closed_hits.append(1))
	panel.close_panel()
	assert_eq(closed_hits.size(), 1, "close_panel 应发 closed")
	assert_eq(panel.get_kind(), RULES.KIND_NONE, "关闭后应回到未打开")
	panel.close_panel()
	assert_eq(closed_hits.size(), 1, "重复关闭应幂等（不重复发信号）")

	# 战败面板
	panel.show_defeat({"cultivation_lost": 12, "dead_names": ["林渊"],
			"binding_card_count": 1})
	assert_eq(panel.get_kind(), RULES.KIND_DEFEAT, "战败面板应打开")
	assert_true(panel.defeat_lines_label.visible, "战败摘要应可见")
	assert_false(panel.skip_button.visible, "战败面板不应有跳过按钮")
	assert_false(panel.get_frame_size() == Vector2.ZERO, "外框应有尺寸")


func test_grant_summary_face_still_works() -> void:
	# 「已到账汇总」视图：网格清空 + 选择段标题与跳过按钮一并隐藏（DEBT-CUI-008-3）。
	var options: Array = [
		{"kind": RULES.OPTION_KIND_CARD, "name": "青云剑诀", "rarity": "蓝",
				"school": "功法"},
		{"kind": RULES.OPTION_KIND_LINGSHI, "amount": 25},
	]
	panel.show_victory(options, 5, 20, ["灵石 +10"])
	assert_false(panel.is_showing_grant_summary(), "选择前不应是汇总视图")

	panel.show_grant_summary(["灵石 +10"])
	assert_true(panel.is_showing_grant_summary(), "应切到已到账汇总视图")
	assert_true(panel.get_cards().is_empty(), "汇总视图不应有选项卡")
	assert_false(panel.skip_button.visible, "汇总视图不应有跳过按钮")
	assert_false(panel.pick_title_label.visible, "汇总视图不应有选择段标题")
	assert_eq(panel.get_selected_index(), -1, "汇总视图应清空选中下标")
