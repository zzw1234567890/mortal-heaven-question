class_name NodeGraphScreen
extends Control
## NodeGraphScreen —— 节点图主界面（exploration-ui Story S16-3）。
##
## [b]节点形态[/b]（ADR-0031 §1）：场景内 Control 树（零新增 Autoload），由
## [code]ExplorationScene[/code] 薄容器挂载（进入地图后替代/叠加于 MapSelectScreen）。[br]
## [br][b]结构[/b]：NodeGraphViewport（缩放平移容器）承载 NodeGraphRenderer（渲染
## 基座）+ 右上角行动力标签 + 返回按钮。[br]
## [br][b]信号驱动路径[/b]：本界面[b]只消费 [signal ExplorationSystem.map_generated][/b]
## ——遍历 map_data.nodes/graph 构建节点控件快照 → 六态经
## [NodeStateLogic.classify_node_state] 纯函数判定 → 样式经
## [NodeStateLogic.node_state_style] 渲染（注入 renderer.set_states）。[br]
## [br][b]数据源优先级[/b]（[method trigger_map_load]）：1. 注入了真实探索系统且其
## 声明 [code]map_generated[/code] → 调 [code]enter_map[/code] 命令（系统自己广播
## 信号），本界面不写任何游戏状态；2. 否则挂 [MapGeneratedStub] 降级发射器，渲染
## story-003 的 stub 样本（headless/编辑器预览、Feature 层缺失时界面不空白）——
## 降级路径由 [method is_using_stub_source] 标记，集成测试据此断言「真实数据 ≠ stub」。
## [br][b]零状态所有权[/b]（ADR-0031 §2）：[code]_current_snapshot[/code] 为渲染输入
## 快照（瞬态交互状态，不进存档）；节点状态每次信号周期从系统 API/信号载荷重读。
## [br][b]零轮询[/b]：无 [code]_process()[/code]——逐层展开动画（0.8s）经 Tween
## 驱动 renderer.reveal_max_layer（Tween 完成即停，非 _process 常驻）。[br]
## [br][b]迷雾消散[/b]（0.3s）：node_moved 后重算六态并 queue_redraw——揭示集合按
## 「已访问 ∪ 当前 ∪ 其前向邻接」推导（[NodeStateLogic.is_revealed]），与系统写入的
## visited 同源；消散动画时序归手动证据（AC-2/AC-3）。[br]
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

## NodeGraphLoadSource 脚本常量——数据源选择与加载编排（真实 enter_map / stub 降级）。
const NodeGraphLoadSourceScript := preload("res://src/ui/exploration/node_graph_load_source.gd")
## 子组件装配编排（交互组件 + 事件弹出通道）——挂载细节在装配器，屏幕只持引用。
const ComponentAssemblyScript := preload(
		"res://src/ui/exploration/node_graph_component_assembly.gd")

## 六态重算 + 逐层展开动画。
const NodeGraphRevealAnimatorScript := preload(
		"res://src/ui/exploration/node_graph_reveal_animator.gd")

## 固定 UI 词条（项目暂无本地化系统——S16-1 TEXT_* 同源豁免注记）。
const TEXT_AP_PREFIX: String = "AP"

## === 信号 ==================================================================

## 返回地图选择意图——[param back_button] 点击后发出（场景编排归探索系统）。
signal back_to_map_select_requested

## === 到达通知转发（审查 H3——006/007 消费入口）=============================
## 交互组件的到达信号经屏幕层再暴露一层：后续 story 只需连接屏幕信号，
## 无需依赖子组件节点路径。
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
## 数据源选择与加载编排（真实 enter_map / stub 降级——见 [NodeGraphLoadSource]）。
var _load_source: RefCounted = null
## 待加载地图 ID——[method trigger_map_load] 在进树前被调用时记下，[method _ready]
## 补触发一次（场景编排先 add_child 后调 trigger_map_load 是既有顺序）。
var _pending_map_id: StringName = &""
## 装配结果——[code]{interaction_mount, event_presenter, shop_presenter,
## teleport_presenter, harvest_presenter, craft_presenter, meditation_presenter}[/code]
## （见 [NodeGraphComponentAssembly]）。[b]为什么整块存字典[/b]：屏幕只负责
## 「持引用防提前释放」+ 对外访问器，逐个声明等于把返回契约写两处。
var _components: Dictionary = {}
## 六态重算 + 逐层展开动画（见 [NodeGraphRevealAnimator]）。
var _reveal_animator: RefCounted = null


func _ready() -> void:
	_connect_signals()
	# 数据源选择（真实信号 / stub 降级）交给子模块——判定依据是
	# [b]信号是否声明[/b]而非 Autoload 是否存在（B-1 回归见子模块文档）。
	var es: Node = _get_exploration_system()
	_load_source = NodeGraphLoadSourceScript.new()
	_load_source.call(&"resolve", es, self, _on_map_generated)
	back_button.pressed.connect(_on_back_pressed)
	_mount_components(es)
	# 宿主先 add_child 再调 trigger_map_load 时，本次 _ready 已消费该请求；
	# 反之（先赋值再 add_child）留待宿主调用。
	if _pending_map_id != &"":
		var pending: StringName = _pending_map_id
		_pending_map_id = &""
		trigger_map_load(pending)


## 当前数据源是否为 stub 降级（只读标记——集成测试据此区分真实数据与 stub）。[br]
## 未进树时为 false——此时还没有数据源可选。
func is_using_stub_source() -> bool:
	return _load_source != null and bool(_load_source.get(&"using_stub"))


## 商店/回复接线组件（见 [ShopNodePresenter]）——未挂载时为 null。[br]
## [br][b]以下五个访问器同口径[/b]：公开入口，集成测试与后续 story 经此断言/驱动
## 各类 overlay，不依赖私有成员名。
func shop_presenter() -> Variant:
	return _components.get("shop_presenter")


## 传送选层接线组件（见 [TeleportNodePresenter]）。
func teleport_presenter() -> Variant:
	return _components.get("teleport_presenter")


## 采集接线组件（见 [HarvestNodePresenter]）。
func harvest_presenter() -> Variant:
	return _components.get("harvest_presenter")


## 炼丹台/炼器台接线组件（见 [CraftNodePresenter]——两个台子共用一份，靠 kind 区分）。
func craft_presenter() -> Variant:
	return _components.get("craft_presenter")


## 打坐/洞府接线组件（见 [MeditationNodePresenter]——突破冲关 overlay）。
func meditation_presenter() -> Variant:
	return _components.get("meditation_presenter")


## 触发地图加载。[br]
## [br][b]真实源[/b]：调用 [code]ExplorationSystem.enter_map[/code] 命令——
## 地图生成、GSM 写入、[signal ExplorationSystem.map_generated] 广播都在系统侧，
## 本界面只是监听者（零状态所有权，ADR-0031 §2）。[br]
## [b]stub 源[/b]：发射 stub 快照驱动同一渲染路径（降级，见 [method is_using_stub_source]）。[br]
## [br][param p_map_id] 目标地图 ID（默认青云剑宗——编辑器/预览路径用）。[br]
func trigger_map_load(p_map_id: StringName = &"qing_yun_jian_zong") -> void:
	# 未进树时信号尚未连接（_ready 里连）——记下目标，进树后补触发，
	# 否则真实源广播的 map_generated 会被丢掉、节点图空白。
	if not is_inside_tree():
		_pending_map_id = p_map_id
		return
	if _load_source == null:
		_load_source = NodeGraphLoadSourceScript.new()
		_load_source.call(&"resolve", _get_exploration_system(), self, _on_map_generated)
	_load_source.call(&"load_map", p_map_id)


func _exit_tree() -> void:
	if _reveal_animator != null:
		_reveal_animator.call(&"kill")


## 连接探索系统信号——map_generated / node_moved（事件驱动，无轮询）。
func _connect_signals() -> void:
	var es: Node = _get_exploration_system()
	if es == null:
		return
	if es.has_signal(&"map_generated"):
		es.map_generated.connect(_on_map_generated)
	if es.has_signal(&"node_moved"):
		es.node_moved.connect(_on_node_moved)


## 挂载全部子组件——挂载与接线细节在 [NodeGraphComponentAssembly]（交互三组件 +
## 事件弹出通道 + 商店/回复/传送/采集/炼制/打坐接线 + 转发回调表），屏幕只持引用。
func _mount_components(es: Node) -> void:
	_components = ComponentAssemblyScript.assemble(self, renderer(),
			viewport, es, reduce_motion_override)


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
## [b]唯一渲染入口[/b]：真实系统与 stub 降级两条数据源都汇到本方法，渲染路径
## 只有一份（换数据源不改渲染）。[br]
## [param _map_id] 地图 ID（快照里也有一份，渲染不用）。[br]
## [param map_data] 渲染快照（graph/nodes/visited/current_node/ap_remaining）。
func _on_map_generated(_map_id: StringName, map_data: Dictionary) -> void:
	_current_snapshot = map_data
	renderer().setup(
			map_data.get("graph", {}),
			map_data.get("nodes", {}),
			map_data.get("visited", []),
			int(map_data.get("current_node", -1)))
	_refresh_ap_label(map_data)
	_reveal().call(&"recompute_states", renderer(), map_data)
	var nodes: Dictionary = map_data.get("nodes", {})
	if animate:
		_reveal().call(&"play_reveal", self, renderer(), nodes)
	else:
		_reveal().call(&"reveal_all", renderer(), nodes)
	# S17-005：快照注入移动交互组件 + 教程首次进入入口
	var interactor: Variant = _sub_component(&"interactor")
	if interactor != null:
		interactor.call(&"apply_snapshot", map_data)
	var tutorial: Variant = _sub_component(&"tutorial")
	if tutorial != null:
		tutorial.call(&"on_map_entered")
	var popup_host: Variant = _sub_component(&"popup_host")
	if popup_host != null:
		popup_host.call(&"apply_snapshot", map_data)
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
	_reveal().call(&"recompute_states", renderer(), _current_snapshot)
	# S17-006：快照随移动重下发——否则弹窗宿主的 current_node 停留在上一节点，
	# 战斗弹窗会锚在「出发节点」而非「到达节点」（弹窗在动画结束后才打开，
	# 本回调先于到达转发执行，时机足够）。
	var popup_host: Variant = _sub_component(&"popup_host")
	if popup_host != null:
		popup_host.call(&"apply_snapshot", _current_snapshot)
	# S17-005：移动动画由交互组件自绑 node_moved 信号驱动（_bind_system_signals
	# ——宿主不转发，避免双重动画+缓冲队列双重消费）。


## === 六态判定 / 逐层展开（消费 NodeStateLogic 纯函数——Logic 内核）==========

## === 内部辅助 ==============================================================

## 渲染器引用——viewport 的内容宿主（[NodeGraphViewport.renderer]）。
func renderer() -> NodeGraphRenderer:
	return viewport.renderer


## 刷新行动力标签（右上角 AP 显示；数据源 = 快照 ap_remaining）。
func _refresh_ap_label(snapshot: Dictionary) -> void:
	ap_label.text = "%s: %d" % [TEXT_AP_PREFIX, int(snapshot.get("ap_remaining", 0))]


## 六态重算 + 展开动画子模块（惰性初始化）。
func _reveal() -> RefCounted:
	if _reveal_animator == null:
		_reveal_animator = NodeGraphRevealAnimatorScript.new()
	return _reveal_animator


## 交互子组件（interactor / tutorial / popup_host）——未挂载时返回 null。[br]
## [b]用字典读取而非类型化字段[/b]：子组件由 [NodeGraphInteractionMount] 持有，
## 屏幕不重复声明（避免两处各记一份）；headless 下单测也可能没走过挂载。
func _sub_component(p_key: StringName) -> Variant:
	var mount: Variant = _components.get("interaction_mount")
	if mount == null:
		return null
	return mount.get(p_key)


## 获取探索系统——注入对象优先，否则回退 Autoload。
func _get_exploration_system() -> Node:
	if exploration_system != null:
		return exploration_system
	return get_node_or_null("/root/ExplorationSystem")


func _on_back_pressed() -> void:
	back_to_map_select_requested.emit()
