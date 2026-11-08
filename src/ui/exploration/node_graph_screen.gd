class_name NodeGraphScreen
extends Control
## NodeGraphScreen —— 节点图主界面（exploration-ui Story S16-3）。
##
## [b]节点形态[/b]（ADR-0031 §1）：场景内 Control 树（零新增 Autoload），由
## [code]ExplorationScene[/code] 薄容器挂载（进入地图后替代/叠加于 MapSelectScreen）。[br]
## [br][b]结构[/b]：NodeGraphViewport（缩放平移容器）承载 NodeGraphRenderer（渲染
## 基座）+ 右上角行动力标签 + 返回按钮。[br]
## [br][b]信号驱动路径[/b]（stub 先行，2026-10-26 裁决）：[method _on_map_generated]
## 消费 [signal map_generated]——遍历 map_data.nodes/graph 构建节点控件快照 →
## 六态经 [NodeStateLogic.classify_node_state] 纯函数判定 → 样式经
## [NodeStateLogic.node_state_style] 渲染（注入 renderer.set_states）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：[code]_current_snapshot[/code] 为渲染
## 输入快照（瞬态交互状态，不进存档）；节点状态每次信号周期从系统 API/信号载荷
## 重读。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——逐层展开动画（0.8s）经 Tween
## 驱动 renderer.reveal_max_layer（Tween 完成即停，非 _process 常驻）。[br]
## [br][b]迷雾消散[/b]（0.3s）：node_moved 信号触发后重算六态并 queue_redraw——
## 迷雾状态判定归探索系统（stub 阶段以 stub 迷雾揭示集合近似）；消散动画时序归
## 手动证据（AC-2/AC-3）。
##
## 来源: story-003-node-graph-data-states.md、ADR-0031 §2/§3、
## ADR-0014 §决策 3（map_generated/node_moved 信号）、story-001 基座。

## === 依赖（测试可替换）======================================================

## 探索系统引用——map_generated/node_moved 信号源（null 时回退 stub 发射器）。
var exploration_system: Node = null
## 动画开关——测试注入（S16-1 先例）；false 时跳过逐层展开动画直接全显。
var animate: bool = true
## 减少动态偏好——测试/宿主注入（null 时从 SettingsStore 读取，审查 H5）。
var reduce_motion_override: Variant = null

## === 场景常量 ==============================================================

const MapGeneratedStubScript := preload("res://src/ui/exploration/map_generated_stub.gd")
## NodeStateLogic 脚本常量——六态分类器（class_name 在 headless 动态加载下
## 不可靠，preload 脚本常量——S16-1/2 先例）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")

## 逐层展开浮现动画总时长（秒）——AC-1「逐层从入口向 Boss 展开浮现（0.8s）」。
const REVEAL_DURATION: float = 0.8

## NodeMoveInteractor 脚本常量——移动交互组件（S17-005；class_name 在 headless
## 动态加载下不可靠，preload 脚本常量——S16-1/2 先例）。
const NodeMoveInteractorScript := preload("res://src/ui/exploration/node_move_interactor.gd")
## NodeTutorialOverlay 脚本常量——教程覆盖组件（S17-005 B10）。
const NodeTutorialOverlayScript := preload("res://src/ui/exploration/node_tutorial_overlay.gd")
## NodeInteractionPopupHost 脚本常量——节点交互弹窗宿主（S17-006）。
const NodeInteractionPopupHostScript := preload(
		"res://src/ui/exploration/node_interaction_popup_host.gd")
## SettingsStore 脚本常量——reduce_motion 偏好读取（审查 H5；GFX_KEY_* 单一真理来源）。
const SettingsStoreScript := preload("res://src/ui/main_menu/settings_store.gd")

## 固定 UI 词条（项目暂无本地化系统——S16-1 TEXT_* 同源豁免注记）。
const TEXT_AP_PREFIX: String = "AP"

## === 信号 ==================================================================

## 返回地图选择意图——[param back_button] 点击后发出（场景编排归探索系统）。
signal back_to_map_select_requested

## === 到达通知转发（审查 H3——006/007 消费入口）=============================
## 交互组件的到达信号经屏幕层再暴露一层：后续 story 只需连接屏幕信号，
## 无需依赖私有成员 [member _move_interactor] 的节点路径。
signal combat_arrival_forwarded(enemy_roster: Array, combat_type: StringName)
signal boss_arrival_forwarded(boss_data: Dictionary)
signal node_interaction_forwarded(node_id: int, interaction_type: StringName, payload: Dictionary)
## 移动失败 toast 文案（审查 H1——延迟接线义务：HUD 通知区域
## [method Hud.request_notification] 存在后由 006 接入，见 story Test Evidence）。
signal move_feedback_forwarded(toast_text: String, node_id: int)

## === 节点引用 ==============================================================

@onready var viewport: NodeGraphViewport = $NodeGraphViewport
@onready var ap_label: Label = $TopBar/APLabel
@onready var back_button: Button = $TopBar/BackButton

## === 瞬态渲染状态（ADR-0031 §2.1 瞬态交互状态）============================

## 当前渲染快照（graph/nodes/visited/current_node/ap_remaining）——node_moved
## 后重算六态用；不进存档。
var _current_snapshot: Dictionary = {}
## stub 信号发射器实例（Feature 层补齐后删除）。
var _stub_emitter: Node = null
## 逐层展开 Tween 句柄（重入时 kill 防悬挂）。
var _reveal_tween: Tween = null
## 移动交互组件（S17-005）——点击委托/失败反馈/移动动画/键盘路径。
var _move_interactor: Control = null
## 教程覆盖组件（S17-005 B10）——首次进入 3 步提示。
var _tutorial_overlay: Control = null
## 节点交互弹窗宿主（S17-006）——分发表路由/节点图冻结/背景模糊。
var _popup_host: Control = null


func _ready() -> void:
	_connect_signals()
	# stub 先行：无 [code]map_generated[/code] 信号源时建立 stub 发射器（不立即
	# 发射——由宿主进入地图时调用 [method trigger_map_load]；Feature 层
	# [code]map_generated[/code] 落盘后删除本分支）。[br]
	# [b]判定依据[/b]：信号源是否存在（而非 Autoload 是否存在）——当前项目
	# ExplorationSystem 已注册 Autoload 但未声明 map_generated 信号，仅判
	# Autoload 存在会导致 stub 永不建立、节点图空白（B-1）。
	var es: Node = _get_exploration_system()
	if es == null or not es.has_signal(&"map_generated"):
		_stub_emitter = MapGeneratedStubScript.new()
		add_child(_stub_emitter)
		_stub_emitter.map_generated.connect(_on_map_generated)
	back_button.pressed.connect(_on_back_pressed)
	_mount_interaction_components(es)


## 触发地图加载——真实源（es）已连 map_generated 时无操作（enter_map 会发射）；
## stub 源时发射 stub map_generated 驱动节点图构建。
func trigger_map_load() -> void:
	if _stub_emitter != null:
		_stub_emitter.emit_map_generated()


func _exit_tree() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()


## 连接探索系统信号——map_generated / node_moved（事件驱动，无轮询）。
func _connect_signals() -> void:
	var es: Node = _get_exploration_system()
	if es == null:
		return
	if es.has_signal(&"map_generated"):
		es.map_generated.connect(_on_map_generated)
	if es.has_signal(&"node_moved"):
		es.node_moved.connect(_on_node_moved)


## 挂载移动交互组件 + 教程覆盖（S17-005）——interactor 绑定 renderer 与
## 探索系统（依赖注入——测试可经 exploration_system 成员先注入 mock 再 add_child）。[br]
## [b]reduce_motion[/b]（审查 H5）：从 SettingsStore 读取用户无障碍偏好注入，
## 缺失时回退 false（动画正常播放）。
func _mount_interaction_components(es: Node) -> void:
	_move_interactor = NodeMoveInteractorScript.new()
	_move_interactor.name = "NodeMoveInteractor"
	add_child(_move_interactor)
	_move_interactor.setup(renderer(), es)
	_move_interactor.set_reduce_motion(_read_reduce_motion())
	_move_interactor.move_feedback_requested.connect(_on_move_feedback)
	_move_interactor.keyboard_focus_changed.connect(_on_keyboard_focus_changed)
	# 到达通知透明转发（审查 H3——006/007 消费入口，不依赖私有成员）
	_move_interactor.combat_arrival_forwarded.connect(
			func(roster: Array, ctype: StringName) -> void: combat_arrival_forwarded.emit(roster, ctype))
	_move_interactor.boss_arrival_forwarded.connect(
			func(data: Dictionary) -> void: boss_arrival_forwarded.emit(data))
	_move_interactor.node_interaction_forwarded.connect(
			func(nid: int, itype: StringName, payload: Dictionary) -> void:
				node_interaction_forwarded.emit(nid, itype, payload))
	_tutorial_overlay = NodeTutorialOverlayScript.new()
	_tutorial_overlay.name = "NodeTutorialOverlay"
	add_child(_tutorial_overlay)
	_mount_popup_host(es)


## 挂载节点交互弹窗宿主（S17-006）——消费交互组件与屏幕层已暴露的到达信号，
## 弹窗本身按下表派发（GDD §4c）。[br]
## [b]事件节点显式排除[/b]（AC-9）：本方法不连 [code]event_node_reached[/code]
## ——EventSystem 事件面板接管，防双面板。[br]
## [b]依赖注入[/b]：探索系统 / 场景管理器 / 境界系统均经参数传入（测试可替换）。
func _mount_popup_host(es: Node) -> void:
	_popup_host = NodeInteractionPopupHostScript.new()
	_popup_host.name = "NodeInteractionPopupHost"
	add_child(_popup_host)
	_popup_host.setup(renderer(), viewport, es,
			get_node_or_null(NodePath("/root/SceneManager")),
			get_node_or_null(NodePath("/root/RealmSystem")))
	_popup_host.set_reduce_motion(_read_reduce_motion())
	# 交互节点到达（商店/灵泉/回复/渡劫台——战斗/精英走 combat_node_reached）
	_move_interactor.node_interaction_forwarded.connect(
			func(nid: int, itype: StringName, payload: Dictionary) -> void:
				_popup_host.on_node_interaction(nid, itype, payload))
	# 战斗/精英到达（B4 先移动后弹窗——载荷由交互组件在动画后转发）
	_move_interactor.combat_arrival_forwarded.connect(
			func(roster: Array, ctype: StringName) -> void:
				_popup_host.on_combat_arrival(roster, ctype))
	# 弹窗期间冻结键盘路径（鼠标/缩放平移由宿主经视口 input_frozen 冻结）
	_popup_host.popup_opened.connect(func(_nid: int, _kind: StringName) -> void:
		if _move_interactor != null:
			_move_interactor.set_process_unhandled_key_input(false))
	# 关闭弹窗时回到节点图焦点（键盘路径恢复）
	_popup_host.popup_closed.connect(func(_nid: int, _kind: StringName) -> void:
		if _move_interactor != null:
			_move_interactor.set_process_unhandled_key_input(true))


## 读取减少动态偏好——注入覆盖优先，否则读 SettingsStore 画面分类。
func _read_reduce_motion() -> bool:
	if reduce_motion_override != null:
		return bool(reduce_motion_override)
	var store: RefCounted = SettingsStoreScript.new()
	var gfx: Dictionary = store.load_graphics_category()
	return bool(gfx.get(SettingsStoreScript.GFX_KEY_REDUCE_MOTION, false))


## 键盘焦点转发——渲染器绘制松石青焦点环（ADR-0031 §4 双焦点双视觉）。
func _on_keyboard_focus_changed(node_id: int) -> void:
	renderer().set_focused_node(node_id)


## 移动失败反馈转发——先向后续 story 暴露公开信号 [signal move_feedback_forwarded]，
## 再由 HUD 通知区域消费（[b]审查 H1 延后接线[/b]：HUD 目前尚未由启动流程挂载，
## [method Hud.request_notification] 虽已就绪但全库无调用方；接线义务记入
## story Test Evidence）。stub 阶段 push_warning 留痕便于走查。
func _on_move_feedback(toast_text: String, node_id: int) -> void:
	move_feedback_forwarded.emit(toast_text, node_id)
	push_warning("NodeGraphScreen: 移动反馈 toast（%s）——通知区域接线归 HUD story" % toast_text)


## === map_generated 消费（信号驱动构建路径——AC-1）==========================

## map_generated 信号处理——构建节点图 + 六态渲染 + 逐层展开动画。[br]
## [b]替换 story-001 的 [code]setup()[/code] 直连为信号驱动路径[/b]：Feature 层
## [code]map_generated[/code] 落盘后仅替换信号源、不改本方法渲染路径。
func _on_map_generated(_map_id: StringName, map_data: Dictionary) -> void:
	_current_snapshot = map_data
	renderer().setup(
			map_data.get("graph", {}),
			map_data.get("nodes", {}),
			map_data.get("visited", []),
			int(map_data.get("current_node", -1)))
	_refresh_ap_label(map_data)
	_recompute_states(map_data)
	if animate:
		_play_reveal_animation()
	else:
		renderer().reveal_max_layer = _max_layer(map_data.get("nodes", {}))
	# S17-005：快照注入移动交互组件 + 教程首次进入入口
	if _move_interactor != null:
		_move_interactor.apply_snapshot(map_data)
	if _tutorial_overlay != null:
		_tutorial_overlay.on_map_entered()
	if _popup_host != null:
		_popup_host.apply_snapshot(map_data)
	# 新地图不保留上一张的键盘焦点（审查 L5）
	renderer().set_focused_node(-1)


## node_moved 信号处理——迷雾消散（0.3s）+ 状态翻转重算（AC-2/AC-6）。[br]
## [b]早退与交互一致[/b]（审查 H6）：快照未注入时无六态可重算，但交互组件
## 也不应播出「只有标记在飞」的动画——由 interactor 判断快照为空即直跳终位。
func _on_node_moved(_from_node: int, to_node: int, ap_remaining: int) -> void:
	if _current_snapshot.is_empty():
		return
	var visited: Array = (_current_snapshot.get("visited", []) as Array).duplicate()
	if not visited.has(to_node):
		visited.append(to_node)
	_current_snapshot["visited"] = visited
	_current_snapshot["current_node"] = to_node
	_current_snapshot["ap_remaining"] = ap_remaining
	renderer().setup(
			_current_snapshot.get("graph", {}),
			_current_snapshot.get("nodes", {}),
			visited,
			to_node)
	_refresh_ap_label(_current_snapshot)
	_recompute_states(_current_snapshot)
	# S17-006：快照随移动重下发——否则弹窗宿主的 current_node 停留在上一节点，
	# 战斗弹窗会锚在「出发节点」而非「到达节点」（弹窗在动画结束后才打开，
	# 本回调先于到达转发执行，时机足够）。
	if _popup_host != null:
		_popup_host.apply_snapshot(_current_snapshot)
	# S17-005：移动动画由交互组件自绑 node_moved 信号驱动（_bind_system_signals
	# ——宿主不转发，避免双重动画+缓冲队列双重消费）。


## === 六态判定（消费 NodeStateLogic 纯函数——Logic 内核）====================

## 重算六态并注入 renderer——每个节点经 [NodeStateLogic.classify_node_state]
## 判定后写入 states 映射。
func _recompute_states(snapshot: Dictionary) -> void:
	var graph: Dictionary = snapshot.get("graph", {})
	var nodes: Dictionary = snapshot.get("nodes", {})
	var visited: Array = snapshot.get("visited", [])
	var current_node: int = int(snapshot.get("current_node", -1))
	var ap_remaining: int = int(snapshot.get("ap_remaining", 0))
	var state_map: Dictionary = {}
	for node_id: int in nodes.keys():
		state_map[node_id] = NodeStateLogicScript.classify_node_state(
				node_id, graph, visited, current_node, ap_remaining, nodes)
	renderer().set_states(state_map)


## === 动画（时序归手动证据——AC-3 走查）====================================

## 逐层展开浮现（0.8s）——reveal_max_layer 从 -1 递增到最大层。[br]
## [b]动画时序不纳入集成测试自动化断言[/b]（Integration 类型正常边界），由
## QA Test Cases AC-3 手动走查覆盖。
func _play_reveal_animation() -> void:
	if _reveal_tween != null and _reveal_tween.is_valid():
		_reveal_tween.kill()
	var max_layer: int = _max_layer(_current_snapshot.get("nodes", {}))
	renderer().reveal_max_layer = -1
	_reveal_tween = create_tween()
	_reveal_tween.tween_method(_reveal_step.bind(max_layer), 0.0, 1.0, REVEAL_DURATION)


## 展开步进——[code]reveal_max_layer = round(t * max_layer)[/code]（逐层浮现）。
func _reveal_step(t: float, max_layer: int) -> void:
	renderer().reveal_max_layer = int(round(t * float(max_layer)))
	renderer().queue_redraw()


## === 内部辅助 ==============================================================

## 渲染器引用——viewport 的内容宿主（[NodeGraphViewport.renderer]）。
func renderer() -> NodeGraphRenderer:
	return viewport.renderer


## 刷新行动力标签（右上角 AP 显示；数据源 = 快照 ap_remaining）。
func _refresh_ap_label(snapshot: Dictionary) -> void:
	ap_label.text = "%s: %d" % [TEXT_AP_PREFIX, int(snapshot.get("ap_remaining", 0))]


## 最大层索引（-1 = 空）。
func _max_layer(nodes: Dictionary) -> int:
	var max_layer: int = -1
	for node_id: int in nodes.keys():
		max_layer = maxi(max_layer, int(nodes[node_id].get("layer", 0)))
	return max_layer


## 获取探索系统——注入对象优先，否则回退 Autoload。
func _get_exploration_system() -> Node:
	if exploration_system != null:
		return exploration_system
	return get_node_or_null("/root/ExplorationSystem")


func _on_back_pressed() -> void:
	back_to_map_select_requested.emit()
