extends RefCounted
## PauseMenuState —— 暂停菜单的[b]场景变体[/b]与[b]二次确认 / 退出[/b]编排
## （从 PauseMenu 拆出）。[br]
## [br][b]为什么单独一处[/b]：[code]pause_menu.gd[/code] 已贴 300 行软上限
## （.claude/docs/coding-standards.md），而「哪个场景藏哪个按钮、确认框什么时候弹、
## 确认之后走哪条退出链、ESC 先退哪一层」与「锁怎么配对、模糊动画怎么放」是两件事
## （同 [code]pause_menu_actions.gd[/code] 的拆因）。[br]
## [br][b]职责一：场景变体[/b]（design/ux/pause-menu.md §States & Variants）——
## 战斗中 / 商店事件中「保存并退出」隐藏（不可存档），探索中全部可用。判定本身是
## 纯函数，在 [PauseMenuLayout]；本模块负责把它落到控件上（含焦点起点重锚）。[br]
## [br][b]职责二：二次确认 + 退出[/b]（GAP-5 无障碍要求）——「保存并退出」与
## 「返回主菜单」都是不可逆动作，两者都要防误触。本模块持有确认框实例、把玩家选择
## 翻成退出链；[b]写盘与转场本身仍调用 [PauseMenuActions][/b]（本模块不碰
## SaveLoadSystem / SceneManager）。[br]
## [br][b]确认框是复用式单例[/b]（同 [code]LoadSlotPanel[/code]）：建一次、开合只切
## [code]visible[/code]——每次新建会让「上一个框还没释放就已经又开一个」变成可能。[br]
## [br][b]ESC 三层退[/b]：确认框 → 读档面板 → 暂停菜单。[method handle_esc] 一次
## 只退一层（共用一个键时必须一层层退，否则玩家按一下 ESC 直接被打回游戏，
## 连自己在哪个框里都来不及看清）。[br]
## [br][b]依赖注入[/b]（ADR-0031 §2）：场景 ID 经宿主注入的 [code]scene_manager[/code]
## 现取；拿不到时按「最宽松」处理（按钮全显示）——见 [PauseMenuLayout] 的注记。
## 宿主内部的三处能力（[code]get_actions[/code] / [code]_show_status[/code] /
## [code]_release_pause[/code]）以具名方法调用访问——同 [code]LoadSlotPanel[/code]
## 按名连宿主处理器的既有口径。[br]
## [br]来源: design/ux/pause-menu.md（States & Variants / 两个确认弹窗 / 键盘焦点顺序 /
## Accessibility「确认弹窗防误触」）、ADR-0031 §1/§2、.claude/rules/ui-code.md。

const LayoutScript := preload("res://src/ui/hud/pause_menu_layout.gd")
const ConfirmScript := preload("res://src/ui/hud/pause_menu_confirm.gd")

## 确认框类型（[PauseMenuConfirm] 是真理来源，此处为调用侧的具名入口）。
const CONFIRM_SAVE_EXIT: int = 0
const CONFIRM_RETURN: int = 1

## 宿主（PauseMenu 本体——按钮容器、动作层与反馈行的来源）。
var _host: Control = null
## 受场景变体影响的「保存并退出」按钮（战斗中隐藏）。
var _save_exit_button: Button = null
## 「返回主菜单」按钮（战斗确认文案用它判定变体）。
var _return_button: Button = null
## 确认框实例（复用式单例——懒建一次）。
var _confirm: Control = null


## 绑定宿主与两个退出按钮（宿主 [code]_ready[/code] 后调一次；重复调用覆盖）。[br]
## [br][b]为什么按钮由宿主传进来[/b]：[code]@onready[/code] 路径引用只在宿主里写一次，
## 本模块不必再抄一份控件路径（路径一改就会漏改一处）。
func bind(p_host: Control, p_save_exit_button: Button, p_return_button: Button) -> void:
	_host = p_host
	_save_exit_button = p_save_exit_button
	_return_button = p_return_button


# ═══════════════════════════════════════════════════════════════════════════════
# 场景变体
# ═══════════════════════════════════════════════════════════════════════════════

## 按当前场景落定按钮可见性，并把键盘/手柄焦点重锚到首个可选按钮。[br]
## [br][b]为什么两件事一起做[/b]：[code]request_open[/code] 里先隐藏再锚焦点，顺序
## 一旦拆给两处调用，就会出现「焦点已锚在隐藏按钮上」的中间态（战斗中打开菜单，
## 焦点停在看不见的「保存并退出」上——按 Enter 仍会触发它）。[br]
## [br][b]返回[/b]：被锚定的按钮（无可选按钮时 null——宿主保持现状）。
func apply_variant() -> Button:
	if _save_exit_button != null and is_instance_valid(_save_exit_button):
		_save_exit_button.visible = LayoutScript.save_exit_visible(current_scene_id())
	return focus_default()


## 当前场景 ID（宿主注入的 SceneManager 现取）。[br]
## [br][b]拿不到时返回 -1[/b]：宿主未注入 / mock 缺方法时按「未知场景」处理，
## 变体规则退回最宽松（全部按钮可显示）——藏掉一个本该可用的按钮，玩家会以为
## 存档功能没了；多显示一个则由动作层的失败反馈兜底。
func current_scene_id() -> int:
	if _host == null:
		return -1
	var sm: Variant = _host.get("scene_manager")
	if sm == null or not (sm is Node) or not (sm as Node).has_method(&"get_current_scene_id"):
		return -1
	return int((sm as Node).call(&"get_current_scene_id"))


## 锚定焦点到菜单里首个可见且可激活的按钮（跳过隐藏/置灰者）。[br]
## [br][b]顺序来源[/b]：按钮容器（[code]Panel/VBox[/code]）的树序——它本身就是 UX
## 规格的焦点顺序（继续 → 卡组 → 设置 → 存档 → 读档 → 保存并退出 → 返回），
## 再抄一份常量数组会和 tscn 的排列各自漂移。[br]
## [br][b]返回[/b]：被锚定的按钮；无可选按钮时 null。
func focus_default() -> Button:
	if _save_exit_button == null or not is_instance_valid(_save_exit_button):
		return null
	var parent: Node = _save_exit_button.get_parent()
	if parent == null:
		return null
	var target: Button = LayoutScript.first_focusable(parent.get_children())
	if target != null:
		target.grab_focus()
	return target


# ═══════════════════════════════════════════════════════════════════════════════
# 二次确认
# ═══════════════════════════════════════════════════════════════════════════════

## 弹出二次确认框（供「保存并退出」/「返回主菜单」两个按钮调用）。[br]
## [br][param p_type] 见 [PauseMenuConfirm].[constant TYPE_SAVE_AND_EXIT] /
## [constant TYPE_RETURN_TO_MENU]。[br]
## [br][b]返回[/b]：确认框实例；宿主缺失时 null（不崩——接线没完成不该变崩溃）。
func request_confirm(p_type: int) -> Control:
	if _host == null or not is_instance_valid(_host):
		return null
	var dialog: Control = _ensure_confirm()
	dialog.call(&"open", p_type, LayoutScript.is_combat(current_scene_id()))
	return dialog


## 确认框是否打开（ESC 分层判定用）。
func is_confirm_open() -> bool:
	return _confirm != null and is_instance_valid(_confirm) \
			and bool(_confirm.call(&"is_open"))


## 取消确认框（ESC 第一层）。[br]
## [br][b]返回[/b]：是否真的收掉了一个开着的框（没开时 false——ESC 应往下走一层）。
func cancel_confirm() -> bool:
	if not is_confirm_open():
		return false
	_confirm.call(&"cancel")
	return true


## 收起确认框（关闭菜单 / 转场前清理用——不留一个「开着」的框在隐藏的菜单里）。
func close_confirm() -> void:
	if _confirm != null and is_instance_valid(_confirm):
		_confirm.call(&"close")


## ESC 分层处理（返回「这一下 ESC 是否已被本模块消化」）。[br]
## [br][b]顺序即优先级[/b]：确认框在最上层、读档面板在其下、菜单在最底——
## 打开确认框时读档面板必然已收起（两个入口互斥），但顺序写死成「先问最上层」
## 才不会被将来新增的覆盖层插队打乱。[br]
## [br][b]读档面板那一层委托宿主[/b]：面板的开合归 [PauseMenuActions]（本模块不持
## 面板引用），宿主已有 [code]get_actions().close_load_panel()[/code] 这条链。
func handle_esc() -> bool:
	if cancel_confirm():
		focus_default()
		return true
	if _host == null or not is_instance_valid(_host):
		return false
	if bool(_host.call(&"close_load_panel_if_open")):
		focus_default()
		return true
	return false


## 确认框实例——懒建一次并接到宿主的 [code]_on_confirm_outcome[/code]。[br]
## [br][b]挂在宿主节点树下[/b]：菜单隐藏/释放时确认框跟着走，不必单独管生命期
## （先例 [code]LoadSlotPanel[/code] 挂在暂停菜单本体）。
func _ensure_confirm() -> Control:
	if _confirm != null and is_instance_valid(_confirm):
		return _confirm
	_confirm = ConfirmScript.new()
	_confirm.connect(&"outcome_chosen", Callable(_host, &"_on_confirm_outcome"))
	_host.add_child(_confirm)
	return _confirm


# ═══════════════════════════════════════════════════════════════════════════════
# 退出链（确认之后真正落地——写盘 / 转场仍走动作层）
# ═══════════════════════════════════════════════════════════════════════════════

## 确认框结果的落地入口（[signal PauseMenuConfirm.outcome_chosen] 的唯一消费者，
## 宿主把它转发到 [method resolve_outcome]）。[br]
## [br][b]「确认保存」对两种确认类型同义[/b]：都是「存档成功后转场主菜单」
## （[method save_and_exit]）——差别只在文案，不在动作。[br]
## [br][b]「不保存」只可能来自返回主菜单变体[/b]：保存并退出没有这一键。
func resolve_outcome(outcome: int) -> void:
	match outcome:
		ConfirmScript.OUTCOME_SAVE_EXIT:
			save_and_exit()
		ConfirmScript.OUTCOME_LEAVE:
			return_to_main_menu()
		_:
			# 取消（按钮 / ESC）——弹窗已自行收起，动作上一件事都不做；但焦点必须
			# 回锚：框里的按钮一隐藏焦点就悬空，键盘玩家会觉得「什么都按不动」。
			focus_default()


## 存档并离开：存档成功才走；失败留在菜单里给原因。[br]
## [br][b]不再多存一次[/b]：这次动作本身就是存档，转场前的自动存档由
## [method PauseMenuActions.auto_save_first] 在「返回主菜单」那条路上负责。
func save_and_exit() -> void:
	var actions: RefCounted = get_actions()
	var outcome: Dictionary = actions.call(&"save_now")
	if not bool(outcome.get("ok", false)):
		_host.call(&"_show_status", str(outcome.get("message", "")), false)
		return
	actions.call(&"navigate_main_menu")
	_host.call(&"_release_pause")


## 返回主菜单——先自动存档一次再转场（不判存档结果，见动作层注记）。
func return_to_main_menu() -> void:
	get_actions().call(&"request_main_menu")
	_host.call(&"_release_pause")


## 宿主的动作编排层（每次现取——宿主可能在 [code]_ready[/code] 之前就绑定了本层，
## 而动作层是懒建的）。
func get_actions() -> RefCounted:
	return _host.call(&"get_actions")
