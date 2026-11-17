extends RefCounted
## PauseMenuDeckHost —— 暂停菜单里[b]只读卡组面板[/b]的挂载与开合（从 PauseMenu 拆出）。[br]
## [br][b]为什么单独一处[/b]：[code]pause_menu.gd[/code] 要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「面板实例怎么建、依赖怎么透传、开合怎么
## 配对」与「按钮怎么摆、转场怎么发」是两件事（同 [PauseMenuPauseCycle] /
## [PauseMenuState] / [PauseMenuActions] 的拆因）。[br]
## [br][b]为什么挂在宿主节点树下[/b]：菜单隐藏 / 释放时面板跟着走，不必单独管生命期
## （先例 [LoadSlotPanel] 挂在暂停菜单本体）。[br]
## [br][b]为什么懒建[/b]：卡组面板是菜单树下的第 4 层覆盖，绝大多数会话一次都不会
## 打开，没必要让每个暂停菜单都背一套控件树（同 [PauseMenuState] 懒建确认框的理由）。[br]
## [br][b]依赖每次现取[/b]：宿主在 [code]_ready[/code] 之后才拿到 HUD 的注入
## （[code]_setup_pause_menu[/code]），只认构造那一刻会让面板永远读不到卡组。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块只持控件引用与三个只读依赖的透传，
## 不缓存任何玩法数据。[br]
##
## 来源: design/ux/pause-menu.md（§Interaction Map 战斗中特殊规则「只读模式」）、
## design/ux/deck-editing-ui.md（§多入口到达）、ADR-0031 §1/§2。

## 面板本体（纯代码构建，见 [PauseMenuDeckView]）。
const DeckViewScript := preload("res://src/ui/hud/pause_menu_deck_view.gd")

## 宿主（[PauseMenu] 本体——依赖注入与焦点回锚的来源）。
var _host: Control = null
## 面板实例（懒建一次，见类文档「为什么懒建」）。
var _view: Control = null


## 绑定宿主（宿主 [code]_ready[/code] 后调一次；重复调用覆盖）。
func bind(p_host: Control) -> void:
	_host = p_host


## 打开面板（宿主「查看卡组」按钮的落地）。[br]
## [br][b]依赖每次现取现传[/b]：宿主注入值可能在首次打开之后才变（测试替换）。[br]
## [br][b]返回[/b]：面板实例；宿主缺失时 null（不崩——接线没完成不该变崩溃）。
func open() -> Control:
	var view: Control = _ensure_view()
	if view == null:
		return null
	view.set(&"deck_system", _host.get("deck_system"))
	view.set(&"card_system", _host.get("card_system"))
	view.set(&"combat_system", _host.get("combat_system"))
	view.call(&"open")
	return view


## 面板若开着则收起；返回「是否真的收掉了」（ESC 分层的第三层）。[br]
## [br][b]为什么返回布尔[/b]：[method PauseMenuState.handle_esc] 靠它判断「这一层
## 吃掉了没有」——false 就往下退一层（读档面板 → 菜单）。
func close_if_open() -> bool:
	if not is_open():
		return false
	_view.call(&"close")
	return true


## 面板是否处于打开态。
func is_open() -> bool:
	return _view != null and is_instance_valid(_view) and bool(_view.get("visible"))


## 面板实例（未建过时为 null——测试查询用，不触发建树）。
func view() -> Control:
	return _view if _view != null and is_instance_valid(_view) else null


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 建面板并接回宿主（只建一次；重复调用返回既有实例）。[br]
## [br][b]焦点回锚走信号[/b]：面板只报「我要退出了」，焦点是菜单的知识。
func _ensure_view() -> Control:
	if _view != null and is_instance_valid(_view):
		return _view
	if _host == null or not is_instance_valid(_host):
		return null
	_view = DeckViewScript.new()
	_view.connect(&"back_requested", Callable(_host, &"_on_deck_view_back"))
	_host.add_child(_view)
	return _view
