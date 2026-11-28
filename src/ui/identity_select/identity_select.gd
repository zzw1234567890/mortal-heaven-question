class_name IdentitySelect
extends Control
## IdentitySelect —— 开局身份选择场景（identity-selection Story S16-1）。
##
## [b]节点形态[/b]（ADR-0031 §1）：场景内 Control 树（零新增 Autoload），由
## [constant SceneManager.SCENE_PATHS] 的 IDENTITY_SELECT 条目挂载
## （[code]res://src/ui/identity_select/identity_select.tscn[/code]）。[br]
## [br][b]职责边界[/b]——本脚本只做节点接线 + 瞬态选中态 + 事件处理：[br]
##   · 门禁判定与 UI 文案 → [code]identity_select_rules.gd[/code]（static 纯函数）[br]
##   · 渲染 / 高亮 / 弹窗 / 叙事 → [code]identity_select_presenter.gd[/code][br]
##   · 卡片结构构建 → [code]identity_card_factory.gd[/code]（static）[br]
##   · 读档跳过 / 导航 / 音频 → [code]identity_select_nav.gd[/code][br]
## [br][b]开局门禁[/b]（二级）：未解锁 → 提示轮回天赋；已解锁但卡组模板不全 →
## 提示「该身份暂未开放」。两种都[b]禁止开局[/b]——被拦的卡点击不进选中态、
## 确认按钮保持禁用、确认路径再校验一次，绝不静默改用身份①开局。
## [code]apply_identity()[/code] 若仍失败，弹玩家可见的失败提示并停在选择界面。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：[member selected_id] / [member selected_entry]
## 是场景内瞬态交互状态（§2.1 三分类——不进存档、刷新即弃）；最终结果只经
## [code]apply_identity()[/code] 写入 GSM，本场景绝不直接写 GSM。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]。
##
## @experimental
## 来源: ADR-0022、ADR-0031、control-manifest §Presentation、
## design/gdd/identity-selection-system.md §4-5、story-004-identity-select-ui.md。

## 门禁判定与 UI 文本子模块（static 纯函数）。
const Rules := preload("res://src/ui/identity_select/identity_select_rules.gd")
## 渲染/动画子模块。
const PresenterScript := preload("res://src/ui/identity_select/identity_select_presenter.gd")
## 导航/音频子模块。
const NavScript := preload("res://src/ui/identity_select/identity_select_nav.gd")
## 跨场景意图（新游戏强制走选择流程——见该模块类文档）。
const IntentScript := preload("res://src/ui/identity_select/identity_select_intent.gd")
## InputManager 脚本常量——ActionType/DeviceType 枚举真理来源。
const InputManagerScript := preload("res://src/foundation/input_manager.gd")

## 入场动画时长与叙事行间隔——转出给 Presenter（策划参数对照此名）。
const INTRO_DURATION: float = PresenterScript.INTRO_DURATION
const INTRO_STAGGER: float = PresenterScript.INTRO_STAGGER
const NARRATIVE_LINE_INTERVAL: float = PresenterScript.NARRATIVE_LINE_INTERVAL

## === 依赖注入（测试可替换）=====================================================

## SceneManager 引用——导航转场用（null 时回退 Autoload，先例 main_menu）。
var scene_manager: Node = null
## IdentitySelectionSystem 引用——查询/apply 数据源（null 时回退 Autoload）。
var identity_system: Node = null
## 动画开关——测试注入 + reduce-motion 预留接线点。
var animate: bool = true

## === 瞬态交互状态（ADR-0031 §2.1）=============================================

## 当前选中身份 ID（空 = 未选中）——场景内瞬态交互状态，不进存档、刷新即弃。
var selected_id: StringName = &""
## 当前选中条目——开局门禁与提示文案都读它（选中态与条目同进同出）。
var selected_entry: Dictionary = {}

## === 节点引用：网格 + 确认按钮 =================================================

@onready var title_label: Label = $LayoutAnchor/TitleLabel
@onready var grid: GridContainer = $LayoutAnchor/GridContainer
@onready var confirm_button: Button = $LayoutAnchor/ConfirmButton

## === 子模块 ====================================================================

## 渲染子模块——懒建一次（节点引用只在 _ready 后可用，故不在 _init 固化）。
var _presenter: RefCounted = null
## 导航子模块——同样懒建。
var _nav: RefCounted = null

## === Logic 内核（static 纯函数——BLOCKING 单测目标，实现见 Rules）===============

## 确认按钮启用态判定（AC-1 / QA AC-1）。[br]
## [br]纯函数——无状态、无 Autoload 访问（static 供 GUT 直调）。
static func confirm_button_enabled(selected_id: StringName) -> bool:
	return Rules.confirm_button_enabled(selected_id)


## 解锁状态透传（AC-2 / QA AC-2）。[br]
## [br]纯函数——无状态、无 Autoload 访问。
static func is_identity_unlocked(entry: Dictionary) -> bool:
	return Rules.is_identity_unlocked(entry)


## === 生命周期 ==================================================================

func _ready() -> void:
	# 新游戏意图优先：主菜单点「新游戏」时落一份一次性意图，强制走选择流程——
	# 否则同一进程里已选过身份（或存档里有 identity_id）会被下面的跳过判定整体吞掉，
	# 表现成「点新游戏直接跳到选地图」（听风 2026-11-27 报的 bug）。
	if IntentScript.take_force_show():
		_build_ui()
		return
	# 读档跳过：identity_id 非空 → 直接请求导航 EXPLORATION，不渲染选择 UI。
	if _get_nav().is_skip_needed():
		_get_nav().skip_to_exploration()
		return
	_build_ui()


func _exit_tree() -> void:
	if _presenter != null:
		_presenter.call(&"teardown")


## === UI 构建 ===================================================================

## 渲染 6 卡网格 + 详情面板初始态 + 音频状态 + 入场动画 + 初始焦点。
func _build_ui() -> void:
	title_label.text = Rules.TEXT_TITLE
	confirm_button.text = Rules.TEXT_CONFIRM_BUTTON
	$LayoutAnchor/DetailPanel.visible = false
	# 详情面板不空着：默认展示「初始焦点那张卡」的身份详情，玩家不用先点一下才知道有这块。
	# 仍然等 refresh_cards 之后再填——entries 没落地时 _get_identity_preview 拿不到身份表。
	var entries: Array = _get_available_identities()
	_get_presenter().call(&"refresh_cards", entries,
			Callable(self, &"_on_card_gui_input"))
	_refresh_confirm_button()
	_get_nav().trigger_audio_state()
	if animate:
		_get_presenter().call(&"play_intro")
	# 初始焦点 = 第一张可开局卡（story Implementation Notes——键盘焦点环）。
	var focus_index: int = int(_get_presenter().call(&"first_startable_index", entries))
	if focus_index >= 0:
		var card: Control = grid.get_child(focus_index) as Control
		if card != null:
			card.grab_focus()
		# 与焦点卡配对：右侧详情直接显示这张身份，避免开局就是一大片留白（老板 2026-11-28 反馈）。
		# [b]只填信息、不进选中态[/b]——选中态归点击，未开放/未解锁的身份不得因默认焦点被选中（既有门禁用例钉住）。
		var focus_id: StringName = StringName(str(entries[focus_index].get(&"identity_id", &"")))
		if not focus_id.is_empty():
			_get_presenter().call(&"show_detail", _get_identity_preview(focus_id))


## === 卡片交互 ==================================================================

## 高亮选中卡片，其余恢复默认——纯视觉，不写游戏状态（实现在 Presenter）。[br]
## [br][b]为何仍在场景脚本保留这个薄转发[/b]：既有单测直接以
## [code]screen._highlight_selected(card)[/code] 驱动遮罩不变量断言；
## 转发保住该 API（未改名、未删除任何既有测试），实现细节则留在 Presenter。
func _highlight_selected(selected_card: Control) -> void:
	_get_presenter().call(&"highlight", selected_card)


## 0.6s 6 卡依次飞入；被拦卡的飞入目标为半透明遮罩而非 1.0（实现在 Presenter）。[br]
## [br]同上：既有单测以 [code]screen._play_intro()[/code] 驱动遮罩断言，故保留转发。
func _play_intro() -> void:
	_get_presenter().call(&"play_intro")


## 卡片点击——瞬态选中态，直接 [code]gui_input[/code] 合法（不改变游戏状态）。[br]
## [br]被拦的卡（未解锁 / 暂未开放）→ 弹对应提示且[b]不进入选中态[/b]，
## 确认按钮保持禁用，玩家无法据此开局。
func _on_card_gui_input(event: InputEvent, index: int, entry: Dictionary) -> void:
	if not (event is InputEventMouseButton):
		return
	if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
		return
	var card: Control = grid.get_child(index) as Control
	if card == null:
		return
	if not Rules.is_identity_ready(entry):
		_show_blocked_toast(entry)
		return
	selected_id = StringName(str(entry.get(&"identity_id", &"")))
	selected_entry = entry
	_get_presenter().call(&"highlight", card)
	_get_presenter().call(&"show_detail", _get_identity_preview(selected_id))
	_refresh_confirm_button()


## === 确认流程 ==================================================================

## 确认按钮点击——改变游戏状态（apply_identity 写 GSM）必须过
## [code]InputManager.is_input_allowed()[/code] 锁栈判定。[br]
## [br]二次门禁：选中态可能已过期（条目重读后不再可开局）——此处重新判定并拦住。
func _on_confirm_pressed() -> void:
	if selected_id.is_empty():
		return
	if not Rules.is_identity_ready(selected_entry):
		_show_blocked_toast(selected_entry)
		return
	if not _is_input_allowed():
		return
	_get_presenter().call(&"populate_confirm_dialog",
			_get_identity_preview(selected_id))


## [返回重选]——关闭弹窗、保留选中（不重置 [member selected_id]）。
func _on_confirm_dialog_canceled() -> void:
	pass  # 选中保留——仅关闭弹窗（selected_id / selected_entry 不动）


## [确定]——[code]apply_identity()[/code] 成功 → 开局叙事 → 请求导航 EXPLORATION。[br]
## [br][b]失败必须让玩家看见[/b]：门禁已提前拦过一轮，走到这里仍失败说明身份/资产
## 在会话中途变了（如模板被删）——弹提示停在选择界面，绝不 push_error 了事、
## 也绝不改用身份①静默开局。
func _on_confirm_dialog_confirmed() -> void:
	if not Rules.is_identity_ready(selected_entry):
		_show_blocked_toast(selected_entry)
		return
	var isys: Node = _get_nav().get_identity_system()
	if isys == null or not isys.has_method(&"apply_identity"):
		_show_toast(Rules.TEXT_APPLY_FAILED_TOAST, Rules.TEXT_APPLY_FAILED_TITLE)
		return
	if not bool(isys.apply_identity(selected_id)):
		_show_toast(Rules.TEXT_APPLY_FAILED_TOAST, Rules.TEXT_APPLY_FAILED_TITLE)
		return
	_start_narrative()


## === 开局叙事（基础展示 + 任意键跳过——完整演出归叙事 epic）====================

## 开始叙事展示——从 [code]get_identity_preview()[/code] 的 flavor_text 逐行显示。[br]
## [br][b]结束时请求的是「新开局」那条导航[/b]：本场景只有「玩家确认了身份」这一种
## 情况会走到叙事，因此叙事结束 = 一局新游戏的开端——请求里带上
## [constant ExplorationEntryIntent.EntryMode.FIRST_MAP] 意图，探索场景挂载时直接
## 进第一张图（青云剑宗），玩家不必再点一次地图卡。[br]
## [br][b]读档跳过不在此列[/b]：那条走 [method IdentitySelectNav.skip_to_exploration]，
## 目标是「回到存档里那张图」——见 [method _get_nav] 的 on_transition_target。[br]
## [br]信号经 [method Object.connect] 接线（Presenter 声明为 RefCounted——
## 静态类型下用 [method Object.call] / [method Object.connect] 访问其成员，
## 避免把子模块的具体类型泄漏进场景脚本）。
func _start_narrative() -> void:
	var flavor: String = str(_get_identity_preview(selected_id).get(&"flavor_text", ""))
	var presenter: RefCounted = _get_presenter()
	if not presenter.is_connected(&"narrative_finished", _request_new_run_exploration):
		presenter.connect(&"narrative_finished", _request_new_run_exploration)
	presenter.call(&"start_narrative", flavor)


## 任意键跳过叙事——[code]_input()[/code] 拦截（先例 pause_menu ESC 拦截路径）。[br]
## [b]消费输入[/b]：仅当真跳过了（叙事层原本可见）才 [code]set_input_as_handled()[/code]
## ——阻止 ESC 继续传播到 InputManager 触发暂停菜单、阻止点击穿透到下层卡片。
func _input(event: InputEvent) -> void:
	var presenter: RefCounted = _presenter
	if presenter == null or not bool(presenter.call(&"narrative_visible")):
		return
	var pressed: bool = (event is InputEventKey or event is InputEventMouseButton) \
			and event.pressed
	if not pressed:
		return
	if bool(presenter.call(&"skip_narrative")):
		get_viewport().set_input_as_handled()


## === 提示弹窗 ==================================================================

## 按身份条目弹对应提示（未解锁 → 轮回天赋文案；暂未开放 → 「该身份暂未开放」）。
func _show_blocked_toast(entry: Dictionary) -> void:
	_show_toast(Rules.blocked_toast_text(entry), Rules.blocked_toast_title(entry))


## 弹提示——AcceptDialog 弹窗（现有先例 corrupt_save_dialog）。
func _show_toast(text: String, title: String = "") -> void:
	_get_presenter().call(&"show_toast", text, title)


## === 内部辅助 ==================================================================

## 请求导航到探索（读档跳过 / 叙事结束共用；实现在 Nav）。
func _request_exploration() -> void:
	_get_nav().request_exploration()


## 请求导航到探索——[b]新开局路径[/b]（叙事结束时的回调）。[br]
## [br][b]与 [method _request_exploration] 的差别[/b]：多带一条「直接进第一张图」的
## 跨场景意图（见 [method IdentitySelectNav.request_new_run_exploration]）。读档跳过的
## 回调仍是前者——那条要回到存档里那张图，不是第一张。[br]
func _request_new_run_exploration() -> void:
	_get_nav().request_new_run_exploration()


## 输入锁栈判定——确认按钮改变游戏状态，必须过
## [code]InputManager.is_input_allowed[/code]（ADR-0004 公共 API；实现在 Nav）。
func _is_input_allowed() -> bool:
	return bool(_get_nav().is_input_allowed())


## 确认按钮 enabled 态刷新——「选了」且「选中那个能开局」（Rules 纯函数驱动）。
func _refresh_confirm_button() -> void:
	confirm_button.disabled = not Rules.confirm_enabled_for(selected_id, selected_entry)


## 取/建渲染子模块——首次调用时把场景节点组交给它（节点引用只在 _ready 后可用，
## 故不在 _init 里固化；接线集中在 Presenter.attach）。
func _get_presenter() -> RefCounted:
	if _presenter == null:
		_presenter = PresenterScript.new()
		_presenter.call(&"attach", self)
	return _presenter


## 取/建导航子模块（注入引用透传给 Nav）。
func _get_nav() -> RefCounted:
	if _nav == null:
		_nav = NavScript.new()
		_nav.host = self
		_nav.scene_manager = scene_manager
		_nav.identity_system = identity_system
		_nav.on_transition_target = Callable(self, &"_request_exploration")
	return _nav


## 获取 6 条身份条目——系统不可用时返回空数组（渲染 6 张「暂未开放」占位卡，
## 场景不崩溃，且不存在任何可开局的假象）。
func _get_available_identities() -> Array:
	var isys: Node = _get_nav().get_identity_system()
	if isys != null and isys.has_method(&"get_available_identities"):
		return isys.get_available_identities()
	push_warning("IdentitySelect: IdentitySelectionSystem 不可用——渲染锁定位")
	return []


## 获取身份预览——同上防御。
func _get_identity_preview(identity_id: StringName) -> Dictionary:
	var isys: Node = _get_nav().get_identity_system()
	if isys != null and isys.has_method(&"get_identity_preview"):
		return isys.get_identity_preview(identity_id)
	return {}
