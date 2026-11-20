extends RefCounted
## CombatBagHost —— 战斗内「行囊」的编排（入口按钮 → 面板 → 结算 → 回填）。[br]
## [br][b]职责[/b]：把四件事串起来——[br]
##   1. 底部条「行囊」按钮点击 → 开 / 关面板（再点一次关闭）；[br]
##   2. 打开期间[b]冻结出牌输入[/b]、关闭时解冻（[code]CombatSceneInteraction.set_enabled[/code]）；[br]
##   3. 面板发 [signal CombatBagScreen.entry_use_requested] → 交 [code]CombatBagUse[/code] 结算；[br]
##   4. 把系统给的 [code]message[/code] 回填给面板，并在真的消耗掉时刷新（[code]consumed[/code]）。[br]
## [br][b]为什么冻结走 [code]CombatSceneInteraction[/code] 而不是 [code]InputManager[/code] 的锁[/b]：锁栈会被
## [code]InputManager._on_tree_changed[/code] 整体清空（[code]tree_changed[/code] 每帧至多一次，
## 面板入树即触发），同帧 push 的锁立刻被抹掉——实测 [code]is_input_allowed[/code] 仍返回 true，
## 面板开着时照样能点穿出牌。冻结走的是交互层自己的 [code]_enabled[/code] 普通字段，不受树变更影响
## （与商店 overlay 期间的节点图冻结同一取舍）。[br]
## [br][b]开战时先解冻一次[/b]：[code]wire[/code] 之后交互层处于停用态（备战面板期间不该能出牌），
## 开战由 [code]CombatSceneInteraction.enable[/code] 放行；本模块[b]不接管开战时机[/b]，
## 只在打开行囊时记住「当前是开是关」，关闭时恢复。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不持有条目、不缓存 HP / 灵力——每次打开现读；
## 本模块只持接线句柄与「面板是否开着」这一个瞬态交互标志（§2.1 豁免）。[br]
## [br][b]文案本地化豁免[/b]：与 combat_bag_rules / combat_bag_screen 同源口径。
##
## 来源: design/gdd/alchemy-crafting-system.md §1c（丹药使用时机「战斗中或背包」）、
## ADR-0031 §2、.claude/rules/ui-code.md、先例
## [code]inventory_screens_host.gd[/code]（面板发意图、宿主调系统）、
## [code]shop_node_presenter.gd[/code]（overlay 期间冻结底层交互）。

## 行囊面板与图标入口。
const ScreenScript := preload("res://src/ui/combat/bag/combat_bag_screen.gd")

## 底部条「行囊」按钮缺失时的告警文案（装配错漏要看得见，但不必崩）。
const WARN_NO_BUTTON: String = "CombatBagHost: 未找到底部条「行囊」按钮——入口不可用"

## 面板（[method mount] 创建；未挂载为 null）。
var panel: Control = null
## 结算层（注入——生产由装配处接 [code]CombatBagUse[/code]；null 时降级为不可用）。
var use_layer: RefCounted = null
## 出牌输入开关 [code]func(enabled: bool) -> void[/code]（注入——生产接
## [code]CombatSceneInteraction.set_enabled[/code]）。
var _set_input: Callable = Callable()
## 按钮本体（退订时断开连接用）。
var _button: Button = null
## 键盘/手柄焦点记忆（注入——整场战斗一份，见 [method mount] 的 [param p_focus_memory]）。
var _focus_memory: RefCounted = null


## 装配：把面板挂到 [param p_host]、接上底部条的入口按钮与出牌输入开关。[br]
## [br][param p_host] 面板宿主（通常是战场根 [code]CombatLayout[/code]）。[br]
## [br][param p_bottombar] 底部条（读它的 [code]bag_button[/code]）。[br]
## [br][param p_set_input] 出牌输入开关；[br]
## [param p_use_layer] 结算层。[br]
## [param p_focus_memory] 焦点记忆（可空——打开前记焦点、关闭后还原；见下）。[br]
## [br][b]返回[/b]：是否装上了入口按钮（false = 底部条结构不符，面板仍可手动打开）。[br]
## [br][b]为什么行囊也要焦点记忆[/b]：行囊是覆盖面板，一开就把焦点抢到面板里；
## 关闭后不还回去，玩家的焦点会落到链的默认焦点（第一张手牌）而不是他打开行囊
## 时的位置——每开一次面板丢一次位置。
func mount(p_host: Control, p_bottombar: Variant, p_set_input: Callable,
		p_use_layer: RefCounted, p_focus_memory: RefCounted = null) -> bool:
	use_layer = p_use_layer
	_set_input = p_set_input
	_focus_memory = p_focus_memory
	panel = ScreenScript.new()
	panel.set_entries_source(_entries_of(p_use_layer))
	panel.connect(&"entry_use_requested", _on_entry_use_requested)
	panel.connect(&"closed", close)
	p_host.add_child(panel)
	panel.call(&"close")
	return _connect_button(p_bottombar)


## 打开面板（幂等：已打开时只刷新，不重复冻结）。[br]
## [br][b]打开期间冻结出牌输入[/b]：面板盖住了手牌区，不冻结就会出现「隔面板点穿出牌」
## ——玩家点的是行囊里的一行，打出去的却是手牌。[br]
## [br][b]先记焦点再开[/b]：顺序反了记到的是面板自己的默认焦点（等于没记）。
func open() -> void:
	if panel == null:
		return
	_remember_focus()
	panel.call(&"open")
	_apply_input(false)


## 关闭面板并解冻出牌输入（未打开时为空操作）。[br]
## [br][b]无条件还原焦点[/b]：未打开时 [method close] 本就是幂等的（解冻 + 还焦点），
## 记忆为空时还原是空操作，不产生副作用。
func close() -> void:
	if panel == null:
		return
	panel.call(&"close")
	_apply_input(true)
	_restore_focus()


## 面板是否开着（按钮据此决定「再点一次是开还是关」）。
func is_open() -> bool:
	return panel != null and bool(panel.call(&"is_open"))


## 退订（场景退场——信号源是常驻 Autoload 与场景内节点）。[br]
## [br][b]先关再置空手柄[/b]：退订之后再也解不了冻（[member _set_input] 已被清空）。
## 若退场时面板还开着，出牌交互层会带着「停用」状态活到下一次进战斗——输入层挂在
## 常驻 Autoload 的同一条链路上，表现为「进了战斗却点不动牌」。故解冻必须落在
## 置空之前；未打开时 [method close] 是一次幂等的解冻，不产生副作用。
func unbind() -> void:
	close()
	if _button != null and is_instance_valid(_button) \
			and _button.pressed.is_connected(_on_button_pressed):
		_button.pressed.disconnect(_on_button_pressed)
	_button = null
	panel = null
	use_layer = null
	_set_input = Callable()
	_focus_memory = null


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 入口按钮接线——底部条的 [code]bag_button[/code]（组件缺失时告警降级，不崩）。
func _connect_button(p_bottombar: Variant) -> bool:
	if p_bottombar == null or not (p_bottombar as Object).has_method(&"get"):
		push_warning(WARN_NO_BUTTON)
		return false
	var icon: Variant = (p_bottombar as Object).get("bag_button")
	if icon == null:
		push_warning(WARN_NO_BUTTON)
		return false
	var button: Variant = (icon as Object).get("button")
	if not (button is Button):
		push_warning(WARN_NO_BUTTON)
		return false
	_button = button as Button
	if not _button.pressed.is_connected(_on_button_pressed):
		_button.pressed.connect(_on_button_pressed)
	return true


## 「行囊」按钮点击——开 / 关切换（同一个出口，不写两条路径）。
func _on_button_pressed() -> void:
	if is_open():
		close()
	else:
		open()


## 面板请求使用某一条目——交给结算层，再把结果文案回填给面板。[br]
## [br][b]面板不参与判断[/b]：用得成用不成、为什么用不成，全是结算层给的
## [code]message[/code]；本模块只做两件事——把句子显示出来、在真的消耗掉时刷新
## （[code]consumed[/code] 为真才刷新：无谓的刷新会把玩家的游标弹回首行）。[br]
## [br][b]先取文案再刷新[/b]：刷新会重置提示文案（空态/操作提示都会改写它），
## 顺序反了玩家就看不到系统给的那句话。
func _on_entry_use_requested(p_entry: Dictionary, p_target_ids: Array) -> void:
	if use_layer == null or panel == null:
		return
	var result: Dictionary = use_layer.call(&"use_entry", p_entry, p_target_ids)
	var message: String = str(result.get("message", ""))
	if bool(result.get("consumed", false)):
		panel.call(&"refresh")
	panel.call(&"show_message", message)


## 落输入开关（未注入时无操作——headless 单测不带交互层）。
func _apply_input(p_enabled: bool) -> void:
	if _set_input.is_valid():
		_set_input.call(p_enabled)


## 开面板前记下焦点（未注入焦点记忆时空操作——headless 单测不带交互层）。
func _remember_focus() -> void:
	if _focus_memory != null:
		_focus_memory.call(&"remember_current")


## 关面板后把焦点还给打开前的控件（未注入时空操作）。
func _restore_focus() -> void:
	if _focus_memory != null:
		_focus_memory.call(&"restore")


## 结算层持有的条目来源（面板直接问它——不必经本模块转一道手）。
func _entries_of(p_use_layer: RefCounted) -> RefCounted:
	if p_use_layer == null:
		return null
	var source: Variant = p_use_layer.get(&"entries")
	return source as RefCounted
