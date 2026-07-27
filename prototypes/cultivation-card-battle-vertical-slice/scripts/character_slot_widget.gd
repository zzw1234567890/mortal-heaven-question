# VERTICAL SLICE - NOT FOR PRODUCTION
# Date: 2026-07-27
##
## 角色阵位显示组件——显示单个角色的状态（HP条、名字、职业）。
## 所有 UI 程序化创建，无外部 .tscn 依赖。

class_name VSCharacterSlotWidget
extends PanelContainer

signal slot_clicked(slot_index: int)

var slot_index: int = -1
var character_id: String = ""
var is_front_row: bool = true

var name_label: Label
var profession_label: Label
var hp_bar: ProgressBar
var hp_label: Label
var background: ColorRect


func _init() -> void:
	custom_minimum_size = Vector2(120, 100)

	# 背景
	background = ColorRect.new()
	background.name = "Background"
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.2, 0.2, 0.2, 0.8)
	add_child(background)

	# 内容容器
	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8.0
	vbox.offset_top = 8.0
	vbox.offset_right = -8.0
	vbox.offset_bottom = -8.0
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	# 名字
	name_label = Label.new()
	name_label.name = "NameLabel"
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	# 职业
	profession_label = Label.new()
	profession_label.name = "ProfessionLabel"
	profession_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	profession_label.add_theme_font_size_override("font_size", 11)
	profession_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(profession_label)

	# HP 条
	hp_bar = ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.custom_minimum_size = Vector2(0, 16)
	hp_bar.show_percentage = false
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.2, 0.6, 0.2, 0.8)
	hp_bar.add_theme_stylebox_override("fill", bar_style)
	vbox.add_child(hp_bar)

	# HP 文字
	hp_label = Label.new()
	hp_label.name = "HPLabel"
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.add_theme_font_size_override("font_size", 11)
	vbox.add_child(hp_label)


func setup(index: int, char_id: String, front_row: bool) -> void:
	slot_index = index
	character_id = char_id
	is_front_row = front_row

	if char_id != "" and char_id in VSCharacterData.CHARACTERS:
		var char_data: Dictionary = VSCharacterData.CHARACTERS[char_id]
		name_label.text = char_data.get("name", "")
		profession_label.text = char_data.get("profession", "")

		# 根据前后排设置背景色
		if front_row:
			background.color = Color(0.2, 0.3, 0.5, 0.8)  # 蓝色调
		else:
			background.color = Color(0.3, 0.2, 0.5, 0.8)  # 紫色调


func update_hp(current_hp: int, max_hp: int) -> void:
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_label.text = "%d/%d" % [current_hp, max_hp]

	# HP 低于 30% 时变红
	if current_hp < max_hp * 0.3:
		hp_bar.modulate = Color(1.0, 0.3, 0.3)
	else:
		hp_bar.modulate = Color.WHITE


func set_dead() -> void:
	modulate = Color(0.3, 0.3, 0.3, 0.5)
	name_label.text = "（已阵亡）"


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		slot_clicked.emit(slot_index)
