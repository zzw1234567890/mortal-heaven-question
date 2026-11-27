extends RefCounted
## NodeGraphTooltipPainter —— 悬停 tooltip 的[b]一笔[/b]（内容组装 + 盒子绘制），纯绘制。[br]
##
## [b]为什么从 [code]node_graph_node_painter.gd[/code] 拆出来[/b]：那份已 318 行，
## 越过 300 行软上限（coding-standards）；而「悬停时弹出的小盒子」与「节点本身长什么样」
## 是两件事——前者只在鼠标停住时画一次，读的是 tooltip 文案纯函数，后者每帧画满整图，
## 读的是六态样式。拆完两边都回到上限内。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不持状态——宿主（渲染器）经 [param p_host]
## 传入，只读它的渲染输入快照（nodes/states）。[br]
##
## [br]来源: ADR-0031 §5、design/gdd/exploration-ui-system.md §2（AC-10 悬停提示）、
## exploration-ui Story 003。

## 视觉规格（尺寸/配色常量唯一来源）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")
## 六态样式查询（判定纯函数——绘制侧只消费）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")


## 悬停 tooltip（AC-10）——名称 + 描述 + 敌人详情；迷雾显示「?」。[br]
## [br][b]内容源[/b]：[NodeStateLogic.tooltip_text] 纯函数（迷雾判定以六态 FOGGED
## 为准——与渲染器的迷雾集合同源，不会出现「节点画成亮的、tooltip 说不知道」）。[br]
## [br][b]空文案不画[/b]：没有可说的内容时连盒子都不建（免得悬停出一个空格子）。
static func draw_hover_tooltip(p_host: Control, p_node_id: int) -> void:
	var detail: Dictionary = p_host.nodes.get(p_node_id, {})
	var fogged: bool = false
	if p_host.states.has(p_node_id):
		fogged = int(p_host.states[p_node_id]) == NodeStateLogicScript.NodeState.FOGGED
	else:
		fogged = p_host.call(&"_is_fogged", p_node_id)
	var text: String = NodeStateLogicScript.tooltip_text(detail, fogged)
	if text.is_empty():
		return
	var pos: Vector2 = p_host.call(&"get_node_position", p_node_id)
	# tooltip 盒子锚定在节点上方（画布局部坐标——随 renderer.scale 缩放）
	var anchor := Vector2(pos.x - Style.NODE_SIZE * 0.5,
			pos.y - Style.NODE_SIZE * 0.5 - Style.TOOLTIP_ANCHOR_OFFSET)
	var box: Rect2 = tooltip_rect(text, anchor)
	p_host.draw_rect(box, Style.TOOLTIP_BG_COLOR)
	p_host.draw_rect(box, Style.TOOLTIP_BORDER_COLOR, false, 1.0)
	p_host.draw_string(label_font(p_host),
			box.position + Vector2(Style.TOOLTIP_PADDING, Style.TOOLTIP_BASELINE),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.LABEL_FONT_SIZE)


## tooltip 盒子尺寸估算——按文本字符数 × 字体宽度近似（stub；真实测量归
## 字体资产管线）。[br][b]返回[/b]: 以 [param anchor] 为左上角的矩形。
static func tooltip_rect(text: String, anchor: Vector2) -> Rect2:
	var width: float = maxf(Style.TOOLTIP_MIN_WIDTH,
			float(text.length()) * Style.TOOLTIP_CHAR_WIDTH
			+ Style.TOOLTIP_PADDING * 2.0)
	return Rect2(anchor, Vector2(width, Style.TOOLTIP_HEIGHT))


## 文字字体——主题默认（真实字体归美术资产管线）。[br]
## [br][b]为什么不与 [NodeGraphLandmark.label_font] 合并[/b]：两处都是「主题字体取不到
## 就用引擎兜底」的三行，合并要为一个三行函数建一条跨模块依赖（地标 → 本模块），
## 而两者的取用场景（常显标签 / 悬停提示）本就分属两层。
static func label_font(p_host: Control) -> Font:
	var theme_font: Font = p_host.get_theme_default_font()
	return theme_font if theme_font != null else ThemeDB.fallback_font
