# VERTICAL SLICE - NOT FOR PRODUCTION
# Date: 2026-07-27
##
## 战斗 HUD -- 显示双方 6 阵位 + 手牌 + 行动日志 + 修为进度 + 境界信息。
## 垂直切片 D1：新增修为进度条、境界标签、突破按钮。
## 所有子节点程序化创建，无外部 .tscn 依赖。

class_name VSBattleHUD
extends Control

signal character_slot_clicked(slot_index: int)
signal enemy_slot_clicked(slot_index: int)
signal breakthrough_button_pressed()

var mana_label: Label
var realm_label: Label
var cultivation_bar: ProgressBar
var cultivation_label: Label
var shield_label: Label
var turn_label: Label
var alive_count_label: Label

var hand_container: HBoxContainer
var action_log: RichTextLabel
var end_turn_button: Button
var breakthrough_button: Button

var result_panel: Panel
var result_label: Label
var return_button: Button

var ally_slot_buttons: Array[Button] = []
var enemy_slot_buttons: Array[Button] = []

var _target_selection_label: Label
var _breakthrough_ready_panel: Panel
var _deployment_ref: VSDeploymentState
var _enemy_ref: VSEnemyAI
var _player_ref: VSPlayerState


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_PASS
	_build_ui()


func _build_ui() -> void:
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_vbox.offset_left = 12.0
	main_vbox.offset_top = 8.0
	main_vbox.offset_right = -12.0
	main_vbox.offset_bottom = -8.0
	main_vbox.add_theme_constant_override("separation", 6)
	main_vbox.mouse_filter = MOUSE_FILTER_PASS
	add_child(main_vbox)

	# -- 双方阵位区（上下分栏） --
	var both_sides := VBoxContainer.new()
	both_sides.add_theme_constant_override("separation", 6)
	both_sides.size_flags_vertical = Control.SIZE_EXPAND_FILL
	both_sides.mouse_filter = MOUSE_FILTER_PASS
	main_vbox.add_child(both_sides)

	var enemy_panel := _build_side_panel("敌方", Color(0.5, 0.15, 0.15, 0.5), false)
	both_sides.add_child(enemy_panel)

	var ally_panel := _build_side_panel("我方", Color(0.2, 0.3, 0.5, 0.5), true)
	both_sides.add_child(ally_panel)

	# -- 目标选择提示 --
	_target_selection_label = Label.new()
	_target_selection_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_selection_label.add_theme_font_size_override("font_size", 14)
	_target_selection_label.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1))
	_target_selection_label.visible = false
	main_vbox.add_child(_target_selection_label)

	# -- 行动日志 --
	action_log = RichTextLabel.new()
	action_log.bbcode_enabled = true
	action_log.fit_content = false
	action_log.scroll_following = true
	action_log.selection_enabled = false
	action_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_log.custom_minimum_size = Vector2(0, 80)
	main_vbox.add_child(action_log)

	# -- 状态栏 --
	var status_bar := HBoxContainer.new()
	status_bar.add_theme_constant_override("separation", 12)
	status_bar.mouse_filter = MOUSE_FILTER_PASS
	main_vbox.add_child(status_bar)

	alive_count_label = Label.new()
	alive_count_label.add_theme_font_size_override("font_size", 13)
	alive_count_label.text = "存活：0/0"
	alive_count_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
	status_bar.add_child(alive_count_label)

	realm_label = Label.new()
	realm_label.add_theme_font_size_override("font_size", 13)
	realm_label.text = "境界：炼气期"
	realm_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.4, 1))
	status_bar.add_child(realm_label)

	mana_label = Label.new()
	mana_label.add_theme_font_size_override("font_size", 13)
	mana_label.text = "灵力：0"
	status_bar.add_child(mana_label)

	shield_label = Label.new()
	shield_label.add_theme_font_size_override("font_size", 13)
	shield_label.text = "队伍护盾：0"
	shield_label.add_theme_color_override("font_color", Color(0.3, 0.5, 0.9))
	status_bar.add_child(shield_label)

	turn_label = Label.new()
	turn_label.add_theme_font_size_override("font_size", 13)
	turn_label.text = "准备中..."
	status_bar.add_child(turn_label)

	# -- 修为进度条 --
	var cultivation_box := HBoxContainer.new()
	cultivation_box.add_theme_constant_override("separation", 8)
	cultivation_box.mouse_filter = MOUSE_FILTER_PASS
	main_vbox.add_child(cultivation_box)

	var cult_title := Label.new()
	cult_title.text = "修为："
	cult_title.add_theme_font_size_override("font_size", 12)
	cult_title.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 1))
	cultivation_box.add_child(cult_title)

	cultivation_bar = ProgressBar.new()
	cultivation_bar.custom_minimum_size = Vector2(200, 18)
	cultivation_bar.min_value = 0.0
	cultivation_bar.max_value = 100.0
	cultivation_bar.value = 0.0
	cultivation_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cultivation_box.add_child(cultivation_bar)

	cultivation_label = Label.new()
	cultivation_label.text = "0/100"
	cultivation_label.add_theme_font_size_override("font_size", 12)
	cultivation_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1))
	cultivation_box.add_child(cultivation_label)

	# -- 突破按钮 --
	var btn_wrap := HBoxContainer.new()
	btn_wrap.add_theme_constant_override("separation", 12)
	btn_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_wrap.mouse_filter = MOUSE_FILTER_PASS
	main_vbox.add_child(btn_wrap)

	breakthrough_button = Button.new()
	breakthrough_button.text = "突破！"
	breakthrough_button.add_theme_font_size_override("font_size", 14)
	breakthrough_button.custom_minimum_size = Vector2(100, 30)
	breakthrough_button.visible = false
	breakthrough_button.pressed.connect(_on_breakthrough_button_pressed)
	btn_wrap.add_child(breakthrough_button)

	# -- 突破就绪面板 --
	_breakthrough_ready_panel = Panel.new()
	_breakthrough_ready_panel.anchor_left = 0.5
	_breakthrough_ready_panel.anchor_right = 0.5
	_breakthrough_ready_panel.offset_left = -200.0
	_breakthrough_ready_panel.offset_right = 200.0
	_breakthrough_ready_panel.anchor_top = 1.0
	_breakthrough_ready_panel.anchor_bottom = 1.0
	_breakthrough_ready_panel.offset_top = -80.0
	_breakthrough_ready_panel.offset_bottom = -0.0
	_breakthrough_ready_panel.visible = false
	var bstyle := StyleBoxFlat.new()
	bstyle.bg_color = Color(0.15, 0.1, 0.3, 0.95)
	bstyle.border_width_left = 2
	bstyle.border_width_right = 2
	bstyle.border_width_top = 2
	bstyle.border_color = Color(0.9, 0.7, 0.2, 1)
	_breakthrough_ready_panel.add_theme_stylebox_override("panel", bstyle)
	add_child(_breakthrough_ready_panel)

	# -- 手牌区域 --
	var hand_bg := PanelContainer.new()
	hand_bg.custom_minimum_size = Vector2(0, 110)
	hand_bg.mouse_filter = MOUSE_FILTER_PASS
	var hand_style := StyleBoxFlat.new()
	hand_style.bg_color = Color(0.08, 0.07, 0.05, 0.6)
	hand_bg.add_theme_stylebox_override("panel", hand_style)
	main_vbox.add_child(hand_bg)

	hand_container = HBoxContainer.new()
	hand_container.add_theme_constant_override("separation", 6)
	hand_container.alignment = BoxContainer.ALIGNMENT_CENTER
	hand_container.mouse_filter = MOUSE_FILTER_PASS
	hand_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hand_bg.add_child(hand_container)

	# -- 结束回合按钮 --
	var endbtn_wrap := HBoxContainer.new()
	endbtn_wrap.alignment = BoxContainer.ALIGNMENT_CENTER
	endbtn_wrap.mouse_filter = MOUSE_FILTER_PASS
	main_vbox.add_child(endbtn_wrap)

	end_turn_button = Button.new()
	end_turn_button.text = "结束回合 ->"
	end_turn_button.add_theme_font_size_override("font_size", 13)
	end_turn_button.custom_minimum_size = Vector2(110, 28)
	endbtn_wrap.add_child(end_turn_button)

	# -- 结算面板（屏幕居中） --
	result_panel = Panel.new()
	result_panel.anchor_left = 0.5
	result_panel.anchor_right = 0.5
	result_panel.anchor_top = 0.5
	result_panel.anchor_bottom = 0.5
	result_panel.offset_left = -160.0
	result_panel.offset_top = -90.0
	result_panel.offset_right = 160.0
	result_panel.offset_bottom = 90.0
	result_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.08, 0.06, 0.95)
	result_panel.add_theme_stylebox_override("panel", panel_style)
	add_child(result_panel)

	var rv := VBoxContainer.new()
	rv.set_anchors_preset(Control.PRESET_FULL_RECT)
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	result_panel.add_child(rv)

	result_label = Label.new()
	result_label.add_theme_font_size_override("font_size", 32)
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rv.add_child(result_label)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	rv.add_child(sp)

	return_button = Button.new()
	return_button.text = "返回主菜单"
	return_button.add_theme_font_size_override("font_size", 15)
	return_button.custom_minimum_size = Vector2(150, 36)
	rv.add_child(return_button)


func _build_side_panel(title: String, bg_color: Color, is_ally: bool) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = MOUSE_FILTER_PASS
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	vbox.mouse_filter = MOUSE_FILTER_PASS
	panel.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = title
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	vbox.add_child(title_lbl)

	var front_row := HBoxContainer.new()
	front_row.add_theme_constant_override("separation", 3)
	front_row.mouse_filter = MOUSE_FILTER_PASS
	vbox.add_child(front_row)

	for i in range(3):
		var btn := _create_slot_mini(i, is_ally)
		front_row.add_child(btn)
		if is_ally:
			ally_slot_buttons.append(btn)
		else:
			enemy_slot_buttons.append(btn)

	var back_row := HBoxContainer.new()
	back_row.add_theme_constant_override("separation", 3)
	back_row.mouse_filter = MOUSE_FILTER_PASS
	vbox.add_child(back_row)

	for i in range(3, 6):
		var btn := _create_slot_mini(i, is_ally)
		back_row.add_child(btn)
		if is_ally:
			ally_slot_buttons.append(btn)
		else:
			enemy_slot_buttons.append(btn)

	return panel


func _create_slot_mini(slot_index: int, is_ally: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 55)
	btn.text = "空" if is_ally else "敌"
	btn.clip_text = true
	btn.add_theme_font_size_override("font_size", 10)
	if is_ally:
		btn.pressed.connect(_on_ally_slot_pressed.bind(slot_index))
	else:
		btn.pressed.connect(_on_enemy_slot_pressed.bind(slot_index))
	return btn


func _on_ally_slot_pressed(slot_index: int) -> void:
	character_slot_clicked.emit(slot_index)


func _on_enemy_slot_pressed(slot_index: int) -> void:
	enemy_slot_clicked.emit(slot_index)


func _on_breakthrough_button_pressed() -> void:
	breakthrough_button_pressed.emit()


func setup(player_state: VSPlayerState, enemy_ai: VSEnemyAI, deployment: VSDeploymentState) -> void:
	_deployment_ref = deployment
	_enemy_ref = enemy_ai
	_player_ref = player_state

	realm_label.text = "境界：%s" % VSRealmData.get_realm_name(player_state.realm_level)
	mana_label.text = "灵力：%d" % player_state.get_current_mana()
	cultivation_bar.max_value = float(player_state.cultivation_system.get_max_cultivation())
	_update_cultivation_display()
	turn_label.text = "第 1 回合"
	update_alive_count()

	# 信号连接
	player_state.cost_changed.connect(_on_mana_changed)
	player_state.cultivation_changed.connect(_on_cultivation_changed)
	player_state.cultivation_max_changed.connect(_on_cultivation_max_changed)
	player_state.breakthrough_ready.connect(_on_breakthrough_ready)
	player_state.realm_changed.connect(_on_realm_changed)

	deployment.character_deployed.connect(_on_ally_deployed)
	deployment.character_hp_changed.connect(_on_ally_hp_changed)
	deployment.character_shield_changed.connect(_on_ally_shield_changed)
	deployment.character_died.connect(_on_ally_died)

	enemy_ai.enemy_slot_hp_changed.connect(_on_enemy_hp_changed)
	enemy_ai.enemy_slot_died.connect(_on_enemy_died)


func _on_mana_changed(_old: int, new: int) -> void:
	mana_label.text = "灵力：%d" % new


func _on_cultivation_changed(_old: int, new: int) -> void:
	_update_cultivation_display()


func _on_cultivation_max_changed(_old: int, new: int) -> void:
	cultivation_bar.max_value = float(new)
	_update_cultivation_display()


func _on_breakthrough_ready() -> void:
	breakthrough_button.visible = true
	breakthrough_button.disabled = false
	_breakthrough_ready_panel.visible = true


func _on_realm_changed(_old_realm: int, new_realm: int, new_name: String) -> void:
	realm_label.text = "境界：%s" % new_name
	breakthrough_button.visible = false
	_breakthrough_ready_panel.visible = false


func _update_cultivation_display() -> void:
	if _player_ref == null:
		return
	var cur: int = _player_ref.cultivation_system.get_current_cultivation()
	var m: int = _player_ref.cultivation_system.get_max_cultivation()
	cultivation_bar.value = float(cur) if m > 0 else 0.0
	cultivation_label.text = "%d/%d" % [cur, m]


func update_enemy_display(enemy_ai: VSEnemyAI) -> void:
	_enemy_ref = enemy_ai
	for i in range(6):
		_refresh_enemy_slot(i)
	update_alive_count()


func _on_ally_deployed(slot_index: int, _char_id: String) -> void:
	_refresh_ally_slot(slot_index)
	update_alive_count()


func _on_ally_hp_changed(slot_index: int, _old: int, _new: int) -> void:
	_refresh_ally_slot(slot_index)


func _on_ally_shield_changed(slot_index: int, _old_s: int, _new_s: int) -> void:
	_refresh_ally_slot(slot_index)
	_update_team_shield()


func _on_ally_died(slot_index: int) -> void:
	_refresh_ally_slot(slot_index)
	update_alive_count()


func _on_enemy_hp_changed(slot_index: int, _old: int, _new: int) -> void:
	_refresh_enemy_slot(slot_index)


func _on_enemy_died(slot_index: int) -> void:
	_refresh_enemy_slot(slot_index)


func _refresh_ally_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= ally_slot_buttons.size() or _deployment_ref == null:
		return
	var btn := ally_slot_buttons[slot_index]
	var cd: Dictionary = _deployment_ref.get_character(slot_index)
	if not cd.get("is_alive", false):
		btn.text = "阵亡"
		btn.modulate = Color(0.35, 0.35, 0.35, 0.5)
		return
	var cdata: Dictionary = VSCharacterData.CHARACTERS.get(cd.get("character_id", ""), {})
	var n: String = cdata.get("name", "?")
	var hp: int = cd.get("current_hp", 0)
	var mhp: int = cd.get("max_hp", 0)
	var sh: int = cd.get("shield", 0)
	var st := "S" if sh > 0 else ""
	btn.text = "%s\n%d/%d%s" % [n, hp, mhp, st]
	btn.modulate = Color(0.85, 0.9, 1.0) if slot_index < 3 else Color(0.92, 0.85, 1.0)


func _refresh_enemy_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= enemy_slot_buttons.size() or _enemy_ref == null:
		return
	var btn := enemy_slot_buttons[slot_index]
	var ed: Dictionary = _enemy_ref.get_slot(slot_index)
	if ed.is_empty():
		return
	if ed.get("character_id", "") == "":
		return
	if not ed.get("is_alive", false):
		btn.text = "阵亡"
		btn.modulate = Color(0.35, 0.35, 0.35, 0.5)
		return
	# 获取敌方角色名称（支持按境界缩放后的名字）
	var cid: String = ed.get("character_id", "")
	var ename: String = cid  # 默认用 ID
	# 从敌方 AI 的库中找（可能按境界缩放后）
	if _enemy_ref.has_method("get_enemy_name"):
		ename = _enemy_ref.get_enemy_name(slot_index)
	var hp: int = ed.get("current_hp", 0)
	var mhp: int = ed.get("max_hp", 0)
	btn.text = "%s\n%d/%d" % [ename, hp, mhp]
	btn.modulate = Color(1.0, 0.75, 0.7) if slot_index < 3 else Color(1.0, 0.6, 0.6)


func update_alive_count() -> void:
	if _deployment_ref == null or _enemy_ref == null:
		return
	var aa: int = _deployment_ref.get_alive_count()
	var ea: int = _enemy_ref.get_alive_count()
	alive_count_label.text = "我方：%d | 敌方：%d" % [aa, ea]


func _update_team_shield() -> void:
	if _deployment_ref == null:
		return
	var ts: int = 0
	for i in range(6):
		ts += _deployment_ref.get_character(i).get("shield", 0)
	shield_label.text = "队伍护盾：%d" % ts


func set_turn_label(text: String) -> void:
	turn_label.text = text
	end_turn_button.disabled = false


func show_victory() -> void:
	_show_result("胜  利", Color.GOLD)


func show_defeat() -> void:
	_show_result("败  北", Color(0.8, 0.2, 0.2))


func show_breakthrough_ready() -> void:
	## 修为满了——在日志中提示玩家点击突破按钮。
	_log("")
	_log("[color=gold][b]修为已满！点击底部 [突破！] 按钮触发渡劫突破！[/b][/color]")
	breakthrough_button.visible = true
	breakthrough_button.disabled = false
	_breakthrough_ready_panel.visible = false  ## 战斗结算后不弹面板，让玩家点突破


func show_breakthrough_success(new_name: String) -> void:
	## 突破成功——大屏提示。
	_log("")
	_log("[color=gold][b]突破成功！你已进入 [%s]！[/b][/color]" % new_name)
	# 闪烁效果
	var tween := create_tween()
	tween.tween_callback(func(): realm_label.modulate = Color.GOLD)
	tween.tween_interval(0.3)
	tween.tween_callback(func(): realm_label.modulate = Color(0.95, 0.85, 0.4, 1))
	tween.tween_interval(0.3)


func _show_result(text: String, color: Color) -> void:
	result_label.text = text
	result_label.add_theme_color_override("font_color", color)
	result_panel.visible = true
	end_turn_button.disabled = true
	hand_container.visible = false
	breakthrough_button.visible = false
	_breakthrough_ready_panel.visible = false


func log_action(card_name: String, effect: String, value: int) -> void:
	if effect == "---":
		_log(card_name)
	else:
		_log("打出 [color=cyan]%s[/color]：%s %d 点" % [card_name, effect, value])


func _log(msg: String) -> void:
	action_log.append_text(msg + "\n")


func enter_target_selection_mode(mode_text: String) -> void:
	_target_selection_label.text = "> %s（点击角色阵位）" % mode_text
	_target_selection_label.visible = true
	_highlight_ally_slots()


func exit_target_selection_mode() -> void:
	_target_selection_label.visible = false
	_reset_ally_highlights()


func _highlight_ally_slots() -> void:
	if _deployment_ref == null:
		return
	for i in range(ally_slot_buttons.size()):
		var cd: Dictionary = _deployment_ref.get_character(i)
		if cd.get("is_alive", false):
			ally_slot_buttons[i].add_theme_color_override("font_color", Color(0.2, 1.0, 0.2))
		else:
			ally_slot_buttons[i].disabled = true


func _reset_ally_highlights() -> void:
	for i in range(ally_slot_buttons.size()):
		ally_slot_buttons[i].remove_theme_color_override("font_color")
		var cd: Dictionary = _deployment_ref.get_character(i) if _deployment_ref else {}
		ally_slot_buttons[i].disabled = not cd.get("is_alive", true)
