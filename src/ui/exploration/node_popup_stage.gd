class_name NodePopupStage
extends RefCounted
## NodePopupStage —— 节点交互弹窗的「舞台」职责（从
## [code]node_interaction_popup_host.gd[/code] 拆出）。[br]
## [br][b]职责[/b]：弹窗期间节点图的[b]冻结/解冻[/b]、弹窗的[b]屏幕定位[/b]、
## 背景模糊[b]遮罩的挂载与 z 序[/b]。三者都只碰「视觉与输入面」，不碰任何
## 业务状态——宿主继续负责分发表路由与确认派发。[br]
## [br][b]为什么合在一处[/b]：冻结、遮罩、定位共享同一组坐标与层级前提
## （视口缩放/平移、宿主尺寸、z 序「节点图 < 遮罩 < 弹窗」）。散在宿主里时
## 每次改 z 序都要跨三个方法核对，拆成一个组件后这三件事只有一处可审。[br]
## [br][b]冻结幂等[/b]：连续到达（弹窗未关就换下一类）会二次冻结——若不判
## [member _frozen]，第二次会把「已冻结」当作原件保存，关闭后永远解不开冻。[br]
## [br][b]零轮询[/b]（ADR-0031 §3）：无 [code]_process()[/code]——全部由宿主
## 的开合调用驱动。[br]
##
## 来源: design/gdd/exploration-ui-system.md §4「模糊 40% / 弹窗在节点附近」、
## ADR-0031 §2/§3、exploration-ui Story 006（AC-11）。

## 弹窗定位常量（与 [NodeInteractionRules] 同源——尺寸/偏移/边距的单一来源）。
const Rules := preload("res://src/ui/exploration/node_interaction_rules.gd")
## 背景模糊遮罩（BackBufferCopy + pause_blur 着色器——复用暂停菜单同源 shader）。
const BlurMaskScript := preload("res://src/ui/exploration/node_popup_blur_mask.gd")

## 宿主容器（遮罩挂载点 + 布局尺寸来源）。
var host: Control = null
## 渲染器（节点中心坐标源——[method NodeGraphRenderer.get_node_position]）。
var renderer: Control = null
## 视口（冻结缩放/平移——[member NodeGraphViewport.input_frozen]）。
var viewport: Control = null

## 冻结前的 renderer 鼠标过滤模式（恢复用）。
var _saved_mouse_filter: int = Control.MOUSE_FILTER_STOP
## 冻结前视口 input_frozen 值（恢复用）。
var _saved_viewport_frozen: bool = false
## 是否处于冻结态（幂等守卫）。
var _frozen: bool = false
## 背景模糊遮罩实例（[NodePopupBlurMask]）。
var _mask: Control = null
## 弹窗实例（惰性构建——与遮罩共享同一宿主，便于 z 序编排）。
var _popup_ref: Control = null


## 绑定宿主与两个依赖（宿主 setup 时调用；可重复调用——幂等）。
func bind(p_host: Control, p_renderer: Control, p_viewport: Control) -> void:
	host = p_host
	renderer = p_renderer
	viewport = p_viewport


## 挂载背景模糊遮罩（[NodePopupBlurMask] 持有 BackBufferCopy + 着色器；
## 本组件只负责挂载与置顶层级）。GDD §4「模糊 40%」。
func build_mask() -> void:
	if host == null:
		return
	if _mask != null and is_instance_valid(_mask):
		return
	_mask = BlurMaskScript.new()
	host.add_child(_mask)
	_mask.move_to_front()


## 遮罩显隐——先亮遮罩并置顶，再把弹窗提到遮罩之上。[br]
## z 序不变式：节点图 < 遮罩 < 弹窗。
func show_mask(p_show: bool, p_popup: Control) -> void:
	if _mask == null or not is_instance_valid(_mask):
		return
	_mask.show_blur(p_show)
	if not p_show:
		return
	_mask.move_to_front()
	if p_popup != null:
		p_popup.move_to_front()


## 冻结节点图——视口 input_frozen + renderer 鼠标过滤（点击/悬停/缩放/平移全失效）。[br]
## [br][b]幂等[/b]：已在冻结态时直接返回，不覆盖保存的原值。
func freeze() -> void:
	if _frozen:
		return
	_frozen = true
	if viewport != null and (&"input_frozen" in viewport):
		_saved_viewport_frozen = bool(viewport.get(&"input_frozen"))
		viewport.set(&"input_frozen", true)
	if renderer != null:
		_saved_mouse_filter = renderer.mouse_filter
		renderer.mouse_filter = Control.MOUSE_FILTER_IGNORE


## 解冻节点图（恢复冻结前状态——不硬编码 STOP，尊重场景原值）。
func unfreeze() -> void:
	if not _frozen:
		return
	_frozen = false
	if viewport != null and (&"input_frozen" in viewport):
		viewport.set(&"input_frozen", _saved_viewport_frozen)
	if renderer != null:
		renderer.mouse_filter = _saved_mouse_filter


## 是否处于冻结态（测试/宿主查询）。
func is_frozen() -> bool:
	return _frozen


## 打开弹窗的视觉编排（冻结 → 遮罩 → 开 → 定位）。[br]
## [br][b]顺序即 z 序前提[/b]：遮罩必须先亮并置顶，弹窗才提到遮罩之上；
## 定位在 [method NodeInteractionPopup.open] 之后（尺寸已定）。
func present(p_popup: Control, p_kind: StringName, p_lines: Array,
		p_warning: Array, p_node_id: int) -> void:
	if p_popup == null:
		return
	freeze()
	show_mask(true, p_popup)
	p_popup.open(p_kind, p_lines, p_warning)
	place(p_popup, p_node_id)


## 关闭弹窗的视觉编排（关动画 → 解冻 → 遮罩淡出）。[br]
## [br]解冻不依赖弹窗实例：实例丢失时仍要把节点图放出来（防锁死）。
func dismiss(p_popup: Control) -> void:
	if p_popup != null:
		p_popup.play_close()
	unfreeze()
	show_mask(false, p_popup)


## 弹窗实例（惰性构建——控件树只建一次；宿主负责连接信号与派发）。[br]
## [br][param p_script] 弹窗脚本（[code]node_interaction_popup.gd[/code]）。[br]
## [param p_reduce_motion] 动画偏好（新建时写入；已存在时同步）。
func popup(p_script: GDScript, p_reduce_motion: bool) -> Control:
	if _popup_ref != null and is_instance_valid(_popup_ref):
		_popup_ref.reduce_motion = p_reduce_motion
		return _popup_ref
	if host == null or p_script == null:
		return null
	_popup_ref = p_script.new()
	_popup_ref.reduce_motion = p_reduce_motion
	host.add_child(_popup_ref)
	return _popup_ref


## 弹窗是否可见（无实例 = false）。
func is_popup_open() -> bool:
	return _popup_ref != null and is_instance_valid(_popup_ref) \
			and _popup_ref.visible


## ESC 关闭（AC-2 Edge——宿主全局兜底）。[br]
## [br][b]返回[/b]：是否消费了该事件（弹窗打开且按下 ESC）。
func handle_escape(p_event: InputEvent, p_close: Callable) -> bool:
	if not is_popup_open():
		return false
	if not (p_event is InputEventKey and p_event.pressed and not p_event.echo):
		return false
	if p_event.keycode != KEY_ESCAPE:
		return false
	p_close.call()
	return true


## 定位弹窗到节点附近（renderer 画布坐标 → 屏幕坐标 → 夹入视口）。[br]
## [param p_node_id] 为 -1 时无节点锚点（战斗到达）——居中偏右，不覆盖全屏。
func place(p_popup: Control, p_node_id: int) -> void:
	if p_popup == null:
		return
	var host_size: Vector2 = host.size if host != null else Vector2.ZERO
	var popup_size: Vector2 = Rules.POPUP_SIZE
	if renderer == null or p_node_id < 0:
		p_popup.position = Rules.popup_position(host_size * 0.5, popup_size, host_size)
		return
	var world: Vector2 = renderer.get_node_position(p_node_id)
	var zoom: float = 1.0
	var offset: Vector2 = Vector2.ZERO
	if viewport != null:
		zoom = float(viewport.get(&"zoom")) if (&"zoom" in viewport) else 1.0
		offset = viewport.get(&"offset") if (&"offset" in viewport) else Vector2.ZERO
	p_popup.position = Rules.popup_position(world * zoom + offset, popup_size, host_size)
