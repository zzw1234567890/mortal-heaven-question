extends Control
## CultivationScreen —— 修炼室（[code]SceneID.CULTIVATION = 10[/code]，纯代码构建 UI）。[br]
## [br][b]为什么需要它[/b]：[code]SceneManager.SCENE_PATHS[/code] 里
## [code]CULTIVATION[/code] 一直指向占位场景，玩家从主菜单点「修为养成」进去只能看到
## 一个返回按钮。而「打坐涨修为」与「修为满则渡劫 / 突破」几条链路[b]早已存在[/b]：
## [code]CultivationSystem.gain_cultivation[/code] 是修为获取的唯一入口，
## [code]RealmSystem.realm_up[/code] 是境界写入的唯一编排器（ADR-0010），
## [code]TribulationSystem[/code] 是渡劫状态机；缺的只是一个把它们接给玩家的常驻场景。[br]
## [br][b]门面而非再造[/b]（ADR-0031 §2 零状态所有权）：本屏不持有也不推算任何玩法数值
## ——控件树在 [code]CultivationSceneLayout[/code]、呈现与读取在
## [code]CultivationScreenView[/code]、措辞在 [code]CultivationViewRules[/code]、
## 语义判定在 [code]CultivationTribulationGate[/code]、玩法接入在
## [code]CultivationActions[/code]、屏外接线在 [code]CultivationScreenBinding[/code]、
## 渡劫回流在 [code]CultivationTribulationFeed[/code]。本屏只管「把这几块接起来、
## 把回执交出去」。[br]
## [br][b]上限是帧末到账的[/b]：境界写入的 Cat 1 信号走 GSM 帧末缓冲，而修为上限的重算由
## [code]CultivationSystem[/code] 订阅 [code]realm_changed[/code] 完成（GDD §6）——
## 故 [method refresh] 刚跑完时上限可能仍是旧值。本屏订阅同一信号，信号一到再刷一次
## （见 [code]CultivationScreenBinding[/code]）。测试若要断言「上限跟着变」，等帧。[br]
## [br][b]事件层级 = _input[/b]：与坊市 / 洞府面板同源理由——焦点落在 [Button] 上时引擎的
## 内置焦点导航会在 GUI 阶段先吃掉方向键；[code]_input[/code] 排在 GUI 派发之前，是唯一能
## 拦住的层。消费走 [method Viewport.set_input_as_handled]（顺带挡住
## [code]InputManager[/code] 的 Esc → 暂停菜单）。[br]
## [br][b]文案本地化豁免[/b]：项目暂无本地化系统——面向玩家的句子集中在
## [code]CultivationViewRules[/code]（本屏不自己措辞）。[br]
##
## 来源: design/gdd/cultivation-system.md §4/§5/§6、design/gdd/tribulation-system.md
## §1/§2、ADR-0010 §realm_up 编排器、ADR-0021 §trigger_tribulation、ADR-0031 §2/§4、
## ADR-0005（导航唯一入口）、.claude/rules/ui-code.md（双输入 + 色盲可读）、
## 先例 [code]shop_screen.gd[/code] / [code]meditation_panel_screen.gd[/code]。

## 玩家点了「离开」（[code]ShopPanelLayout.build[/code] 把「离开」按钮的
## [signal Button.pressed] 转发到这个信号上——本屏必须[b]自己声明[/b]它：
## [method Object.emit_signal] 对未声明的信号名不报编译错、只在运行时静默失败）。[br]
## [br][b]本屏自己消费这个信号[/b]（见 [member _binding]）：唯一的出口是「回主菜单」。
## 若改成「另外把按钮的 pressed 接到出口上」，同一次点击会经两条路各发一次转场请求。
signal leave_requested

## 本屏的控件树（底色 + 中段信息块 + 两个动作行；骨架复用探索侧商店布局）。
const SceneLayoutScript := preload("res://src/ui/cultivation/cultivation_scene_layout.gd")
## 键盘/手柄导航与焦点搬运（游标复用探索侧商店的那一份）。
const SceneInputScript := preload("res://src/ui/cultivation/cultivation_scene_input.gd")
## 呈现与读取半边（写 Label / 按钮态、给测试读文本——本屏不直接持控件）。
const ViewScript := preload("res://src/ui/cultivation/cultivation_screen_view.gd")
## 措辞单点（标题 / 提示行）。
const RulesScript := preload("res://src/ui/cultivation/cultivation_view_rules.gd")
## 玩法接入半边（读状态 / 打坐 / 渡劫-突破——每次现取屏幕上的注入字段）。
const ActionsScript := preload("res://src/ui/cultivation/cultivation_actions.gd")
## 屏外接线（GSM 信号订阅 / 渡劫回流 / 回主菜单出口——本屏不自己订）。
const BindingScript := preload("res://src/ui/cultivation/cultivation_screen_binding.gd")
## 消费输入的包装（Esc 返回会把自己摘走——见 [method UiInputConsume.mark_handled]）。
const ConsumeScript := preload("res://src/ui/shared/ui_input_consume.gd")

## 依赖注入（null 时按 /root 找 Autoload——同坊市 / 卡组编辑的回退口径）。[br]
## [br][b]接入半边现读这些字段[/b]：故「进树前注入」即可被采信——[member _actions_] /
## [member _binding] 构造时只拿本屏引用，不缓存系统句柄。
var cultivation_system: Node = null
var realm_system: Node = null
var tribulation_system: Node = null
var gsm: Node = null
var scene_manager: Node = null
## 境界表覆盖（空 = 用 [code]RealmSystem.realm_table[/code] 真配置）。[br]
## [br][b]为什么是个注入点[/b]：「不需要渡劫的境界」真配置里一行都没标（GDD 只在故事线
## 留了一处例外）——测试要覆盖「这一行仍是『突破』」只能注入一张翻过键的同构表。
var tribulation_table: Dictionary = {}

## 玩法接入半边（[method _init] 时构造——它只持本屏引用）。
var _actions_: RefCounted = null
## 屏外接线（[method _init] 时构造——它只持本屏引用）。
var _binding: RefCounted = null
## 呈现与读取半边（[method _build_layout] 时构造——只持控件引用）。
var _view: RefCounted = null
## 键盘/手柄导航半边（[method _build_layout] 时接线——它只持控件引用与回调）。
var _input_router: RefCounted = null
## 动作行容器与「离开」按钮（焦点搬运与按行取原因用——其余控件归 [member _view]）。
var _item_box: VBoxContainer = null
var _leave_button: Button = null


func _init() -> void:
	name = "CultivationScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_actions_ = ActionsScript.new(self)
	_binding = BindingScript.new(self)
	_build_layout()


func _ready() -> void:
	_binding.call(&"bind")
	refresh()


## 离屏时摘掉 GSM 与渡劫系统的信号订阅（两者都是 Autoload、活得比本屏久——不摘会让
## 它们继续持有一个指向已释放界面的 [Callable]）。
func _exit_tree() -> void:
	_binding.call(&"unbind")


# ═══════════════════════════════════════════════════════════════════════════════
# 对外：刷新与两个动作
# ═══════════════════════════════════════════════════════════════════════════════

## 重读修为 / 境界 / 灵石并刷新界面数字。[br]
## [br][b]每次动作后都调一次[/b]（不是只在 [method _ready] 读一遍）：打坐会改修为、
## 渡劫/突破会改境界与上限，屏幕必须永远是当前状态的样子。[br]
## [br][b]系统缺失时不臆造[/b]：走降级形态（可读的中文提示 + 唯一可用的出口）。[br]
## [br][b]屏外接线也会调它[/b]（[code]realm_changed[/code] 与渡劫回流的帧末重刷），
## 故它是公开出口而非私有方法。
func refresh() -> void:
	var status: Dictionary = _actions_.call(&"status")
	if status.is_empty():
		_view.call(&"present_unavailable", _ling_shi())
	else:
		_view.call(&"present", status, _ling_shi())
	_ensure_focus()


## 把一句话写进提示行（屏外接线转达渡劫结果用）。
func show_message(p_text: String) -> void:
	_view.call(&"show_message", p_text)


# === 查询（测试断言用——转交呈现半边，本屏不再持一份控件表）==================

func title_text() -> String: return str(_view.call(&"title_text"))
func balance_text() -> String: return str(_view.call(&"balance_text"))
func realm_text() -> String: return str(_view.call(&"realm_text"))
func progress_text() -> String: return str(_view.call(&"progress_text"))
func status_text() -> String: return str(_view.call(&"status_text"))
func message_text() -> String: return str(_view.call(&"message_text"))
func meditate_text() -> String: return str(_view.call(&"meditate_text"))


## 进度条填充比例（0.0-1.0——条是第二通道，文字才是主通道）。
func progress_ratio() -> float: return float(_view.call(&"progress_ratio"))


## 第二动作行（打坐之外那一行）的按钮文本——需渡劫的境界是「渡劫」，否则「突破」。
func breakthrough_text() -> String: return str(_view.call(&"breakthrough_text"))


## 第二动作行当前的语义（[code]&"tribulation"[/code] / [code]&"breakthrough"[/code] /
## [code]&"none"[/code]——由判定层给出，测试据此断言「按下去调的是谁」）。
func action_kind() -> StringName:
	return StringName(_actions_.call(&"kind"))


## 当前是否勾了「越阶渡劫」（GDD §6 主动选项——透传给渡劫入口共用件）。
func is_cross_realm_checked() -> bool:
	return bool(_view.call(&"cross_realm_checked"))


## 「越阶渡劫」勾选框此刻是否露出（该境界不可越阶时藏起来）。
func is_cross_realm_visible() -> bool:
	return bool(_view.call(&"cross_realm_visible"))


## 「越阶渡劫」勾选框此刻的文案（测试据它断言「开 / 关」两种说法）。
func cross_realm_text() -> String:
	return str(_view.call(&"cross_realm_text"))


## 测试用：切换「越阶渡劫」勾选框（不依赖真实输入事件）。
func toggle_cross_realm() -> void:
	_view.call(&"toggle_cross_realm")


## 第二动作行是否可点（修为未满 / 已达最高境界 / 渡劫不可用时为 false）。
func is_breakthrough_enabled() -> bool:
	return bool(_view.call(&"is_breakthrough_enabled"))


## 「打坐」按钮是否可点（到顶时关闭——修为无处可用）。
func is_meditate_enabled() -> bool:
	return bool(_view.call(&"is_meditate_enabled"))


## 键盘/手柄游标当前所在动作行（0 打坐 / 1 第二行 / -1 无落点）。
func focused_index() -> int:
	return int(_input_router.call(&"focus_index"))


## 第 [param p_index] 个动作行是否持有键盘焦点。
func is_action_focused(p_index: int) -> bool:
	var button: Button = _item_box.get_child(p_index) as Button
	return button != null and button.has_focus()


## 动作行数（当前固定两行——打坐与第二动作）。
func action_count() -> int:
	return _item_box.get_child_count()


## 第 [param p_index] 个动作行的控件（测试投递真实鼠标事件用——「点灰行给原因」那条路
## 走的是 [signal Control.gui_input]，只有拿到控件本身才验得了）。
func row_button(p_index: int) -> Button:
	return _view.call(&"row_button", p_index) as Button


## 测试用：按下「打坐」（不依赖真实输入事件）。[br]
## [br][b]禁用态同样走「点下去给原因」那条路[/b]——到顶时这一行会关掉，玩家点下去该看到
## 「修为无处可用」，而不是一片安静（同 [method press_breakthrough] 的口径）。
func press_meditate() -> void:
	_press_row(0)


## 测试用：按下第二动作行（渡劫 / 突破，不依赖真实输入事件）。[br]
## [br][b]禁用态同样走「点下去给原因」那条路[/b]——与真实鼠标点击同一条代码
## （真实点击由 [signal Control.gui_input] 送进来，见 [method _show_refusal]）。
func press_breakthrough() -> void:
	_press_row(1)


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
	# Esc 那条路会发出回主菜单的转场（当场把本屏摘走），回到这里时本节点已不在
	# 树上——消费走空安全包装，见那边类文档。
	ConsumeScript.mark_handled(self)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：两个动作
# ═══════════════════════════════════════════════════════════════════════════════

## 按第 [param p_index] 行（禁用行给原因、可点行走它自己的 [signal Button.pressed]）。
func _press_row(p_index: int) -> void:
	var button: Button = row_button(p_index)
	if button == null:
		return
	if button.disabled:
		_view.call(&"show_message", str(_actions_.call(&"refusal", p_index)))
		return
	button.emit_signal(&"pressed")


## 打坐——结算归 [code]CultivationActions[/code]，本屏只刷新 + 回执。[br]
## [br][b]结算后才刷新[/b]：修为与上限都在系统侧，先刷后算会把刚加的那次漏掉。
func _on_meditate_pressed() -> void:
	var message: String = str(_actions_.call(&"meditate"))
	refresh()
	show_message(message)


## 第二动作行——语义与结算都归 [code]CultivationActions[/code]（渡劫那条路触发后由它请求
## 转场；本屏只刷新 + 回执）。[br]
## [br][b]成功才需要等帧末的上限重算[/b]：屏外接线订阅了 [code]realm_changed[/code]，
## 信号一到会自己再刷一次。[br]
## [br][b]渡劫触发后本屏即将被转场释放[/b]：渡劫那一路的最终画面由回流接线在回来时重刷
## （见 [code]CultivationScreenBinding[/code]）。
func _on_breakthrough_pressed() -> void:
	var message: String = str(_actions_.call(&"breakthrough", is_cross_realm_checked()))
	refresh()
	show_message(message)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：控件树
# ═══════════════════════════════════════════════════════════════════════════════

## 建控件树并接线（控件树见 [code]CultivationSceneLayout[/code]）。[br]
## [br][b]「离开」只接一个出口[/b]：骨架已把按钮的 [signal Button.pressed] 转发到本屏的
## [signal leave_requested]——再接一次按钮会让同一次点击发出两次转场请求。[br]
## [br][b]控件引用分两处持有[/b]：呈现与读取要用的归 [member _view]，导航与焦点要用的
## （容器 + 离开按钮）留在这里——同一件事不会有两份引用表。
func _build_layout() -> void:
	var parts: Dictionary = SceneLayoutScript.build(self, RulesScript.TEXT_TITLE,
			_on_meditate_pressed, _on_breakthrough_pressed)
	_item_box = parts.get("item_box")
	_leave_button = parts.get("leave_button")
	_view = ViewScript.new(parts)
	leave_requested.connect(_request_leave)
	_input_router = SceneInputScript.new()
	_input_router.call(&"bind", parts, _activate_row, _request_leave, _show_refusal)


## 点到禁用行——把拒绝原因写进提示行（同坊市「买不起的行点下去仍给原因」）。[br]
## [br][b]只认左键按下[/b]：悬停 / 松开 / 右键都会送 [code]gui_input[/code]，不筛会让鼠标
## 划过灰按钮就弹一句「修为不足」。[br]
## [br][b]原因按行取[/b]：动作行不止一个会灰（到顶时打坐也灰），说错行的理由比不说还糟
## ——行号由控件自己在容器里的位置定，不另存一份映射。
func _show_refusal(p_event: InputEvent, p_button: Button) -> void:
	if p_button == null or not p_button.disabled:
		return
	if not (p_event is InputEventMouseButton):
		return
	var mouse: InputEventMouseButton = p_event
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	_view.call(&"show_message", str(_actions_.call(&"refusal", p_button.get_index())))


## 无游标时让导航半边复位（有游标则原地不动——见那一侧的说明）。
func _ensure_focus() -> void:
	_input_router.call(&"ensure_focus")


## 游标确认——复用按钮自身的 [signal Button.pressed]（鼠标与键盘一条实现）。
func _activate_row(p_index: int) -> void:
	var button: Button = _item_box.get_child(p_index) as Button
	if button != null and not button.disabled:
		button.emit_signal(&"pressed")


## 「离开」——转交屏外接线（那里的 [code]SceneManager[/code] 出口，ADR-0005 唯一仲裁）。
func _request_leave() -> void:
	_binding.call(&"request_leave")


## 当前灵石（只读——本屏不持有资源，[code]ResourceSystem[/code] 才是写入口）。
func _ling_shi() -> int:
	return int(_actions_.call(&"ling_shi"))
