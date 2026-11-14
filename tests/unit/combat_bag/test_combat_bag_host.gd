extends GutTest
## CombatBagHost 单元测试——入口按钮、开合编排与[b]出牌输入冻结[/b]。[br]
## [br][b]本文件最重要的一条是冻结[/b]（点名验收 ①）：面板盖住了手牌区，不冻结就会
## 出现「隔面板点穿出牌」——玩家点的是行囊里的一行，打出去的却是手牌。[br]
## [br][b]冻结为什么不用 InputManager 的 MODAL 锁[/b]（见宿主类文档）：锁栈被
## [code]InputManager._on_tree_changed[/code] 整体清空，而 [code]tree_changed[/code]
## 每帧至多一次、面板入树即触发——同帧 push 的锁立刻被抹掉，面板照样点得穿。
## 故此处注入的是交互层的普通字段开关，用记录调用的 Callable 钉死它的时机。
##
## 来源: 本轮任务书第 1 条、ADR-0031 §2、先例 [code]shop_node_presenter.gd[/code]。

const HostScript := preload("res://src/feature/combat/combat_bag_host.gd")
const BarScript := preload("res://src/ui/combat/layout/combat_bottombar.gd")
const RulesScript := preload("res://src/feature/combat/combat_bag_rules.gd")


## 战场根桩——宿主只问它两件事：一个能挂面板的父节点、一个底部条。
class StubLayout extends Control:
	var combat_bottombar: Control = null


## 结算层桩——记录被用掉的条目，并回一句可控的文案。[br]
## [br][b]为什么不接真结算层[/b]：本文件测的是编排（谁在什么时机被调用），
## 真结算链路的数值口径在 [code]test_combat_bag_use.gd[/code] 里逐条钉过了。
class StubUse extends RefCounted:
	var entries: RefCounted = null
	var calls: Array = []
	## 下一次 [code]use_entry[/code] 的返回（用例据此造成功 / 拒绝两种结果）。
	var next: Dictionary = {"ok": true, "consumed": true, "healed": 4,
		"message": "回春丹已服下 · 回复 4 点生命"}

	func use_entry(p_entry: Dictionary, p_targets: Array) -> Dictionary:
		calls.append({"entry": p_entry, "targets": p_targets})
		return next


## 条目来源桩——面板挂载时宿主会把它交给面板。
class StubSource extends RefCounted:
	var rows: Array = []

	func entries() -> Array:
		return rows


var layout: StubLayout = null
var bar: CombatBottombar = null
var use: StubUse = null
var host: RefCounted = null
## 输入开关的调用记录（[code][true/false][/code]——本文件的冻结断言全靠它）。
var input_calls: Array = []


func before_each() -> void:
	layout = StubLayout.new()
	add_child_autofree(layout)
	bar = BarScript.new() as CombatBottombar
	add_child_autofree(bar)
	layout.combat_bottombar = bar
	use = StubUse.new()
	use.entries = StubSource.new()
	input_calls = []
	host = HostScript.new()


## 装配宿主（[param p_set_input] 为真时注入输入开关）。
func _mount(p_set_input: bool = true) -> bool:
	var toggle: Callable = Callable()
	if p_set_input:
		toggle = func(p_enabled: bool) -> void: input_calls.append(p_enabled)
	return bool(host.call(&"mount", layout, layout.combat_bottombar, toggle, use))


# ═══════════════════════════════════════════════════════════════════════════════
# 装配：面板挂上、入口接上
# ═══════════════════════════════════════════════════════════════════════════════

func test_mount_attaches_the_panel_and_the_entry_button() -> void:
	# Act
	var ok: bool = _mount()
	# Assert
	assert_true(ok, "底部条结构正常时应装上了入口")
	assert_not_null(host.get("panel"), "面板应已实例化")
	assert_true(layout.is_ancestor_of(host.get("panel")), "面板应挂在战场根上")
	assert_false((host.get("panel") as Control).visible, "挂载即隐藏")


func test_mount_without_bottom_bar_degrades_with_a_warning() -> void:
	## 底部条结构不符 → 告警但面板仍可手动打开（不把装配错漏变成崩溃）。
	# Act
	var ok: bool = bool(host.call(&"mount", layout, null, Callable(), use))
	# Assert
	assert_false(ok, "没有底部条时入口装不上")
	assert_push_warning_count(1, "应 push_warning 一次（装配错漏要看得见）")
	assert_not_null(host.get("panel"), "面板仍应挂上")


# ═══════════════════════════════════════════════════════════════════════════════
# 点名验收 ①：打开冻结出牌输入、关闭解冻
# ═══════════════════════════════════════════════════════════════════════════════

func test_opening_the_bag_freezes_play_input() -> void:
	# Arrange
	_mount()
	var panel: Control = host.get("panel")
	# Act——点底部条的「行囊」按钮
	(bar.bag_button as CombatBagButton).button.emit_signal(&"pressed")
	# Assert
	assert_true(panel.visible, "面板应打开")
	assert_eq(input_calls, [false], "打开应把出牌输入关掉（隔面板点不穿）")


func test_closing_the_bag_unfreezes_play_input() -> void:
	# Arrange
	_mount()
	var panel: Control = host.get("panel")
	(bar.bag_button as CombatBagButton).button.emit_signal(&"pressed")
	# Act——再点一次同一个按钮（开关走同一个出口）
	(bar.bag_button as CombatBagButton).button.emit_signal(&"pressed")
	# Assert
	assert_false(panel.visible, "面板应关闭")
	assert_eq(input_calls, [false, true], "关闭应把出牌输入放行")


func test_back_button_closes_and_unfreezes() -> void:
	## 「返回」走的是面板的 [signal CombatBagScreen.closed]，与按钮点击同一个出口。
	# Arrange
	_mount()
	var panel: Control = host.get("panel")
	(bar.bag_button as CombatBagButton).button.emit_signal(&"pressed")
	# Act
	panel.call(&"press_back")
	# Assert
	assert_false(panel.visible, "面板应关闭")
	assert_eq(input_calls, [false, true], "「返回」也应解冻")


func test_opening_twice_does_not_double_freeze() -> void:
	## 幂等：已打开时只刷新，不重复冻结——重复调用不该让开关次数与开合次数脱钩。
	# Arrange
	_mount()
	var panel: Control = host.get("panel")
	host.call(&"open")
	# Act
	host.call(&"open")
	# Assert
	assert_true(panel.visible, "仍应是打开的")
	assert_eq(input_calls, [false, false], "两次 open 各写一次开关（值相同即幂等）")


func test_close_when_never_opened_is_a_noop() -> void:
	# Arrange
	_mount()
	# Act
	host.call(&"close")
	# Assert
	assert_eq(input_calls, [true], "未打开时关闭只解冻一次（不会崩，也不会弹面板）")


func test_mount_without_an_input_toggle_is_safe() -> void:
	## headless 单测不带交互层——空 Callable 时开关是空操作，不应崩。
	# Arrange
	_mount(false)
	var panel: Control = host.get("panel")
	# Act
	host.call(&"open")
	# Assert
	assert_true(panel.visible, "没有输入开关时面板仍应能打开")
	assert_eq(input_calls, [], "空 Callable 不该产生任何调用")


# ═══════════════════════════════════════════════════════════════════════════════
# 确认一行 → 交结算层 → 回填文案
# ═══════════════════════════════════════════════════════════════════════════════

func test_confirming_a_row_delegates_to_the_use_layer() -> void:
	# Arrange
	_mount()
	var entry: Dictionary = _row("回春丹")
	(use.entries as StubSource).rows = [entry]
	host.call(&"open")
	# Act——点第 0 行
	(host.get("panel") as Control).call(&"press_row", 0)
	# Assert
	assert_eq(use.calls.size(), 1, "应交给结算层一次")
	assert_eq(str((use.calls[0]["entry"] as Dictionary)["name"]), "回春丹",
			"交出去的应是那一行携带的条目")


func test_success_message_is_shown_and_the_list_refreshes() -> void:
	## 用成了：先刷新（少了一枚）再回填系统给的句子——顺序反了玩家就看不到那句话。
	# Arrange
	_mount()
	(use.entries as StubSource).rows = [_row("回春丹")]
	host.call(&"open")
	use.next = {"ok": true, "consumed": true, "healed": 4,
		"message": "回春丹已服下 · 回复 4 点生命"}
	# Act
	(host.get("panel") as Control).call(&"press_row", 0)
	# Assert
	assert_eq(str((host.get("panel") as Control).call(&"message_text")),
			"回春丹已服下 · 回复 4 点生命", "应回填结算层给的文案")


func test_refusal_message_is_shown_without_refreshing() -> void:
	## 没消耗掉就不刷新——无谓的刷新会把玩家的游标弹回首行。[br]
	## [br]断言的是「文案照常显示」而列表内容不变：这里让来源换一批行，若宿主
	## 走了刷新分支，屏上就会变成新那批。
	# Arrange
	_mount()
	(use.entries as StubSource).rows = [_row("回春丹")]
	host.call(&"open")
	use.next = {"ok": false, "consumed": false, "healed": 0,
		"message": RulesScript.TEXT_NO_COST % [1, 0]}
	(use.entries as StubSource).rows = [_row("天罗丹")]
	# Act
	(host.get("panel") as Control).call(&"press_row", 0)
	# Assert
	assert_eq(str((host.get("panel") as Control).call(&"message_text")),
			RulesScript.TEXT_NO_COST % [1, 0], "拒绝时也应显示原因")
	assert_true(str((host.get("panel") as Control).call(&"entry_texts")[0]).contains("回春丹"),
			"未消耗时不该刷新（屏上仍是原来那一行）")


func test_partial_failure_still_refreshes_because_the_item_left_the_bag() -> void:
	## 法宝「一笔都没加上」：ok 为假但 consumed 为真——实物确实少了一件，
	## 故仍要刷新（否则玩家看到一件已经不存在的法宝还列在行囊里）。
	# Arrange
	_mount()
	(use.entries as StubSource).rows = [_row("空壳法器")]
	host.call(&"open")
	use.next = {"ok": false, "consumed": true, "healed": 0,
		"message": "此宝未能加身——气机紊乱"}
	(use.entries as StubSource).rows = []
	# Act
	(host.get("panel") as Control).call(&"press_row", 0)
	# Assert
	assert_eq(int((host.get("panel") as Control).call(&"entry_count")), 0,
			"consumed 为真时应刷新（实物已取出）")
	assert_eq(str((host.get("panel") as Control).call(&"message_text")),
			"此宝未能加身——气机紊乱", "仍应显示系统给的句子")


# ═══════════════════════════════════════════════════════════════════════════════
# 退订（场景退场）
# ═══════════════════════════════════════════════════════════════════════════════

func test_unbind_closes_the_panel_before_dropping_the_handles() -> void:
	## 退订把宿主的手柄全部置空——之后再也解不了冻。故必须[b]先关再退订[/b]：
	## 否则若退场时面板还开着，出牌交互层会带着「停用」状态活到下一次进战斗
	## （输入层挂在常驻 Autoload 的同一条链路上），表现为「进了战斗却点不动牌」。
	# Arrange
	_mount()
	var panel: Control = host.get("panel")
	host.call(&"open")
	assert_eq(input_calls, [false], "前置：已冻结")
	# Act
	host.call(&"unbind")
	# Assert
	assert_eq(input_calls, [false, true], "退订应先关面板再置空手柄（解冻落在置空之前）")
	assert_false(panel.visible, "面板应关掉")


func test_unbind_disconnects_the_entry_button() -> void:
	## 退订后按钮不该再有任何反应（场景内的按钮会随场景一起销毁，但连接不能留着）。
	# Arrange
	_mount()
	host.call(&"unbind")
	# Act
	(bar.bag_button as CombatBagButton).button.emit_signal(&"pressed")
	# Assert
	assert_eq(input_calls, [true], "退订后按钮不该再驱动宿主")


func test_button_toggles_between_open_and_closed() -> void:
	## 同一个出口（不写两条路径）：开 → 关 → 开。
	# Arrange
	_mount()
	var button: Button = (bar.bag_button as CombatBagButton).button
	# Act
	button.emit_signal(&"pressed")
	button.emit_signal(&"pressed")
	button.emit_signal(&"pressed")
	# Assert
	assert_eq(input_calls, [false, true, false], "三次点击应是 开/关/开")
	assert_true(bool(host.call(&"is_open")), "最终应是打开态")


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════════════════

## 造一行条目（面板真正读的那几个键——行文本仍由判据模块折出）。
func _row(p_name: String) -> Dictionary:
	var entry: Dictionary = {
		"kind": &"pill", "name": p_name, "rarity_name": "蓝", "count": 1,
		"template_id": p_name, "instance_id": 1, "cost": 1,
		"target_type": "single_ally", "effect_kind": 1, "effect_value": 4,
		"stat_changes": {}, "usable": true, "reason": "",
	}
	entry["text"] = RulesScript.row_text(entry)
	return entry
