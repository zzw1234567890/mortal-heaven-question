class_name CombatInputLayer
extends Control
## CombatInputLayer —— 战斗出牌的真实输入路径（combat-ui-interaction 001 / 本轮）。
##
## [b]职责[/b]：把鼠标事件变成出牌请求——[br]
##   1. 按下手牌：[code]press[/code] 记卡与位置；[br]
##   2. 移动 ≥8px（[constant CombatDragRules.DRAG_THRESHOLD]）→ 进入拖拽；[br]
##   3. 释放：<8px 视为[b]点击[/b]（点卡 = 选中 / 再点同一张 = 确认；点敌方 = 选目标）；
##      越过阈值视为[b]拖拽[/b]（释放到敌方目标 = 出牌；释放到空白 = 取消）；[br]
##   4. 点我方角色卡 = 切换当前操作角色（施法者）；[br]
##   5. 被拒 → 调 [code]hint_printer[/code] 显示提示（费用不足等）。[br]
## [br][b]为什么单独成节点[/b]：手势语义归 [code]CombatPlayFlow[/code]（纯类），
## 事件归一与命中测试归这里；[code]CombatLayout[/code] 只负责把它挂上。
## 这样「真实对局里有 InputEvent 驱动出牌」这条边界由本节点单一收口。[br]
## [br][b]输入锁[/b]（ADR-0004）：入口先问 [code]InputManager.is_input_allowed(
## GAMEPLAY, MOUSE)[/code]——阶段 4/5 等动画锁期间不响应（同既有交互契约）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不缓存手牌 / HP / 阶段，每次都问门面；
## 按压状态是瞬态交互状态（§2.1 豁免）。[br][b]零轮询[/b]：无 [code]_process()[/code]。
##
## @experimental
## 来源: ADR-0004（路径 C：鼠标走 [code]_gui_input[/code] 并过锁栈）、ADR-0031、
## design/gdd/combat-ui-system.md §手牌交互、combat-ui-interaction story-003。

## 出牌手势语义（点/拖、单/多、确认时机——禁止内联）。
const FlowScript := preload("res://src/ui/combat/shared/combat_play_flow.gd")
## 按压/拖拽状态机（8px 阈值的落点）。
const GestureScript := preload("res://src/ui/combat/interaction/combat_gesture_model.gd")
## 手势数据供给（目标词 / 可负担 / 敌方命中）。
const ProviderScript := preload("res://src/ui/combat/interaction/combat_play_provider.gd")
## 结果字典工具（判成功 / 取提示文本）。
const PlayResultScript := preload("res://src/feature/combat/combat_play_result.gd")
## 阶段常量（出牌阶段——手势准入判据）。
const PLAY_PHASE: int = 2

## 非出牌阶段的提示文案（敌方行动 / 攻击结算期间玩家点了手牌时显示）。[br]
## [br][b]为什么写在这里而不是 [code]CombatPlayResult[/code][/b]：那份文案表是
## 「出牌被系统拒绝」的原因映射（费用不足 / 目标非法…），本提示是[b]手势根本没提交[/b]
## 的说明——两者不是同一类事件，混进去会让「出牌结果」表混入非出牌结果。
const NOT_PLAY_PHASE_HINT: String = "当前阶段不能出牌，请等待你的回合"

## 门面（需实现 current_caster_id / select_actor / enemy_at / ally_at /
## hand_snapshot / play_controller 等同形状方法）。
var _layout: Variant = null
## 出牌闭环控制器。
var _controller: RefCounted = null
## 手势语义。
var _flow: RefCounted = null
## 手势数据供给。
var _provider: RefCounted = null
## 按压状态机。
var _gesture: RefCounted = GestureScript.new()
## 提示回调——[code]func(message: String) -> void[/code]（空则静默）。
var _hint_printer: Callable = Callable()
## 是否启用（场景未就绪 / 面板打开时可由上层关掉）。
var _enabled: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## 注入门面与提示回调。[br]
## [param p_layout] 战场门面（[code]CombatLayout[/code] 或同形状桩）。[br]
## [param p_hint_printer] 提示打印回调（显示「灵力不足」等文本）。
func setup(p_layout: Variant, p_hint_printer: Callable = Callable()) -> void:
	_layout = p_layout
	_hint_printer = p_hint_printer
	_controller = p_layout.call(&"play_controller")
	_provider = ProviderScript.new()
	_provider.call(&"setup", p_layout, _cost_source())
	_flow = FlowScript.new()
	_flow.call(&"setup", _controller, _provider)


## 启用 / 停用输入（模态面板打开时由上层关掉——避免点穿）。
func set_enabled(p_enabled: bool) -> void:
	_enabled = p_enabled
	if not p_enabled:
		_gesture.call(&"cancel")


## 是否启用（测试探针）。
func is_enabled() -> bool:
	return _enabled


## 手势语义实例（测试可直接驱动，不经鼠标事件）。
func get_flow() -> RefCounted:
	return _flow


## 全局坐标 → 命中结果 [code]{card_id, enemy_id, ally_id}[/code]（未命中为 -1）。[br]
## [br][b]优先级[/b]：手牌 > 我方角色 > 敌方角色——手牌在最上层绘制，
## 玩家点到的就是看到的。
func hit_test(p_global_pos: Vector2) -> Dictionary:
	return {
		"card_id": _card_at(p_global_pos),
		"enemy_id": _enemy_at(p_global_pos),
		"ally_id": _ally_at(p_global_pos),
	}


# === 输入事件 =================================================================

func _gui_input(event: InputEvent) -> void:
	if not _enabled or _layout == null:
		return
	if event is InputEventMouseButton:
		_handle_button(event)
	elif event is InputEventMouseMotion:
		_handle_motion(event)


## 鼠标按下 / 释放。
func _handle_button(event: InputEventMouseButton) -> void:
	var button: InputEventMouseButton = event
	if button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			if not _input_allowed():
				return
			# 非出牌阶段（阶段 5 敌方行动等）——不接受任何手势，但要给可读提示：
			# 「点了没反应」正是本轮要消灭的失败形态。
			if not _is_play_phase():
				_hint(NOT_PLAY_PHASE_HINT)
				return
			var hit: Dictionary = hit_test(button.global_position)
			_gesture.call(&"press", int(hit["card_id"]), button.global_position)
			accept_event()
			return
		_release(button.global_position)
		accept_event()
	elif button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		# 右键取消（UX #9：右键/ESC 取消当前选择）
		_gesture.call(&"cancel")
		if _flow != null:
			_flow.call(&"cancel")
		accept_event()


## 鼠标移动——刚越过 8px 阈值时不做额外事（拖拽视觉归后续 story），
## 只把状态机推进到「拖拽中」，释放时据此区分点击/拖拽。
func _handle_motion(event: InputEventMouseMotion) -> void:
	if not bool(_gesture.call(&"is_pressed")):
		return
	_gesture.call(&"move", event.global_position)


## 释放——按状态机结果分流为点击或拖拽。[br]
## [br][b]阶段已离开出牌则整体作废[/b]（GDD §边缘情况「拖拽中阶段切换 → 无效释放」）：
## 按压发生在阶段 2、释放时已是敌方行动——这次手势不能生效，否则玩家能在
## 敌方回合里出一张牌。手势状态机一并复位，避免残留的按压态污染下一次操作。
func _release(p_global_pos: Vector2) -> void:
	if not _is_play_phase():
		_gesture.call(&"cancel")
		return
	var outcome: Dictionary = _gesture.call(&"release")
	var kind: int = int(outcome.get("kind", GestureScript.KIND_NONE))
	var card_id: int = int(outcome.get("card_id", -1))
	if kind == GestureScript.KIND_NONE:
		return
	if kind == GestureScript.KIND_DRAG:
		_act(_flow.call(&"drop", card_id, _enemy_at(p_global_pos)))
		return
	_action_at(p_global_pos, card_id)


## 点击分流：手牌 > 我方角色 > 敌方目标 > 空白。
func _action_at(p_global_pos: Vector2, p_clicked_card: int) -> void:
	var hit: Dictionary = hit_test(p_global_pos)
	if p_clicked_card >= 0:
		_act(_flow.call(&"click_card", p_clicked_card))
		return
	var ally_id: int = int(hit["ally_id"])
	if ally_id >= 0:
		# 点我方角色 = 切换当前操作角色（出牌施法者随之改变）。
		if bool(_layout.call(&"select_actor", ally_id)):
			_hint("%s 开始行动" % _actor_label(ally_id))
		return
	var enemy_id: int = int(hit["enemy_id"])
	if enemy_id >= 0:
		_act(_flow.call(&"click_target", enemy_id))
		return
	# 空白：取消选中（不出牌、不扣费）。
	_flow.call(&"cancel")


## 执行一次手势结果并处理反馈。
func _act(p_outcome: Dictionary) -> void:
	if p_outcome.is_empty():
		return
	var status: StringName = StringName(str(p_outcome.get("status", &"")))
	var result: Dictionary = p_outcome.get("result", {})
	if status == FlowScript.STATUS_REJECTED:
		_show_rejection(result)
	elif status == FlowScript.STATUS_PLAYED:
		_hint("出牌成功")


# === 内部 =====================================================================

## 拒绝 → 显示提示（文案只取 result.message，不自拼）。
func _show_rejection(p_result: Dictionary) -> void:
	var message: String = String(PlayResultScript.message_for(
			StringName(str(p_result.get("reason", &""))),
			p_result.get("context", {})))
	_hint(message)


## 提示回调（未注入 / 空串 → 静默）。
func _hint(p_message: String) -> void:
	if p_message.strip_edges().is_empty() or not _hint_printer.is_valid():
		return
	_hint_printer.call(p_message)


## 输入锁判定（无 InputManager 时放行——桩环境不锁死）。[br]
## [br][b]不再有任何豁免[/b]（DEBT-CBT-018-11 已根治）：战斗系统此前整场持有
## [code]ANIMATION[/code] 锁，为让出牌阶段能收到点击，这里曾开过一条
## 「只剩战斗那把锁 + 阶段 2」的窄口子。现在 [code]CombatSystem[/code] 已把锁
## 收窄到阶段 4/5（进/出配对），严格按锁栈判定即可——豁免连同它的判据
## （[code]_only_battle_animation_lock[/code]）一并删除，少一条需要长期维护的例外。
func _input_allowed() -> bool:
	var im: Node = _autoload(&"InputManager")
	if im == null or not im.has_method(&"is_input_allowed"):
		return true
	return bool(im.call(&"is_input_allowed",
			im.get(&"ActionType").GAMEPLAY, im.get(&"DeviceType").MOUSE))


## 当前是否处于玩家可出牌的阶段（阶段 2）。[br]
## [br][b]与输入锁的分工[/b]：锁管「动画/弹窗期间不许动」，阶段管「这个阶段本来
## 就不是出牌的时候」——敌方行动（阶段 5）即使没有锁也不该接受出牌。[br]
## [br][b]阶段未知（-1）时返回 true[/b]：门面未接线时保持宽松（与
## [code]refresh()[/code] 的「未知即宽松」同口径），否则未接线的调用方会全被拒。
func _is_play_phase() -> bool:
	var phase: int = _current_phase()
	return phase < 0 or phase == PLAY_PHASE


## 当前战斗阶段（门面不可用 → -1）。
func _current_phase() -> int:
	if _layout != null and _layout.has_method(&"current_phase"):
		return int(_layout.call(&"current_phase"))
	return -1


## 费用数据源（CostSystem Autoload——可空）。
func _cost_source() -> Node:
	return _autoload(&"CostSystem")


## 我方角色显示标签（名称管线归叙事层——此处只用 ID 兜底，不臆造名字）。
func _actor_label(p_character_id: int) -> String:
	return "角色 %d" % p_character_id


func _card_at(p_global_pos: Vector2) -> int:
	if _layout == null or not _layout.has_method(&"hand_area"):
		return -1
	var hand: Variant = _layout.call(&"hand_area")
	if hand == null or not (hand as Object).has_method(&"card_instance_id_at"):
		return -1
	return int((hand as Object).call(&"card_instance_id_at", p_global_pos))


func _enemy_at(p_global_pos: Vector2) -> int:
	if _layout != null and _layout.has_method(&"enemy_at"):
		return int(_layout.call(&"enemy_at", p_global_pos))
	return -1


func _ally_at(p_global_pos: Vector2) -> int:
	if _layout != null and _layout.has_method(&"ally_at"):
		return int(_layout.call(&"ally_at", p_global_pos))
	return -1


## Autoload 动态查找（避免测试环境缺 Autoload 时 NameError）。
func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = get_tree()
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
