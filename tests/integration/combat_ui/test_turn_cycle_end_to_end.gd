extends "res://tests/integration/combat_ui/turn_cycle_fixture.gd"
## 回合循环：我方结束 → 敌方行动 → 回到我方，费用与手牌按 GDD 重置。[br]
## [br][b]本文件的核心断言[/b]：「敌方决策 → 真的掉血」这条此前断开的链
## （[code]execute_turn[/code] 的行动被丢弃，玩家看不到任何敌方伤害）。[br]
## 夹具见 [code]turn_cycle_fixture.gd[/code]。


func before_each() -> void:
	setup()


func after_each() -> void:
	teardown()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 我方结束回合 → 敌方行动 → 回到我方
# ═══════════════════════════════════════════════════════════════════════════════

## 结束出牌阶段后，敌方在其行动阶段真的造成了伤害，且回合回到我方（turn+1）。[br]
## [br][b]这条是本轮的核心[/b]：敌方回合此前是黑盒一跳（决策被丢弃、零伤害）。
func test_end_turn_runs_enemy_then_returns_to_player() -> void:
	# Arrange——单个敌人，攻击力 4，我方防御 0 → 每次 4 点
	var enemies: Array = [_enemy_state(&"grunt", 0)]
	_start(enemies)
	var hp_before: int = _hp(CHAR_A)
	var actions: Array = _capture_enemy_actions()
	var turns: Array = _capture_turn_started()
	_advance_to(2)  # → 出牌阶段
	# Act——玩家结束回合（阶段 2 → 3 → 4 → 5 敌方行动 → 6 结束 → 下一回合准备）
	cs.call("confirm_end_turn")
	_advance_to(0)  # 绕回 PREPARATION（新回合）
	# Assert——敌方真的造成了伤害
	assert_eq(actions.size(), 1, "敌方行动结算一次（每个存活敌人一次）")
	assert_eq(int(actions[0]["damage"]), ENEMY_ATK, "伤害 = 攻击力 − 0 防御")
	assert_eq(_hp(CHAR_A) + _hp(CHAR_B), hp_before * 2 - ENEMY_ATK,
			"我方总 HP 减少了敌方造成的伤害")
	# Assert——回合切换信号带新回合号
	assert_eq(turns.size(), 1, "回合切换信号发射一次")
	assert_eq(int(turns[0]["turn"]), 2, "新回合号为 2")


## 费用按 GDD 重置：回合结束回满到境界上限（先手第 2 回合）。[br]
## [br][b]为什么单测这一条[/b]：费用是玩家能感知的最直接的回合边界——
## 不重置会让「这回合没花完的费」变成下回合的额外资源（GDD 明令不累积）。
func test_cost_refills_at_turn_end() -> void:
	# Arrange——上限由 battle_start 经 RealmSystem 现读（境界费用），故这里
	# 不硬编码数字，读实际上限来构造「花掉一部分」的前置
	_start([_enemy_state(&"grunt", 0)])
	var cap: int = CostSystem.get_max_cost()
	assert_true(cap > 0, "前置：费用上限已由开战激活（读到 %d）" % cap)
	_advance_to(2)
	CostSystem.spend(1)
	assert_eq(CostSystem.get_current_cost(), cap - 1, "前置：花掉 1 点")
	# Act——结束回合并绕回下一回合
	cs.call("confirm_end_turn")
	_advance_to(0)
	# Assert
	assert_eq(CostSystem.get_current_cost(), cap, "回合结束费用回满到上限")


## 手牌在下一回合的抽牌阶段按抽牌表补充。[br]
## [br][b]第 2 回合基础 2 张[/b]（先手第 1 回合为 0——开局手牌已单独发给）。
func test_hand_drawn_next_turn() -> void:
	# Arrange
	_start([_enemy_state(&"grunt", 0)])
	cs.call("deal_opening_hand")
	var opening: int = cs.call("get_hand").size()
	assert_eq(opening, Economy.OPENING_HAND_FIRST, "先手开局手牌 4 张")
	_advance_to(2)
	# Act——结束回合，绕回下一回合并进入其抽牌阶段
	cs.call("confirm_end_turn")
	_advance_to(1)  # 新回合的 DRAW 阶段
	# Assert
	assert_eq(cs.call("get_hand").size(), opening + Economy.DRAW_BASE,
			"第 2 回合抽牌阶段补充 %d 张" % Economy.DRAW_BASE)


## 结束出牌阶段后回到我方回合时，再次处于可出牌的阶段（阶段 2）。[br]
## [br][b]为什么值得断言[/b]：回合循环若在敌方行动后卡住（不回绕），
## 玩家会永久失去操作权——这条是「回到我方」的可操作性证明。
func test_returns_to_player_play_phase() -> void:
	# Arrange
	_start([_enemy_state(&"grunt", 0)])
	_advance_to(2)
	# Act
	cs.call("confirm_end_turn")
	_advance_to(2)  # 下一回合的出牌阶段
	# Assert
	assert_eq(int(cs.call("get_current_phase")), 2, "回到出牌阶段")
	assert_eq(int(cs.call("get_turn_number")), 2, "已是第 2 回合")


## 回合结束手牌超限 → 弃至上限，弃的牌进弃牌堆（GDD card-system §手牌限制）。[br]
## [br][b]弃最旧的[/b]：手牌头部先抽到，抽牌追加在尾部——故 12 张时弃掉的是
## 最早的两张，而不是刚抽到的。
func test_hand_overflow_discarded_at_turn_end() -> void:
	# Arrange——注入 12 张手牌（超上限 2 张）
	_start([_enemy_state(&"grunt", 0)])
	var hand: Array = []
	var instances: Dictionary = {}
	for i: int in range(12):
		var cid: int = 9200 + i
		hand.append({"card_instance_id": cid, "cost": 0})
		instances[cid] = {"card_instance_id": cid, "cost": 0, "template_id": "t"}
	cs.call("set_card_instances", instances)
	cs.call("set_hand", hand)
	var oldest_two: Array = [9200, 9201]
	_advance_to(2)
	# Act——结束回合并走完 END
	cs.call("confirm_end_turn")
	_advance_to(0)
	# Assert
	assert_eq(cs.call("get_hand").size(), Economy.HAND_LIMIT,
			"手牌弃至上限 %d 张" % Economy.HAND_LIMIT)
	assert_eq(cs.call("get_discard_pile").size(), 2, "弃掉 2 张并进弃牌堆")
	var remaining: Array = []
	for card: Dictionary in cs.call("get_hand"):
		remaining.append(int(card["card_instance_id"]))
	for cid: int in oldest_two:
		assert_false(cid in remaining, "最旧的牌 %d 已被弃置" % cid)
	assert_true(9211 in remaining, "最新抽到/最晚的牌留在手上")

