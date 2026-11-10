class_name CombatGestureModel
extends RefCounted
## CombatGestureModel —— 手牌按压/拖拽状态机（combat-ui-interaction 001 / 本轮：
## 真实输入路径）。
##
## [b]职责[/b]：记录一次按压的生命周期——按下时记住「按的是哪张卡、按在哪」，
## 移动时按 [constant CombatDragRules.DRAG_THRESHOLD]（8px）判定是否已启动拖拽，
## 并区分本次按压最终是 [b]点击[/b] 还是 [b]拖拽释放[/b]。[br]
## [br][b]为什么独立成纯类[/b]：[code]_gui_input[/code] 里的几行 if 无法被测试
## 覆盖；「7px 不启动 / 8px 启动」是写进 GDD 的规格，边界必须能断言。
## 输入组件只负责把事件坐标喂进来，判定全在本类。[br]
## [br][b]纯状态[/b]（ADR-0031 Logic 内核模式）：不持有节点、不发信号。
##
## @experimental
## 来源: ADR-0004、design/gdd/combat-ui-system.md §手牌交互、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md（AC-1）。

## 事件种类——[method release] 的返回值。
const KIND_NONE: int = 0     ## 无按压（未按下就释放）
const KIND_CLICK: int = 1    ## 点击（从未越过阈值）
const KIND_DRAG: int = 2     ## 拖拽释放（越过了阈值）

## 已按压标志。
var _pressed: bool = false
## 按下的卡实例 ID（[code]-1[/code] = 按在空白处）。
var _card_id: int = -1
## 按下位置（全局坐标——与释放位置同一坐标系）。
var _press_pos: Vector2 = Vector2.ZERO
## 是否已启动拖拽。
var _dragging: bool = false


## 按下。[param p_card_id] 按到的卡（-1 = 空白）；[param p_pos] 全局坐标。
func press(p_card_id: int, p_pos: Vector2) -> void:
	_pressed = true
	_card_id = p_card_id
	_press_pos = p_pos
	_dragging = false


## 移动——返回「本次移动是否刚刚越过拖拽阈值」。[br]
## [br][b]只报一次[/b]：越过阈值后继续移动返回 false（调用方不必自己去重）。
func move(p_pos: Vector2) -> bool:
	if not _pressed or _dragging:
		return false
	if not CombatDragRules.should_start(_press_pos, p_pos):
		return false
	_dragging = true
	return true


## 释放——返回本次按压的种类与卡 ID：[code]{kind, card_id}[/code]。[br]
## 释放后状态清空（[member _pressed] = false）。
func release() -> Dictionary:
	var out: Dictionary = {
		"kind": KIND_NONE if not _pressed else (KIND_DRAG if _dragging else KIND_CLICK),
		"card_id": _card_id,
	}
	_pressed = false
	_card_id = -1
	_dragging = false
	return out


## 取消（右键 / 阶段切换 / 弹窗）——清空状态，不产生释放事件。
func cancel() -> void:
	_pressed = false
	_card_id = -1
	_dragging = false


## 是否处于按压中（测试探针）。
func is_pressed() -> bool:
	return _pressed


## 是否已启动拖拽（测试探针）。
func is_dragging() -> bool:
	return _dragging


## 当前按压的卡 ID（无按压为 -1）。
func pressed_card_id() -> int:
	return _card_id
