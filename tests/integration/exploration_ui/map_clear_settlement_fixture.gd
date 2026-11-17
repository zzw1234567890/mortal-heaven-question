extends GutTest
## MapClearSettlementFixture —— 地图通关结算用例的共享夹具。[br]
## [br][b]为什么单独一处[/b]：用例文件要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「怎么进图、怎么造一场 Boss 胜利」与
## 「断言什么」是两件事（同 [code]exploration_exit_fixture.gd[/code] 先例）。[br]
## [br][b]用法[/b]：子类 [code]extends "res://…/map_clear_settlement_fixture.gd"[/code]，
## 直接写 [code]test_*[/code] 方法即可；[code]before_each[/code] /
## [code]after_each[/code] 由本夹具提供，子类若要扩展需先 [code]super()[/code]。[br]
## [br][b]文件前缀[/b]：本文件不以 [code]test_[/code] 开头——GUT 按前缀收集，
## 因此它只作为基类被继承，不会被当作用例文件单独执行。[br]
## [br][b]用真实 Autoload[/b]：本组用例验证的正是生产接线（结算场景 → 探索系统 →
## GSM → 面板），而 [code]PlaceholderScene._settle_boss_victory[/code] 与
## [code]ExplorationScene[/code] 都按 [code]/root/[/code] 查 Autoload，没有注入点。[br]
## [br][b]存档隔离[/b]：player / collection / 校验库 / exploration 域 / 跨场景静态
## 缓存在 [code]before_each[/code] 快照、[code]after_each[/code] 原样还原
## （同 [code]shop_rest_node_fixture.gd[/code] 口径）。[br]
##
## 来源: design/gdd/exploration-system.md §5 地图通关奖励、exploration-ui-system.md §7、
## ADR-0014 §决策 5、ADR-0031 §2。

const SceneScript := preload("res://src/feature/exploration/exploration_scene.gd")
const BootstrapScript := preload("res://src/feature/exploration/exploration_bootstrap.gd")
const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")
const LaunchScript := preload("res://src/feature/combat/combat_launch_context.gd")
const ClearView := preload("res://src/feature/exploration/map_clear_view.gd")
const ResultScreenScript := preload("res://src/ui/result_screen/result_screen.gd")
## 卡牌模板就位助手（异步加载的同步推进——与商店/炼制用例共用）。
const PrimerScript := preload("res://tests/integration/exploration_ui/card_template_primer.gd")

## 用例地图（探明表里青云剑宗为 LOW 档，首通档位表 LOW = 灵石 50 / 修为 30 / 培元丹）。
const MAP_ID: StringName = &"qing_yun_jian_zong"
## 青云剑宗的首通彩头（[code]exploration_first_clear_rewards.gd[/code] LOW 档）。
const FIRST_CLEAR_CARD: StringName = &"pei_yuan_dan"
## 战斗开始的节点 ID（非入口即可——只用来验证标记路由）。
const BOSS_NODE: int = 310

var gsm: Node = null
var es: Node = null
var scene: Control = null
var _player_before: Dictionary = {}
var _collection_before: Dictionary = {}
var _db_before: Dictionary = {}
var _validation_before: bool = false
var _exploration_before: Dictionary = {}
var _resources_before: Dictionary = {}


func before_each() -> void:
	gsm = get_node_or_null(NodePath("/root/GameStateManager"))
	es = get_node_or_null(NodePath("/root/ExplorationSystem"))
	assert_not_null(es, "本文件需要真实 ExplorationSystem Autoload")
	_player_before = (gsm.player as Dictionary).duplicate(true)
	_collection_before = (gsm.collection as Dictionary).duplicate(true)
	_db_before = (gsm.get("_card_template_database") as Dictionary).duplicate(true)
	_validation_before = bool(gsm.validation_enabled)
	_exploration_before = (gsm.exploration as Dictionary).duplicate(true)
	_resources_before = (gsm.player.resources as Dictionary).duplicate(true)
	_prepare_card_validation()
	ViewScript.clear()
	LaunchScript.clear()
	ClearView.clear()
	_reset_gsm()
	# 生产装配（地图配置 + 敌人池 + 货架）——未装配时地图名与首通档位都取不到
	BootstrapScript.mount(es, get_node_or_null(NodePath("/root/AISystem")))
	if es.has_method(&"set_rng_seed"):
		es.call("set_rng_seed", 42)


func after_each() -> void:
	ViewScript.clear()
	LaunchScript.clear()
	ClearView.clear()
	gsm.player = _player_before
	gsm.collection = _collection_before
	gsm.set("_card_template_database", _db_before)
	gsm.validation_enabled = _validation_before
	gsm.exploration = _exploration_before
	gsm.player.resources = _resources_before
	gsm.set("_signal_chain_depth", 0)
	var router: Variant = gsm.get("_signal_router")
	if router != null:
		router.set("_pending_changes", [])
	if es != null and es.has_method(&"clear_dag_cache"):
		es.call("clear_dag_cache")
	if scene != null and is_instance_valid(scene):
		scene.free()
	scene = null


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 进一张真实地图（[code]current_map[/code] 就位——结算要有活跃地图才跑得起来）。[br]
## [br][param p_map_id] 目标地图（缺省 [constant MAP_ID]；重入链路的用例换用收费地图）。[br]
## [br][b]不走解锁门禁[/b]：门禁是选图界面的事（[code]ExplorationMapGate[/code]），
## 本装置直调系统侧 [code]enter_map[/code]——用例要的是「在图里」这个前提，
## 不是再验一遍解锁。
func enter_map(p_map_id: StringName = MAP_ID) -> void:
	es.call(&"enter_map", p_map_id, 1, 10)
	assert_eq(gsm.exploration.get("current_map"), p_map_id, "前置：已进入 %s" % p_map_id)


## 造一场胜利结算（走真实结算场景的收尾入口，与生产同一条路径）。[br]
## [br][param p_combat_type] 开战上下文里的战斗类型——[code]boss[/code] 时胜利 =
## 本图通关；缺省（旧调用方）走「只标一格已清」。[br]
## [br][b]返回[/b]：结算场景实例（已挂树——断言用）。
func run_victory(p_combat_type: StringName = &"") -> Node:
	ViewScript.publish(_victory_view())
	var context: Dictionary = {LaunchScript.KEY_NODE_ID: BOSS_NODE}
	if p_combat_type != &"":
		context[LaunchScript.KEY_COMBAT_TYPE] = p_combat_type
	LaunchScript.publish(context)
	var screen: Node = ResultScreenScript.new()
	screen.set(&"screen_id", 8)
	add_child_autofree(screen)
	screen.call(&"_mark_battle_node_cleared_if_victory")
	return screen


## 走完整闭环：进图 → Boss 胜利 → 探索场景挂载（面板在此时弹）。
## [br][b]返回[/b]：本次结算摘要（[code]end_exploration[/code] 的载荷由系统持有，
## 断言走 GSM 与 [code]MapClearView[/code]）。
func run_boss_clear(p_mount_scene: bool = true) -> void:
	enter_map()
	run_victory(LaunchScript.COMBAT_TYPE_BOSS)
	if p_mount_scene:
		scene = SceneScript.new()
		add_child_autofree(scene)


## 某图在 [code]map_states[/code] 里的状态（结算写的就是它）。[br]
## [br][param p_map_id] 目标地图（缺省 [constant MAP_ID]——重入链路的用例换图读）。[br]
## [br][b]读的是 GSM 现取[/b]：结算写完立刻可读，用例不必等信号。
func map_state(p_map_id: StringName = MAP_ID) -> Dictionary:
	var states: Dictionary = gsm.exploration.get("map_states", {})
	var state: Variant = states.get(p_map_id, {})
	return state if state is Dictionary else {}


## 一批收藏里的模板 ID（含判定用——首通彩头在不在）。
func owned_templates() -> Array:
	var out: Array = []
	for card: Variant in gsm.collection.owned_cards:
		out.append(str((card as Dictionary).get("template_id", "")))
	return out


func owned_count_of(p_template_id: StringName) -> int:
	var count: int = 0
	for tid: String in owned_templates():
		if tid == str(p_template_id):
			count += 1
	return count


func ling_shi() -> int:
	return int(gsm.player.resources.get("ling_shi", 0))


func cultivation() -> int:
	return int(gsm.player.cultivation)


## 当前待展示的通关结算（面板取数的同一份缓存）。
func pending_view() -> Dictionary:
	return ClearView.peek()


## 通关结算面板（探索场景的公开入口——未弹时为 null）。
func panel() -> Variant:
	if scene == null or not is_instance_valid(scene):
		return null
	var presenter: Variant = scene.get(&"map_clear_presenter")
	return presenter.call(&"panel") if presenter != null else null


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 一份胜利结算对象（只填判定用得到的字段——[method CombatResultView.is_victory]）。
func _victory_view() -> RefCounted:
	var view: RefCounted = ViewScript.new()
	view.set("result", ViewScript.RESULT_VICTORY)
	return view


## 重置 GSM 探索域（enter_map 会写 current_map / visited / ap / map_states）。
func _reset_gsm() -> void:
	if gsm == null:
		return
	gsm.exploration = {
		"current_map": &"",
		"node_position": {"layer": 0, "idx": 0},
		"visited_nodes": [],
		"action_points": 0,
		"max_action_points": 0,
		"map_states": {},
	}
	gsm.set("_signal_chain_depth", 0)


## 备好卡牌校验——真实模板注册表 + GSM 校验开启（同 [code]test_battle_reward_grant[/code] 口径）。
## [br]不开启校验时 [code]add_card_to_collection[/code] 直接拒绝，首通卡会静默不入库，
## 用例就分不出「没发」与「发了但被拒」。
func _prepare_card_validation() -> void:
	PrimerScript.prime(CardSystem, FIRST_CLEAR_CARD)
	var database: Dictionary = gsm.get("_card_template_database")
	database[str(FIRST_CLEAR_CARD)] = database.get(str(FIRST_CLEAR_CARD), {})
	gsm.set("_card_template_database", database)
	gsm.validation_enabled = true
