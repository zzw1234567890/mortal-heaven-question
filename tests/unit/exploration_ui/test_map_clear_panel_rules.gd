extends GutTest
## MapClearPanelRules —— 地图通关结算面板文案内核的纯函数用例。[br]
## [br][b]本文件补的断链[/b]：GDD §7 的四条 AC（首通行金色高亮 / 非首次不显示首通行 /
## 基础奖励按难度档给 / 点击卡牌看详情）此前**只有线框没有实现**——[code]MapClearView[/code]
## 只是把结算载荷缓起来，没有任何界面消费它。本文件锁死「哪一段该出现、每行长什么样」。[br]
## [br][b]覆盖[/b]：[br]
##   1. [b]首通行只在首通时出现[/b]——判据是载荷的 [code]is_first_clear[/code]，
##      [b]不是[/b]「首通奖励是否为空」（否则配置漏写奖励时首通行会被静默藏掉）；[br]
##   2. [b]两段分开取[/b]——基础卡与首通卡各取一段，合并后就分不出哪张是首通彩头；[br]
##   3. [b]零值不出行[/b]——「灵石 × 0」是噪音；全零时走「本次无额外奖励」兜底；[br]
##   4. [b]卡牌行与详情行[/b]——名称/稀有度/类型写在文本里（色盲可读），
##      缺字段时回退 ID、不臆造描述。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用，本文件不需要任何
## 装置——这正是不把文案拼装写进面板控件的理由。[br]
##
## 来源: design/gdd/exploration-ui-system.md §7 地图通关结算 + §AC「通关结算与探索结束」、
## ADR-0031 §2。

const Rules := preload("res://src/ui/exploration/map_clear_panel_rules.gd")
const ClearView := preload("res://src/feature/exploration/map_clear_view.gd")


## 一份首通结算载荷（数值取 LOW 档 + 首通档位表，与 catalog 注入的配置同源）。
func _first_clear_view() -> Dictionary:
	return {
		ClearView.KEY_MAP_ID: &"qing_yun_jian_zong",
		ClearView.KEY_MAP_NAME: "青云剑宗",
		ClearView.KEY_IS_FIRST_CLEAR: true,
		ClearView.KEY_CLEAR_COUNT: 1,
		ClearView.KEY_LING_SHI: 50,
		ClearView.KEY_CULTIVATION: 50,
		ClearView.KEY_FIRST_LING_SHI: 50,
		ClearView.KEY_FIRST_CULTIVATION: 30,
		ClearView.KEY_CARDS: [],
		ClearView.KEY_FIRST_CARDS: [{
			"card_id": "pei_yuan_dan", "name": "培元丹",
			"rarity": "白", "school": "丹药",
		}],
		ClearView.KEY_CARDS_FAILED: [],
	}


## 同一局的重复通关载荷（上游不给 [code]extra[/code]，首通三键全为 0 / 空）。
func _repeat_clear_view() -> Dictionary:
	var view: Dictionary = _first_clear_view()
	view[ClearView.KEY_IS_FIRST_CLEAR] = false
	view[ClearView.KEY_CLEAR_COUNT] = 2
	view[ClearView.KEY_FIRST_LING_SHI] = 0
	view[ClearView.KEY_FIRST_CULTIVATION] = 0
	view[ClearView.KEY_FIRST_CARDS] = []
	return view


# ═══════════════════════════════════════════════════════════════════════════════
# 面板骨架
# ═══════════════════════════════════════════════════════════════════════════════

func test_title_matches_gdd_wireframe() -> void:
	assert_eq(Rules.title(), "地图通关！", "GDD §7 线框首行为「地图通关！」")


func test_map_name_prefers_catalog_name() -> void:
	assert_eq(Rules.map_name(_first_clear_view()), "青云剑宗", "有登记名时用登记名")


func test_map_name_falls_back_to_map_id() -> void:
	var view: Dictionary = _first_clear_view()
	view[ClearView.KEY_MAP_NAME] = ""
	assert_eq(Rules.map_name(view), "qing_yun_jian_zong",
			"没有中文名时回退地图 ID——不显示占位名")


func test_map_name_empty_without_map() -> void:
	assert_eq(Rules.map_name({}), "", "两者都缺时为空串，面板整行省略")


func test_clear_count_text_reports_which_run_this_was() -> void:
	assert_eq(Rules.clear_count_text(_repeat_clear_view()), "第 2 次通关",
			"次数行让玩家知道这一局算第几次")


func test_clear_count_text_omitted_when_unknown() -> void:
	assert_eq(Rules.clear_count_text({}), "", "次数缺失时不出行（不显示「第 0 次」）")


# ═══════════════════════════════════════════════════════════════════════════════
# 首通行出现与否（GDD §7 两条 AC）
# ═══════════════════════════════════════════════════════════════════════════════

func test_first_section_shown_on_first_clear() -> void:
	assert_true(Rules.shows_first_section(_first_clear_view()),
			"首次通关应显示「⭐ 首次通关奖励」段")


func test_first_section_hidden_on_repeat_clear() -> void:
	assert_false(Rules.shows_first_section(_repeat_clear_view()),
			"非首次通关不显示首次通关奖励行（GDD §7 明文）")


func test_first_section_judged_by_flag_not_by_empty_reward() -> void:
	## 判据是标志位：首通但上游没配奖励时仍应显示该段（空段也好过静默藏掉，
	## 那样「首通是不是没生效」就不可观测了）。
	var view: Dictionary = _repeat_clear_view()
	view[ClearView.KEY_IS_FIRST_CLEAR] = true
	assert_true(Rules.shows_first_section(view),
			"首通判定只看 is_first_clear——首通奖励为空也应显示该段")


func test_first_section_hidden_on_empty_view() -> void:
	assert_false(Rules.shows_first_section({}), "没有结算就没有首通可言")


# ═══════════════════════════════════════════════════════════════════════════════
# 奖励行与卡牌行
# ═══════════════════════════════════════════════════════════════════════════════

func test_amount_lines_following_wireframe_order() -> void:
	assert_eq(Rules.amount_lines(50, 50), ["灵石 × 50", "修为 × 50"],
			"GDD §7 线框顺序为「灵石 → 修为」")


func test_amount_lines_skip_zero_values() -> void:
	assert_eq(Rules.amount_lines(0, 30), ["修为 × 30"], "灵石为 0 时不出行")
	assert_eq(Rules.amount_lines(50, 0), ["灵石 × 50"], "修为为 0 时不出行")
	assert_eq(Rules.amount_lines(0, 0), [], "双零时不出一行")


func test_sections_take_separate_amounts() -> void:
	var view: Dictionary = _first_clear_view()
	assert_eq(Rules.section_amount_lines(view, false), ["灵石 × 50", "修为 × 50"],
			"基础段取基础三键")
	assert_eq(Rules.section_amount_lines(view, true), ["灵石 × 50", "修为 × 30"],
			"首通段取首通三键（两段键名不同，不能互相串）")


func test_sections_take_separate_cards() -> void:
	var view: Dictionary = _first_clear_view()
	assert_eq(Rules.section_cards(view, false).size(), 0, "基础段没有卡（出厂配置为空）")
	assert_eq(Rules.section_cards(view, true).size(), 1, "首通段有 1 张首通彩头")


func test_cards_of_tolerates_dirty_payload() -> void:
	var view: Dictionary = {ClearView.KEY_CARDS: "不是数组"}
	assert_eq(Rules.cards_of(view, ClearView.KEY_CARDS), [], "非数组按空处理")
	view[ClearView.KEY_CARDS] = [null, 42, {"card_id": "a"}, "bare_id"]
	assert_eq(Rules.cards_of(view, ClearView.KEY_CARDS).size(), 2,
			"只收字典与裸 ID，丢弃 null 与数字")


func test_card_row_text_carries_name_tag_and_hint() -> void:
	var entry: Dictionary = _first_clear_view()[ClearView.KEY_FIRST_CARDS][0]
	assert_eq(Rules.card_row_text(entry), "培元丹 （白·丹药） ← 点击查看",
			"GDD §7 线框「[青云剑诀] 蓝色·功法 ← 点击查看」")


func test_card_row_text_falls_back_to_id() -> void:
	assert_eq(Rules.card_row_text({"card_id": "unknown_card"}),
			"unknown_card ← 点击查看", "没有名称时回退卡牌 ID")
	assert_eq(Rules.card_row_text({}), "未知卡牌 ← 点击查看", "连 ID 都没有时的兜底")


func test_card_tag_handles_partial_fields() -> void:
	assert_eq(Rules.card_tag({"rarity": "蓝"}), "（蓝）", "只有稀有度时只显示一项")
	assert_eq(Rules.card_tag({"school": "功法"}), "（功法）", "只有类型时同理")
	assert_eq(Rules.card_tag({}), "", "两者都缺时不出现空括号")


func test_card_detail_lines_include_template_extra() -> void:
	var entry: Dictionary = _first_clear_view()[ClearView.KEY_FIRST_CARDS][0]
	var lines: Array = Rules.card_detail_lines(entry,
			{"description": "回复少量生命", "flavor_text": "丹香清冽"})
	assert_eq(lines, ["培元丹", "（白·丹药）", "回复少量生命", "丹香清冽"],
			"详情 = 名称 + 档位 + 模板描述 + 风味")


func test_card_detail_lines_without_provider_do_not_invent_text() -> void:
	var entry: Dictionary = _first_clear_view()[ClearView.KEY_FIRST_CARDS][0]
	assert_eq(Rules.card_detail_lines(entry), ["培元丹", "（白·丹药）"],
			"拿不到模板时不编造描述行")


# ═══════════════════════════════════════════════════════════════════════════════
# 空段兜底
# ═══════════════════════════════════════════════════════════════════════════════

func test_has_any_reward_on_first_clear() -> void:
	assert_true(Rules.has_any_reward(_first_clear_view()), "首通有基础 + 首通奖励")


func test_has_any_reward_on_repeat_clear_uses_base_only() -> void:
	assert_true(Rules.has_any_reward(_repeat_clear_view()),
			"重复通关仍有基础奖励（面板不该说「本次无额外奖励」）")


func test_has_any_reward_false_when_everything_is_zero() -> void:
	var view: Dictionary = _first_clear_view()
	view[ClearView.KEY_LING_SHI] = 0
	view[ClearView.KEY_CULTIVATION] = 0
	view[ClearView.KEY_FIRST_LING_SHI] = 0
	view[ClearView.KEY_FIRST_CULTIVATION] = 0
	view[ClearView.KEY_FIRST_CARDS] = []
	assert_false(Rules.has_any_reward(view), "全零时走「本次无额外奖励」兜底")


func test_has_any_reward_ignores_first_rewards_on_repeat_clear() -> void:
	## 显示判据与非空判据必须同源：重复通关的载荷里首通键本就是 0，但若哪天上游
	## 漏清，显示判据说「没有首通行」而非空判据说「有」就会自相矛盾——届时面板会
	## 显示「本次无额外奖励」却同时画着一个空的首通段。基线奖励清零以隔离这条判据。
	var view: Dictionary = _repeat_clear_view()
	view[ClearView.KEY_LING_SHI] = 0
	view[ClearView.KEY_CULTIVATION] = 0
	view[ClearView.KEY_CARDS] = []
	view[ClearView.KEY_FIRST_LING_SHI] = 999
	assert_false(Rules.has_any_reward(view),
			"非首通时首通键不计入——两个判据同源")


func test_nothing_text_is_defined() -> void:
	assert_false(Rules.TEXT_NOTHING.is_empty(), "空段兜底文案必须存在")
