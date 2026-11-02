class_name EndTurnButton
extends Control
## EndTurnButton —— 底部条「结束出牌」按钮位（combat-ui-layout Story 005）。
##
## [b]职责[/b]：按钮渲染态 + 启用态——仅阶段 2 可见（其余阶段隐藏；GDD
## 边界澄清补充二 2026-09-07）；启用态常亮（player_confirmed_end 无前置
## 条件——玩家可能想跳过攻击）。[br]
## [br][b]范围划分[/b]：按钮本体渲染与显示/隐藏归本 story；鼠标点击/键盘/手柄
## 确认流转归 interaction epic（点击后 [code]player_confirmed_end[/code] 推进）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不持游戏状态——阶段经
## [method apply_phase] 信号驱动显示/隐藏。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]。
##
## @experimental
## 来源: ADR-0031、ADR-0008、design/gdd/combat-ui-system.md §569/§结束出牌控件、
## combat-ui-layout Story 005（AC-7）。

## === 视觉常量 ================================================================

## 按钮文本。
const LABEL_TEXT: String = "结束出牌"
## 按钮字号。
const BUTTON_FONT_SIZE: int = 16
## 出牌阶段号（ADR-0008 CombatPhase.PLAY——仅此阶段显示/可点）。
const PLAY_PHASE: int = 2

## === 子节点引用 ==============================================================

## 按钮本体（Button）。
var button: Button = null

## === 运行态 ==================================================================

## 当前阶段（-1 = 未初始化——默认隐藏）。
var _phase: int = -1


func _init() -> void:
	_build()


## 构建按钮（_init 构建——不依赖场景树时序）。
func _build() -> void:
	custom_minimum_size = Vector2(96, 40)
	button = Button.new()
	button.name = "EndTurnButton"
	button.text = LABEL_TEXT
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 启用态常亮——无前置条件（Button 默认 enabled，无需显式设 disabled）
	add_child(button)
	_apply_visibility()


## 应用阶段（phase_changed 载荷——AC-7：仅阶段 2 可见）。
func apply_phase(new_phase: int) -> void:
	_phase = new_phase
	_apply_visibility()


## 是否可见（测试断言用——仅阶段 2 可见）。
func is_visible_in_phase() -> bool:
	return button.visible


## 按钮启用态（测试断言用——常亮，无前置条件）。
func is_enabled() -> bool:
	return not button.disabled


## === 内部 ====================================================================

## 阶段 2 可见性落定（其余阶段隐藏——PLAY_PHASE 常量关联 CombatPhase.PLAY）。
func _apply_visibility() -> void:
	button.visible = _phase == PLAY_PHASE
