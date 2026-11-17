extends RefCounted
## PauseMenuHandlers —— 暂停菜单[b]「按钮按下之后做什么」[/b]（从 [PauseMenu] 拆出）。[br]
## [br][b]为什么单独一处[/b]：[code]pause_menu.gd[/code] 要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「点存档要写哪一格、点卡组要弹什么面板、
## 点退出要弹哪个确认框」与「控件路径长什么样、开合怎么配对」是两件事
## （同 [PauseMenuActions] / [PauseMenuState] / [PauseMenuPauseCycle] 的拆因）。[br]
## [br][b]为什么处理器不能一走了之[/b]：[code]PauseMenu.tscn[/code] 的
## [code][connection][/code] 指向根节点，方法必须长在 [PauseMenu] 上——所以那边
## 留一层同名的瘦转发（一行），知识全在本模块。[br]
## [br][b]反馈行归本模块[/b]：存档 / 读档的结果要翻成一行带颜色的字，而
## 「成功用松石青、失败用朱砂红」是本项目对「正向 / 警报」的统一编码
## （先例 [code]lingshi_deck_bar[/code]）——两处各写一份颜色常量必然漂移。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不缓存任何玩法数据，进度行与
## 存档载荷都由动作层现取现算；它只写自己那一行 UI 文本。[br]
##
## 来源: design/ux/pause-menu.md（§Interaction Map 对照表 / §Accessibility
## 确认弹窗防误触）、ADR-0031 §2、hud Story 005。

## 确认框结果取值镜像——[code]PauseMenuConfirm[/code] 是真理来源。
const OUTCOME_SAVE_EXIT: int = 0
const OUTCOME_LEAVE: int = 1
## 确认框类型镜像（两个按钮各自对应一种）。
const CONFIRM_SAVE_EXIT: int = 0
const CONFIRM_RETURN: int = 1

## 宿主（[PauseMenu] 本体——各编排层的入口都在它身上）。
var _host: Control = null
## 反馈行控件（由宿主下发——路径只在宿主里写一遍）。
var _status_label: Label = null


## 绑定宿主与反馈行（宿主 [code]_ready[/code] 后调一次；重复调用覆盖）。
func bind(p_host: Control, p_status_label: Label) -> void:
	_host = p_host
	_status_label = p_status_label


## 反馈行成功态色——[code]PauseMenu.COLOR_STATUS_OK[/code] 是真理来源（对外配色
## 契约，本模块转发不抄字面量；两处各写一份颜色必然漂移）。
func _color_ok() -> Color:
	return _host.COLOR_STATUS_OK


## 反馈行失败态色——同上，真理来源 [code]PauseMenu.COLOR_STATUS_FAIL[/code]。
func _color_fail() -> Color:
	return _host.COLOR_STATUS_FAIL


# ═══════════════════════════════════════════════════════════════════════════════
# 菜单项
# ═══════════════════════════════════════════════════════════════════════════════

## 继续游戏 / 遮罩点击——收起菜单。
func close_menu() -> void:
	_host.call(&"request_close")


## 查看卡组——打开只读卡组查看面板（见 [PauseMenuDeckView]）。[br]
## [br][b]信号保留[/b]：本按钮此前只发导航请求信号、全库零消费者；面板现在落在
## 宿主树里，[signal PauseMenu.deck_view_requested] 仍照发一次——它是「玩家看了
## 卡组」这一动作的既有上报口（分析事件口径见 design/ux/pause-menu.md §Events
## Fired 的 [code]CARD_DECK_VIEWED[/code]），不是面板的开关。
func open_deck_view() -> void:
	clear_status()
	_host.emit_signal(&"deck_view_requested")
	_host.call(&"get_deck_host").call(&"open")


## 系统设置——发导航请求（界面本体归 main-menu epic，Out of Scope）。
func request_settings() -> void:
	_host.emit_signal(&"settings_requested")


## 存档——成功给「已存档」，失败给原因（磁盘满 / 校验不过 / 依赖缺失）。[br]
## [br][b]失败不关菜单、不退出[/b]：玩家留在菜单里能再试一次或换个动作，
## 比静默丢档强（动作层返回失败文案，本层只负责显示）。
func save_now() -> void:
	var outcome: Dictionary = _actions().call(&"save_now")
	show_status(str(outcome.get("message", "")), bool(outcome.get("ok", false)))


## 读档——打开槽位选择面板（复用主菜单那份 [LoadSlotPanel]）。[br]
## [br]列表每次现取（[method PauseMenuActions.loadable_entries]）——停留期间
## 槽位可能已被刚写的存档改变。
func open_load_panel() -> void:
	clear_status()
	_actions().call(&"open_load_panel", _host)


## 玩家在读档面板选中一格——面板已自行收起（先收再报意图）。[br]
## [br][b]成功才解除暂停[/b]：动作层在能续玩时已发出转场请求，转场管线不含暂停
## 恢复职责，冻结态下新场景会停在冻结帧；失败则留在菜单里给一句交代。
func load_slot_chosen(p_slot_type: int, p_slot_id: int) -> void:
	var outcome: Dictionary = _actions().call(&"load_slot", p_slot_type, p_slot_id)
	if bool(outcome.get("navigated", false)):
		_host.call(&"_release_pause")
		return
	show_status(str(outcome.get("message", "")), false)


## 覆盖层「返回」后的收尾——清掉上一条反馈，把焦点还给菜单默认按钮。[br]
## [br][b]焦点必须回锚[/b]（design/ux/pause-menu.md §Interaction Map 战斗中特殊
## 规则「关闭后回到暂停菜单」）：面板按钮一隐藏，键盘焦点就落在不可见的控件上，
## 方向上键按不动、回车还会打到看不见的按钮（4.6 双焦点下鼠标不受影响）。
## 回锚走 [method PauseMenuState.focus_default]（跳过隐藏/置灰者——战斗中
## 「保存并退出」是隐藏的，硬抓它等于把焦点扔回一个看不见的按钮上）。
func restore_focus() -> void:
	clear_status()
	_state().call(&"focus_default")


## 保存并退出（GAP-5 裁决 + 二次确认）——先弹确认框；确认后才存档并离开。[br]
## [br][b]为什么不在按下时就存[/b]：这是不可逆动作（存档后结束本次会话），
## 无障碍要求防误触（design/ux/pause-menu.md §Accessibility）。
func confirm_save_exit() -> void:
	clear_status()
	_state().call(&"request_confirm", CONFIRM_SAVE_EXIT)


## 返回主菜单（GAP-5 裁决 + 二次确认）——先弹确认框。确认框里的三键对应：
## 确认 = 先存档再离开；不保存 = 直接离开（自动存档仍会顺手存一次底）；
## 取消 / ESC = 留在菜单。
func confirm_return() -> void:
	clear_status()
	_state().call(&"request_confirm", CONFIRM_RETURN)


## 确认框结果落地（[signal PauseMenuConfirm.outcome_chosen] 的唯一消费者）。
## 「确认之后走哪条退出链」是变体编排层的知识，本模块只做转发。
func resolve_outcome(p_outcome: int) -> void:
	_state().call(&"resolve_outcome", p_outcome)


# ═══════════════════════════════════════════════════════════════════════════════
# 覆盖层开合（ESC 分层与关闭序列共用的两条链）
# ═══════════════════════════════════════════════════════════════════════════════

## 读档面板若开着则收起；返回「是否真的收掉了」（ESC 分层的第二层）。[br]
## [br][b]为什么要这一层包装[/b]：分层判定归 [PauseMenuState]（它不持面板引用），
## 面板开合归动作层——包一层让两边都不必知道对方的细节。
func close_load_panel_if_open() -> bool:
	if not bool(_actions().call(&"is_load_panel_open")):
		return false
	_actions().call(&"close_load_panel")
	return true


## 卡组查看面板若开着则收起；返回「是否真的收掉了」（ESC 分层的第三层）。[br]
## [br][b]压在读档面板之上[/b]：两个覆盖层互斥（各自从菜单按钮进），但顺序写死成
## 「先收最上面那个」才不会被将来新增的覆盖层插队打乱（同 [method PauseMenuState.handle_esc]
## 的分层口径）。面板收起自己——本方法只报「收掉了没有」，焦点回锚走信号那条路。
func close_deck_view_if_open() -> bool:
	return bool(_host.call(&"get_deck_host").call(&"close_if_open"))


# ═══════════════════════════════════════════════════════════════════════════════
# 关闭序列
# ═══════════════════════════════════════════════════════════════════════════════

## 解除暂停并收起菜单（关闭与「转场前离开」两条路径共用）。[br]
## [br][b]两段[/b]：先收本组件树下的覆盖层（确认框 / 卡组面板——留一个「开着」的
## 覆盖层在隐藏的菜单里，下次打开会看到上一次的残影，状态串味），再走
## [method PauseMenuPauseCycle.release] 的五步逆序（模糊 → 音频 → 暂停 → 隐藏
## → pop 锁，[b]pop 锁在最后[/b]）。[br]
## [br][b]顺序不可反[/b]（ADR-0031 §1.1）：转场管线不含「恢复暂停」的职责，
## 冻结态下发起转场，新场景会停在冻结帧。
func release_pause() -> void:
	_state().call(&"close_confirm")
	close_deck_view_if_open()
	_host.call(&"get_cycle").call(&"release")


# ═══════════════════════════════════════════════════════════════════════════════
# 反馈行
# ═══════════════════════════════════════════════════════════════════════════════

## 探索进度行刷新（GAP-2 降级裁决）——「层 N」由动作层现读 GSM 求得
## （零状态所有权：不缓存副本——ADR-0031 §2）。
func refresh_progress_row() -> void:
	var label: Label = _host.get("_progress_label")
	if label != null:
		label.text = str(_actions().call(&"progress_text"))


## 反馈行显示（存档 / 读档结果）。[br]
## [br][param p_ok] 决定颜色档（松石青「正向」/ 朱砂红「警报」）——文案本身
## 已含原因（错误码），颜色只是让玩家不用读完就知道成没成。
## [br][b]不靠颜色单独承载信息[/b]（.claude/rules/ui-code.md 色盲模式强制项）：
## 成败在文案里就说得出来，颜色只是加速。
func show_status(p_text: String, p_ok: bool) -> void:
	if _status_label == null or not is_instance_valid(_status_label):
		return
	_status_label.text = p_text
	_status_label.add_theme_color_override(&"font_color",
			_color_ok() if p_ok else _color_fail())


## 清空反馈行（打开菜单 / 再次发起动作时——上一条结果与这一次无关）。
func clear_status() -> void:
	if _status_label != null and is_instance_valid(_status_label):
		_status_label.text = ""


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 动作编排层（每次现取——宿主懒建，且注入引用可能在启动后才到位）。
func _actions() -> RefCounted:
	return _host.call(&"get_actions")


## 场景变体 / 二次确认编排层（同上）。
func _state() -> RefCounted:
	return _host.call(&"get_state")
