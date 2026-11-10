class_name NodeInteractionPopupHost
extends Control
## NodeInteractionPopupHost —— 节点交互弹窗宿主（exploration-ui Story 006）。
##
## [b]职责[/b]：消费屏幕层的 [code]node_interaction_forwarded[/code] 与
## [code]combat_arrival_forwarded[/code]，按 GDD §4c 分发表打开对应弹窗，并在
## 确认时调用探索系统 API 或请求场景切换。[br]
## [br][b]与舞台的边界[/b]：冻结/解冻、遮罩、定位、弹窗构建与 ESC 兜底全部委托
## [NodePopupStage]——宿主只管「开哪个弹窗、派发什么」，舞台只管「怎么显示、
## 期间锁什么」。背景模糊由 [NodePopupBlurMask] 承载。[br]
## [br][b]与服务面的边界[/b]：灵泉/回复点 API、SceneManager 转场、RealmSystem
## 只读查询、渡劫判定全部委托 [NodePopupServices]——宿主不再持有这些系统的
## 枚举与表结构。[br]
## [br][b]与遭遇契约的边界[/b]：节点遭遇的读取（快照 → 规范化）与名册拷贝走
## [code]EncounterFields[/code]——与 DAG 生成器、开战上下文同一实现。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不缓存节点/AP/HP；弹窗每次按信号
## 载荷重建文案，确认动作只发信号或调系统 API（不写 GSM）。[br]
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
## 遭遇字段契约（弹窗与开战上下文读同一份节点数据）。
const Fields := preload("res://assets/enemies/encounter_fields.gd")
## 冻结 / 遮罩 / 定位（本宿主的「舞台」半区）。
const StageScript := preload("res://src/ui/exploration/node_popup_stage.gd")
## 外部服务面（探索 API / 转场 / 境界查询 / 渡劫判定）。
const ServicesScript := preload("res://src/ui/exploration/node_popup_services.gd")
## SceneManager 枚举真理来源（preload 避免 headless 下的全局名解析问题）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
## 探索→战斗开战上下文构建（跨场景传递——战斗场景据此重建敌方阵容）。
const LaunchRequestScript := preload("res://src/ui/exploration/combat_launch_request.gd")

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
## 当前战斗节点的规范化遭遇配置（弹窗正文 + 开战上下文共用）。
var _pending_encounter: Dictionary = {}
## 当前战斗弹窗的敌方名册载荷（确认时折进开战上下文）。
var _pending_combat_roster: Array = []
## 玩家出战阵容提供者（[code]func() -> Array[/code]；空 = 读 GSM deck.slots）。
## 测试注入点——生产路径走 Autoload 现读，UI 不缓存名册。
var player_roster_provider: Callable = Callable()
## 当前弹窗的商店库存载荷（确认时随 [signal shop_opened] 回传）。
var _shop_inventory: Dictionary = {}
## 渲染快照（节点详情——渡劫台 [code]tribulation_ready[/code] 判定来源；
## 由屏幕层 [method apply_snapshot] 注入，本宿主只读不写）。
var _snapshot: Dictionary = {}
## 舞台（冻结 / 遮罩 / 定位）。
var _stage: RefCounted = null
## 外部服务面（探索 API / 转场 / 境界 / 渡劫）。
var _services_ref: RefCounted = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_unhandled_key_input(true)
	_stage_ref().call(&"build_mask")


## 注入依赖（宿主挂载时调用；可重复调用——幂等）。
func setup(p_renderer: Control, p_viewport: Control, p_system: Node,
		p_scene_manager: Node = null, p_realm_system: Node = null) -> void:
	renderer = p_renderer
	viewport = p_viewport
	exploration_system = p_system
	scene_manager = p_scene_manager
	realm_system = p_realm_system
	_stage_ref()  # 依赖刚变——舞台按新 renderer/viewport 重新绑定


## 设置动画偏好（reduce_motion 直跳终态）。
func set_reduce_motion(value: bool) -> void:
	reduce_motion = value
	var popup: Control = _popup()
	if popup != null:
		popup.reduce_motion = value


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
	if kind == Rules.KIND_TRIBULATION and not bool(_services().call(
			&"tribulation_ready", _snapshot, node_id)):
		# AC-7：修为未满 → 无弹窗（节点渲染层已显示「修为尚未圆满」）
		return
	var lines: Array = []
	var warning: Array = []
	var combat_type: StringName = &"combat"
	match kind:
		Rules.KIND_COMBAT:
			combat_type = interaction_type
			_pending_combat_roster = Fields.roster_copy(payload.get("enemy_roster", []))
			_pending_encounter = Fields.of_snapshot(_snapshot, node_id)
			lines = Rules.combat_lines_for_encounter(_pending_encounter,
					_pending_combat_roster, _max_deploy(),
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
	_pending_combat_roster = Fields.roster_copy(enemy_roster)
	var node_id: int = int(_snapshot.get("current_node", -1))
	_pending_encounter = Fields.of_snapshot(_snapshot, node_id)
	var lines: Array = Rules.combat_lines_for_encounter(_pending_encounter,
			_pending_combat_roster, _max_deploy())
	_show(node_id, Rules.KIND_COMBAT, lines, [], combat_type)


## 注入渲染快照（屏幕层 map_generated / node_moved 时下发——只读副本，
## 渡劫台 AC-7 判定、弹窗锚定坐标与遭遇数据的来源）。
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
	_stage_ref().call(&"present", popup, kind, lines, warning, node_id)
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
	_stage_ref().call(&"dismiss", popup)
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
			_publish_launch_context(node_id)
			combat_entry_requested.emit(_pending_combat_type)
			_services().call(&"request_scene_change", scene_manager,
					SceneManagerScript.SceneID.COMBAT,
					SceneManagerScript.TransitionType.EXPLORE_TO_COMBAT)
		Rules.KIND_SHOP:
			shop_opened.emit(node_id, _shop_inventory)
		Rules.KIND_SPRING:
			spring_used.emit(node_id, _services().call(&"use_spring",
					exploration_system, node_id))
		Rules.KIND_REST:
			rest_used.emit(node_id, _services().call(&"rest_party",
					exploration_system, node_id))
		Rules.KIND_TRIBULATION:
			tribulation_requested.emit(node_id)
			_services().call(&"request_scene_change", scene_manager,
					SceneManagerScript.SceneID.TRIBULATION,
					SceneManagerScript.TransitionType.TRIBULATION)
	close_popup()


## 发布探索→战斗的开战上下文（构建与发布委托 [code]combat_launch_request.gd[/code]）。[br]
## [br][b]为什么在确认时发布[/b]：场景切换会释放本场景，上下文必须在请求转场
## [b]之前[/b]落盘到跨场景缓存；战斗场景 [code]_ready[/code] 一次性取走。
## 节点详情取渲染快照 [code]nodes[node_id][/code]（含生成器写入的 encounter 契约）。
func _publish_launch_context(node_id: int) -> void:
	var request: RefCounted = LaunchRequestScript.new()
	request.set(&"player_roster_provider", player_roster_provider)
	request.call(&"publish", node_id, _pending_combat_type, _pending_combat_roster,
			_snapshot, get_node_or_null(NodePath("/root/AISystem")))


## 外部服务面（探索 API / 转场 / 境界查询 / 渡劫判定）。
func _services() -> RefCounted:
	if _services_ref == null:
		_services_ref = ServicesScript.new()
	return _services_ref


## 当前境界上场人数上限（只读查询——UI 不推算境界数值）。
func _max_deploy() -> int:
	return int(_services().call(&"max_deploy", realm_system, realm_id, self))


## 舞台实例（惰性单例——冻结/遮罩/定位委托 [NodePopupStage]）。[br]
## 每次都按当前 [member renderer] / [member viewport] 重绑：`_ready` 先于
## [method setup] 执行，测试也可能在挂载后才注入依赖。
func _stage_ref() -> RefCounted:
	if _stage == null:
		_stage = StageScript.new()
	_stage.call(&"bind", self, renderer, viewport)
	return _stage


## 弹窗实例（惰性构建归舞台——控件树只建一次；信号连接留在宿主）。
func _popup() -> Control:
	var popup: Control = _stage_ref().call(&"popup", PopupScript, reduce_motion)
	if popup == null:
		return null
	if not popup.confirmed.is_connected(_on_confirmed):
		popup.confirmed.connect(_on_confirmed)
	if not popup.cancelled.is_connected(close_popup):
		popup.cancelled.connect(close_popup)
	return popup


func _unhandled_key_input(event: InputEvent) -> void:
	if bool(_stage_ref().call(&"handle_escape", event, close_popup)):
		accept_event()
