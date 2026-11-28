extends RefCounted
## 主题生成器·控件族分册之一：读数装置与浮层（进度条 / 滑杆 / 滚动条 / 输入框 /
## 弹出层 / 工具提示 / 窗口标题栏）。[br]
## [br][b]为什么拆册[/b]：这一套槽位多、注释重，全塞进主册 [code]tools/gen_theme.gd[/code]
## 会把那个文件推过 300 行软上限（.claude/docs/coding-standards.md）。主册管调色板与四个
## 基础类型，本册与 [code]gen_theme_choices.gd[/code] 管「裸引擎外观的控件」。[br]
## [br][b]几何一律照抄引擎默认值[/b]：每个样式盒的边框宽 / 内容边距 / 圆角都对着引擎默认
## 主题逐值抄下来（探针实测，见各方法注释），只在[b]颜色[/b]上换 token。理由：四屏配色
## 收敛已经立了「零布局位移」这条规矩（[code]theme/main.tres[/code] 里 Button 的最小尺寸
## 必须仍是 [code](8,8)[/code] 就是它的可执行形式），控件族若顺手改了杆厚或内边距，
## 全库版面会跟着动。[br]
## [br][b]例外只有圆角[/b]：引擎给滑杆滑块 / 滚动条开到 10px、进度条 6px，超出 art-bible
## §3.3.1 的「全微圆角 2-4px」硬约束，本册一律收到 [constant RADIUS]。圆角不参与最小尺寸
## 计算，收窄不挪布局。[br]
## [br][b]色值来源[/b]：全部经 [code]Style.tok()[/code] 取调色板 token，本册不写任何 hex。[br]
## [br][b]状态阶梯[/b]（悬停 / 按下 / 禁用）沿用主册 Button 的既有口径（悬停
## [code]lightened(0.08)[/code]、按下 [code]darkened(0.15)[/code]），理由见
## [method _option_button] 的对应说明在姊妹册 [code]gen_theme_choices.gd[/code]。[br]
## [br][b]焦点槽一律不设[/b]——与主册同一条政策：焦点长什么样的唯一来源是
## [code]shop_panel_layout.apply_focus_ring[/code]（松石青 3px 圆角 4）。本册涉及
## [code]HScrollBar/VScrollBar[/code] 的 [code]scroll_focus[/code]；姊妹册涉及
## [code]OptionButton/focus[/code] 与 [code]TabContainer/tab_focus[/code]。

const Style: GDScript = preload("res://tools/gen_theme_style.gd")

## 全微圆角（art-bible §3.3.1 的下限，与主册 Button / Panel 同一支语言）。
const RADIUS: int = 2


## 把本册所有控件族挂到 [param p_th] 上（由主册在保存前调用）。
static func apply(p_th: Theme) -> void:
	_progress_bar(p_th)
	_sliders(p_th)
	_scroll_bars(p_th)
	_line_edit(p_th)
	_text_edit(p_th)
	_popups(p_th)
	_tooltip(p_th)
	_window(p_th)


# ═══════════════════════════════════════════════════════════════════════════════
# 一、进度条 —— 修为的读数装置
# ═══════════════════════════════════════════════════════════════════════════════

## 槽 + 填充两档。[br]
## [br][b]槽用 [code]disabled_fill[/code]（BG-0）[/b]：调色板里没有「凹陷槽 / 轨道」专用
## token，BG-0 是语义最近的一支（最深、且名字就是「未填充」）；用 [code]panel[/code]
## 当槽会让进度条长在面板上时看不见边。[br]
## [br][b]填充用 [code]accent_success[/code]（松石青）[/b]：art-bible §4.1 把松石青钉在
## 「修为值 / 修炼进度」上，进度条正是它点名的典型出现场景。[br]
## [br]几何：引擎 [code]background/fill[/code] 内容边距均 4 边 2px（最小尺寸
## [code](4,4)[/code]），照抄；边框宽 0。
static func _progress_bar(p_th: Theme) -> void:
	var trough: Color = Style.tok(p_th, &"disabled_fill")
	var fill: Color = Style.tok(p_th, &"accent_success")
	p_th.set_stylebox(&"background", &"ProgressBar", Style.uniform(trough, trough, 0, 2, RADIUS))
	p_th.set_stylebox(&"fill", &"ProgressBar", Style.uniform(fill, fill, 0, 2, RADIUS))
	# 条上的百分比数字是「必须被即时读取」的数值——§4.7.2 归 T-0。
	p_th.set_color(&"font_color", &"ProgressBar", Style.tok(p_th, &"text_primary"))
	p_th.set_font_size(&"font_size", &"ProgressBar", 16)


# ═══════════════════════════════════════════════════════════════════════════════
# 二、滑杆 —— 音量（灰阶，理由见下）
# ═══════════════════════════════════════════════════════════════════════════════

## 轨道 + 已填充段 + 悬停段三档。[br]
## [br][b]为什么整条是灰阶而不是松石青[/b]：项目里的 HSlider 只有一处用途——设置面板的
## 三个音量条。音量不属于朱砂红 / 松石青 / 琉璃金任何一支的语义域，按 art-bible §4.1
## 的核心规则「不属于三色的语义域就必须回归墨白灰阶」，它只能是灰阶。[br]
## [br]几何：引擎三段的内容边距均 4px（最小尺寸 [code](8,8)[/code]），照抄；圆角 4px 已在
## §3.3.1 的范围内，保持。滑块图形（[code]grabber[/code]）是引擎内置 icon，主题没有
## icon 调色槽——见生成报告「仍未收敛的裸引擎外观」。
static func _sliders(p_th: Theme) -> void:
	var trough: Color = Style.tok(p_th, &"disabled_fill")
	var filled: Color = Style.tok(p_th, &"control")
	for type: StringName in [&"HSlider", &"VSlider"]:
		p_th.set_stylebox(&"slider", type, Style.uniform(trough, trough, 0, 4, 4))
		p_th.set_stylebox(&"grabber_area", type, Style.uniform(filled, filled, 0, 4, 4))
		p_th.set_stylebox(&"grabber_area_highlight", type,
				Style.uniform(filled.lightened(0.08), filled.lightened(0.08), 0, 4, 4))


# ═══════════════════════════════════════════════════════════════════════════════
# 三、滚动条 —— 横竖各一套
# ═══════════════════════════════════════════════════════════════════════════════

## 轨道 / 滑块 / 悬停滑块 / 按下滑块四档，灰度阶梯照 §4.7.3 的交互状态语言。[br]
## [br][b]「细杆」的实现方式[/b]：杆厚就是引擎默认的 8px（轨道内容边距 4px × 2），本就细。
## 改薄要动最小尺寸、会挪版面，故按「不增粗」处理——本轮把它从引擎的深灰半透明换成
## 调色板的 BG-0 / BG-3。[br]
## [br]几何：横条轨道内容边距 [code][0,4,0,4][/code]（最小尺寸 [code](0,8)[/code]）、
## 竖条 [code][4,0,4,0][/code]（[code](8,0)[/code]）、四段滑块均 4 边 4px（[code](8,8)[/code]）
## ——逐值照抄；圆角从引擎的 10px 收到 [constant RADIUS]（超 §3.3.1 上限）。[br]
## [br][code]scroll_focus[/code] 不设——同焦点政策，见文件头。
static func _scroll_bars(p_th: Theme) -> void:
	var trough: Color = Style.tok(p_th, &"disabled_fill")
	var border: Color = Style.tok(p_th, &"control_border")
	var grab: Color = Style.tok(p_th, &"control")
	var cr: Array = [RADIUS, RADIUS, RADIUS, RADIUS]
	p_th.set_stylebox(&"scroll", &"HScrollBar",
			Style.flat(trough, trough, [0, 0, 0, 0], [0, 4, 0, 4], cr))
	p_th.set_stylebox(&"scroll", &"VScrollBar",
			Style.flat(trough, trough, [0, 0, 0, 0], [4, 0, 4, 0], cr))
	for type: StringName in [&"HScrollBar", &"VScrollBar"]:
		p_th.set_stylebox(&"grabber", type, Style.uniform(grab, border, 0, 4, RADIUS))
		p_th.set_stylebox(&"grabber_highlight", type,
				Style.uniform(grab.lightened(0.08), border.lightened(0.15), 0, 4, RADIUS))
		p_th.set_stylebox(&"grabber_pressed", type,
				Style.uniform(grab.darkened(0.15), border.lightened(0.25), 0, 4, RADIUS))


# ═══════════════════════════════════════════════════════════════════════════════
# 四、文本输入 —— LineEdit / TextEdit
# ═══════════════════════════════════════════════════════════════════════════════

## 常态 = 面板底 + 1px 描边。焦点 = 描边换朱砂 token。[br]
## [br]几何：引擎三态的内容边距均 4px（最小尺寸 [code](8,8)[/code]），照抄。常态边框收成
## 全周 1px（引擎原本只有下边 2px 的一道线，与「1px 描边」的口径不符；边框宽不参与最小
## 尺寸，改边不挪布局）。[br]
## [br][code]read_only[/code] 的描边取 BG-4 的 50% 透明度（§4.7.3 禁用态口径）。[br]
## [br][b]焦点态用松石青（accent_success）[/b]：art-bible §4.1 把「交互高亮」列在朱砂红的严禁清单里，
## 且项目既有焦点环（shop_panel_layout.apply_focus_ring）就是松石青——同一主题里焦点只能有一种颜色。
static func _line_edit(p_th: Theme) -> void:
	var bg: Color = Style.tok(p_th, &"panel")
	var border: Color = Style.tok(p_th, &"panel_border")
	var focus: Color = Style.tok(p_th, &"accent_success")
	p_th.set_stylebox(&"normal", &"LineEdit", Style.uniform(bg, border, 1, 4, RADIUS))
	p_th.set_stylebox(&"focus", &"LineEdit", Style.uniform(bg, focus, 2, 4, RADIUS))
	p_th.set_stylebox(&"read_only", &"LineEdit",
			Style.uniform(Style.tok(p_th, &"disabled_fill"), Style.alpha(border, 0.5), 1, 4, RADIUS))
	_input_colors(p_th, &"LineEdit")
	p_th.set_color(&"font_uneditable_color", &"LineEdit", Style.tok(p_th, &"text_disabled"))
	p_th.set_color(&"clear_button_color", &"LineEdit", Style.tok(p_th, &"text_secondary"))
	p_th.set_color(&"clear_button_color_pressed", &"LineEdit", Style.tok(p_th, &"text_primary"))


## 多行输入：槽位与 LineEdit 同名同义，共用 [method _input_colors]。[br]
## [br]额外两处：只读文字走 T-3（§4.7.2「已完成的条件 / 不可读」）；当前行底色原本是引擎
## 的偏蓝 [code](0.25,0.25,0.26,0.8)[/code]，换成 BG-3 半透明。[br]
## [br][code]background_color[/code] 引擎默认就是全透明（底由样式盒给），显式写 0 让它有出处。[br]
## [br]几何：三态内容边距均 4px（最小尺寸 [code](8,8)[/code]），照抄；常态/只读边框同 LineEdit。
static func _text_edit(p_th: Theme) -> void:
	var bg: Color = Style.tok(p_th, &"panel")
	var border: Color = Style.tok(p_th, &"panel_border")
	var focus: Color = Style.tok(p_th, &"accent_success")
	p_th.set_stylebox(&"normal", &"TextEdit", Style.uniform(bg, border, 1, 4, RADIUS))
	p_th.set_stylebox(&"focus", &"TextEdit", Style.uniform(bg, focus, 2, 4, RADIUS))
	p_th.set_stylebox(&"read_only", &"TextEdit",
			Style.uniform(Style.tok(p_th, &"disabled_fill"), Style.alpha(border, 0.5), 1, 4, RADIUS))
	_input_colors(p_th, &"TextEdit")
	p_th.set_color(&"font_readonly_color", &"TextEdit", Style.tok(p_th, &"text_disabled"))
	p_th.set_color(&"background_color", &"TextEdit", Color(0, 0, 0, 0))
	p_th.set_color(&"current_line_color", &"TextEdit",
			Style.alpha(Style.tok(p_th, &"control"), 0.5))


## LineEdit / TextEdit 共有的文字色（两类型槽名相同，一次写两处）。[br]
## [br]口径：录入的文字是 T-0（必须即时读取）；占位提示是 T-3（§4.7.2 明写 T-3 用于
## 「空白状态的占位提示」）；选区底色取 BG-4——调色板没有「选中高亮」token，BG-4 是语义
## 最近的一支（界面色，落在面板底上看得见）；选区里的字回到 T-0（§4.7.3 选中态）。
static func _input_colors(p_th: Theme, p_type: StringName) -> void:
	p_th.set_color(&"font_color", p_type, Style.tok(p_th, &"text_primary"))
	p_th.set_color(&"font_selected_color", p_type, Style.tok(p_th, &"text_primary"))
	p_th.set_color(&"font_placeholder_color", p_type, Style.tok(p_th, &"text_disabled"))
	p_th.set_color(&"caret_color", p_type, Style.tok(p_th, &"text_primary"))
	p_th.set_color(&"selection_color", p_type, Style.tok(p_th, &"panel_border"))
	p_th.set_font_size(&"font_size", p_type, 16)


# ═══════════════════════════════════════════════════════════════════════════════
# 五、弹出层 —— PopupPanel / PopupMenu
# ═══════════════════════════════════════════════════════════════════════════════

## 面板底 / 悬停 / 分隔线三档。[br]
## [br][b]底用 [code]panel[/code]（BG-2）[/b]：art-bible §4.7.1 的「应用场景」列把 BG-2
## 点名给了「下拉菜单、工具提示框」这一层。[br]
## [br][b]分隔线[/b]：引擎用的是 [code]StyleBoxLine[/code]（不是 Flat），线宽 1px、左右
## 内容边距各 4px（最小尺寸 [code](8,0)[/code]）——逐值照抄，只换线色为 BG-4。[br]
## [br][b]勾选记号（[code]checked[/code]）上不了色[/b]：它是 icon 槽不是颜色槽，而 PopupMenu
## 没有像 OptionButton 那样的 icon 调色开关——记号随 [code]font_color[/code] 走，
## 所以换字色等于换记号色。
static func _popups(p_th: Theme) -> void:
	var bg: Color = Style.tok(p_th, &"panel")
	var border: Color = Style.tok(p_th, &"panel_border")
	p_th.set_stylebox(&"panel", &"PopupPanel", Style.uniform(bg, border, 0, 4, RADIUS))
	# PopupMenu 的 panel 引擎带 2px 边框——收成 1px，与面板描边口径一致（不挪布局）。
	p_th.set_stylebox(&"panel", &"PopupMenu", Style.uniform(bg, border, 1, 4, RADIUS))
	p_th.set_stylebox(&"hover", &"PopupMenu",
			Style.uniform(Style.tok(p_th, &"control"), border, 0, 4, RADIUS))
	var sep := StyleBoxLine.new()
	sep.color = border
	sep.thickness = 1
	sep.grow_begin = 1.0
	sep.grow_end = 1.0
	sep.content_margin_left = 4.0
	sep.content_margin_right = 4.0
	p_th.set_stylebox(&"separator", &"PopupMenu", sep)
	p_th.set_color(&"font_color", &"PopupMenu", Style.tok(p_th, &"text_secondary"))
	p_th.set_color(&"font_hover_color", &"PopupMenu", Style.tok(p_th, &"text_primary"))
	p_th.set_color(&"font_disabled_color", &"PopupMenu", Style.tok(p_th, &"text_disabled"))
	p_th.set_color(&"font_accelerator_color", &"PopupMenu", Style.tok(p_th, &"text_tertiary"))
	p_th.set_color(&"font_separator_color", &"PopupMenu", Style.tok(p_th, &"text_tertiary"))
	p_th.set_font_size(&"font_size", &"PopupMenu", 16)


## 工具提示：深底浅字，字号在引擎默认的 16 上减一档。[br]
## [br][b]为什么底不用 §4.7.1 点名给工具提示框的 BG-2[/b]：提示框是浮层，压的正是面板
## （同为 BG-2）——同色叠同色就读不出边界了。改用一档更浅的 BG-3，靠亮度差把浮层「抬」
## 到面板之上（不违反 §4.7.1：那一列讲的是层级归属，浮层本来就在面板之上）。[br]
## [br]几何：引擎内容边距 [code][8,2,8,2][/code]（最小尺寸 [code](16,4)[/code]）、无边框，
## 照抄。加描边会撑大竖直尺寸（边框宽参与最小尺寸），浮层靠底色差分离即可。[br]
## [br][code]TooltipLabel[/code] 没有样式盒槽，只有颜色与字号。
static func _tooltip(p_th: Theme) -> void:
	p_th.set_stylebox(&"panel", &"TooltipPanel",
			Style.flat(Style.tok(p_th, &"control"), Style.tok(p_th, &"panel_border"),
					[0, 0, 0, 0], [8, 2, 8, 2], [RADIUS, RADIUS, RADIUS, RADIUS]))
	p_th.set_color(&"font_color", &"TooltipLabel", Style.tok(p_th, &"text_primary"))
	p_th.set_font_size(&"font_size", &"TooltipLabel", 15)


# ═══════════════════════════════════════════════════════════════════════════════
# 六、窗口标题栏
# ═══════════════════════════════════════════════════════════════════════════════

## 标题字号 / 标题色 / 内外边框。[br]
## [br]几何：引擎 [code]embedded_border[/code] 的内容边距是 [code][10,28,10,8][/code]
## （最小尺寸 [code](20,36)[/code]），照抄——顶边 28px 就是标题栏的高度预算，
## [code]title_height[/code] constant（36）也不动，两者一起才撑住标题栏。[br]
## [br]标题字号沿用正文档 16（引擎默认也是 16，写出来只是让它有出处）。[br]
## [br]未聚焦边框：引擎给的是比聚焦[b]更亮[/b]的一支（0.4 对 0.25）；本项目按 §4.7.3 的
## 禁用语言反过来——未聚焦回到最深的 BG-0 + 半透明描边，读作「这块不活跃」。
static func _window(p_th: Theme) -> void:
	var border: Color = Style.tok(p_th, &"panel_border")
	var cm: Array = [10, 28, 10, 8]
	var cr: Array = [RADIUS, RADIUS, RADIUS, RADIUS]
	p_th.set_stylebox(&"embedded_border", &"Window",
			Style.flat(Style.tok(p_th, &"panel"), border, [1, 1, 1, 1], cm, cr))
	p_th.set_stylebox(&"embedded_unfocused_border", &"Window",
			Style.flat(Style.tok(p_th, &"disabled_fill"), Style.alpha(border, 0.5),
					[1, 1, 1, 1], cm, cr))
	p_th.set_color(&"title_color", &"Window", Style.tok(p_th, &"text_primary"))
	p_th.set_font_size(&"title_font_size", &"Window", 16)
