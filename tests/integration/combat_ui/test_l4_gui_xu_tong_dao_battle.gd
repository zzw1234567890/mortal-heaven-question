extends "res://tests/integration/combat_ui/full_battle_fixture.gd"
## L4 打归墟通道的端到端验收：真实战斗里敌方人数走人数轴、回合数落在可接受区间。[br]
## [br][b]补的是什么缺口[/b]（上轮遗留③）：解析模型判「L4 打归墟打不过」，但那是
## 模型「敌人每回合都放最强技能」的保守口径——真实战斗的手牌/费用/技能权重都会
## 改变结果。本文件跑真实 [code]combat_scene.tscn[/code]、真实 [code]CardSystem[/code]、
## 真实鼠标点击出牌，用战斗自己报出的 [code]turn_count[/code] 锁住真实观感。[br]
## [br][b]另一条缺口（本轮主线）[/b]：敌方 [b]人数[/b]。改造前人数写死在
## [code]gui_xu_tong_dao[/code] 的配置里，玩家炼气来与元婴来是同一个数字。
## 本文件断言真实战斗里的敌方人数 = [code]DifficultyCurve[/code] 对「该图档 + 该境界」
## 给的区间（口径只有一处，测试不另抄一份）。[br]
## [br][b]断言口径（为什么不断言「必胜」）[/b]：[b]五角色只抽 2 张牌/回合[/b]
## （[code]CombatTurnEconomy.DRAW_BASE[/code]），每回合的实际输出被手牌卡住而非
## 出战人数——归墟通道的鬼修 2 人合 76 HP / 每回合 26 伤，我方 5 人共 43 HP。
## 真实结果是[b]打不过[/b]，这是数值现状而不是本轮的接线缺陷，故这里锁的是
## 「战斗能在有限回合内结束、敌人人数与区间一致、敌方属性走难度系数表」；
## 战败是[b]如实断言[/b]的，不粉饰成胜利（[constant EXPECTED_OUTCOME]）。[br]
## [br]本文件独占角色段：卡实例 ID 由 CardSystem 分配，不手写。

const TempoModel := preload("res://tests/fixtures/battle_tempo_model.gd")
const CurveScript := preload("res://assets/enemies/difficulty_curve.gd")
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")
const RealmScript := preload("res://src/core/realm_system.gd")
const SeedScript2 := preload("res://tests/integration/combat_ui/full_battle_seed.gd")
## 归墟通道（元婴地图，[code]enemy_realm[/code] = 4）。
const MAP_ID: StringName = &"gui_xu_tong_dao"
## 验收的玩家境界——元婴（与地图档相同 = 「追平」档）。
const PLAYER_REALM: int = 4
## 出战角色（按 ATK 降序取前 5 名——[code]BattleTempoModel.player_side[/code] 的口径）。
const CHARS: Array[StringName] = [&"tu_ye", &"su_jian_ming", &"ling_shuang_yue",
		&"fang_ling_su", &"mu_xing_he"]
## 本场实际结果——defeat（见类文档「断言口径」）。
const EXPECTED_OUTCOME: String = "defeat"
## 回合数上限：`run_full_battle` 自带 12 回合防挂死上限，这里再收紧到 8——
## 「打不过」也必须是几回合内见分晓，不能是磨到天荒地老的消耗战。
const TURN_CEILING: int = 8
## 每回合最多出牌次数（防 [method _play_round] 内层循环失控）。
const PLAYS_PER_ACTOR: int = 15


## 五角色 + 伤害密集卡组（L4 的 [code]max_deploy[/code] = 5）。
func _seed_deck_and_characters() -> void:
	assert_true(SeedScript2.ensure_templates(), "前置：卡牌模板应已加载")
	GameStateManager.player = (GameStateManager.player as Dictionary).duplicate(true)
	GameStateManager.player["realm"] = PLAYER_REALM
	GameStateManager.player["character_hp"] = {}
	var deck_ids: Array = []
	for _i: int in range(BASIC_COUNT):
		deck_ids.append(SeedScript2.make_card(BASIC_ATTACK))
	deck_ids.append(SeedScript2.make_card(HOLD_CARD))
	char_ids = []
	for tid: StringName in CHARS:
		char_ids.append(SeedScript2.make_card(tid))
	for cid: int in char_ids:
		assert_gt(cid, 0, "前置：角色卡实例应创建成功")
	DeckEditingSystem.initialize_initial_deck(deck_ids)
	GameStateManager._set_deck_slots([char_ids[0], char_ids[1], char_ids[2],
			char_ids[3], char_ids[4], null])


## 开战上下文——敌方模板取生产池对「归墟通道 + 元婴玩家」的真实输出，节点档取该图
## 的 [code]enemy_realm[/code]（与探索侧 [code]ExplorationDAGContent._level_of[/code] 同源）。
func _launch_context(p_defeat: bool) -> Dictionary:
	var context: Dictionary = super._launch_context(p_defeat)
	context["enemy_template_ids"] = _production_roster_ids()
	context["enemy_level"] = CatalogScript.enemy_realm_of(MAP_ID, PLAYER_REALM)
	return context


## 每个用例后释放场景与战斗实例（否则它们会被 GUT 记成孤儿）。
func after_each() -> void:
	await teardown()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 敌方人数与属性都走本轮/上轮的轴
# ═══════════════════════════════════════════════════════════════════════════════

func test_gui_xu_battle_roster_follows_the_count_axis() -> void:
	# Arrange
	setup(false)
	confirm_deploy()
	var config: Dictionary = CatalogScript.config_for(MAP_ID, PLAYER_REALM)
	var span: Dictionary = CurveScript.count_range_of(
			int(config["enemy_realm"]), PLAYER_REALM,
			int(config["enemy_count_max"]),
			RealmScript.realm_table[PLAYER_REALM]["max_deploy"])
	# Act
	var roster: Array = cs.call("get_battle_enemy_roster")
	# Assert——人数 = 生产池掷出的数量，且落在人数轴给的区间内（沿用上一条的人数表）
	assert_eq(roster.size(), _production_roster_ids().size(),
			"前置：战斗名册 = 生产池掷出的名册")
	assert_between(roster.size(), int(span["min"]), int(span["max"]),
			"敌方人数应落在难度曲线给的区间（追平档）")
	# Assert——属性走难度系数表（gap=0 → 模板原值），逐条比对不手抄系数
	for entry: Variant in roster:
		var tid: StringName = StringName(str(entry.get("template_id")))
		var template: Variant = AISystem.get_template(tid)
		assert_not_null(template, "前置：模板可查（%s）" % tid)
		var expected: Dictionary = CurveScript.apply(
				int(template.get("base_hp")), int(template.get("base_attack")),
				int(template.get("base_defense")), int(template.get("realm")),
				PLAYER_REALM, int(config["enemy_realm"]))
		assert_eq(int(entry.get("max_hp")), int(expected["max_hp"]),
				"敌方 HP 走难度系数表（模板 %s）" % tid)
		assert_eq(int(entry.get("attack")), int(expected["attack"]),
				"敌方 ATK 走难度系数表（模板 %s）" % tid)


func test_gui_xu_battle_player_deploys_the_realm_allowance() -> void:
	# 前置校验：L4 的 max_deploy = 5，五名角色都要真的上场（否则下面的
	# 回合数不是「五角色阵容」的回合数）
	setup(false)
	confirm_deploy()
	assert_eq(RealmScript.realm_table[PLAYER_REALM]["max_deploy"], CHARS.size(),
			"前置：元婴出战名额 = 本文件给的角色数")
	assert_eq(int(cs.get("_battle_player_roster").size()), CHARS.size(),
			"开战名册应含全部 5 名角色")
	assert_gt(player_hp_total(), 0, "前置：我方应有血量")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 真实战斗：回合数落在可接受区间，胜负如实
# ═══════════════════════════════════════════════════════════════════════════════

func test_gui_xu_battle_ends_within_the_turn_ceiling() -> void:
	# Arrange——真实场景 + 五角色 + 真实鼠标点击
	setup(false)
	confirm_deploy()
	# Act——完整战斗：每回合切换当前操作角色，让 5 人都真的出手
	var turns: int = _run_battle_with_all_actors()
	# Assert——战斗结束（不是挂死），回合数在区间内，战绩与实测一致
	assert_false(bool(cs.call("is_battle_active")), "前置：战斗应结束")
	assert_eq(battle_events.size(), 1, "战斗结束应发射一次 battle_ended")
	assert_between(turns, 1, TURN_CEILING,
			"归墟通道一战应在 1~%d 回合内见分晓（实得 %d）" % [TURN_CEILING, turns])
	var record: Dictionary = battle_record()
	assert_eq(int(record.get("turn_count", 0)), turns, "战绩回合数 = 实际进行的回合数")
	assert_eq(str(record.get("outcome", "")), EXPECTED_OUTCOME,
			"归墟通道对元婴玩家是硬仗——本轮实测为战败（数值现状见类文档）")
	assert_eq(int((record.get("enemy", {}) as Dictionary).get("count", 0)),
			_production_roster_ids().size(), "战绩里的敌方数量 = 名册数量")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 生产池对「归墟通道 + 元婴玩家」掷出的模板 ID（种子由地图 ID 与境界派生 → 可复现）。
func _production_roster_ids() -> Array:
	var side: Dictionary = TempoModel.enemy_side(MAP_ID, PLAYER_REALM,
			Callable(AISystem, &"get_template"))
	return (side["roster"] as Array).map(
			func(entry: Dictionary) -> StringName:
				return StringName(str(entry["template_id"])))


## 跑完整场战斗——每回合依次把当前操作角色切到每个存活角色，再打出该角色能出的
## 全部基础攻击。[br]
## [br][b]为什么要逐个切换[/b]：施法者 = 「当前操作角色」（[code]CombatActorSelection[/code]），
## 不切换的话五人阵容也只有一个人在打——那测的是「一人队」，不是「五人队」。
func _run_battle_with_all_actors() -> int:
	var turns: int = 0
	while bool(cs.call("is_battle_active")) and turns < 12:
		if not drive_to_play():
			break
		if turns > 0:
			_play_round()
		finish_turn()
		turns += 1
	return turns


## 一个我方回合：每个存活角色轮流当施法者，各自打出能打的基础攻击。
func _play_round() -> void:
	for cid: int in _alive_ids():
		var stage: Variant = _root().get("actor_stage")
		var card: Control = stage.call("get_card", cid)
		if card == null:
			continue
		_clicks.call("click", card.get_global_rect().get_center())
		_play_until_stuck()


## 连续打出基础攻击，直到打不出为止（防挂死上限 [constant PLAYS_PER_ACTOR]）。
func _play_until_stuck() -> void:
	for _guard: int in range(PLAYS_PER_ACTOR):
		if int(cs.call("get_current_phase")) != 2:
			return
		var index: int = _first_basic_index()
		var enemy_id: int = _first_alive_enemy()
		if index < 0 or enemy_id < 0:
			return
		var hand_before: int = int(cs.call("get_hand").size())
		_clicks.call("click", _clicks.call("hand_card_pos", index))
		_clicks.call("click", _clicks.call("enemy_card_pos", enemy_id))
		if int(cs.call("get_hand").size()) >= hand_before:
			return  # 未打出去——避免无限循环


## 当前存活的我方角色 ID（阵亡的不参与切换）。
func _alive_ids() -> Array:
	var alive: Array = []
	for cid: int in char_ids:
		if int(cs.call("get_character_hp", cid).get("current", 0)) > 0:
			alive.append(cid)
	return alive
