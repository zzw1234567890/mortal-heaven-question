# VERTICAL SLICE - NOT FOR PRODUCTION
# Date: 2026-07-27
##
## 角色选择界面 —— 居中面板 + 全屏暗背景

class_name VSCharacterSelectionScreen
extends Control

signal characters_selected(character_ids: Array[String])

var _available_characters: Array[String] = []
var _selected_characters: Array[String] = []
var _character_buttons: Dictionary = {}

var _title_label: Label
var _character_grid: GridContainer
var _confirm_button: Button
var _selected_label: Label


func _ready() -> void:
	# 手动撑满视口（父节点是普通 Node，anchors 不可靠）
	var vs := get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vs

	_available_characters = VSCharacterData.STARTING_CHARACTERS.duplicate()
	_build_ui(vs)
	_update_selected_label()


func _build_ui(vs: Vector2) -> void:
	# 全屏暗背景
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.03, 0.95)
	bg.position = Vector2.ZERO
	bg.size = vs
	add_child(bg)

	# 居中面板
	var pw: float = 640.0
	var ph: float = 500.0
	var panel := PanelContainer.new()
	panel.position = Vector2((vs.x - pw) / 2.0, (vs.y - ph) / 2.0)
	panel.size = Vector2(pw, ph)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.06, 0.9)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 20.0
	vbox.offset_top = 20.0
	vbox.offset_right = -20.0
	vbox.offset_bottom = -20.0
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	_title_label = Label.new()
	_title_label.text = "选择上阵角色（1-6 名）"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4, 1))
	vbox.add_child(_title_label)

	_character_grid = GridContainer.new()
	_character_grid.columns = 3
	_character_grid.add_theme_constant_override("h_separation", 12)
	_character_grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(_character_grid)

	for char_id in _available_characters:
		var char_data: Dictionary = VSCharacterData.CHARACTERS[char_id]
		var button := Button.new()
		button.text = "%s\n%s\nHP:%d ATK:%d" % [
			char_data.get("name", ""),
			char_data.get("profession", ""),
			char_data.get("max_hp", 0),
			char_data.get("attack", 0),
		]
		button.custom_minimum_size = Vector2(180, 72)
		button.pressed.connect(_on_character_button_pressed.bind(char_id, button))
		_character_grid.add_child(button)
		_character_buttons[char_id] = button

	_selected_label = Label.new()
	_selected_label.text = "未选择角色"
	_selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_selected_label.add_theme_font_size_override("font_size", 16)
	vbox.add_child(_selected_label)

	_confirm_button = Button.new()
	_confirm_button.text = "确认出战"
	_confirm_button.custom_minimum_size = Vector2(200, 48)
	_confirm_button.add_theme_font_size_override("font_size", 20)
	_confirm_button.disabled = true
	_confirm_button.pressed.connect(_on_confirm_pressed)
	vbox.add_child(_confirm_button)


func _on_character_button_pressed(char_id: String, button: Button) -> void:
	if char_id in _selected_characters:
		_selected_characters.erase(char_id)
		button.modulate = Color.WHITE
	else:
		if _selected_characters.size() < 6:
			_selected_characters.append(char_id)
			button.modulate = Color(0.8, 1.0, 0.8)
	_update_selected_label()


func _update_selected_label() -> void:
	if _selected_characters.is_empty():
		_selected_label.text = "未选择角色"
		_confirm_button.disabled = true
	else:
		var names: Array[String] = []
		for char_id in _selected_characters:
			var char_data: Dictionary = VSCharacterData.CHARACTERS[char_id]
			names.append(char_data.get("name", ""))
		_selected_label.text = "已选择 %d 个角色：%s" % [_selected_characters.size(), ", ".join(names)]
		_confirm_button.disabled = false


func _on_confirm_pressed() -> void:
	if not _selected_characters.is_empty():
		visible = false
		characters_selected.emit(_selected_characters)
		queue_free()