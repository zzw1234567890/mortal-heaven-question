extends GutTest
## 战斗节点「打完即清」验收——胜利写已清、失败/撤退不写、重复不重复计数。[br]
## [br][b]为什么需要本文件[/b]：`ecb4ff2` 只加了「胜利 → add_visited_node」的生产逻辑，
## 没有任何用例证明它真的被调用、也没证明失败与撤退不会误标——而误标的后果是
## 玩家战败后节点直接消失，整张图白送。[br]
## [br][b]覆盖[/b]：[br]
##   1. RESULT_SCREEN + 胜利 + 有节点上下文 → 该节点进 visited_nodes；[br]
##   2. DEFEAT_SCREEN + 战败 → 不进 visited_nodes；[br]
##   3. DEFEAT_SCREEN + 撤退 → 不进 visited_nodes；[br]
##   4. 同一节点重复标记 → visited_nodes 里只出现一次。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型、`placeholder_scene.gd` 战斗节点清零逻辑。

const ResultScreenScript := preload("res://src/ui/result_screen/result_screen.gd")
const DefeatScreenScript := preload("res://src/ui/defeat_screen/defeat_screen.gd")
const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")
const LaunchScript := preload("res://src/feature/combat/combat_launch_context.gd")

const NODE_ID: int = 7

var gsm: Node = null
var _visiting_before: Array = []


func before_each() -> void:
	gsm = get_node_or_null("/root/GameStateManager")
	assert_not_null(gsm, "GSM 不可用——本文件依赖 Autoload")
	if gsm == null:
		return
	_visiting_before = (gsm.exploration.get("visited_nodes", []) as Array).duplicate()
	gsm.exploration["visited_nodes"] = []


func after_each() -> void:
	if gsm != null:
		gsm.exploration["visited_nodes"] = _visiting_before.duplicate()
	# 清掉跨场景静态缓存，避免污染后继用例
	LaunchScript.clear()
	ViewScript.publish(null)


## 造一份结算对象（只填判定用得到的字段）。
func _make_view(result_code: int) -> RefCounted:
	var view: RefCounted = ViewScript.new()
	view.set("result", result_code)
	return view


## 造一个占位场景并调一次「胜利则标已清」。
func _run_mark(screen_script: GDScript, screen_id: int, result_code: int) -> void:
	ViewScript.publish(_make_view(result_code))
	LaunchScript.publish({LaunchScript.KEY_NODE_ID: NODE_ID})
	var scene: Node = screen_script.new()
	scene.set("screen_id", screen_id)
	add_child_autofree(scene)
	scene.call("_mark_battle_node_cleared_if_victory")


func test_victory_marks_node_cleared() -> void:
	if gsm == null:
		return
	_run_mark(ResultScreenScript, 8, ViewScript.RESULT_VICTORY)
	var visited: Array = gsm.exploration.get("visited_nodes", [])
	assert_true(visited.has(NODE_ID), "胜利后该节点应进 visited_nodes")


func test_defeat_does_not_mark_node_cleared() -> void:
	if gsm == null:
		return
	_run_mark(DefeatScreenScript, 9, ViewScript.RESULT_DEFEAT)
	var visited: Array = gsm.exploration.get("visited_nodes", [])
	assert_false(visited.has(NODE_ID), "战败不应把节点标为已清")


func test_retreat_does_not_mark_node_cleared() -> void:
	if gsm == null:
		return
	_run_mark(DefeatScreenScript, 9, ViewScript.RESULT_RETREAT)
	var visited: Array = gsm.exploration.get("visited_nodes", [])
	assert_false(visited.has(NODE_ID), "撤退不应把节点标为已清")


func test_repeated_clear_keeps_single_entry() -> void:
	if gsm == null:
		return
	_run_mark(ResultScreenScript, 8, ViewScript.RESULT_VICTORY)
	_run_mark(ResultScreenScript, 8, ViewScript.RESULT_VICTORY)
	var visited: Array = gsm.exploration.get("visited_nodes", [])
	var count: int = 0
	for id: Variant in visited:
		if int(id) == NODE_ID:
			count += 1
	assert_eq(count, 1, "重复标记不应重复计数")
