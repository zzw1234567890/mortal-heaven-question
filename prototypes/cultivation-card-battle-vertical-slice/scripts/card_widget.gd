# VERTICAL SLICE - NOT FOR PRODUCTION
# Validation Question: 玩家能否在 3 分钟内完成一场卡牌战斗——打出卡牌、
#   看到效果结算并击败敌人——且架构遵循 Foundation 层设计？
# Date: 2026-07-27
##
## 单张手牌控件——展示卡牌信息，处理点击打出。
## 所有子节点在 _init() 中程序化创建——垂直切片无需单独 .tscn 场景。
## 生产环境中由战斗 UI 系统的 CardWidget 场景替代。

class_name VSCardWidget
extends Control

signal card_played(card_id: String)

const CARD_WIDTH: float = 130.0
const CARD_HEIGHT: float = 150.0

var card_id: String = ""
var _card_def: Dictionary = {}
var _can_play: bool = true

## 子节点——程序化创建

var bg_rect: ColorRect
var name_label: Label
var cost_label: Label
var desc_label: Label
var select_border: ColorRect


func _init() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	mouse_filter = MOUSE_FILTER_STOP

	# 背景
	bg_rect = ColorRect.new()
	bg_rect.name = "Background"
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg_rect)

	# 卡名
	name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_color_override("font_color", Color.BLACK)
	name_label.anchor_left = 0.0; name_label.offset_left = 4.0
	name_label.anchor_right = 1.0; name_label.offset_right = -4.0
	name_label.anchor_top = 0.0; name_label.offset_top = 10.0
	name_label.offset_bottom = 36.0
	name_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(name_label)

	# 费用
	cost_label = Label.new()
	cost_label.name = "CostLabel"
	cost_label.add_theme_font_size_override("font_size", 18)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.add_theme_color_override("font_color", Color.BLACK)
	cost_label.anchor_left = 0.0; cost_label.offset_left = CARD_WIDTH - 34.0
	cost_label.anchor_right = 1.0; cost_label.offset_right = 0.0
	cost_label.anchor_top = 0.0; cost_label.offset_top = 5.0
	cost_label.offset_bottom = 30.0
	cost_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(cost_label)

	# 描述
	desc_label = Label.new()
	desc_label.name = "DescLabel"
	desc_label.add_theme_font_size_override("font_size", 11)
	desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("font_color", Color.BLACK)
	desc_label.anchor_left = 0.0; desc_label.offset_left = 6.0
	desc_label.anchor_right = 1.0; desc_label.offset_right = -6.0
	desc_label.anchor_bottom = 1.0; desc_label.offset_bottom = -8.0
	desc_label.offset_top = -48.0
	desc_label.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(desc_label)

	# 选中边框
	select_border = ColorRect.new()
	select_border.name = "SelectBorder"
	select_border.set_anchors_preset(Control.PRESET_FULL_RECT)
	select_border.color = Color(0.0, 0.8, 0.8, 0.3)
	select_border.visible = false
	select_border.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(select_border)


func setup(card: Dictionary) -> void:
	_card_def = card
	card_id = card.get("id", "")
	name_label.text = card.get("name", "???")
	cost_label.text = str(card.get("cost", 0))
	desc_label.text = card.get("description", "")

	# 按类型着色
	var type_color := _get_type_color(card.get("type", "damage"))
	bg_rect.color = type_color


func set_can_play(can: bool) -> void:
	_can_play = can
	if not can:
		modulate = Color(0.4, 0.4, 0.4, 0.7)  ## 灰度——费用不足
	else:
		modulate = Color.WHITE


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not _can_play:
			return
		# 打出——不做选中动画，直接触发信号
		select_border.visible = true
		card_played.emit(card_id)
		select_border.visible = false


func _get_type_color(type: String) -> Color:
	match type:
		"damage":
			return Color(0.9, 0.2, 0.2, 0.85)   ## 朱砂红
		"heal":
			return Color(0.2, 0.7, 0.3, 0.85)    ## 翠玉绿
		"shield":
			return Color(0.3, 0.5, 0.9, 0.85)    ## 湛蓝
		_:
			return Color(0.5, 0.5, 0.5, 0.85)    ## 中灰
