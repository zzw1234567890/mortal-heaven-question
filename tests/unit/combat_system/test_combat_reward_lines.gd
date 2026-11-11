extends GutTest
## 战斗奖励文案内核——结算面板 / 结算场景 / 回探索提示的同一份口径。[br]
## [br][b]覆盖[/b]：灵石（含区间标注）、修为、到手卡牌、未抽到卡牌、发放失败、
## 空奖励与单行摘要。文案是玩家可见的唯一表达，分叉即自相矛盾。[br]
##
## 来源: GDD combat-system.md §9、DEBT-CUI-008-1（文案中文硬编码的既有口径）。

const Lines := preload("res://src/feature/combat/combat_reward_lines.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 单行
# ═══════════════════════════════════════════════════════════════════════════════

func test_lingshi_line_plain_when_not_rolled() -> void:
	var lines: Array = Lines.reward_lines({"lingshi": 12})
	assert_eq(lines, ["灵石 +12"], "定值灵石只显示数值")


func test_lingshi_line_shows_range_when_rolled() -> void:
	var lines: Array = Lines.reward_lines({
		"lingshi": 6, "lingshi_min": 4, "lingshi_max": 8, "lingshi_rolled": true,
	})
	assert_eq(lines, ["灵石 +6（区间 4~8 掷出）"], "掷骰结果应带上区间（可解释随机性）")


func test_lingshi_range_hidden_when_interval_is_a_point() -> void:
	var lines: Array = Lines.reward_lines({
		"lingshi": 5, "lingshi_min": 5, "lingshi_max": 5, "lingshi_rolled": true,
	})
	assert_eq(lines, ["灵石 +5"], "区间收成一点时不显示「5~5」的噪声")


func test_cultivation_line() -> void:
	assert_eq(Lines.reward_lines({"cultivation": 3}), ["修为 +3"], "修为行")


func test_zero_or_negative_rewards_produce_no_lines() -> void:
	assert_eq(Lines.reward_lines({"lingshi": 0, "cultivation": 0, "cards": []}), [],
			"0 奖励不产生行（不显示「+0」）")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 卡牌：到手 / 未抽到 / 未入库
# ═══════════════════════════════════════════════════════════════════════════════

func test_gained_card_line_with_rarity_and_school() -> void:
	var lines: Array = Lines.reward_lines({"cards": [
		{"card_id": "pei_yuan_dan", "name": "培元丹", "rarity": "白", "school": "丹药"},
	]})
	assert_eq(lines, ["获得卡牌：培元丹（白·丹药）"], "到手卡牌行")


func test_gained_card_line_falls_back_to_card_id() -> void:
	var lines: Array = Lines.reward_lines({"cards": [{"card_id": "pei_yuan_dan"}]})
	assert_eq(lines, ["获得卡牌：pei_yuan_dan"], "缺名称时回退卡牌 ID（不臆造名字）")


func test_missed_card_line_with_chance_percent() -> void:
	var lines: Array = Lines.reward_lines({"cards_missed": [
		{"card_id": "gui_xiu_page", "name": "鬼修残页", "chance": 0.2},
	]})
	assert_eq(lines, ["未抽到：鬼修残页（20%）"], "未命中行带概率（解释为什么没到手）")


func test_missed_card_line_without_chance_has_no_percent() -> void:
	var lines: Array = Lines.reward_lines({"cards_missed": [
		{"card_id": "gui_xiu_page", "name": "鬼修残页"},
	]})
	assert_eq(lines, ["未抽到：鬼修残页"], "无概率配置时不显示百分比")


func test_failed_card_line_has_reason() -> void:
	var lines: Array = Lines.reward_lines({"cards_failed": [
		{"card_id": "unknown_card", "reason": "未知卡牌"},
	]})
	assert_eq(lines, ["unknown_card 未能发放（未知卡牌）"], "发放失败要说明原因")


func test_grant_failure_flags_are_reported() -> void:
	var lines: Array = Lines.reward_lines({
		"lingshi": 5, "cultivation": 2,
		"lingshi_granted": false, "cultivation_granted": false,
	})
	assert_true(lines.has("灵石 未能发放（资源系统不可用）"), "灵石未入账要可见")
	assert_true(lines.has("修为 未能发放（修为系统不可用）"), "修为未入账要可见")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 顺序、段与摘要
# ═══════════════════════════════════════════════════════════════════════════════

func test_line_order_is_stable() -> void:
	var lines: Array = Lines.reward_lines({
		"lingshi": 6, "lingshi_min": 4, "lingshi_max": 8, "lingshi_rolled": true,
		"cultivation": 3,
		"cards": [{"card_id": "a", "name": "甲"}],
		"cards_missed": [{"card_id": "b", "name": "乙", "chance": 0.5}],
		"cards_failed": [{"card_id": "c", "reason": "未知卡牌"}],
	})
	assert_eq(lines[0], "灵石 +6（区间 4~8 掷出）", "第一行是灵石")
	assert_eq(lines[1], "修为 +3", "第二行是修为")
	assert_eq(lines[2], "获得卡牌：甲", "第三行是到手卡牌")
	assert_eq(lines[3], "未抽到：乙（50%）", "第四行是未抽到")
	assert_eq(lines[4], "c 未能发放（未知卡牌）", "最后是发放失败")


func test_section_falls_back_to_nothing_text() -> void:
	var section: Dictionary = Lines.section({})
	assert_eq(str(section["title"]), Lines.TEXT_SECTION, "段标题固定")
	assert_eq(section["lines"], [Lines.TEXT_NOTHING], "无奖励时给明确兜底提示")


func test_section_passes_lines_through() -> void:
	var section: Dictionary = Lines.section({"lingshi": 9})
	assert_eq(section["lines"], ["灵石 +9"], "有奖励时原样给出正文")


func test_summary_text_empty_when_no_rewards() -> void:
	assert_eq(Lines.summary_text({}), "", "无奖励时不产生提示")
	assert_eq(Lines.summary_text({"lingshi": 0}), "", "0 奖励同样不提示")


func test_summary_text_is_single_line_with_all_parts() -> void:
	var text: String = Lines.summary_text({
		"lingshi": 6, "cultivation": 3,
		"cards": [{"card_id": "a", "name": "培元丹"}],
		"cards_missed": [{"card_id": "b", "name": "鬼修残页"}],
	})
	assert_string_contains(text, Lines.TEXT_SECTION, "摘要带段落标题")
	assert_string_contains(text, "灵石 +6", "摘要含灵石")
	assert_string_contains(text, "修为 +3", "摘要含修为")
	assert_string_contains(text, "获得「培元丹」", "摘要含到手卡牌")
	assert_string_contains(text, "未抽到「鬼修残页」", "摘要含未抽到")
	assert_false(text.contains("\n"), "摘要是单行（Toast 展示）")


func test_summary_reports_failed_cards_count() -> void:
	var text: String = Lines.summary_text({"cards_failed": [
		{"card_id": "a", "reason": "未知卡牌"}, {"card_id": "b", "reason": "未知卡牌"},
	]})
	assert_string_contains(text, "2 张卡牌未能入库", "失败张数要可见")


func test_notification_type_only_when_there_is_something() -> void:
	assert_eq(Lines.notification_type({}), "", "无奖励不发通知")
	assert_eq(Lines.notification_type({"lingshi": 1}), "item", "有奖励走高亮 item 通知")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 脏数据
# ═══════════════════════════════════════════════════════════════════════════════

func test_non_dictionary_reward_payloads_are_tolerated() -> void:
	assert_eq(Lines.reward_lines({}), [], "空载荷不崩")
	assert_eq(Lines.summary_text({}), "", "空载荷摘要为空")
	# 非数组 / 非字典条目被忽略
	var lines: Array = Lines.reward_lines({"cards": "not-an-array"})
	assert_eq(lines, [], "非数组 cards 被忽略")
