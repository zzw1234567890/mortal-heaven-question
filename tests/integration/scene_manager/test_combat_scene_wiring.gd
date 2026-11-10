extends GutTest
## Sprint 18 场景补链回归：战斗/渡劫薄容器的挂载与出口接线。
##
## [b]背景[/b]（gate-check 2026-11-08 §B1）：`SCENE_PATHS[COMBAT]` 此前无资产，
## 节点图「进入战斗」必然回退主菜单。本文件验证两件事：[br]
##   1. `combat_scene.tscn` 真的挂上了 `CombatRoot`（四区域 / 备战面板 / 结算宿主）；[br]
##   2. 容器的三个出口（确认出战 / 备战返回 / 撤退确认）分别落到战斗系统与
##      `SceneManager.request_scene_change`——且导航一律走 SceneManager（ADR-0005）。
##
## 依赖全部注入桩（stub）——不触发真实战斗与真实转场。

const CombatScenePath: String = "res://src/feature/combat/combat_scene.tscn"
const TribulationScenePath: String = "res://src/feature/tribulation/tribulation_scene.tscn"

## 桩战斗系统——记录 battle_start 载荷与 confirm_retreat 调用次数。
class CombatStub extends Node:
	## 结算接线订阅的 Cat 2b 信号（载荷同生产：result + rewards）。
	signal battle_ended(result: int, rewards: Dictionary)

	var last_config: Dictionary = {}
	var retreat_calls: int = 0
	var active: bool = false
	var hp_store: Dictionary = {}

	func battle_start(config: Dictionary) -> void:
		last_config = config.duplicate(true)
		active = true

	func is_battle_active() -> bool:
		return active

	func confirm_retreat() -> void:
		retreat_calls += 1
		active = false

	## 反馈协调器的 hp_reader_cb 契约（生产为 CombatSystem.get_character_hp）。
	func get_character_hp(character_id: int) -> Dictionary:
		return hp_store.get(character_id, {"current": 0, "max": 0})

	## 敌方名册快照（角色卡装配台建卡用）。
	func get_battle_enemy_roster() -> Array:
		return []


## 桩场景管理器——记录导航请求；`audio` 恒为 null（不创建真实音频节点池）。
class SceneManagerStub extends Node:
	var requests: Array = []
	var current_id: int = 4

	func get_current_scene_id() -> int:
		return current_id

	func get_audio_manager() -> Variant:
		return null

	func request_scene_change(from: int, to: int, type: int) -> bool:
		requests.append({"from": from, "to": to, "type": type})
		return true


## 桩布阵系统——记录 setup_field 调用（DEBT-CBT-018-1：开战前必须落位）。
class DeploymentStub extends Node:
	var setups: Array = []
	var accepted: bool = true

	func setup_field(character_ids: Array, _layout: Dictionary = {}) -> bool:
		setups.append(character_ids.duplicate())
		return accepted


var scene: Control = null
var sm: SceneManagerStub = null
var combat: CombatStub = null
var deployment: DeploymentStub = null


func before_each() -> void:
	sm = SceneManagerStub.new()
	add_child_autofree(sm)
	combat = CombatStub.new()
	add_child_autofree(combat)
	deployment = DeploymentStub.new()
	add_child_autofree(deployment)
	scene = _instantiate(CombatScenePath)
	scene.set("scene_manager", sm)
	scene.set("combat_system", combat)
	scene.set("deployment_system", deployment)
	scene.set("reduce_motion_override", true)  # 进场动画直跳终态（确定性）
	add_child_autofree(scene)


func after_each() -> void:
	scene = null
	sm = null
	combat = null
	deployment = null


## 实例化场景（不立即进树——先注入桩依赖再 add_child）。
func _instantiate(path: String) -> Control:
	var packed: PackedScene = load(path)
	return packed.instantiate() as Control


# ═══════════════════════════════════════════════════════════════════════════════
# 结构：CombatRoot 挂载
# ═══════════════════════════════════════════════════════════════════════════════

func test_combat_scene_mounts_combat_root() -> void:
	assert_not_null(scene.get("combat_root"), "战斗场景应挂载 CombatRoot")
	var root: Control = scene.get("combat_root") as Control
	for zone_name: String in ["TopBar", "EnemyArea", "AllyArea", "BottomBar"]:
		assert_not_null(root.get_node_or_null(zone_name),
				"CombatRoot 应含区域容器 %s" % zone_name)


func test_combat_scene_mounts_deploy_panel_visible_by_default() -> void:
	var deploy: Variant = (scene.get("combat_root") as Control).get("deploy_panel")
	assert_not_null(deploy, "战斗场景应装配备战面板")
	assert_true((deploy as Control).visible,
			"进入战斗场景即展示备战面板（唯一开战入口）")


func test_combat_scene_exposes_retreat_button_enabled() -> void:
	var root: Control = scene.get("combat_root") as Control
	var button: Button = root.get("retreat_button") as Button
	assert_not_null(button, "战斗场景应装配撤退按钮")
	assert_false(button.disabled, "撤退按钮渲染态常亮（GDD §10）")


# ═══════════════════════════════════════════════════════════════════════════════
# 出口：确认出战 / 返回 / 撤退
# ═══════════════════════════════════════════════════════════════════════════════

func test_deploy_confirmed_starts_battle_once_with_ids() -> void:
	# Arrange: 备战面板选定两名角色后确认
	var deploy: Variant = (scene.get("combat_root") as Control).get("deploy_panel")
	deploy.emit_signal("confirm_requested", [101, 202])
	# Assert: 战斗系统收到一次开战请求，载荷含角色 ID
	assert_true(combat.active, "确认出战应启动战斗")
	assert_eq(combat.last_config.get("character_ids"), [101, 202],
			"battle_start 载荷应携带已选角色 ID")
	assert_false((deploy as Control).visible, "确认后备战面板应隐藏")


## DEBT-CBT-018-1：开战前须把所选角色写入阵位——否则 Phase 6 END 的
## 「己方全灭」判据读不到「阵位曾有人」，阵亡永远判不出战败。
func test_deploy_confirmed_setups_field_before_battle_start() -> void:
	# Act
	var deploy: Variant = (scene.get("combat_root") as Control).get("deploy_panel")
	deploy.emit_signal("confirm_requested", [101, 202])
	# Assert
	assert_eq(deployment.setups.size(), 1, "确认出战应布阵一次")
	assert_eq(deployment.setups[0], [101, 202], "布阵名册应与开战名册一致")


# ═══════════════════════════════════════════════════════════════════════════════
# 表现层接线（DEBT-CBT-018-1 残留：反馈协调器此前无生产实例化点）
# ═══════════════════════════════════════════════════════════════════════════════

func test_combat_scene_mounts_feedback_coordinator() -> void:
	var root: Control = scene.get("combat_root") as Control
	assert_not_null(root.get("feedback"), "战斗根应实例化 CombatFeedbackCoordinator")
	assert_not_null(root.get("actor_stage"), "战斗根应实例化角色卡装配台")


## 生产接线：hp_reader_cb 必须指向战斗系统的读取契约（UI 不缓存 HP）。
func test_feedback_hp_reader_bound_to_combat_system() -> void:
	# Arrange
	var root: Control = scene.get("combat_root") as Control
	var feedback: Control = root.get("feedback") as Control
	assert_true(feedback.hp_reader_cb.is_valid(), "hp_reader_cb 应已注入")
	# Act——战斗系统换上真实 HP 后经回调读取
	combat.hp_store = {101: {"current": 42, "max": 60}}
	var hp: Dictionary = feedback.hp_reader_cb.call(101)
	# Assert
	assert_eq(int(hp["current"]), 42, "hp_reader_cb 应直达 CombatSystem.get_character_hp")
	assert_eq(int(hp["max"]), 60, "max 同源读取")


## 确认出战后按名册建卡并注册进编排器——HP 条/飘字/阵亡动效才有对象可作用于。
func test_deploy_confirmed_builds_roster_cards() -> void:
	# Arrange
	combat.hp_store = {101: {"current": 50, "max": 50}, 202: {"current": 30, "max": 30}}
	var root: Control = scene.get("combat_root") as Control
	var stage: Node = root.get("actor_stage") as Node
	var feedback: Control = root.get("feedback") as Control
	# Act
	var deploy: Variant = root.get("deploy_panel")
	deploy.emit_signal("confirm_requested", [101, 202])
	# Assert
	assert_eq(stage.call(&"card_count"), 2, "两名上场角色应各建一张卡")
	assert_eq(feedback._cards.size(), 2, "建好的卡应注册进反馈编排器")
	var card: Control = stage.call(&"get_card", 101)
	assert_not_null(card, "角色 101 应有卡")
	assert_eq(card.current_hp, 50, "卡片初始 HP 应读战斗系统种子值")


func test_deploy_confirmed_is_idempotent_while_active() -> void:
	var deploy: Variant = (scene.get("combat_root") as Control).get("deploy_panel")
	deploy.emit_signal("confirm_requested", [101])
	combat.last_config = {}
	# Act: 再次确认
	deploy.emit_signal("confirm_requested", [303])
	# Assert: 不重复开战（载荷未被覆盖）
	assert_eq(combat.last_config, {}, "战斗中重复确认不应再次 battle_start")


func test_deploy_back_requests_exploration_transition() -> void:
	# Act
	var deploy: Variant = (scene.get("combat_root") as Control).get("deploy_panel")
	deploy.emit_signal("back_requested")
	# Assert: 唯一导航入口 = SceneManager，目标 EXPLORATION
	assert_eq(sm.requests.size(), 1, "返回探索应发出一次转场请求")
	var req: Dictionary = sm.requests[0]
	assert_eq(int(req["from"]), 4, "from 应取当前场景 ID（COMBAT）")
	assert_eq(int(req["to"]), 3, "目标应为 EXPLORATION")
	assert_eq(int(req["type"]), 4, "转场类型应为 COMBAT_TO_EXPLORE")


func test_retreat_confirmed_while_active_delegates_to_combat_system() -> void:
	# Arrange: 先开战
	var deploy: Variant = (scene.get("combat_root") as Control).get("deploy_panel")
	deploy.emit_signal("confirm_requested", [101])
	var host: Variant = (scene.get("combat_root") as Control).get("settlement_host")
	# Act
	host.emit_signal("retreat_confirmed")
	# Assert: 交给战斗系统收尾（结算/转场由 battle_end 负责），容器不自行跳转
	assert_eq(combat.retreat_calls, 1, "撤退确认应委托 CombatSystem.confirm_retreat")
	assert_eq(sm.requests.size(), 0, "活跃战斗的撤退不由容器直接转场")


func test_retreat_confirmed_without_active_battle_returns_to_exploration() -> void:
	# Arrange: 未开战（备战阶段点撤退）
	var host: Variant = (scene.get("combat_root") as Control).get("settlement_host")
	# Act
	host.emit_signal("retreat_confirmed")
	# Assert: 不卡在空战场——直接回探索
	assert_eq(combat.retreat_calls, 0, "未开战不应调用战斗系统撤退")
	assert_eq(sm.requests.size(), 1, "未开战撤退应回探索")
	assert_eq(int(sm.requests[0]["to"]), 3, "目标应为 EXPLORATION")


func test_defeat_confirmed_returns_to_exploration() -> void:
	# Act
	var host: Variant = (scene.get("combat_root") as Control).get("settlement_host")
	host.emit_signal("defeat_confirmed")
	# Assert
	assert_eq(sm.requests.size(), 1, "战败确认应回探索")
	assert_eq(int(sm.requests[0]["type"]), 4, "转场类型应为 COMBAT_TO_EXPLORE")


# ═══════════════════════════════════════════════════════════════════════════════
# 渡劫变体
# ═══════════════════════════════════════════════════════════════════════════════

func test_tribulation_scene_marks_is_tribulation() -> void:
	# Arrange: 渡劫场景（独立实例——不复用 combat 场景）
	var trib: Control = _instantiate(TribulationScenePath)
	trib.set("scene_manager", sm)
	trib.set("combat_system", combat)
	trib.set("deployment_system", deployment)
	trib.set("reduce_motion_override", true)
	add_child_autofree(trib)
	# Assert: 结算宿主按渡劫变体装配（红框 80% 撤退 + 战前警示）
	assert_true(bool(trib.get("is_tribulation")), "渡劫场景应标记 is_tribulation")
	var host: Variant = (trib.get("combat_root") as Control).get("settlement_host")
	assert_true(bool(host.get("is_tribulation")),
			"结算宿主应继承渡劫标识（撤退 80% 变体）")


# ═══════════════════════════════════════════════════════════════════════════════
# 结算回流接线（Sprint 18）——battle_ended → CombatResultView
# ═══════════════════════════════════════════════════════════════════════════════

const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")

## 战斗结束 → 结算对象发布（结算/战败场景据此取数）。
func test_battle_ended_publishes_result_view() -> void:
	# Arrange
	assert_not_null(scene.get("result_bridge"), "战斗场景应装配结算接线")
	ViewScript.clear()
	# Act
	combat.battle_ended.emit(1, {"result": 1, "record": {
		"outcome": "victory", "turn_count": 2, "effect_entries": 4,
		"player": {"count": 1, "alive_count": 1, "remaining_hp": 6},
		"enemy": {"count": 1, "alive_count": 0, "remaining_hp": 0},
	}})
	# Assert
	var view: RefCounted = ViewScript.last()
	assert_not_null(view, "battle_ended 应发布结算对象")
	assert_eq(int(view.call(&"player_remaining_hp")), 6, "我方剩余 HP 应可读")
	ViewScript.clear()


## 接线挂在注入的战斗系统上（而非另找 Autoload）——注入优先的容器口径。
## [br][b]退订语义[/b]由 [code]test_combat_result_bridge.gd::test_unbind_stops_publishing[/code]
## 覆盖：容器 [code]_exit_tree[/code] 只是调用同一入口，在场景内出树会牵动
## [code]SettlementHost[/code] 的销毁路径（既有缺陷，另案登记）。
func test_result_bridge_bound_to_injected_combat_system() -> void:
	# Arrange
	var bridge: RefCounted = scene.get("result_bridge")
	assert_not_null(bridge, "战斗场景应装配结算接线")
	# Act——桩战斗系统发信号
	combat.battle_ended.emit(1, {"result": 1})
	# Assert——发布方就是本容器持有的接线
	assert_eq(ViewScript.last(), bridge.get("published"), "发布应经本容器的接线实例")
	ViewScript.clear()


func test_tribulation_deploy_confirms_falls_back_to_plain_battle() -> void:
	# Arrange: 渡劫系统未处于 PREPARING（实机直入场景的情形）
	var trib: Control = _instantiate(TribulationScenePath)
	trib.set("scene_manager", sm)
	trib.set("combat_system", combat)
	trib.set("deployment_system", deployment)
	trib.set("reduce_motion_override", true)
	add_child_autofree(trib)
	var deploy: Variant = (trib.get("combat_root") as Control).get("deploy_panel")
	# Act
	deploy.emit_signal("confirm_requested", [101])
	# Assert: 降级为普通开战（不退化成「点了没反应」）
	assert_true(combat.active, "渡劫系统未接战时应降级开战")
	assert_eq(bool(combat.last_config.get("is_tribulation")), true,
			"降级开战仍应携带渡劫标识")
