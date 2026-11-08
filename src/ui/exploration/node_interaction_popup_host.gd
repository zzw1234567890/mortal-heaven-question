class_name NodeInteractionPopupHost
extends Control
## NodeInteractionPopupHost —— 节点交互弹窗宿主（exploration-ui Story 006）。
##
## [b]职责[/b]：消费屏幕层的 [code]node_interaction_forwarded[/code] 与
## [code]combat_arrival_forwarded[/code]，按 GDD §4c 分发表打开对应弹窗；弹窗
## 期间冻结节点图（缩放/平移/点击全部无效——control-manifest Required）、叠加
## 背景模糊遮罩（GDD §4「模糊 40%」）、并在确认时调用探索系统 API 或请求
## 场景切换。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不缓存节点/AP/HP；弹窗每次按信号
## 载荷重建文案，确认动作只发信号或调系统 API（不写 GSM）。[br]
## [br][b]背景模糊[/b]：遮罩由 [NodePopupBlurMask] 承载（BackBufferCopy + 暂停菜单
## 同源着色器），本类只负责挂载、置顶与显隐——z 序为「节点图 < 遮罩 < 弹窗」。[br]
## [br][b]零轮询[/b]（ADR-0031 §3）：无 [code]_process()[/code]——信号与输入驱动；
## 模糊淡入与弹窗开合均为 Tween（纯视觉变换，豁免）。[br]
## [br][b]事件节点显式排除[/b]（GDD §4c + AC-9）：分发表不含 [code]event[/code]，
## [code]event_node_reached[/code] 不经本宿主——本类不连接该信号（防双面板）。[br]
## [br][b]传送节点显式排除[/b]（B5 裁决 + AC-10）：[code]teleport[/code] 不在
## 分发表中，到达后无任何弹窗（按普通节点渲染）。[br]
## [br][b]先移动后弹窗[/b]（B4 裁决）：到达信号由 [NodeMoveInteractor] 在移动
## 动画结束后才转发，本宿主无需额外缓冲。
##
## 来源: design/gdd/exploration-ui-system.md §4/§4b/§4c、ADR-0014 §决策 3、
## ADR-0031 §2/§3、exploration-ui Story 006（AC-1~AC-10）。

const Rules := preload("res://src/ui/exploration/node_interaction_rules.gd")
const PopupScript := preload("res://src/ui/exploration/node_interaction_popup.gd")
## 背景模糊遮罩（BackBufferCopy + pause_blur 着色器——复用暂停菜单同源 shader）。
const BlurMaskScript := preload("res://src/ui/exploration/node_popup_blur_mask.gd")
## SceneManager 枚举真理来源（preload 避免 headless 下的全局名解析问题）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
const RealmSystemScript := preload("res://src/core/realm_system.gd")

## === 信号（宿主/后续 story 消费——本组件不自行完成场景编排）=================

## 确认进入战斗（AC-1 战斗弹窗确认）——[param combat_type] 为 combat/elite。
signal combat_entry_requested(combat_type: StringName)
## 商店 overlay 打开（AC-8——B9 裁决：UI overlay 而非场景切换；内容归商店 epic）。
signal shop_opened(node_id: int, inventory: Dictionary)
## 灵泉已使用（AC-4）——[param restored] 为系统返回的回复量（未实现 API 时为 0）。
signal spring_used(node_id: int, restored: int)
## 回复点已休息（AC-5）——[param healed] 为系统返回的治疗量。
signal rest_used(node_id: int, healed: int)
## 请求进入渡劫（AC-6——SceneManager TRIBULATION 已受理或已发出请求）。
signal tribulation_requested(node_id: int)
## 弹窗开关（观测/analytics；[param kind] 为弹窗种类）。
signal popup_opened(node_id: int, kind: StringName)
signal popup_closed(node_id: int, kind: StringName)

## === 依赖注入（测试可替换）=================================================

## 渲染器（节点中心坐标源——[method NodeGraphRenderer.get_node_position]）。
var renderer: Control = null
## 视口（冻结缩放/平移——[member NodeGraphViewport.input_frozen]）。
var viewport: Control = null
## 探索系统（灵泉/回复 API 调用方；缺失时仅发信号）。
var exploration_system: Node = null
## 场景管理器（战斗/渡劫转场请求；缺失时仅发信号）。
var scene_manager: Node = null
## 境界系统（推荐上场角色数——只读查询，UI 不推算境界数值）。
var realm_system: Node = null
## 当前境界（推荐角色数的上限来源；≤0 时回退 1）。
var realm_id: int = 1
## 减少动态偏好（Tween 直跳终态）。
var reduce_motion: bool = false

## === 状态（瞬态视觉——ADR-0031 §2.1 豁免）=================================

## 当前弹窗节点 ID（-1 = 无弹窗）。
var _open_node_id: int = -1
## 当前弹窗种类。
var _open_kind: StringName = &""
## 当前点击的战斗类型（combat/elite——确认派发时回传）。
var _pending_combat_type: StringName = &"combat"
## 当前弹窗的商店库存载荷（确认时随 [signal shop_opened] 回传）。
var _shop_inventory: Dictionary = {}
## 弹窗实例引用（首用时构建——[method _popup] 的缓存，避免每帧 get_node）。
var _popup_ref: Control = null
## 渲染快照（节点详情——渡劫台 [code]tribulation_ready[/code] 判定来源；
## 由屏幕层 [method apply_snapshot] 注入，本宿主只读不写）。
var _snapshot: Dictionary = {}
## 节点图冻结前的 renderer 鼠标过滤模式（恢复用）。
var _saved_mouse_filter: int = Control.MOUSE_FILTER_STOP
## 冻结前视口 input_frozen 值（恢复用）。
var _saved_viewport_frozen: bool = false
## 是否处于冻结态（幂等守卫——连续到达换弹窗时不得二次保存"已冻结"为原值）。
var _frozen: bool = false
## 背景模糊遮罩实例（[NodePopupBlurMask]；_ready 构建）。
var _mask: Control = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_key_input(true)
	_build_mask()


## 注入依赖（宿主挂载时调用；可重复调用——幂等）。
func setup(p_renderer: Control, p_viewport: Control, p_system: Node,
		p_scene_manager: Node = null, p_realm_system: Node = null) -> void:
	renderer = p_renderer
	viewport = p_viewport
	exploration_system = p_system
	scene_manager = p_scene_manager
	realm_system = p_realm_system


## 设置动画偏好（reduce_motion 直跳终态）。
func set_reduce_motion(value: bool) -> void:
	reduce_motion = value
	if _popup() != null:
		_popup().reduce_motion = value


# ═══════════════════════════════════════════════════════════════════════════════
# 到达消费（AC-1——分发表路由）
# ═══════════════════════════════════════════════════════════════════════════════

## 交互节点到达——按 [param interaction_type] 查分发表开对应弹窗。[br]
## [b]无弹窗类型[/b]（event/teleport/未知）→ 静默忽略（AC-9/AC-10）。
func on_node_interaction(node_id: int, interaction_type: StringName,
		payload: Dictionary = {}) -> void:
	var kind: StringName = Rules.popup_kind_for(interaction_type)
	if kind == Rules.KIND_NONE:
		return
	if kind == Rules.KIND_TRIBULATION and not _tribulation_ready(node_id):
		# AC-7：修为未满 → 无弹窗（节点渲染层已显示「修为尚未圆满」）
		return
	var lines: Array = []
	var warning: Array = []
	var combat_type: StringName = &"combat"
	match kind:
		Rules.KIND_COMBAT:
			combat_type = interaction_type
			lines = Rules.combat_lines(
					payload.get("enemy_roster", []), _max_deploy(),
					int(payload.get("recommended_deploy", 0)))
		Rules.KIND_SHOP:
			_shop_inventory = (payload.get("inventory", {}) as Dictionary).duplicate(true)
		Rules.KIND_TRIBULATION:
			warning = Rules.tribulation_warning_lines()
	_show(node_id, kind, lines, warning, combat_type)


## 战斗节点到达（[code]combat_arrival_forwarded[/code]——与交互分发表同源，
## 战斗/精英节点由 [code]combat_node_reached[/code] 单独派发）。[br]
## [param combat_type]: [code]&"combat"[/code] 或 [code]&"elite"[/code]。
func on_combat_arrival(enemy_roster: Array, combat_type: StringName) -> void:
	var lines: Array = Rules.combat_lines(enemy_roster, _max_deploy())
	_show(int(_snapshot.get("current_node", -1)), Rules.KIND_COMBAT, lines, [],
			combat_type)


## 注入渲染快照（屏幕层 map_generated / node_moved 时下发——只读副本，
## 渡劫台 AC-7 判定与弹窗锚定坐标的来源）。
func apply_snapshot(snapshot: Dictionary) -> void:
	_snapshot = snapshot.duplicate(true)
	if snapshot.has("realm_id"):
		realm_id = int(snapshot.get("realm_id", realm_id))


## 打开弹窗（[param node_id] 为 -1 时居中偏右定位——仍不覆盖全屏）。
func _show(node_id: int, kind: StringName, lines: Array, warning: Array,
		combat_type: StringName = &"combat") -> void:
	var popup: Control = _popup()
	if popup == null:
		return
	_open_node_id = node_id
	_open_kind = kind
	_pending_combat_type = combat_type
	_freeze_graph()
	_show_mask(true)
	popup.open(kind, lines, warning)
	_place_popup(popup, node_id)
	popup_opened.emit(node_id, kind)


## 关闭弹窗（取消路径——AC-3：停留该节点、AP 不回退、无场景切换）。[br]
## [b]幂等[/b]：关闭动画（0.15s）期间 [member _open_kind] 已复位、弹窗仍 visible——
## 以种类而非可见性作守卫，避免重复发 [signal popup_closed]（屏幕层据此恢复键盘路径）。
func close_popup() -> void:
	var popup: Control = _popup()
	if popup == null or _open_kind == Rules.KIND_NONE:
		return
	var closed_node: int = _open_node_id
	var closed_kind: StringName = _open_kind
	_open_node_id = -1
	_open_kind = Rules.KIND_NONE
	popup.play_close()
	_unfreeze_graph()
	_show_mask(false)
	popup_closed.emit(closed_node, closed_kind)


## 是否有弹窗打开（宿主/测试查询）。
func is_popup_open() -> bool:
	var popup: Control = _popup()
	return popup != null and popup.visible


## 当前弹窗种类（无弹窗时为 [constant Rules.KIND_NONE]）。
func get_open_kind() -> StringName:
	return _open_kind


# ═══════════════════════════════════════════════════════════════════════════════
# 确认派发（AC-4/AC-5/AC-6/AC-8）
# ═══════════════════════════════════════════════════════════════════════════════

## 弹窗确认——按 kind 派发（UI 不做数值计算，回复量取系统返回值）。
func _on_confirmed() -> void:
	var node_id: int = _open_node_id
	match _open_kind:
		Rules.KIND_COMBAT:
			combat_entry_requested.emit(_pending_combat_type)
			_request_scene_change(SceneManagerScript.SceneID.COMBAT,
					SceneManagerScript.TransitionType.EXPLORE_TO_COMBAT)
		Rules.KIND_SHOP:
			shop_opened.emit(node_id, _shop_inventory)
		Rules.KIND_SPRING:
			spring_used.emit(node_id, _use_spring(node_id))
		Rules.KIND_REST:
			rest_used.emit(node_id, _rest_party(node_id))
		Rules.KIND_TRIBULATION:
			tribulation_requested.emit(node_id)
			_request_scene_change(SceneManagerScript.SceneID.TRIBULATION,
					SceneManagerScript.TransitionType.TRIBULATION)
	close_popup()


## 灵泉——调用探索系统 API（效果执行归 Feature 层），返回系统给出的回复量。
func _use_spring(node_id: int) -> int:
	if exploration_system == null:
		return 0
	if exploration_system.has_method(&"use_action_spring"):
		return int(exploration_system.call(&"use_action_spring", node_id))
	# Feature 层 API 未实现（story Out of Scope：效果执行归探索系统域）
	push_warning("NodeInteractionPopupHost: 探索系统缺少 use_action_spring()——灵泉效果未执行")
	return 0


## 回复点——调用探索系统 API，返回系统给出的治疗量。
func _rest_party(node_id: int) -> int:
	if exploration_system == null:
		return 0
	if exploration_system.has_method(&"rest_at_node"):
		return int(exploration_system.call(&"rest_at_node", node_id))
	push_warning("NodeInteractionPopupHost: 探索系统缺少 rest_at_node()——回复点效果未执行")
	return 0


## 请求场景切换（[b]唯一入口[/b]——control-manifest Required：禁止直调
## [code]change_scene_to_file[/code]）。scene_manager 缺失时仅发信号。
func _request_scene_change(to_scene: int, transition: int) -> void:
	if scene_manager != null and scene_manager.has_method(&"request_scene_change"):
		scene_manager.call(&"request_scene_change",
				SceneManagerScript.SceneID.EXPLORATION, to_scene, transition)


# ═══════════════════════════════════════════════════════════════════════════════
# 冻结 / 模糊
# ═══════════════════════════════════════════════════════════════════════════════

## 冻结节点图——视口 input_frozen + renderer 鼠标过滤（点击/悬停/缩放/平移全失效）。[br]
## [b]幂等[/b]：弹窗未关就换下一类（连续到达）时会二次调用——若不判 [member _frozen]，
## 第二次会把「已冻结」当作原件保存，关闭后永远解不开冻。
func _freeze_graph() -> void:
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
func _unfreeze_graph() -> void:
	if not _frozen:
		return
	_frozen = false
	if viewport != null and (&"input_frozen" in viewport):
		viewport.set(&"input_frozen", _saved_viewport_frozen)
	if renderer != null:
		renderer.mouse_filter = _saved_mouse_filter


## 定位弹窗到节点附近（renderer 画布坐标 → 屏幕坐标 → 夹入视口）。
func _place_popup(popup: Control, node_id: int) -> void:
	var host_size: Vector2 = size
	var popup_size: Vector2 = Rules.POPUP_SIZE
	if renderer == null or node_id < 0:
		# 无节点锚点（战斗到达）——居中偏右，仍不覆盖全屏
		popup.position = Rules.popup_position(host_size * 0.5, popup_size, host_size)
		return
	var world: Vector2 = renderer.get_node_position(node_id)
	var zoom: float = 1.0
	var offset: Vector2 = Vector2.ZERO
	if viewport != null:
		zoom = float(viewport.get(&"zoom")) if (&"zoom" in viewport) else 1.0
		offset = viewport.get(&"offset") if (&"offset" in viewport) else Vector2.ZERO
	var anchor: Vector2 = world * zoom + offset
	popup.position = Rules.popup_position(anchor, popup_size, host_size)


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_popup_open():
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		close_popup()
		accept_event()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 弹窗实例（首用时构建——控件树只建一次）。
func _popup() -> Control:
	if _popup_ref != null and is_instance_valid(_popup_ref):
		return _popup_ref
	var popup: Control = PopupScript.new()
	add_child(popup)
	popup.confirmed.connect(_on_confirmed)
	popup.cancelled.connect(close_popup)
	popup.reduce_motion = reduce_motion
	_popup_ref = popup
	return popup


## 背景模糊遮罩构建（组件化——[NodePopupBlurMask] 持有 BackBufferCopy + 着色器；
## 本宿主只负责挂载与置顶层级）。GDD §4「模糊 40%」。
func _build_mask() -> void:
	_mask = BlurMaskScript.new()
	add_child(_mask)
	_mask.move_to_front()


## 遮罩显隐——先亮遮罩并置顶，再把弹窗提到遮罩之上（z 序：节点图 < 遮罩 < 弹窗）。
func _show_mask(show_it: bool) -> void:
	if _mask == null or not is_instance_valid(_mask):
		return
	_mask.show_blur(show_it)
	if show_it:
		_mask.move_to_front()
		var popup: Control = _popup()
		if popup != null:
			popup.move_to_front()


## 当前境界上场人数上限（RealmSystem 只读查询；UI 不推算境界数值）。
func _max_deploy() -> int:
	var rs: Node = realm_system
	if rs == null:
		rs = get_node_or_null(NodePath("/root/RealmSystem"))
	if rs != null and rs.has_method(&"get_realm_property"):
		var value: Variant = rs.call(&"get_realm_property", realm_id, &"max_deploy")
		if value != null:
			return int(value)
	return int((RealmSystemScript.realm_table.get(realm_id, {}) as Dictionary)
			.get("max_deploy", 1))


## 渡劫台是否修为圆满——“修为未满不弹窗”（AC-7）。[br]
## [b]数据源[/b]：注入的渲染快照 nodes[node_id].tribulation_ready；快照缺失或
## 字段缺失时宽松视为圆满（详细判定归渲染层 [NodeStateLogic.is_tribulation_not_ready]）。
func _tribulation_ready(node_id: int) -> bool:
	var nodes: Dictionary = _snapshot.get("nodes", {})
	var detail: Dictionary = nodes.get(node_id, {})
	return Rules.tribulation_ready(detail)
