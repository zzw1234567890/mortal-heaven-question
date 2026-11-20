class_name CombatBagButton
extends Control
## CombatBagButton —— 底部条「行囊」入口按钮位（本轮：战斗内用丹药与法宝）。[br]
## [br][b]职责[/b]：按钮渲染态 + 显示时机——仅出牌阶段（阶段 2）可见，其余阶段隐藏
## （与 [EndTurnButton] 同一时机，理由见下）。[br]
## [br][b]为什么只在出牌阶段可见[/b]：GDD 的「一个回合」在战斗域就是玩家的出牌阶段
## ——敌方行动 / 结算 / 过渡期间玩家没有可支配的灵力，开一个不能用的行囊只会让人以为
## 面板坏了。与「结束出牌」按钮同生共死，玩家看到的两个按钮都在同一段时间里有效。[br]
## [br][b]不做「常驻可见 + 点了给拒绝提示」[/b]：那要额外解释「为什么现在不能开」，
## 而答案（等你的回合）玩家从按钮出现/消失本身就已经知道了。[br]
## [br][b]范围划分[/b]：按钮本体与显示/隐藏归本组件；点击之后的编排（开面板 +
## 冻结出牌输入 + 调结算层）归 [code]combat_bag_host.gd[/code]——组件不发意图信号，
## 由持有者接 [member button] 的 [signal Button.pressed]（同 [EndTurnButton] 口径）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不持游戏状态——阶段经 [method apply_phase]
## 信号驱动。[br][b]零轮询[/b]：无 [code]_process()[/code]。[br]
## [br][b]文案本地化豁免[/b]：与 combat_bottombar / end_turn_button 同源口径。
##
## @experimental
## 来源: design/gdd/alchemy-crafting-system.md §1c（丹药使用时机「战斗中或背包」）、
## ADR-0008（回合阶段）、ADR-0031 §2、先例
## [code]end_turn_button.gd[/code]（阶段驱动显隐的按钮位）。

## 按钮文本。
const LABEL_TEXT: String = "行囊"
## 按钮字号（与结束出牌按钮同档）。
const BUTTON_FONT_SIZE: int = 16
## 出牌阶段号（ADR-0008 [code]CombatPhase.PLAY[/code]——仅此阶段显示/可点）。
const PLAY_PHASE: int = 2

## 焦点环样式（松石青粗边——与商店 / 卡组编辑面板同一份来源，禁止另写一套）。
const FocusStyle: GDScript = preload(
		"res://src/ui/exploration/shop_panel_layout.gd")

## 按钮本体（持有者据此接点击）。
var button: Button = null

## 当前阶段（-1 = 未初始化——默认隐藏）。
var _phase: int = -1


func _init() -> void:
	_build()


## 构建按钮（_init 构建——不依赖场景树时序）。[br]
## [br][b]键盘/手柄可达[/b]（.claude/rules/ui-code.md 双输入）：显式钉住
## [code]focus_mode[/code] 并挂焦点环——焦点可见，不是「按了才知道」。
## 链子的串法归 [code]combat_focus_chain.gd[/code]。
func _build() -> void:
	custom_minimum_size = Vector2(88, 40)
	button = Button.new()
	button.name = "BagButton"
	button.text = LABEL_TEXT
	button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE)
	button.set_anchors_preset(Control.PRESET_FULL_RECT)
	button.focus_mode = Control.FOCUS_ALL
	FocusStyle.apply_focus_ring(button)
	# 启用态常亮——「能不能开」由持有者按阶段再次裁定（按钮可见即可点）
	add_child(button)
	_apply_visibility()


## 应用阶段（[code]phase_changed[/code] 载荷——仅阶段 2 可见）。
func apply_phase(new_phase: int) -> void:
	_phase = new_phase
	_apply_visibility()


## 是否可见（测试断言用——仅阶段 2 可见）。
func is_visible_in_phase() -> bool:
	return button.visible


## 按钮启用态（测试断言用——常亮，无前置条件）。
func is_enabled() -> bool:
	return not button.disabled


## 阶段 2 可见性落定（其余阶段隐藏——PLAY_PHASE 常量关联 CombatPhase.PLAY）。
func _apply_visibility() -> void:
	button.visible = _phase == PLAY_PHASE
