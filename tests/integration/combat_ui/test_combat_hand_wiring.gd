extends GutTest
## 真实对局的手牌供给与刷新（combat-ui-interaction 001 / 本轮）。[br]
## [br][b]背景[/b]：生产路径下此前无人给手牌区供牌（[code]hand_changed[/code] 没有
## 发射方），真实对局的手牌永远是空的——再好的出牌手势也没有卡可点。[br]
## [br][b]本文件锁定三条语义[/b]：[br]
##   1. [method refresh] 把战斗手牌下发到 [code]HandArea[/code]（含卡面目标词）；[br]
##   2. [code]phase_changed[/code] / [code]cost_changed[/code] 到达即刷新（灰显与灵能预览跟随）；[br]
##   3. 退订后信号不再驱动刷新（防场景退场后仍写已释放节点）。

const CombatRootScene: PackedScene = preload("res://src/ui/combat/layout/CombatRoot.tscn")
const Wiring := preload("res://src/ui/combat/interaction/combat_hand_wiring.gd")


## 桩战斗系统——手牌 + 两个信号（phase_changed / character_died）。
class CombatStub extends Node:
	signal phase_changed(old_phase: int, new_phase: int, turn: int)
	signal character_died(character_id: int, side: int, binding_card_ids: Array)

	var hand: Array = []
	var phase: int = 2

	func get_hand() -> Array:
		return hand.duplicate()

	func get_current_phase() -> int:
		return phase


## 桩部署系统——我方阵位（手牌快照不读它，装配台接线需要）。
class DeploymentStub extends Node:
	func get_field() -> Array:
		return [{"slot_index": 0, "character_id": 9301, "is_front": true,
			"state": 1, "deploy_turn": 0}]


## 桩费用系统——can_afford + cost_changed。
class CostStub extends Node:
	signal cost_changed(current: int, max_show: int, total_max: int)

	var current: int = 3

	func get_current_cost() -> int:
		return current

	func can_afford(cost: int) -> bool:
		return cost <= 0 or current >= cost


var layout: Control = null
var combat: CombatStub = null
var cost: CostStub = null
var deployment: DeploymentStub = null
var wiring: RefCounted = null


func before_each() -> void:
	layout = CombatRootScene.instantiate()
	add_child_autofree(layout)
	combat = CombatStub.new()
	add_child_autofree(combat)
	cost = CostStub.new()
	add_child_autofree(cost)
	deployment = DeploymentStub.new()
	add_child_autofree(deployment)
	# 门面接线（手牌快照经装配台 → 战斗系统现读）；交互层把取数收敛在一层
	layout.call(&"setup_feedback", combat, deployment, Callable(), null, null, true)
	layout.call(&"setup_interaction", true)
	combat.hand = [
		{"card_instance_id": 91, "name": "御剑术", "cost": 1,
			"target_type": &"single_enemy"},
		{"card_instance_id": 92, "name": "五行阵", "cost": 9,
			"target_type": &"all_enemy"},
	]
	wiring = Wiring.new()


func after_each() -> void:
	wiring = null


func _hand_area() -> Variant:
	return layout.get(&"hand_area")


## 交互层门面（手牌供给的数据来源——与生产接线同一入口）。
func _interaction() -> Variant:
	return layout.call(&"interaction")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 首次供牌
# ═══════════════════════════════════════════════════════════════════════════════

## 接线即供牌：手牌区拿到两张卡，卡面目标词随之可见。
func test_setup_supplies_hand_snapshot() -> void:
	# Act
	wiring.call(&"setup", layout.call(&"interaction"), combat, cost)
	# Assert
	assert_eq(int(_hand_area().call(&"get_card_count")), 2, "两张卡下发到手牌区")
	assert_eq(_hand_area().call(&"get_card_instance_ids"), [91, 92], "实例 ID 保留")
	var snapshot: Array = _interaction().call(&"hand_snapshot")
	assert_eq(StringName(str(snapshot[0]["target_type"])), &"single_enemy",
			"卡面目标词随快照下发")


## 可负担性按当前灵力判定：1 费可出、9 费灰显。
func test_setup_applies_affordability() -> void:
	wiring.call(&"setup", layout.call(&"interaction"), combat, cost)
	var hand: Variant = _hand_area()
	assert_true(bool(hand.call(&"get_card", 0).get(&"is_affordable")), "1 费可出")
	assert_false(bool(hand.call(&"get_card", 1).get(&"is_affordable")), "9 费灰显")


## 阶段 2 外（灵能预览）——快照照常下发，卡进入预览态。
func test_refresh_respects_non_play_phase() -> void:
	combat.phase = 3
	wiring.call(&"setup", layout.call(&"interaction"), combat, cost)
	assert_eq(int(_hand_area().call(&"get_card_count")), 2, "仍下发快照")
	assert_true(bool(_hand_area().call(&"get_card", 0).get(&"is_psychic")),
			"非出牌阶段进入灵能预览")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 信号驱动刷新
# ═══════════════════════════════════════════════════════════════════════════════

## 费用变化 → 灰显刷新（费用从 3 降到 0，1 费卡变灰）。
func test_cost_changed_refreshes_affordability() -> void:
	wiring.call(&"setup", layout.call(&"interaction"), combat, cost)
	assert_true(bool(_hand_area().call(&"get_card", 0).get(&"is_affordable")), "前置：可出")
	# Act
	cost.current = 0
	cost.cost_changed.emit(0, 5, 5)
	# Assert
	assert_false(bool(_hand_area().call(&"get_card", 0).get(&"is_affordable")),
			"费用耗尽后灰显")


## 手牌变化（打出后）→ 下一次刷新即反映新快照。
func test_refresh_picks_up_new_hand() -> void:
	wiring.call(&"setup", layout.call(&"interaction"), combat, cost)
	# Act——打出一张（战斗侧手牌少一张），再刷新
	combat.hand = [combat.hand[1]]
	wiring.call(&"refresh")
	# Assert
	assert_eq(int(_hand_area().call(&"get_card_count")), 1, "手牌区跟随新快照")


## 阶段切换信号 → 预览态刷新（出牌阶段 → 攻击声明）。
func test_phase_changed_refreshes_preview_state() -> void:
	wiring.call(&"setup", layout.call(&"interaction"), combat, cost)
	assert_false(bool(_hand_area().call(&"get_card", 0).get(&"is_psychic")),
			"前置：出牌阶段非预览")
	# Act
	combat.phase = 3
	combat.phase_changed.emit(2, 3, 1)
	# Assert
	assert_true(bool(_hand_area().call(&"get_card", 0).get(&"is_psychic")),
			"阶段外进入灵能预览")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 退订
# ═══════════════════════════════════════════════════════════════════════════════

## 退订后费用信号不再驱动刷新（场景退场后仍写已释放节点是崩溃来源）。
func test_unbind_stops_signal_driven_refresh() -> void:
	wiring.call(&"setup", layout.call(&"interaction"), combat, cost)
	wiring.call(&"unbind")
	assert_false(cost.cost_changed.is_connected(wiring.get(&"_on_cost_changed")),
			"费用信号已断开")
	assert_false(combat.phase_changed.is_connected(wiring.get(&"_on_phase_changed")),
			"阶段信号已断开")
