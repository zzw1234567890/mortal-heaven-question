extends RefCounted
## NodeGraphComponentAssembly —— 节点图屏幕的子组件装配编排（从 NodeGraphScreen 拆出）。
##
## [b]为什么单独一处[/b]：屏幕脚本超 300 行软上限，而「挂哪些组件、怎么接线」
## 与「收到快照怎么画」是两件事——后者才是屏幕的职责
## （同 [code]node_graph_interaction_mount.gd[/code] 拆分先例）。
##
## [b]装配内容[/b]：[br]
##   - [NodeGraphInteractionMount]——移动/教程/弹窗三组件（转发回调表由屏幕提供）；[br]
##   - [EventNodePresenter]——事件节点弹出通道（AC-9 防双面板——独立于弹窗宿主，
##     监听 [code]event_node_reached[/code]）。
##
## [b]不持有游戏状态[/b]：只建组件与连信号，状态全在快照里（ADR-0031 §2）。
##
## 来源: story-003/005/006（交互组件）、Sprint 18 事件节点、ADR-0031 §2/§4。

## NodeGraphInteractionMount 脚本常量（class_name 在 headless 动态加载下不可靠）。
const NodeGraphInteractionMountScript := preload(
		"res://src/ui/exploration/node_graph_interaction_mount.gd")
## EventNodePresenter 脚本常量（事件弹出通道）。
const EventNodePresenterScript := preload(
		"res://src/ui/exploration/event_node_presenter.gd")
## SettingsStore 脚本常量——reduce_motion 偏好读取（GFX_KEY_* 单一真理来源）。
const SettingsStoreScript := preload("res://src/ui/main_menu/settings_store.gd")


## 装配屏幕的全部子组件。[br]
## [param p_screen] 屏幕（组件宿主 + 转发回调源 + 焦点/反馈处理者）。[br]
## [param p_renderer] 节点图渲染器。[br]
## [param p_viewport] 缩放平移容器（弹窗冻结用）。[br]
## [param p_es] 探索系统（信号源，可空——stub 降级时仍挂 UI 组件）。[br]
## [param p_reduce_motion_override] 测试注入的减少动态偏好（null 时读 SettingsStore）。[br]
## [b]返回[/b]：[code]{interaction_mount, event_presenter}[/code]——屏幕持有引用
## 防 RefCounted 提前释放。
static func assemble(p_screen: Control, p_renderer: Control, p_viewport: Control,
		p_es: Node, p_reduce_motion_override: Variant) -> Dictionary:
	var interaction_mount: RefCounted = NodeGraphInteractionMountScript.new()
	interaction_mount.call(&"mount", p_screen, p_renderer, p_viewport, p_es,
			_read_reduce_motion(p_reduce_motion_override), _forward_table(p_screen),
			p_screen.get_node_or_null(NodePath("/root/SceneManager")),
			p_screen.get_node_or_null(NodePath("/root/RealmSystem")))
	return {
		"interaction_mount": interaction_mount,
		"event_presenter": _mount_event_presenter(p_screen, p_es),
	}


## 事件节点弹出通道挂载——[EventNodePresenter] 监听 [code]event_node_reached[/code]
## 弹面板（AC-9：不走弹窗宿主，防双面板）。[br]
## [b]rng 注入[/b]：生产路径注入真实 rng——事件在候选内随机抽取
## （GDD §10「到达时才确定」防 SL）；测试直接 attach Presenter 时缺省 null，
## 走按节点 id 取模的确定性路径。
static func _mount_event_presenter(p_host: Control, p_es: Node) -> RefCounted:
	if p_es == null or not p_es.has_signal(&"event_node_reached"):
		return null
	var presenter: RefCounted = EventNodePresenterScript.new()
	presenter.call(&"attach", p_es, p_host, RandomNumberGenerator.new())
	return presenter


## 转发回调表——交互组件的到达/反馈信号经屏幕公开信号再暴露（审查 H3——
## 后续 story 只连屏幕信号，不依赖私有成员）。
static func _forward_table(p_screen: Node) -> Dictionary:
	return {
		NodeGraphInteractionMountScript.KEY_MOVE_FEEDBACK:
			Callable(p_screen, &"_on_move_feedback"),
		NodeGraphInteractionMountScript.KEY_KEYBOARD_FOCUS:
			Callable(p_screen, &"_on_keyboard_focus_changed"),
		NodeGraphInteractionMountScript.KEY_COMBAT_ARRIVAL:
			func(roster: Array, ctype: StringName) -> void:
				p_screen.emit_signal(&"combat_arrival_forwarded", roster, ctype),
		NodeGraphInteractionMountScript.KEY_BOSS_ARRIVAL:
			func(data: Dictionary) -> void:
				p_screen.emit_signal(&"boss_arrival_forwarded", data),
		NodeGraphInteractionMountScript.KEY_NODE_INTERACTION:
			func(nid: int, itype: StringName, payload: Dictionary) -> void:
				p_screen.emit_signal(&"node_interaction_forwarded", nid, itype, payload),
	}


## 读取减少动态偏好——注入覆盖优先，否则读 SettingsStore 画面分类（审查 H5）。
static func _read_reduce_motion(p_override: Variant) -> bool:
	if p_override != null:
		return bool(p_override)
	var store: RefCounted = SettingsStoreScript.new()
	var gfx: Dictionary = store.load_graphics_category()
	return bool(gfx.get(SettingsStoreScript.GFX_KEY_REDUCE_MOTION, false))
