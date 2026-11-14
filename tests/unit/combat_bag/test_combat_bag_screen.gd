extends GutTest
## CombatBagScreen 单元测试——面板本身的渲染与意图出口（不接任何系统）。[br]
## [br][b]为什么能脱离 Autoload 单测[/b]：面板只认「条目来源」这个鸭子类型契约
## （[code]entries()[/code] / [code]targets(for_pill)[/code]），取数全在注入的那一侧。
## 故这里用一个两方法的桩就能把渲染、游标、目标选择、意图出口逐条钉死。[br]
## [br][b]面板的职责边界[/b]：发意图不调系统（ADR-0031 §2）——本文件断言的是
## [signal CombatBagScreen.entry_use_requested] 的载荷，而不是任何状态变化。[br]
## [br]来源: 本轮任务书第 1 条（打开能列出条目）/ 第 4 条（空行囊显示空态文案）、
## ADR-0031 §2/§4、.claude/rules/ui-code.md。

const ScreenScript := preload("res://src/ui/combat/bag/combat_bag_screen.gd")
const LayoutScript := preload("res://src/ui/combat/bag/combat_bag_layout.gd")
const RulesScript := preload("res://src/feature/combat/combat_bag_rules.gd")

const TEXT_TITLE: String = "行囊"


## 条目来源桩——面板要的两件事：条目列与按种类分的候选池。
class StubSource extends RefCounted:
	var rows: Array = []
	var pill_targets: Array = []
	var artifact_targets: Array = []
	## [code]targets()[/code] 的调用记录（断言「每次现问来源、不缓存」用）。
	var target_calls: Array = []

	func entries() -> Array:
		return rows

	func targets(p_for_pill: bool) -> Array:
		target_calls.append(p_for_pill)
		return pill_targets if p_for_pill else artifact_targets


var screen: Control = null
var source: StubSource = null
var used: Array = []
var closes: int = 0


func before_each() -> void:
	source = StubSource.new()
	screen = ScreenScript.new()
	screen.set_entries_source(source)
	add_child_autofree(screen)
	used = []
	closes = 0
	screen.connect(&"entry_use_requested",
			func(p_entry: Dictionary, p_targets: Array) -> void:
				used.append({"entry": p_entry, "targets": p_targets}))
	screen.connect(&"closed", func() -> void: closes += 1)


# ═══════════════════════════════════════════════════════════════════════════════
# 开合：默认隐藏，由宿主 open() 才显示
# ═══════════════════════════════════════════════════════════════════════════════

func test_screen_starts_hidden() -> void:
	## 挂载即隐藏——面板何时出现由宿主决定（同一时刻要冻结出牌输入）。
	assert_false(screen.visible, "构造后应不可见")
	assert_false(bool(screen.call(&"is_open")), "is_open 应如实回报")


func test_open_refreshes_and_close_hides() -> void:
	# Arrange——一条可用丹药 + 一个候选
	source.rows = [_row("回春丹", true, 1)]
	source.pill_targets = [_target(601)]
	# Act
	screen.call(&"open")
	# Assert
	assert_true(screen.visible, "open() 后应可见")
	assert_true(bool(screen.call(&"is_open")), "is_open 应为真")
	assert_eq(int(screen.call(&"entry_count")), 1, "应渲染出一条条目")
	# Act
	screen.call(&"close")
	# Assert
	assert_false(screen.visible, "close() 后应隐藏")
	assert_false(bool(screen.call(&"is_open")), "is_open 应为假")


func test_reopen_rereads_the_source() -> void:
	## 每次打开都现读（零缓存）：关闭期间玩家可能刚打完一场、用掉一枚丹。[br]
	## [br]这条断言的是「面板不会把上一次的条目留在屏上」——陈旧的行比空屏更危险。
	# Arrange
	source.rows = [_row("回春丹", true, 1)]
	screen.call(&"open")
	assert_eq(int(screen.call(&"entry_count")), 1, "前置：先有一条")
	# Act——来源变了，重开
	source.rows = []
	screen.call(&"open")
	# Assert
	assert_eq(int(screen.call(&"entry_count")), 0, "重开应读到新的空列")


# ═══════════════════════════════════════════════════════════════════════════════
# 点名验收 ⑤：空行囊显示空态文案
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_bag_shows_the_empty_state_text() -> void:
	# Arrange——来源在，但一条都没有
	source.rows = []
	# Act
	screen.call(&"open")
	# Assert
	assert_eq(int(screen.call(&"entry_count")), 0, "空行囊不该有行")
	assert_eq(str(screen.call(&"message_text")), RulesScript.TEXT_EMPTY,
			"应显示空态文案（句子归判据模块，面板不自行措辞）")
	assert_eq(str(screen.call(&"target_text")),
			LayoutScript.TEXT_TARGET_PREFIX + LayoutScript.TEXT_TARGET_NONE,
			"无行时目标栏应显示「无」（不写「角色 -1」这种假信息）")


func test_missing_source_is_reported_differently_from_empty() -> void:
	## 「链路没接上」与「行囊是空的」是两件事——混在一句里会误导排查。
	# Arrange——不注入来源
	var bare: Control = ScreenScript.new()
	add_child_autofree(bare)
	# Act
	bare.call(&"open")
	# Assert
	assert_eq(str(bare.call(&"message_text")), str(ScreenScript.TEXT_UNAVAILABLE),
			"来源缺失应报「读取链路未就绪」")
	assert_ne(str(ScreenScript.TEXT_UNAVAILABLE), RulesScript.TEXT_EMPTY,
			"两句文案必须不同（否则排查时看不出是哪种情况）")


func test_hint_replaces_the_empty_text_when_rows_exist() -> void:
	# Arrange
	source.rows = [_row("回春丹", true, 1)]
	source.pill_targets = [_target(601)]
	# Act
	screen.call(&"open")
	# Assert
	assert_eq(str(screen.call(&"message_text")), str(ScreenScript.TEXT_HINT),
			"有行时应显示操作提示")


# ═══════════════════════════════════════════════════════════════════════════════
# 渲染：不可用行灰显且写进文本
# ═══════════════════════════════════════════════════════════════════════════════

func test_unusable_row_is_disabled_and_carries_the_reason() -> void:
	# Arrange——一条灵力不足的丹
	source.rows = [_row("回春丹", false, 1, RulesScript.TEXT_NO_COST % [1, 0])]
	source.pill_targets = [_target(601)]
	# Act
	screen.call(&"open")
	# Assert
	assert_true(bool(screen.call(&"is_row_disabled", 0)), "不可用行应 disabled")
	var texts: Array = screen.call(&"entry_texts")
	assert_true(str(texts[0]).contains("灵力不足"),
			"原因应写进行文本（色盲可读）：%s" % str(texts[0]))


func test_usable_row_is_not_disabled() -> void:
	# Arrange
	source.rows = [_row("回春丹", true, 1)]
	source.pill_targets = [_target(601)]
	# Act
	screen.call(&"open")
	# Assert
	assert_false(bool(screen.call(&"is_row_disabled", 0)), "可用行不该 disabled")


func test_cursor_skips_disabled_rows_and_lands_on_the_usable_one() -> void:
	## 游标判据就是 [code]disabled[/code]——用不了的条目在键盘路径上也点不到。
	# Arrange——首行不可用，次行可用
	source.rows = [
		_row("九转金丹", false, 1, RulesScript.TEXT_PILL_UNKNOWN),
		_row("回春丹", true, 1),
	]
	source.pill_targets = [_target(601)]
	# Act
	screen.call(&"open")
	# Assert
	assert_eq(int(screen.call(&"focused_index")), 1, "游标应跳过禁用行落到第 2 行")
	assert_true(bool(screen.call(&"is_row_focused", 1)), "第 2 行应真的持有键盘焦点")


# ═══════════════════════════════════════════════════════════════════════════════
# 目标：候选池跟着当前行走，可显式选择
# ═══════════════════════════════════════════════════════════════════════════════

func test_target_bar_shows_the_first_candidate_and_cycles() -> void:
	# Arrange——两个候选
	source.rows = [_row("回春丹", true, 1)]
	source.pill_targets = [_target(601), _target(602)]
	# Act
	screen.call(&"open")
	# Assert——默认落在 ID 最小的那一位
	assert_true(str(screen.call(&"target_text")).contains("601"),
			"目标栏默认应显示 601：%s" % str(screen.call(&"target_text")))
	assert_eq(screen.call(&"selected_target_ids"), [601], "默认选中的应是 601")
	# Act——点目标栏切到下一个
	screen.call(&"press_target")
	# Assert
	assert_true(str(screen.call(&"target_text")).contains("602"), "切换后应显示 602")
	assert_eq(screen.call(&"selected_target_ids"), [602], "选中的应随之变成 602")


func test_target_cycle_wraps_around() -> void:
	## 候选只有几个人，到头绕回来比卡住更好用。
	# Arrange
	source.rows = [_row("回春丹", true, 1)]
	source.pill_targets = [_target(601), _target(602)]
	screen.call(&"open")
	# Act——切两次回到原点
	screen.call(&"press_target")
	screen.call(&"press_target")
	# Assert
	assert_eq(screen.call(&"selected_target_ids"), [601], "切两次应绕回 601")


func test_all_allies_row_selects_every_candidate() -> void:
	## 全体效果没有「换一个」的语义——目标栏显示人数、方向键不改下标。
	# Arrange
	source.rows = [_row("天罗丹", true, 2, "", "all_allies")]
	source.pill_targets = [_target(601), _target(602)]
	# Act
	screen.call(&"open")
	# Assert
	assert_true(str(screen.call(&"target_text")).contains("全体"),
			"全体效果的目标栏应显示全体：%s" % str(screen.call(&"target_text")))
	assert_eq(screen.call(&"selected_target_ids"), [601, 602],
			"全体效果应选中全部候选")
	assert_false(str(screen.call(&"target_text")).contains("切换"),
			"全体效果不该带「← → 切换」提示")


func test_no_candidate_shows_none_and_selects_nothing() -> void:
	# Arrange——丹药无人缺血
	source.rows = [_row("回春丹", false, 1, RulesScript.TEXT_NOBODY_NEEDS)]
	source.pill_targets = []
	# Act
	screen.call(&"open")
	# Assert
	assert_eq(str(screen.call(&"target_text")),
			LayoutScript.TEXT_TARGET_PREFIX + LayoutScript.TEXT_TARGET_NONE,
			"无候选时目标栏应显示「无」")
	assert_eq(screen.call(&"selected_target_ids"), [], "无候选时不该选中任何人")


func test_artifact_row_asks_for_the_non_pill_pool() -> void:
	## 丹与宝的候选池不同（丹药只列有缺口者）——面板按当前行的种类现问。
	# Arrange
	source.rows = [_row("基础法器", true, 1, "", "single_ally", RulesScript.KIND_ARTIFACT)]
	source.artifact_targets = [_target(601), _target(602), _target(603)]
	# Act
	screen.call(&"open")
	# Assert
	assert_eq(source.target_calls, [false], "法宝行应问非丹药的候选池")
	assert_true(str(screen.call(&"target_text")).contains("601"), "应显示首个候选")


# ═══════════════════════════════════════════════════════════════════════════════
# 意图出口：按行 → 发意图（不调系统）
# ═══════════════════════════════════════════════════════════════════════════════

func test_pressing_a_row_emits_the_intent_with_entry_and_target() -> void:
	# Arrange
	source.rows = [_row("回春丹", true, 1)]
	source.pill_targets = [_target(602), _target(601)]
	screen.call(&"open")
	screen.call(&"press_target")  # 切到 601
	# Act
	screen.call(&"press_row", 0)
	# Assert
	assert_eq(used.size(), 1, "应按下一行发一次意图")
	assert_eq(str((used[0]["entry"] as Dictionary)["name"]), "回春丹",
			"意图应带上那一行携带的条目")
	assert_eq(used[0]["targets"], [601], "意图应带上玩家显式选定的目标")


func test_activating_a_disabled_row_emits_nothing() -> void:
	## 禁用行不发意图——与鼠标点击被 [code]disabled[/code] 拦住同口径。
	# Arrange——唯一一行不可用
	source.rows = [_row("九转金丹", false, 1, RulesScript.TEXT_PILL_UNKNOWN)]
	source.pill_targets = [_target(601)]
	screen.call(&"open")
	# Act——走键盘确认路径（游标在无可用行时为 -1，activate 应直接返回 false）
	screen.call(&"_input", _key_event(KEY_ENTER))
	# Assert
	assert_eq(used.size(), 0, "无可用行时回车不该发意图")
	assert_eq(int(screen.call(&"focused_index")), -1, "无可用行时游标应为 -1")


func test_back_button_emits_closed() -> void:
	# Arrange
	screen.call(&"open")
	# Act
	screen.call(&"press_back")
	# Assert
	assert_eq(closes, 1, "「返回」应发一次 closed（关不关由宿主决定）")


func test_escape_emits_closed() -> void:
	# Arrange
	screen.call(&"open")
	# Act
	screen.call(&"_input", _key_event(KEY_ESCAPE))
	# Assert
	assert_eq(closes, 1, "Esc 应发 closed（面板开着时 Esc 是关行囊，不是弹暂停）")


func test_hidden_screen_ignores_input() -> void:
	## 面板没开时不该吃任何事件（否则会隔着隐藏控件抢走战斗里的按键）。
	# Act
	screen.call(&"_input", _key_event(KEY_ESCAPE))
	# Assert
	assert_eq(closes, 0, "隐藏时不该响应 Esc")


func test_show_message_replaces_the_hint_with_the_result() -> void:
	## 宿主用「先刷新再回填」的顺序显示系统给的句子（顺序反了玩家就看不到）。
	# Arrange
	source.rows = [_row("回春丹", true, 1)]
	source.pill_targets = [_target(601)]
	screen.call(&"open")
	# Act
	screen.call(&"show_message", "回春丹已服下 · 回复 4 点生命")
	# Assert
	assert_eq(str(screen.call(&"message_text")), "回春丹已服下 · 回复 4 点生命",
			"结果文案应盖住操作提示")


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════════════════

## 造一行条目（[code]CombatBagEntries.entries()[/code] 的产出形状里面板真正读的那几个键）。[br]
## [br][b]为什么用 [method CombatBagRules.row_text] 折行文案[/b]：行文本是判据模块的
## 产出——测试手拼一句会与生产分叉，而面板渲染的正是那一句。
func _row(p_name: String, p_usable: bool, p_count: int = 1, p_reason: String = "",
		p_target_type: String = "single_ally",
		p_kind: StringName = &"pill") -> Dictionary:
	var entry: Dictionary = {
		"kind": p_kind, "name": p_name, "rarity_name": "蓝", "count": p_count,
		"template_id": p_name, "instance_id": 1, "cost": 1,
		"target_type": p_target_type, "effect_kind": 1, "effect_value": 4,
		"stat_changes": {}, "usable": p_usable, "reason": p_reason,
	}
	entry["text"] = RulesScript.row_text(entry)
	return entry


## 造一个候选（目标栏只读 [code]character_id[/code] 与 [code]label[/code]）。
func _target(p_character_id: int) -> Dictionary:
	return {
		"character_id": p_character_id, "current_hp": 5, "max_hp": 10,
		"label": RulesScript.target_label(p_character_id),
	}


## 造一个按键事件（面板走 [code]_input[/code]，直调即复现引擎同一次派发）。
func _key_event(p_code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = p_code
	event.pressed = true
	event.echo = false
	return event
