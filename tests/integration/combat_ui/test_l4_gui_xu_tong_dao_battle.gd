extends "res://tests/integration/combat_ui/full_battle_fixture.gd"
## 归墟通道的端到端验收：同境界 3~5 回合打赢、越级仍打不过。[br]
## [br][b]补的是什么缺口[/b]（上轮遗留③）：解析模型判「L4 打归墟打不过」，但那是
## 模型「敌人每回合都放最强技能」的保守口径——真实战斗的手牌/费用/技能权重都会
## 改变结果。本文件跑真实 [code]combat_scene.tscn[/code]、真实 [code]CardSystem[/code]、
## 真实鼠标点击出牌，用战斗自己报出的 [code]turn_count[/code] 锁住真实观感。[br]
## [br][b]另一条缺口[/b]：敌方 [b]人数[/b]。改造前人数写死在
## [code]gui_xu_tong_dao[/code] 的配置里，玩家炼气来与元婴来是同一个数字。
## 本文件断言真实战斗里的敌方人数 = [code]DifficultyCurve[/code] 对「该图档 + 该境界」
## 给的区间（口径只有一处，测试不另抄一份）。[br]
## [br][b]本轮修掉的失衡（EXPECTED_OUTCOME 由 defeat 改 victory 的理由）[/b]：
## 改造前每回合固定抽 2 张，而元婴我方有 5 名角色——手牌只够 2 人出手，第 3~5 名
## 角色整场轮不到出牌，每回合实际输出 3~8 点（账面 17 点）。敌方 2 鬼修 76 HP
## 每回合打 26 点，我方 43 HP 只撑 5 回合 → 真实结果是必败，与「同境界 3~5 回合
## 能赢」这条口径矛盾。[b]抽牌数改为随出战人数走[/b]
## （[code]CombatTurnEconomy.DRAW_PER_ACTOR[/code]）后，五人阵容每回合能打出 4~5 张，
## 实测 5 回合获胜（我方残血 9）。[br]
## [br][b]两个方向的用例都在本文件[/b]：同境界（元婴打归墟）必须赢、且回合数落在
## GDD 节奏窗口；[b]越级[/b]（炼气打归墟）必须仍然打不过——只把难度整体拉平
## 会让「地图境界档」这条轴失去意义。[br]
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
## 越级用例的玩家境界——炼气（落后地图档 2 档以上 = 「苦战」档）。
const UNDERLEVELED_REALM: int = 1
## 出战角色（按 ATK 降序取前 5 名——[code]BattleTempoModel.player_side[/code] 的口径）。
const CHARS: Array[StringName] = [&"tu_ye", &"su_jian_ming", &"ling_shuang_yue",
		&"fang_ling_su", &"mu_xing_he"]
## 越级用例的出战角色（炼气 [code]max_deploy[/code] = 2）。
const LOW_CHARS: Array[StringName] = [&"tu_ye", &"su_jian_ming"]
## 本场实际结果——[b]victory[/b]（抽牌经济修好后，同境界真打得过；见类文档）。
## [br][b]取值就是战绩 token 本身[/b]（[code]battle_record()["outcome"][/code]，
## 战败侧的对照值同样是它的 "defeat"）——不另立一套「win/lose」词表。
const EXPECTED_OUTCOME: String = "victory"
## GDD 节奏窗口（ai-system.md §调优参数、本轮验收目标）。
const EXPECTED_TURNS_MIN: int = 3
const EXPECTED_TURNS_MAX: int = 5
## 越级用例的回合数上限——打不过也必须是几回合内见分晓，不能磨到天荒地老。
const TURN_CEILING: int = 8
## 每回合最多出牌次数（防 [method _play_round] 内层循环失控）。
const PLAYS_PER_ACTOR: int = 15

## 本用例的玩家境界 / 出战角色（默认追平档；越级用例覆写后自行复位）。
var _player_realm: int = PLAYER_REALM
var _chars: Array[StringName] = CHARS


func before_each() -> void:
	# 手牌放大到 180x252 后，1280x720 的宿主里 5 张卡会挤到敌对区与目标选择区，
	# 真实点击容易落到错的对象上；端到端按玩家真实分辨率跑（其余用例仍走 720 覆盖低分辨率）。
	host_size = Vector2(1920.0, 1080.0)
	_player_realm = PLAYER_REALM
	_chars = CHARS


## 角色按本用例的境界与名额（L4 的 [code]max_deploy[/code] = 5、L1 = 2）。
func _seed_deck_and_characters() -> void:
	assert_true(SeedScript2.ensure_templates(), "前置：卡牌模板应已加载")
	GameStateManager.player = (GameStateManager.player as Dictionary).duplicate(true)
	GameStateManager.player["realm"] = _player_realm
	GameStateManager.player["character_hp"] = {}
	var deck_ids: Array = []
	for _i: int in range(BASIC_COUNT):
		deck_ids.append(SeedScript2.make_card(BASIC_ATTACK))
	deck_ids.append(SeedScript2.make_card(HOLD_CARD))
	char_ids = []
	for tid: StringName in _chars:
		char_ids.append(SeedScript2.make_card(tid))
	for cid: int in char_ids:
		assert_gt(cid, 0, "前置：角色卡实例应创建成功")
	var slots: Array = []
	for cid: int in char_ids:
		slots.append(cid)
	while slots.size() < 6:
		slots.append(null)
	DeckEditingSystem.initialize_initial_deck(deck_ids)
	GameStateManager._set_deck_slots(slots)


## 开战上下文——敌方模板取生产池对「归墟通道 + 本用例境界」的真实输出，节点档取
## 该图的 [code]enemy_realm[/code]（与探索侧 [code]ExplorationDAGContent._level_of[/code] 同源）。
func _launch_context(p_defeat: bool) -> Dictionary:
	var context: Dictionary = super._launch_context(p_defeat)
	context["enemy_template_ids"] = _production_roster_ids()
	context["enemy_level"] = CatalogScript.enemy_realm_of(MAP_ID, _player_realm)
	return context


## 每个用例后释放场景与战斗实例（否则它们会被 GUT 记成孤儿）。
func after_each() -> void:
	await teardown()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 敌方人数与属性都走本轮的轴
# ═══════════════════════════════════════════════════════════════════════════════

func test_gui_xu_battle_roster_follows_the_count_axis() -> void:
	# Arrange
	setup(false)
	confirm_deploy()
	var config: Dictionary = CatalogScript.config_for(MAP_ID, _player_realm)
	var span: Dictionary = CurveScript.count_range_of(
			int(config["enemy_realm"]), _player_realm,
			int(config["enemy_count_max"]),
			RealmScript.realm_table[_player_realm]["max_deploy"])
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
				_player_realm, int(config["enemy_realm"]))
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
# 2. 同境界：真实战斗里 3~5 回合打赢
# ═══════════════════════════════════════════════════════════════════════════════

## 同境界（元婴打归墟）[b]必须打赢，且回合数落在 GDD 节奏窗口 3~5 内[/b]。[br]
## [br][b]用例名是改造前留下的[/b]（[code]ends_within_the_turn_ceiling[/code]）——
## 它当初锁的是「打不过也要在有限回合内见分晓」，本轮期望值翻到胜利后，
## 上限由 [constant EXPECTED_TURNS_MAX] 承担、下限由 [constant EXPECTED_TURNS_MIN]
## 承担；名字保留，改的是被它锁住的期望值（[constant EXPECTED_OUTCOME]）。
func test_gui_xu_battle_ends_within_the_turn_ceiling() -> void:
	# Arrange——真实场景 + 五角色 + 真实鼠标点击
	setup(false)
	confirm_deploy()
	# Act——完整战斗：每回合切换当前操作角色，让 5 人都真的出手
	var turns: int = _run_battle_with_all_actors()
	# Assert——战斗结束（不是挂死），且真的赢了
	assert_false(bool(cs.call("is_battle_active")), "前置：战斗应结束")
	assert_eq(battle_events.size(), 1, "战斗结束应发射一次 battle_ended")
	var record: Dictionary = battle_record()
	assert_eq(int(record.get("turn_count", 0)), turns, "战绩回合数 = 实际进行的回合数")
	assert_eq(str(record.get("outcome", "")), EXPECTED_OUTCOME,
			"元婴打归墟通道（同境界）应能赢——抽牌经济修好后实测为胜")
	# Assert——回合数落在 GDD 节奏窗口内（同境界 = 3~5 回合）
	assert_between(turns, EXPECTED_TURNS_MIN, EXPECTED_TURNS_MAX,
			"同境界应在 %d~%d 回合内获胜（实得 %d 回合）"
			% [EXPECTED_TURNS_MIN, EXPECTED_TURNS_MAX, turns])
	assert_eq(int((record.get("enemy", {}) as Dictionary).get("count", 0)),
			_production_roster_ids().size(), "战绩里的敌方数量 = 名册数量")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 越级：炼气打归墟仍然打不过（难度轴没有被整体拉平）
# ═══════════════════════════════════════════════════════════════════════════════

## 炼气玩家（落后该图 2 档以上）打归墟通道——[b]必须仍是战败[/b]。[br]
## [br][b]为什么必须留着这条[/b]：本轮为了让「同境界能赢」而放宽了抽牌经济，
## 若只锁「赢」的一面，把抽牌改到离谱（例如每回合抽 20 张）也能全绿——
## 那条轴会变成「怎么改都是赢」，地图境界档就失去了意义。本用例是它的反向约束。[br]
## [br][b]对照口径[/b]：同境界赢、越级输，两者用的是同一张地图、同一副卡组、
## 同一套出牌驱动，唯一变量是玩家境界。
func test_underleveled_player_still_loses_at_gui_xu() -> void:
	# Arrange——炼气（该图 enemy_realm = 4，gap 夹到 +2「苦战」）
	_player_realm = UNDERLEVELED_REALM
	_chars = LOW_CHARS
	setup(false)
	confirm_deploy()
	var config: Dictionary = CatalogScript.config_for(MAP_ID, _player_realm)
	assert_gt(int(config["enemy_realm"]) - _player_realm,
			CurveScript.TIER_MAX_GAP, "前置：本用例确实是越级档（差 > 2 档）")
	# Act
	var turns: int = _run_battle_with_all_actors()
	# Assert——打不过，且是有限回合内见分晓（不是磨到挂死）
	assert_false(bool(cs.call("is_battle_active")), "前置：战斗应结束")
	assert_eq(battle_events.size(), 1, "战斗结束应发射一次 battle_ended")
	var record: Dictionary = battle_record()
	assert_eq(str(record.get("outcome", "")), "defeat",
			"炼气打归墟应战败——越级轴不能被抽牌改动抹平")
	assert_between(turns, 1, TURN_CEILING,
			"越级一战应在 1~%d 回合内见分晓（实得 %d）" % [TURN_CEILING, turns])
	assert_eq(int((record.get("player", {}) as Dictionary).get("remaining_hp", -1)), 0,
			"战败口径：我方剩余 HP 归零")
	assert_gt(int((record.get("enemy", {}) as Dictionary).get("remaining_hp", 0)), 0,
			"战败口径：敌方仍有残血（不是同归于尽）")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 生产池对「归墟通道 + 本用例境界」掷出的模板 ID（种子由地图 ID 与境界派生 → 可复现）。
func _production_roster_ids() -> Array:
	var side: Dictionary = TempoModel.enemy_side(MAP_ID, _player_realm,
			Callable(AISystem, &"get_template"))
	return (side["roster"] as Array).map(
			func(entry: Dictionary) -> StringName:
				return StringName(str(entry["template_id"])))


## 跑完整场战斗——每回合依次把当前操作角色切到每个存活角色，再打出该角色能出的
## 全部基础攻击。[br]
## [br][b]为什么要逐个切换[/b]：施法者 = 「当前操作角色」（[code]CombatActorSelection[/code]），
## 不切换的话五人阵容也只有一个人在打——那测的是「一人队」，不是「五人队」。[br]
## [br][b]第 1 回合也出牌[/b]（与基类 [method run_full_battle] 的「首回合只点按钮」不同）：
## 基类那样做是为了在没有手牌内容依赖的前提下验证「结束出牌」按钮；本文件量的是
## [b]真实观感[/b]（玩家开局手牌 4 张一定会打出去）。首回合不出牌等于白让一整回合的
## 输出——归墟通道里那正好是胜负之差，量出来的就不是玩家会经历的回合数。
## 按钮路径由 [method finish_turn] 每回合照常走，覆盖没有丢。
func _run_battle_with_all_actors() -> int:
	var turns: int = 0
	while bool(cs.call("is_battle_active")) and turns < 12:
		if not drive_to_play():
			break
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
