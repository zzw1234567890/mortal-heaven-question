extends GutTest
## 回复点结算的公式与边缘情况 —— GDD §公式 7 的纯函数侧。[br]
## [br][b]覆盖[/b]：[br]
##   · 回复量 = [code]floor(已损失 × 0.5)[/code]（含向下取整与零缺口）；[br]
##   · 阵亡角色不计入已损失总量、也不被「回复」复活；[br]
##   · 满血角色不参与；越界存档值（current > max）按上限参与，不放大缺口；[br]
##   · 总额一次算、逐角色分配——[code]total_heal == heal_for(total_lost)[/code]
##     恒成立（逐角色各 floor 会掉零头）；[br]
##   · 分配不超各自上限；字符串键（存档形态）与整数键都认。[br]
## [br]来源: design/gdd/exploration-system.md §公式 7 / §8 边界、
## [code]combat_hp_carryover.gd[/code] 的存储形态（字符串键 + current/max）。

const RestScript := preload("res://src/feature/exploration/exploration_rest.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 公式
# ═══════════════════════════════════════════════════════════════════════════════

func test_heal_for_returns_half_of_lost_floored() -> void:
	assert_eq(RestScript.heal_for(18), 9, "18 点缺口回复 9 点")
	assert_eq(RestScript.heal_for(3), 1, "3 点缺口向下取整为 1")
	assert_eq(RestScript.heal_for(1), 0, "1 点缺口不足半点，回复 0")


func test_heal_for_zero_or_negative_lost_is_zero() -> void:
	assert_eq(RestScript.heal_for(0), 0, "无缺口回复 0")
	assert_eq(RestScript.heal_for(-5), 0, "异常负值不得返回负回复量")


# ═══════════════════════════════════════════════════════════════════════════════
# 计划（纯函数）
# ═══════════════════════════════════════════════════════════════════════════════

func test_plan_excludes_dead_characters_from_lost_and_heal() -> void:
	# Arrange——A 阵亡、B 残血（GDD 公式 7：阵亡角色不计入）
	var planned: Dictionary = RestScript.plan({
		1: {"current_hp": 0, "max_hp": 10},
		2: {"current_hp": 2, "max_hp": 10},
	})
	# Assert——缺口只算 B 的 8 点，回复 4 点且全部给 B
	assert_eq(int(planned["total_lost"]), 8, "阵亡角色的缺口不计入")
	assert_eq(int(planned["total_heal"]), 4, "回复量为存活角色缺口的 floor(8 × 0.5)")
	var allocation: Dictionary = planned["plan"]
	assert_false(allocation.has(1), "阵亡角色不得被「回复」（复活不归回复点）")
	assert_eq(int(allocation.get(2, 0)), 4, "存活角色拿到全部额度")


func test_plan_skips_full_hp_characters() -> void:
	var planned: Dictionary = RestScript.plan({
		1: {"current_hp": 10, "max_hp": 10},
		2: {"current_hp": 6, "max_hp": 10},
	})
	assert_eq(int(planned["total_lost"]), 4, "满血角色不计入缺口")
	assert_false((planned["plan"] as Dictionary).has(1), "满血角色不出现在分配表里")


func test_plan_total_heal_matches_heal_for_even_with_rounding() -> void:
	# Arrange——三名角色各缺 3 点：逐角色 floor 会得到 1+1+1=3，而总额 floor(9×0.5)=4
	var planned: Dictionary = RestScript.plan({
		1: {"current_hp": 7, "max_hp": 10},
		2: {"current_hp": 7, "max_hp": 10},
		3: {"current_hp": 7, "max_hp": 10},
	})
	# Assert——总额口径唯一：total_heal 必须等于 heal_for(total_lost)
	assert_eq(int(planned["total_lost"]), 9, "总缺口 9")
	assert_eq(int(planned["total_heal"]), RestScript.heal_for(9),
			"实际回复量与公式一致（不因逐角色取整掉零头）")
	assert_eq(int(planned["total_heal"]), 4, "9 点缺口回复 4 点")


func test_plan_allocation_never_exceeds_character_gap() -> void:
	# Arrange——A 缺 1 点、B 缺 19 点，额度 10 点：A 只该拿 1，余下给 B
	var planned: Dictionary = RestScript.plan({
		1: {"current_hp": 9, "max_hp": 10},
		2: {"current_hp": 1, "max_hp": 20},
	})
	var allocation: Dictionary = planned["plan"]
	assert_eq(int(allocation.get(1, 0)), 1, "缺口小的角色只补到满，不溢出")
	assert_eq(int(allocation.get(2, 0)), 9, "余额给下一个角色")
	assert_eq(int(planned["total_heal"]), 10, "额度恰好用尽（总额 10 ≤ 总缺口 20）")


func test_plan_treats_out_of_range_hp_as_capped() -> void:
	# Arrange——存档里 current > max（不应放大缺口）
	var planned: Dictionary = RestScript.plan({1: {"current_hp": 99, "max_hp": 10}})
	assert_eq(int(planned["total_lost"]), 0, "越界存档值按上限参与，缺口为 0")
	assert_true((planned["plan"] as Dictionary).is_empty(), "无缺口时分配表为空")


func test_plan_accepts_string_keys_from_save_file() -> void:
	# 存档 JSON 的对象键必为字符串——读侧必须两种键都认
	var planned: Dictionary = RestScript.plan({"7701": {"current_hp": 4, "max_hp": 10}})
	assert_eq(int(planned["total_lost"]), 6, "字符串键的缺口应被读到")
	assert_eq(int((planned["plan"] as Dictionary).get(7701, 0)), 3, "分配键归一为整数角色 ID")


func test_plan_ignores_malformed_entries() -> void:
	# 非数字键 / 非字典值 / 缺 max_hp 的条目一律跳过（不臆造数值）
	var planned: Dictionary = RestScript.plan({
		"hero": {"current_hp": 1, "max_hp": 10},
		1: "not a dict",
		2: {"current_hp": 1},
	})
	assert_eq(int(planned["total_lost"]), 0, "非法条目不得贡献缺口")
	assert_true((planned["plan"] as Dictionary).is_empty(), "非法条目不得产生分配")


# ═══════════════════════════════════════════════════════════════════════════════
# 结算（读 → 计划 → 写回）
# ═══════════════════════════════════════════════════════════════════════════════

func test_rest_at_node_writes_healed_hp_through_gsm() -> void:
	# Arrange——两名角色各 1/10，走真实 GSM 写入通路
	var before: Dictionary = (GameStateManager.player as Dictionary).duplicate(true)
	GameStateManager.player.character_hp = {
		"7701": {"current_hp": 1, "max_hp": 10},
		"7702": {"current_hp": 1, "max_hp": 10},
	}
	var rest: RefCounted = RestScript.new(null)
	# Act
	var healed: int = int(rest.call(&"rest_at_node", 303))
	# Assert——返回实际回复量，且真的写进了 GSM（且不超上限）
	assert_eq(healed, 9, "全队回复 floor(18 × 0.5) = 9 点")
	var table: Dictionary = GameStateManager.player.character_hp
	for key: String in ["7701", "7702"]:
		var hp: int = int((table[key] as Dictionary).get("current_hp", -1))
		assert_true(hp <= 10, "角色 %s 的 HP 不得超过上限" % key)
	assert_eq(int((table["7701"] as Dictionary).get("current_hp", 0))
			+ int((table["7702"] as Dictionary).get("current_hp", 0)), 11,
			"两人合计血量应为 2 + 9")
	# 还原
	GameStateManager.player = before


func test_rest_at_node_on_full_party_writes_nothing() -> void:
	var before: Dictionary = (GameStateManager.player as Dictionary).duplicate(true)
	GameStateManager.player.character_hp = {"7701": {"current_hp": 10, "max_hp": 10}}
	var rest: RefCounted = RestScript.new(null)
	assert_eq(int(rest.call(&"rest_at_node", 303)), 0, "无缺口时返回 0")
	assert_eq(int((GameStateManager.player.character_hp["7701"] as Dictionary)
			.get("current_hp", -1)), 10, "满血角色不应被写坏")
	GameStateManager.player = before
