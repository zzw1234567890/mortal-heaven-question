class_name NodeGraphScreen
extends Control
## NodeGraphScreen —— 节点图主界面（exploration-ui Story S16-3）。
##
## [b]节点形态[/b]（ADR-0031 §1）：场景内 Control 树（零新增 Autoload），由
## [code]ExplorationScene[/code] 薄容器挂载（进入地图后叠加于 MapSelectScreen）。[br]
## [br][b]结构[/b]：NodeGraphViewport（缩放平移）承载 NodeGraphRenderer（渲染基座）
## + 顶栏状态区（[NodeGraphStatusBar]：行动力 / 走投无路提示 / 退出探索）。[br]
## [br][b]信号驱动路径[/b]：本界面[b]只消费 [signal ExplorationSystem.map_generated][/b]
## ——按 map_data.nodes/graph 构建快照 → 六态经 [NodeStateLogic.classify_node_state]
## 判定 → 样式经 [NodeStateLogic.node_state_style] 渲染。[br]
## [br][b]数据源优先级[/b]（[method trigger_map_load]）：1. 真实探索系统可用且声明
## [code]map_generated[/code] → 调 [code]enter_map[/code] 命令（生成/写入/广播都在系统侧），
## 本界面不写任何游戏状态；2. 否则挂 [MapGeneratedStub] 降级发射器渲染 story-003 样本
## （判据是[b]信号是否声明[/b]而非 Autoload 是否存在——B-1 回归）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：[code]_current_snapshot[/code] 为渲染输入快照
## （瞬态交互状态，不进存档）。[b]零轮询[/b]：无 [code]_process()[/code]——展开/迷雾皆由信号驱动 Tween。[br]
## 来源: story-003-node-graph-data-states.md、ADR-0031 §2/§3、ADR-0014 §决策 3。

## === 依赖（测试可替换）======================================================

## 探索系统引用——map_generated/node_moved 信号源（null 时回退 stub 发射器）。
var exploration_system: Node = null
## 动画开关——测试注入（S16-1 先例）；false 时跳过逐层展开动画直接全显。
var animate: bool = true
## 减少动态偏好——测试/宿主注入（null 时从 SettingsStore 读取，审查 H5）。
var reduce_motion_override: Variant = null

## === 场景常量 ==============================================================

## 数据源选择、加载编排与信号连接配对（真实 enter_map / stub 降级）。
const NodeGraphLoadSourceScript := preload("res://src/ui/exploration/node_graph_load_source.gd")
## 子组件装配编排（交互组件 + 事件弹出通道）——挂载细节在装配器，屏幕只持引用。
const ComponentAssemblyScript := preload(
		"res://src/ui/exploration/node_graph_component_assembly.gd")
## 六态重算 + 逐层展开动画；顶栏状态区（行动力显示 / 走投无路提示 / 退出探索）。
const NodeGraphRevealAnimatorScript := preload(
		"res://src/ui/exploration/node_graph_reveal_animator.gd")
const StatusBarScript := preload("res://src/ui/exploration/node_graph_status_bar.gd")

## === 信号 ==================================================================

## 返回地图选择意图——顶栏「退出探索」确认后发出。[br]
## [b]一条信号两件事[/b]：「退出探索」的结果就是回到地图选择界面（GDD
## exploration-system.md §AC），故不另立一个语义重复的信号；结算由薄容器接住。
signal back_to_map_select_requested

## === 到达通知转发（审查 H3——006/007 消费入口：组件信号经屏幕再暴露一层，后续 story 不必依赖节点路径）==
signal combat_arrival_forwarded(enemy_roster: Array, combat_type: StringName)
signal boss_arrival_forwarded(boss_data: Dictionary)
signal node_interaction_forwarded(node_id: int, interaction_type: StringName, payload: Dictionary)
## 移动失败 toast 文案（审查 H1——HUD 通知区域 [method Hud.request_notification] 接线后由 006 接入）。
signal move_feedback_forwarded(toast_text: String, node_id: int)

## === 节点引用 ==============================================================

@onready var viewport: NodeGraphViewport = $NodeGraphViewport

## === 瞬态渲染状态（ADR-0031 §2.1 瞬态交互状态）============================

## 当前渲染快照（graph/nodes/visited/current_node/ap_remaining）——node_moved
## 后重算六态用；不进存档。
var _current_snapshot: Dictionary = {}
## 数据源选择、加载编排与信号连接（见 [NodeGraphLoadSource]）。
var _load_source: RefCounted = null
## 待加载地图 ID——[method trigger_map_load] 在进树前被调用时记下，[method _ready]
## 补触发一次（场景编排先 add_child 后调 trigger_map_load 是既有顺序）。
var _pending_map_id: StringName = &""
## 待加载是否走读档续玩——与 [member _pending_map_id] 同进同出（同一个请求的两半）。
var _pending_resume: bool = false
## 装配结果——[code]{interaction_mount, event_presenter, shop_presenter,
## teleport_presenter, harvest_presenter, craft_presenter, meditation_presenter}[/code]
## （见 [NodeGraphComponentAssembly]）。[b]为什么整块存字典[/b]：屏幕只负责
## 「持引用防提前释放」+ 对外访问器，逐个声明等于把返回契约写两处。
var _components: Dictionary = {}
## 六态重算 + 逐层展开动画（见 [NodeGraphRevealAnimator]）。
var _reveal_animator: RefCounted = null
## 顶栏状态区（行动力 / 走投无路提示 / 退出探索——见 [NodeGraphStatusBar]）。
var _status_bar: RefCounted = null


func _ready() -> void:
	# 数据源选择与信号连接都在子模块——判定依据是[b]信号是否声明[/b]而非
	# Autoload 是否存在（B-1 回归见子模块文档）。
	var es: Node = _get_exploration_system()
	_ensure_load_source()
	_mount_status_bar()
	_mount_components(es)
	# 宿主先 add_child 再调 trigger_map_load 时，本次 _ready 已消费该请求；
	# 反之（先赋值再 add_child）留待宿主调用。
	if _pending_map_id != &"":
		var pending: StringName = _pending_map_id
		var pending_resume: bool = _pending_resume
		_pending_map_id = &""
		_pending_resume = false
		trigger_map_load(pending, pending_resume)


func _exit_tree() -> void:
	if _reveal_animator != null:
		_reveal_animator.call(&"kill")
	if _load_source != null:
		# 断开探索系统信号——理由见 [method NodeGraphLoadSource.unbind]（旧界面在
		# queue_free 生效前仍连着，同帧重进地图会把广播打到已脱树的界面上）。
		_load_source.call(&"unbind")


## 当前数据源是否为 stub 降级（只读标记——集成测试据此区分真实数据与 stub）。[br]
## 未进树时为 false——此时还没有数据源可选。
func is_using_stub_source() -> bool:
	return _load_source != null and bool(_load_source.get(&"using_stub"))


## 是否已拿到渲染快照（[param p_resume] 路径的失败判据）。[br]
## [br][b]为什么薄容器需要它[/b]：读档续玩时该图若在存档里没有 graph/nodes 快照，
## 加载会如实失败、本屏幕保持空白——容器据此拆掉它退回选图界面。
func has_snapshot() -> bool:
	return not _current_snapshot.is_empty()


## 商店/回复接线组件（见 [ShopNodePresenter]）——未挂载时为 null。[br]
## [br][b]以下五个 presenter 访问器同口径[/b]：公开入口，集成测试与后续 story 经此
## 断言/驱动各类 overlay，不依赖私有成员名。依次为——商店/回复、传送选层、采集、
## 炼丹台+炼器台（共用一份，靠 kind 区分）、打坐/洞府（突破冲关 overlay）。
## 都是纯转发，故紧凑排列（不改访问器名）。
func shop_presenter() -> Variant:
	return _components.get("shop_presenter")

func teleport_presenter() -> Variant:
	return _components.get("teleport_presenter")

func harvest_presenter() -> Variant:
	return _components.get("harvest_presenter")

func craft_presenter() -> Variant:
	return _components.get("craft_presenter")

func meditation_presenter() -> Variant:
	return _components.get("meditation_presenter")

## 顶栏状态区（见 [NodeGraphStatusBar]）——未进树时为 null。
func status_bar() -> Variant:
	return _status_bar


## 触发地图加载。[br]
## [br][b]真实源[/b]：调用 [code]ExplorationSystem.enter_map[/code] 命令——
## 地图生成、GSM 写入、[signal ExplorationSystem.map_generated] 广播都在系统侧，
## 本界面只是监听者（零状态所有权，ADR-0031 §2）。[br]
## [b]stub 源[/b]：发射 stub 快照驱动同一渲染路径（降级，见 [method is_using_stub_source]）。[br]
## [br][param p_map_id] 目标地图 ID（默认青云剑宗——编辑器/预览路径用）。[br]
## [param p_resume] [code]true[/code] = [b]读档续玩[/b]（从存档快照重建，不重生成）。
func trigger_map_load(p_map_id: StringName = &"qing_yun_jian_zong",
		p_resume: bool = false) -> void:
	# 未进树时信号尚未连接（_ready 里连）——记下目标，进树后补触发，
	# 否则真实源广播的 map_generated 会被丢掉、节点图空白。
	if not is_inside_tree():
		_pending_map_id = p_map_id
		_pending_resume = p_resume
		return
	_ensure_load_source()
	_load_source.call(&"load_map", p_map_id, p_resume)


## 挂载全部子组件——挂载与接线细节在 [NodeGraphComponentAssembly]（交互三组件 +
## 事件弹出通道 + 商店/回复/传送/采集/炼制/打坐接线 + 转发回调表），屏幕只持引用。
func _mount_components(es: Node) -> void:
	_components = ComponentAssemblyScript.assemble(self, renderer(),
			viewport, es, reduce_motion_override)


## 键盘焦点转发——渲染器绘制松石青焦点环（ADR-0031 §4 双焦点双视觉）。
func _on_keyboard_focus_changed(node_id: int) -> void:
	renderer().set_focused_node(node_id)


## 移动失败反馈转发——先向后续 story 暴露公开信号 [signal move_feedback_forwarded]，
## 再由 HUD 通知区域消费（[b]审查 H1 延后接线[/b]：HUD 尚未挂载、
## [method Hud.request_notification] 全库无调用方；义务记入 story Test Evidence）。
func _on_move_feedback(toast_text: String, node_id: int) -> void:
	move_feedback_forwarded.emit(toast_text, node_id)
	push_warning("NodeGraphScreen: 移动反馈 toast（%s）——通知区域接线归 HUD story" % toast_text)


## === map_generated / node_moved 消费（信号驱动构建路径——AC-1/AC-2）========

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
	# S17-005：快照注入交互侧组件 + 教程首次进入入口（键名归装配器，见 push_snapshot）
	ComponentAssemblyScript.push_snapshot(_components, map_data)
	ComponentAssemblyScript.notify_map_entered(_components)
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
	# S17-006：快照随移动重下发（理由见 [method NodeGraphComponentAssembly.push_snapshot]）。
	ComponentAssemblyScript.push_snapshot(_components, _current_snapshot)
	# S17-005：移动动画由交互组件自绑 node_moved 信号驱动（宿主不转发，
	# 避免双重动画 + 缓冲队列双重消费）。


## === 内部辅助 ==============================================================

## 渲染器引用——viewport 的内容宿主（[NodeGraphViewport.renderer]）。
func renderer() -> NodeGraphRenderer:
	return viewport.renderer


## 刷新顶栏（行动力显示 + 走投无路提示；数据源 = 快照 + 系统的只读查询）。[br]
## [br][b]两者同一轮刷新[/b]：提示要读本图 [code]ap_cost[/code] 与豁免规则，由系统
## 作答（见 [NodeGraphStatusBar.can_reach_boss]）——对屏幕来说「AP 显示」与
## 「还能不能到 Boss」是同一份快照的两个读数。
func _refresh_ap_label(snapshot: Dictionary) -> void:
	if _status_bar == null:
		return
	_status_bar.call(&"bind_system", _get_exploration_system(), _from_system())
	_status_bar.call(&"refresh", snapshot)


## 挂载顶栏状态区——行动力标签 / 走投无路提示 / 退出探索按钮（见 [NodeGraphStatusBar]）。[br]
## [br][b]退出路径[/b]：按钮 → 确认弹窗 → [signal back_to_map_select_requested]，
## 由薄容器接住并走既有结算。本屏幕[b]不结算[/b]——零状态所有权（ADR-0031 §2）。
func _mount_status_bar() -> void:
	_status_bar = StatusBarScript.mount(self, Callable(self, &"_on_exit_confirmed"))


## 退出已确认——发意图（结算与场景编排归薄容器，见 [method _mount_status_bar]）。
func _on_exit_confirmed() -> void:
	back_to_map_select_requested.emit()


## 建好数据源模块并完成信号连接（幂等——[method trigger_map_load] 也会调）。
func _ensure_load_source() -> void:
	if _load_source != null:
		return
	_load_source = NodeGraphLoadSourceScript.new()
	_load_source.call(&"resolve", _get_exploration_system(), self,
			_on_map_generated, _on_node_moved)


## 正在渲染的快照是否出自真实系统（stub 降级 / 测试直调都为 false）。[br]
## 见 [member NodeGraphLoadSource.from_system]——系统在场不等于快照出自它。
func _from_system() -> bool:
	return _load_source != null and bool(_load_source.get(&"from_system"))


## 六态重算 + 展开动画子模块（惰性初始化）。[br]
## [br][b]可达性判定交给系统[/b]：[code]can_move_to_detail[/code]（本轮拆出的
## [code]{ok, reason}[/code]）与本界面六态同词表——由它作答，画出来的可达性就是
## 玩家点下去会得到的结果（含本图 [code]ap_cost[/code]）。[br]
## [br][b]只在快照真的出自系统时才接[/b]（见 [method _from_system]）——否则会被系统
## 缓存里那张无关的 DAG 判成一片不可达。每轮重算前刷新（系统与数据源均可注入）。
func _reveal() -> RefCounted:
	if _reveal_animator == null:
		_reveal_animator = NodeGraphRevealAnimatorScript.new()
	_reveal_animator.call(&"bind_verdict_provider", _get_exploration_system(), _from_system())
	return _reveal_animator


## 获取探索系统——注入对象优先，否则回退 Autoload。
func _get_exploration_system() -> Node:
	if exploration_system != null:
		return exploration_system
	return get_node_or_null("/root/ExplorationSystem")
