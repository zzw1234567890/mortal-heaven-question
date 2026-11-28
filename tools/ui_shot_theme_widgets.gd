extends RefCounted
## ui_shot_theme 的陈列屏构建册：把本轮补进主题的九个控件族摆成一屏，供肉眼验收。[br]
## [br][b]为什么单独一册[/b]：这一屏的构件多（三列 + 弹层 + 一整套排版小工具），与主册
## [code]tools/ui_shot_theme.gd[/code] 合起来会越过 300 行软上限（.claude/docs/coding-standards.md）
## ——同 [code]tools/gen_theme_widgets.gd[/code] 的拆册理由。[br]
## [br]本册[b]自闭环[/b]：三列用到的排版小工具（[method _column] / [method _caption] /
## [method _palette]）只在这里用，故一并搬过来；主册只负责「挂场景 → 等 → 截图 → 拆场景」
## 这条流程（截图与帧等待仍在主册，本册不碰 [code]Viewport[/code]）。[br]
## [br]无状态：全部 static，由主册 [code]Widgets.build(self)[/code] 一次调用建出整屏。

## 陈列屏里要摆的字号档位——与主册的变体名一一对应（顺带验收变体在真场景里解析）。
const TIER_ROWS: Array = [
	["DisplayText", "主标题 DisplayText 48"],
	["TitleText", "屏内标题 TitleText 32"],
	["SubtitleText", "数值行 SubtitleText 22"],
	["BodyText", "正文 BodyText 16"],
	["CaptionText", "说明 CaptionText 13"],
]


## 建出整屏陈列界面，返回宿主 [Control]（调用方负责 queue_free）。[br]
## [br][b]为什么要真的 popup[/b]：下拉列表 / 右键菜单 / 工具提示的样式盒只在弹出后才画，
## 不弹就是三个空槽位，「补了控件族外观」这件事等于没取证——见 [method _popup_demos]。[br]
## [br]调用方接着要做的：等若干帧、[code]await _capture(...)[/code]、再 [code]queue_free()[/code]。[br]
## [br][param p_host] 宿主节点（主册自己）——弹层与背景板都挂在它下面。
static func build(p_host: Node) -> Control:
	var holder: Control = Control.new()
	holder.name = "WidgetsHolder"
	holder.size = Vector2(1920, 1080)
	p_host.add_child(holder)

	var backdrop := ColorRect.new()
	backdrop.color = _palette(&"backdrop")
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(backdrop)

	var root := HBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40.0
	root.offset_top = 32.0
	root.offset_right = -40.0
	root.offset_bottom = -32.0
	root.add_theme_constant_override(&"separation", 32)
	holder.add_child(root)

	root.add_child(_column_text_and_buttons())
	root.add_child(_column_bars_and_inputs())
	root.add_child(_column_popups())
	return holder


## 第一列：文字档位 + Button 四态 + CheckBox / CheckButton 各态 + NavButton。
static func _column_text_and_buttons() -> Control:
	var col := _column("文字档位与按钮")
	for tier: Array in TIER_ROWS:
		var l := Label.new()
		l.text = tier[1]
		l.theme_type_variation = StringName(tier[0])
		col.add_child(l)
	col.add_child(_caption("—— Button 四态 ——"))
	for spec: Array in [["常态", true, false], ["禁用", false, true]]:
		var b := Button.new()
		b.text = spec[0]
		b.disabled = bool(spec[2])
		col.add_child(b)
	# 悬停 / 按下是瞬时态，theme_override 伪造不出来——由主册推真实鼠标事件压上去
	# （见 [code]tools/ui_shot_theme.gd[/code] 的 [code]_hover_at[/code] / [code]_press_at[/code]）。
	var hover := Button.new()
	hover.name = "HoverDemo"
	hover.text = "悬停（真鼠标压上）"
	col.add_child(hover)
	var pressed := Button.new()
	pressed.name = "PressDemo"
	pressed.text = "按下（真鼠标按住）"
	col.add_child(pressed)
	col.add_child(_caption("—— NavButton / CheckBox / CheckButton ——"))
	var nav := Button.new()
	nav.text = "NavButton 变体 18"
	nav.theme_type_variation = &"NavButton"
	col.add_child(nav)
	var cb := CheckBox.new()
	cb.text = "CheckBox 未勾"
	col.add_child(cb)
	var cb_on := CheckBox.new()
	cb_on.text = "CheckBox 已勾"
	cb_on.button_pressed = true
	col.add_child(cb_on)
	var cbt := CheckButton.new()
	cbt.text = "CheckButton 未开"
	col.add_child(cbt)
	var cbt_on := CheckButton.new()
	cbt_on.text = "CheckButton 已开"
	cbt_on.button_pressed = true
	col.add_child(cbt_on)
	return col


## 第二列：进度条（空/半/满）+ 滑杆 + 滚动条 + 输入框 + 工具提示宿主。
static func _column_bars_and_inputs() -> Control:
	var col := _column("读数装置与输入")
	col.add_child(_caption("—— ProgressBar（0% / 45% / 100%）——"))
	for v: float in [0.0, 45.0, 100.0]:
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(320.0, 22.0)
		pb.max_value = 100.0
		pb.value = v
		pb.show_percentage = false
		col.add_child(pb)
	col.add_child(_caption("—— HSlider（音量，灰阶）——"))
	var hs := HSlider.new()
	hs.custom_minimum_size = Vector2(320.0, 32.0)
	hs.max_value = 100.0
	hs.value = 62.0
	col.add_child(hs)
	col.add_child(_caption("—— VSlider ——"))
	var vs_row := HBoxContainer.new()
	vs_row.add_theme_constant_override(&"separation", 24)
	var vs := VSlider.new()
	vs.custom_minimum_size = Vector2(32.0, 120.0)
	vs.max_value = 100.0
	vs.value = 40.0
	vs_row.add_child(vs)
	# 细杆：一条横向 ScrollContainer 里的长内容 → VScrollBar；再一条竖列表 → HScrollBar。
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(240.0, 120.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var inner := VBoxContainer.new()
	for i: int in range(12):
		var l := Label.new()
		l.text = "滚动内容第 %d 行" % (i + 1)
		inner.add_child(l)
	scroll.add_child(inner)
	vs_row.add_child(scroll)
	col.add_child(vs_row)
	col.add_child(_caption("—— LineEdit / TextEdit ——"))
	var le := LineEdit.new()
	le.placeholder_text = "占位提示（T-3）"
	le.text = "录入文字（T-0）"
	col.add_child(le)
	var le_ro := LineEdit.new()
	le_ro.text = "只读（T-3 文字 + BG-0 底）"
	le_ro.editable = false
	col.add_child(le_ro)
	var te := TextEdit.new()
	te.custom_minimum_size = Vector2(320.0, 90.0)
	te.text = "多行输入：当前行底色 BG-3 半透明。\n第二行。"
	col.add_child(te)
	col.add_child(_caption("—— Tooltip（鼠标压上去看浮层）——"))
	var tip := Button.new()
	tip.name = "TooltipDemo"
	tip.text = "悬停我看工具提示"
	tip.tooltip_text = "工具提示：深底浅字，字号比正文小一档"
	col.add_child(tip)
	return col


## 第三列：下拉框 + PopupMenu + 焦点态输入框。
static func _column_popups() -> Control:
	var col := _column("选择控件与弹层")
	col.add_child(_caption("—— OptionButton（真下拉）——"))
	var ob := OptionButton.new()
	ob.name = "OptionDemo"
	for item: String in ["全屏", "窗口化", "无边框窗口"]:
		ob.add_item(item)
	ob.selected = 0
	col.add_child(ob)
	var ob_dis := OptionButton.new()
	ob_dis.add_item("禁用态下拉框")
	ob_dis.disabled = true
	col.add_child(ob_dis)
	col.add_child(_caption("—— PopupMenu（面板 / 悬停 / 分隔线）——"))
	var menu := PopupMenu.new()
	menu.name = "MenuDemo"
	menu.add_item("普通条目")
	menu.add_item("已勾选条目")
	menu.set_item_checked(1, true)
	menu.add_item("禁用条目")
	menu.set_item_disabled(2, true)
	menu.add_separator("分组")
	menu.add_item("快捷键条目")
	menu.set_item_accelerator(3, KEY_MASK_CTRL | KEY_S)
	col.add_child(menu)
	col.add_child(_caption("—— LineEdit 焦点态（朱砂描边）——"))
	var focus_le := LineEdit.new()
	focus_le.name = "FocusDemo"
	focus_le.text = "焦点描边"
	col.add_child(focus_le)
	col.add_child(_caption("—— 面板 / 富文本 ——"))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300.0, 0.0)
	var box := MarginContainer.new()
	box.add_theme_constant_override(&"margin_left", 12)
	box.add_theme_constant_override(&"margin_top", 8)
	box.add_theme_constant_override(&"margin_right", 12)
	box.add_theme_constant_override(&"margin_bottom", 8)
	var rtl := RichTextLabel.new()
	rtl.bbcode_enabled = true
	rtl.fit_content = true
	rtl.text = "面板底 BG-2 + 1px 描边 BG-4。[br][color=#C8A84E]WarningText 琉璃金[/color] / [color=#B3424A]DangerText 朱砂[/color]"
	box.add_child(rtl)
	panel.add_child(box)
	col.add_child(panel)
	return col


## 把三个真弹层弹出来：OptionButton 的下拉、PopupMenu、焦点态输入框。[br]
## [br][b]为什么要真弹[/b]：这三者的样式盒只在 popup / 获得焦点之后才画——不给它们这个状态，
## 截图里就是三个空槽位。[br]
## [br]由调用方在本册 [method build] 之后、等够帧再调（节点要先进树，位置才算得准）。
static func popup_demos(p_holder: Control) -> void:
	var menu: PopupMenu = p_holder.find_child("MenuDemo", true, false) as PopupMenu
	if menu != null:
		menu.position = Vector2i(1340, 300)
		menu.popup()
	var ob: OptionButton = p_holder.find_child("OptionDemo", true, false) as OptionButton
	if ob != null:
		var r: Rect2 = ob.get_global_rect()
		ob.get_popup().position = Vector2i(int(r.position.x), int(r.position.y + r.size.y + 4.0))
		ob.get_popup().popup()
	# 焦点态：真把焦点给输入框（朱砂描边只在有焦点时画）。
	var focus_le: LineEdit = p_holder.find_child("FocusDemo", true, false) as LineEdit
	if focus_le != null:
		focus_le.grab_focus()


# ═══════════════════════════════════════════════════════════════════════════════
# 排版小工具（只本册用，故随本册走）
# ═══════════════════════════════════════════════════════════════════════════════

## 一列：标题 + 竖排容器（给陈列屏分栏用）。
static func _column(p_title: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override(&"separation", 6)
	var head := Label.new()
	head.text = p_title
	head.theme_type_variation = &"TitleText"
	box.add_child(head)
	return box


## 列内的小标题（T-2 说明档）。
static func _caption(p_text: String) -> Label:
	var l := Label.new()
	l.text = p_text
	l.theme_type_variation = &"CaptionText"
	return l


## 从项目主题取调色板 token（陈列屏的底色跟游戏一致，不与真屏幕脱节）。
static func _palette(p_name: StringName) -> Color:
	var th: Theme = ThemeDB.get_project_theme()
	if th == null:
		return Color.BLACK
	return th.get_color(p_name, &"GamePalette")
