class_name DeckCounter
extends Control
## DeckCounter —— 底部条牌库/弃牌堆计数组件（combat-ui-layout Story 005）。
##
## [b]职责[/b]：牌库剩余张数 + 弃牌堆张数的数字显示（GDD §4 费用栏右侧）。
## 点击展开牌库/弃牌详情归 interaction epic——本 story 只渲染计数。[br]
## [br][b]stub 先行[/b]（2026-11-01 用户裁决）：CombatSystem 抽牌/弃牌/洗牌
## 尚未发射牌库变化信号——本接口公开 [method set_deck_counts] 供测试直调与
## 未来接线（同 story 004 日志 append_entry stub 模式）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：计数为渲染快照——数字由战斗系统
## 信号组装后传入，本组件只持展示值。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §4/§费用栏右侧计数、
## combat-ui-layout Story 005（AC-5）。

## === 视觉常量 ================================================================

## 牌库数字字号。
const DECK_FONT_SIZE: int = 14
## 牌库数字色（近白）。
const DECK_COLOR: Color = Color(0.92, 0.92, 0.90)
## 弃牌堆数字色（灰）。
const DISCARD_COLOR: Color = Color(0.58, 0.58, 0.60)

## === 子节点引用 ==============================================================

## 牌库计数 Label（「≡牌库:N」）。
var deck_label: Label = null
## 弃牌堆计数 Label（「弃:N」）。
var discard_label: Label = null

## === 运行态（渲染快照）=======================================================

## 牌库剩余张数。
var _deck_count: int = 0
## 弃牌堆张数。
var _discard_count: int = 0


func _init() -> void:
	_build()


## 构建子节点（牌库 + 弃牌 Label——_init 构建）。
func _build() -> void:
	custom_minimum_size = Vector2(110, 32)
	deck_label = Label.new()
	deck_label.name = "DeckLabel"
	deck_label.add_theme_font_size_override("font_size", DECK_FONT_SIZE)
	deck_label.add_theme_color_override("font_color", DECK_COLOR)
	deck_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	deck_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	deck_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(deck_label)
	discard_label = Label.new()
	discard_label.name = "DiscardLabel"
	discard_label.add_theme_font_size_override("font_size", DECK_FONT_SIZE)
	discard_label.add_theme_color_override("font_color", DISCARD_COLOR)
	discard_label.anchor_left = 0.0
	discard_label.anchor_top = 0.0
	discard_label.anchor_right = 0.0
	discard_label.anchor_bottom = 0.0
	discard_label.offset_top = 16.0
	discard_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(discard_label)
	_apply_texts()


## 设置牌库/弃牌计数（渲染管线入口——数字由战斗系统组装后传入）。[br]
## [b]stub 先行[/b]：真信号源（牌库变化信号）归后续 story，当前供测试直调。
func set_deck_counts(deck_count: int, discard_count: int) -> void:
	_deck_count = maxi(deck_count, 0)
	_discard_count = maxi(discard_count, 0)
	_apply_texts()


## 获取牌库计数（测试断言用）。
func get_deck_count() -> int:
	return _deck_count


## 获取弃牌堆计数（测试断言用）。
func get_discard_count() -> int:
	return _discard_count


## 获取牌库文本（测试断言用）。
func get_deck_text() -> String:
	return deck_label.text


## 获取弃牌堆文本（测试断言用）。
func get_discard_text() -> String:
	return discard_label.text


## === 内部 ====================================================================

## 计数文本落定。
func _apply_texts() -> void:
	deck_label.text = "≡牌库:%d" % _deck_count
	discard_label.text = "弃:%d" % _discard_count
