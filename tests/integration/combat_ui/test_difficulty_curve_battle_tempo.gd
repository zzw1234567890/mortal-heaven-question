extends "res://tests/integration/combat_ui/full_battle_fixture.gd"
## 难度曲线的端到端节奏验收：真实战斗场景里，追平境界的一战必须落在 3~5 回合。[br]
## [br][b]补的是什么缺口[/b]：单元测试能证明「系数乘对了」，证明不了「这场仗打完
## 是几个回合」——系数表可以整体偏硬/偏软而每条断言都绿。本文件跑真实
## [code]combat_scene.tscn[/code]、真实 [code]CardSystem[/code]、真实鼠标点击出牌，
## 用战斗自己报出的 [code]turn_count[/code] 去卡 GDD 的节奏窗口。[br]
## [br][b]名册来自生产池[/b]：敌方模板 ID 由 [code]ExplorationEnemyPool[/code] 对
## 「首图 + 炼气玩家」现掷（种子由地图 ID 派生 → 可复现），再交给战斗场景——
## 不是手写一串模板 ID，否则「池里出了什么」与「战斗里打了什么」会脱钩。[br]
## [br][b]两套卡组的实测差异（本文件两条用例的分工）[/b]：[br]
##   · [b]伤害密集卡组[/b]（[constant BASIC_COUNT] 张 0 费基础攻击，夹具既有口径）
##     ——用来看「系数 + 人数」这条链路的节奏，实测 4 回合；[br]
##   · [b]真实初始卡组[/b]（青云剑宗外门弟子：7 张里只有 2 张基础攻击）
##     ——玩家真正会经历的观感，实测 6 回合。[br]
## 两者差在[b]卡组攻击密度[/b]（不是难度系数）：初始卡组 5 张是绑定/增益/护盾，
## 出不了伤害。本文件把两个数字都锁住，避免以后误以为「改系数就能改节奏」。[br]
## [br][b]与解析模型的分工[/b]：[code]BattleTempoModel[/code] 给乐观下界，
## 这里给真实观感，两者互为上下界。[br]
## [br]本文件独占角色段：卡实例 ID 由 CardSystem 分配，不手写。

const TempoModel := preload("res://tests/fixtures/battle_tempo_model.gd")
const CurveScript := preload("res://assets/enemies/difficulty_curve.gd")
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")
const SeedScript2 := preload("res://tests/integration/combat_ui/full_battle_seed.gd")

const VictoryResult: int = 1

## 首图（唯一「炼气玩家一进游戏就能进」的地图）。
const FIRST_MAP: StringName = &"qing_yun_jian_zong"
## 验收的玩家境界——炼气，与首图境界档相同（即「追平」）。
const PLAYER_REALM: int = 1
## GDD 节奏窗口（ai-system.md §调优参数、本轮验收目标）。
const TURNS_MIN: int = 3
const TURNS_MAX: int = 5
## 首图唯一敌人模板（池权重 100）。
const FIRST_MAP_ENEMY: StringName = &"san_xiu"
## 真实初始卡组的回合上限——[b]不是 3~5[/b]：初始卡组只有 2 张伤害牌，
## 实测 6 回合（见类文档）。这条上限只锁「没变成拖沓的消耗战」，不冒充节奏目标。
const STARTER_DECK_TURN_CEILING: int = 8
## 青云剑宗外门弟子的开局卡组（[code]identity_templates.gd[/code] 第 1 号身份）。
const STARTER_DECK: Array[StringName] = [
	&"ku_mu_feng_chun_jue", &"yan_yun_bu", &"ying_ci", &"basic_attack",
	&"basic_attack", &"jian_yi_hu_dun", &"jian_yi_hu_dun",
]

## 节点等级覆盖（≤0 = 用首图自身的境界档）。
var _override_map_realm: int = -1
## 是否换成真实初始卡组（默认用夹具的伤害密集卡组）。
var _use_starter_deck: bool = false
## 本场遭遇的敌方模板 ID（生产池掷出，[method before_each] 重算）。
var _enemy_ids: Array = []


func before_all() -> void:
	# CardSystem 的模板是异步加载的——等它读完真实目录（上限防挂死）。
	for _i: int in range(300):
		if CardSystem.get_template(&"basic_attack") != null \
				and CardSystem.get_template(&"lin_yuan") != null:
			break
		await get_tree().process_frame
	# AISystem 同步扫描 assets/enemies/——名册池要按 template_id 查它。
	AISystem.load_templates()


func before_each() -> void:
	_override_map_realm = -1
	_use_starter_deck = false
	_enemy_ids = _first_map_roster_ids()
	assert_eq(_enemy_ids.size(), 1, "前置：首图敌人池应掷出恰好 1 个模板")


func after_each() -> void:
	await teardown()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 追平境界 → 3~5 回合获胜（本轮验收目标）
# ═══════════════════════════════════════════════════════════════════════════════

func test_first_map_is_won_inside_the_target_turn_window() -> void:
	# Arrange——首图遭遇，玩家境界与地图境界档相同（gap = 0「均势」）
	setup(false)
	confirm_deploy()
	var roster: Array = cs.call("get_battle_enemy_roster")
	assert_eq(roster.size(), _enemy_ids.size(), "前置：敌方数量 = 生产池掷出的数量")
	for entry: Variant in roster:
		assert_eq(StringName(str(entry.get("template_id"))), FIRST_MAP_ENEMY,
				"前置：首图只出散修")
		assert_eq(int(entry.get("max_hp")), CurveScript.apply(16, 2, 0, 1,
				PLAYER_REALM, _map_realm())["max_hp"],
				"前置：敌方 HP 走难度系数表（gap=0 → 模板原值）")
	# Act——完整战斗（真实点击出牌 → 结束出牌 → 敌方回合 → 全灭）
	var turns: int = run_full_battle()
	# Assert——赢，且回合数落在节奏窗口内
	assert_false(bool(cs.call("is_battle_active")), "前置：战斗应结束")
	assert_eq(battle_events.size(), 1, "战斗结束应发射一次 battle_ended")
	assert_eq(int(battle_events[0]["result"]), VictoryResult, "追平境界应能打赢首图")
	var record: Dictionary = battle_record()
	assert_eq(int(record.get("turn_count", 0)), turns, "战绩回合数 = 实际进行的回合数")
	assert_between(turns, TURNS_MIN, TURNS_MAX,
			"追平后应在 %d~%d 回合内获胜（实得 %d 回合）" % [TURNS_MIN, TURNS_MAX, turns])


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 玩家真正会经历的首战：真实初始卡组也不能变成消耗战
# ═══════════════════════════════════════════════════════════════════════════════

## 用身份预设的开局卡组（7 张、只有 2 张伤害牌）再打一次首图。[br]
## [br][b]为什么单列[/b]：第 1 条用的是伤害密集的夹具卡组，它回答「系数配平了吗」；
## 本条回答「新手实际手感如何」。两者差在卡组攻击密度而非难度系数——把这条也锁上，
## 以后有人为了让数字好看去调系数时，会先看到真实卡组的实测值。[br]
## [br][b]上限不是 3~5[/b]：实测 6 回合（施法者恒为阵位首位、每回合平均 1 张伤害牌），
## 见类文档。断言取 [constant STARTER_DECK_TURN_CEILING]，只防「打不完 / 磨太久」。
func test_real_starter_deck_wins_the_first_map_without_dragging() -> void:
	# Arrange——换成真实初始卡组
	_use_starter_deck = true
	setup(false)
	confirm_deploy()
	# 牌堆 = 初始卡组扣除开局手牌（先手发 4 张）——两边相加才是整副。
	var deck_size: int = int(cs.call("get_deck").size())
	var hand_size: int = int(cs.call("get_hand").size())
	assert_eq(deck_size + hand_size, STARTER_DECK.size(),
			"前置：本局用满整副初始卡组 %d 张（牌堆 %d + 手牌 %d）"
			% [STARTER_DECK.size(), deck_size, hand_size])
	# Act
	var turns: int = run_full_battle()
	# Assert
	assert_eq(battle_events.size(), 1, "战斗应结束")
	assert_eq(int(battle_events[0]["result"]), VictoryResult,
			"新手用初始卡组打首图应能赢（否则「一路玩下去」在第一步就断了）")
	var record: Dictionary = battle_record()
	assert_gt(int(record["player"]["remaining_hp"]), 0, "应残血存活，不是同归于尽")
	assert_gt(turns, 0, "应真的打了若干回合")
	assert_lte(turns, STARTER_DECK_TURN_CEILING,
			"初始卡组首战不应超过 %d 回合（实得 %d）"
			% [STARTER_DECK_TURN_CEILING, turns])


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 同一批敌人、节点档高玩家一档 → 真实战斗里确实更硬
# ═══════════════════════════════════════════════════════════════════════════════

## 玩家落后一档时，战斗场景里的敌方总 HP 必须高于「均势档」的同一批敌人。[br]
## [br][b]对比物由 [code]DifficultyCurve[/code] 现算[/b]（不手抄系数）：两边只差
## [code]map_realm[/code] 一个输入，差异全部来自档位轴——这就是「地图境界档真的
## 进了战斗数值」这条链路的端到端证据（改造前两边的取值会完全相同）。[br]
func test_higher_node_tier_hardens_the_same_roster_in_real_battle() -> void:
	# Arrange——节点档 = 玩家境界 + 1「吃力」
	_override_map_realm = PLAYER_REALM + 1
	setup(false)
	confirm_deploy()
	# Act——真实战斗场景里的敌方名册（缩放由 CombatSceneBattleSetup 走生产路径）
	var roster: Array = cs.call("get_battle_enemy_roster")
	assert_eq(roster.size(), _enemy_ids.size(), "前置：同一份名册，逐条可比")
	var even_total: int = 0
	var harder_total: int = 0
	# Assert——逐条比对：实测值 = 难度系数表对「均势档」的取值 × 吃力档系数。
	# [b]逐条而非比总数[/b]：取整在每条上各做一次，总数会掩盖取整差异；
	# 期望值从 [code]DifficultyCurve[/code] 现算，不手抄系数。
	for entry: Variant in roster:
		var template: Variant = AISystem.get_template(
				StringName(str(entry.get("template_id"))))
		assert_not_null(template, "前置：模板可查（%s）" % entry.get("template_id"))
		var args: Array = [int(template.get("base_hp")),
				int(template.get("base_attack")), int(template.get("base_defense")),
				int(template.get("realm")), PLAYER_REALM]
		var even: Dictionary = CurveScript.apply(args[0], args[1], args[2],
				args[3], args[4], PLAYER_REALM)
		var harder: Dictionary = CurveScript.apply(args[0], args[1], args[2],
				args[3], args[4], _map_realm())
		assert_eq(int(entry.get("max_hp")), int(harder["max_hp"]),
				"实测 HP 应等于吃力档取值（%d）" % int(harder["max_hp"]))
		assert_eq(int(entry.get("attack")), int(harder["attack"]),
				"实测 ATK 应等于吃力档取值（%d）" % int(harder["attack"]))
		even_total += int(even["max_hp"])
		harder_total += int(harder["max_hp"])
	assert_gt(harder_total, even_total,
			"落后一档的实测总 HP（%d）应高于均势档（%d）" % [harder_total, even_total])


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 开战上下文——把夹具的测试遭遇换成首图的真实名册与节点档。[br]
## [br][b]其余字段保持夹具口径[/b]：本文件只替换「敌方是谁、多少级」这两项，
## 掉落 / 玩家阵容 / 节点 ID 沿用既有夹具，避免顺带改变结算链路。
func _launch_context(p_defeat: bool) -> Dictionary:
	var context: Dictionary = super._launch_context(p_defeat)
	context["enemy_template_ids"] = _enemy_ids.duplicate()
	context["enemy_level"] = _map_realm()
	return context


## 卡组种子——默认走夹具口径；[member _use_starter_deck] 为真时换成身份预设卡组。[br]
## [br][b]只换牌不换人[/b]：角色仍是林渊 + 苏剑鸣（正是青云剑宗身份的两个角色位），
## 差异因此只来自卡组的攻击密度。
func _seed_deck_and_characters() -> void:
	if not _use_starter_deck:
		super._seed_deck_and_characters()
		return
	assert_true(SeedScript2.ensure_templates(), "前置：卡牌模板应已加载")
	GameStateManager.player = (GameStateManager.player as Dictionary).duplicate(true)
	GameStateManager.player["realm"] = PLAYER_REALM
	GameStateManager.player["character_hp"] = {}
	var deck_ids: Array = []
	for tid: StringName in STARTER_DECK:
		deck_ids.append(SeedScript2.make_card(tid))
	char_ids = []
	for tid: StringName in CHAR_TEMPLATES:
		char_ids.append(SeedScript2.make_card(tid))
	for cid: int in char_ids:
		assert_gt(cid, 0, "前置：角色卡实例应创建成功")
	DeckEditingSystem.initialize_initial_deck(deck_ids)
	GameStateManager._set_deck_slots([char_ids[0], char_ids[1], null, null, null, null])


## 本场节点等级——覆盖值优先，否则取首图自身的境界档。
func _map_realm() -> int:
	if _override_map_realm > 0:
		return _override_map_realm
	return CatalogScript.enemy_realm_of(FIRST_MAP, PLAYER_REALM)


## 生产池对「首图 + 炼气玩家」掷出的模板 ID 列表（种子与运行期一致 → 可复现）。
func _first_map_roster_ids() -> Array:
	var side: Dictionary = TempoModel.enemy_side(FIRST_MAP, PLAYER_REALM,
			Callable(AISystem, &"get_template"))
	var ids: Array = []
	for entry: Dictionary in side.get("roster", []):
		ids.append(StringName(str(entry.get("template_id"))))
	return ids
