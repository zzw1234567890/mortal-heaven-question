extends Node
## MockExplorationSystem —— exploration-ui Story 17-005 节点移动交互测试 mock。
##
## [b]契约对齐[/b]：[code]src/feature/exploration_system.gd[/code] 的
## [code]move_to_node(from_node, to_node) -> Dictionary[/code]（返回
## {success, reason, ap_remaining}）与 Cat 2b 信号（node_moved /
## node_interaction_triggered / combat_node_reached / boss_node_reached /
## event_node_reached / map_generated）。参照
## [code]tests/integration/combat_ui/mocks/mock_hand_signals.gd[/code] 先例——
## 自建 stub Node 带原生 signal 声明 + 可编程返回值，不需要完整 Autoload。
##
## 来源: story-005-node-move-interaction.md QA Test Cases、ADR-0014 §决策 3 信号表。

# === 信号（与 ExplorationSystem 同构）=========================================

signal map_generated(map_id: StringName, map_data: Dictionary)
signal node_moved(from_node: int, to_node: int, ap_remaining: int)
signal node_interaction_triggered(node_id: int, interaction_type: StringName, payload: Dictionary)
signal combat_node_reached(enemy_roster: Array, combat_type: StringName)
signal boss_node_reached(boss_data: Dictionary)
signal event_node_reached(map_pool: Array, player_realm: int)

# === 可编程状态 ================================================================

## move_to_node 返回值——测试用例注入（默认全失败空 reason）。
var move_result: Dictionary = {"success": false, "reason": "", "ap_remaining": 0}
## move_to_node 调用记录——[[from_node, to_node], ...]（计数断言用）。
var move_calls: Array = []
## 成功时自动发射 node_moved + 到达信号的模拟开关（默认开——端到端流测试）。
var emit_on_success: bool = true
## 成功时模拟发射的到达信号名（默认 combat——战斗节点用例）。
var arrival_signal: StringName = &"combat_node_reached"
## 各信号发射计数——「恰好一次/不预弹」断言用。
var emit_counts: Dictionary = {}


# === move_to_node mock =========================================================

## 记录调用并返回 [member move_result]；emit_on_success 时模拟系统行为——
## 发射 node_moved + 到达信号（真实系统内 resolve_node 自动触发，见
## exploration_system.gd move_to_node 尾部）。
func move_to_node(from_node: int, to_node: int) -> Dictionary:
	move_calls.append([from_node, to_node])
	if bool(move_result.get("success", false)) and emit_on_success:
		node_moved.emit(from_node, to_node, int(move_result.get("ap_remaining", 0)))
		match arrival_signal:
			&"combat_node_reached":
				combat_node_reached.emit([], &"combat")
			&"boss_node_reached":
				boss_node_reached.emit({})
			&"node_interaction_triggered":
				node_interaction_triggered.emit(to_node, &"shop", {})
	return move_result


# === 到达信号独立发射（不预弹断言的对照路径）===================================

## 手动发射 combat_node_reached（计数记录）。
func emit_combat_arrival() -> void:
	emit_counts["combat_node_reached"] = int(emit_counts.get("combat_node_reached", 0)) + 1
	combat_node_reached.emit([], &"combat")


## 手动发射 boss_node_reached（计数记录）。
func emit_boss_arrival() -> void:
	emit_counts["boss_node_reached"] = int(emit_counts.get("boss_node_reached", 0)) + 1
	boss_node_reached.emit({})


## 手动发射 node_interaction_triggered（计数记录）。
func emit_interaction(node_id: int) -> void:
	emit_counts["node_interaction_triggered"] = \
			int(emit_counts.get("node_interaction_triggered", 0)) + 1
	node_interaction_triggered.emit(node_id, &"shop", {})


## 重置全部可编程状态（测试 before_each 自清理）。
func reset() -> void:
	move_result = {"success": false, "reason": "", "ap_remaining": 0}
	move_calls.clear()
	emit_on_success = true
	arrival_signal = &"combat_node_reached"
	emit_counts.clear()
