extends Control
## CultivationScreen —— 修炼室（[code]SceneID.CULTIVATION = 10[/code]，纯代码构建 UI）。[br]
## [br][b]为什么需要它[/b]：[code]SceneManager.SCENE_PATHS[/code] 里
## [code]CULTIVATION[/code] 一直指向占位场景（深色底 +「修为养成功能正在打造中」），
## 玩家从主菜单点「修为养成」进去只能看到一个返回按钮。而「打坐涨修为」与「修为满则
## 突破」两条链路[b]早已存在[/b]：[code]CultivationSystem.gain_cultivation[/code] 是
## 修为获取的唯一入口，[code]RealmSystem.realm_up[/code] 是境界写入的唯一编排器
## （ADR-0010）；缺的只是一个把它们接给玩家的常驻场景。[br]
## [br][b]门面而非再造[/b]（ADR-0031 §2 零状态所有权）：本屏不持有也不推算任何玩法
## 数值——控件树在 [code]CultivationSceneLayout[/code]、措辞与判定在
## [code]CultivationViewRules[/code]、系统接入在 [code]CultivationActions[/code]。
## 本屏只管「把三者接起来、把回执写进提示行」。[br]
## [br][b]上限是帧末到账的[/b]：境界写入的 Cat 1 信号走 GSM 帧末缓冲
## （[code]_buffer_change[/code] → [code]call_deferred[/code]），而修为上限的重算由
## [code]CultivationSystem[/code] 订阅 [code]realm_changed[/code] 完成（GDD §6）——
## 故 [method refresh] 刚跑完时上限可能仍是旧值。本屏订阅同一信号，信号一到再刷一次
## （见 [method _connect_realm_changed]）。测试若要断言「上限跟着变」，等帧。[br]
## [br][b]事件层级 = _input[/b]：与坊市 / 洞府面板同源理由——焦点落在 [Button] 上时
## 引擎的内置焦点导航会在 GUI 阶段先吃掉方向键；[code]_input[/code] 排在 GUI 派发之前，
## 是唯一能拦住的层。消费走 [method Viewport.set_input_as_handled]（顺带挡住
## [code]InputManager[/code] 的 Esc → 暂停菜单）。[br]
## [br][b]文案本地化豁免[/b]：项目暂无本地化系统——面向玩家的句子集中在
## [code]CultivationViewRules[/code] 的 [code]TEXT_*[/code]（本屏不自己措辞，
## 同 S16/S17 口径）。[br]
##
## 来源: design/gdd/cultivation-system.md §4/§5/§6、ADR-0010 §realm_up 编排器、
## ADR-0031 §2/§4、ADR-0005（导航唯一入口）、.claude/rules/ui-code.md（双输入 +
## 色盲可读）、先例 [code]shop_screen.gd[/code]（同形态的独立场景 + 复用布局模块）、
## [code]meditation_panel_screen.gd[/code]（同一套突破语义的 overlay 形态）。

## 玩家点了「离开」（[code]ShopPanelLayout.build[/code] 把「离开」按钮的
## [signal Button.pressed] 转发到这个信号上——本屏必须[b]自己声明[/b]它：
## [method Object.emit_signal] 对未声明的信号名不报编译错、只在运行时静默失败
## （[code]ERR_UNAVAILABLE[/code]），届时按钮点了没反应）。[br]
## [br][b]本屏自己消费这个信号[/b]（见 [method _request_leave]）：唯一的出口是
## 「回主菜单」。若改成「另外把按钮的 pressed 接到出口上」，同一次点击会经两条路
## 各发一次转场请求。
signal leave_requested

## 本屏的控件树（底色 + 中段信息块 + 两个动作行；骨架复用探索侧商店布局）。
const SceneLayoutScript := preload("res://src/ui/cultivation/cultivation_scene_layout.gd")
## 键盘/手柄导航与焦点搬运（游标复用探索侧商店的那一份）。
const SceneInputScript := preload("res://src/ui/cultivation/cultivation_scene_input.gd")
## 措辞与判定单点（打坐增量 / 状态行 / 拒绝原因 / 按钮可用性）。
const RulesScript := preload("res://src/ui/cultivation/cultivation_view_rules.gd")
## 系统接入半边（读状态 / 打坐 / 突破——每次现取屏幕上的注入字段）。
const ActionsScript := preload("res://src/ui/cultivation/cultivation_actions.gd")
## 依赖解析（注入优先、否则 Autoload——与坊市 / 卡组编辑同口径）。
const SourcesScript := preload("res://src/ui/hud/deck_view_sources.gd")
## SceneManager 脚本常量——SceneID / TransitionType 枚举真理来源。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")

## 依赖注入（null 时按 /root 找 Autoload——同坊市 / 卡组编辑的回退口径）。[br]
## [br][b]接入半边现读这三个字段[/b]：故「进树前注入」即可被采信——
## [member _actions_] 构造时只拿本屏引用，不缓存系统句柄。
var cultivation_system: Node = null
var realm_system: Node = null
var gsm: Node = null
var scene_manager: Node = null

## 系统接入半边（[method _init] 时构造——它只持本屏引用）。
var _actions_: RefCounted = null
## 键盘/手柄导航半边（[method _build_layout] 时接线——它只持控件引用与回调）。
var _input_router: RefCounted = null
var _title_label: Label = null
var _balance_label: Label = null
var _realm_label: Label = null
var _status_label: Label = null
var _progress_label: Label = null
var _progress_fill: ColorRect = null
var _item_box: VBoxContainer = null
var _message_label: Label = null
var _meditate_button: Button = null
var _breakthrough_button: Button = null
var _leave_button: Button = null


func _init() -> void:
	name = "CultivationScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_actions_ = ActionsScript.new(self)
	_build_layout()


func _ready() -> void:
	_connect_realm_changed()
	refresh()


## 离屏时摘掉 GSM 信号订阅（GSM 是 Autoload、活得比本屏久——不摘会让它继续持有一个
## 指向已释放界面的 [Callable]）。
func _exit_tree() -> void:
	var store: Node = _gsm()
	if store == null or not store.has_signal(&"realm_changed"):
		return
	if store.is_connected(&"realm_changed", _on_realm_changed):
		store.disconnect(&"realm_changed", _on_realm_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# 对外：刷新与两个动作
# ═══════════════════════════════════════════════════════════════════════════════

## 重读修为 / 境界 / 灵石并刷新界面数字。[br]
## [br][b]每次动作后都调一次[/b]（不是只在 [method _ready] 读一遍）：打坐会改修为、
## 突破会改境界与上限，屏幕必须永远是当前状态的样子。[br]
## [br][b]系统缺失时不臆造[/b]：走 [method _present_unavailable] 的降级形态（可读的
## 中文提示 + 唯一可用的出口），而不是留一块空白或直接崩。
func refresh() -> void:
	var status: Dictionary = _actions_.call(&"status")
	if status.is_empty():
		_present_unavailable()
		return
	_present(int(status.get("current", 0)), int(status.get("max", 0)),
			int(status.get("realm", 0)), bool(status.get("can_break", false)))
	_ensure_focus()


# === 查询（测试断言用——不触及内部控件路径）==================================

## 标题文本。
func title_text() -> String:
	return _title_label.text


## 右上灵石行文本（「灵石：N」）。
func balance_text() -> String:
	return _balance_label.text


## 当前境界行文本（「当前境界：炼气期」）。
func realm_text() -> String:
	return _realm_label.text


## 修为进度行文本（「修为 100 / 1000」——数字由文字承载）。
func progress_text() -> String:
	return _progress_label.text


## 进度条填充比例（0.0-1.0——条是第二通道，文字才是主通道）。
func progress_ratio() -> float:
	return _progress_fill.anchor_right


## 突破状态行文本（可突破 / 修为不足 / 已达顶——中文，非机器码）。
func status_text() -> String:
	return _status_label.text


## 当前提示行文案（不可见时返回空串）。
func message_text() -> String:
	return _message_label.text if _message_label.visible else ""


## 「打坐」按钮文本（含增量说明）。
func meditate_text() -> String:
	return _meditate_button.text


## 「突破」按钮文本。
func breakthrough_text() -> String:
	return _breakthrough_button.text


## 「突破」按钮是否可点（修为未满 / 已达最高境界时为 false）。
func is_breakthrough_enabled() -> bool:
	return _breakthrough_button != null and not _breakthrough_button.disabled


## 「打坐」按钮是否可点（常驻可点——修为满了也会转成溢出池）。
func is_meditate_enabled() -> bool:
	return _meditate_button != null and not _meditate_button.disabled


## 键盘/手柄游标当前所在动作行（0 打坐 / 1 突破 / -1 无落点）。
func focused_index() -> int:
	return int(_input_router.call(&"focus_index"))


## 第 [param p_index] 个动作行是否持有键盘焦点。
func is_action_focused(p_index: int) -> bool:
	var button: Button = _item_box.get_child(p_index) as Button
	return button != null and button.has_focus()


## 动作行数（当前固定两行——打坐与突破）。
func action_count() -> int:
	return _item_box.get_child_count()


## 测试用：按下「打坐」（不依赖真实输入事件）。
func press_meditate() -> void:
	if _meditate_button != null:
		_meditate_button.emit_signal(&"pressed")


## 测试用：按下「突破」（不依赖真实输入事件）。[br]
## [b]禁用态同样走「点下去给原因」那条路[/b]——与真实鼠标点击同一条代码
## （真实点击由 [signal Control.gui_input] 送进来，见 [method _show_refusal]）。
func press_breakthrough() -> void:
	if _breakthrough_button == null:
		return
	if _breakthrough_button.disabled:
		_show_message(str(_actions_.call(&"refusal")))
		return
	_breakthrough_button.emit_signal(&"pressed")


## 测试用：按下「离开」。
func press_leave() -> void:
	if _leave_button != null:
		_leave_button.emit_signal(&"pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘 / 手柄导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——上下选行动 / 回车执行 / 取消返回主菜单，未映射的动作原样放行。[br]
## [br][b]本屏只做「消费即拦断」这一件事[/b]：游标怎么动、确认意味着什么全在
## [code]CultivationSceneInput[/code] 里（同商店面板把游标拆出去的口径）。
func _input(p_event: InputEvent) -> void:
	if not bool(_input_router.call(&"handle_event", p_event)):
		return
	get_viewport().set_input_as_handled()


## 境界变化——上限由 [code]CultivationSystem[/code] 在同一帧末重算（GDD §6），
## 本屏只把新数字读回来（见类文档「上限是帧末到账的」）。
func _on_realm_changed(_p_old_realm: int, _p_new_realm: int) -> void:
	refresh()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：两个动作
# ═══════════════════════════════════════════════════════════════════════════════

## 打坐——结算归 [code]CultivationActions[/code]，本屏只刷新 + 回执。[br]
## [br][b]结算后才刷新[/b]：修为与上限都在系统侧，先刷后算会把刚加的那次漏掉。
func _on_meditate_pressed() -> void:
	var message: String = str(_actions_.call(&"meditate"))
	refresh()
	_show_message(message)


## 突破——结算归 [code]CultivationActions[/code]（先问能不能，再请编排器动手）。[br]
## [br][b]成功才需要等帧末的上限重算[/b]：本屏订阅了 [code]realm_changed[/code]，
## 信号一到会自己再刷一次（见 [method _on_realm_changed]），这里只负责把当前画面
## 与回执写出来。
func _on_breakthrough_pressed() -> void:
	var message: String = str(_actions_.call(&"breakthrough"))
	refresh()
	_show_message(message)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：控件树
# ═══════════════════════════════════════════════════════════════════════════════

## 建控件树并接线（控件树见 [code]CultivationSceneLayout[/code]）。[br]
## [br][b]「离开」只接一个出口[/b]：骨架已把按钮的 [signal Button.pressed] 转发到
## 本屏的 [signal leave_requested]——再接一次按钮的 [signal Button.pressed] 会让
## 同一次点击发出两次转场请求。
func _build_layout() -> void:
	var parts: Dictionary = SceneLayoutScript.build(self, RulesScript.TEXT_TITLE,
			_on_meditate_pressed, _on_breakthrough_pressed)
	_title_label = parts.get("title_label")
	_balance_label = parts.get("balance_label")
	_item_box = parts.get("item_box")
	_message_label = parts.get("message_label")
	_leave_button = parts.get("leave_button")
	_realm_label = parts.get("realm_label")
	_status_label = parts.get("status_label")
	_progress_label = parts.get("progress_label")
	_progress_fill = parts.get("progress_fill")
	_meditate_button = parts.get("meditate_button")
	_breakthrough_button = parts.get("breakthrough_button")
	# 两句按钮词条在这里落一次：控件树不持有面向玩家的措辞（见
	# [code]CultivationSceneLayout[/code] 的说明），词条单点是 [code]CultivationViewRules[/code]。
	_meditate_button.text = RulesScript.meditate_line()
	_breakthrough_button.text = RulesScript.TEXT_BREAKTHROUGH
	leave_requested.connect(_request_leave)
	_input_router = SceneInputScript.new()
	_input_router.call(&"bind", parts, _activate_row, _request_leave, _show_refusal)
	_show_message(RulesScript.TEXT_HINT)


## 点到禁用行——把拒绝原因写进提示行（同坊市「买不起的行点下去仍给原因」）。[br]
## [br][b]只认左键按下[/b]：悬停 / 松开 / 右键都会送 [code]gui_input[/code]，
## 不筛会让鼠标划过灰按钮就弹一句「修为不足」。
func _show_refusal(p_event: InputEvent, p_button: Button) -> void:
	if p_button == null or not p_button.disabled:
		return
	if not (p_event is InputEventMouseButton):
		return
	var mouse: InputEventMouseButton = p_event
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	_show_message(str(_actions_.call(&"refusal")))


## 上架一份状态（数字与文本全来自规则层——本屏零数值计算、零措辞）。
func _present(p_current: int, p_max: int, p_realm: int, p_can_break: bool) -> void:
	_balance_label.text = RulesScript.balance_line(_actions_.call(&"ling_shi"))
	_realm_label.text = RulesScript.realm_line(p_realm)
	_progress_label.text = RulesScript.progress_line(p_current, p_max)
	_progress_fill.anchor_right = RulesScript.fill_ratio(p_current, p_max)
	_status_label.text = RulesScript.status_line(p_realm, p_current, p_can_break)
	_breakthrough_button.disabled = not RulesScript.allows_breakthrough(p_realm, p_can_break)


## 系统缺失时的降级形态（可读的中文原因 + 唯一可用的出口，不臆造数值）。
func _present_unavailable() -> void:
	_balance_label.text = RulesScript.balance_line(_actions_.call(&"ling_shi"))
	_realm_label.text = RulesScript.realm_line(0)
	_progress_label.text = RulesScript.progress_line(0, 0)
	_progress_fill.anchor_right = 0.0
	_status_label.text = RulesScript.TEXT_UNAVAILABLE
	_breakthrough_button.disabled = true
	_show_message(RulesScript.TEXT_UNAVAILABLE)
	_ensure_focus()


## 无游标时让导航半边复位（有游标则原地不动——见那一侧的说明）。
func _ensure_focus() -> void:
	_input_router.call(&"ensure_focus")


## 游标确认——复用按钮自身的 [signal Button.pressed]（鼠标与键盘一条实现）。
func _activate_row(p_index: int) -> void:
	var button: Button = _item_box.get_child(p_index) as Button
	if button != null and not button.disabled:
		button.emit_signal(&"pressed")


## 「离开」——经 [code]SceneManager[/code] 回主菜单（ADR-0005 唯一仲裁）。[br]
## [br][b]目的地固定是主菜单[/b]：本屏只从主菜单进入，故不存在「回哪一层」的分派。[br]
## [br][b]转场类型走 GAME_TO_MENU[/b]：音频矩阵的 [code]任意 → MAIN_MENU[/code] 行
## 由它索引（同坊市口径）。[br]
## [br][b]from 动态取当前场景[/b]：不写魔数（PauseMenu M-2 先例）。[br]
## [br][b]转场不可用时留在原地[/b]：把「按键失灵」变成一句看得见的回执。
func _request_leave() -> void:
	var sm: Node = SourcesScript.resolve(scene_manager, &"SceneManager")
	if sm == null or not sm.has_method(&"request_scene_change"):
		_show_message(RulesScript.TEXT_NO_SCENE_MANAGER)
		return
	var from_id: int = SceneManagerScript.SceneID.CULTIVATION
	if sm.has_method(&"get_current_scene_id"):
		from_id = int(sm.call(&"get_current_scene_id"))
	sm.call(&"request_scene_change", from_id, SceneManagerScript.SceneID.MAIN_MENU,
			SceneManagerScript.TransitionType.GAME_TO_MENU)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：信号接入与杂项
# ═══════════════════════════════════════════════════════════════════════════════

## 订阅 GSM 的 [code]realm_changed[/code]（上限重算到账后自己再刷一次）。[br]
## [br][b]连接顺序是有意的[/b]：[code]CultivationSystem[/code] 在 Autoload 启动时
## 就已连上同一信号，本屏后连——故本屏的处理函数跑在它之后，读到的是重算后的上限。
func _connect_realm_changed() -> void:
	var store: Node = _gsm()
	if store == null or not store.has_signal(&"realm_changed"):
		return
	if store.is_connected(&"realm_changed", _on_realm_changed):
		return
	store.connect(&"realm_changed", _on_realm_changed)


func _gsm() -> Node:
	return SourcesScript.resolve(gsm, &"GameStateManager")


func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()
