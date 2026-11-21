extends "res://tests/integration/tribulation/tribulation_reward_fixture.gd"
## 渡劫金卡奖励——发放与幂等（GDD §6 口径的落地验证，真实系统无桩替身）。[br]
## [br][b]覆盖[/b]：[br]
##   1. 普通渡劫胜利：收藏真多 1 张，且是金档、模板 ID 在模板池里存在；[br]
##   2. 越阶渡劫胜利：发 2 张（GDD §6「额外+1张（共2张）」）；[br]
##   3. 失败不发卡，修为按既有规则扣（max_cultivation × 0.15）、境界不变；[br]
##   4. 同一场结算两次：卡数与修为都不变（幂等）。[br]
## [br]降级（池空 / 系统缺席）见 [code]test_tribulation_reward_degradation.gd[/code]，
## 文案与结算屏见 [code]test_tribulation_reward_lines.gd[/code]——装置见基类。[br]
## [br]来源: design/gdd/tribulation-system.md §6 固定金卡奖励 + §越阶渡劫、
## ADR-0021 §_handle_tribulation_success、ADR-0006（卡牌实例与收藏入库）。


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 普通渡劫胜利——真发 1 张金卡
# ═══════════════════════════════════════════════════════════════════════════════

func test_normal_victory_adds_exactly_one_card_to_collection() -> void:
	# Arrange
	var before: int = _owned_count()
	_enter_combat()
	# Act
	ts.call("_handle_tribulation_success")
	# Assert
	assert_eq(_owned_count(), before + PoolScript.CARDS_NORMAL,
			"普通渡劫胜利应发 %d 张" % PoolScript.CARDS_NORMAL)


func test_normal_victory_card_is_gold_and_template_exists_in_pool() -> void:
	# Arrange
	var before: int = _owned_count()
	_enter_combat()
	# Act
	ts.call("_handle_tribulation_success")
	# Assert
	var added: Array = _owned().slice(before)
	assert_eq(added.size(), 1, "本场应添 1 张")
	var entry: Dictionary = added[0]
	var template_id: String = str(entry.get("template_id", ""))
	var gold_ids: Array = PoolScript.gold_ids(cs)
	assert_true(gold_ids.has(StringName(template_id)),
			"发出来的卡应在金档池内（实得 '%s'，池 %s）" % [template_id, str(gold_ids)])
	var tpl: Variant = cs.call("get_template", StringName(template_id))
	assert_not_null(tpl, "模板应能在卡牌系统查到（template_id='%s'）" % template_id)
	assert_eq(int(tpl.get("rarity")), PoolScript.GOLD_RARITY, "稀有度应为金档")


func test_normal_victory_report_lists_gained_card_with_rarity_name() -> void:
	# Arrange
	_enter_combat()
	# Act
	var report: Dictionary = ts.call("_handle_tribulation_success")
	# Assert
	var cards: Array = report[PoolScript.KEY_CARDS]
	assert_eq(cards.size(), 1, "报告应列 1 张到手卡")
	assert_eq(str(cards[0].get("rarity")), "金", "报告里的稀有度应为中文「金」")
	assert_eq(int(cards[0].get("rarity_id")), PoolScript.GOLD_RARITY, "rarity_id 应为金档值")
	assert_eq(int(gsm.player.tribulation_state), TS_SCRIPT.TribulationState.NOT_READY,
			"结算后应回到 NOT_READY")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 越阶渡劫——比普通多 1 张（GDD §6）
# ═══════════════════════════════════════════════════════════════════════════════

func test_cross_realm_victory_adds_two_cards() -> void:
	# Arrange
	var before: int = _owned_count()
	_enter_combat(true)
	# Act
	ts.call("_handle_tribulation_success")
	# Assert
	assert_eq(_owned_count(), before + PoolScript.CARDS_CROSS_REALM,
			"越阶渡劫应发 %d 张" % PoolScript.CARDS_CROSS_REALM)


func test_cross_realm_grants_exactly_one_more_than_normal() -> void:
	assert_eq(PoolScript.CARDS_CROSS_REALM, PoolScript.CARDS_NORMAL + 1,
			"GDD §6：越阶额外 +1 张")


func test_gold_pool_excludes_other_rarities() -> void:
	# Arrange / Act
	var ids: Array = PoolScript.gold_ids(cs)
	# Assert
	assert_true(ids.has(GOLD_A) and ids.has(GOLD_B), "两张金档都应在池内")
	assert_false(ids.has(WHITE_C), "白档不应进渡劫金卡池")
	assert_false(ids.has(DARK_D), "暗金不应进渡劫金卡池（境界上限那道闸不越）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 失败——不发卡、扣修为、境界不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_failure_grants_no_cards() -> void:
	# Arrange
	var before: int = _owned_count()
	_enter_combat()
	# Act
	ts.call("_handle_tribulation_failure")
	# Assert
	assert_eq(_owned_count(), before, "渡劫失败不得发卡")


func test_failure_deducts_cultivation_by_existing_rule() -> void:
	# Arrange
	gsm.player.cultivation = BASE_MAX
	_enter_combat()
	# Act
	ts.call("_handle_tribulation_failure")
	# Assert
	var penalty: int = int(floor(float(BASE_MAX) * SettlementScript.FAILURE_PENALTY_RATIO))
	assert_eq(_cultivation(), BASE_MAX - penalty,
			"失败应按 max_cultivation × %f 扣" % SettlementScript.FAILURE_PENALTY_RATIO)
	assert_eq(_realm(), 1, "失败境界不变")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 同一场结算两次——幂等
# ═══════════════════════════════════════════════════════════════════════════════

func test_double_success_settle_keeps_card_count() -> void:
	# Arrange
	var before: int = _owned_count()
	_enter_combat()
	ts.call("_handle_tribulation_success")
	var after_first: int = _owned_count()
	# Act——第二次（场景重入 / 重复 battle_end）
	ts.call("_handle_tribulation_success")
	# Assert
	assert_eq(_owned_count(), after_first, "重复结算不得再发一遍卡")
	assert_eq(_owned_count(), before + PoolScript.CARDS_NORMAL, "且总数与首次一致")


func test_double_success_settle_does_not_level_realm_twice() -> void:
	# Arrange
	_enter_combat()
	ts.call("_handle_tribulation_success")
	var realm_after_first: int = _realm()
	# Act
	ts.call("_handle_tribulation_success")
	# Assert
	assert_eq(_realm(), realm_after_first, "重复结算不得连升两级")


func test_double_failure_settle_keeps_cultivation() -> void:
	# Arrange
	gsm.player.cultivation = BASE_MAX
	_enter_combat()
	ts.call("_handle_tribulation_failure")
	var after_first: int = _cultivation()
	# Act
	ts.call("_handle_tribulation_failure")
	# Assert
	assert_eq(_cultivation(), after_first, "重复结算不得连扣两次修为")


func test_settle_outside_combat_is_ignored() -> void:
	# Arrange——NOT_READY（没在打渡劫）——普通战斗撞上来的 battle_ended 走这条
	var before: int = _owned_count()
	# Act
	ts.call("_handle_tribulation_success")
	# Assert
	assert_eq(_realm(), 1, "非渡劫流程不得进境")
	assert_eq(_owned_count(), before, "非渡劫流程不得发卡")
