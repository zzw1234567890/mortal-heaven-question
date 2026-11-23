extends RefCounted
## NotificationToastRender —— Toast 的[b]渲染与版式[/b]（从
## [code]notification_toast_area.gd[/code] 拆出）。[br]
## [br][b]为什么单独一处[/b]：组件本身要管通知队列的接线、Timer 时间注入与节点对账，
## 而「Toast 长什么样、占多高、文字什么颜色」是另一件事——且版式那部分是**纯计算**
## （给定文本宽度与可用宽度，算行数），能在没有控件树的用例里逐条摆数字断言
## （同 [code]deck_view_rows.gd[/code] / [code]pause_menu_layout.gd[/code] 的拆因）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本件无实例状态，方法一律 static；
## 只按入参产生节点或数字，不读游戏状态。[br]
## [br][b]为什么颜色映射留在本件而不是内核[/b]：G3 裁决——内核只给 color 标识串
## （[code]green[/code]/[code]gold[/code]…），[code]String→Color[/code] 是视觉决定，
## 属渲染层。[br]
## [br][b]版式常量为什么必须是单一出处[/b]：holder 的占位高度（
## [method height_for_text]）与内层 Label 的字号 / 留白（[method build_panel]）
## 必须用同一组数字——两边各写一份就会出现「按 A 算高度、按 B 排版」，
## 表现是第二行画到隔壁 Toast 上。[br]
## [br]来源: design/gdd/hud-system.md §4、design/ux/hud.md 元素 12、
## design/art/art-bible.md §4.1、ADR-0031 §2、编码标准「单文件 ≤300 行」。

## 通知文本颜色映射（类型映射 color 标识 → 美术圣经 §4.1 主色调色板 +
## design/ux/hud.md 元素 12 视觉规范）：[br]
## green=松石青 #4A9494（获得/正向——修为运转语义复用）、gold=琉璃金 #C8A84E（稀有/
## 灵石）、purple=烟灰紫 #6E6878（修为变更——烟灰阶紫）、red=朱砂红 #C23B3B
## （战斗事件攻/错误——生命语义）、blue=松石青 #4A9494（战斗事件守——松石青复用，
## 界定交互模式库「朱砂红/松石青」双编码）、white=淡墨 #6B675E（系统提示——中性）。
const TEXT_COLORS: Dictionary = {
	"green": Color("#4A9494"),
	"gold": Color("#C8A84E"),
	"purple": Color("#6E6878"),
	"red": Color("#C23B3B"),
	"blue": Color("#4A9494"),
	"white": Color("#6B675E"),
}

## 未知 color 标识的兜底键（内核已判过安全默认，这里再兜一层防手改数据）。
const DEFAULT_COLOR_KEY: String = "white"

## Toast 最小宽度（通知区的设计宽——短提示不缩成一条）。
const TOAST_MIN_WIDTH: float = 360.0
## 单行 Toast 高度（与容器 offset 高度同源）。
const TOAST_LINE_HEIGHT: float = 32.0
## 通知文本字号。
const TOAST_FONT_SIZE: int = 13
## 文本左右留白（Toast 内的内边距——文字不贴面板边）。
const TOAST_PAD_H: float = 12.0
## 文本可用宽 = 最小宽度减两侧留白——超长文案在这里折行，不裁字。
const TOAST_TEXT_WIDTH: float = TOAST_MIN_WIDTH - TOAST_PAD_H * 2.0


## 按文本像素宽算折成几行。[br]
## [br][b]按字符量宽[/b]：中文在 [code]AUTOWRAP_WORD_SMART[/code] 下可逐字折行，
## 「整串宽 ÷ 可用宽」向上取整即行数（英文单词折行的误差落在一行以内，只多不少——
## 多给的高度是空白，少给才是裁字）。[br]
## [br][param p_text_width] 文本在目标字号下的像素宽（[method Font.get_string_size] 的 x）。[br]
## [param p_available_width] 可用宽（本组件传 [constant TOAST_TEXT_WIDTH]）。[br]
## [br][b]返回[/b]：行数（至少 1——空串或零宽也占一行高）。
static func line_count_for_width(p_text_width: float, p_available_width: float) -> int:
	if p_available_width <= 0.0:
		return 1
	return maxi(1, int(ceil(p_text_width / p_available_width)))


## 行数 → 占位高度。[br]
## [br][b]返回[/b]：高度（至少一行——0 行在布局上等于「不可见」，不是我们要的）。
static func height_for_lines(p_lines: int) -> float:
	return TOAST_LINE_HEIGHT * float(maxi(1, p_lines))


## 文本 → 占位高度（先量宽、再算行数、再乘单行高）。[br]
## [br][param p_font] 量宽用的字体（组件传 StackContainer 的主题字体；
## null 时按单行算——没有字体就没有折行信息，少给不如给一行）。[br]
static func height_for_text(p_text: String, p_font: Font) -> float:
	if p_font == null:
		return height_for_lines(1)
	var width: float = p_font.get_string_size(p_text, HORIZONTAL_ALIGNMENT_LEFT,
			-1, TOAST_FONT_SIZE).x
	return height_for_lines(line_count_for_width(width, TOAST_TEXT_WIDTH))


## color 标识 → 颜色（未知标识落 [constant DEFAULT_COLOR_KEY]）。
static func color_for(p_color_key: String) -> Color:
	return TEXT_COLORS.get(p_color_key, TEXT_COLORS[DEFAULT_COLOR_KEY])


## 构建内层 Toast 面板（文本 + 颜色映射 + 点击关闭绑定）。[br]
## Panel 与 Label 均 FULL_RECT 锚——跟随 holder 尺寸（holder 为普通 Control，
## 无容器布局覆写内层 position）。[br]
## [br][param p_entry] 内核条目（读 [code]text[/code] / [code]color[/code] / [code]id[/code]）。[br]
## [param p_on_gui_input] 点击回调，签名 [code](event: InputEvent, id: int)[/code]。[br]
## [br][b]返回[/b]：可加进 holder 的 Panel（名字 "SlidePanel"——动画与滑出都按此名找）。
static func build_panel(p_entry: Dictionary, p_on_gui_input: Callable) -> Panel:
	var panel: Panel = Panel.new()
	panel.name = "SlidePanel"
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var label: Label = Label.new()
	label.name = "Text"
	label.text = str(p_entry[&"text"])
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# 超长文案折行而不是被裁：holder 高度已按 [method height_for_text] 给足行数，
	# 折行后的第二行落在面板内，不会画到隔壁 Toast 上。
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.offset_left = TOAST_PAD_H
	label.offset_right = -TOAST_PAD_H
	if label.label_settings == null:
		label.label_settings = LabelSettings.new()
		label.label_settings.font_size = TOAST_FONT_SIZE
	label.label_settings.font_color = color_for(str(p_entry[&"color"]))
	panel.add_child(label)
	panel.gui_input.connect(p_on_gui_input.bind(int(p_entry[&"id"])))
	return panel
