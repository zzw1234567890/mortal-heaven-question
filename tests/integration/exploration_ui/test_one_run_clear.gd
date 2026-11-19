extends "res://tests/integration/exploration_ui/one_run_combat_fixture.gd"
## 一周目冒烟（通关段）—— 打赢首图 Boss → 本图通关 → 下一张图解锁。[br]
## [br][b]为什么单独一文件[/b]：本段要挂真实战斗场景（另一层装置，见
## [code]one_run_combat_fixture.gd[/code]），且它验证的是链路终点——「打赢之后
## 这条路还走得下去吗」。[br]
## [br][b]覆盖[/b]：[br]
##   6. 打赢（真实出牌链路）→ 胜利 / 首通入账 / 通关计数 +1；[br]
##   7. 回选图 → 下一张图由锁变可进（读选图界面那张卡的条目，前后对比）。[br]
##
## 来源: design/gdd/exploration-system.md §5、exploration-ui-system.md §7、
## ADR-0014 §决策 5。


# ═══════════════════════════════════════════════════════════════════════════════
# 6. 打赢这一场 → 本图通关
# ═══════════════════════════════════════════════════════════════════════════════

func test_winning_boss_battle_settles_the_map() -> void:
	# Arrange——走完真实开局 → 走到 Boss → 确认开战 → 挂战斗场景出战
	start_new_run()
	prepare_battle_path()
	walk_to_boss()
	confirm_popup()
	mount_combat_and_deploy()
	var before: Dictionary = _before_battle()

	# Act——真实战斗链路：点击出牌 → 结束出牌 → 全灭 → 结算屏返回探索
	var turns: int = run_battle_to_end()
	assert_gt(turns, 0, "前置：这一仗应真的打了若干回合")
	return_to_exploration()

	# Assert——胜利经真实结算链路回写探索侧[br]
	# [br][b]通关后 current_map 已清空[/b]（结算把导航状态收了尾），所以下面的
	# 通关态一律按首图 ID 读——不读「当前图」，那时已经没有当前图了。
	var map_id: StringName = first_map_id()
	assert_true(battle_won(), "Boss 战应打出胜利结局（不是战败/撤退）")
	assert_eq(clear_count(map_id), int(before["clear"]) + 1, "通关后本图通关次数应 +1")
	assert_true(is_first_clear(map_id), "首次通关应写下首通标记")
	assert_gt(int(gsm.player.cultivation), int(before["cultivation"]),
			"通关应结算修为（首通档位给修为）")
	assert_gt(ling_shi(), int(before["ling_shi"]), "通关应结算灵石")
	assert_gt(owned_count_of(FIRST_CLEAR_CARD), int(before["card"]),
			"首通彩头卡应进收藏（至少一项奖励入账）")
	assert_eq(str(gsm.exploration.get("current_map", "")), "",
			"通关后本图导航状态应清空（回选图重来）")


# ═══════════════════════════════════════════════════════════════════════════════
# 7. 回选图 → 下一张图由锁变可进
# ═══════════════════════════════════════════════════════════════════════════════

func test_next_map_unlocks_after_clearing_the_first() -> void:
	# Arrange——同一段链路，先在「未通关」态取一次界面条目
	start_new_run()
	prepare_battle_path()
	walk_to_boss()
	var gated: StringName = next_gated_map_id()
	assert_ne(str(gated), "", "前置：首图应有后置地图（血渊秘境）")
	var before_entry: Dictionary = map_entry(gated)
	assert_false(before_entry.is_empty(), "前置：选图界面上应有 %s 这张卡" % gated)
	assert_false(bool(before_entry.get("is_unlocked", false)),
			"前置：首图未通关时 %s 的卡应是锁着的" % gated)
	assert_ne(str(before_entry.get("locked_hint", "")), "",
			"前置：锁着时应给出「缺什么」的文案")

	# Act——通关首图
	confirm_popup()
	mount_combat_and_deploy()
	run_battle_to_end()
	return_to_exploration()
	assert_true(is_first_clear(first_map_id()), "前置：首图应已通关")

	# Assert——同一张卡由锁变可进（界面条目，不是另算一遍）
	var after_entry: Dictionary = map_entry(gated)
	assert_false(after_entry.is_empty(), "%s 这张卡仍应在界面上" % gated)
	assert_true(bool(after_entry.get("is_unlocked", false)),
			"通关首图后 %s 的卡应解锁（前置已通关）" % gated)
	assert_eq(str(after_entry.get("locked_hint", "")), "",
			"解锁后不应再给「缺什么」的文案")
	assert_true(bool(after_entry.get("prerequisite_cleared", false)),
			"前置通关这一条应如实为真")
	assert_true(bool(map_entry(first_map_id()).get("is_cleared", false)),
			"首图那张卡应显示为已通关")
	assert_eq(int(map_entry(first_map_id()).get("clear_count", 0)), 1,
			"首图卡片上的通关次数应为 1（首通而非刷图）")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 战前状态快照（通关后逐项比对增量）。[br]
## [br][b]按首图 ID 读[/b]：结算跑完 [code]current_map[/code] 就空了，
## [method clear_count] 的缺省参数（读当前图）那时只会拿到 0。
func _before_battle() -> Dictionary:
	var map_id: StringName = first_map_id()
	return {
		"ling_shi": ling_shi(),
		"cultivation": int(gsm.player.cultivation),
		"card": owned_count_of(FIRST_CLEAR_CARD),
		"clear": clear_count(map_id),
	}
