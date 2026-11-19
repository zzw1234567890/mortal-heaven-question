extends RefCounted
## RealInputClickDriver —— 用真实视口事件投递（[code]Viewport.push_input[/code]）
## 点击控件的驱动（2026-11-19 玩家实测反馈复现）。[br]
## [br][b]为什么要它[/b]：既有战斗用例要么直调
## [code]CombatInputLayer._handle_button[/code]，要么 [code]button.emit_signal("pressed")[/code]
## ——前者绕过了「按钮能不能收到事件」，后者绕过了「事件能不能走到按钮」。
## 玩家报的「点了没反应」恰好落在被绕过的这一段里。[br]
## [br][b]投递方式[/b]：[code]Viewport.push_input[/code]（引擎每帧对真实事件做的事），
## 按下与抬起成对（[code]Button.pressed[/code] 在抬起时发射，且抬起须落在按钮内）。[br]
## [br][b]坐标[/b]：投递收视口坐标，控件给的是画布坐标——一律经
## [code]get_global_transform_with_canvas()[/code] 换算（[code]stretch/mode=
## "canvas_items"[/code] 下两者不等价，写死坐标会在缩放窗口下错位）。[br]
## [br][b]命中自检[/b]：[method hit_control_at] 按引擎的拾取规则（[b]先子树后自身[/b]、
## 树内可见、[code]mouse_filter[/code] 非 IGNORE、矩形包含）回答「这点落在谁身上」。
## 这条自检是本轮定位的关键：按钮点不动时，先要分清「事件没送到按钮」还是「按钮自己坏」。[br]
## [br][b]为什么不用 [code]Input.parse_input_event[/code][/b]：它进的是 Input 单例
## 缓冲、下一帧才被取走；本驱动要求「投递即生效」的确定性（GUT 无帧循环保证）。[br]
## [br][b]为什么不用 [code]gui_get_hovered_control[/code] 判命中[/b]：它反映的是视口的
## 真实指针位置，合成事件不改它——实测会给出与分派无关的恒定答案。

## 战场门面取数回调（[code]func() -> Variant[/code]——夹具注入）。
var _root_provider: Callable = Callable()


func setup(p_root_provider: Callable) -> void:
	_root_provider = p_root_provider


# ═══════════════════════════════════════════════════════════════════════════════
# 坐标换算
# ═══════════════════════════════════════════════════════════════════════════════

## 控件中心 → 视口坐标（合成事件的投递坐标）。
func control_center_in_viewport(p_control: Control) -> Vector2:
	return p_control.get_global_transform_with_canvas() * (p_control.size * 0.5)


func end_turn_button_pos() -> Vector2:
	var b: Button = end_turn_button()
	return control_center_in_viewport(b) if b != null else Vector2(-1.0, -1.0)


func bag_button_pos() -> Vector2:
	var b: Button = bag_button()
	return control_center_in_viewport(b) if b != null else Vector2(-1.0, -1.0)


func retreat_button_pos() -> Vector2:
	var b: Button = retreat_button()
	return control_center_in_viewport(b) if b != null else Vector2(-1.0, -1.0)


# ═══════════════════════════════════════════════════════════════════════════════
# 投递
# ═══════════════════════════════════════════════════════════════════════════════

## 一次完整点击（按下 + 抬起成对——[code]Button.pressed[/code] 在抬起时发射）。[br]
## [br][b]抬起坐标同按下点[/b]：越界抬起会被按钮判成「拖出后松手」，不发信号。
func click(p_viewport_pos: Vector2) -> void:
	push_mouse(p_viewport_pos, true)
	push_mouse(p_viewport_pos, false)


## 点某个控件（自带坐标换算）。
func click_control(p_control: Control) -> void:
	if p_control != null:
		click(control_center_in_viewport(p_control))


## 单条鼠标事件投递（需要只发按下 / 只发抬起时用）。[br]
## [br][b]必须传 [code]in_local_coords = true[/code][/b]（2026-11-19 定位的第二个坑）：
## [code]push_input[/code] 默认把事件当[b]屏幕坐标[/b]，会再乘一次
## [code]get_final_transform().affine_inverse()[/code]（[code]canvas_items[/code] 拉伸的缩放）。
## 而本驱动给的已经是视口内坐标——再乘一次就整体偏掉：设计尺寸 1920×1080、无头窗口
## 1280×720 时缩放是 1.5，点 (1201,670) 实际落到 (1801,1005)，全屏输入层收下便再无下文
## （表现为「命中的确是按钮、点下去却没反应」，与玩家报的症状一模一样）。
## [code]true[/code] = 事件已是本地坐标，引擎直接拿去分派。
func push_mouse(p_viewport_pos: Vector2, p_pressed: bool) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = p_pressed
	event.position = p_viewport_pos
	event.global_position = p_viewport_pos
	tree.root.push_input(event, true)


# ═══════════════════════════════════════════════════════════════════════════════
# 命中自检与诊断
# ═══════════════════════════════════════════════════════════════════════════════

## 该视口坐标上会被 GUI 分派到的控件实例 ID（无命中返回 0）。
func hit_control_at(p_viewport_pos: Vector2) -> int:
	var hit: Control = sample_at(p_viewport_pos)
	return hit.get_instance_id() if hit != null else 0


## 该视口坐标上的命中控件（无命中返回 null）。[br]
## [br]按引擎的拾取规则采样——[code]Viewport._gui_find_control_at_pos[/code] 的顺序：
## 子节点逆序递归（最后画的先命中），子节点都没认领才轮到自身；自身认领要求
## 树内可见 + [code]mouse_filter[/code] 非 IGNORE + 矩形包含该点。
func sample_at(p_viewport_pos: Vector2) -> Control:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return _sample(tree.root, p_viewport_pos)


## 命中诊断——按钮点不动时打印这一行：命中 / 阶段 / 锁栈 / 层级一次看清。
func diagnose() -> String:
	var parts: Array = []
	parts.append("end_turn_hit=%s" % describe(sample_at(end_turn_button_pos())))
	parts.append("end_turn_rect=%s" % rect_text(end_turn_button()))
	parts.append("bag_hit=%s" % describe(sample_at(bag_button_pos())))
	parts.append("retreat_hit=%s" % describe(sample_at(retreat_button_pos())))
	parts.append("retreat_rect=%s" % rect_text(retreat_button()))
	parts.append("phase=%d" % int(_combat().call("get_current_phase")))
	parts.append("locks=%s" % str(InputManager.get_lock_stack()))
	var layer: Node = input_layer()
	parts.append("input_layer=%s(rect=%s, enabled=%s)" % [describe(layer),
			rect_text(layer as Control),
			str(layer.call("is_enabled")) if layer != null else "n/a"])
	return " | ".join(parts)


## 广场门面取数回调（部分用例把它当 [code]_root()[/code] 的别名用）。
func root_facade() -> Variant:
	return _root()


## 控件描摹（诊断文本用——null 与具名控件区分开）。
func describe(p_control: Control) -> String:
	if p_control == null:
		return "null"
	return "%s:%s" % [p_control.name, p_control.get_class()]


## 控件在视口空间里的矩形（诊断用——尺寸为 0 时一眼看得出）。
func rect_text(p_control: Control) -> String:
	if p_control == null:
		return "null"
	var r: Rect2 = p_control.get_global_rect()
	return "pos=(%.0f,%.0f) size=(%.0f,%.0f)" % [r.position.x, r.position.y,
			r.size.x, r.size.y]


# ═══════════════════════════════════════════════════════════════════════════════
# 组件探针（前置断言——把「装配缺失」与「点击无效」分开）
# ═══════════════════════════════════════════════════════════════════════════════

## 底部条「结束出牌」按钮本体（缺失返回 null）。
func end_turn_button() -> Button:
	return _wrapper_button("end_turn_button")


## 底部条「行囊」按钮本体（缺失返回 null）。
func bag_button() -> Button:
	var bar: Variant = _root().get("combat_bottombar")
	if bar == null:
		return null
	var wrapper: Variant = (bar as Object).get("bag_button")
	if wrapper is Button:
		return wrapper as Button
	if wrapper == null:
		return null
	return (wrapper as Object).get("button") as Button


## 右上角「撤退」按钮本体（缺失返回 null）。
func retreat_button() -> Button:
	var button: Variant = _root().get("retreat_button")
	return button as Button


## 前置探针：按钮存在且树内可见（不存在时测试体报「装配缺失」而非「点击无效」）。
func probe_end_turn() -> bool:
	var b: Button = end_turn_button()
	return b != null and b.is_visible_in_tree()


func probe_bag() -> bool:
	var b: Button = bag_button()
	return b != null and b.is_visible_in_tree()


func probe_retreat() -> bool:
	var b: Button = retreat_button()
	return b != null and b.is_visible_in_tree()


## 该控件中心的命中控件实例 ID（拿不到返回 0）——「点落在谁身上」的直接答案。
func hit_of(p_control: Control) -> int:
	if p_control == null:
		return 0
	return hit_control_at(control_center_in_viewport(p_control))


## 行囊面板当前条目数（0 = 空面板；未装配返回 -1）。
func bag_entry_count() -> int:
	var panel: Control = bag_panel()
	if panel == null:
		return -1
	return int((panel as Object).call(&"entry_count"))


## 行囊面板的「返回」按钮（关闭的真实鼠标路径——再点「行囊」够不到，见用例说明）。
func bag_leave_button() -> Button:
	var panel: Control = bag_panel()
	if panel == null:
		return null
	return panel.get("_leave_button") as Button


## 行囊面板本体（未装配返回 null）。
func bag_panel() -> Control:
	var mount: Variant = _scene().get("bag_mount")
	if mount == null:
		return null
	var host: Variant = (mount as Object).get("host")
	if host == null:
		return null
	return (host as Object).get("panel") as Control


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 底部条某按钮位 → Button 本体（按钮位是包装控件，本体在 [code]button[/code] 属性）。
func _wrapper_button(p_property: String) -> Button:
	var bar: Variant = _root().get("combat_bottombar")
	if bar == null:
		return null
	var wrapper: Variant = (bar as Object).get(p_property)
	if wrapper == null:
		return null
	return (wrapper as Object).get("button") as Button


## 引擎拾取规则的采样（子节点逆序递归 → 自身）。
func _sample(p_node: Node, p_point: Vector2) -> Control:
	for i: int in range(p_node.get_child_count() - 1, -1, -1):
		var hit: Control = _sample(p_node.get_child(i), p_point)
		if hit != null:
			return hit
	if p_node is Control and _receives(p_node as Control, p_point):
		return p_node as Control
	return null


## 控件是否认领该视口坐标（树内可见 + mouse_filter 非 IGNORE + 矩形包含）。[br]
## [br][b]必须用 [method CanvasItem.is_visible_in_tree][/b]：面板隐藏时其子控件的
## [code]visible[/code] 仍是 true（本地标志），只看它会得出「隐藏面板把整屏挡住」的
## 假结论——引擎自己的拾取走的是树内可见性。
func _receives(p_control: Control, p_point: Vector2) -> bool:
	if not p_control.is_visible_in_tree() \
			or p_control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		return false
	var local: Vector2 = p_control.get_global_transform_with_canvas() \
			.affine_inverse() * p_point
	return Rect2(Vector2.ZERO, p_control.size).has_point(local)


func _root() -> Variant:
	return _root_provider.call() if _root_provider.is_valid() else null


## 战斗场景容器（战场根的父级——[code]bag_mount[/code] / 注入句柄挂在它身上）。
func _scene() -> Control:
	var root: Variant = _root()
	return (root as Node).get_parent() as Control if root != null else null


func _combat() -> Node:
	var s: Control = _scene()
	return s.get("combat_system") as Node if s != null else null


## 出牌手势层（全屏输入节点——它的层级位置正是本轮缺陷的现场）。
func input_layer() -> Node:
	var root: Variant = _root()
	if root == null:
		return null
	var interaction: Variant = (root as Object).call(&"interaction")
	if interaction == null or not (interaction as Object).has_method(&"get_input_layer"):
		return null
	return (interaction as Object).call(&"get_input_layer") as Node
