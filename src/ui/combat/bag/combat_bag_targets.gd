class_name CombatBagTargets
extends RefCounted
## CombatBagTargets —— 行囊面板的「目标选择」状态机（从 [CombatBagScreen] 拆出）。[br]
## [br][b]为什么单独一处[/b]：目标栏是本面板里唯一带[b]内部状态[/b]的部分
## （候选池 + 当前下标 + 是否全体），而「选谁」与「怎么渲染 / 怎么发意图」是两件事。
## 拆开后 [CombatBagScreen] 只管事件与渲染，候选池口径与下标收敛全部收在这里。[br]
## [br][b]候选池跟着当前行走[/b]：[code]CombatBagEntries.targets[/code] 的产出随条目而变
## （丹药只列[b]有缺口[/b]的人、法宝列全部存活者），故 [method sync] 每次都重算，
## 并把下标归零——沿用旧下标会指向另一个人，而玩家看到的行文案没变，属于「静默改目标」。[br]
## [br][b]全体效果没有「换一个」的语义[/b]：如天罗丹（[code]all_allies[/code]）的目标栏
## 改为显示人数、去掉切换提示，方向键也不再改下标（否则会误触发引擎焦点导航）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不持有条目与收藏，只持「当前选中谁」这一个
## 瞬态交互标志（§2.1 豁免）；候选池每次现问来源，不缓存。[br]
## [br][b]文案本地化豁免[/b]：与 combat_bag_layout / combat_bag_rules 同源口径。
##
## 来源: design/gdd/alchemy-crafting-system.md §1c（丹药使用时机「战斗中或背包」）、
## ADR-0031 §2、.claude/rules/ui-code.md、先例 [code]combat_bag_layout.gd[/code]。

## 控件树样式与目标栏文案（前缀 / 提示 / 全体描述的唯一来源）。
const LayoutScript := preload("res://src/ui/combat/bag/combat_bag_layout.gd")
## 判据与常量来源（[code]all_allies[/code] 与「丹 / 宝」两分只在那一个文件里定义）。
const RulesScript := preload("res://src/feature/combat/combat_bag_rules.gd")

## 条目来源（注入——面板持有，本模块只问 [code]targets(is_pill)[/code]）。
var entries_source: RefCounted = null
## 目标栏按钮（由布局建好、交进来——本模块只管它的文本与焦点查询）。
var button: Button = null
## 当前候选池（[member button] 显示的正是它的第 [member _index] 项）。
var _pool: Array = []
## 当前下标（越界由 [method cycle] 的取模收敛）。
var _index: int = 0
## 当前条目是否为全体效果（目标栏改为显示人数）。
var _all_targets: bool = false


func _init(p_button: Button = null, p_entries_source: RefCounted = null) -> void:
	button = p_button
	entries_source = p_entries_source


## 注入条目来源（宿主装配时接上 [code]CombatBagEntries[/code]）。
func set_entries_source(p_source: RefCounted) -> void:
	entries_source = p_source


## 按当前游标那一行重算候选池并刷新目标栏。[br]
## [br][param p_entry] 当前行携带的条目（空字典 = 没有可用行）。[br]
## [br][b]候选池变了就把下标归零[/b]：见类文档「候选池跟着当前行走」。
func sync(p_entry: Dictionary) -> void:
	_all_targets = RulesScript.is_all_allies(p_entry)
	var is_pill: bool = str(p_entry.get("kind", "")) == str(RulesScript.KIND_PILL)
	if entries_source == null or p_entry.is_empty():
		_pool = []
	elif entries_source.has_method(&"targets"):
		var raw: Variant = entries_source.call(&"targets", is_pill)
		_pool = raw if raw is Array else []
	else:
		_pool = []
	_index = 0
	_update_text()


## 当前显式选定的目标 ID（全体效果为全部候选；无候选为空数组）。[br]
## [br][b]确认时就用它[/b]——面板显示的与发出去的必须是同一份，不各自再算一遍。
func selected_ids() -> Array:
	if _all_targets:
		return _pool.map(func(row: Dictionary) -> int: return int(row["character_id"]))
	if _index < 0 or _index >= _pool.size():
		return []
	return [int((_pool[_index] as Dictionary)["character_id"])]


## 左右键 → 换目标。[br]
## [br][b]为什么左右归本模块[/b]：行内没有横向语义，左右在这一层就是「换目标」——
## 那是本模块唯一的职责（纵向选行归 [code]ShopPanelNavigator[/code]）。[br]
## [br][b]返回[/b]：是否消费。目标栏自己持焦点时返回 false——光标停在那一行上，
## 玩家按方向键的意图指向它，原样放行（同 [code]PagedPanelNavigator[/code] 对分类栏的处置）。
func handle_sideways(p_event: InputEvent) -> bool:
	if not p_event.is_action_pressed(&"ui_left") and not p_event.is_action_pressed(&"ui_right"):
		return false
	if has_focus():
		return false
	# 全体效果没有「换一个」的语义——吃掉事件但不改状态（否则会误触发引擎焦点导航）。
	if not _all_targets:
		cycle(-1 if p_event.is_action_pressed(&"ui_left") else 1)
	return true


## 切到相邻目标（环绕——候选只有几个人，到头绕回来比卡住更好用）。
func cycle(p_delta: int) -> void:
	if _pool.size() <= 1:
		return
	_index = (_index + p_delta + _pool.size()) % _pool.size()
	_update_text()


## 当前条目是否全体效果（方向键此时不改下标）。
func is_all_targets() -> bool:
	return _all_targets


## 目标栏文本（测试断言用——面板不碰内部控件路径）。
func text() -> String:
	return button.text if button != null else ""


## 当前候选池（渲染实证用——面板不直接读它，只经 [method selected_ids] 取结论）。
func pool_size() -> int:
	return _pool.size()


## 目标栏是否持有键盘焦点（未挂载时为 false——不臆造）。[br]
## [br]方向键在焦点落在目标栏上时原样放行（玩家的意图指向它，同
## [code]PagedPanelNavigator[/code] 对分类栏的处置）。
func has_focus() -> bool:
	return button != null and is_instance_valid(button) and button.has_focus()


## 测试用：点目标栏（等价于真实鼠标点击——切到下一个目标）。
func press() -> void:
	if button != null:
		button.emit_signal(&"pressed")


## 按当前状态刷新目标栏文本（无候选时显示「无」——不写「角色 -1」这种假信息）。
func _update_text() -> void:
	if button == null:
		return
	if _pool.is_empty():
		LayoutScript.set_target_text(button, LayoutScript.TEXT_TARGET_NONE, true)
		return
	if _all_targets:
		LayoutScript.set_target_text(button,
				LayoutScript.TEXT_TARGET_ALL % _pool.size(), true)
		return
	var row: Dictionary = _pool[clampi(_index, 0, _pool.size() - 1)]
	LayoutScript.set_target_text(button, str(row.get("label", "")), false)
