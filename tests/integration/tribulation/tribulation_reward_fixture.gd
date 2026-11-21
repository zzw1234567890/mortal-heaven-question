extends GutTest
## TribulationRewardFixture —— 渡劫金卡奖励用例的共享装置（GDD §6）。[br]
## [br][b]为什么单独一处[/b]：三个用例文件（发放 / 降级 / 文案）守同一个夹具，
## 而「怎么把 CardSystem 灌好模板、怎么推进到 IN_COMBAT、怎么读收藏」与
## 「断言什么」是两件事——后者才是用例的职责（同
## [code]tests/integration/exploration_ui/tribulation_entry_fixture.gd[/code] 的拆因）。[br]
## [br][b]文件前缀[/b]：不以 [code]test_[/code] 开头——只作基类被继承。[br]
## [br][b]为什么注入 CardSystem 实例[/b]：真实 Autoload 的模板是异步加载的
## （[code]load_threaded_request[/code]），跑用例时不一定就绪；注入一个已灌入夹具模板的
## 实例即可确定性地验「发的是不是金档」。GSM / CultivationSystem / RealmSystem 用真实
## Autoload——[b]断言正是「玩家数据真的变了」[/b]。[br]
## [br][b]稀有度与张数的真理来源[/b]：[code]tribulation_reward_pool.gd[/code] 的常量
## （用例文件不写死 4 / 1 / 2）。[br]
##
## 来源: design/gdd/tribulation-system.md §6 固定金卡奖励 + §越阶渡劫、
## ADR-0021 §_handle_tribulation_success、ADR-0006（卡牌实例与收藏入库）。

const TS_SCRIPT := preload("res://src/feature/tribulation_system.gd")
const PoolScript := preload("res://src/feature/tribulation/tribulation_reward_pool.gd")
const LinesScript := preload("res://src/feature/tribulation/tribulation_reward_lines.gd")
const SettlementScript := preload("res://src/feature/tribulation/tribulation_settlement.gd")
const CS_SCRIPT := preload("res://src/core/card_system/card_system.gd")
const TemplateClass := preload("res://src/core/card_system/card_template.gd")

## 夹具金档模板（两张——「随机取一张」才有得可挑）。
const GOLD_A: StringName = &"test_trib_gold_a"
const GOLD_B: StringName = &"test_trib_gold_b"
## 夹具白档模板——用来验「只发金档，不发别的档」。
const WHITE_C: StringName = &"test_trib_white_c"
## 夹具暗金模板——GDD §6 只承诺金卡；暗金有境界上限那道闸，不得顺手发。
const DARK_D: StringName = &"test_trib_dark_d"

## 炼气期的修为上限（境界表 §1——本夹具的基准状态）。
const BASE_MAX: int = 1000

## [code]battle_ended[/code] 结果取值——[b]直接引真实枚举[/b]。[br]
## [br][b]这里原先记着一处缺陷[/b]：[code]tribulation_combat.gd[/code] 曾用
## [code]if result == 0[/code] 判胜，而枚举真理来源
## [code]src/feature/combat_system.gd[/code] §CombatResult 是
## [code]VICTORY = 1 / DEFEAT = 2 / RETREAT = 3[/code]——打赢也走失败结算
## （境界不升、修为被扣、金卡不发）。缺陷已修（判据改为引用枚举本身），
## 本常量随之改成同一个出处：[b]用例与生产判据同源，再也无法分叉[/b]。[br]
## [br]回归守卫见 [code]test_tribulation_result_wiring.gd[/code]。
const CombatScript := preload("res://src/feature/combat_system.gd")
const COMBAT_VICTORY: int = CombatScript.CombatResult.VICTORY
const COMBAT_DEFEAT: int = CombatScript.CombatResult.DEFEAT
const COMBAT_RETREAT: int = CombatScript.CombatResult.RETREAT

var ts: Node = null
var gsm: Node = null
var cs: Node = null
var _player_before: Dictionary = {}
var _collection_before: Dictionary = {}
var _db_before: Dictionary = {}
var _validation_before: bool = false


func before_each() -> void:
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		fail_test("GSM Autoload 未注册")
		return
	_player_before = (gsm.player as Dictionary).duplicate(true)
	_collection_before = (gsm.collection as Dictionary).duplicate(true)
	# GSM 的校验模板库只认第一次 enable_validation（跨套件共享）——别的套件可能已灌入
	# 桩模板，本夹具要用自己的夹具模板，故临时补齐后原样还原（同 test_battle_reward_grant）。
	_db_before = gsm.get("_card_template_database").duplicate(true)
	_validation_before = bool(gsm.validation_enabled)
	var database: Dictionary = _db_before
	for id: StringName in [GOLD_A, GOLD_B, WHITE_C, DARK_D]:
		database[str(id)] = database.get(str(id), {})
	gsm.set("_card_template_database", database)
	gsm.validation_enabled = true

	cs = _make_card_system()
	ts = TS_SCRIPT.new()
	ts.set("_card_override", cs)
	gsm.player.cultivation = BASE_MAX
	gsm.player.max_cultivation = BASE_MAX
	gsm.player.realm = 1
	gsm.player.tribulation_state = 0
	gsm.player.consecutive_tribulation_failures = 0
	gsm.set("_signal_chain_depth", 0)
	gsm.get("_signal_router").set("_pending_changes", [])
	# 选牌 RNG 固定种子——同一夹具下「取张数」可复现
	var settlement: RefCounted = ts.call("_get_settlement")
	var pool: RefCounted = PoolScript.new()
	pool.rng.seed = 20261121
	settlement.set("_reward_pool_instance", pool)


func after_each() -> void:
	if ts != null:
		ts.free()
		ts = null
	if cs != null:
		cs.free()
		cs = null
	gsm.player = _player_before
	gsm.collection = _collection_before
	gsm.set("_card_template_database", _db_before)
	gsm.validation_enabled = _validation_before


# ═══════════════════════════════════════════════════════════════════════════════
# 夹具构造
# ═══════════════════════════════════════════════════════════════════════════════

## 造一个灌入夹具模板的 CardSystem 实例（不调 _ready——不走异步加载）。
func _make_card_system() -> Node:
	var system: Node = CS_SCRIPT.new()
	_add_template(system, GOLD_A, "测试金卡甲", TemplateClass.Rarity.GOLD)
	_add_template(system, GOLD_B, "测试金卡乙", TemplateClass.Rarity.GOLD)
	_add_template(system, WHITE_C, "测试白卡", TemplateClass.Rarity.WHITE)
	_add_template(system, DARK_D, "测试暗金卡", TemplateClass.Rarity.DARK_GOLD)
	return system


func _add_template(p_system: Node, p_id: StringName, p_name: String,
		p_rarity: int) -> void:
	var tpl := TemplateClass.new()
	tpl.card_id = p_id
	tpl.name = p_name
	tpl.rarity = p_rarity as TemplateClass.Rarity
	p_system.templates[p_id] = tpl


## 修为满 → 触发渡劫 → 推进到 IN_COMBAT（结算的幂等守卫要求真在打）。
func _enter_combat(p_cross_realm: bool = false) -> void:
	var trib_type: int = TS_SCRIPT.TribulationType.CROSS_REALM if p_cross_realm \
			else TS_SCRIPT.TribulationType.NORMAL
	ts.call("trigger_tribulation", trib_type)
	ts.call("_set_state", TS_SCRIPT.TribulationState.IN_COMBAT)


# ═══════════════════════════════════════════════════════════════════════════════
# 读数据
# ═══════════════════════════════════════════════════════════════════════════════

func _owned() -> Array:
	return gsm.collection.owned_cards as Array


func _owned_count() -> int:
	return _owned().size()


func _cultivation() -> int:
	return int(gsm.player.cultivation)


func _realm() -> int:
	return int(gsm.player.realm)
