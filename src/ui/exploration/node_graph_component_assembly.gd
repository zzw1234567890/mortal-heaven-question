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
##     监听 [code]event_node_reached[/code]）；[br]
##   - [ShopNodePresenter]——商店 overlay 与回复/灵泉提示（消费弹窗宿主的
##     [code]shop_opened[/code] / [code]rest_used[/code] / [code]spring_used[/code]
##     ——「确认之后」的接线）；[br]
##   - [TeleportNodePresenter]——传送节点的选层 overlay（消费交互组件的
##     [code]node_interaction_forwarded[/code] 里的 [code]teleport[/code]——
##     传送被 B5 裁决排除在弹窗分发表之外，故走独立通道）。[br]
##
## [b]不持有游戏状态[/b]：只建组件与连信号，状态全在快照里（ADR-0031 §2）。
##
## 来源: story-003/005/006（交互组件）、Sprint 18 事件节点、ADR-0031 §2/§4、
## GDD exploration-ui-system.md §4c（商店确认 → overlay）。

## NodeGraphInteractionMount 脚本常量（class_name 在 headless 动态加载下不可靠）。
const NodeGraphInteractionMountScript := preload(
		"res://src/ui/exploration/node_graph_interaction_mount.gd")
## EventNodePresenter 脚本常量（事件弹出通道）。
const EventNodePresenterScript := preload(
		"res://src/ui/exploration/event_node_presenter.gd")
## ShopNodePresenter 脚本常量（商店 overlay + 回复/灵泉提示——「确认之后」接线）。
const ShopNodePresenterScript := preload(
		"res://src/ui/exploration/shop_node_presenter.gd")
## TeleportNodePresenter 脚本常量（传送选层 overlay——B5 排除弹窗后的独立通道）。
const TeleportNodePresenterScript := preload(
		"res://src/ui/exploration/teleport_node_presenter.gd")
## NodePopupStage 脚本常量（商店面板期间的节点图冻结——独立实例，见挂载方法）。
const NodePopupStageScript := preload("res://src/ui/exploration/node_popup_stage.gd")
## SettingsStore 脚本常量——reduce_motion 偏好读取（GFX_KEY_* 单一真理来源）。
const SettingsStoreScript := preload("res://src/ui/main_menu/settings_store.gd")
## HUD 生产挂载入口——通知出口（[method HudBootstrap.mounted] 是 HUD 节点路径
## 的单一查找点，与 exploration_scene 的回探索提示同源）。
const HudBootstrapScript := preload("res://src/ui/hud/hud_bootstrap.gd")
## SceneManager 路径常量（EventSystem/通知出口共用的 Autoload 名）。
const SCENE_MANAGER_PATH: StringName = &"/root/SceneManager"


## 装配屏幕的全部子组件。[br]
## [param p_screen] 屏幕（组件宿主 + 转发回调源 + 焦点/反馈处理者）。[br]
## [param p_renderer] 节点图渲染器。[br]
## [param p_viewport] 缩放平移容器（弹窗冻结用）。[br]
## [param p_es] 探索系统（信号源，可空——stub 降级时仍挂 UI 组件）。[br]
## [param p_reduce_motion_override] 测试注入的减少动态偏好（null 时读 SettingsStore）。[br]
## [b]返回[/b]：[code]{interaction_mount, event_presenter, shop_presenter,
## teleport_presenter}[/code]——屏幕持有引用防 RefCounted 提前释放。
static func assemble(p_screen: Control, p_renderer: Control, p_viewport: Control,
		p_es: Node, p_reduce_motion_override: Variant) -> Dictionary:
	var interaction_mount: RefCounted = NodeGraphInteractionMountScript.new()
	interaction_mount.call(&"mount", p_screen, p_renderer, p_viewport, p_es,
			_read_reduce_motion(p_reduce_motion_override), _forward_table(p_screen),
			p_screen.get_node_or_null(NodePath(SCENE_MANAGER_PATH)),
			p_screen.get_node_or_null(NodePath("/root/RealmSystem")))
	return {
		"interaction_mount": interaction_mount,
		"event_presenter": _mount_event_presenter(p_screen, p_es),
		"shop_presenter": _mount_shop_presenter(p_screen, p_renderer, p_viewport, p_es,
				interaction_mount.get(&"popup_host"), interaction_mount.get(&"interactor")),
		"teleport_presenter": _mount_teleport_presenter(p_screen, p_renderer, p_viewport,
				p_es, interaction_mount.get(&"interactor")),
	}


## 商店/回复接线挂载——[ShopNodePresenter] 消费弹窗宿主的确认信号。[br]
## [br][b]宿主选择[/b]：商店 overlay 挂屏幕自身（与事件面板同层——都是全屏覆盖层）；
## [b]提示出口[/b]接常驻 HUD（[method HudBootstrap.mounted] 是 HUD 节点路径的
## 单一查找点），HUD 未挂载时 presenter 只留痕不崩溃。[br]
## [br][b]冻结来源（独立舞台实例）[/b]：商店面板存活期间节点图不吃输入
## （GDD §4c）。用[b]自建[/b] [NodePopupStage] 而非弹窗宿主那份——宿主那份在
## 弹窗关闭时已解冻，且它保存的「原值」是弹窗自己的基线；自建实例保存的是
## 「商店打开前」的基线，两侧各管各的配对，互不干扰（弹窗若在商店期间开合，
## 它会把自己看到的「已冻结」当原值，关回去仍是冻结——语义正确）。[br]
## [br][b]键盘路径[/b]：舞台只管视口/渲染器，键盘走位由交互组件的
## [code]set_process_unhandled_key_input[/code] 开关（与弹窗期间同一做法）。
static func _mount_shop_presenter(p_host: Control, p_renderer: Control,
		p_viewport: Control, p_es: Node, p_popup_host: Variant,
		p_interactor: Variant) -> RefCounted:
	if p_popup_host == null or not (p_popup_host is Control):
		return null
	var stage: RefCounted = NodePopupStageScript.new()
	stage.call(&"bind", p_host, p_renderer, p_viewport)
	var presenter: RefCounted = ShopNodePresenterScript.new()
	presenter.call(&"attach", p_es, p_popup_host, p_host, _notification_sink(p_host),
			_freeze_of(stage, p_interactor, true), _freeze_of(stage, p_interactor, false))
	return presenter


## 传送选层接线挂载——[TeleportNodePresenter] 消费交互组件的到达转发里的
## [code]teleport[/code]（B5 裁决：传送不进弹窗分发表，走独立通道）。[br]
## [br][b]为什么挂屏幕自身[/b]：与商店 overlay 同层（都是全屏覆盖层）；
## [b]冻结来源[/b]同样用自建 [NodePopupStage]（保存的基线是「传送面板打开前」，
## 与弹窗那侧各管各的配对）。[br]
## [br][b]键盘路径[/b]：由面板自己的 [code]_input[/code] 消费方向键/确认/取消
## （见 [code]teleport_panel_screen.gd[/code] 类文档「事件层级 = _input」），
## 冻结只需挡住节点图的键盘走位。
static func _mount_teleport_presenter(p_host: Control, p_renderer: Control,
		p_viewport: Control, p_es: Node, p_interactor: Variant) -> RefCounted:
	if p_interactor == null or not (p_interactor is Control):
		return null
	var stage: RefCounted = NodePopupStageScript.new()
	stage.call(&"bind", p_host, p_renderer, p_viewport)
	var presenter: RefCounted = TeleportNodePresenterScript.new()
	presenter.call(&"attach", p_es, p_interactor, p_host, _notification_sink(p_host),
			_freeze_of(stage, p_interactor, true), _freeze_of(stage, p_interactor, false))
	return presenter


## 冻结 / 解冻闭包——舞台 + 交互组件键盘开关（[param p_freeze] 区分方向）。
static func _freeze_of(p_stage: RefCounted, p_interactor: Variant, p_freeze: bool) -> Callable:
	return func() -> void:
		p_stage.call(&"freeze" if p_freeze else &"unfreeze")
		if p_interactor != null and is_instance_valid(p_interactor):
			p_interactor.call(&"set_process_unhandled_key_input", not p_freeze)


## 通知出口——常驻 HUD 的 [method Hud.request_notification]；未挂载时返回无效
## Callable（presenter 走 [code]last_hint[/code] + push_warning 降级路径）。
static func _notification_sink(p_host: Node) -> Callable:
	var sm: Node = p_host.get_node_or_null(NodePath(SCENE_MANAGER_PATH))
	var hud: Node = HudBootstrapScript.mounted(sm)
	if hud == null or not hud.has_method(&"request_notification"):
		return Callable()
	return Callable(hud, &"request_notification")


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
