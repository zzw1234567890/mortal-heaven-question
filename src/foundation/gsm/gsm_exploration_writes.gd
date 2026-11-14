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


## 重置已访问节点集合——进入地图时写入「入口已访问」的初始集合。[br]
## [br][b]仅 ExplorationSystem.enter_map() 调用[/b]——ADR-0014 §GSM 写入契约。[br]
## [br][b]为什么需要单独的方法[/b]：[method set_exploration_map] 只重置
## [code]current_map[/code] 与 [code]node_position[/code]；换图时若不清空
## [code]visited_nodes[/code]，上一张图的路径会被节点图画进新图的绿色已访问态。[br]
## [br][param p_initial] 初始已访问集合（深拷贝写入，不与调用方共享引用）。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型、GDD exploration-system.md §4。
func reset_exploration_visited(p_initial: Array) -> void:
	var old_visited: Array = \
			(_gsm.exploration.get("visited_nodes", []) as Array).duplicate()
	var new_visited: Array = p_initial.duplicate()
	_gsm.exploration.visited_nodes = new_visited
	_gsm._buffer_change("exploration.visited_nodes", old_visited, new_visited.duplicate())


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


## 恢复行动力——写入 exploration.action_points，[b]夹到上限[/b]。[br]
## [br][b]与 set_exploration_ap 的分工[/b]：那个是「设成某个值」（进入地图 /
## 移动扣费——调用方已经算好了值），本方法是「在现值上加」的语义
## （事件结果 RESTORE_AP / 丹药回复）。[br]
## [br][b]为什么要 clamp[/b]：GDD action-point-system.md §8 边界「使用丹药回复超过
## 上限：回复时取 [code]min(current + amount, max_action_points)[/code]，不溢出」。
## 不夹会让行动力顶到上限之上：图标显示 5/5 却持有 9 点，而灵泉
## （[code]ExplorationActionSpring.restore_for[/code]）按「上限 - 当前」算出的
## 回复量变成 0——玩家看到「行动力已满」但其实还能再多花 4 点。[br]
## [br][b]上限为 0 时不夹[/b]：0 表示「尚未进入任何地图、上限未知」
## （[code]gsm_serializer.gd[/code] 的两个字段出厂都是 0）——此时按原值累加，
## 不臆造一个上限把恢复吞掉。[br]
## [br][b]越界存档值[/b]：当前值本就超过上限时也走同一条 [code]min[/code] 口径
## （结果就是上限），不倒扣——与 [code]ExplorationActionSpring[/code] 的
## 「不放大也不倒扣」一致。[br]
## [br][param amount] 恢复量（必须为正值，非正值报错并原样返回）。[br]
## [br]来源: GDD action-point-system.md §8 边界、ADR-0014 §GSM 写入契约。
func restore_action_points(amount: int) -> void:
	if amount <= 0:
		push_error("GSM.restore_action_points: amount 必须为正值（收到: %d）" % amount)
		return

	var old_val: int = int(_gsm.exploration.get("action_points", 0))
	var max_ap: int = int(_gsm.exploration.get("max_action_points", 0))
	var new_val: int = old_val + amount
	# 上限未知（0）→ 不夹；已知 → min(current + amount, max)，见方法注释
	if max_ap > 0:
		new_val = mini(new_val, max_ap)
	_gsm.exploration.action_points = new_val
	_gsm._buffer_change("exploration.action_points", old_val, new_val)


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
