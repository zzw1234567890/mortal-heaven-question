extends RefCounted
## NodeGraphRegionPainter —— 把每个节点画成[b]一整片地区[/b]：底渍 → 墨边 → 地名纸条。[br]
##
## [b]为什么需要它[/b]（老板原话「我想要一个节点一块地区，鼠标移上去都能高亮有交互的
## 那种」「现在这个看起来还是太简陋了」）：节点此前只有那一枚 56px 的圆印可交互，地图
## 上其他地方是「背景」。本轮把每个节点的势力范围画成一整片地——鼠标移到那片地里的
## 任何一处，整片地亮起来。[br]
##
## [br][b]★ 三层，顺序即语义（由下到上）★[/b]：[br]
##   1. [b]底渍[/b]：极淡的墨色面，把「这一片归谁」铺出来——浓度按节点 ID 奇偶微差，
##      相邻两块能看出分界但不花（本文件）；[br]
##   2. [b]墨边[/b]：2.5px 细墨线，按顶点做[b]确定性抖动[/b]（Voronoi 的边是直线段，
##      围起来是几何网格；舆图上的疆界是手描的）——不可达态改画虚线
##      （[code]node_graph_region_edge_painter.gd[/code]）；[br]
##   3. [b]地名纸条[/b]：半透明宣纸 + 1px 墨边，深字压浅底（与节点下方的浅字压深底
##      相反——宣纸的读法）。纸条画在图标[b]下方[/b]，不与圆印重叠
##      （[code]node_graph_region_paper.gd[/code]）。[br]
##
## [br][b]★ 六态只动三根轴 ★[/b]（映射表见 [NodeGraphStyleRegion.region_visual]）：
## 底渍浓淡 / 边的虚实粗细 / 有没有朱红印记。[b]不改[/b]
## [code]node_state_logic.gd[/code] 的六态样式表——那张表被既有断言逐键钉死
## （[code]test_node_state_logic.gd[/code] / [code]test_node_graph_legibility.gd[/code]）。[br]
##
## [br][b]为什么地区用面、节点用点两组视觉[/b]：两者回答两个问题——地区答「这一片山域
## 跟我什么关系」（一眼扫过就知道该往哪走），节点答「这一格是什么」（凑近看）。面只能
## 承载三条轴，点能承载六条；把同一份六态折进三条轴必须有取舍，取舍理由见映射表注记。[br]
##
## [br][b]★ 三笔为什么拆成三个文件 ★[/b]：单文件 300 行软上限（coding-standards）。
## 拆的判据是[b]笔[/b]——每一笔有自己的几何手法（面的三角化 / 边的抖动与虚线相位 /
## 纸条的文本测量），三者之间只共享「哪块地可见、这块地什么态」这一个查询，那份共享
## 查询收在 [NodeGraphRegionCommon]。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：宿主（渲染器）经 [param p_host] 传入，
## 只[b]读[/b]它的渲染输入快照（cells / states / nodes / positions）并把画笔落在它身上。[br]
##
## [br]来源: 本轮任务书任务二（地区怎么画）、老板 2026-11-27 反馈、
## ADR-0031 §2/§5、design/gdd/exploration-ui-system.md §2 界面规则表。

## 地区视觉规格（本层专属常量 + 六态→面视觉映射表）。
const RegionStyle := preload("res://src/ui/exploration/node_graph_style_region.gd")
## 地区层共享读写口（分块表 / 可见集合 / 六态视觉 / 高亮判定）。
const RegionCommon := preload("res://src/ui/exploration/node_graph_region_common.gd")
## 第二笔：墨边（确定性抖动、虚线环、外扩）。
const EdgePainter := preload("res://src/ui/exploration/node_graph_region_edge_painter.gd")
## 第三笔：地名纸条（宣纸 + 墨边 + 朱红印记）。
const PaperPainter := preload("res://src/ui/exploration/node_graph_region_paper.gd")


## 画一张完整的地图地区层——逐地区画三笔。[br]
## [br][param p_host] 绘制宿主（渲染器——提供 [code]cells[/code] /
## [code]states[/code] / [code]nodes[/code] / [code]reveal_max_layer[/code] /
## [code]is_node_highlighted[/code] / [code]place_name_of[/code]）。[br]
## [br][b]绘制顺序：先全部底渍 → 再全部边 → 最后全部纸条[/b]，而不是「一个地区三笔
## 连画」。原因：相邻地区共边，逐块连画时后画的那块底渍会盖住前一块的边；同理纸条要在
## [b]所有[/b]底渍与边之上，否则邻块的边会压在纸条上。三轮的顺序是全局的。[br]
## [br][b]分块表为空就直接返回[/b]：布局还没跑过（[code]cells[/code] 未生成）时不画，
## 免得在原点堆出一坨退化多边形。
static func draw_regions(p_host: Control) -> void:
	var cells: Dictionary = p_host.get(&"cells")
	if cells.is_empty():
		return
	var ids: Array = RegionCommon.visible_ids(p_host, cells)
	_draw_washes(p_host, cells, ids)
	EdgePainter.draw_edges(p_host, cells, ids)
	# 纸条（地区名）本轮[b]不画[/b]：一个地区正好一个节点，纸条上的字与节点下方的地名逐字相同，
	# 同一屏里出现两次；玩家读「这一片叫什么」看节点下方的字就够，地区这一层只负责「疆域」。
	# PaperPainter.draw_papers(p_host, cells, ids)


## 地区分块表（[code]{node_id: PackedVector2Array}[/code]）——渲染器持有，绘制前算一次。[br]
## [br][b]为什么在渲染器上持有而不在绘制时现算[/b]：同一份分块被[b]三处[/b]读——绘制、
## 命中检测、内容包围盒（地区要铺满可视范围）。三处各算一次就是三次 O(n²) 裁剪，且
## 三份结果一旦因为输入微差而不同，就会出现「画在这块地、点那块地」的错位。
static func cells_of_nodes(p_positions: Dictionary, p_bounds: Rect2) -> Dictionary:
	return RegionCommon.cells_of_nodes(p_positions, p_bounds)


# ═══════════════════════════════════════════════════════════════════════════════
# 第一笔：底渍（极淡墨色面）
# ═══════════════════════════════════════════════════════════════════════════════

## 逐地区铺底渍（含去饱和与整块压暗两档）。[br]
## [br][b]高亮怎么处理[/b]：悬停/焦点的那一块浓度乘
## [constant NodeGraphStyleRegion.HIGHLIGHT_WASH_GAIN]——「整片地亮起来」只动浓度这根轴，
## 六态的信息一个像素没丢（换色会与六态配色打架）。[br]
## [br][b]为什么要先三角化再合批[/b]：[code]draw_colored_polygon[/code] 每次调用是一个
## 独立绘制项（每块地区一个）；三角化后同色块合进一个
## [code]canvas_item_add_triangle_array[/code]，出厂图 12 块地合成 2 批（暖块一批、
## 冷块一批，见 [method _wash_color]）。[br]
## [br][b]为什么按 [method Color.is_equal_approx] 断批而不是按奇偶下标断[/b]：断批的
## 依据应是「画出来是不是同色」；本方法只认颜色，则 [method _wash_color] 将来多出任何
## 一档色差都自动多断一批，不必回来改这里。
static func _draw_washes(p_host: Control, p_cells: Dictionary, p_ids: Array) -> void:
	var canvas: RID = p_host.get_canvas_item()
	var points := PackedVector2Array()
	var indices := PackedInt32Array()
	var color: Color = Color.TRANSPARENT
	var started: bool = false
	for node_id: int in p_ids:
		var poly: PackedVector2Array = p_cells[node_id]
		if poly.size() < 3:
			continue
		var block_color: Color = _wash_color(p_host, node_id)
		if not started or not block_color.is_equal_approx(color):
			_flush(canvas, points, indices, color)
			points = PackedVector2Array()
			indices = PackedInt32Array()
			color = block_color
			started = true
		_append(points, indices, poly)
	_flush(canvas, points, indices, color)


## 第 [param p_node_id] 块地区的底渍色（浓度 + 冷暖微差 + 去饱和 + 压暗 + 高亮提亮）。[br]
## [br][b]冷暖微差由节点 ID 奇偶给出[/b]（确定性、无需随机源）：奇数块偏暖（R 抬、
## B 压），偶数块偏冷——幅度 [constant NodeGraphStyleRegion.WASH_TEMP_SHIFT]，
## 肉眼只在相邻两块之间才分辨得出，正是「看得出是一块块地、但不花」的那一档。[br]
## [br][b]为什么去饱和用手算而不是 [method Color.srgb_to_linear] 一族[/b]：面是纯色
## 填充，没有按顶点着色的渐变可用；去饱和按「向该色亮度靠拢」的线性插值给出，量小
## （0.45）且方向明确，不需要色彩空间往返。[br]
## [br][b]压暗为什么加在浓度上[/b]：底色本身已是近黑，提高不透明度就是把这块地往下沉
## ——与「再盖一层黑」同效，但省一整个绘制项。[br]
## [br][b]返回[/b]：不透明色（alpha 含浓度、去饱和只动色相不动 alpha）。
static func _wash_color(p_host: Control, p_node_id: int) -> Color:
	var base: Color = RegionStyle.WASH_COLOR
	var warm: bool = (p_node_id % 2) == 1
	var shift: float = RegionStyle.WASH_TEMP_SHIFT * (1.0 if warm else -1.0)
	base = Color(base.r + shift, base.g, base.b - shift)
	var alpha: float = RegionStyle.WASH_ALPHA_MAX if warm else RegionStyle.WASH_ALPHA_MIN
	var visual: Dictionary = RegionCommon.visual_of(p_host, p_node_id)
	alpha *= float(visual.get("wash_gain", 1.0))
	if RegionCommon.highlighted(p_host, p_node_id):
		alpha *= RegionStyle.HIGHLIGHT_WASH_GAIN
	var desaturate: float = float(visual.get("desaturate", 0.0))
	if desaturate > 0.0:
		var luma: float = base.r * 0.30 + base.g * 0.59 + base.b * 0.11
		base = base.lerp(Color(luma, luma, luma), desaturate)
	var dim: float = float(visual.get("dim", 0.0))
	return Color(base.r, base.g, base.b, clampf(alpha + dim * 0.5, 0.0, 1.0))


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════════════════

## 一笔底的批绘制收尾（同色块合成一批——见 [method _draw_washes]）。[br]
## [br][b]为什么颜色表只有一个元素[/b]：[code]canvas_item_add_triangle_array[/code] 的
## 每顶点色表若给一个元素、顶点表给 N 个，引擎对全部顶点取该色（与
## [code]node_graph_fog_region.gd[/code] 同一条口径）。整批同色，故一个就够。[br]
## [br][b]空批直接返回[/b]：没有任何面的批次调用
## [code]canvas_item_add_triangle_array[/code] 会生成一个空绘制项。
static func _flush(p_canvas: RID, p_points: PackedVector2Array,
		p_indices: PackedInt32Array, p_color: Color) -> void:
	if p_indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(p_canvas, p_indices, p_points,
			PackedColorArray([p_color]))


## 三角化一块多边形并把顶点 / 索引追加进批表（退化块跳过——同迷雾那一笔的口径）。[br]
## [br][b]为什么底渍不走抖动[/b]：底渍是[b]面[/b]，它的边界随后必被第二笔的墨边压住
## ——面的轮廓抖动一个像素也看不见；而抖动会给顶点表插入大量采样点（一条 200px 的边
## 插 5 个点），面是整张图上最大的一批几何，白插的顶点是纯粹的浪费。[br]
## [br][b]为什么不能假设它是凸的从而走三角扇[/b]：Voronoi 的单元确实是凸的，但裁剪后的
## 顶点表可能含[b]共线点[/b]（半平面恰好切在顶点上），三角扇对共线点的退化行为不保证；
## 统一走 [method Geometry2D.triangulate_polygon] 与迷雾那一笔同一条通路。[br]
## [br][b]三角化失败（返回空表）就跳过[/b]：退化多边形（面积为 0）画出来是一片噪点，
## 不如不画。
static func _append(p_points: PackedVector2Array, p_indices: PackedInt32Array,
		p_poly: PackedVector2Array) -> void:
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(p_poly)
	if triangles.is_empty():
		return
	var base: int = p_points.size()
	p_points.append_array(p_poly)
	for i: int in triangles:
		p_indices.append(base + i)
