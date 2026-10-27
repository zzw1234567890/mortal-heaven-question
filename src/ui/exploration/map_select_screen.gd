class_name MapSelectScreen
extends Control
## MapSelectScreen —— 地图选择界面（exploration-ui Story S16-2）。
##
## [b]节点形态[/b]（ADR-0031 §1）：场景内 Control 树（零新增 Autoload），
## 挂载于 [code]res://src/feature/exploration/exploration_scene.tscn[/code]
## 薄容器（本 story 落盘，闭合 SCENE_PATHS EXPLORATION 占位）。[br]
## [br][b]结构[/b]：标题 + 顶部灵石余额 + 横向滚动卡片列表（ScrollContainer
## + HBoxContainer，MapCard 动态构建）+ 重入确认弹窗（ConfirmationDialog）。[br]
## [br][b]Logic 内核[/b]（BLOCKING 单测目标）：[method should_show_lock] /
## [method is_reenterable] / [method can_confirm_reentry] /
## [method unlock_requirement_text] 四个 static 纯函数（场景脚本内定义、static
## 暴露供 GUT 直调——S16-1 先例）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：灵石余额经
## [code]ResourceSystem.get_resource(&"ling_shi")[/code] 只读 + GSM
## [signal resource_changed] 刷新；地图列表经 [code]get_map_list()[/code] 按需
## 读取（Feature 层未实现时回退 stub）；UI 绝不写 GSM、绝不自行扣灵石。[br]
## [br][b]重入流[/b]：UI 仅发意图（点击确认 → 记录待重入 map_id + 发
## [signal reentry_requested]），扣费与拒绝信号归探索系统（Feature 层补齐后
## 替换 stub）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]。
##
## @experimental
## 来源: ADR-0031、ADR-0014 §get_map_list 契约、control-manifest §Presentation、
## design/gdd/exploration-ui-system.md §1/§6、story-002-map-select-screen.md。

## === 视觉常量（数据驱动）====================================================

## 卡片入场逐张飞入时长（秒）——0.3s/张（B7 裁决）。
const CARD_ANIM_DURATION: float = 0.3
## 每张卡片飞入错峰间隔（秒）。
const CARD_ANIM_STAGGER: float = 0.08
## 卡片尺寸（B7 裁决）——MapCard 内部也声明，主界面用于滚动容器预估算。
const CARD_SIZE: Vector2 = Vector2(360, 420)

## 固定 UI 词条（项目暂无本地化系统——S16-1 TEXT_* 同源豁免注记）。
const TEXT_TITLE: String = "选择地图"
## 顶部灵石余额前缀（AC-8——GDD 布局「灵石: 125」格式，不复用 TEXT_TITLE
## 避免与左上角标题文字重复，code-review Required #1）。
const TEXT_BALANCE_PREFIX: String = "灵石"
const TEXT_REENTRY_DIALOG_TITLE: String = "重入地图"
const TEXT_REENTRY_CONFIRM: String = "确认传送"
const TEXT_REENTRY_CANCEL: String = "取消"
const TEXT_COST_DETAIL: String = "传送费用：%d灵石（基础价 %d × 倍率 %d）"
const TEXT_CURRENT_BALANCE: String = "当前灵石：%d"
const TEXT_INSUFFICIENT: String = "灵石不足"
const TEXT_CONFIRM_WARN: String = "重入地图将消耗%d灵石并生成新的节点图"
const TEXT_MAP_LINE: String = "地图：%s（已通关）"
## 手柄 LB/RB 单次滚动步长（像素）——AC-9 三路径之一（数据驱动，非魔数）。
const SCROLL_STEP: int = 128

## InputManager 脚本常量——ActionType/DeviceType 枚举真理来源。
const InputManagerScript := preload("res://src/foundation/input_manager.gd")
## MapCard 脚本常量——动态构建卡片用（class_name 在动态加载下不可靠）。
const MapCardScript := preload("res://src/ui/exploration/map_card.gd")
## MapDataStub 脚本常量——stub 载荷数据源（Feature 层补齐后删除本引用）。
const MapDataStubScript := preload("res://src/ui/exploration/map_data_stub.gd")

## === 依赖注入（测试可替换）=====================================================

## 探索系统引用——get_map_list 数据源（null 时回退 Autoload / stub）。
var exploration_system: Node = null
## 资源系统引用——灵石余额只读（null 时回退 Autoload）。
var resource_system: Node = null
## 动画开关——测试注入 + reduce-motion 预留接线点（S16-1 先例）。
var animate: bool = true

## === 瞬态交互状态（ADR-0031 §2.1）=============================================

## 待重入地图 ID（重入确认弹窗打开期间）——场景内瞬态状态，不进存档。
var _pending_reentry_id: StringName = &""

## 入场 Tween 句柄（新请求时 kill 防悬挂）。
var _intro_tween: Tween = null

## === 信号 ======================================================================

## 进入地图意图——未通关+境界达标路径（0 灵石直接进入）。[param map_id] 目标。
## 节点图加载归 story 003，本 story 只发意图。
signal enter_map_requested(map_id: StringName)
## 重入地图意图——已通关重入确认后。[param map_id] 目标（扣费/拒绝归探索系统）。
signal reentry_requested(map_id: StringName)

## === 节点引用 ==================================================================

@onready var title_label: Label = $LayoutAnchor/TitleLabel
@onready var balance_label: Label = $LayoutAnchor/BalanceLabel
@onready var scroll: ScrollContainer = $LayoutAnchor/ScrollContainer
@onready var card_row: HBoxContainer = $LayoutAnchor/ScrollContainer/CardRow
@onready var reentry_dialog: ConfirmationDialog = $ReentryDialog
@onready var reentry_map_label: Label = $ReentryDialog/VBox/MapLineLabel
@onready var reentry_cost_label: Label = $ReentryDialog/VBox/CostDetailLabel
@onready var reentry_balance_label: Label = $ReentryDialog/VBox/BalanceLabel
@onready var reentry_warn_label: Label = $ReentryDialog/VBox/WarnLabel
@onready var reentry_confirm_button: Button = $ReentryDialog.get_ok_button()

## === Logic 内核（static 纯函数——BLOCKING 单测目标）===========================

## 卡片点击分流决策枚举——[method entry_action] 返回值。
enum EntryAction {
	IGNORE = 0,  ## 无操作（锁定卡 / 已通关不可重入）
	REENTER = 1, ## 弹重入确认窗（已通关可重入）
	ENTER = 2,   ## 直接进入（未通关 + 境界达标）
}


## 卡片点击分流决策（AC-3/AC-5/AC-7）。[br]
## [b]返回[/b]: [enum EntryAction] 三态——锁定卡 → IGNORE；已通关可重入 →
## REENTER；已通关不可重入（苍玄古战场）→ IGNORE（与未通关区分，
## QA-S16-2-001 回归目标）；未通关 → ENTER。[br]
## 纯函数——无状态、无 Autoload 访问（提取分流决策供 GUT 直调，
## [method _on_card_activated] 消费本函数，路由缺陷可单测捕获）。
static func entry_action(entry: Dictionary) -> int:
	if should_show_lock(entry):
		return EntryAction.IGNORE
	if bool(entry.get(&"is_cleared", false)):
		return EntryAction.REENTER if is_reenterable(entry) else EntryAction.IGNORE
	return EntryAction.ENTER


## 锁定卡片判定（AC-1/AC-10）。[br]
## [b]返回[/b]: [code]is_unlocked[/code] 为 false → true（显示灰显+🔒）；缺字段
## 安全默认 false（不锁定——[code].get(..., true)[/code] 缺省视为已解锁）。[br]
## 纯函数——无状态、无 Autoload 访问。
static func should_show_lock(entry: Dictionary) -> bool:
	return not bool(entry.get(&"is_unlocked", true))


## 重入资格判定（AC-3/AC-5）。[br]
## [b]返回[/b]: 已通关 且 reentry_allowed 为 true → true（点击弹确认窗）；苍玄
## 古战场 reentry_allowed=false → false（无重入入口）。缺字段安全默认 false。[br]
## 纯函数。
static func is_reenterable(entry: Dictionary) -> bool:
	return bool(entry.get(&"is_cleared", false)) \
			and bool(entry.get(&"reentry_allowed", false))


## 重入确认按钮启用态（AC-4）。[br]
## [b]返回[/b]: 可重入 且 can_reenter（灵石充足）→ true；灵石不足 → false
## （灰显 + 标注「灵石不足」）。缺字段安全默认 false。[br]
## 纯函数。
static func can_confirm_reentry(entry: Dictionary) -> bool:
	return is_reenterable(entry) and bool(entry.get(&"can_reenter", false))


## 解锁条件悬停文本（AC-6）。[br]
## [b]返回[/b]: [code]"需%d境界" % realm_requirement[/code]。[br]
## 纯函数。
static func unlock_requirement_text(entry: Dictionary) -> String:
	return "需%d境界" % int(entry.get(&"realm_requirement", 0))


## === 生命周期 ==================================================================

func _ready() -> void:
	title_label.text = TEXT_TITLE
	_connect_signals()
	_refresh_map_list()
	_refresh_balance()
	# 初始焦点 = 第一张可交互卡（解锁卡）——键盘焦点环。
	var first: MapCard = _first_unlocked_card()
	if first != null:
		first.grab_focus()


func _exit_tree() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()


## 连接 GSM 资源信号——[signal resource_changed] 触发余额刷新（事件驱动，
## 无轮询——control-manifest 必需）。
func _connect_signals() -> void:
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm != null and gsm.has_signal(&"resource_changed"):
		gsm.resource_changed.connect(_on_resource_changed)


## === 数据刷新（零状态所有权——每信号周期从源系统读取）======================

## 刷新地图卡片列表——消费 [code]get_map_list()[/code]（Feature 层未实现时
## 回退 stub 载荷）。[br]
## [b]防御[/b]：数据源返回空数组时仍渲染 stub（场景不空白崩溃）。
func _refresh_map_list() -> void:
	for child: Node in card_row.get_children():
		card_row.remove_child(child)
		child.queue_free()
	var entries: Array = _get_map_list()
	if entries.is_empty():
		entries = _stub_map_list()
	for entry: Dictionary in entries:
		var card: MapCard = MapCardScript.new()
		card.setup(entry)
		card.card_activated.connect(_on_card_activated)
		card_row.add_child(card)
	if animate:
		_play_intro()


## 刷新灵石余额——只读消费 [code]ResourceSystem.get_resource(&"ling_shi")[/code]。[br]
## [b]余额前缀[/b]：用 [constant TEXT_BALANCE_PREFIX]（非 TEXT_TITLE——code-review
## Required #1：避免与左上角标题文字重复），格式「灵石: N」。
func _refresh_balance() -> void:
	var ling_shi: int = _get_ling_shi()
	balance_label.text = "%s: %d" % [TEXT_BALANCE_PREFIX, ling_shi]
	if reentry_dialog.visible:
		reentry_balance_label.text = TEXT_CURRENT_BALANCE % ling_shi


## === 卡片交互分流 ==============================================================

## 卡片点击分流（MapCard.card_activated 信号）——消费 [method entry_action]
## 纯函数决策。[br]
## 锁定卡/已通关不可重入 → 无操作；已通关可重入 → 弹重入确认；未通关 →
## 直接进入意图（0 灵石）。[br]
## [b]改变游戏状态的分支[/b]（进入/重入确认）必须先过 [method _is_input_allowed]。
func _on_card_activated(entry: Dictionary) -> void:
	match entry_action(entry):
		EntryAction.REENTER:
			if _is_input_allowed():
				_show_reentry_dialog(entry)
		EntryAction.ENTER:
			if _is_input_allowed():
				enter_map_requested.emit(entry.get(&"map_id", &""))
		_:
			pass  # IGNORE——锁定卡 / 已通关不可重入


## === 重入确认弹窗 ==============================================================

## 弹出重入确认窗口——地图名 + 明细（基础价×倍率）+ 当前灵石 + 确认/取消。[br]
## [b]灵石不足[/b]：确认按钮灰显 + 标注「灵石不足」（[method can_confirm_reentry]）。
func _show_reentry_dialog(entry: Dictionary) -> void:
	_pending_reentry_id = entry.get(&"map_id", &"")
	reentry_map_label.text = TEXT_MAP_LINE % str(entry.get(&"name", "—"))
	reentry_cost_label.text = TEXT_COST_DETAIL % [
		int(entry.get(&"reentry_total", 0)),
		int(entry.get(&"reentry_base", 0)),
		int(entry.get(&"reentry_multiplier", 1)),
	]
	reentry_balance_label.text = TEXT_CURRENT_BALANCE % _get_ling_shi()
	reentry_warn_label.text = TEXT_CONFIRM_WARN % int(entry.get(&"reentry_total", 0))
	var enough: bool = can_confirm_reentry(entry)
	reentry_confirm_button.disabled = not enough
	reentry_confirm_button.text = TEXT_REENTRY_CONFIRM if enough \
			else "%s（%s）" % [TEXT_REENTRY_CONFIRM, TEXT_INSUFFICIENT]
	reentry_dialog.popup_centered()


func _on_reentry_confirmed() -> void:
	if _pending_reentry_id.is_empty():
		return
	if _is_input_allowed():
		reentry_requested.emit(_pending_reentry_id)
	_pending_reentry_id = &""


func _on_reentry_canceled() -> void:
	_pending_reentry_id = &""


## === 输入 ======================================================================

## 手柄 LB/RB 横向滚动——[code]ui_left[/code]/[code]ui_right[/code] action 驱动
## ScrollContainer（AC-9 三路径之一；滚轮/滚动条为 ScrollContainer 内建）。[br]
## [b]设备限定[/b]：仅响应手柄输入（[InputEventJoypadButton] /
## [InputEventJoypadMotion]）——[code]ui_left[/code]/[code]ui_right[/code] 默认
## 同时绑定键盘方向键，若在 [method _input] 全量拦截会吞掉键盘焦点导航
## （godot-specialist 输入冲突修正）。
func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event.is_action_pressed(&"ui_left"):
			scroll.scroll_horizontal -= SCROLL_STEP
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed(&"ui_right"):
			scroll.scroll_horizontal += SCROLL_STEP
			get_viewport().set_input_as_handled()


## === 动画 ======================================================================

## 卡片逐张飞入 0.3s/张。[br]
## [b]锁定卡遮罩保护[/b]：锁定卡飞入目标 alpha 保持 LOCKED_ALPHA（MapCard
## 内部调制），且用非过冲缓动（TRANS_QUAD——TRANS_BACK 会过冲短暂超过
## 0.45，破坏遮罩不变量，code-review Required #2）。
func _play_intro() -> void:
	if not is_inside_tree():
		return
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = create_tween()
	_intro_tween.set_parallel(true)
	for i: int in range(card_row.get_child_count()):
		var card: MapCard = card_row.get_child(i) as MapCard
		if card == null:
			continue
		var target_alpha: float = 1.0
		var transition: Tween.TransitionType = Tween.TRANS_BACK
		if should_show_lock(card.entry):
			target_alpha = MapCardScript.LOCKED_ALPHA
			transition = Tween.TRANS_QUAD  # 锁定卡非过冲——遮罩不变量
		card.modulate.a = 0.0
		_intro_tween.tween_property(card, "modulate:a", target_alpha,
				CARD_ANIM_DURATION) \
				.set_delay(i * CARD_ANIM_STAGGER) \
				.set_trans(transition).set_ease(Tween.EASE_OUT)


## === 内部辅助 ==================================================================

## 获取地图列表——注入对象优先 → Autoload → 空（上层回退 stub）。
func _get_map_list() -> Array:
	var es: Node = _get_exploration_system()
	if es != null and es.has_method(&"get_map_list"):
		return es.get_map_list()
	return []


## stub 地图列表——Feature 层 get_map_list 未实现时的 fallback（依赖缺口
## 裁决「stub 先行」）。数据存于 MapDataStub 独立文件——Feature 层补齐后
## 删除本方法与 MapDataStub 文件即可，不牵连 UI 逻辑。
func _stub_map_list() -> Array:
	return MapDataStubScript.stub_map_list()


## 获取灵石余额——注入对象优先 → Autoload → 0。
func _get_ling_shi() -> int:
	var rs: Node = _get_resource_system()
	if rs != null and rs.has_method(&"get_resource"):
		return int(rs.get_resource(&"ling_shi"))
	return 0


## 获取第一张已解锁卡（初始焦点目标）。
func _first_unlocked_card() -> MapCard:
	for i: int in range(card_row.get_child_count()):
		var card: MapCard = card_row.get_child(i) as MapCard
		if card != null and not should_show_lock(card.entry):
			return card
	return null


## 输入锁栈判定——改变游戏状态的点击必须过 InputManager（ADR-0004）。[br]
## InputManager 不可用时放行（测试 mock 场景无 Autoload）。
func _is_input_allowed() -> bool:
	var im: Node = get_node_or_null("/root/InputManager")
	if im == null or not im.has_method(&"is_input_allowed"):
		return true
	return bool(im.is_input_allowed(
			InputManagerScript.ActionType.GAMEPLAY,
			InputManagerScript.DeviceType.MOUSE))


## GSM resource_changed 信号处理——仅灵石变更刷新余额（非灵石资源变更
## 不触发——HUD lingshi_deck_bar G1 裁决先例）。
func _on_resource_changed(type: StringName, _delta: int, _balance: int) -> void:
	if type == &"ling_shi":
		_refresh_balance()


## 获取探索系统——注入对象优先，否则回退 Autoload。
func _get_exploration_system() -> Node:
	if exploration_system != null:
		return exploration_system
	return get_node_or_null("/root/ExplorationSystem")


## 获取资源系统——注入对象优先，否则回退 Autoload。
func _get_resource_system() -> Node:
	if resource_system != null:
		return resource_system
	return get_node_or_null("/root/ResourceSystem")
