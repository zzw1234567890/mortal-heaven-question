# VERTICAL SLICE - NOT FOR PRODUCTION
# Date: 2026-07-27
##
## 胜利奖励界面 -- 居中面板 + 全屏暗背景

class_name VSRewardScreen
extends Control

signal reward_collected

var _reward_cards: Array[String] = []
var _reward_lingshi: int = 0
var _lingshi_label: Label
var _card_list: VBoxContainer


func _ready() -> void:
	var vs := get_viewport().get_visible_rect().size
	position = Vector2.ZERO
	size = vs
	_build_ui(vs)


func _build_ui(vs: Vector2) -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.03, 0.95)
	bg.position = Vector2.ZERO
	bg.size = vs
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)

	var pw: float = 400.0
	var ph: float = 320.0
	var panel := PanelContainer.new()
	panel.position = Vector2((vs.x - pw) / 2.0, (vs.y - ph) / 2.0)
	panel.size = Vector2(pw, ph)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.1, 0.08, 0.06, 0.95)
	panel.add_theme_stylebox_override("panel", ps)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 24.0
	vbox.offset_top = 24.0
	vbox.offset_right = -24.0
	vbox.offset_bottom = -24.0
	vbox.add_theme_constant_override("separation", 16)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "战斗胜利！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1))
	vbox.add_child(title)

	var sep := HSeparator.new()
	vbox.add_child(sep)

	var rt := Label.new()
	rt.text = "获得奖励"
	rt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rt.add_theme_font_size_override("font_size", 20)
	vbox.add_child(rt)

	_lingshi_label = Label.new()
	_lingshi_label.text = "灵石：+0"
	_lingshi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lingshi_label.add_theme_font_size_override("font_size", 18)
	_lingshi_label.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0, 1))
	vbox.add_child(_lingshi_label)

	var ct := Label.new()
	ct.text = "新卡牌："
	ct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ct.add_theme_font_size_override("font_size", 16)
	vbox.add_child(ct)

	_card_list = VBoxContainer.new()
	_card_list.add_theme_constant_override("separation", 8)
	vbox.add_child(_card_list)

	var cb := Button.new()
	cb.text = "确认"
	cb.custom_minimum_size = Vector2(150, 40)
	cb.add_theme_font_size_override("font_size", 18)
	cb.pressed.connect(_on_confirm_pressed)
	vbox.add_child(cb)


func set_rewards(cards: Array[String], lingshi: int) -> void:
	_reward_cards = cards
	_reward_lingshi = lingshi
	if _lingshi_label:
		_lingshi_label.text = "灵石：+%d" % lingshi
	if _card_list:
		for child in _card_list.get_children():
			child.queue_free()
		for cid in cards:
			if cid in VSCardData.CARDS:
				var cd: Dictionary = VSCardData.CARDS[cid]
				var lbl := Label.new()
				lbl.text = "  %s（费用：%d）" % [cd.get("name", ""), cd.get("cost", 0)]
				lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				lbl.add_theme_font_size_override("font_size", 16)
				_card_list.add_child(lbl)


func _on_confirm_pressed() -> void:
	reward_collected.emit()