class_name DialoguePlayer
extends RefCounted
## DialoguePlayer —— 对话播放引擎（RefCounted 服务类，ADR-0027）。
##
## Feature 层 RefCounted（非 Autoload）。持有对话播放运行时状态：[br]
## 当前节点 ID、对话历史、播放进度。由触发对话的系统实例化，[br]
## 对话结束后由 UI 释放引用。[br]
## [br]来源: ADR-0027 §决策 3 + GDD dialogue-system.md §1/§4。


## 对话开始信号。
signal dialogue_started(tree_id: String)
## 对话结束信号。
signal dialogue_finished

## 当前播放的对话树 ID。
var _tree_id: String = ""
## 对话树数据引用。
var _tree: Dictionary = {}
## 当前节点 ID。
var _current_node_id: String = ""
## 对话历史——记录已播放的节点 ID。
var _dialogue_history: Array = []
## 是否已结束（到达 end_node 或无 next_node）。
var _is_finished: bool = false
## EventSystem 引用（条件评估 + outcomes 委托）。
var _event_system: Node = null


## 开始播放对话树——Story 7-13 API，带 EventSystem 注入。[br]
## 发射 dialogue_started 信号，评估起始节点条件。
func start_dialogue(tree_id: String, tree_data: Dictionary, event_system: Node = null) -> void:
	_event_system = event_system
	start(tree_id, tree_data)
	dialogue_started.emit(tree_id)
	_check_and_skip_conditions()


## 开始播放对话树——Story 7-12 API（无 EventSystem）。
func start(tree_id: String, tree_data: Dictionary) -> void:
	_tree_id = tree_id
	_tree = tree_data.duplicate(true)
	_current_node_id = str(_tree.get("start_node", ""))
	_dialogue_history = []
	_is_finished = false
	if not _current_node_id.is_empty():
		_dialogue_history.append(_current_node_id)


## 获取当前节点数据。
func get_current_node() -> Dictionary:
	if _is_finished or _current_node_id.is_empty():
		return {}
	var nodes: Dictionary = _tree.get("nodes", {})
	return nodes.get(_current_node_id, {}).duplicate(true)


## 推进对话——无 choices 时推进到 next_node。[br]
## 到达无 next_node 的节点时标记结束并发射 dialogue_finished 信号。
func advance() -> void:
	if _is_finished:
		return
	var node: Dictionary = get_current_node()
	if node.is_empty():
		_is_finished = true
		dialogue_finished.emit()
		return
	# 有 choices 的节点不可直接 advance——需要 select_choice
	if node.has("choices") and (node["choices"] as Array).size() > 0:
		return
	# 推进到 next_node
	var next_id: String = str(node.get("next_node", ""))
	if next_id.is_empty():
		_is_finished = true
		dialogue_finished.emit()
		return
	_current_node_id = next_id
	_dialogue_history.append(_current_node_id)
	_check_and_skip_conditions()


## 选择选项——Story 7-13 API。[br]
## 执行 next_node 跳转，委托 outcomes 到 EventSystem。[br]
## [param choice_id] 选项 ID。[br]
## [b]返回[/b]: 选项的 outcomes 列表。
func select_option(choice_id: String) -> Array:
	var outcomes: Array = select_choice(choice_id)
	# 委托 outcomes 到 EventSystem
	if _event_system != null:
		for outcome in outcomes:
			if outcome is Dictionary:
				var o: Dictionary = outcome
				if str(o.get("type", "")) == "set_flag":
					_event_system.set_flag(str(o.get("target", "")), o.get("value", true))
	# 如果选择导致对话结束，发射信号
	if _is_finished:
		dialogue_finished.emit()
	return outcomes


## 选择选项——Story 7-12 API。[br]
## [param choice_id] 选项 ID。[br]
## [b]返回[/b]: 选项的 outcomes 列表。
func select_choice(choice_id: String) -> Array:
	if _is_finished:
		return []
	var node: Dictionary = get_current_node()
	if not node.has("choices"):
		return []
	var choices: Array = node["choices"]
	for choice: Dictionary in choices:
		if str(choice.get("id", "")) == choice_id:
			var outcomes: Array = choice.get("outcomes", [])
			var next_id: String = str(choice.get("next_node", ""))
			if next_id.is_empty():
				_is_finished = true
			else:
				_current_node_id = next_id
				_dialogue_history.append(_current_node_id)
				_check_and_skip_conditions()
			return outcomes.duplicate(true) if outcomes is Array else []
	return []


## 获取当前节点可见选项列表——含条件可见性判定。[br]
## 每个选项附带 {visible: bool, reason: String}。
func get_visible_choices() -> Array:
	var node: Dictionary = get_current_node()
	if not node.has("choices"):
		return []
	var result: Array = []
	var choices: Array = node["choices"]
	for choice: Dictionary in choices:
		var visible: bool = true
		var reason: String = ""
		if choice.has("conditions"):
			var conditions: Array = choice["conditions"]
			for cond: Dictionary in conditions:
				if not _evaluate_condition(cond):
					visible = false
					reason = "condition_not_met"
					break
		var entry: Dictionary = choice.duplicate(true)
		entry["visible"] = visible
		entry["reason"] = reason
		result.append(entry)
	return result


## 跳过对话——allow_skip=true 时直接结束。
func skip() -> void:
	if _is_finished:
		return
	if not bool(_tree.get("allow_skip", false)):
		return
	_is_finished = true
	dialogue_finished.emit()


## 是否已结束。
func is_finished() -> bool:
	return _is_finished


## 获取对话历史。
func get_history() -> Array:
	return _dialogue_history.duplicate()


## 获取对话树 ID。
func get_tree_id() -> String:
	return _tree_id


## 获取 end_action（对话结束后的动作）。
func get_end_action() -> String:
	return str(_tree.get("end_action", ""))


# ============================================================================
# 内部：条件评估
# ============================================================================

## 检查当前节点条件——条件不满足时自动跳过到 next_node。
func _check_and_skip_conditions() -> void:
	var visited: Dictionary = {}
	while not _is_finished:
		var node: Dictionary = get_current_node()
		if node.is_empty():
			_is_finished = true
			dialogue_finished.emit()
			return
		if not node.has("conditions"):
			return  # 无条件——可见
		var all_pass: bool = true
		var conditions: Array = node["conditions"]
		for cond: Dictionary in conditions:
			if not _evaluate_condition(cond):
				all_pass = false
				break
		if all_pass:
			return  # 条件满足——可见
		# 条件不满足——跳过到 next_node
		var next_id: String = str(node.get("next_node", ""))
		if next_id.is_empty() or visited.has(next_id):
			_is_finished = true
			dialogue_finished.emit()
			return
		visited[next_id] = true
		_current_node_id = next_id
		_dialogue_history.append(_current_node_id)


## 评估单个条件。[br]
## 支持 10 种条件类型：story_flag / realm / faction / card_owned / [br]
## identity / chapter_completed / relation / has_item / combat_result / always。
func _evaluate_condition(cond: Dictionary) -> bool:
	var cond_type: String = str(cond.get("type", ""))
	match cond_type:
		"always":
			return true
		"story_flag":
			if _event_system == null:
				return false
			var flag_name: String = str(cond.get("flag", ""))
			var op: String = str(cond.get("operator", "=="))
			var expected: Variant = cond.get("value", true)
			var actual: Variant = null
			if _event_system.has_method("get_flag"):
				actual = _event_system.get_flag(flag_name)
			return _compare_values(actual, op, expected)
		"realm", "faction", "card_owned", "identity", \
		"chapter_completed", "relation", "has_item", "combat_result":
			return true  # 桩——需游戏状态上下文，后续接线
		_:
			return true  # 未知条件类型——默认可见


## 比较两个值。
func _compare_values(actual: Variant, op: String, expected: Variant) -> bool:
	match op:
		"==":
			return str(actual) == str(expected)
		"!=":
			return str(actual) != str(expected)
		_:
			return str(actual) == str(expected)
