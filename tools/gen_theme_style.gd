extends RefCounted
## 主题生成器的样式盒工厂 + 调色板取色——[code]tools/gen_theme.gd[/code] 及两册分册共用。[br]
## [br][b]为什么单独一个文件[/b]：控件族按行数预算拆成两册（.claude/docs/coding-standards.md
## 的 300 行软上限），两册都要这两个工厂；helper 复制两份就是两份会各自漂的实现。[br]
## [br][b]拆册不构成颜色来源的分散[/b]：本文件[code]不写任何 hex[/code]，
## [method tok] 只从主册写好的 [code]GamePalette[/code] 里取。改配色的落点仍然唯一
## （主册的常量区）。


## 取主册写好的调色板 token（不是硬编码色值）。
static func tok(p_th: Theme, p_name: StringName) -> Color:
	return p_th.get_color(p_name, &"GamePalette")


## 只改透明度，不改色相——用于 §4.7.3 的「禁用态 = BG-4 的 50% 透明度」这类口径。
static func alpha(p_color: Color, p_alpha: float) -> Color:
	return Color(p_color.r, p_color.g, p_color.b, p_alpha)


## 四边同值的样式盒（绝大多数槽位都是这个形状）。
static func uniform(p_bg: Color, p_border: Color, p_border_w: int, p_margin: int,
		p_radius: int) -> StyleBoxFlat:
	return flat(p_bg, p_border, [p_border_w, p_border_w, p_border_w, p_border_w],
			[p_margin, p_margin, p_margin, p_margin],
			[p_radius, p_radius, p_radius, p_radius])


## 逐边样式盒：边框宽与内容边距按 [code][左,上,右,下][/code]，圆角按
## [code][左上,右上,右下,左下][/code]。[br]
## [br][b]内容边距必须显式写[/b]（含 0）——[code]StyleBoxFlat[/code] 的缺省值是 -1，
## 含义是「跟随边框」，会让最小尺寸随边框宽漂（主册 [method _panel_box] 有同一段说明）。
## 各册几何靠这一条守住「只换颜色、不挪布局」。
static func flat(p_bg: Color, p_border: Color, p_bw: Array, p_cm: Array,
		p_cr: Array) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = p_bg
	sb.border_color = p_border
	sb.border_width_left = int(p_bw[0])
	sb.border_width_top = int(p_bw[1])
	sb.border_width_right = int(p_bw[2])
	sb.border_width_bottom = int(p_bw[3])
	sb.content_margin_left = float(p_cm[0])
	sb.content_margin_top = float(p_cm[1])
	sb.content_margin_right = float(p_cm[2])
	sb.content_margin_bottom = float(p_cm[3])
	sb.corner_radius_top_left = int(p_cr[0])
	sb.corner_radius_top_right = int(p_cr[1])
	sb.corner_radius_bottom_right = int(p_cr[2])
	sb.corner_radius_bottom_left = int(p_cr[3])
	return sb


## 透明盒（引擎给 CheckBox / CheckButton 常态用的就是它）。[br]
## [br]内容边距由参数给——空盒也参与最小尺寸计算（[code](8,8)[/code] 与
## [code](12,8)[/code] 的差别全在这四个数上）。
static func empty(p_cm: Array) -> StyleBoxEmpty:
	var sb := StyleBoxEmpty.new()
	sb.content_margin_left = float(p_cm[0])
	sb.content_margin_top = float(p_cm[1])
	sb.content_margin_right = float(p_cm[2])
	sb.content_margin_bottom = float(p_cm[3])
	return sb
