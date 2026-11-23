extends GutTest
## 结算屏两段分工的装配测试（DEBT-CUI-008-3）。[br]
## [br][b]覆盖[/b]（对应任务单 Item 2 的可验证要求）：[br]
##   1. [b]选择段标题按实际候选数落到控件上[/b]：1 项 → 「本次奖励：这份直接带走」，
##      3 项 → 「本次奖励：3 选 1」（[b]精确匹配[/b]控件 text，不是 contains）；[br]
##   2. [b]顺序即语义[/b]：选择段标题在控件树里排在「已入账」块[b]之前[/b]
##      （两段并列同权重正是玩家分不清哪组已到手的成因）；[br]
##   3. [b]「已到账」块只用发放记录[/b]：清单来自调用方给的发放返回值，
##      面板只前置「已入账：」标记，不重新算一遍；[br]
##   4. [b]选完后选择器真的消失[/b]：汇总视图下网格 / 跳过 / 选择段标题全隐藏，
##      卡片清空。[br]
## [br][b]走真实面板[/b]：真实 [code]SettlementPanel[/code] + 真实控件树，
## 只桩掉计时器相位（沿用 [file test_loot_delay_clickable.gd] 的既定接缝）。

const PanelScript := preload("res://src/ui/combat/settlement/settlement_panel.gd")
const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")

var panel: Control = null


func before_each() -> void:
	panel = PanelScript.new()
	add_child_autofree(panel)
	panel.reduce_motion = true


## 三个候选（卡牌 / 灵石 / 消耗品）。
func _three_options() -> Array:
	return [
		{"kind": Rules.OPTION_KIND_CARD, "name": "青云剑诀", "rarity": "蓝",
				"school": "功法"},
		{"kind": Rules.OPTION_KIND_LINGSHI, "amount": 25},
		{"kind": Rules.OPTION_KIND_CONSUMABLE, "name": "回血丹"},
	]


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 标题按候选数落到控件
# ═══════════════════════════════════════════════════════════════════════════════

func test_victory_with_three_options_shows_three_choose_one_title() -> void:
	panel.show_victory(_three_options(), 5, 20, [])
	assert_eq(panel.pick_title_label.text, "本次奖励：3 选 1",
			"3 项候选的段标题应为「本次奖励：3 选 1」（精确匹配）")
	assert_true(panel.pick_title_label.visible, "有候选时段标题应显示")


func test_victory_with_two_options_shows_two_choose_one_title() -> void:
	panel.show_victory(_three_options().slice(0, 2), 5, 20, [])
	assert_eq(panel.pick_title_label.text, "本次奖励：2 选 1",
			"2 项候选的段标题应为「本次奖励：2 选 1」（精确匹配）")


func test_victory_with_one_option_says_take_directly() -> void:
	panel.show_victory(_three_options().slice(0, 1), 5, 20, [])
	assert_eq(panel.pick_title_label.text, "本次奖励：这份直接带走",
			"1 项候选的段标题应为「本次奖励：这份直接带走」（不再写三选一）")
	assert_eq(panel.confirm_button.text, "直接带走",
			"1 项候选的按钮应同阈值改为「直接带走」")


func test_victory_with_no_options_hides_pick_title() -> void:
	panel.show_victory([], 5, 20, [])
	assert_false(panel.pick_title_label.visible,
			"无候选时选择段标题应隐藏（该段整体不存在）")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 顺序：选择段在入账段之前
# ═══════════════════════════════════════════════════════════════════════════════

func test_pick_title_precedes_granted_block_in_layout() -> void:
	# 顺序即语义——「先挑，再看到手了什么」，两段不再是并列同权重的两组数字
	var pick_index: int = panel.pick_title_label.get_index()
	var granted_index: int = panel.reward_lines_label.get_index()
	assert_true(pick_index < granted_index,
			"选择段标题（#%d）应排在入账块（#%d）之前" % [pick_index, granted_index])


func test_loot_grid_precedes_granted_block_in_layout() -> void:
	var grid_index: int = panel.loot_grid.get_index()
	var granted_index: int = panel.reward_lines_label.get_index()
	assert_true(grid_index < granted_index,
			"战利品网格（#%d）应排在入账块（#%d）之前——玩家先做完选择" % [
					grid_index, granted_index])


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 「已到账」块只列发放记录
# ═══════════════════════════════════════════════════════════════════════════════

func test_granted_block_prefixes_real_lines_without_recomputing() -> void:
	# 清单来自调用方给的发放返回值（SettlementGrantLines.granted_lines 的产物）——
	# 面板只加段首标记，不改写、不重算
	panel.show_victory(_three_options(), 5, 20, [])
	var granted: Array = ["灵石 +25", "修为 +5", "获得卡牌：培元丹（白）"]
	panel.show_grant_summary(granted)
	assert_eq(panel.reward_lines_label.text,
			"已入账：灵石 +25\n修为 +5\n获得卡牌：培元丹（白）",
			"入账块应为「已入账：」+ 发放记录原文（逐行、逐字）")
	assert_true(panel.reward_lines_label.visible, "有入账记录时该块应显示")


func test_granted_block_single_line_matches_grant_record() -> void:
	panel.show_victory(_three_options(), 5, 20, [])
	panel.show_grant_summary(["本次战斗无奖励"])
	assert_eq(panel.reward_lines_label.text, "已入账：本次战斗无奖励",
			"单行入账记录同样只加前缀")


func test_victory_pending_block_marks_not_yet_granted() -> void:
	# 选择段的汇总行是「尚未入账」形态——与「已入账」形成对照
	panel.show_victory(_three_options(), 5, 20, ["灵石 +25", "修为 +5"])
	assert_eq(panel.reward_lines_label.text,
			"本场奖励（尚未入账）：灵石 +25\n修为 +5",
			"选择阶段的汇总行应带「本场奖励（尚未入账）：」标记")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 选完后选择器消失
# ═══════════════════════════════════════════════════════════════════════════════

func test_grant_summary_hides_selector_entirely() -> void:
	panel.show_victory(_three_options(), 5, 20, [])
	assert_eq(panel.get_cards().size(), 3, "前置条件：选择阶段有 3 张候选卡")
	panel.show_grant_summary(["灵石 +25", "修为 +5"])
	assert_false(panel.loot_grid.visible, "汇总视图下战利品网格应隐藏")
	assert_false(panel.pick_title_label.visible, "汇总视图下选择段标题应隐藏")
	assert_false(panel.skip_button.visible, "汇总视图下跳过按钮应隐藏")
	assert_eq(panel.get_cards().size(), 0, "汇总视图下候选卡应清空")
	assert_eq(panel.selected_index, -1, "汇总视图下选中态应复位")


func test_grant_summary_keeps_panel_open_for_confirmation() -> void:
	# 选择器消失不等于面板关闭——玩家还要点确认落定
	panel.show_victory(_three_options(), 5, 20, [])
	panel.show_grant_summary(["灵石 +25"])
	assert_true(panel.is_open(), "汇总视图下面板仍开着")
	assert_true(panel.is_showing_grant_summary(), "应处于汇总视图")


func test_defeat_screen_hides_pick_title() -> void:
	panel.show_victory(_three_options(), 5, 20, [])
	panel.show_defeat({"cultivation_lost": 3, "dead_names": [], "binding_card_count": 0})
	assert_false(panel.pick_title_label.visible,
			"战败面板没有奖励段，选择段标题应隐藏")
