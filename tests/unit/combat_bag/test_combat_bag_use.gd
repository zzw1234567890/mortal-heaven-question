extends "res://tests/unit/combat_bag/combat_bag_fixture.gd"
## CombatBagUse 单元测试——「用一枚丹 / 祭一件宝」的结算层。[br]
## [br][b]态度：失败不半完成[/b]。拒绝路径的每条断言都同时在钉三件事——不扣实物、
## 不扣灵力、不动 HP。少了任何一条，玩家都可能「用不成还少了东西」。[br]
## [br][b]数值一个都不写[/b]：回血量、属性增量全部来自模板经评估器现算（下述断言
## 读的也是同一次算法的产出），故装置里没有「回春丹是 4 点」这类常量。[br]
## [br]装置见 [combat_bag_fixture.gd]（真实状态表 + 真实落库 + 真实评估器）。
##
## 来源: 本轮任务书第 2 条（扣卡 + 扣费 + 中文提示）、第 3 条（法宝走增益）、
## design/gdd/alchemy-crafting-system.md §1c。

const EvaluatorScript := preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")
const BonusScript := preload("res://src/feature/combat/combat_stat_bonus.gd")


## 走完整链路用一枚条目：先取条目（带真实模板结论），再交给结算层。[br]
## [br][b]为什么不直接手搓条目[/b]：手搓会绕过「条目带对了 cost / instance_id」这一段，
## 而那正是生产路径的输入。
func _use(p_template: Resource, p_targets: Array = []) -> Dictionary:
	return use_template(p_template, p_targets)


# ═══════════════════════════════════════════════════════════════════════════════
# 点名验收 ②：用丹药回血 + 实例减少
# ═══════════════════════════════════════════════════════════════════════════════

func test_pill_heals_target_and_consumes_one_instance() -> void:
	# Arrange——收藏里两张回春丹，A 有 5 点缺口
	set_hp(CHAR_A, 5, 10)
	own(PILL_HEAL, 201)
	own(PILL_HEAL, 202)
	# Act
	var result: Dictionary = _use(PILL_HEAL, [CHAR_A])
	# Assert——真的回了血
	assert_true(bool(result["ok"]), "应可用：%s" % str(result["message"]))
	assert_eq(int(result["healed"]), 4, "回血量取自模板 effect_value（4 点）")
	assert_eq(hp_of(CHAR_A), 9, "A 应从 5 回到 9")
	# Assert——真的少了一枚（只少一枚）
	assert_true(bool(result["consumed"]), "consumed 应为真")
	assert_eq(owned_count(PILL_HEAL), 1, "两张应只剩一张")
	assert_eq(gsm.removals, [201], "应恰好取出那一张（同名多张只少一张）")
	# Assert——中文提示
	assert_true(str(result["message"]).contains("回春丹"), "提示应含名称")
	assert_true(str(result["message"]).contains("回复 4 点生命"),
			"提示应报实际回复量：%s" % str(result["message"]))


func test_heal_is_clamped_and_message_reports_actual_amount() -> void:
	## 回复量超过缺口时只补到满血，提示报的是[b]实际[/b]补上的点数。
	# Arrange
	set_hp(CHAR_A, 8, 10)  # 缺口 2 < 回复 4
	own(PILL_HEAL, 203)
	# Act
	var result: Dictionary = _use(PILL_HEAL, [CHAR_A])
	# Assert
	assert_eq(int(result["healed"]), 2, "应只报实际补上的 2 点")
	assert_eq(hp_of(CHAR_A), 10, "应夹在满血")
	assert_true(str(result["message"]).contains("回复 2 点生命"),
			"提示不该虚报 4 点：%s" % str(result["message"]))


func test_single_target_pill_heals_only_the_chosen_one() -> void:
	## 目标可显式选择——单体丹药只落在选中的那一位头上。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	set_hp(CHAR_B, 5, 10)
	own(PILL_HEAL, 204)
	# Act——显式选 B（不选 ID 更小的 A）
	var result: Dictionary = _use(PILL_HEAL, [CHAR_B])
	# Assert
	assert_true(bool(result["ok"]), "应成功")
	assert_eq(hp_of(CHAR_B), 9, "选中的 B 应回血")
	assert_eq(hp_of(CHAR_A), 5, "未选中的 A 不该被治")


func test_default_target_is_the_lowest_id_candidate() -> void:
	## 不指定目标时按 ID 升序取首个可施者（既有先例 combat_caster_rules）。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	set_hp(CHAR_B, 5, 10)
	own(PILL_HEAL, 205)
	# Act
	var result: Dictionary = _use(PILL_HEAL)
	# Assert
	assert_true(bool(result["ok"]), "应成功")
	assert_eq(hp_of(CHAR_A), 9, "默认应治 ID 最小的那一位")


func test_all_allies_pill_heals_everyone_with_a_gap() -> void:
	## 全体丹药（天罗丹 all_allies）逐人落库，返回值是[b]总量[/b]。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	set_hp(CHAR_B, 4, 10)
	own(PILL_ALL, 206)
	# Act
	var result: Dictionary = _use(PILL_ALL, [CHAR_A, CHAR_B])
	# Assert
	assert_true(bool(result["ok"]), "应成功")
	assert_eq(hp_of(CHAR_A), 10, "A 应回满（缺 5 < 回复 6）")
	assert_eq(hp_of(CHAR_B), 10, "B 应回满（缺 6 = 回复 6）")
	assert_eq(int(result["healed"]), 11, "返回的应是实际回血总量 5 + 6")
	assert_eq(owned_count(PILL_ALL), 0, "应消耗掉那一枚")


func test_all_allies_pill_defaults_to_every_candidate() -> void:
	## 不指定目标时，全体效果作用于[b]全部[/b]候选（不是只治首个）。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	set_hp(CHAR_B, 5, 10)
	own(PILL_ALL, 207)
	# Act
	var result: Dictionary = _use(PILL_ALL)
	# Assert
	assert_true(bool(result["ok"]), "应成功")
	assert_eq(hp_of(CHAR_A), 10, "A 应被治")
	assert_eq(hp_of(CHAR_B), 10, "B 也应被治（全体）")


func test_pill_bills_cost_through_the_shared_cost_system() -> void:
	## 计费走既有费用系统（与出牌同一套规则），不新造「行动点」。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	own(PILL_HEAL, 208)
	cost.current = 3
	# Act
	var result: Dictionary = _use(PILL_HEAL, [CHAR_A])
	# Assert
	assert_true(bool(result["ok"]), "应成功")
	assert_eq(cost.spends, [1], "应按模板 cost 扣一次")
	assert_eq(cost.current, 2, "灵力应从 3 降到 2")


# ═══════════════════════════════════════════════════════════════════════════════
# 点名验收 ③：灵力不足禁用且不扣费
# ═══════════════════════════════════════════════════════════════════════════════

func test_insufficient_cost_is_refused_without_charging_or_consuming() -> void:
	# Arrange——灵力为 0，丹要 1 点
	set_hp(CHAR_A, 5, 10)
	own(PILL_HEAL, 209)
	cost.current = 0
	# Act
	var result: Dictionary = _use(PILL_HEAL, [CHAR_A])
	# Assert——拒绝且说清原因
	assert_false(bool(result["ok"]), "灵力不足应拒绝")
	assert_eq(str(result["message"]), RulesScript.TEXT_NO_COST % [1, 0],
			"应报「需要 1 点，当前 0 点」")
	# Assert——什么都没动
	assert_false(bool(result["consumed"]), "拒绝时不该消耗")
	assert_eq(gsm.removals, [], "拒绝时不该动收藏")
	assert_eq(cost.spends, [], "拒绝时不该扣费")
	assert_eq(hp_of(CHAR_A), 5, "拒绝时血量应原封不动")
	assert_eq(owned_count(PILL_HEAL), 1, "拒绝时实物应还在")


func test_insufficient_cost_row_is_also_disabled_in_the_list() -> void:
	## 界面的灰显判据与结算层的二次拒绝必须同结论——否则会出现「能点但点了白点」。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	own(PILL_HEAL, 210)
	cost.current = 0
	# Act
	var row: Dictionary = entry_of(PILL_HEAL)
	var result: Dictionary = _use(PILL_HEAL, [CHAR_A])
	# Assert
	assert_false(bool(row["usable"]), "列表里应灰显")
	assert_false(bool(result["ok"]), "结算层也应拒绝")
	assert_eq(str(row["reason"]), str(result["message"]),
			"两处的句子应逐字一致（判据只有一份）")


# ═══════════════════════════════════════════════════════════════════════════════
# 拒绝路径：种类 / 实物 / 目标（校验全在动手之前）
# ═══════════════════════════════════════════════════════════════════════════════

func test_non_pill_non_artifact_entry_is_refused() -> void:
	## 传进来一条灵材或符箓——判据表根本没有对应词条，故这句话由结算层自己说。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	var entry: Dictionary = bare_entry(&"ling_cai", EvaluatorScript.EffectCategory.HEAL)
	# Act
	var result: Dictionary = use.call(&"use_entry", entry, [CHAR_A])
	# Assert
	assert_false(bool(result["ok"]), "非丹非宝应拒绝")
	assert_eq(str(result["message"]), UseScript.TEXT_BAD_KIND, "应报「不能直接使用」")
	assert_eq(gsm.removals, [], "拒绝时不该动收藏")
	assert_eq(cost.spends, [], "拒绝时不该扣费")


func test_entry_without_instance_is_refused() -> void:
	# Arrange
	set_hp(CHAR_A, 5, 10)
	var entry: Dictionary = bare_entry(RulesScript.KIND_PILL,
			EvaluatorScript.EffectCategory.HEAL, 1, 0)
	# Act
	var result: Dictionary = use.call(&"use_entry", entry, [CHAR_A])
	# Assert
	assert_false(bool(result["ok"]), "无实物应拒绝")
	assert_eq(str(result["message"]), RulesScript.TEXT_NO_INSTANCE, "应报「已无实物」")


func test_explicit_target_outside_the_pool_is_refused() -> void:
	## 显式指定的目标不在候选池里（满血 / 已阵亡 / 未知）→ 拒绝，
	## 而不是「找不到就随便治一个」。
	# Arrange——A 满血（不在丹药候选池），B 有缺口
	set_hp(CHAR_A, 10, 10)
	set_hp(CHAR_B, 5, 10)
	own(PILL_HEAL, 211)
	# Act
	var result: Dictionary = _use(PILL_HEAL, [CHAR_A])
	# Assert
	assert_false(bool(result["ok"]), "目标不在候选池应拒绝")
	assert_eq(str(result["message"]), UseScript.TEXT_TARGET_INVALID,
			"应报「所选目标已不可施术」")
	assert_eq(gsm.removals, [], "拒绝时不该动收藏")
	assert_eq(hp_of(CHAR_B), 5, "不该顺手治了别人")


func test_use_without_any_target_is_refused() -> void:
	## 全员满血 → 候选池空 → 拒绝且说明「此刻无人需要」，不消耗。
	# Arrange
	set_hp(CHAR_A, 10, 10)
	own(PILL_HEAL, 212)
	# Act
	var result: Dictionary = _use(PILL_HEAL)
	# Assert
	assert_false(bool(result["ok"]), "无人需要时应拒绝")
	assert_eq(str(result["message"]), RulesScript.TEXT_NOBODY_NEEDS, "应说明原因")
	assert_eq(gsm.removals, [], "拒绝时不该动收藏")


func test_consume_failure_leaves_everything_untouched() -> void:
	## 取物是本链路唯一会失败的动手步骤，放在最前——它失败意味着什么都还没发生。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	own(PILL_HEAL, 213)
	gsm.removable = false  # 模拟校验未开启 / 实例已被移除
	# Act
	var result: Dictionary = _use(PILL_HEAL, [CHAR_A])
	# Assert
	assert_false(bool(result["ok"]), "取不出实物应拒绝")
	assert_eq(str(result["message"]), UseScript.TEXT_CONSUME_FAILED, "应报取出失败")
	assert_eq(cost.spends, [], "取物失败时绝不该扣灵力")
	assert_eq(hp_of(CHAR_A), 5, "取物失败时不该回血")
	assert_eq(owned_count(PILL_HEAL), 1, "实物应仍在（失败不半完成）")


func test_unmodelled_pill_is_refused_by_the_settlement_layer_too() -> void:
	## 界面已灰显，但结算层是公开入口——自己再对一次类别，不靠调用方自觉。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	own(PILL_INERT, 214)
	# Act
	var result: Dictionary = _use(PILL_INERT, [CHAR_A])
	# Assert
	assert_false(bool(result["ok"]), "效果未建模应拒绝")
	assert_eq(str(result["message"]), RulesScript.TEXT_PILL_UNKNOWN, "应报「效用尚未参透」")
	assert_eq(gsm.removals, [], "拒绝时不该动收藏")


# ═══════════════════════════════════════════════════════════════════════════════
# 法宝：走增益效果（落状态表，不是写 HP）
# ═══════════════════════════════════════════════════════════════════════════════

func test_artifact_applies_attack_bonus_and_consumes_one() -> void:
	# Arrange——基础法器：攻击 +3（模板 effect_value 3，buff）
	set_hp(CHAR_A, 10, 10)
	own(ARTIFACT_BUFF, 221)
	var atk_before: int = int(roster.call(&"get_atk", CHAR_A))
	# Act
	var result: Dictionary = _use(ARTIFACT_BUFF, [CHAR_A])
	# Assert——真的加上了
	assert_true(bool(result["ok"]), "应成功：%s" % str(result["message"]))
	assert_eq(int(roster.call(&"get_atk", CHAR_A)), atk_before + 3,
			"攻击力应 +3（模板 buff 3）")
	var bonus: RefCounted = roster.call(&"get_bonus_manager")
	assert_true(bool(bonus.call(&"has_any", CHAR_A)), "应记下一笔增益")
	assert_eq(int(bonus.call(&"get_bonus", CHAR_A, BonusScript.STAT_ATK)), 3,
			"记的应是 ATK +3")
	# Assert——消耗与计费
	assert_true(bool(result["consumed"]), "consumed 应为真")
	assert_eq(owned_count(ARTIFACT_BUFF), 0, "应消耗掉那一件")
	assert_eq(cost.spends, [1], "应按模板 cost 扣一次")
	# Assert——提示
	assert_true(str(result["message"]).contains("基础法器"), "提示应含名称")
	assert_true(str(result["message"]).contains("攻击 +3"),
			"提示应含属性增量：%s" % str(result["message"]))


func test_artifact_can_buff_a_full_hp_character() -> void:
	## 满血不妨碍吃法宝（它的候选池是全部存活者）。
	# Arrange
	set_hp(CHAR_A, 10, 10)
	own(ARTIFACT_BUFF, 222)
	# Act
	var result: Dictionary = _use(ARTIFACT_BUFF)
	# Assert
	assert_true(bool(result["ok"]), "满血也应能用：%s" % str(result["message"]))
	assert_eq(int(roster.call(&"get_atk", CHAR_A)), 6, "基准 3 + 增益 3")


func test_artifact_without_effective_bonus_reports_failure_but_still_consumes() -> void:
	## 增量为 0（模板没写数值）→ 一笔都没记上 → 如实报失败。[br]
	## [br][b]但实物已取出[/b]（取物在校验之后、落效果之前）：这是本链路里唯一
	## 「consumed 为真而 ok 为假」的情形——面板据此仍要刷新（行囊里确实少了一件）。
	# Arrange——造一个 buff 数值为 0 的模板（字典形态即可，评估器两条路径都吃）
	cards.templates["artifact_inert"] = {
		"card_id": "artifact_inert", "name": "空壳法器", "type": 2, "rarity": 1,
		"cost": 1, "effect_type": &"buff", "effect_value": 0, "target_type": &"",
	}
	set_hp(CHAR_A, 10, 10)
	(gsm.collection["owned_cards"] as Array).append({
		"card_instance_id": 223, "template_id": "artifact_inert",
	})
	# Act
	var result: Dictionary = use.call(&"use_entry", entry_of_by_id("artifact_inert"),
			[CHAR_A])
	# Assert
	assert_false(bool(result["ok"]), "一笔都没加上应报失败")
	assert_eq(str(result["message"]), UseScript.TEXT_BUFF_FAILED, "应报「未能加身」")
	assert_true(bool(result["consumed"]), "实物已取出（面板据此刷新）")
	assert_eq(owned_count_by_id("artifact_inert"), 0, "实物确实少了一件")
	assert_eq(int(roster.call(&"get_atk", CHAR_A)), 3, "攻击力不该变")


func test_artifact_targeting_a_dead_character_is_refused() -> void:
	## 目标已阵亡 → 不在候选池 → 拒绝（玩家在面板上选的是当时的行）。
	# Arrange
	set_hp(CHAR_A, 10, 10)
	set_hp(CHAR_B, 4, 10)
	roster.call(&"apply_damage", CHAR_B, 99)
	own(ARTIFACT_BUFF, 224)
	# Act
	var result: Dictionary = _use(ARTIFACT_BUFF, [CHAR_B])
	# Assert
	assert_false(bool(result["ok"]), "阵亡角色不该被加持")
	assert_eq(str(result["message"]), UseScript.TEXT_TARGET_INVALID, "应报目标已不可施术")
	assert_eq(gsm.removals, [], "拒绝时不该动收藏")


# ═══════════════════════════════════════════════════════════════════════════════
# 返回契约与本链路不碰回合（只花灵力）
# ═══════════════════════════════════════════════════════════════════════════════

func test_use_result_shape_is_the_documented_contract() -> void:
	## 返回四键 [code]{ok, consumed, healed, message}[/code]——面板只显示 message，
	## 判断「要不要刷新」看 consumed。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	own(PILL_HEAL, 231)
	# Act
	var result: Dictionary = _use(PILL_HEAL, [CHAR_A])
	# Assert
	for key: String in ["ok", "consumed", "healed", "message"]:
		assert_true(result.has(key), "返回契约应含 %s 键" % key)


func test_use_does_not_touch_any_turn_bookkeeping() -> void:
	## 行囊只花灵力——阶段与回合数由战斗系统既有节奏驱动（本层连它们的句柄都没有）。[br]
	## [br][b]这条是「用后回合状态正确推进」的单元侧半边[/b]：真跑一场战斗后的
	## 阶段/回合断言在集成用例里（那里才有真实的战斗系统）。
	# Arrange
	set_hp(CHAR_A, 5, 10)
	own(PILL_HEAL, 232)
	# Act——用一个只有战斗状态表与落库的世界：任何对阶段 / 回合的触碰都会在这里崩
	var result: Dictionary = _use(PILL_HEAL, [CHAR_A])
	# Assert
	assert_true(bool(result["ok"]), "没有回合句柄的世界里也应能用药")
	assert_eq(hp_of(CHAR_A), 9, "效果照常落地")
