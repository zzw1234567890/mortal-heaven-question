extends "res://tests/unit/combat_system/resume_playable_fixture.gd"
## 「续战读档前后本回合可出牌数相等」的落地验收。[br]
## [br][b]补的断链[/b]：续战快照存了阶段 / 回合 / 费用 / 三堆牌，读档也逐项落位——
## 但[b]落位之后紧接着把自动推进放行了[/b]。玩家主动阶段（出牌 / 攻击声明）本不该
## 自动推进，这一放行就把那张存档[b]当场推走[/b]：攻击声明阶段的
## [code]_attack_queue[/code] 刚被 [code]battle_start[/code] 清空 → 3→4 空真放行 →
## 一路滑到下一回合的出牌阶段（还多抽一轮牌）。症状是「读档回来又能出一张」——
## 正是本组要钉住的那个数。[br]
## [br][b]期望值的来源[/b]：可出张数[b]现读活着的系统[/b]（阶段 / 费用 / 手牌三者共同
## 决定），不是手抄常量——手抄只能证明「我以为的那几个数」。计法见
## [code]resume_playable_fixture.playable_count[/code]。[br]
## [br][b]覆盖[/b]：[br]
##   1. 攻击声明阶段存的档 → 读档原地停在攻击声明（不滑走），可出张数相等；[br]
##   2. 出牌阶段存的档（费已花光）→ 读档仍在出牌阶段，可出张数为 0 且不为负数；[br]
##   3. 自动阶段（抽牌等）照样要能自己往前走——修复不能把自动推进一起焊死；[br]
##   4. 出过的牌有去处：弃牌堆随读档回来（「还能出几张」的另一半）。[br]
## [br]装置见 [code]resume_playable_fixture.gd[/code]（真 CombatSystem + 真 Autoload，
## 不注入桩）。[br]
## [br]注：[code]cs[/code] / [code]PayloadScript[/code] / 角色 ID 段由夹具提供，
## 此处不重复声明——GDScript 子类重复同名成员是解析错误，整个文件会被 GUT 静默忽略。[br]
## [br]来源: ADR-0008 §阶段状态机 §子系统编排顺序、本轮「读档少出一张 / 多出一张」。


# ═══════════════════════════════════════════════════════════════════════════════
# 攻击声明阶段：存档前后可出张数逐位相等
# ═══════════════════════════════════════════════════════════════════════════════

## 本组的主症：在攻击声明阶段存档（出过牌、点过「结束回合」），读档后不得再多出一次
## 出牌机会。[br]
## [br][b]断言的是可出张数而不是阶段号[/b]：阶段号只是它的一条成因——真正对玩家有
## 意义的是「这一回合我还能动几张牌」。
func test_save_in_attack_declaration_keeps_playable_count() -> void:
	# Arrange——出掉一张（费用 2→1），点「结束回合」推进到攻击声明
	start_battle()
	drive_to(2)
	var hand_before_play: int = (cs.call("get_hand") as Array).size()
	var first: int = hand_ids(cs)[0]
	assert_true(bool(cs.call("play_card", first, [])), "前置：出一张 1 费牌成功")
	assert_eq(CostSystem.get_current_cost(), 1, "前置：费用确实花掉了 1 点")
	cs.call("confirm_end_turn")
	assert_eq(int(cs.call("get_current_phase")), 3, "前置：停在攻击声明阶段")
	var before: int = playable_count(cs)
	assert_eq(before, 0, "前置：非出牌阶段本回合可出 0 张")
	assert_eq((cs.call("get_hand") as Array).size(), hand_before_play - 1,
			"前置：手牌确实少了一张（出掉的牌已进弃牌堆）")
	assert_eq(affordable_in_hand(cs), (cs.call("get_hand") as Array).size(),
			"前置：剩下那几张都还打得起（1 费 × 1 点余额）——读档后若滑到下一回合成 6 张，差额才看得见")
	# Act——抓快照 → 按续战顺序重建 → 放行自动推进
	var payload: Dictionary = capture_snapshot(cs).battle_resume
	var restored: Node = rebuild(payload)
	assert_eq(int(restored.call("get_current_phase")), 3,
			"重建瞬间应停在存档那个阶段（落位不重放阶段入口）")
	release_auto_advance(restored)
	await await_frames()
	# Assert——放行之后仍停在攻击声明（玩家主动阶段不自动推进）
	assert_eq(CostSystem.get_current_cost(), 1, "费用应仍是存档那一刻的 1 点")
	assert_eq(int(restored.call("get_current_phase")), 3,
			"读档后不得把攻击声明阶段推走（推走 = 一路滑到下一回合，白白多出一轮出牌）")
	assert_eq(playable_count(restored), before,
			"【本症】存档前还能出 %d 张，读档后也必须是 %d 张" % [before, before])
	assert_eq(affordable_in_hand(restored), affordable_in_hand(cs),
			"手里那几张的费用口径也要原样回来（阶段对了但费不对同样是漂移）")


## 攻击声明阶段的「牌还没出完」形态：手里还有牌、费用也还有，只是玩家点了结束回合。
## 读档后不得把这些牌变成可以接着出的。
func test_save_in_attack_declaration_with_cards_left_still_frozen() -> void:
	# Arrange——一张不出，直接点「结束回合」
	start_battle()
	drive_to(2)
	var hand_size: int = (cs.call("get_hand") as Array).size()
	assert_gt(hand_size, 0, "前置：手里还有牌（否则这条与费花光那条重复）")
	cs.call("confirm_end_turn")
	var before: int = playable_count(cs)
	# Act
	var payload: Dictionary = capture_snapshot(cs).battle_resume
	var restored: Node = rebuild(payload)
	release_auto_advance(restored)
	await await_frames()
	# Assert——原地不动，可出张数相等
	assert_eq(int(restored.call("get_turn_number")), int(cs.call("get_turn_number")),
			"读档不得把回合数推走（推走意味着白白多抽一轮牌）")
	assert_eq((restored.call("get_hand") as Array).size(), hand_size,
			"手牌应原样接管（顺序与张数都取存档值）")
	assert_eq(playable_count(restored), before,
			"【本症】存档前还能出 %d 张，读档后也必须是 %d 张" % [before, before])


# ═══════════════════════════════════════════════════════════════════════════════
# 出牌阶段：费花光时也不能凭空回费
# ═══════════════════════════════════════════════════════════════════════════════

## 在出牌阶段把费用花光后存档（费用耗尽正是这回合「出不动了」的形态）。[br]
## [br][b]为什么单独一条[/b]：这一条的失败形态与上一条相反——上一条是「多出一整个
## 回合」，这一条是「费用被回满」（读档落到 [code]init_for_battle[/code] 那条链上），
## 两者由不同的代码路径决定，一条断言盖不住另一条。
func test_save_in_play_with_cost_spent_keeps_zero_playable() -> void:
	# Arrange——连出两张把 2 费花光
	start_battle()
	drive_to(2)
	assert_eq(CostSystem.get_max_cost(), 2, "前置：费用上限 2（练气期）")
	var ids: Array = hand_ids(cs)
	assert_gte(ids.size(), 2, "前置：手上至少两张牌")
	assert_true(bool(cs.call("play_card", int(ids[0]), [])), "前置：第 1 张出牌成功")
	assert_true(bool(cs.call("play_card", int(ids[1]), [])), "前置：第 2 张出牌成功")
	assert_eq(CostSystem.get_current_cost(), 0, "前置：费用已花光")
	assert_eq(int(cs.call("get_current_phase")), 2, "前置：仍停在出牌阶段")
	var left: Array = cs.call("get_hand")
	assert_gt(left.size(), 0, "前置：手里还有牌（只是打不起了）")
	assert_gt(card_cost(left[0]), 0,
			"前置：这些牌[b]卡面本身要费[/b]——否则「读档后为 0 张」是被 0 费卡撑住的，"
			+ "证明不了费用被回满")
	var before: int = playable_count(cs)
	assert_eq(before, 0, "前置：费花光时一张也出不动")
	# Act
	var payload: Dictionary = capture_snapshot(cs).battle_resume
	var restored: Node = rebuild(payload)
	release_auto_advance(restored)
	await await_frames()
	# Assert——费用不回升，可出张数相等
	assert_eq(CostSystem.get_current_cost(), 0,
			"读档不得把费用回满（回满 = 白送一轮出牌）")
	assert_eq(playable_count(restored), before,
			"【本症】存档前还能出 %d 张，读档后也必须是 %d 张" % [before, before])


## 出过的牌进了弃牌堆——「还能出几张」的另一半：出的牌不能凭空回到手里。[br]
## [br][b]为什么要单独钉[/b]：手牌张数对了但弃牌堆是空的时候，[code]_draw_cards[/code]
## 抽空返还会把那些牌重新洗回牌堆，等于把出过的牌还给了玩家。
func test_played_cards_stay_in_discard_after_resume() -> void:
	# Arrange
	start_battle()
	drive_to(2)
	var discard_before: int = (cs.call("get_discard_pile") as Array).size()
	cs.call("play_card", int(hand_ids(cs)[0]), [])
	var discard_after_play: int = (cs.call("get_discard_pile") as Array).size()
	assert_eq(discard_after_play, discard_before + 1, "前置：出掉的牌落进弃牌堆")
	# Act
	var payload: Dictionary = capture_snapshot(cs).battle_resume
	var restored: Node = rebuild(payload)
	# Assert——三堆逐 ID 相等（含顺序）
	assert_eq(restored.call("get_hand"), cs.call("get_hand"), "手牌应逐 ID 相等")
	assert_eq(restored.call("get_discard_pile"), cs.call("get_discard_pile"),
			"弃牌堆应逐 ID 相等（出过的牌不得读档后回到牌堆）")
	assert_eq((restored.call("get_discard_pile") as Array).size(), discard_after_play,
			"弃牌堆张数应取存档值")


# ═══════════════════════════════════════════════════════════════════════════════
# 反向守卫：修复不得把自动推进一起焊死
# ═══════════════════════════════════════════════════════════════════════════════

## 自动阶段（抽牌）照旧要自己往前走——「玩家阶段不排下一格」不能变成「一律不排」。[br]
## [br][b]为什么必须有这条[/b]：修复的形态是「[code]resume_auto_advance[/code] 多了
## 一个判据」，判据写宽了（比如把所有阶段都拦下）会让读档回来的抽牌阶段永远停住——
## 那是比原症更糟的死局，而上面几条断言一条都不会红。
func test_auto_phase_still_advances_after_resume() -> void:
	# Arrange——停在抽牌阶段（自动阶段）
	start_battle()
	drive_to(1)
	assert_eq(int(cs.call("get_current_phase")), 1, "前置：停在抽牌阶段")
	var payload: Dictionary = capture_snapshot(cs).battle_resume
	assert_eq(int(payload[PayloadScript.KEY_PHASE]), 1, "前置：快照记的是抽牌阶段")
	# Act
	var restored: Node = rebuild(payload)
	assert_eq(int(restored.call("get_current_phase")), 1, "重建瞬间应停在抽牌阶段")
	release_auto_advance(restored)
	await await_frames()
	# Assert——自动阶段自己往前走（抽牌→出牌）
	assert_eq(int(restored.call("get_current_phase")), 2,
			"自动阶段读档后仍须自己推进（判据写宽会把抽牌阶段焊死）")
	assert_eq(int(restored.call("get_turn_number")), int(payload[PayloadScript.KEY_TURN]),
			"推进的是阶段不是回合（同一回合内往前走一格）")


# ═══════════════════════════════════════════════════════════════════════════════
# 敌方意图：本场没有「可被重摇的意图」这回事（结论见断言注释）
# ═══════════════════════════════════════════════════════════════════════════════

## 存档里[b]没有敌方意图段[/b]，快照里也不该有——敌方意图在本实现里不是一份可存的状态。[br]
## [br][b]判定依据（本轮核对过，结论是「不该改代码」）[/b]：[br]
##   · 意图是[b]当场决策[/b]、不是提前公告的状态：敌方行动由
##     [code]ai_decision_engine.gd:25 execute_turn[/code] 在 ENEMY_TURN 入口现算
##     （技能评分 + 目标选择，含 [code]:222[/code] 的加权随机与 [code]:243[/code]
##     的撤退掷骰），没有任何对象把它存下来；[br]
##   · 战斗侧[b]拿到就立刻消费[/b]：[code]combat_enemy_turn.gd:55 run[/code] 调
##     [code]execute_turn[/code] 后马上 [code]:66 resolve[/code] 逐条结算，行动指令
##     不落地、不出现在任何查询面上；[br]
##   · 玩家[b]看不到未来的意图[/b]（这是他无从重摇的关键）：全库没有任何「下回合
##     敌人要干什么」的展示面；[code]enemy_action_resolved[/code]
##     （[code]combat_system.gd:107[/code]）是[b]事后战报[/b]（谁打了谁、掉多少血），
##     唯一的生产订阅方 [code]enemy_action_broadcast.gd[/code]（[code]:126[/code]
##     处理器）只渲染已经发生的事；[br]
##   · 开战那一刻 [code]battle_start[/code]（[code]combat_system.gd:389[/code]）
##     只把名册写进 [code]_battle_enemy_roster[/code]（[code]:525[/code]
##     [code]_capture_battle_rosters[/code]），没有任何决策结果被记下。[br]
## [br][b]因此「读档重摇敌人行为」不是本实现里的漏洞[/b]：敌方行动发生在
## ENEMY_TURN 这一格的入口，而玩家能存档的时刻（探索/暂停菜单）都在那之前；
## 他既看不到敌人要出什么，读档后也不会得到与「不读档」不同的结局。公平性不受影响。[br]
## [br][b]本条断言锁住的是「不存意图」这个既有口径 + 「看得见的盘面逐位复现」[/b]：
## 将来若有人给快照加了意图段（无论是提前公告还是防重摇），前一半会红，逼他先回答
## 「玩家现在看得见意图了吗」；后一半则不论怎么改都必须成立——可见信息不得漂移。
func test_snapshot_carries_no_enemy_intent_section() -> void:
	# Arrange——推到敌方回合。这一格的入口已经把 AI 决策跑掉并逐条结算了
	# （[code]combat_phase_manager.gd:101 enter_phase(ENEMY_TURN)[/code] → 执行），
	# 所以此刻盘面上是「敌人已经出过手」的结果态——正是玩家能看见的那部分。
	start_battle()
	drive_to(5)
	assert_eq(int(cs.call("get_current_phase")), 5, "前置：停在敌方回合")
	# Act
	var payload: Dictionary = capture_snapshot(cs).battle_resume
	# Assert——载荷里没有意图段（键名口径与形状模块同源，不另起名）
	for intent_key: String in ["intent", "enemy_intent", "next_action", "telegraph"]:
		assert_false(payload.has(intent_key),
				"存档不得带敌方意图段（%s）——本实现的意图是敌方回合入口现算的，"
				% intent_key + "存下来反而会让「读档重摇」从无到有")
	# Assert——公平性落在「能看见的那部分逐位复现」：读档回来的盘面与存档那一刻相同
	var before: Dictionary = _hp_board(cs)
	var restored: Node = rebuild(payload)
	assert_eq(_hp_board(restored), before,
			"读档回来的敌我血量应与存档那一刻逐一相同——玩家看得见的盘面原样复现，"
			+ "他既看不到也没法改变敌人接下来要做什么（意图不可见 ⇒ 无从重摇）")
	assert_false(before.is_empty(), "前置：盘面确实取到了血（否则上面那条断言是空转）")


## 本场敌我当前血量（现读状态表全量快照——与结算同一取数口径）。[br]
## [br][b]键为 [code]side:character_id[/code][/b]：两侧 ID 段可能相撞，
## 只按 ID 归并会把敌我混成一格。
func _hp_board(p_combat: Node) -> Dictionary:
	var out: Dictionary = {}
	for raw: Variant in p_combat.call("get_roster_state").call("snapshot_all"):
		var entry: Dictionary = raw
		var key: String = "%d:%d" % [int(entry.get("side", 0)),
				int(entry.get("character_id", -1))]
		out[key] = int(entry.get("current_hp", -1))
	return out
