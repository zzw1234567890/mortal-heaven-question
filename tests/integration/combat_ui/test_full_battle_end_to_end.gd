extends "res://tests/integration/combat_ui/full_battle_fixture.gd"
## 一场完整战斗的端到端验收（2026-11-10）。[br]
## [br][b]起点[/b]：真实 [code]combat_scene.tscn[/code] 进树 → 备战面板点选并确认。
## [b]过程[/b]：真实鼠标点击命中手牌与敌方角色卡出牌；「结束出牌」按钮结束回合；
## 敌方行动按 AI 决策落库。 [b]终点[/b]：一方全灭 → [code]battle_ended[/code]
## → 转场请求 → 结算/战败场景读到战绩。[br]
## [br][b]本文件修掉的断链[/b]（详见 [code]production/qa/combat-full-battle-acceptance-2026-11-10.md[/code]）：
## 卡组未初始化、敌方阵容无来源、打出的牌不进弃牌堆、0 费牌出牌后手牌不刷新、
## 「结束出牌」按钮无处理者。[br]
## [br]本文件独占角色段：卡实例 ID 由 CardSystem 分配，不手写。

## 结局取值引真实枚举（[constant CS_SCRIPT] 来自父夹具
## [code]full_battle_fixture.gd[/code]——子类不重复声明）。
const VictoryResult: int = CS_SCRIPT.CombatResult.VICTORY
const DefeatResult: int = CS_SCRIPT.CombatResult.DEFEAT


func before_all() -> void:
	# CardSystem 的模板是异步加载的——等它把真实目录读完（上限防挂死）。
	for _i: int in range(300):
		if CardSystem.get_template(&"basic_attack") != null \
				and CardSystem.get_template(&"lin_yuan") != null:
			break
		await get_tree().process_frame
	# AISystem 同步扫描 assets/enemies/——补一次，确保新增模板已入注册表。
	AISystem.load_templates()


func after_each() -> void:
	await teardown()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 胜利方向：完整链路 → 结算场景
# ═══════════════════════════════════════════════════════════════════════════════

func test_full_battle_victory_reaches_result_screen() -> void:
	# Arrange——默认遭遇战（散修 HP16/ATK2），我方林渊 10/2 + 苏剑鸣 7/4
	setup(false)
	confirm_deploy()
	assert_eq(int(cs.call("get_turn_number")), 1, "开战即第 1 回合")
	var hp_start: int = player_hp_total()
	assert_eq(hp_start, 17, "前置：两名角色按模板入场（10 + 7）")
	assert_eq(int(cs.call("get_hand").size()), 4, "先手开局手牌 4 张")
	var enemy_id: int = _first_alive_enemy()
	assert_gt(enemy_id, 0, "前置：敌方阵容已由遭遇战配置生成")
	assert_eq(int(cs.call("get_character_hp", enemy_id)["current"]), 16,
			"前置：敌方 HP 来自 san_xiu 模板")
	# Act——跑完整场（第 1 回合点按钮结束；其后每回合点击出牌）
	var turns: int = run_full_battle()
	# Assert——战斗真的结束
	assert_false(bool(cs.call("is_battle_active")), "敌方全灭后战斗应结束")
	assert_gt(turns, 1, "完整战斗应跨多个回合")
	assert_eq(battle_events.size(), 1, "battle_ended 应发射一次")
	assert_eq(int(battle_events[0]["result"]), VictoryResult, "结局应为胜利")
	# Assert——敌方真的打到了人（技能池 + 决策 + 落库链路）
	assert_gt(enemy_actions.size(), 0, "敌方行动应被结算并广播")
	var first_action: Dictionary = enemy_actions[0]
	assert_true(bool(first_action.get("known", false)), "敌方行动应落在已知目标上")
	assert_gt(int(first_action.get("damage", 0)), 0, "敌方技能伤害应大于 0（散修「削弱」威力 0.8 × ATK 2）")
	assert_gt(int(first_action.get("target_id", -1)), 0, "目标应是我方角色")
	# Assert——玩家点击出牌的伤害真的落库（每条基础攻击计一条效果）
	var record: Dictionary = battle_record()
	assert_eq(int(record.get("result", 0)), VictoryResult, "战绩结果应为胜利")
	assert_eq(String(record.get("outcome", "")), "victory", "结局 token 应为 victory")
	assert_gt(int(record.get("turn_count", 0)), 1, "战绩应记录真实回合数")
	var entries: int = int(record.get("effect_entries", 0))
	assert_gt(entries, 0, "点击出牌应触发效果条目")
	# 初始卡组只有 6 张基础攻击；打出超过 6 张必须依赖「弃牌堆回收」——
	# 这条同时锁住「0 费牌出牌后手牌刷新」与「打出的牌进弃牌堆」两条修复。
	assert_gt(entries, BASIC_COUNT,
			"打出的基础攻击数应超过初始张数 %d（抽空后经弃牌堆回收）" % BASIC_COUNT)
	assert_eq(int(record["enemy"]["remaining_hp"]), 0, "敌方剩余 HP 应为 0")
	assert_eq(int(record["enemy"]["alive_count"]), 0, "敌方存活数应为 0")
	var remaining: int = int(record["player"]["remaining_hp"])
	assert_gt(remaining, 0, "我方应存活并保留残血")
	var total_damage: int = 0
	for action: Dictionary in enemy_actions:
		total_damage += int(action.get("damage", 0))
	assert_eq(remaining, hp_start - total_damage,
			"我方剩余 HP = 初始 − 历次敌方行动伤害总和")
	# Assert——转场目标为结算场景
	assert_eq(sm.requests.size(), 1, "战斗结束应发出一次转场请求")
	assert_eq(int(sm.requests[0]["to"]), 8, "胜利应转场 RESULT_SCREEN")
	# Assert——结算场景真的消费了战绩（不是占位文案）
	var screen: Control = mount_result_screen(RESULT_SCREEN)
	assert_eq((screen.get("title_label") as Label).text, "战斗胜利", "标题来自真实战绩")
	var brief: String = (screen.get("brief_label") as Label).text
	assert_true(brief.contains("回合数: %d" % int(record["turn_count"])), "摘要含回合数")
	assert_true(brief.contains("剩余 HP %d" % remaining), "摘要含我方剩余 HP")
	assert_true(brief.contains("敌方: 存活 0/1"), "摘要含敌方全灭")


# ═══════════════════════════════════════════════════════════════════════════════
# 1b. 单次出牌的界面回写：手牌区刷新 + 卡进弃牌堆
# ═══════════════════════════════════════════════════════════════════════════════

## 点卡 → 点敌人之后：战斗手牌减少、手牌区同步减少、打出的卡进入弃牌堆。[br]
## [br][b]为什么单列[/b]：0 费卡出牌不触发 [code]cost_changed[/code]，手牌区若不主动
## 刷新会继续显示已打出的卡（点它只会重复提交同一张卡）——这条点击路径此前断在这里。
func test_click_play_refreshes_hand_area_and_moves_card_to_discard() -> void:
	# Arrange
	setup(false)
	confirm_deploy()
	assert_true(drive_to_play(), "前置：进入出牌阶段")
	var hand_before: int = int(cs.call("get_hand").size())
	var discard_before: int = int(cs.call("get_discard_pile").size())
	var hand_area: Variant = _root().get("hand_area")
	assert_eq(int(hand_area.call("get_card_count")), hand_before,
			"前置：手牌区与战斗手牌等长")
	var index: int = _first_basic_index()
	var played_id: int = _hand_card_id_at(index)
	# Act——真实点击路径
	_clicks.call("click", _clicks.call("hand_card_pos", index))
	_clicks.call("click", _clicks.call("enemy_card_pos", _first_alive_enemy()))
	# Assert
	assert_eq(int(cs.call("get_hand").size()), hand_before - 1, "战斗手牌减少 1 张")
	assert_eq(int(hand_area.call("get_card_count")), hand_before - 1,
			"手牌区应随出牌刷新（0 费卡不触发 cost_changed）")
	assert_eq(int(cs.call("get_discard_pile").size()), discard_before + 1,
			"打出的卡应进入弃牌堆")
	assert_eq(int(cs.call("get_discard_pile")[discard_before]), played_id,
			"弃牌堆记录的是刚打出的那张卡")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 战败方向：同一链路 → 战败场景
# ═══════════════════════════════════════════════════════════════════════════════

func test_full_battle_defeat_reaches_defeat_screen() -> void:
	# Arrange——碾压型遭遇（魔修 HP30/ATK9，我方总 HP 17）
	setup(true)
	confirm_deploy()
	var enemy_id: int = _first_alive_enemy()
	assert_eq(int(cs.call("get_character_hp", enemy_id)["current"]), 30,
			"前置：敌方 HP 来自 mo_xiu 模板")
	# Act
	var turns: int = run_full_battle()
	# Assert——我方全灭 → 结束
	assert_false(bool(cs.call("is_battle_active")), "我方全灭后战斗应结束")
	assert_gt(turns, 1, "战败应发生在多个回合之后")
	var record: Dictionary = battle_record()
	assert_eq(int(record.get("result", 0)), DefeatResult, "结局应为战败")
	assert_eq(String(record.get("outcome", "")), "defeat", "结局 token 应为 defeat")
	assert_eq(int(record["player"]["remaining_hp"]), 0, "我方剩余 HP 应为 0")
	assert_eq(int(record["player"]["alive_count"]), 0, "我方存活数应为 0")
	assert_gt(int(record["enemy"]["remaining_hp"]), 0, "敌方应仍有残血（不是同归于尽）")
	# Assert——敌方高伤害真的落库（9 点一击）
	var max_damage: int = 0
	for action: Dictionary in enemy_actions:
		max_damage = maxi(max_damage, int(action.get("damage", 0)))
	assert_gt(max_damage, 0, "魔修行动应造成伤害")
	assert_true(max_damage <= 9, "魔修伤害不应超过裸 ATK 9（群攻技能威力 0.8）")
	# Assert——转场目标为战败场景，且场景消费了战绩
	assert_eq(sm.requests.size(), 1, "战斗结束应发出一次转场请求")
	assert_eq(int(sm.requests[0]["to"]), 9, "战败应转场 DEFEAT_SCREEN")
	var screen: Control = mount_result_screen(DEFEAT_SCREEN)
	assert_eq((screen.get("title_label") as Label).text, "战斗失败", "标题来自真实战绩")
	var brief: String = (screen.get("brief_label") as Label).text
	assert_true(brief.contains("我方: 存活 0/2"), "摘要含我方全灭")
	assert_true(brief.contains("剩余 HP 0"), "摘要含我方归零")
