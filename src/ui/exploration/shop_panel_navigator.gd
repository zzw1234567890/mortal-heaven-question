class_name ShopPanelNavigator
extends RefCounted
## ShopPanelNavigator —— 商店商品行的键盘/手柄游标（纯逻辑，不碰控件树）。[br]
## [br][b]职责[/b]：持有一个「当前选中的商品行」游标，把方向键/确认/取消翻译成
## 三件事——移动游标、确认购买、请求离开；货架重建时复位到首个可选行。[br]
## [br][b]为什么单独一处[/b]：[ShopPanelScreen] 已近 300 行软上限，而「游标怎么动」
## 与「行怎么画」是两件事（同 [NodeGraphInteractionMount] 拆分先例）。本模块只读
## [Button] 的 [member Button.disabled]，不认识货架、价格与库存——零状态所有权
## （ADR-0031 §2）。[br]
## [br][b]禁用行不可选中[/b]：售罄 / 灵石不足的行在游标路径上直接跳过。实测
## [method Control.grab_focus] 对 [code]disabled[/code] 的 [Button] 仍然生效，
## 故这道跳过必须由游标自己做（引擎不会代劳）；与鼠标点击被
## [member Button.disabled] 拦住同口径。[br]
## [br][b]不环绕[/b]：走到头即停（与引擎内置焦点导航同语义），不做首尾相接——
## 环绕会让「已经到底了」这件事不可观测。[br]
## [br][b]键位走 ui_* 动作[/b]：`.claude/rules/ui-code.md`「所有交互元素必须同时支持
## 键盘/鼠标和手柄输入」——[code]ui_up[/code] / [code]ui_down[/code] /
## [code]ui_accept[/code] / [code]ui_cancel[/code] 四个默认动作在键鼠与手柄上
## 都有绑定，故一条实现同时覆盖两种输入设备。[br]
## [br][b]事件要喂 [method InputEvent.is_action_pressed] 的原始事件[/b]：调用方须在
## 引擎 GUI 派发[b]之前[/b]取到事件（见 [method ShopPanelScreen._input] 的说明——
## 焦点在 [Button] 上时引擎的内置焦点导航会先把方向键吃掉）。本模块只做语义判定，
## 不关心事件从哪一级来。[br]
##
## 来源: .claude/rules/ui-code.md（双输入）、ADR-0031 §2/§4（零状态所有权 + 双焦点）、
## GDD exploration-ui-system.md §4c（商店 overlay）、先例
## [code]node_keyboard_navigator.gd[/code]（游标 + 纯函数寻路）。

## 游标变化（下标；-1 = 无游标）——面板据此把键盘焦点搬到对应行。
signal focus_changed(p_index: int)

## 行数组提供者 [code]func() -> Array[/code]（货架每次重建都换一批控件，
## 故每次现取行而非缓存——缓存会让游标指向上一次的行）。
var _rows: Callable = Callable()
## 确认选中行 [code]func(index: int) -> void[/code]——面板决定「确认」意味着什么。
var _on_activate: Callable = Callable()
## 请求离开 [code]func() -> void[/code]——面板转发到 [signal ShopPanelScreen.leave_requested]。
var _on_cancel: Callable = Callable()

## 当前游标下标（-1 = 无）。
var _focus: int = -1


## 接线——注入行提供者与两个动作出口（面板构建时调用一次）。
func bind(p_rows: Callable, p_on_activate: Callable, p_on_cancel: Callable) -> void:
	_rows = p_rows
	_on_activate = p_on_activate
	_on_cancel = p_on_cancel


## 货架重建后复位——游标清空后落到首个可选行（无可用行时为 -1，如实报告）。
func reset() -> void:
	_set_focus(-1)
	move(1)


## 当前游标下标（-1 = 无）。
func focus_index() -> int:
	return _focus


## 移动游标 [param p_delta] 行（正为下、负为上）。[br]
## [br]跳过禁用行；无候选时游标停在原位（首次移动且全列禁用时保持 -1）。[br]
## [br][b]返回[/b]：移动后的游标下标。
func move(p_delta: int) -> int:
	var rows: Array = _rows_of()
	var count: int = rows.size()
	if count == 0:
		return _set_focus(-1)
	var step: int = 1 if p_delta >= 0 else -1
	# 无游标时从「列表外侧」起步，让第一次移动直接落到首 / 末个可选行
	var from: int = _focus if _focus >= 0 and _focus < count else (-1 if step > 0 else count)
	var probe: int = from + step
	while probe >= 0 and probe < count:
		if not _is_disabled(rows[probe]):
			return _set_focus(probe)
		probe += step
	return _focus


## 确认当前游标行。[br]
## [br][b]返回[/b]：是否发起了购买（无游标 / 游标行禁用时为 false——禁用行不发意图，
## 与鼠标点击同口径）。
func activate() -> bool:
	var rows: Array = _rows_of()
	if _focus < 0 or _focus >= rows.size() or _is_disabled(rows[_focus]):
		return false
	if _on_activate.is_valid():
		_on_activate.call(_focus)
	return true


## 处理一条输入事件。[br]
## [br][b]返回[/b]：是否应当消费（消费的事件由面板标记为已处理，不再向下传播）。[br]
## [br]未映射的动作（鼠标、Tab 焦点切换、无关按键）原样放行——面板只吃这四个动作。
func handle_event(p_event: InputEvent) -> bool:
	if p_event.is_action_pressed(&"ui_down"):
		move(1)
		return true
	if p_event.is_action_pressed(&"ui_up"):
		move(-1)
		return true
	if p_event.is_action_pressed(&"ui_accept"):
		return activate()
	if p_event.is_action_pressed(&"ui_cancel"):
		if _on_cancel.is_valid():
			_on_cancel.call()
		return true
	return false


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 取当前行数组（提供者缺失时为空——组件未接线的降级路径不崩）。
func _rows_of() -> Array:
	if not _rows.is_valid():
		return []
	var raw: Variant = _rows.call()
	return raw if raw is Array else []


## 行是否禁用（非 [Button] 的脏条目按禁用处理，不臆造可点性）。
static func _is_disabled(p_row: Variant) -> bool:
	return not (p_row is Button) or (p_row as Button).disabled


## 写入游标并发信号（同值不重复发——焦点搬运是幂等的，重复发只会白刷）。
func _set_focus(p_index: int) -> int:
	if _focus == p_index:
		return _focus
	_focus = p_index
	focus_changed.emit(p_index)
	return _focus
