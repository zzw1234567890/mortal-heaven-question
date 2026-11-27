extends RefCounted
## NodeGraphLandmark —— 单个节点画成「地标」的那几层（地盘 + 两行文字），纯绘制。[br]
##
## [b]为什么单独成文件[/b]：[code]node_graph_node_painter.gd[/code] 已贴 300 行
## 软上限（coding-standards），而「节点长什么样」里最占篇幅的两块就是「立在地图上的
## 底盘」与「地名 + 类型两行文字」——它们与六态判定、图集取用、斜线标记都不相交。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不持状态，宿主（渲染器）经 [param p_host]
## 传入，只读它的渲染输入快照。[br]
##
## [br][b]本轮的地图化改动[/b]（反馈原话「做成地图的，每个节点要有地名」）：[br]
##   - 底盘：节点外一圈石台 + 下半圈投影——「立在地图上」而不是「浮在背景上」；[br]
##   - 文字：[b]地名为大、类型为小[/b]两行。地名回答「我去哪儿」，类型回答
##     「那儿是什么」——两个不同的问题，此前只有后者。[br]
##
## 来源: 本轮任务书任务三（节点改地标造型 + 地名）+ 任务二（地名系统）、
## ADR-0031 §5、design/gdd/exploration-ui-system.md §2 界面规则表。

## 视觉规格（尺寸/配色常量唯一来源）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")
## 图集（类型短标签取用——[method NodeIconAtlas.get_label]）。
const NodeIconAtlasScript := preload("res://src/ui/exploration/node_icon_atlas.gd")


## 地标底盘——投影 + 八边形石台 + 细亮边，画在图标[b]之下[/b]。[br]
## [br][b]三层顺序[/b]（由下到上）：投影 → 石台 → 石台亮边。[br]
## [br][b]为什么投影只画下半圈[/b]：全圈投影读起来是「一圈描边」，只有压在[b]下方[/b]
## 才读成光从上面打下来的落影——这是「地标立在地上」的观感来源。[br]
## [br][b]为什么用八边形而不是矩形或菱形[/b]：矩形就是原来的色块（没改），菱形
## （[constant Style.LANDMARK_CORNER_CUT] = 0.5）可用面积掉一半、图标被挤小；
## 切四角是两者之间的形状，远看是一块石碑。[br]
## [br][param p_host] 绘制宿主。[br][param p_rect] 图标矩形（已含悬停放大）。[br]
## [param p_pos] 节点中心坐标。[br]
static func draw_plate(p_host: Control, p_rect: Rect2, p_pos: Vector2) -> void:
	var half: float = p_rect.size.x * 0.5
	# 投影——下半圈的一块扇形（以节点中心为心、半径略大于石台）
	p_host.draw_colored_polygon(half_disc(p_pos, half * Style.LANDMARK_SHADOW_SCALE),
			Style.LANDMARK_SHADOW_COLOR)
	# 石台——八边形（切四角）
	var plate_half: float = half * Style.LANDMARK_PLATE_SCALE
	var plate: PackedVector2Array = octagon(p_pos, plate_half,
			Style.LANDMARK_CORNER_CUT)
	p_host.draw_colored_polygon(plate, Style.LANDMARK_PLATE_COLOR)
	# 石台亮边——同一条八边形收一圈细线（画成封闭折线，draw_polyline 不闭合）
	p_host.draw_polyline(closed_loop(plate), Style.LANDMARK_PLATE_EDGE_COLOR,
			Style.LANDMARK_PLATE_EDGE_WIDTH)


## 半圆扇形多边形（正下方那一半；投影用——见 [method draw_plate]）。[br]
## [br][b]为什么不用 [method CanvasItem.draw_arc][/b]：arc 画的是[b]线[/b]（有宽度
## 的弧），要的是一块[b]面[/b]（半圆填充）。[br]
## [br][b]返回[/b]：顶点表（圆心 → 半圆采样点 → 闭合）。
static func half_disc(p_center: Vector2, p_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array([p_center])
	var steps: int = 16
	for i: int in range(steps + 1):
		var angle: float = PI * float(i) / float(steps)
		points.append(p_center + Vector2(cos(angle), sin(angle)) * p_radius)
	return points


## 两行文字——[b]地名[/b]（大）在图标正下方，[b]类型短标签[/b]（小）紧随其下。[br]
## [br][b]顺序不能反[/b]：地名是玩家找路用的信息，读的频率远高于类型；小字在下、
## 大字在上，视线从节点往下的第一落点就是地名。[br]
## [br][b]两行都带描边[/b]：底色是地图插画 + 压暗 + 暗角，同一行文字两端可能落在
## 亮度差一倍的底上（见 [constant Style.LABEL_OUTLINE_COLOR] 的注记）。[br]
## [br][b]类型行不显示的原因只有一个[/b]：不传 [param p_show_type]（迷雾节点——
## 类型不暴露，GDD 界面规则）。地名[b]照常显示[/b]：玩家要先看到「去哪儿」，
## 未访问的格子正是最需要知道去哪儿的地方。[br]
## [br][b]地名由调用方给[/b]（[code]NodeGraphRenderer.place_name_of[/code]）——
## 覆盖表与地名池的择优只写在那一个入口，绘制侧不重复判定。[br]
## [br][param p_host] 绘制宿主。[br][param p_place] 地名（已定）。[br]
## [param p_detail] 节点详情（取类型短标签）。[br][param p_pos] 节点中心。[br]
## [param p_node_size] 图标边长（已含悬停放大）。[br]
## [param p_show_type] 是否画第二行类型短标签。[br]
## [param p_type_id] 节点类型 ID。[br]
static func draw_labels(p_host: Control, p_place: String, p_detail: Dictionary,
		p_pos: Vector2, p_node_size: float, p_show_type: bool,
		p_type_id: int) -> void:
	var box_width: float = p_node_size * Style.LABEL_BOX_RATIO
	var font: Font = label_font(p_host)
	var anchor := Vector2(p_pos.x - box_width * 0.5,
			p_pos.y + p_node_size * 0.5 + Style.LABEL_BASELINE_OFFSET)
	_draw_line_of_text(p_host, font, p_place, anchor, box_width,
			Style.LABEL_FONT_SIZE, Style.LABEL_COLOR)
	if not p_show_type:
		return
	var type_label: String = str(p_detail.get("label",
			NodeIconAtlasScript.get_label(p_type_id)))
	_draw_line_of_text(p_host, font, type_label,
			anchor + Vector2(0.0, Style.TYPE_LABEL_EXTRA_OFFSET), box_width,
			Style.TYPE_LABEL_FONT_SIZE, Style.TYPE_LABEL_COLOR)


## 单行居中文字（先描边后填色——描边必须整行画完再画填充，否则后一字会盖住前一字
## 的描边）。[br]
## [br][b]为什么抽出来[/b]：两行的字号/颜色不同但排版完全一样，写两遍就有一遍会漂。
static func _draw_line_of_text(p_host: Control, p_font: Font, p_text: String,
		p_anchor: Vector2, p_box_width: float, p_font_size: int, p_color: Color) -> void:
	p_host.draw_string_outline(p_font, p_anchor, p_text, HORIZONTAL_ALIGNMENT_CENTER,
			p_box_width, p_font_size, Style.LABEL_OUTLINE_SIZE,
			Style.LABEL_OUTLINE_COLOR)
	p_host.draw_string(p_font, p_anchor, p_text, HORIZONTAL_ALIGNMENT_CENTER,
			p_box_width, p_font_size, p_color)


## 八边形顶点——以 [param p_center] 为心、[param p_half] 为半宽，四角各切去
## [param p_corner_cut] × 半宽。[br]
## [br][param p_corner_cut] = 0 退化为正方形，0.5 退化为菱形——两端都是合法形状，
## 中间那段才是「地标石碑」。[br]
## [br][b]返回[/b]：8 个顶点（顺时针）。
static func octagon(p_center: Vector2, p_half: float, p_corner_cut: float) -> PackedVector2Array:
	var cut: float = p_half * clampf(p_corner_cut, 0.0, 0.5)
	var x0: float = p_center.x - p_half
	var x1: float = p_center.x + p_half
	var y0: float = p_center.y - p_half
	var y1: float = p_center.y + p_half
	return PackedVector2Array([
		Vector2(x0 + cut, y0), Vector2(x1 - cut, y0),
		Vector2(x1, y0 + cut), Vector2(x1, y1 - cut),
		Vector2(x1 - cut, y1), Vector2(x0 + cut, y1),
		Vector2(x0, y1 - cut), Vector2(x0, y0 + cut),
	])


## 把顶点表变成闭合折线（首点补到末尾——[method CanvasItem.draw_polyline] 不闭合）。
static func closed_loop(p_points: PackedVector2Array) -> PackedVector2Array:
	var loop: PackedVector2Array = p_points.duplicate()
	if not loop.is_empty():
		loop.append(loop[0])
	return loop


## 文字字体——主题默认（真实字体归美术资产管线）。
static func label_font(p_host: Control) -> Font:
	var theme_font: Font = p_host.get_theme_default_font()
	return theme_font if theme_font != null else ThemeDB.fallback_font
