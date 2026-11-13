extends GutTest

## [b]为什么需要本文件[/b]：ADR-0014 要求「到达 / 战斗胜利 / 事件结算」三种确认共用一处
## 标记入口，并各有唯一可观测出口。`ExplorationSystem.mark_node_visited()` 就是那个入口，
## 本文件锁它的三条契约：首次标记发 is_new=true、重复标记发 is_new=false、负数节点不写
## 也不发信号。

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")

var es: Node = null
var received: Array = []


func before_each() -> void:
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	assert_not_null(gsm, "前置：GameStateManager 应存在")
	gsm.exploration["visited_nodes"] = []
	es = ES_SCRIPT.new()
	received = []
	es.node_marked_visited.connect(func(node_id: int, is_new: bool) -> void:
		received.append({"node_id": node_id, "is_new": is_new}))


func after_each() -> void:
	if es != null:
		es.free()
		es = null
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm != null:
		gsm.exploration["visited_nodes"] = []


func test_first_mark_emits_is_new_true() -> void:
	var is_new: bool = es.mark_node_visited(101)

	assert_true(is_new, "首次标记应返回 true")
	assert_eq(received.size(), 1, "应发一次 node_marked_visited")
	assert_eq(int(received[0]["node_id"]), 101, "载荷应带节点 ID")
	assert_true(bool(received[0]["is_new"]), "首次标记 is_new 应为 true")
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	assert_true((gsm.exploration["visited_nodes"] as Array).has(101), "应写入 GSM")


func test_repeat_mark_is_idempotent_and_emits_is_new_false() -> void:
	es.mark_node_visited(202)
	received = []

	var is_new: bool = es.mark_node_visited(202)

	assert_false(is_new, "重复标记应返回 false")
	assert_eq(received.size(), 1, "重复标记也要发一次（幂等确认）")
	assert_false(bool(received[0]["is_new"]), "重复标记 is_new 应为 false")
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	assert_eq((gsm.exploration["visited_nodes"] as Array).count(202), 1, "不应重复写入")


func test_negative_node_is_ignored() -> void:
	var is_new: bool = es.mark_node_visited(-1)

	assert_false(is_new, "非法节点应返回 false")
	assert_eq(received.size(), 0, "非法节点不应发信号")


func test_battle_and_event_marking_share_one_entry() -> void:
	# 到达 → 战斗胜利确认 → 事件结算确认，对同一节点连打三次，
	# 只有第一次是 is_new=true（口径统一、天然幂等）。
	es.mark_node_visited(301)
	es.mark_node_visited(301)
	es.mark_node_visited(301)

	assert_eq(received.size(), 3, "三次确认都应可观测")
	assert_true(bool(received[0]["is_new"]), "第一次为首次标记")
	assert_false(bool(received[1]["is_new"]), "第二次为幂等确认")
	assert_false(bool(received[2]["is_new"]), "第三次为幂等确认")
