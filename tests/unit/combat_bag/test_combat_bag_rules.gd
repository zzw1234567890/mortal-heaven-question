extends "res://tests/unit/combat_bag/combat_bag_fixture.gd"
## CombatBagRules 单元测试——「能不能用 / 为什么不能用」的判据与文案。[br]
## [br][b]为什么单测纯函数[/b]：判据的每个拒绝分支都要能脱离存档 / 费用 / 战斗系统
## 单独钉死——喂一条字典就得到一句结论，这是把判据从取数里分出来的全部理由。[br]
## [br][b]顺带锁住的一件事[/b]：判据的[b]顺序[/b]即「玩家最该先知道哪一条」。
## 顺序错了不会报错，只会让玩家看到一句不解决问题的提示（手上没有这枚丹，
## 却被告诉「效用尚未参透」）。故顺序本身也是断言对象。
##
## 装置见 [combat_bag_fixture.gd]。
##
## 来源: 本轮任务书第 3 条（不可用条目禁用并写明原因）、
## design/gdd/alchemy-crafting-system.md §1c。

const EvaluatorScript := preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")

const HEAL: int = EvaluatorScript.EffectCategory.HEAL
const BUFF: int = EvaluatorScript.EffectCategory.BUFF
const UNEVALUABLE: int = EvaluatorScript.EffectCategory.UNEVALUABLE


# ═══════════════════════════════════════════════════════════════════════════════
# 可用：全部门过 → 空串（不是「可用」这句话，是没有理由）
# ═══════════════════════════════════════════════════════════════════════════════

func test_usable_pill_has_no_reason() -> void:
	# Arrange——回春丹：有实物 / 模板在 / 治疗 / 有人缺 / 灵力够
	var entry: Dictionary = bare_entry(RulesScript.KIND_PILL, HEAL)
	# Act
	var reason: String = RulesScript.reason_for(entry, true, true, true, 5)
	# Assert
	assert_eq(reason, "", "六道门全过时不该有任何理由句")
	assert_true(RulesScript.is_usable(entry, true, true, true, 5),
			"is_usable 应是 reason_for 的空串视图")


func test_free_pill_is_usable_when_cost_is_zero() -> void:
	# Arrange——0 费丹（[code]can_afford(0)[/code] 恒真，即便灵力为 0）
	var entry: Dictionary = bare_entry(RulesScript.KIND_PILL, HEAL, 0)
	# Act / Assert
	assert_true(RulesScript.is_usable(entry, true, true, true, 0),
			"0 费条目在灵力为 0 时仍可用")


# ═══════════════════════════════════════════════════════════════════════════════
# 不可用：四道前置门
# ═══════════════════════════════════════════════════════════════════════════════

func test_missing_instance_reports_no_instance() -> void:
	# Arrange——instance_id <= 0 = 指不到任何一张实物
	var entry: Dictionary = bare_entry(RulesScript.KIND_PILL, HEAL, 1, 0)
	# Act / Assert
	assert_eq(RulesScript.reason_for(entry, true, true, true, 5),
			RulesScript.TEXT_NO_INSTANCE, "无实物应报「已无实物」")


func test_missing_template_reports_lost_template() -> void:
	# Arrange
	var entry: Dictionary = bare_entry(RulesScript.KIND_PILL, HEAL)
	# Act / Assert
	assert_eq(RulesScript.reason_for(entry, false, true, true, 5),
			RulesScript.TEXT_NO_TEMPLATE, "模板查不到应报「图谱已散佚」")


func test_instance_gate_precedes_template_gate() -> void:
	## 顺序即语义：连实物都没有时，「图谱散佚」是句废话——玩家手上根本没这枚丹。
	# Arrange
	var entry: Dictionary = bare_entry(RulesScript.KIND_PILL, HEAL, 1, 0)
	# Act / Assert
	assert_eq(RulesScript.reason_for(entry, false, true, true, 5),
			RulesScript.TEXT_NO_INSTANCE, "两道门同时不过时应先说「无实物」")


func test_pill_with_unmodelled_effect_is_refused() -> void:
	## 模板在、实物在，但效果未建模（如九转金丹的「永久 +1 最大生命」）→
	## 如实说用不了，不拿 0 点回血冒充成功。
	# Arrange
	var entry: Dictionary = bare_entry(RulesScript.KIND_PILL, UNEVALUABLE)
	# Act / Assert
	assert_eq(RulesScript.reason_for(entry, true, true, true, 5),
			RulesScript.TEXT_PILL_UNKNOWN, "效果未建模的丹应报「效用尚未参透」")


func test_artifact_with_non_buff_effect_is_refused() -> void:
	## 法宝不是加属性的那种（如减伤 / 阵法类）→ 本轮不建模直用，如实拒绝。
	# Arrange
	var entry: Dictionary = bare_entry(RulesScript.KIND_ARTIFACT, HEAL)
	# Act / Assert
	assert_eq(RulesScript.reason_for(entry, true, true, true, 5),
			RulesScript.TEXT_ARTIFACT_INERT, "非增益法宝应报「还不能直接催动」")


# ═══════════════════════════════════════════════════════════════════════════════
# 不可用：目标门（丹与宝各有各的措辞）
# ═══════════════════════════════════════════════════════════════════════════════

func test_pill_without_target_reports_nobody_needs_it() -> void:
	## 全员满血时丹药不可用——满血吃药是无意义操作（候选池已滤掉无缺口者）。
	# Arrange
	var entry: Dictionary = bare_entry(RulesScript.KIND_PILL, HEAL)
	# Act / Assert
	assert_eq(RulesScript.reason_for(entry, true, false, true, 5),
			RulesScript.TEXT_NOBODY_NEEDS, "无人缺血的丹应报「此刻无人需要」")


func test_artifact_without_target_reports_nobody_to_buff() -> void:
	## 法宝加的是攻防，满血也吃得着——它的「没人」指的是场上无人可加持。
	# Arrange
	var entry: Dictionary = bare_entry(RulesScript.KIND_ARTIFACT, BUFF)
	# Act / Assert
	assert_eq(RulesScript.reason_for(entry, true, false, true, 5),
			RulesScript.TEXT_NO_TARGET, "无人可加持的宝应报「场上无人可加持」")


func test_target_gate_precedes_cost_gate() -> void:
	## 场上无人可施时，灵力够不够都不是玩家该先解决的事。
	# Arrange
	var entry: Dictionary = bare_entry(RulesScript.KIND_PILL, HEAL, 3)
	# Act / Assert
	assert_eq(RulesScript.reason_for(entry, true, false, false, 0),
			RulesScript.TEXT_NOBODY_NEEDS, "目标门应先于费用门")


# ═══════════════════════════════════════════════════════════════════════════════
# 不可用：费用门（文案与出牌同句式）
# ═══════════════════════════════════════════════════════════════════════════════

func test_insufficient_cost_writes_required_and_current() -> void:
	## 文案两位：需要 / 当前——与出牌的「灵力不足」同句式（对玩家是同一件事：
	## 都花灵力，措辞不该因为入口不同而换一套）。
	# Arrange
	var entry: Dictionary = bare_entry(RulesScript.KIND_PILL, HEAL, 3)
	# Act
	var reason: String = RulesScript.reason_for(entry, true, true, false, 1)
	# Assert
	assert_eq(reason, RulesScript.TEXT_NO_COST % [3, 1],
			"应报「需要 3 点，当前 1 点」")
	assert_true(reason.contains("3") and reason.contains("1"),
			"两个数字都要出现在文案里：%s" % reason)


func test_cost_gate_is_the_last_one() -> void:
	## 前四道门全过、只差灵力 → 这才是费用门该说话的时候。
	# Arrange
	var entry: Dictionary = bare_entry(RulesScript.KIND_ARTIFACT, BUFF, 2)
	# Act / Assert
	assert_eq(RulesScript.reason_for(entry, true, true, false, 0),
			RulesScript.TEXT_NO_COST % [2, 0], "应报费用不足")


# ═══════════════════════════════════════════════════════════════════════════════
# 类别映射 / 全体判定 / 行文案
# ═══════════════════════════════════════════════════════════════════════════════

func test_category_for_maps_pill_to_heal_and_artifact_to_buff() -> void:
	## 「丹药治人、法宝加身」收在一处——界面与结算层对的是同一个类别。
	assert_eq(RulesScript.category_for(true), HEAL, "丹药应映射到治疗")
	assert_eq(RulesScript.category_for(false), BUFF, "法宝应映射到增益")


func test_is_all_allies_only_for_declared_target_word() -> void:
	# Arrange——天罗丹是 all_allies；其余取值按单目标处理（宁可只作用一人，
	## 也不把 single_ally 的丹悄悄撒到全队头上）
	var all_entry: Dictionary = bare_entry(RulesScript.KIND_PILL, HEAL, 1, 1, "all_allies")
	var single_entry: Dictionary = bare_entry(RulesScript.KIND_PILL, HEAL, 1, 1, "single_ally")
	# Act / Assert
	assert_true(RulesScript.is_all_allies(all_entry), "all_allies 应判为全体")
	assert_false(RulesScript.is_all_allies(single_entry), "single_ally 不应判为全体")
	assert_false(RulesScript.is_all_allies({}), "缺字段不应判为全体")


func test_row_text_carries_name_effect_count_and_reason() -> void:
	## 状态写进文本：不可用原因绝不能只靠灰显承载（色盲可读）。
	# Arrange
	var entry: Dictionary = bare_entry(RulesScript.KIND_PILL, HEAL)
	entry["name"] = "回春丹"
	entry["rarity_name"] = "蓝"
	entry["effect_value"] = 4
	entry["count"] = 2
	entry["reason"] = RulesScript.TEXT_NOBODY_NEEDS
	# Act
	var text: String = RulesScript.row_text(entry)
	# Assert
	assert_true(text.contains("回春丹"), "行文案应含名称：%s" % text)
	assert_true(text.contains("×2"), "行文案应含数量：%s" % text)
	assert_true(text.contains("回复 4 点生命"), "行文案应含效果数值：%s" % text)
	assert_true(text.contains(RulesScript.TEXT_NOBODY_NEEDS),
			"不可用原因应写进文本：%s" % text)


func test_effect_text_is_empty_for_unmodelled_effect() -> void:
	## 数值读不到时不写「回复 0 点生命」这种假信息——宁可少一段。
	# Arrange
	var entry: Dictionary = bare_entry(RulesScript.KIND_PILL, HEAL)
	entry["effect_value"] = 0
	# Act / Assert
	assert_eq(RulesScript.effect_text(entry), "", "0 点回复不该生成效果句")


func test_effect_text_renders_stat_changes_for_artifact() -> void:
	## 法宝的增量句由 [code]stat_changes[/code] 折出（评估层写什么这里就显示什么）。
	# Arrange
	var entry: Dictionary = bare_entry(RulesScript.KIND_ARTIFACT, BUFF)
	entry["stat_changes"] = {"ATK": 3}
	# Act / Assert
	assert_eq(RulesScript.effect_text(entry), "攻击 +3", "应渲染为「攻击 +3」")


func test_empty_text_is_non_empty_and_shared() -> void:
	## 空行囊文案在判据模块——面板与宿主都引它，两处各写一份必然漂移。
	assert_false(RulesScript.TEXT_EMPTY.strip_edges().is_empty(),
			"空态文案不该是空串")
