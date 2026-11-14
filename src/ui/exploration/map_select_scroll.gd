extends RefCounted
## MapSelectScroll —— 地图选择界面的手柄横向滚动（从 [MapSelectScreen] 拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕脚本要守在 300 行软上限内，而「手柄怎么滚卡片行」
## 与「列表怎么取、点击怎么分流」是两件事（同 [code]map_select_data.gd[/code] /
## [code]map_select_animator.gd[/code] 拆分先例）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块只持有滚动容器引用，不读不写任何
## 玩法数据——滚动位置是纯呈现状态。[br]
## [br][b]设备限定[/b]（godot-specialist 输入冲突修正）：仅响应手柄输入
## （[InputEventJoypadButton] / [InputEventJoypadMotion]）——
## [code]ui_left[/code]/[code]ui_right[/code] 默认同时绑定键盘方向键，若在
## [code]_input[/code] 全量拦截会吞掉键盘焦点导航（左右方向键在卡片间移动焦点是
## 引擎内建能力，必须留给它）。滚轮/滚动条为 ScrollContainer 内建，不走本模块。[br]
##
## 来源: design/gdd/exploration-ui-system.md §1、AC-9（三路径之一）、
## ADR-0031 §2、.claude/rules/ui-code.md（双输入）。

## 手柄 LB/RB 单次滚动步长（像素）——数据驱动，非魔数。
const SCROLL_STEP: int = 128

var _scroll: ScrollContainer = null


## 绑定滚动容器（宿主 [code]_ready[/code] 或首次使用时调用一次）。
func bind(p_scroll: ScrollContainer) -> void:
	_scroll = p_scroll


## 处理一条输入事件。[br]
## [br][b]返回[/b]：[code]true[/code] 表示已消费（调用方应
## [method Viewport.set_input_as_handled]），[code]false[/code] 为原样放行。[br]
## [br][b]未绑定容器时返回 false[/b]：宿主未完成接线不应变成崩溃，也不该吞输入。
func handle(p_event: InputEvent) -> bool:
	if _scroll == null or not is_instance_valid(_scroll):
		return false
	if not (p_event is InputEventJoypadButton or p_event is InputEventJoypadMotion):
		return false
	if p_event.is_action_pressed(&"ui_left"):
		_scroll.scroll_horizontal -= SCROLL_STEP
		return true
	if p_event.is_action_pressed(&"ui_right"):
		_scroll.scroll_horizontal += SCROLL_STEP
		return true
	return false
