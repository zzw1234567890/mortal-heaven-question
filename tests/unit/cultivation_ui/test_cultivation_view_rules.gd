extends GutTest
## CultivationViewRules 单元测试——修炼室的措辞与判定纯函数。[br]
## [br][b]为什么单测这一层[/b]：本模块不碰控件、不读 GSM，只有「给一组数字，得到
## 一句中文 / 一个布尔」——正是最容易悄悄漂移的地方（境界名写死、所需修为抄一份、
## 「到顶」这道闸漏掉）。集成测试只覆盖常见路径，边界（到顶、上限为 0、越界等级）
## 在这里逐条钉。[br]
## [br][b]数值来源不写死[/b]：境界名与所需修为都从 [code]RealmSystem.realm_table[/code]
## 的读取面取（测试与实现同一个来源，故断言的是「用对了来源」而不是「恰好等于某个
## 字面值」——表变了本文件跟着走）。
##
## 来源: design/gdd/cultivation-system.md §4/§6、ADR-0010 §realm_up 编排器、
## 先例 [code]test_map_clear_panel_rules.gd[/code]（规则层纯函数单测）。

const RulesScript := preload("res://src/ui/cultivation/cultivation_view_rules.gd")
const TableScript := preload("res://src/feature/exploration/exploration_breakthrough_table.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 文案（一律读配置，不硬编码境界名与数值）
# ═══════════════════════════════════════════════════════════════════════════════

func test_realm_line_reads_name_from_config_table() -> void:
	# Act + Assert——逐境界对着配置表核名（不是对着字面值）
	for level: int in range(1, TableScript.max_realm() + 1):
		var line: String = RulesScript.realm_line(level)
		assert_true(line.contains(TableScript.realm_name(level)),
				"境界 %d 的行应含配置表里的名字：%s" % [level, line])


func test_realm_line_uses_placeholder_for_unknown_level() -> void:
	# Arrange——表里没有的等级（0 / 越界）
	# Act + Assert——用占位符而不是空串或臆造的名字
	assert_true(RulesScript.realm_line(0).contains(RulesScript.TEXT_UNKNOWN),
			"未知等级应给占位符：%s" % RulesScript.realm_line(0))
	assert_true(RulesScript.realm_line(99).contains(RulesScript.TEXT_UNKNOWN),
			"越界等级应给占位符：%s" % RulesScript.realm_line(99))


func test_progress_line_carries_both_numbers() -> void:
	# Act
	var line: String = RulesScript.progress_line(120, 1000)
	# Assert——两个数字都在文本里（数字由文字承载，不只靠进度条）
	assert_true(line.contains("120"), "应含当前值：%s" % line)
	assert_true(line.contains("1000"), "应含上限：%s" % line)


func test_balance_line_keeps_zero_visible() -> void:
	# Act + Assert——0 也要照实写出来（不能「空着」让玩家分不清 0 与没读出来）
	assert_true(RulesScript.balance_line(0).contains("0"),
			"零余额也应写出来：%s" % RulesScript.balance_line(0))


func test_meditate_line_carries_the_same_amount_as_the_action() -> void:
	# Act + Assert——按钮上写的增量与真正加的量必须是同一个数
	var line: String = RulesScript.meditate_line()
	assert_true(line.contains(str(RulesScript.MEDITATE_AMOUNT)),
			"按钮文案应含实际增量 %d：%s" % [RulesScript.MEDITATE_AMOUNT, line])


func test_refusal_line_for_not_enough_carries_current_and_required() -> void:
	# Arrange——炼气期修为 300（所需 = 该境界的 max_cultivation）
	var required: int = TableScript.required_cultivation(1)
	# Act
	var line: String = RulesScript.refusal_line(1, 300)
	# Assert——两个数字都在：玩家据此知道还差多少
	assert_true(line.contains("300"), "应含当前修为：%s" % line)
	assert_true(line.contains(str(required)), "应含所需修为：%s" % line)


func test_refusal_line_at_max_realm_is_the_at_max_text() -> void:
	# Arrange——最高境界（修为多少都不该说「修为不足」）
	var top: int = TableScript.max_realm()
	# Act
	var line: String = RulesScript.refusal_line(top, 999999)
	# Assert——到顶用的是另一句（不是「修为不足」）
	assert_eq(line, TableScript.TEXT_AT_MAX, "到顶应给「已达最高境界」")


# ═══════════════════════════════════════════════════════════════════════════════
# 判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_allows_breakthrough_when_full_and_below_max() -> void:
	assert_true(RulesScript.allows_breakthrough(1, true),
			"修为满且未到顶时应允许突破")


func test_allows_breakthrough_false_when_not_full() -> void:
	assert_false(RulesScript.allows_breakthrough(1, false),
			"修为未满时不得允许突破")


func test_allows_breakthrough_false_at_max_realm_even_when_full() -> void:
	# Arrange——到顶时 check_breakthrough 仍返回 true（它只看修为满没满）
	# Act + Assert——本层必须自己拦住（不拦就是「按钮能点、点了报错」）
	assert_false(RulesScript.allows_breakthrough(TableScript.max_realm(), true),
			"已达最高境界时必须拦住，哪怕修为是满的")


func test_status_line_prefers_can_break_when_allowed() -> void:
	assert_eq(RulesScript.status_line(1, 1000, true), RulesScript.TEXT_CAN_BREAK,
			"可突破时状态行应是「可以突破了」")


func test_status_line_falls_back_to_refusal_when_not_allowed() -> void:
	# Act——修为不足
	var line: String = RulesScript.status_line(1, 10, false)
	# Assert——与拒绝提示同一套措辞（屏幕两处不会各说一套）
	assert_eq(line, RulesScript.refusal_line(1, 10),
			"状态行与拒绝提示必须是同一句")


# ═══════════════════════════════════════════════════════════════════════════════
# 进度条比例（只作第二通道——故边界必须稳）
# ═══════════════════════════════════════════════════════════════════════════════

func test_fill_ratio_is_proportional() -> void:
	assert_eq(RulesScript.fill_ratio(250, 1000), 0.25, "四分之一应为 0.25")


func test_fill_ratio_clamps_overflow_to_full() -> void:
	# 溢出池存在时当前值可能等于上限——比例不得超过 1
	assert_eq(RulesScript.fill_ratio(1500, 1000), 1.0, "超出上限应夹到 1.0")


func test_fill_ratio_is_zero_when_max_is_zero() -> void:
	# 上限 0 不是「满」而是不可读——给 0 而不是除零
	assert_eq(RulesScript.fill_ratio(100, 0), 0.0, "上限为 0 时比例应为 0.0")


func test_fill_ratio_is_zero_for_empty_progress() -> void:
	assert_eq(RulesScript.fill_ratio(0, 1000), 0.0, "零进度应为 0.0")


# ═══════════════════════════════════════════════════════════════════════════════
# 回执
# ═══════════════════════════════════════════════════════════════════════════════

func test_meditate_done_line_carries_the_amount() -> void:
	var line: String = RulesScript.meditate_done_line(50)
	assert_true(line.contains("50"), "回执应写明加了多少：%s" % line)


func test_breakthrough_done_line_names_both_realms() -> void:
	# Act——从炼气期突破
	var line: String = RulesScript.breakthrough_done_line(1)
	# Assert——旧境界与新境界的名字都在（且都来自配置表）
	assert_true(line.contains(TableScript.realm_name(1)), "应含旧境界名：%s" % line)
	assert_true(line.contains(TableScript.realm_name(2)), "应含新境界名：%s" % line)
