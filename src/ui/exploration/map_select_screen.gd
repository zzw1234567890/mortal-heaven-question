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
## [method unlock_requirement_text] / [method entry_action] 五个 static 纯函数
## （场景脚本内定义、static 暴露供 GUT 直调——S16-1 先例）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：灵石余额与地图列表经 [MapSelectData]
## 只读现取（UI 绝不写 GSM、绝不自行扣灵石）；列表刷新由 GSM [signal
## resource_changed] 驱动（零轮询）。重入流只发意图（[signal reentry_requested]），
## 扣费与拒绝归探索系统。[br]
## [br][b]不硬编码地图[/b]：列表 100% 来自 [code]ExplorationSystem.get_map_list()[/code]
## （探明表 [code]ExplorationMapCatalog.MAPS[/code] × GSM 组装）；此前的
## [code]map_data_stub.gd[/code] 兜底随 get_map_list 落地删除——数据源不可用时
## 列表为空，不塞假地图。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]。
##
## @experimental
## 来源: ADR-0031、ADR-0014 §get_map_list 契约、control-manifest §Presentation、
## design/gdd/exploration-ui-system.md §1/§6、story-002-map-select-screen.md。

## === 视觉常量（数据驱动）====================================================

## 卡片尺寸（B7 裁决）——MapCard 内部也声明，主界面用于滚动容器预估算。
const CARD_SIZE: Vector2 = Vector2(360, 420)

## 固定 UI 词条（项目暂无本地化系统——S16-1 TEXT_* 同源豁免注记）。
const TEXT_TITLE: String = "选择地图"
## 顶部灵石余额前缀（AC-8——GDD 布局「灵石: 125」格式，不复用 TEXT_TITLE
## 避免与左上角标题文字重复，code-review Required #1）。
const TEXT_BALANCE_PREFIX: String = "灵石"
## 重入弹窗的标题与取消文案（弹窗内的正文/明细文案在 [MapSelectReentryDialog]
## ——那边是填控件的地方，词条跟着它走）。
const TEXT_REENTRY_DIALOG_TITLE: String = "重入地图"
const TEXT_REENTRY_CANCEL: String = "取消"

## MapCard 脚本常量——动态构建卡片用（class_name 在动态加载下不可靠）。
const MapCardScript := preload("res://src/ui/exploration/map_card.gd")
## 数据读取面（地图列表 / 灵石 / 输入锁栈——只读，见 [MapSelectData]）。
const DataScript := preload("res://src/ui/exploration/map_select_data.gd")
## 入场动画编排（逐张飞入 + 锁定卡遮罩不变量，见 [MapSelectAnimator]）。
const AnimatorScript := preload("res://src/ui/exploration/map_select_animator.gd")
## 重入确认弹窗的文案填充（见 [MapSelectReentryDialog]）。
const ReentryDialogScript := preload(
		"res://src/ui/exploration/map_select_reentry_dialog.gd")
## 手柄横向滚动（见 [MapSelectScroll]——设备限定逻辑只在一处）。
const ScrollScript := preload("res://src/ui/exploration/map_select_scroll.gd")

## === 依赖注入（测试可替换）=====================================================

## 探索系统引用——get_map_list 数据源（null 时回退 Autoload）。
var exploration_system: Node = null
## 资源系统引用——灵石余额只读（null 时回退 Autoload）。
var resource_system: Node = null
## 动画开关——测试注入 + reduce-motion 预留接线点（S16-1 先例）。
var animate: bool = true

## === 瞬态交互状态（ADR-0031 §2.1）=============================================

## 待重入地图 ID（重入确认弹窗打开期间）——场景内瞬态状态，不进存档。
var _pending_reentry_id: StringName = &""
## 数据读取面（惰性构建——_init 时宿主尚未就绪）。
var _data: RefCounted = null
## 入场动画编排（惰性构建）。
var _animator: RefCounted = null
## 重入确认弹窗的文案填充（惰性构建 + 首次使用时绑定控件）。
var _reentry: RefCounted = null
## 手柄横向滚动（惰性构建 + 首次使用时绑定滚动容器）。
var _scroll_helper: RefCounted = null

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
## [b]返回[/b]：锁定卡 → IGNORE；已通关可重入 → REENTER；已通关不可重入
## （苍玄古战场）→ IGNORE（与未通关区分，QA-S16-2-001 回归目标）；未通关 →
## ENTER。[br]纯函数、无 Autoload 访问——[method _on_card_activated] 消费它，
## 路由缺陷可单测捕获。
static func entry_action(entry: Dictionary) -> int:
	if should_show_lock(entry):
		return EntryAction.IGNORE
	if bool(entry.get(&"is_cleared", false)):
		return EntryAction.REENTER if is_reenterable(entry) else EntryAction.IGNORE
	return EntryAction.ENTER


## 锁定卡片判定（AC-1/AC-10）。[br]
## [b]返回[/b]：[code]is_unlocked[/code] 为 false → true（灰显+🔒）；缺字段安全
## 默认不锁定（[code].get(..., true)[/code] 视为已解锁）。纯函数。
static func should_show_lock(entry: Dictionary) -> bool:
	return not bool(entry.get(&"is_unlocked", true))


## 重入资格判定（AC-3/AC-5）。[br]
## [b]返回[/b]：已通关且 [code]reentry_allowed[/code] → true（点击弹确认窗）；
## 苍玄古战场 [code]reentry_allowed=false[/code] → false。缺字段默认 false。纯函数。
static func is_reenterable(entry: Dictionary) -> bool:
	return bool(entry.get(&"is_cleared", false)) \
			and bool(entry.get(&"reentry_allowed", false))


## 重入确认按钮启用态（AC-4）。[br]
## [b]返回[/b]：可重入且 [code]can_reenter[/code]（灵石充足）→ true；
## 灵石不足 → false（灰显 + 标注「灵石不足」）。缺字段默认 false。纯函数。
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
	if _animator != null:
		_animator.call(&"kill")


## 连接 GSM 资源信号——[signal resource_changed] 触发余额刷新（事件驱动，零轮询）。
func _connect_signals() -> void:
	var gsm: Node = get_node_or_null("/root/GameStateManager")
	if gsm != null and gsm.has_signal(&"resource_changed"):
		gsm.resource_changed.connect(_on_resource_changed)


## === 数据刷新（零状态所有权——每信号周期从源系统读取）======================

## 刷新地图卡片列表——消费 [code]get_map_list()[/code]（探明表 × GSM）。[br]
## [b]空列表不兜底[/b]：数据源不可用时列表就是空的——塞假地图会让玩家点进一张
## 不存在的图（此前的 stub 兜底正是这个问题）。
func _refresh_map_list() -> void:
	for child: Node in card_row.get_children():
		card_row.remove_child(child)
		child.queue_free()
	for entry: Dictionary in _data_ref().call(&"map_list"):
		var card: MapCard = MapCardScript.new()
		card.setup(entry)
		card.card_activated.connect(_on_card_activated)
		card_row.add_child(card)
	if animate:
		_animator_ref().call(&"play_intro", self, card_row,
				Callable(self, &"should_show_lock"))


## 刷新灵石余额——只读消费 [code]ResourceSystem.get_resource(&"ling_shi")[/code]，
## 格式「灵石: N」（前缀用 [constant TEXT_BALANCE_PREFIX]，不复用标题文字）。
func _refresh_balance() -> void:
	var ling_shi: int = int(_data_ref().call(&"ling_shi"))
	balance_label.text = "%s: %d" % [TEXT_BALANCE_PREFIX, ling_shi]
	_reentry_ref().call(&"refresh_balance", ling_shi)


## === 卡片交互分流 ==============================================================

## 卡片点击分流（MapCard.card_activated）——消费 [method entry_action] 决策。[br]
## [b]改变游戏状态的分支[/b]（进入/重入确认）必须先过输入锁栈判定。
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

## 弹出重入确认窗口。[br]
## [b]文案与启用态的填充在 [MapSelectReentryDialog][/b]——本方法只决定「弹哪张卡」。
func _show_reentry_dialog(entry: Dictionary) -> void:
	_pending_reentry_id = entry.get(&"map_id", &"")
	_reentry_ref().call(&"show_for", entry, int(_data_ref().call(&"ling_shi")),
			can_confirm_reentry(entry))


func _on_reentry_confirmed() -> void:
	if _pending_reentry_id.is_empty():
		return
	if _is_input_allowed():
		reentry_requested.emit(_pending_reentry_id)
	_pending_reentry_id = &""


func _on_reentry_canceled() -> void:
	_pending_reentry_id = &""


## === 输入 ======================================================================

## 手柄 LB/RB 横向滚动——设备限定逻辑在 [MapSelectScroll]（只认手柄事件，键盘
## 方向键留给引擎的焦点导航；滚轮/滚动条为 ScrollContainer 内建）。[br]
## 消费走 [method Viewport.set_input_as_handled]——滚动手柄时不惊动下层。
func _input(event: InputEvent) -> void:
	if bool(_scroll_ref().call(&"handle", event)):
		get_viewport().set_input_as_handled()


## === 内部辅助 ==================================================================

## 数据读取面（惰性构建——宿主为本屏幕，注入字段由 [MapSelectData] 读取）。
func _data_ref() -> RefCounted:
	if _data == null:
		_data = DataScript.new(self)
	return _data


## 入场动画编排（惰性构建）。
func _animator_ref() -> RefCounted:
	if _animator == null:
		_animator = AnimatorScript.new()
	return _animator


## 重入弹窗填充器（惰性构建 + 绑定弹窗控件——控件由场景提供，引用交它持有）。
func _reentry_ref() -> RefCounted:
	if _reentry == null:
		_reentry = ReentryDialogScript.new()
		_reentry.call(&"bind", reentry_dialog, reentry_map_label, reentry_cost_label,
				reentry_balance_label, reentry_warn_label, reentry_confirm_button)
	return _reentry


## 手柄滚动助手（惰性构建 + 绑定滚动容器）。
func _scroll_ref() -> RefCounted:
	if _scroll_helper == null:
		_scroll_helper = ScrollScript.new()
		_scroll_helper.call(&"bind", scroll)
	return _scroll_helper


## 第一张已解锁卡（初始焦点目标）。
func _first_unlocked_card() -> MapCard:
	for i: int in range(card_row.get_child_count()):
		var card: MapCard = card_row.get_child(i) as MapCard
		if card != null and not should_show_lock(card.entry):
			return card
	return null


## 输入锁栈判定——改变游戏状态的点击必须过 InputManager（ADR-0004）。
func _is_input_allowed() -> bool:
	return bool(_data_ref().call(&"input_allowed"))


## GSM resource_changed——仅灵石变更刷新余额（HUD lingshi_deck_bar G1 先例）。
func _on_resource_changed(type: StringName, _delta: int, _balance: int) -> void:
	if type == &"ling_shi":
		_refresh_balance()
