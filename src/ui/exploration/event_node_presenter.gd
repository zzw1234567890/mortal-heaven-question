class_name EventNodePresenter
extends RefCounted
## EventNodePresenter —— 探索事件节点的「来即弹面板」接线。
##
## 挂在 [NodeGraphScreen] 下作为子组件：监听 [signal ExplorationSystem.event_node_reached]，
## 按玩家境界筛出候选事件后取一个（有 rng 随机、无 rng 按节点 id 取模），弹出事件面板；
## 玩家选完 → [ExplorationEventSystem]
## 结算并把结果文案回显到面板，再关闭清场。
##
## [b]为什么不走 NodeInteractionPopupHost[/b]：事件节点会与服务端「节点点击弹窗」
## 的双面板打架（见 [code]node_interaction_popup_host.gd[/code] 类文档 AC-9），
## 因此事件走独立通道——本类是那条通道的唯一实现点。
##
## [b]零状态所有权[/b]：本类不写任何玩法数据，落库全部经
## [ExplorationEventSystem.resolve_option] 转交 GSM / ResourceSystem /
## CultivationSystem / CardSystem（ADR-0031 §2）。
##
## 来源: Sprint 18 探索事件节点（Story 018-events）。

const EventSystemScript := preload("res://src/feature/exploration_event_system.gd")
const PanelScript := preload("res://src/ui/event_panel/event_panel_screen.gd")

## 本类持有的事件注册表与结算器。
var _events: RefCounted = null
## 当前面板（无面板时为 null）。
var _panel: Variant = null
## 已弹过事件的节点 id——同一节点重复到达只弹一次（仅在面板成功弹出时标记：
## 缺可用事件的到达不占名额）。
var _shown_nodes: Dictionary = {}
## 面板宿主（父 Control——通常是 NodeGraphScreen 自身）。
var _host: Control = null
var _rng: RandomNumberGenerator = null
var _last_result: Dictionary = {}


## 接线：连接事件信号并预加载事件资源。[br]
## [param p_rng] 可注入——事件选取与数额掷骰共用；null 时选取退化为按节点 id
## 取模（可复现），测试用它拿确定性结果。
func attach(p_exploration_system: Object, p_host: Control,
		p_rng: RandomNumberGenerator = null) -> void:
	_host = p_host
	_rng = p_rng
	_events = EventSystemScript.new()
	_events.call(&"load_events")
	if p_exploration_system == null or not is_instance_valid(p_exploration_system):
		return
	if not p_exploration_system.has_signal(&"event_node_reached"):
		return
	var handler := Callable(self, &"_on_event_node_reached")
	if not p_exploration_system.is_connected(&"event_node_reached", handler):
		p_exploration_system.connect(&"event_node_reached", handler)


## 注册表是否加载成功（集成测试用）。
func event_count() -> int:
	if _events == null:
		return 0
	return int(_events.call(&"event_count"))


func last_result() -> Dictionary:
	return _last_result


func is_panel_open() -> bool:
	return _panel != null and is_instance_valid(_panel)


func _on_event_node_reached(_p_map_pool: Array, p_player_realm: int) -> void:
	var node_id: int = _current_node_id()
	if node_id >= 0 and _shown_nodes.has(node_id):
		return
	var def: Variant = _pick_event(node_id, p_player_realm)
	if def == null:
		return
	if node_id >= 0:
		_shown_nodes[node_id] = true
	_open_panel(def)


## 取当前所在节点 id——读 GSM 探索位置；取不到时返回 -1（按 0 号事件兜底）。
func _current_node_id() -> int:
	var gsm: Node = _autoload(&"GameStateManager")
	if gsm == null or not gsm.has_method(&"get_state"):
		return -1
	var pos: Variant = gsm.call(&"get_state", "exploration.position")
	if not (pos is Dictionary):
		return -1
	var node_id: Variant = (pos as Dictionary).get("node_id")
	if node_id == null:
		return -1
	return int(node_id)


## 取本节点的事件——委托 [method ExplorationEventSystem.pick_for_node]：按玩家
## 境界筛候选后取一个。候选为空（境界不足等）返回 [code]null[/code]——调用方
## 据此不弹面板、不报错。
func _pick_event(p_node_id: int, p_player_realm: int) -> Variant:
	if _events == null:
		return null
	var index: int = maxi(p_node_id, 0)
	return _events.call(&"pick_for_node", index, p_player_realm, _rng)


func _open_panel(p_def: Variant) -> void:
	if is_panel_open():
		_close_panel()
	var panel: Control = PanelScript.new()
	panel.name = "EventPanel"
	if _host != null and is_instance_valid(_host):
		_host.add_child(panel)
	else:
		panel.queue_free()
		return
	_panel = panel
	panel.connect(&"option_chosen", _on_option_chosen)
	panel.call(&"present", p_def)


func _on_option_chosen(p_event_id: String, p_option_index: int) -> void:
	_last_result = _events.call(&"resolve_option", p_event_id, p_option_index,
			_build_deps(), _rng)
	if is_panel_open():
		_panel.call(&"show_result", _last_result)


func _build_deps() -> Dictionary:
	return {
		"gsm": _autoload(&"GameStateManager"),
		"resource_system": _autoload(&"ResourceSystem"),
		"cultivation_system": _autoload(&"CultivationSystem"),
		"card_system": _autoload(&"CardSystem"),
	}


## Autoload 取用——headless 单测里可能缺席，返回 null 让上层降级。
func _autoload(p_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_name)))


func _close_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
