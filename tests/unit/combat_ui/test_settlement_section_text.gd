extends GutTest
## 结算屏两段文案分工单元测试（DEBT-CUI-008-3）。[br]
## [br][b]覆盖[/b]：[br]
##   1. [b]选择段标题按实际候选数分档[/b]：1 / 2 / 3 项各自的[b]精确字符串[/b]
##      （不是 contains——本轮修的正是「恒写三选一」）；[br]
##   2. [method SettlementSectionText.has_choice]：≥2 项才算「有得选」；[br]
##   3. [b]确认按钮同阈值[/b]：1 项时是「直接带走」而不是「确认选择」；[br]
##   4. [b]入账段标记[/b]：首行前置「已入账：」，空输入不加标记；[br]
##   5. [b]未入账段标记[/b]：首行前置「本场奖励（尚未入账）：」。[br]
## [br][b]零依赖[/b]：全部为纯函数调用——不建面板、不入场景树。

const Section := preload("res://src/ui/combat/shared/settlement_section_text.gd")
const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 选择段标题：1 / 2 / 3 项（精确字符串）
# ═══════════════════════════════════════════════════════════════════════════════

func test_pick_title_one_option_is_take_it_directly() -> void:
	# 候选不足时不能再说「三选一」——真机走查里最费解的一条
	assert_eq(Section.loot_pick_title(1), "本次奖励：这份直接带走",
			"1 项候选的标题必须是「本次奖励：这份直接带走」（精确匹配）")


func test_pick_title_two_options_is_two_choose_one() -> void:
	assert_eq(Section.loot_pick_title(2), "本次奖励：2 选 1",
			"2 项候选的标题必须是「本次奖励：2 选 1」（精确匹配）")


func test_pick_title_three_options_is_three_choose_one() -> void:
	assert_eq(Section.loot_pick_title(3), "本次奖励：3 选 1",
			"3 项候选的标题必须是「本次奖励：3 选 1」（精确匹配）")


func test_pick_title_zero_options_is_empty() -> void:
	# 空候选时该段整体隐藏（提示行走「本次无战利品」）
	assert_eq(Section.loot_pick_title(0), "", "0 项候选不产标题（整段隐藏）")


func test_pick_title_negative_count_is_empty() -> void:
	assert_eq(Section.loot_pick_title(-1), "", "负数候选（损坏载荷）按 0 处理")


func test_pick_title_four_options_follows_actual_count() -> void:
	# 上游给几项就写几选一——不是只认 1/2/3 三个档
	assert_eq(Section.loot_pick_title(4), "本次奖励：4 选 1",
			"4 项候选应写「4 选 1」（按实际数量）")


# ═══════════════════════════════════════════════════════════════════════════════
# 「有没有得选」判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_has_choice_false_for_zero_and_one() -> void:
	assert_false(Section.has_choice(0), "0 项没有选择")
	assert_false(Section.has_choice(1), "1 项只有带走/跳过，不是挑选")


func test_has_choice_true_from_two_up() -> void:
	assert_true(Section.has_choice(2), "2 项起才有选择")
	assert_true(Section.has_choice(3), "3 项有选择")


# ═══════════════════════════════════════════════════════════════════════════════
# 确认按钮同阈值
# ═══════════════════════════════════════════════════════════════════════════════

func test_confirm_button_one_option_is_take_directly() -> void:
	# 标题写「直接带走」而按钮写「确认选择」会让玩家以为漏了一步
	assert_eq(Section.confirm_button_text(1, "确认选择"), "直接带走",
			"1 项时按钮应是「直接带走」")


func test_confirm_button_multi_options_uses_caller_text() -> void:
	assert_eq(Section.confirm_button_text(3, "确认选择"), "确认选择",
			"≥2 项时按钮文案由调用方给")


func test_rules_confirm_button_text_matches_section() -> void:
	# 门面转发必须同源（Rules 是调用方唯一入口）
	assert_eq(Rules.confirm_button_text(1), Section.confirm_button_text(1, "确认选择"),
			"Rules 与 Section 的 1 项分档必须一致")
	assert_eq(Rules.confirm_button_text(3),
			Section.confirm_button_text(3, Rules.TEXT_CONFIRM_LOOT),
			"Rules 与 Section 的多项分档必须一致")


# ═══════════════════════════════════════════════════════════════════════════════
# 入账段标记
# ═══════════════════════════════════════════════════════════════════════════════

func test_granted_section_prefixes_first_line() -> void:
	var lines: Array = Section.granted_section_lines(["灵石 +10", "修为 +5"])
	assert_eq(lines[0], "已入账：灵石 +10", "首行应前置「已入账：」")
	assert_eq(lines[1], "修为 +5", "其余行原样保留（不改发放结果原文）")
	assert_eq(lines.size(), 2, "不增删行")


func test_granted_section_ends_with_colon_marker() -> void:
	# 标记本身写死在这里——玩家要能一眼看出「这一段是已经到手的」
	assert_eq(Section.TEXT_GRANTED_SECTION, "已入账：", "入账段标记字面量")


func test_granted_section_empty_input_stays_empty() -> void:
	# 空输入加一个光秃秃的「已入账：」比不加更费解
	assert_eq(Section.granted_section_lines([]), [], "空输入不产生标记")


func test_granted_section_single_line() -> void:
	var lines: Array = Section.granted_section_lines(["本次战斗无奖励"])
	assert_eq(lines.size(), 1, "单行不增行")
	assert_eq(lines[0], "已入账：本次战斗无奖励", "单行同样加前缀")


func test_pending_section_prefixes_first_line() -> void:
	var lines: Array = Section.pending_section_lines(["灵石 +10", "修为 +5"])
	assert_eq(lines[0], "本场奖励（尚未入账）：灵石 +10",
			"未入账段首行应前置「本场奖励（尚未入账）：」")
	assert_eq(lines[1], "修为 +5", "其余行原样保留")


func test_pending_section_empty_input_stays_empty() -> void:
	assert_eq(Section.pending_section_lines([]), [], "空输入不产生标记")


# ═══════════════════════════════════════════════════════════════════════════════
# 提示行与标题同阈值（一处改档另一处必须跟着改）
# ═══════════════════════════════════════════════════════════════════════════════

func test_victory_hint_one_option_says_confirm_directly() -> void:
	# 只有一项时「点击战利品选中」是无意义的指引
	assert_eq(Rules.victory_hint_text(true, 1), Section.TEXT_PICK_ONE_HINT,
			"1 项就绪期应说「这份没有别的选择，点确认带走」")


func test_victory_hint_multi_options_keeps_select_prompt() -> void:
	assert_eq(Rules.victory_hint_text(true, 3), Rules.TEXT_LOOT_READY,
			"≥2 项就绪期仍是「点击战利品选中，再点确认生效」")


func test_victory_hint_zero_options_still_no_loot() -> void:
	assert_eq(Rules.victory_hint_text(true, 0), Rules.TEXT_NO_LOOT,
			"0 项仍是「本次无战利品」")


func test_rules_forwards_pick_title_from_section() -> void:
	# 门面转发同源（面板只经 Rules 进入）
	assert_eq(Rules.loot_pick_title(2), Section.loot_pick_title(2),
			"Rules.loot_pick_title 应与 Section 同源")
	assert_eq(Rules.granted_section_lines(["a"])[0],
			Section.granted_section_lines(["a"])[0],
			"Rules.granted_section_lines 应与 Section 同源")
