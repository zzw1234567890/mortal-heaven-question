extends Control
## DeckEditingScreen —— 卡组编辑界面（纯代码构建 UI）。[br]
## [br][b]为什么需要它[/b]：[code]SceneManager.SCENE_PATHS[/code] 里
## [code]DECK_EDITING[/code] 一直指向一个占位场景（深色底 + 「该界面尚未开放」），
## 玩家没有任何地方能改自己的卡组——[code]DeckEditingSystem[/code] 的增删 API、
## [code]deck.slots[/code] 与自动存档链路都已就绪，缺的只是这一层界面。[br]
## [br][b]两栏形态[/b]：左「收藏」右「卡组」——增删就是「从左挑一张搬到右边」
## 「从右边挑一张搬回左边」，两栏并排才看得出这件事。左栏[b]按模板合并[/b]（同名副本
## 是一条数量），右栏[b]逐实例[/b]（我选了哪几张）；见
## [code]deck_editing_layout.gd[/code] / [code]deck_collection_rows.gd[/code]。[br]
## [br][b]加入前先判定，被拒不弹窗[/b]（本轮硬性要求）：同名上限 / 卡组上限 /
## 副本用尽三条都在按下的那一刻给出中文原因，写在提示行里——弹窗会打断正在连点的手，
## 而「为什么加不进去」是看一眼就够的信息。判定归
## [code]DeckBuildRules[/code]。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本界面不持有卡组、不写 GSM——增删经
## [code]DeckEditingActions[/code] 调 [code]DeckEditingSystem[/code] 的统一入口，
## 界面的每一栏都在 [method refresh] 时[b]现读[/b]（刚加进去的那张必须立刻出现在右栏）。[br]
## [br][b]保存即出口[/b]：「保存并返回」写一次盘然后回到打开它的地方
## （[code]DeckEditingEntry[/code] 记的来路）。落盘沿用自动存档口径
## （[code]SaveLoadSystem.auto_save[/code]——项目里唯一的无人值守写盘点）。[br]
## [br][b]模板是异步来的[/b]：卡牌模板由 [code]CardSystem._ready[/code] 用
## [code]load_threaded_request[/code] 分批装载（每帧 10 个），而本界面 [code]_ready[/code]
## 只刷一次。装载完成前右栏会按 [code]DeckViewRows[/code] 的「取不到模板就不出行」少几张
## ——所以本界面接上 [code]templates_loaded[/code]，在装载收尾时自己再刷一次
## （见 [method _connect_templates_loaded]）。少了这条接线，那几行会永远缺着，
## 而统计行照样写着「卡组 6/20」。[br]
## [br][b]事件层级 = _input[/b]：与商店 / 背包 / 卡组查看面板同源理由——焦点落在
## [Button] 上时引擎的内置焦点导航会在 GUI 阶段先吃掉方向键；[code]_input[/code] 排在
## GUI 派发之前，是唯一能拦住的层。出口仍沿用 [code]PlaceholderScene[/code] 的
## 口径（返回经 [code]SceneManager.request_scene_change[/code]，ADR-0005）。[br]
## [br][b]渲染与读数在 [DeckEditingView][/b]：本文件只管「游标怎么动、按下调谁、
## 怎么返回」——本文件因此守得住 300 行软上限。[br]
##
## 来源: design/ux/deck-editing-ui.md、design/gdd/deck-editing-system.md §5/§6、
## ADR-0023（统一增删入口）、ADR-0005、ADR-0031 §1/§2、.claude/rules/ui-code.md、
## 先例 [code]shop_panel_screen.gd[/code] / [code]pause_menu_deck_view.gd[/code]。

## 骨架构建、导航、取数、渲染读数、编排、来路意图（各司其职——见各模块类文档）。
const LayoutScript := preload("res://src/ui/deck_editing/deck_editing_layout.gd")
const NavScript := preload("res://src/ui/deck_editing/deck_editing_navigator.gd")
const ViewScript := preload("res://src/ui/deck_editing/deck_editing_view.gd")
const ActionsScript := preload("res://src/ui/deck_editing/deck_editing_actions.gd")
const EntryScript := preload("res://src/ui/deck_editing/deck_editing_entry.gd")
## 模板就绪守望（异步装载完成后自己再刷一次——见那边类文档）。
const WatchScript := preload("res://src/ui/deck_editing/deck_editing_template_watch.gd")
## 依赖解析（注入优先、否则 Autoload——与 [code]deck_view_sources.gd[/code] 同口径）。
const SourcesScript := preload("res://src/ui/hud/deck_view_sources.gd")
## 消费输入的包装（Esc 返回会把自己摘走——见 [method UiInputConsume.mark_handled]）。
const ConsumeScript := preload("res://src/ui/shared/ui_input_consume.gd")
const TEXT_TITLE: String = "📜 卡组编辑"

## 依赖注入（null 时按 /root 找 Autoload——同 [code]InventoryModel[/code] 的回退口径）。
var deck_system: Node = null
var card_system: Node = null
var gsm: Node = null
var save_load: Node = null
var scene_manager: Node = null

## 已接上「模板装载完成」信号的守望（换了一个卡牌系统则改接新的那一个——
## 见 [method DeckEditingTemplateWatch.watch]）。
var _watch: RefCounted = null

## 两栏的渲染与读数（本界面不自己持控件路径——见类文档）。
var _view: RefCounted = null
var _navigator: RefCounted = null
var _actions: RefCounted = null


func _init() -> void:
	name = "DeckEditingScreen"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_layout()
	_navigator = NavScript.new()
	_navigator.call(&"bind", _rows_of, _activate_row, _request_back, _on_column_changed)
	_navigator.connect(&"focus_changed", _on_focus_changed)


func _ready() -> void:
	_actions = ActionsScript.new(
			SourcesScript.resolve(deck_system, &"DeckEditingSystem"),
			SourcesScript.resolve(card_system, &"CardSystem"),
			SourcesScript.resolve(gsm, &"GameStateManager"),
			SourcesScript.resolve(save_load, &"SaveLoadSystem"))
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

## 重读卡组与收藏、重建两栏、复位游标。[br]
## [br][b]两栏都重建[/b]：加一张会让左栏的「卡组中 N/M 张」与右栏的行数同时变
## （删一张同理）——只刷一边会让另一边的读数停在上一帧。[br]
## [br][b]清空提示行[/b]：上一次的「同名已达上限」与刚刚这次操作无关，留着会让玩家
## 以为这次也被拒了。[br]
## [br][b]卡组与上限都现取[/b]：缓存会让手上这份与系统里那份分叉（刚加进去的那张不在
## 手上，判定就会算错张数）。
func refresh() -> void:
	_connect_templates_loaded()
	_view.rebuild(SourcesScript.resolve(gsm, &"GameStateManager"),
			SourcesScript.resolve(card_system, &"CardSystem"),
			_deck_ids(), _deck_limit(), _on_collection_row_pressed, _on_deck_row_pressed)
	_navigator.call(&"reset")
	# 栏标题的加亮要跟着重刷（换栏时行控件被重建，焦点环会重画，标题色不会自己回来）
	_view.highlight_column(active_column())


# === 查询（测试断言用——不触及内部控件路径）==================================

## 左栏（收藏）行数。
func collection_count() -> int:
	return _view.count_of(NavScript.COLUMN_COLLECTION)


## 右栏（卡组）行数。
func deck_count() -> int:
	return _view.count_of(NavScript.COLUMN_DECK)


## 左栏全部行的文本（渲染实证）。
func collection_texts() -> Array:
	return _view.texts_of(NavScript.COLUMN_COLLECTION)


## 右栏全部行的文本。
func deck_texts() -> Array:
	return _view.texts_of(NavScript.COLUMN_DECK)


## 某一栏的全部行控件（渲染实证的取数口）。[br]
## [br][b]为什么要有它[/b]：[method collection_texts] / [method payload_at] 回答的是
## 「行里写了什么」与「这一行是哪张卡」，都答不了「这一行玩家看不看得见」——
## 那要看控件自己的 [member Control.is_visible_in_tree] 与高度。
func rows_of(p_column: int) -> Array:
	return _view.rows_of(p_column)


## 某一栏第 [param p_index] 行的控件（越界为 null）。
func row_at(p_column: int, p_index: int) -> Node:
	return _view.row_at(p_column, p_index)


## 统计行文案（「卡组 N/上限」）。
func summary_text() -> String:
	return _view.summary_text()


## 提示行文案（不可见时返回空串）。
func message_text() -> String:
	return _view.message_text()


## 某一栏的空态提示是否可见（空的时候才说——不空时说「还没有卡」是在说谎）。
func empty_hint_visible(p_column: int) -> bool:
	return _view.empty_hint_visible(p_column)


## 某一栏的空态提示文案（看不到时返回空串——调用方据此区分「没提示」与「提示是空的」）。
func empty_hint_text(p_column: int) -> String:
	return _view.empty_hint_text(p_column)


## 当前活跃栏（0 = 收藏，1 = 卡组）。
func active_column() -> int:
	return int(_navigator.call(&"column"))


## 当前栏内的游标下标（-1 = 无可选行）。
func focused_index() -> int:
	return int(_navigator.call(&"focus_index"))


## 某行当前是否持有键盘焦点（焦点可见的实证）。
func is_row_focused(p_column: int, p_index: int) -> bool:
	return _view.is_row_focused(p_column, p_index)


## 某一栏第 [param p_index] 行的载荷（测试直接喂给动作层用）。
func payload_at(p_column: int, p_index: int) -> Dictionary:
	return _view.payload_at(p_column, p_index)


## 测试用：确认某一栏的第 [param p_index] 行（不依赖真实输入事件）。[br]
## [b]禁用行不发意图[/b]——与真实按钮行为一致（见 [method DeckEditingView.press_row]）。
func press_row(p_column: int, p_index: int) -> void:
	_view.press_row(p_column, p_index)


## 测试用：换栏（不依赖真实输入事件）。
func select_column(p_column: int) -> void:
	_navigator.call(&"set_column", p_column)


## 测试用：按下「保存并返回」。
func press_save_exit() -> void:
	_on_save_exit_pressed()


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘 / 手柄导航（见类文档「事件层级 = _input」）
# ═══════════════════════════════════════════════════════════════════════════════

## 输入事件——左右换栏 / 上下选牌 / 回车增删 / 取消返回，其余原样放行。[br]
## [br][b]「保存并返回」保有焦点时不吃确认键[/b]：此时 Enter 应触发那个按钮本身
## （玩家用 Tab/鼠标把焦点放过去，意图明确），游标确认让位（同商店面板口径）。[br]
## [br][b]消费即拦断[/b]：向上不再经过引擎焦点导航，也顺带挡住
## [code]InputManager[/code] 的 Esc → 暂停菜单。
func _input(p_event: InputEvent) -> void:
	if _save_has_focus() and p_event.is_action_pressed(&"ui_accept"):
		return
	if not bool(_navigator.call(&"handle_event", p_event)):
		return
	# Esc 那条路会经导航器发出转场（change_scene_to_file 当场把本屏摘走），
	# 回到这里时本节点已不在树上——消费走空安全包装，见那边类文档。
	ConsumeScript.mark_handled(self)


## 游标变化——把键盘焦点搬到新栏的新行（焦点环由样式的 focus 状态随焦点绘制）。
func _on_focus_changed(p_column: int, p_index: int) -> void:
	var row: Node = _view.row_at(p_column, p_index)
	if row is Button and not (row as Button).disabled:
		(row as Button).grab_focus()


## 换栏——当前栏的标题加亮（另一栏压暗）。[br]
## [br][b]不动任何数据[/b]：换栏只是注意力移动（瞬态交互标志，ADR-0031 §2.1 豁免）。
func _on_column_changed(p_column: int) -> void:
	_view.highlight_column(p_column)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 建控件树并接线（骨架来自 [DeckEditingLayout]，渲染读数归 [DeckEditingView]）。
func _build_layout() -> void:
	var parts: Dictionary = LayoutScript.build(self, TEXT_TITLE)
	_view = ViewScript.new(parts)
	var save_button: Button = parts.get("save_button")
	save_button.pressed.connect(_on_save_exit_pressed)


## 接上卡牌系统的「模板装载完成」信号——装载完成后自己再刷一次两栏。[br]
## [br][b]为什么必须有这条接线[/b]：见类文档「模板是异步来的」——没有它，
## 在装载完成前进来的一次刷新就是最终结果，缺的行永远缺着。[br]
## [br][b]为什么挂在这里而不是 [code]_ready[/code][/b]：依赖是注入的，注入发生在进树前
## ——[code]_ready[/code] 那一刻 [member card_system] 未必已经赋好；刷新是「界面开始
## 读数据」的统一时机，接在这一处才不会漏掉后注入的场景。
func _connect_templates_loaded() -> void:
	if _watch == null:
		_watch = WatchScript.new()
	_watch.call(&"watch", SourcesScript.resolve(card_system, &"CardSystem"), refresh)


## 行数组（游标的取数口——每次现取不缓存：刷新会换一批控件）。
func _rows_of(p_column: int) -> Array:
	return _view.rows_of(p_column)


## 游标确认（转发到视图的行按下出口——鼠标与键盘一条实现）。
func _activate_row(p_column: int, p_index: int) -> void:
	_view.press_row(p_column, p_index)


## 左栏某行被按下——加入卡组。[br]
## [br][b]按下后无条件刷新[/b]：被拒时左栏的「卡组中 N/M 张」没变、置灰状态没变，
## 重刷只是让屏幕与存档保持同一个答案（比「记得在哪些分支刷新」更不容易漏）。
func _on_collection_row_pressed(p_index: int) -> void:
	_apply(_actions.call(&"add_card",
			_view.payload_at(NavScript.COLUMN_COLLECTION, p_index), _deck_ids(), _deck_limit()))


## 右栏某行被按下——移出卡组。
func _on_deck_row_pressed(p_index: int) -> void:
	_apply(_actions.call(&"remove_card",
			_view.payload_at(NavScript.COLUMN_DECK, p_index), _deck_ids()))


## 「保存并返回」——落盘一次再回到打开它的地方（唯一出口）。[br]
## [br][b]保存失败也照走[/b]：卡组已经改在 GSM 里了，卡在这一屏只会让玩家更困惑；
## 回执文案由动作层给出（「还没开局」与「写盘失败」分开说）。[br]
## [br][b]返回要经 SceneManager[/b]（ADR-0005 唯一仲裁），来路取
## [code]DeckEditingEntry[/code]（一次性——取走即清）。
func _on_save_exit_pressed() -> void:
	var saved: Dictionary = _actions.call(&"save") if _actions != null else {"message": ""}
	if not _leave():
		# 转场不可用：留在原地并把回执显示出来（比静默什么都不发生可读）
		_view.show_message(str(saved.get("message", "")))


## 请求返回（Esc / 手柄取消键）——[b]不落盘[/b]，与「保存并返回」区分开。[br]
## [br][b]为什么不顺手存一次[/b]：这一屏的每次增删都已经写进 GSM 了，但没落盘；
## 「Esc 直接退出且不保存」是给「我改错了想原样退出去」留的一条路——顺手存会把
## 它变成「改错了也照样存」，那是两个相反的意思。提示行里写清了这一点。
func _request_back() -> void:
	_leave()


## 经 SceneManager 回打开它的地方（ADR-0005）。[br]
## [br][b]返回[/b]：是否真的发出了转场请求（转场不可用时 false——调用方据此把回执
## 显示出来，而不是让玩家觉得按键失灵）。
func _leave() -> bool:
	var sm: Node = SourcesScript.resolve(scene_manager, &"SceneManager")
	if sm == null or not sm.has_method(&"request_scene_change"):
		return false
	var from_id: int = 0
	if sm.has_method(&"get_current_scene_id"):
		from_id = int(sm.call(&"get_current_scene_id"))
	var target: int = EntryScript.take_origin()
	sm.call(&"request_scene_change", from_id, target, EntryScript.transition_for(target))
	return true


## 应用一次动作的结果（成功 → 刷新两栏；失败 → 只把原因写进提示行）。[br]
## [br][b]被拒不弹窗打断[/b]（本轮硬性要求）：原因是看一眼就够的信息，写在提示行里
## 玩家可以立刻再选一张。
func _apply(p_result: Variant) -> void:
	var result: Dictionary = p_result if p_result is Dictionary else {}
	if bool(result.get("ok", false)):
		refresh()
	_view.show_message(str(result.get("message", "")))


## 卡组实例 ID 列表（现取不缓存——缓存会让手上这份与系统里那份分叉，
## 刚加进去的那张不在手上，判定就会算错张数）。
func _deck_ids() -> Array:
	return SourcesScript.deck_ids(deck_system, &"DeckEditingSystem")


## 卡组上限（[code]DeckEditingSystem.get_deck_limit()[/code]；系统不可用时给 20——
## 与那边的默认值同源，不写 0 让统计行显示「卡组 6/0」）。
func _deck_limit() -> int:
	var deck: Node = SourcesScript.resolve(deck_system, &"DeckEditingSystem")
	if deck == null or not deck.has_method(&"get_deck_limit"):
		return 20
	return int(deck.call(&"get_deck_limit"))


## 「保存并返回」是否持有键盘焦点（未挂载时为 false——不臆造）。
func _save_has_focus() -> bool:
	var save_button: Button = _view.save_button
	return save_button != null and is_instance_valid(save_button) and save_button.has_focus()
