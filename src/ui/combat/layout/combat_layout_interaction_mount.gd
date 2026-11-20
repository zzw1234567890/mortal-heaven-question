extends RefCounted
## CombatLayoutInteractionMount —— 出牌交互层的装配（combat_layout 拆分模块·交互组）。
##
## [b]职责[/b]：实例化 [code]CombatInputLayer[/code]（鼠标手势 → 出牌请求）与
## [code]CombatHintToast[/code]（拒绝提示条），把两者接到战场门面与装配台上；
## 同时作为输入节点的「门面适配器」——输入节点只认本模块的同形状方法
## （见 [method play_controller] / [method enemy_at] …），不必知道门面拆了几层。[br]
## [br][b]挂载次序[/b]：提示条在输入层之后创建（提示条绘制在输入层之上），但两者都在
## 备战 / 结算覆盖层之前——覆盖层打开时由上层 [method set_input_enabled] 关掉输入。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不持有手牌 / HP / 阶段，全部转发现读。
##
## 来源: combat-ui-interaction Story 001（出牌手势 + 目标点选）、ADR-0004、ADR-0031。

## 输入层（鼠标手势归一出牌请求）。
const InputLayerScript: GDScript = preload(
		"res://src/ui/combat/interaction/combat_input_layer.gd")
## 提示条（拒绝文案的显示端）。
const ToastScript: GDScript = preload(
		"res://src/ui/combat/interaction/combat_hint_toast.gd")

## 宿主布局根（两个节点挂在这里）。
var _layout: Control = null
## 装配挂载模块（取施法者 / 命中测试 / 手牌快照）。
var _assembly: RefCounted = null
## 输入层实例。
var input_layer: Variant = null
## 提示条实例。
var toast: Variant = null


## 构造——传入宿主布局根与装配模块。
func _init(p_layout: Control, p_assembly: RefCounted) -> void:
	_layout = p_layout
	_assembly = p_assembly


## 构建并接线（[code]_init[/code] 之后由主类在装配完成后调用）。[br]
## [br][b]节点次序[/b]：输入层压在角色卡之上、[b]压在底部条与右上角按钮位之下[/b]
## （见 [method _place_in_tree]）；覆盖层打开时由上层 [method set_input_enabled] 关掉输入。[br]
## [b]选中视觉[/b]：控制器 [code]selection_changed[/code] → 手牌区抬起/描边——
## 选中态在真实对局里第一次有视觉落点。
func build() -> void:
	toast = ToastScript.new()
	toast.name = "CombatHintToast"
	_layout.add_child(toast)
	input_layer = InputLayerScript.new()
	input_layer.name = "CombatInputLayer"
	_layout.add_child(input_layer)
	_place_in_tree()
	input_layer.call(&"setup", self, Callable(toast, &"show_message"))
	_connect_selection()

## 设置减少动态（提示条淡出改瞬时）。
func set_reduce_motion(p_reduce_motion: bool) -> void:
	if toast != null:
		toast.call(&"set_reduce_motion", p_reduce_motion)


## 启用 / 停用输入（模态面板打开时关掉，避免点穿）。
func set_input_enabled(p_enabled: bool) -> void:
	if input_layer != null:
		input_layer.call(&"set_enabled", p_enabled)


## 输入层实例（交互层 / 场景接线与测试直接驱动手势用；未装配为 null）。
func get_input_layer() -> Variant:
	return input_layer


## 提示条实例（未装配为 null）。
func get_toast() -> Variant:
	return toast


## 隐藏提示（取消选中 / 场景退场）。
func clear_hint() -> void:
	if toast != null:
		toast.call(&"clear")


# === 输入层的门面适配（同形状方法——输入节点只认这几个）=====================

## 出牌闭环控制器（选中 → 目标 → 确认）。
func play_controller() -> RefCounted:
	return _assembly.call(&"play_controller")


## 手牌区（命中测试取卡用）。
func hand_area() -> Variant:
	return _layout.get(&"hand_area")


## 全局坐标 → 敌方角色 ID（无命中 -1）。
func enemy_at(p_global_pos: Vector2) -> int:
	return int(_assembly.call(&"enemy_at", p_global_pos))


## 全局坐标 → 我方角色 ID（无命中 -1）。
func ally_at(p_global_pos: Vector2) -> int:
	return int(_assembly.call(&"ally_at", p_global_pos))


## 切换当前操作角色（施法者）。
func select_actor(p_character_id: int) -> bool:
	return bool(_assembly.call(&"select_actor", p_character_id))


## 手牌快照（卡面目标词的来源——与手牌区同一份）。
func hand_snapshot() -> Array:
	return _assembly.call(&"hand_snapshot")


## 当前战斗阶段（-1 = 战斗系统不可用）。
func current_phase() -> int:
	return int(_assembly.call(&"current_phase"))


## 当前操作角色 ID（无角色 -1）。
func current_actor_id() -> int:
	return int(_assembly.call(&"current_actor_id"))


## 敌方候选池（顺序即建卡顺序）。
func enemy_candidates() -> Array:
	return _assembly.call(&"enemy_candidates")


## 当前施法者 ID（出牌桥口径——「当前操作角色」判不出时回退阵位首位）。
func current_caster_id() -> int:
	return int(_assembly.call(&"current_caster_id"))


## 可切换的我方角色 ID（候选）。
func actor_candidates() -> Array:
	return _assembly.call(&"actor_candidates")


## 出牌请求（带拒绝原因）——交互层与测试统一走本入口。
func play_card_detailed(p_card_instance_id: int,
		p_target_indices: Array) -> Dictionary:
	return _assembly.call(&"play_card_detailed", p_card_instance_id,
			p_target_indices)


## === 内部 =====================================================================

## 把提示条与输入层放到该在的层级。[br]
## [br][b]输入层压在哪、谁压着它[/b]（两个方向都错不得，2026-11-19 修复）：[br]
##   · [b]要压住[/b]：敌我角色卡与手牌区——手势要能在战场任意位置起手，
##     而角色卡是画在区域里的 [code]Control[/code]；[br]
##   · [b]要被压住[/b]：底部条的「结束出牌」「行囊」与右上角「撤退」按钮位
##     ——输入层是全屏 [code]MOUSE_FILTER_STOP[/code]，排在这三处之上就把它们
##     整片吃掉（玩家看得见按钮却点不动，界面上没有任何线索说明为什么）。[br]
## [br]落点因此是「紧随第四区、排在 BottomBar 之前」，而不是「挪到覆盖层之前」
## ——后者看起来只让开了面板，实际把底部条整条盖住了。[br]
## [br][b]顶栏也要抬到输入层之上[/b]（2026-11-30 修复）：顶栏是[b]区域 0[/b]，
## 排在输入层之下——于是整条顶栏（战斗日志入口、暂停按钮位）的鼠标事件全被
## 手势层吃掉。实测探针（[code]tools/probe_log_focus_modes.gd[/code] 同类）：
## 点折叠按钮中心采到的命中控件是 [code]CombatInputLayer[/code]。
## 这与底部条是同一个病：可见、可点、没反应。修法是把 TopBar 移到输入层之后
## ——顶栏与战场区域在屏幕上不重叠，「谁盖谁」只影响顶栏内的控件，不影响手势。[br]
## [br][b]覆盖层（备战 / 结算 / 行囊）始终在最后[/b]：它们自带的遮罩会挡住输入层，
## 再由上层 [method set_input_enabled] 关掉手势，两层保障。
func _place_in_tree() -> void:
	if toast == null or input_layer == null:
		return
	var anchor: Node = _layout.get_node_or_null(NodePath("BottomBar"))
	var base: int = anchor.get_index() if anchor != null else _layout.get_child_count()
	_layout.move_child(toast, base)
	_layout.move_child(input_layer, base + 1)
	_lift_topbar()


## 把顶栏抬到输入层之上（顶栏在输入层之下时，其内控件收不到鼠标）。[br]
## [br][b]为什么不是「缩小输入层矩形」[/b]：输入层要覆盖敌我区与手牌区，
## 顶栏在两者之上、底栏在两者之下，单靠矩形避让会把顶栏与敌我区的边界
## 变成一条谁都不认领的缝——手势在缝里起手会被静默丢弃。[br]
## [br][b]落点：覆盖层之前、手牌区之后[/b]——三个约束同时满足：[br]
##   · 在输入层之后（顶栏内的按钮收得到鼠标）；[br]
##   · 在手牌区之后（日志面板展开时盖在手牌区上方——GDD §11 的「覆盖在手牌区
##     上方」；排在 HandArea 之前会被手牌画在身上）；[br]
##   · 在覆盖层之前（备战 / 结算 / 行囊面板打开时要盖住顶栏）。
func _lift_topbar() -> void:
	var top: Node = _layout.get_node_or_null(NodePath("TopBar"))
	if top == null or top == input_layer:
		return
	var target: int = _overlay_base()
	if target < 0:
		target = _layout.get_child_count()
	_layout.move_child(top, target)


## 第一个覆盖层的下标（无覆盖层时 -1）。[br]
## [br][b]为什么按名找而不是记句柄[/b]：覆盖层由各自的挂载模块建（本模块不持它们），
## 名字是它们钉住的稳定契约（同 [code]CombatFocusSweeper.OVERLAY_NAMES[/code] 口径）。
func _overlay_base() -> int:
	for overlay_name: String in ["CombatFeedback", "ActorStage", "DeployPanel",
			"SettlementHost"]:
		var node: Node = _layout.get_node_or_null(NodePath(overlay_name))
		if node != null:
			return node.get_index()
	return -1


## 控制器选中变化 → 手牌区落视觉（抬起 + 描边）。
func _connect_selection() -> void:
	var controller: RefCounted = play_controller()
	if controller == null or not controller.has_signal(&"selection_changed"):
		return
	controller.connect(&"selection_changed", func(card_instance_id: int) -> void:
		var hand: Variant = hand_area()
		if hand != null and is_instance_valid(hand):
			hand.call(&"apply_selection", card_instance_id))
