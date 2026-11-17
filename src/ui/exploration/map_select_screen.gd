class_name MapSelectScreen
extends Control
## MapSelectScreen —— 地图选择界面（exploration-ui Story S16-2）。
##
## [b]节点形态[/b]（ADR-0031 §1）：场景内 Control 树（零新增 Autoload），挂载于
## [code]exploration_scene.tscn[/code] 薄容器（闭合 SCENE_PATHS EXPLORATION 占位）。[br]
## [b]结构[/b]：标题 + 灵石余额 + 横向滚动卡片列表（ScrollContainer + HBoxContainer，
## MapCard 动态构建）+ 重入确认弹窗（ConfirmationDialog）。[br]
## [b]Logic 内核[/b]（BLOCKING 单测目标）：[method should_show_lock] /
## [method is_reenterable] / [method can_confirm_reentry] /
## [method unlock_requirement_text] / [method entry_action] 五个 static 纯函数
## （场景脚本内定义、static 暴露供 GUT 直调——S16-1 先例）。[br]
## [b]零状态所有权[/b]（ADR-0031 §2）：灵石余额与地图列表经 [MapSelectData] 只读现取
## （UI 绝不写 GSM、绝不自行扣灵石）；列表刷新由 GSM [signal resource_changed] 驱动，
## 重入流只发意图（[signal reentry_requested]），扣费与拒绝归探索系统。[br]
## [b]不硬编码地图[/b]：列表 100% 来自 [code]ExplorationSystem.get_map_list()[/code]
## （探明表 × GSM 组装）——数据源不可用时列表为空，不塞假地图（stub 兜底已删）。[br]
## [b]未解锁卡[/b]：灰显 + 🔒 + 卡面条件行，点击由 [MapSelectNotice] 给中文提示不进场。[br]
## [b]零轮询[/b]：无 [code]_process()[/code]。@experimental
##
## 来源: ADR-0031、ADR-0014 §get_map_list 契约、control-manifest §Presentation、
## design/gdd/exploration-ui-system.md §1/§6、story-002-map-select-screen.md。

## === 视觉常量（数据驱动）====================================================

## 固定 UI 词条（项目暂无本地化系统——S16-1 TEXT_* 同源豁免注记）。
const TEXT_TITLE: String = "选择地图"
## 顶部灵石余额前缀（AC-8——GDD 布局「灵石: 125」格式，不复用 TEXT_TITLE 避免与
## 左上角标题文字重复，code-review Required #1）。
const TEXT_BALANCE_PREFIX: String = "灵石"
## 卡片尺寸与重入弹窗词条[b]不在本脚本重复声明[/b]：前者在 [code]MapCard.setup[/code]
## （卡片自建时写入 [code]custom_minimum_size[/code]），后者在 [code]map_select_screen.tscn[/code]
## （title / ok_button_text / cancel_button_text）与 [MapSelectReentryDialog]。此处曾各存
## 一份从无读取方的副本——留着只会与真源漂移（.claude/rules 禁止重复）。

## 卡片行构建与推荐高亮（见 [MapSelectCards]——「推荐下一张」的落点）。
const CardsScript := preload("res://src/ui/exploration/map_select_cards.gd")
## 数据读取面（地图列表 / 灵石 / 输入锁栈——只读，见 [MapSelectData]）。
const DataScript := preload("res://src/ui/exploration/map_select_data.gd")
## 卡片点击的落地效果（进图 / 重入确认 / 条件提示——见 [MapSelectInteraction]）。
const InteractionScript := preload("res://src/ui/exploration/map_select_interaction.gd")
## 入场动画编排（逐张飞入 + 锁定卡遮罩不变量，见 [MapSelectAnimator]）。
const AnimatorScript := preload("res://src/ui/exploration/map_select_animator.gd")
## 手柄横向滚动（见 [MapSelectScroll]——设备限定逻辑只在一处）。
const ScrollScript := preload("res://src/ui/exploration/map_select_scroll.gd")

## === 依赖注入（测试可替换）=====================================================

## 探索系统引用——get_map_list 数据源（null 时回退 Autoload）。
var exploration_system: Node = null
## 资源系统引用——灵石余额只读（null 时回退 Autoload）。
var resource_system: Node = null
## 动画开关——测试注入 + reduce-motion 预留接线点（S16-1 先例）。
var animate: bool = true
## [b]测试注入[/b]：未解锁卡提示的通知入口 [code]func(type, text) -> int[/code]。
## 为 null 时按常驻 HUD 查找（生产路径，见 [MapSelectNotice.notification_sink]）
## ——与 [code]ExplorationScene.notify_cb[/code] 同源注入点。
var notify_cb: Callable = Callable()

## === 瞬态交互状态（ADR-0031 §2.1）=============================================
## 待重入地图 ID 已移到 [MapSelectInteraction]（与弹窗同生共死——查询走
## [method pending_reentry_id]）。下面是本屏幕自己的几个懒构建引用。
## 数据读取面（惰性构建——_init 时宿主尚未就绪）。
var _data: RefCounted = null
## 入场动画编排（惰性构建）。
var _animator: RefCounted = null
## 卡片点击的落地效果（惰性构建 + 首次使用时绑定弹窗控件与两个意图出口）。
var _interaction: RefCounted = null
## 手柄横向滚动（惰性构建 + 首次使用时绑定滚动容器）。
var _scroll_helper: RefCounted = null
## 卡片行构建与推荐高亮（惰性构建——见 [MapSelectCards]）。
var _cards: RefCounted = null

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
## [b]返回[/b]：锁定卡 → IGNORE；已通关可重入 → REENTER；已通关不可重入（苍玄古战场）
## → IGNORE（与未通关区分，QA-S16-2-001 回归目标）；未通关 → ENTER。纯函数、无 Autoload
## 访问——[method _on_card_activated] 消费它，路由缺陷可单测捕获。
static func entry_action(entry: Dictionary) -> int:
	if should_show_lock(entry):
		return EntryAction.IGNORE
	if bool(entry.get(&"is_cleared", false)):
		return EntryAction.REENTER if is_reenterable(entry) else EntryAction.IGNORE
	return EntryAction.ENTER


## 锁定卡片判定（AC-1/AC-10）。[br]
## [b]返回[/b]：[code]is_unlocked[/code] 为 false → true（灰显+🔒）；缺字段安全默认不
## 锁定（[code].get(..., true)[/code] 视为已解锁）。纯函数。
static func should_show_lock(entry: Dictionary) -> bool:
	return not bool(entry.get(&"is_unlocked", true))


## 重入资格判定（AC-3/AC-5）。[br]
## [b]返回[/b]：已通关且 [code]reentry_allowed[/code] → true（点击弹确认窗）；苍玄古战场
## [code]reentry_allowed=false[/code] → false。缺字段默认 false。纯函数。
static func is_reenterable(entry: Dictionary) -> bool:
	return bool(entry.get(&"is_cleared", false)) \
			and bool(entry.get(&"reentry_allowed", false))


## 重入确认按钮启用态（AC-4）。[br]
## [b]返回[/b]：可重入且 [code]can_reenter[/code]（灵石充足）→ true；灵石不足 → false
## （灰显 + 标注「灵石不足」）。缺字段默认 false。纯函数。
static func can_confirm_reentry(entry: Dictionary) -> bool:
	return is_reenterable(entry) and bool(entry.get(&"can_reenter", false))


## 解锁条件悬停文本（AC-6）。[br]
## [b]返回[/b]: [code]"需%d境界" % realm_requirement[/code]（数字形式；卡片与点击提示
## 走 [MapCard.locked_hint_text] / [MapSelectNotice] 的中文口径）。纯函数。
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
## [b]空列表不兜底[/b]：数据源不可用时列表就是空的——塞假地图会让玩家点进一张不存在的图。[br]
## [br][b]重建后重放推荐态[/b]：推荐高亮由 [MapSelectCards] 持有，重建时自动重放
## ——否则「通关确认后刷新一次列表」就会把刚点亮的那张卡抹掉。
func _refresh_map_list() -> void:
	_cards_ref().call(&"rebuild", card_row, _data_ref().call(&"map_list"),
			Callable(self, &"_on_card_activated"))
	if animate:
		_animator_ref().call(&"play_intro", self, card_row,
				Callable(self, &"should_show_lock"))


## 高亮「推荐下一张」——通关结算确认后由宿主调用（[param p_map_id] 为空串 = 全部熄灭）。[br]
## [br][b]调用前提[/b]：列表已是最新（宿主先 [method _refresh_map_list] 再调本方法
## ——刷新会重建卡片，本方法负责重放推荐态，两步顺序不能反）。[br]
## [br][b]返回[/b]：是否真的点亮了某一张（推荐 ID 不在列表里时为 false——不臆造高亮）。
func highlight_next_map(p_map_id: StringName) -> bool:
	return bool(_cards_ref().call(&"highlight", p_map_id))


## 当前被点亮的地图 ID（空串 = 没有推荐——测试断言与宿主查询用）。
func recommended_map_id() -> StringName:
	return _cards_ref().call(&"recommended_id")


## 刷新灵石余额——只读消费 [code]ResourceSystem.get_resource(&"ling_shi")[/code]，
## 格式「灵石: N」（前缀用 [constant TEXT_BALANCE_PREFIX]，不复用标题文字）。
func _refresh_balance() -> void:
	var ling_shi: int = int(_data_ref().call(&"ling_shi"))
	balance_label.text = "%s: %d" % [TEXT_BALANCE_PREFIX, ling_shi]
	_interaction_ref().call(&"refresh_balance", ling_shi)


## === 卡片交互分流 ==============================================================

## 卡片点击分流（MapCard.card_activated）——消费 [method entry_action] 决策。[br]
## [br][b]决策在这里、效果在 [MapSelectInteraction][/b]：本方法只把纯函数的判定结果
## 连同「灵石够不够」一起交出去（谁是真理来源仍在这一处），落地动作归那边。
func _on_card_activated(entry: Dictionary) -> void:
	_interaction_ref().call(&"activate", entry_action(entry), entry,
			can_confirm_reentry(entry))


## === 重入确认弹窗 ==============================================================

## 重入确认——发出重入意图（扣费与进图归 Feature 层）。[br]
## [br][b]由 tscn 的 [code]confirmed[/code] 信号直连[/b]，故保持无参。
func _on_reentry_confirmed() -> void:
	_interaction_ref().call(&"confirm")


## 重入取消——丢弃待办 ID（弹窗关闭 / 取消按钮）。
func _on_reentry_canceled() -> void:
	_interaction_ref().call(&"cancel")


## 当前待重入的地图 ID（空串 = 弹窗未开或已确认/取消——宿主查询与测试断言用）。
func pending_reentry_id() -> StringName:
	return _interaction_ref().call(&"pending_id")


## === 输入 ======================================================================

## 手柄横向滚动——设备限定逻辑在 [MapSelectScroll]（只认手柄事件，键盘方向键留给
## 引擎的焦点导航；滚轮/滚动条为 ScrollContainer 内建）。消费走
## [method Viewport.set_input_as_handled]——滚动手柄时不惊动下层。
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


## 重入弹窗填充器与点击落地的接线（惰性构建 + 绑定弹窗控件与两个意图出口）。[br]
## [br][b]出口为什么是 lambda 而不是 [method Object.emit_signal] 直绑[/b]：
## [method Callable.bind] 把绑定参数接在调用参数[b]之后[/b]——直绑会让信号名落到
## 地图 ID 的位置，发出去的是 [code]emit_signal(map_id, "信号名")[/code]。[br]
## [br][b]为什么是本屏幕持有[/b]：弹窗控件由本屏幕的场景提供，意图出口也是本屏幕的
## 信号——都交给 [MapSelectInteraction] 之后，屏幕自己只留一个引用。
func _interaction_ref() -> RefCounted:
	if _interaction == null:
		_interaction = InteractionScript.new()
		_interaction.call(&"bind", self, reentry_dialog, reentry_map_label,
				reentry_cost_label, reentry_balance_label, reentry_warn_label,
				reentry_confirm_button,
				func(p_id: StringName) -> void: enter_map_requested.emit(p_id),
				func(p_id: StringName) -> void: reentry_requested.emit(p_id))
	return _interaction


## 手柄滚动助手（惰性构建 + 绑定滚动容器）。
func _scroll_ref() -> RefCounted:
	if _scroll_helper == null:
		_scroll_helper = ScrollScript.new()
		_scroll_helper.call(&"bind", scroll)
	return _scroll_helper


## 卡片行构建与推荐高亮（惰性构建——无依赖，见 [MapSelectCards]）。
func _cards_ref() -> RefCounted:
	if _cards == null:
		_cards = CardsScript.new()
	return _cards


## 第一张已解锁卡（初始焦点目标）——卡片数组归 [MapSelectCards] 持有。
func _first_unlocked_card() -> MapCard:
	return _cards_ref().call(&"first_unlocked") as MapCard


## GSM resource_changed——仅灵石变更刷新余额（HUD lingshi_deck_bar G1 先例）。
func _on_resource_changed(type: StringName, _delta: int, _balance: int) -> void:
	if type == &"ling_shi":
		_refresh_balance()
