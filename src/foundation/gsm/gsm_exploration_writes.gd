extends RefCounted
## GSMExplorationWrites —— 探索导航域原子写入子模块（从 gsm_atomic_writes.gd 拆分）。
##
## 持有对 GSM 父节点的引用，提供探索导航域第二层原子写入方法。[br]
## 每个方法写入数据后通过 [method GameStateManager._buffer_change] 进入帧末信号缓冲管线。[br]
## [br]Sprint 8 Story 8-11：从 gsm_atomic_writes.gd 拆分。

## 指向 GSM 父节点的引用。
var _gsm: Node = null


## 构造——传入 GSM 引用。
func _init(gsm: Node = null) -> void:
	_gsm = gsm


## 设置当前地图——写入 exploration.current_map 并重置 node_position 为入口。[br]
## [br][b]仅 ExplorationSystem.enter_map() 调用[/b]——ADR-0014 §GSM 写入契约。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func set_exploration_map(map_id: StringName) -> void:
	var old_map: StringName = _gsm.exploration.get("current_map", &"")
	var old_pos: Dictionary = _gsm.exploration.get("node_position", {}).duplicate(true)
	var new_pos: Dictionary = {"layer": 0, "idx": 0}

	_gsm.exploration.current_map = map_id
	_gsm.exploration.node_position = new_pos.duplicate(true)

	_gsm._buffer_change("exploration.current_map", old_map, map_id)
	_gsm._buffer_change("exploration.node_position", old_pos, new_pos)


## 更新节点位置——写入 exploration.node_position。[br]
## [br][b]仅 ExplorationSystem.move_to_node() 调用[/b]——ADR-0014 §GSM 写入契约。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func set_exploration_position(layer: int, idx: int) -> void:
	var old_pos: Dictionary = _gsm.exploration.get("node_position", {}).duplicate(true)
	var new_pos: Dictionary = {"layer": layer, "idx": idx}

	_gsm.exploration.node_position = new_pos.duplicate(true)
	_gsm._buffer_change("exploration.node_position", old_pos, new_pos)


## 追加已访问节点——写入 exploration.visited_nodes（去重）。[br]
## [br][b]仅 ExplorationSystem.move_to_node() 调用[/b]——ADR-0014 §GSM 写入契约。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func add_visited_node(node_id: int) -> void:
	var visited: Array = _gsm.exploration.get("visited_nodes", [])
	if visited.has(node_id):
		return  # 去重
	var old_visited: Array = visited.duplicate()
	visited.append(node_id)
	_gsm._buffer_change("exploration.visited_nodes", old_visited, visited)


## 设置行动力——同时写入 exploration.action_points + max_action_points。[br]
## [br][b]仅 ExplorationSystem.enter_map() / 恢复节点调用[/b]——ADR-0014 §GSM 写入契约。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func set_exploration_ap(current: int, max_ap: int) -> void:
	var old_current: int = int(_gsm.exploration.get("action_points", 0))
	var old_max: int = int(_gsm.exploration.get("max_action_points", 0))

	_gsm.exploration.action_points = current
	_gsm.exploration.max_action_points = max_ap

	_gsm._buffer_change("exploration.action_points", old_current, current)
	_gsm._buffer_change("exploration.max_action_points", old_max, max_ap)


## 合并写入地图状态——更新 exploration.map_states[map_id] 子字段。[br]
## [br][b]仅 ExplorationSystem 调用[/b]——用于 entry_count、collected_* 等跨地图累计数据。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func update_exploration_map_state(map_id: StringName, changes: Dictionary) -> void:
	var map_states: Dictionary = _gsm.exploration.get("map_states", {})
	var key_str: String = str(map_id)
	var old_state: Dictionary = (map_states.get(map_id, {}) as Dictionary).duplicate(true)

	if not map_states.has(map_id):
		map_states[map_id] = {}
	var target: Dictionary = map_states[map_id]
	for k in changes:
		target[k] = changes[k]

	var new_state: Dictionary = target.duplicate(true)
	_gsm._buffer_change("exploration.map_states.%s" % key_str, old_state, new_state)


## 清除导航状态——重置 current_map/node_position/visited_nodes，保留 map_states。[br]
## [br][b]仅 ExplorationSystem.end_exploration() 调用[/b]——ADR-0014 §决策 5 探索结束结算。[br]
## [br]来源: ADR-0014 §决策 5 探索结束结算。
func clear_exploration_navigation() -> void:
	var old_map: StringName = _gsm.exploration.get("current_map", &"")
	var old_pos: Dictionary = _gsm.exploration.get("node_position", {}).duplicate(true)
	var old_visited: Array = (_gsm.exploration.get("visited_nodes", []) as Array).duplicate()

	_gsm.exploration.current_map = &""
	_gsm.exploration.node_position = {"layer": 0, "idx": 0}
	_gsm.exploration.visited_nodes = []

	_gsm._buffer_change("exploration.current_map", old_map, &"")
	_gsm._buffer_change("exploration.node_position", old_pos, {"layer": 0, "idx": 0})
	_gsm._buffer_change("exploration.visited_nodes", old_visited, [])
