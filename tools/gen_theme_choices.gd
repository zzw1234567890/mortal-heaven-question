extends RefCounted
## 主题生成器·控件族分册之二：选择控件（下拉框 / 勾选框 / 开关 / 页签容器）。[br]
## [br][b]为什么与 [code]gen_theme_widgets.gd[/code] 分册[/b]：两册合起来会双双越过 300 行
## 软上限（.claude/docs/coding-standards.md）。分界按「读数与浮层」对「选择与页签」，
## 两册共用 [code]Style[/code] 的样式盒工厂与取色，颜色来源仍唯一在主册。[br]
## [br][b]状态阶梯跟主册 Button 走[/b]（悬停 [code]lightened(0.08)[/code] /
## 按下 [code]darkened(0.15)[/code]），理由见 [method _option_button]。几何逐值照抄引擎
## 默认，圆角收进 §3.3.1 的 2px。[br]
## [br][b]焦点槽不设[/b]：[code]OptionButton/focus[/code] 与 [code]TabContainer/tab_focus[/code]
## 都留给 [code]shop_panel_layout.apply_focus_ring[/code]——同主册政策。

const Style: GDScript = preload("res://tools/gen_theme_style.gd")

## 全微圆角（art-bible §3.3.1 的下限）。
const RADIUS: int = 2


## 把本册所有选择控件挂到 [param p_th] 上（由主册在保存前调用）。
static func apply(p_th: Theme) -> void:
	_option_button(p_th)
	_check_controls(p_th)
	_tab_container(p_th)


# ═══════════════════════════════════════════════════════════════════════════════
# 一、下拉框
# ═══════════════════════════════════════════════════════════════════════════════

## 四态与主册 Button 同族（同一套灰阶状态语言）。[br]
## [br][b]悬停用 [code]lightened(0.08)[/code] 而不是 §4.7.3 写的「加深 8%」[/b]：主册 Button
## 的悬停就是这么写的——同一个主题里不能有两种悬停方向，否则玩家鼠标扫过设置面板时会看到
## 按钮变亮、下拉框变暗。既有偏差留在原地（那是有断言护着的既有实现），新控件跟它走，
## 差异记在生成报告。[br]
## [br]几何：引擎四态内容边距 [code][8,4,8,4][/code]（最小尺寸 [code](16,8)[/code]），照抄。
## 题面允许「略矮」，但压低高度就是挪布局（引擎默认最小高 20px 里含文字行高），故按
## 「不压」处理，记在报告。[br]
## [br][code]modulate_arrow = 1[/code]：把下拉箭头交给 [code]font_color[/code] 调色——
## 这是 OptionButton 唯一能让引擎贴图落到调色板上的开关（默认 0 = 用贴图原色，即冷白）。
static func _option_button(p_th: Theme) -> void:
	var base: Color = Style.tok(p_th, &"control")
	var border: Color = Style.tok(p_th, &"control_border")
	var cm: Array = [8, 4, 8, 4]
	var cr: Array = [RADIUS, RADIUS, RADIUS, RADIUS]
	p_th.set_stylebox(&"normal", &"OptionButton",
			Style.flat(base, border, [1, 1, 1, 1], cm, cr))
	p_th.set_stylebox(&"hover", &"OptionButton",
			Style.flat(base.lightened(0.08), border.lightened(0.15), [2, 2, 2, 2], cm, cr))
	p_th.set_stylebox(&"pressed", &"OptionButton",
			Style.flat(base.darkened(0.15), border.lightened(0.25), [2, 2, 2, 2], cm, cr))
	p_th.set_stylebox(&"disabled", &"OptionButton",
			Style.flat(Style.tok(p_th, &"disabled_fill"), Style.alpha(border, 0.5),
					[1, 1, 1, 1], cm, cr))
	p_th.set_color(&"font_color", &"OptionButton", Style.tok(p_th, &"text_secondary"))
	for state: StringName in [&"font_hover_color", &"font_pressed_color",
			&"font_hover_pressed_color", &"font_focus_color"]:
		p_th.set_color(state, &"OptionButton", Style.tok(p_th, &"text_primary"))
	p_th.set_color(&"font_disabled_color", &"OptionButton", Style.tok(p_th, &"text_disabled"))
	p_th.set_font_size(&"font_size", &"OptionButton", 16)
	p_th.set_constant(&"modulate_arrow", &"OptionButton", 1)


# ═══════════════════════════════════════════════════════════════════════════════
# 二、勾选框与开关
# ═══════════════════════════════════════════════════════════════════════════════

## 两族五态。[br]
## [br][b]为什么常态与禁用是透明盒、只有悬停与按下上底色[/b]：引擎给这两族的就是
## [code]StyleBoxEmpty[/code]（图形由 icon 画）。设置面板里的一行勾选框不是一个「面」，
## 常态给它铺 BG-3 会凭空多出一块板；而悬停/按下铺 BG-3 正是 §4.7.1 对 BG-3 的定义
## （「暗示这里可以被触碰」）。故常态 / 禁用留空，其余上色。[br]
## [br]几何：空盒也带内容边距——CheckBox [code][4,4,4,4][/code]（最小尺寸 [code](8,8)[/code]）、
## CheckButton [code][6,4,6,4][/code]（[code](12,8)[/code]），逐值照抄；上色的那三态用同一组
## 边距、边框宽 0，最小尺寸逐值不变。[br]
## [br]图形配色（[code]checkbox_*_color[/code] / [code]button_*_color[/code]）：勾上取 T-0、
## 未勾取 BG-4。这是这两族唯一能把引擎贴图拉回调色板的槽（同 OptionButton 的箭头）。
static func _check_controls(p_th: Theme) -> void:
	var base: Color = Style.tok(p_th, &"control")
	var specs: Array = [
		[&"CheckBox", [4, 4, 4, 4], &"checkbox"],
		[&"CheckButton", [6, 4, 6, 4], &"button"],
	]
	var cr: Array = [RADIUS, RADIUS, RADIUS, RADIUS]
	for spec: Array in specs:
		var type: StringName = spec[0]
		var cm: Array = spec[1]
		var prefix: StringName = spec[2]
		p_th.set_stylebox(&"normal", type, Style.empty(cm))
		p_th.set_stylebox(&"disabled", type, Style.empty(cm))
		p_th.set_stylebox(&"hover", type, Style.flat(base, base, [0, 0, 0, 0], cm, cr))
		var down: Color = base.darkened(0.15)
		p_th.set_stylebox(&"pressed", type, Style.flat(down, down, [0, 0, 0, 0], cm, cr))
		p_th.set_stylebox(&"hover_pressed", type, Style.flat(down, down, [0, 0, 0, 0], cm, cr))
		p_th.set_color(prefix + "_checked_color", type, Style.tok(p_th, &"text_primary"))
		p_th.set_color(prefix + "_unchecked_color", type, Style.tok(p_th, &"panel_border"))
		p_th.set_color(&"font_color", type, Style.tok(p_th, &"text_secondary"))
		for state: StringName in [&"font_hover_color", &"font_pressed_color",
				&"font_hover_pressed_color", &"font_focus_color"]:
			p_th.set_color(state, type, Style.tok(p_th, &"text_primary"))
		p_th.set_color(&"font_disabled_color", type, Style.tok(p_th, &"text_disabled"))
		p_th.set_font_size(&"font_size", type, 16)


# ═══════════════════════════════════════════════════════════════════════════════
# 三、页签容器
# ═══════════════════════════════════════════════════════════════════════════════

## 项目里用到 TabContainer 的只有一处（设置面板的四分类）。[br]
## [br][b]为什么只写 TabContainer 的槽、不写 TabBar 的[/b]：TabContainer 内部的页签条是
## 一个自建的 TabBar 子节点，实测它解析的是 [b]TabContainer[/b] 类型上的槽（探针：给两个
## 类型各写一个不同色的 [code]tab_selected[/code]，在树内读内部 TabBar 拿到的是 TabContainer
## 那一支）。给 TabBar 写槽在这个用法下不会生效，写进去只是噪音。[br]
## [br]几何：三态内容边距均 [code][10,4,10,4][/code]（最小尺寸 [code](20,8)[/code]）、
## 选中态下边框 2px（与下方面板接缝）、未选中/悬停/禁用左右各 1px——逐值照抄；圆角只给上两角
## （下缘与面板相接，圆角会在接缝处露缝）。[br]
## [br][code]panel[/code] 槽：内容边距 0（最小尺寸 [code](0,0)[/code]），底色换成 BG-2。[br]
## [br][code]tab_focus[/code] 不设——同焦点政策，见文件头。
static func _tab_container(p_th: Theme) -> void:
	var bg: Color = Style.tok(p_th, &"panel")
	var border: Color = Style.tok(p_th, &"panel_border")
	var trough: Color = Style.tok(p_th, &"disabled_fill")
	var cm: Array = [10, 4, 10, 4]
	var cr: Array = [RADIUS, RADIUS, 0, 0]
	p_th.set_stylebox(&"panel", &"TabContainer", Style.uniform(bg, border, 0, 0, RADIUS))
	# 选中态：底色与内容面板同色 + 接缝处 2px 边框同色——读作「这一页与面板是同一块纸」。
	p_th.set_stylebox(&"tab_selected", &"TabContainer",
			Style.flat(bg, bg, [0, 0, 0, 2], cm, cr))
	p_th.set_stylebox(&"tab_unselected", &"TabContainer",
			Style.flat(trough, border, [1, 0, 1, 0], cm, cr))
	# 悬停：与主册 Button 同一支 +8% 语言（BG-0 是页签的「常态」，故从它往上提）。
	p_th.set_stylebox(&"tab_hovered", &"TabContainer",
			Style.flat(trough.lightened(0.08), border, [1, 0, 1, 0], cm, cr))
	p_th.set_stylebox(&"tab_disabled", &"TabContainer",
			Style.flat(trough, Style.alpha(border, 0.5), [1, 0, 1, 0], cm, cr))
	p_th.set_color(&"font_selected_color", &"TabContainer", Style.tok(p_th, &"text_primary"))
	p_th.set_color(&"font_hovered_color", &"TabContainer", Style.tok(p_th, &"text_primary"))
	p_th.set_color(&"font_unselected_color", &"TabContainer", Style.tok(p_th, &"text_secondary"))
	p_th.set_color(&"font_disabled_color", &"TabContainer", Style.tok(p_th, &"text_disabled"))
	p_th.set_font_size(&"font_size", &"TabContainer", 16)
