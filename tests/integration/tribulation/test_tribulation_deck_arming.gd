extends GutTest
## 渡劫战开战前置回归：委托渡劫系统的路上，[b]布阵与洗牌不能缺席[/b]。[br]
## [br][b]钉住的是什么[/b]：真机走查现场——从修炼室按「渡劫」进天劫战，
## 战斗提示行是「[code]≡牌库:0｜弃:0｜无手牌｜第 21 回合[/code]」，玩家一张牌都
## 出不了、对局打不完、结算永不触发（[code]境界 1→1｜修为 1000→1000[/code]）。[br]
## [br][b]根因[/b]：开局手牌在 [code]CombatSystem.battle_start[/code] 里从[b]牌堆[/b]发，
## 而牌堆由 [code]CombatSceneBattleSetup[/code] 在开战前 [code]init_deck[/code] 备好。
## 探索那条路走父类 [method CombatScene._start_battle] → 开战启动器一次性备齐；
## [code]TribulationScene[/code] 覆写了 [method TribulationScene._start_battle]
## 把开战交给 [code]TribulationSystem.start_tribulation_combat[/code]——
## 那条路上没人备数据，于是洗牌整段被跳过。[br]
## [br][b]为什么是集成测试[/b]：要验的是「场景 + 渡劫系统 + 开战前置三者接起来之后
## 顺序对不对」，光调 [code]arm_field_and_deck[/code] 断言不了接线（那段本来就对，
## 缺的是调用）。渡劫状态机、状态闸、场景挂载都用真实实现。[br]
## [br][b]替身只有三处，各有必要[/b]：导航桩（真转场会换场景、测试树被拆）、
## 战斗桩（只记调用顺序与载荷，无头环境不真起一场仗）、卡组桩（喂确定的牌面，
## 不依赖 GSM 里那份会被别的用例改动的数据）。[br]
## [br][b]顺序用共享账本记[/b]：布阵在 [code]DeploymentSystem[/code]、洗牌与开战在
## [code]CombatSystem[/code]——是三个对象上的三件事，不共用一个 log 就只能断言
## 「都发生过」而断言不了「谁先谁后」，而先后正是本缺陷的全部。[br]
## [br]来源: design/gdd/tribulation-system.md §3、ADR-0008 §生命周期、
## ADR-0021 §start_tribulation_combat、gate-check §B1、2026-11-25 真机走查。

const TribulationScenePath: String = "res://src/feature/tribulation/tribulation_scene.tscn"
const TS_SCRIPT := preload("res://src/feature/tribulation_system.gd")
## AISystem 全局名册的借用—归还守卫（见 [member _ai_roster_snapshot]）。
const AiRosterGuard := preload("res://tests/fixtures/ai_roster_guard.gd")

## 本局卡组（3 张——够发开局手牌，又小到一眼看得出是不是这一副）。
const DECK_IDS: Array = [101, 102, 103]
const DEPLOY_IDS: Array = [7]


## 战斗桩——记录 [code]{init_deck, battle_start}[/code] 的顺序与载荷。[br]
## [br][b]为什么记顺序而不是只记次数[/b]：[code]battle_start[/code] 之后才
## [code]init_deck[/code] 同样是「洗了牌」，但开局手牌已经发完了——次数断言
## 对这条缺陷完全无感。
class CombatOrderStub extends Node:
	signal battle_ended(result: int, rewards: Dictionary)

	var log: Array = []
	var deck_ids: Array = []
	var config: Dictionary = {}
	var active: bool = false

	func init_deck(card_ids: Array) -> void:
		log.append("init_deck")
		deck_ids = card_ids.duplicate()

	func battle_start(p_config: Dictionary) -> void:
		log.append("battle_start")
		config = p_config.duplicate(true)
		active = true

	func is_battle_active() -> bool:
		return active

	func confirm_retreat() -> void:
		active = false

	## 反馈协调器的 hp_reader_cb 契约（生产为 CombatSystem.get_character_hp）。
	func get_character_hp(_character_id: int) -> Dictionary:
		return {"current": 10, "max": 10}

	func get_battle_enemy_roster() -> Array:
		return []


## 布阵桩——与战斗桩共用一本账（顺序跨对象才看得出来）。
class DeploymentStub extends Node:
	var log: Array = []

	func setup_field(character_ids: Array, _layout: Dictionary = {}) -> bool:
		log.append("setup_field")
		return not character_ids.is_empty()


## 导航桩——记录转场请求，不真跳场景。
class SceneManagerStub extends Node:
	var requests: Array = []
	var current_id: int = 10

	func get_current_scene_id() -> int:
		return current_id

	func request_scene_change(from: int, to: int, type: int) -> bool:
		requests.append({"from": from, "to": to, "type": type})
		return true


## 卡组桩——喂确定的牌面（GSM 里那份会被别的用例改动）。[br]
## [br][b]为什么是 Node 不是 RefCounted[/b]：容器上的 [code]deck_system[/code]
## 是 [code]Node[/code] 类型的注入点，塞 RefCounted 进去类型不匹配——注入会静默
## 落空，测试读到的是真 Autoload 的卡组（本用例要喂的是确定的牌面）。
class DeckStub extends Node:
	func get_deck_cards() -> Array:
		return DECK_IDS.duplicate()


var scene: Control = null
var sm: SceneManagerStub = null
var combat: CombatOrderStub = null
var deployment: DeploymentStub = null
var deck: DeckStub = null
var gsm: Node = null
var _player_snapshot: Dictionary = {}
## AISystem 全局名册的借用凭据——本组用例走真实开战前置，天劫雷灵会被写进那个
## 跨套件共享的 Autoload（见 [AiRosterGuard]）。
var _ai_roster_snapshot: Array = []


func before_each() -> void:
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	assert_not_null(gsm, "GSM Autoload 未注册")
	_player_snapshot = (gsm.get("player") as Dictionary).duplicate(true)
	_ai_roster_snapshot = AiRosterGuard.capture()
	sm = SceneManagerStub.new()
	add_child_autofree(sm)
	combat = CombatOrderStub.new()
	add_child_autofree(combat)
	deployment = DeploymentStub.new()
	add_child_autofree(deployment)
	deck = DeckStub.new()
	add_child_autofree(deck)
	# 布阵与洗牌共用一本账——「谁先谁后」是本次要钉的那条。
	deployment.log = combat.log
	# 渡劫系统接的是同一个战斗桩（状态闸过后它会自己调 battle_start）。
	_gss().set("_combat_override", combat)
	# 渡劫流程已在准备阶段——这是从修炼室/节点图进来的真实入口状态。
	gsm.player.tribulation_state = TS_SCRIPT.TribulationState.PREPARING
	gsm.player.realm = 1
	scene = _instantiate(TribulationScenePath)
	scene.set("scene_manager", sm)
	scene.set("combat_system", combat)
	scene.set("deployment_system", deployment)
	scene.set("deck_system", deck)
	scene.set("reduce_motion_override", true)
	add_child_autofree(scene)

func after_each() -> void:
	if gsm != null and not _player_snapshot.is_empty():
		gsm.player.clear()
		gsm.player.merge(_player_snapshot, true)
	_gss().set("_combat_override", null)
	AiRosterGuard.restore(_ai_roster_snapshot)
	scene = null
	sm = null
	combat = null
	deployment = null


# ═══════════════════════════════════════════════════════════════════════════════
# 1-2：洗牌必须在开战之前（本缺陷的正面）
# ═══════════════════════════════════════════════════════════════════════════════

func test_tribulation_arms_deck_before_battle_start() -> void:
	# Act——备战确认（真信号，与玩家点「确认出战」同一入口）
	_confirm()
	# Assert——洗牌发生过，且严格排在开战之前（反过来等于开局发 0 张）
	assert_true(combat.log.has("init_deck"),
			"渡劫战开战前必须先把牌堆交给战斗系统——否则开局手牌发不出（牌库 0 / 无手牌）")
	assert_true(combat.log.has("battle_start"), "确认出战应真的开战")
	assert_lt(combat.log.find("init_deck"), combat.log.find("battle_start"),
			"init_deck 必须早于 battle_start：开局手牌在 battle_start 内从牌堆发出")


func test_tribulation_hands_the_real_deck_to_combat_system() -> void:
	# Act
	_confirm()
	# Assert——洗的是本局卡组，不是空表也不是别的一副
	assert_eq(combat.deck_ids, DECK_IDS, "交给牌堆的应是本局卡组的实例 ID")


func test_tribulation_setups_field_before_battle_start() -> void:
	# Act
	_confirm()
	# Assert——阵位同样要在开战前落地（Phase 6「己方全灭」判据读的就是它）
	assert_true(deployment.log.has("setup_field"), "渡劫战开战前应布阵")
	assert_lt(deployment.log.find("setup_field"), combat.log.find("battle_start"),
			"布阵必须早于 battle_start")


## 洗一次就够——重复洗会把已发的开局手牌换掉。
func test_tribulation_arms_deck_once() -> void:
	# Act
	_confirm()
	# Assert
	var times: int = 0
	for entry: String in combat.log:
		if entry == "init_deck":
			times += 1
	assert_eq(times, 1, "渡劫开战路径只应洗一次牌（父类开战启动器不得再备一次）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3：开战载荷仍是渡劫配置（前置补齐没有把开战改成普通遭遇）
# ═══════════════════════════════════════════════════════════════════════════════

func test_tribulation_battle_start_still_carries_tribulation_config() -> void:
	# Act
	_confirm()
	# Assert——交出去的仍是渡劫配置（由渡劫系统组装，不是本类备的敌方名册）
	assert_true(bool(combat.config.get("is_tribulation", false)),
			"开战载荷应仍标记 is_tribulation")
	assert_true(combat.config.has("tribulation_data"), "渡劫配置应带 tribulation_data")


# ═══════════════════════════════════════════════════════════════════════════════
# 4：降级路径不受影响（渡劫系统没接战时仍走父类那条完整的备数据路）
# ═══════════════════════════════════════════════════════════════════════════════

func test_fallback_path_still_arms_deck_before_battle_start() -> void:
	# Arrange——状态机不在 PREPARING（实机直入渡劫场景的情形）
	gsm.player.tribulation_state = TS_SCRIPT.TribulationState.NOT_READY
	# Act
	_confirm()
	# Assert——降级为普通开战，牌堆照样先就位
	assert_true(combat.active, "非 PREPARING 时应降级开战（不退化成「点了没反应」）")
	assert_true(combat.log.has("init_deck"), "降级路径同样要先洗牌")
	assert_lt(combat.log.find("init_deck"), combat.log.find("battle_start"),
			"降级路径的 init_deck 同样必须早于 battle_start")


# ═══════════════════════════════════════════════════════════════════════════════
# 小工具
# ═══════════════════════════════════════════════════════════════════════════════

## 备战确认——与玩家点「确认出战」走同一个信号入口。
func _confirm() -> void:
	var deploy: Variant = (scene.get("combat_root") as Control).get("deploy_panel")
	assert_not_null(deploy, "渡劫场景应装配备战面板")
	deploy.emit_signal("confirm_requested", DEPLOY_IDS.duplicate())


func _instantiate(path: String) -> Control:
	var packed: PackedScene = load(path)
	return packed.instantiate() as Control


## 真实的 TribulationSystem Autoload（`_combat_override` 注入点就在它身上）。
func _gss() -> Node:
	return (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/TribulationSystem")
