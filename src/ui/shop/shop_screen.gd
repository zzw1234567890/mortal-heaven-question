extends Control
## ShopScreen —— 主菜单坊市界面（纯代码构建 UI）。[br]
## [br][b]为什么需要它[/b]：[code]SceneManager.SCENE_PATHS[/code] 里
## [code]SHOP[/code] 一直指向一个占位场景（深色底 + 「坊市交易功能正在打造中」），
## 玩家从主菜单点进去只能看到一个返回按钮。而坊市的[b]结算链路早已存在[/b]
## ——[code]ExplorationShop[/code] 的「校验 → 建实例 → 扣灵石 → 入收藏」四步与
## 面板控件树（[code]shop_panel_layout.gd[/code]）都是现成的，缺的只是
## 「一块不依赖节点载荷的常驻货架 + 一个挂得上去的场景」。[br]
## [br][b]与探索侧商店的分工[/b]：控件树（怎么摆、焦点环长什么样）与游标
## （方向键怎么动）[b]完全复用[/b]探索侧那两份模块；本文件只管「场景级」的三件事
## ——货源（[ShopLogic] 从 [ShopGoodsCatalog] 取常驻货架）、进出（经
## [code]SceneManager[/code] 回主菜单）、以及把购买结果回填到提示行。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本界面不持有灵石、不写收藏——购买全部
## 经 [ShopLogic]（它再经 [code]ResourceSystem[/code] / [code]CardSystem[/code] /
## [code]GSM[/code]），界面的每一行都在 [method refresh] 时[b]现读[/b]（刚买完那行
## 的可负担态必须立刻刷新）。[br]
## [br][b]为什么买不起的行点下去仍给中文原因[/b]：[code]ShopPanelLayout.add_item_row[/code]
## 把买不起的行设成 [code]disabled[/code]（禁用的 [Button] 不发 [signal Button.pressed]），
## 于是「点了没反应」——玩家无从知道自己差多少灵石。本界面给每行另外接上
## [signal Control.gui_input]：点到禁用行时调一次 [method ShopLogic.purchase]，
## 把它的[b]拒绝原因[/b]（「灵石不足：需要 25，当前 10」）写进提示行。这条路径
## 一分钱都不会动——[method ShopLogic.purchase] 的校验全在动手之前。[br]
## [br][b]模板是异步来的[/b]：卡牌模板由 [code]CardSystem._ready[/code] 用
## [code]load_threaded_request[/code] 分批装载（每帧 10 个），而本界面
## [code]_ready[/code] 只刷一次。[method ShopLogic.rows] 对查不到模板的条目
## [b]直接剔除[/b]（不上架一条没有名字与稀有度的货）——故装载完成前进来的一次
## 刷新会让货架空掉，且此后没有任何东西会再刷第二次。本界面因此接上
## [code]templates_loaded[/code]，在装载收尾时自己再刷一次（见
## [method _connect_templates_loaded]）。[br]
## [br][b]事件层级 = _input[/b]：与商店面板 / 卡组编辑同源理由——焦点落在
## [Button] 上时引擎的内置焦点导航会在 GUI 阶段先吃掉方向键；[code]_input[/code]
## 排在 GUI 派发之前，是唯一能拦住的层。消费走
## [method Viewport.set_input_as_handled]（顺带挡住 [code]InputManager[/code] 的
## Esc → 暂停菜单）。[br]
## [br][b]文案本地化豁免[/b]：项目暂无本地化系统——本文件的面向玩家句子集中在
## [constant TEXT_*]，本地化 epic 入库后替换为 key（同 S16/S17 口径）。
##
## 来源: design/gdd/deck-editing-system.md §3 坊市买卖、
## design/ux/deck-editing-ui.md §坊市-买卡、ADR-0005（导航唯一入口）、
## ADR-0031 §1/§2、.claude/rules/ui-code.md（双输入 + 色盲可读）、先例
## [code]deck_editing_screen.gd[/code]（同形态的独立场景 + 复用布局模块）、
## [code]shop_panel_screen.gd[/code]（同一套控件树与游标）。

## 玩家点了「离开」（[code]ShopPanelLayout.build[/code] 把「离开」按钮的
## [signal Button.pressed] 转发到这个信号上——本屏必须[b]自己声明[/b]它：
## [method Object.emit_signal] 对未声明的信号名不报编译错、只在运行时静默失败
## （[code]ERR_UNAVAILABLE[/code]），届时按钮点了没反应）。[br]
## [br][b]本屏自己消费这个信号[/b]（见 [method _build_layout]）：唯一的出口是
## [method _request_leave]。若改成「另外把按钮的 pressed 接到出口上」，同一次点击会
## 经两条路各发一次转场请求。
signal leave_requested

## 控件树构建与配色 / 配色与焦点环（探索侧既有模块——本界面一个字都不重造）。
const LayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")
## 键盘/手柄游标（纯逻辑，不碰控件树）。
const NavScript := preload("res://src/ui/exploration/shop_panel_navigator.gd")
## 货架与购买结算（Feature 层——本界面只调它的公开方法）。
const LogicScript := preload("res://src/feature/shop/shop_logic.gd")
## 依赖解析（注入优先、否则 Autoload——与卡组编辑同口径）。
const SourcesScript := preload("res://src/ui/hud/deck_view_sources.gd")
## 模板就绪守望（异步装载完成后自己再刷一次——见类文档「模板是异步来的」）。
const WatchScript := preload("res://src/ui/deck_editing/deck_editing_template_watch.gd")
## SceneManager 脚本常量——SceneID / TransitionType 枚举真理来源
## （preload 而非 Autoload 全局名——同 placeholder_scene.gd 口径）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")

## 标题与提示词条。
const TEXT_TITLE: String = "🏪 坊市"
const TEXT_EMPTY: String = "货架空空——坊市今日无货可售。"
const TEXT_HINT: String = "↑ ↓ 选货，回车买入，Esc 或「离开」返回主菜单。"
const TEXT_LEAVE_HAS_FOCUS: String = "按回车离开坊市。"
## 余额行前缀（面板右上——与探索侧「灵石：N」同措辞，玩家不必学两套）。
const TEXT_BALANCE: String = "灵石：%d"

## 依赖注入（null 时按 /root 找 Autoload——同卡组编辑的回退口径）。[br]
## [br][b]逻辑层也可注入[/b]：测试用「空货架 / 定值余额」的替身构造本界面时，
## 把 [member shop_logic] 先赋好再挂进树即可——[member _logic_] 只在它为 null 时
## 才自建。
var resource_system: Node = null
var card_system: Node = null
var gsm: Node = null
var scene_manager: Node = null
var shop_logic: RefCounted = null
## 已接上「模板装载完成」信号的守望（换了一个卡牌系统则改接新的那一个）。
var _watch: RefCounted = null
## 实际使用的逻辑层（注入优先，否则 [method _ready] 时自建）。
var _logic_: RefCounted = null
## 键盘/手柄游标。
var _navigator: RefCounted = null
## 本次上架的行数（与控件数一致——测试断言用）。
var _item_count: int = 0
## 货架行下标 → 逻辑层货架下标（模板缺失的条目被 [method ShopLogic.rows] 剔除后，
## 屏幕上第 N 行不再是货架第 N 件——故把对应关系单独记一份，购买时按它回传）。
var _row_to_goods: Array[int] = []

var _title_label: Label = null
var _balance_label: Label = null
var _item_box: VBoxContainer = null
var _message_label: Label = null
var _leave_button: Button = null


func _init() -> void:
	name = "ShopScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	_navigator = NavScript.new()
	_navigator.call(&"bind", _rows_of, _activate_row, _request_leave)
	_navigator.connect(&"focus_changed", _on_focus_changed)


func _ready() -> void:
	if shop_logic == null:
		shop_logic = LogicScript.new(
				SourcesScript.resolve(resource_system, &"ResourceSystem"),
				SourcesScript.resolve(card_system, &"CardSystem"),
				SourcesScript.resolve(gsm, &"GameStateManager"))
	_logic_ = shop_logic
	refresh()


## 离屏时拆掉模板守望（信号持有的是守望对象，不拆会在界面释放后仍被卡牌系统引用）。[br]
## [br][b]卡牌系统是 Autoload、活得比界面久[/b]：装载完成时它照样会发信号——
## 不拆的话守望对象就白拿着一个指向已释放界面的 [Callable]。
func _exit_tree() -> void:
	if _watch != null:
		_watch.call(&"release")
		_watch = null


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 重读余额与货架、重建行、复位游标。[br]
## [br][b]重建而非就地改[/b]：买走一件后「买不起的那几行」可能变成买得起（不会，
## 只会更买不起）——但反过来余额增加时（将来售卡）就地改就漏了；重建一次的成本
## 是几行控件，换来的是「屏幕永远是当前状态的样子」。[br]
## [br][b]清空提示行[/b]：上一次的「灵石不足」与刚刚这次刷新无关，留着会让玩家
## 以为这次也被拒了。[br]
## [br][b]游标复位到首个可买行[/b]：买完一件后停在原地会让游标压在一行买不起的
## 货上（游标路径跳过禁用行，但复位那一刻的落点是明确的）。
func refresh() -> void:
	_connect_templates_loaded()
	var logic: RefCounted = _logic_
	if logic == null:
		return
	_present(int(logic.call(&"balance")), logic.call(&"rows"))
	_navigator.call(&"reset")
	_focus_fallback()


# === 查询（测试断言用——不触及内部控件路径）==================================

## 当前货架行数。
func item_count() -> int:
	return _item_count


## 全部货架行的按钮文本（渲染实证——含价格与「灵石不足」标记）。
func item_texts() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		if child is Button:
			out.append((child as Button).text)
	return out


## 某行是否可买（买不起的行 [code]disabled[/code]——与探索侧商店同口径）。
func is_item_enabled(p_index: int) -> bool:
	var button: Button = _item_box.get_child(p_index) as Button
	return button != null and not button.disabled


## 当前提示行文案（不可见时返回空串）。
func message_text() -> String:
	return _message_label.text if _message_label.visible else ""


## 余额行文案（「灵石：N」）。
func balance_text() -> String:
	return _balance_label.text


## 键盘/手柄游标当前所在行（-1 = 无可选行，此时焦点在「离开」上）。
func focused_index() -> int:
	return int(_navigator.call(&"focus_index"))


## 某行当前是否持有键盘焦点（焦点可见的实证）。
func is_item_focused(p_index: int) -> bool:
	var button: Button = _item_box.get_child(p_index) as Button
	return button != null and button.has_focus()


## 「离开」按钮是否持有键盘焦点（空货架 / 全买不起时的落点）。
func is_leave_focused() -> bool:
	return _leave_button != null and is_instance_valid(_leave_button) \
			and _leave_button.has_focus()


## 测试用：按下第 [param p_index] 行（不依赖真实输入事件）。[br]
## [b]禁用行同样走「点下去给原因」那条路[/b]——与真实鼠标点击同一条代码
## （真实点击由 [signal Control.gui_input] 送进来，见 [method _on_row_gui_input]）。
func press_item(p_index: int) -> void:
	var button: Button = _item_box.get_child(p_index) as Button
	if button == null:
		return
	if button.disabled:
		_show_message(_refusal_for(int(_row_to_goods[p_index])))
		return
	button.emit_signal(&"pressed")


## 测试用：按下「离开」。
func press_leave() -> void:
	if _leave_button != null:
		_leave_button.emit_signal(&"pressed")


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘 / 手柄导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——上下选货 / 回车买入 / 取消离开，未映射的动作原样放行。[br]
## [br][b]「离开」按钮保有焦点时不吃确认键[/b]：此时 Enter 应触发那个按钮本身
## （玩家用 Tab/鼠标把焦点放过去，意图明确），游标确认让位（同商店面板口径）。[br]
## [br][b]消费即拦断[/b]：向上不再经过引擎焦点导航，也顺带挡住
## [code]InputManager[/code] 的 Esc → 暂停菜单。
func _input(p_event: InputEvent) -> void:
	if is_leave_focused() and p_event.is_action_pressed(&"ui_accept"):
		return
	if not bool(_navigator.call(&"handle_event", p_event)):
		return
	get_viewport().set_input_as_handled()


## 游标变化——把键盘焦点搬到新行（焦点环由样式的 focus 状态随焦点绘制）。
func _on_focus_changed(p_index: int) -> void:
	var button: Button = _item_box.get_child(p_index) as Button
	if button != null and not button.disabled:
		button.grab_focus()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：购买 / 进出
# ═══════════════════════════════════════════════════════════════════════════════

## 行被按下——买下并刷新。[br]
## [br][b]按下后无条件刷新[/b]：成功时余额与全列可负担态都变了；失败时刷新只是
## 让屏幕与存档保持同一个答案（比「记得在哪些分支刷新」更不容易漏）。
func _on_row_pressed(p_index: int) -> void:
	_purchase(int(_row_to_goods[p_index]))


## 点到禁用行——把拒绝原因写进提示行（见类文档「为什么买不起的行点下去仍给原因」）。[br]
## [br][b]只认左键按下[/b]：悬停 / 松开 / 右键都会送 [code]gui_input[/code]，
## 不筛会让鼠标划过一行灰货就弹一句「灵石不足」。
func _on_row_gui_input(p_event: InputEvent, p_button: Button,
		p_index: int) -> void:
	if p_button == null or not p_button.disabled:
		return
	if not (p_event is InputEventMouseButton):
		return
	var mouse: InputEventMouseButton = p_event
	if not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	_show_message(_refusal_for(int(_row_to_goods[p_index])))


## 走一次购买并把结果写进提示行（界面对结果不作判断——文案由逻辑层给出）。[br]
## [br][b]成功才刷新[/b]：失败路径不改任何状态，重建一遍行只会把游标弹回首个可买行、
## 把玩家刚点的位置弄丢。
func _purchase(p_goods_index: int) -> void:
	var logic: RefCounted = _logic_
	if logic == null:
		return
	var result: Dictionary = logic.call(&"purchase", p_goods_index)
	if bool(result.get("ok", false)):
		refresh()
	_show_message(str(result.get("reason", "")))


## 一次「不改变状态」的拒绝原因——复用购买路径的校验（校验全在动手之前，
## 禁用的行必然过不了其中一道，故这里得到的就是玩家该看到的那句话）。[br]
## [br][b]为什么调 purchase 而不是自己判一遍[/b]：判断与措辞只有一处来源；
## 自己再写一遍「余额 < 价格 → 灵石不足」就是第二份真理，且数字格式会漂移。
func _refusal_for(p_goods_index: int) -> String:
	var logic: RefCounted = _logic_
	if logic == null:
		return ""
	var result: Dictionary = logic.call(&"purchase", p_goods_index)
	return str(result.get("reason", ""))


## 「离开」——经 [code]SceneManager[/code] 回主菜单（ADR-0005 唯一仲裁）。[br]
## [br][b]目的地固定是主菜单[/b]：坊市这一屏只从主菜单进入（探索侧商店是节点图上的
## overlay，不是这个场景），故不存在「回哪一层」的分派——写死目的地比留一个
## 永远只有一个取值的分派表更直白。[br]
## [br][b]转场类型走 GAME_TO_MENU[/b]：音频矩阵的 [code]任意 → MAIN_MENU[/code] 行
## （1.5s 淡出/淡入）由它索引；错用别的类型会把主菜单 BGM 接到游戏内过渡参数上。[br]
## [br][b]from 动态取当前场景[/b]：不写魔数（PauseMenu M-2 先例）。[br]
## [br][b]转场不可用时留在原地[/b]：把「按键失灵」变成一句看得见的回执。
func _request_leave() -> void:
	var sm: Node = SourcesScript.resolve(scene_manager, &"SceneManager")
	if sm == null or not sm.has_method(&"request_scene_change"):
		_show_message("场景管理器不可用，暂时无法离开坊市。")
		return
	var from_id: int = SceneManagerScript.SceneID.SHOP
	if sm.has_method(&"get_current_scene_id"):
		from_id = int(sm.call(&"get_current_scene_id"))
	sm.call(&"request_scene_change", from_id, SceneManagerScript.SceneID.MAIN_MENU,
			SceneManagerScript.TransitionType.GAME_TO_MENU)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：控件树
# ═══════════════════════════════════════════════════════════════════════════════

## 建控件树并接线（骨架来自 [ShopPanelLayout]——本界面只管往列表里填行）。[br]
## [br][b]「离开」只接一个出口[/b]：[code]ShopPanelLayout.build[/code] 已把按钮的
## [signal Button.pressed] 转发到本屏的 [signal leave_requested]，故这里只接那一个
## ——再接一次按钮的 [signal Button.pressed] 会让同一次点击发出两次转场请求。[br]
## [br][b]为什么先传本屏的名字进 build[/b]：[method Object.emit_signal] 对未声明的
## 信号名只在运行时静默失败（[code]ERR_UNAVAILABLE[/code]），故签名必须对上本屏
## 真正声明过的那个（见 [signal leave_requested]）。
func _build_layout() -> void:
	var parts: Dictionary = LayoutScript.build(self, TEXT_TITLE)
	_title_label = parts.get("title_label")
	_balance_label = parts.get("balance_label")
	_item_box = parts.get("item_box")
	_message_label = parts.get("message_label")
	_leave_button = parts.get("leave_button")
	leave_requested.connect(_request_leave)


## 上架——清空旧行、按逻辑层给出的行重建、写余额与提示。[br]
## [br][b]行数口径[/b]：[method ShopLogic.rows] 已剔除模板查不到的条目，
## [member _row_to_goods] 记下「屏幕第 N 行 = 货架第几件」的对应关系。
func _present(p_balance: int, p_rows: Array) -> void:
	_balance_label.text = TEXT_BALANCE % p_balance
	_clear_items()
	_item_count = 0
	if p_rows.is_empty():
		_show_message(TEXT_EMPTY)
		return
	_show_message(TEXT_HINT)
	for raw: Variant in p_rows:
		var row: Dictionary = raw
		var button: Button = LayoutScript.add_item_row(
				_item_box, row, _item_count, _on_row_pressed)
		var row_index: int = _item_count
		button.gui_input.connect(
				func(event: InputEvent) -> void: _on_row_gui_input(event, button, row_index))
		_row_to_goods.append(int(row.get("index", row_index)))
		_item_count += 1


## 无候选行时把焦点落到「离开」——否则空货架 / 全买不起时焦点掉出本屏，
## 玩家按回车什么都不发生（Tab 也未必跳得回来）。[br]
## [br][b]提示行也换一句[/b]：此时屏幕上的唯一动作是离开，提示写成「选货」是在指路
## 到没有的东西上。
func _focus_fallback() -> void:
	if int(_navigator.call(&"focus_index")) >= 0:
		return
	if is_leave_focused():
		return
	if _leave_button != null and is_instance_valid(_leave_button):
		_leave_button.grab_focus()
		if _item_count == 0:
			_show_message(TEXT_EMPTY)
		else:
			_show_message(TEXT_LEAVE_HAS_FOCUS)


## 清空货架行（含 [member _row_to_goods] 的对应关系——它与行同生共死）。
func _clear_items() -> void:
	_row_to_goods.clear()
	for child: Node in _item_box.get_children():
		_item_box.remove_child(child)
		child.queue_free()


## 当前行控件数组（游标的取数口——每次现取不缓存：刷新会换一批控件）。
func _rows_of() -> Array:
	var out: Array = []
	for child: Node in _item_box.get_children():
		out.append(child)
	return out


## 游标确认——复用按钮自身的 [signal Button.pressed]（鼠标与键盘一条实现）。
func _activate_row(p_index: int) -> void:
	press_item(p_index)


## 接上卡牌系统的「模板装载完成」信号——装载完成后自己再刷一次（见类文档
## 「模板是异步来的」）。[br]
## [br][b]挂在这里而不是 [code]_ready[/code][/b]：依赖是注入的，注入发生在进树前
## ——[code]_ready[/code] 那一刻 [member card_system] 未必已经赋好；刷新是「界面
## 开始读数据」的统一时机，接在这一处才不会漏掉后注入的场景。
func _connect_templates_loaded() -> void:
	if _watch == null:
		_watch = WatchScript.new()
	_watch.call(&"watch", SourcesScript.resolve(card_system, &"CardSystem"), refresh)


func _show_message(p_text: String) -> void:
	_message_label.text = p_text
	_message_label.visible = not p_text.strip_edges().is_empty()
