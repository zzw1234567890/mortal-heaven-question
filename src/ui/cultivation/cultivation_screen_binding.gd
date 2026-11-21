extends RefCounted
## CultivationScreenBinding —— 修炼室与[b]屏外系统[/b]的接线（从 [CultivationScreen] 拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「订阅谁、解绑谁、转场走哪个出口、灵石从哪读」
## 与「控件怎么排、游标怎么走、动作按下去调谁」是两件事——同
## [code]cultivation_scene_layout.gd[/code]（控件树）/[code]cultivation_scene_input.gd[/code]
## （导航）/[code]cultivation_actions.gd[/code]（玩法接入）/[code]cultivation_screen_view.gd[/code]
## （呈现）的拆因，本模块补齐「屏外接线」这一边。[br]
## [br][b]只接线，不做判断[/b]：本模块不认识修为、不碰控件——收到信号就转告屏幕
## （[method Node.refresh] / [method Node.show_message]），具体显示由屏幕那半边决定
## （零状态所有权，ADR-0031 §2）。[br]
## [br][b]生命周期分明[/b]：屏幕在 [method Node._ready] 调 [method bind]、在
## [method Node._exit_tree] 调 [method unbind]——GSM 与渡劫系统都是 Autoload、活得比屏幕久，
## 不解绑会让它们继续持有指向已释放界面的 [Callable]。
## [br][b]上限是帧末到账的[/b]：境界写入的 Cat 1 信号走 GSM 帧末缓冲，修为上限的重算由
## [code]CultivationSystem[/code] 订阅 [code]realm_changed[/code] 完成（GDD §6）——故
## [method _on_realm_changed] 只能把屏幕再刷一次，读到的是重算后的上限。[br]
##
## 来源: ADR-0005（导航唯一入口）、ADR-0021 §trigger_tribulation、ADR-0031 §2、
## design/gdd/cultivation-system.md §6、GSM 帧末缓冲既有契约、
## 先例 [code]cultivation_actions.gd[/code]（同形态的「持屏幕引用」协作模块）。

## 渡劫结果回流（把 [code]tribulation_succeeded[/code] / [code]tribulation_failed[/code]
## 变成一句中文回执）。
const FeedScript := preload("res://src/ui/cultivation/cultivation_tribulation_feed.gd")
## 措辞单点（转场不可用的回执句子从这里取）。
const RulesScript := preload("res://src/ui/cultivation/cultivation_view_rules.gd")
## 依赖解析（注入优先、否则 Autoload——与坊市 / 卡组编辑同口径）。
const SourcesScript := preload("res://src/ui/hud/deck_view_sources.gd")
## SceneManager 脚本常量——SceneID / TransitionType 枚举真理来源。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")

## 宿主屏幕（只持引用调它的公开出口——本模块不碰它的控件）。
var _screen: Node = null
## 渡劫成败回流接线（[method unbind] 时必须摘掉）。
var _feed: RefCounted = null


func _init(p_screen: Node) -> void:
	_screen = p_screen


# ═══════════════════════════════════════════════════════════════════════════════
# 订阅与解绑
# ═══════════════════════════════════════════════════════════════════════════════

## 进树时接上两路信号：GSM 的 [code]realm_changed[/code] 与渡劫系统的成败回流。[br]
## [br][b]GSM 连接顺序是有意的[/b]：[code]CultivationSystem[/code] 在 Autoload 启动时就已连上
## 同一信号，本模块后连——故屏幕的处理函数跑在它之后，读到的是重算后的上限。
func bind() -> void:
	_connect_realm_changed()
	_bind_tribulation_feed()


## 离屏时摘掉两路订阅（见类文档「生命周期分明」）。
func unbind() -> void:
	if _feed != null:
		_feed.call(&"unbind")
	var store: Node = _gsm()
	if store == null or not store.has_signal(&"realm_changed"):
		return
	if store.is_connected(&"realm_changed", _on_realm_changed):
		store.disconnect(&"realm_changed", _on_realm_changed)


# ═══════════════════════════════════════════════════════════════════════════════
# 对外：出口
# ═══════════════════════════════════════════════════════════════════════════════

## 「离开」——经 [code]SceneManager[/code] 回主菜单（ADR-0005 唯一仲裁）。[br]
## [br][b]目的地固定是主菜单[/b]：本屏只从主菜单进入，故不存在「回哪一层」的分派。[br]
## [br][b]转场类型走 GAME_TO_MENU[/b]：音频矩阵的 [code]任意 → MAIN_MENU[/code] 行由它
## 索引（同坊市口径）。[br]
## [br][b]from 动态取当前场景[/b]：不写魔数（PauseMenu M-2 先例）。[br]
## [br][b]转场不可用时留在原地[/b]：把「按键失灵」变成一句看得见的回执。
func request_leave() -> void:
	var sm: Node = SourcesScript.resolve(_field(&"scene_manager"), &"SceneManager")
	if sm == null or not sm.has_method(&"request_scene_change"):
		_screen.call(&"show_message", RulesScript.TEXT_NO_SCENE_MANAGER)
		return
	var from_id: int = SceneManagerScript.SceneID.CULTIVATION
	if sm.has_method(&"get_current_scene_id"):
		from_id = int(sm.call(&"get_current_scene_id"))
	sm.call(&"request_scene_change", from_id, SceneManagerScript.SceneID.MAIN_MENU,
			SceneManagerScript.TransitionType.GAME_TO_MENU)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：两路信号
# ═══════════════════════════════════════════════════════════════════════════════

## 境界变化——上限由 [code]CultivationSystem[/code] 在本帧末重算（GDD §6），屏幕只把新数字
## 读回来（见类文档「上限是帧末到账的」）。
func _on_realm_changed(_p_old_realm: int, _p_new_realm: int) -> void:
	_screen.call(&"refresh")


## 渡劫战结果回流——把结果写进提示行并[b]重刷一次数字[/b]。[br]
## [br][b]为什么要重刷[/b]：成功时境界与上限都变了、失败时修为被扣了，而这两笔写入发生在
## 渡劫结算那一帧（屏幕不在场，[code]realm_changed[/code] 也没连着它——场景已切走）。
## 不重刷就还显示着出发前的数字。[br]
## [br][b]刷新推迟到本帧末[/b]：渡劫结算发信号时状态还是 [code]SUCCESS[/code] /
## [code]FAILED[/code] 这些[b]瞬态[/b]（结算码发完信号才把状态收回
## [code]NOT_READY[/code]）——当场读会让按钮按「渡劫流程进行中」灰掉，且此后没有任何事件
## 再来纠正它。推到帧末读到的就是收尾后的状态。[br]
## [br][b]提示行不等帧[/b]：那句话只讲刚发生的事，与状态机无关。
func _on_tribulation_result(p_message: String) -> void:
	_screen.call(&"show_message", p_message)
	_screen.call_deferred(&"refresh")


## 订阅 GSM 的 [code]realm_changed[/code]。
func _connect_realm_changed() -> void:
	var store: Node = _gsm()
	if store == null or not store.has_signal(&"realm_changed"):
		return
	if store.is_connected(&"realm_changed", _on_realm_changed):
		return
	store.connect(&"realm_changed", _on_realm_changed)


## 接上渡劫成败回流（渡劫战在别的场景里打，结果信号回到本屏才看得到）。[br]
## [br][b]渡劫系统不可用时不订[/b]：此时屏幕走的是「渡劫系统不可用」的降级形态，那条路
## 根本触发不了渡劫，订了也只是留一个永不触发的连接。
func _bind_tribulation_feed() -> void:
	_feed = FeedScript.new()
	_feed.call(&"bind", SourcesScript.resolve(_field(&"tribulation_system"),
			&"TribulationSystem"), _on_tribulation_result)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：取屏幕上的注入字段
# ═══════════════════════════════════════════════════════════════════════════════

## 现取宿主屏幕上的注入字段（不缓存——「进树前注入即被采信」靠的就是每次现读）。[br]
## [br][b]为什么用 [method Object.get] 而不是直接属性访问[/b]：宿主是动态类型
## （[code]Control[/code]），字段名在编译期不可见；字符串取法也是同目录其它协作模块的
## 既有口径。
func _field(p_name: StringName) -> Variant:
	if _screen == null or not is_instance_valid(_screen):
		return null
	return _screen.get(p_name)


func _gsm() -> Node:
	return SourcesScript.resolve(_field(&"gsm"), &"GameStateManager")
