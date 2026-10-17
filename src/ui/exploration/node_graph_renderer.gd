class_name NodeGraphRenderer
extends Control
## NodeGraphRenderer —— 节点图渲染基座（exploration-ui Story 001 stub）。
##
## [b]职责[/b]：接收 stub DAG 数据（[code]setup(graph, nodes)[/code]——003
## story 将改为真实 ExplorationSystem 数据源），渲染节点 + 连线 + 迷雾覆盖，
## 作为缩放平移容器 [NodeGraphViewport] 的内容宿主。[br]
## [br][b]绘制策略[/b]（ADR-0031 §5 合批）：[br]
##   - **节点**：单一自绘 [code]_draw()[/code]——每节点 3 笔（图集 region + 边框 +
## 文字）× 24 节点；图标统一走 [NodeIconAtlas] 图集（禁止独立纹理）[br]
##   - **连线**：同节点自绘 [code]draw_line[/code]（已访问金色实线 / 未访问暗色虚线
## ——GDD 节点间连线规则）[br]
##   - **迷雾**：[b]整体覆盖层单节点[/b]（[code]FogOverlay[/code] 内类——一块
## 全画布半透遮罩，访问过的节点区域挖孔）。不逐节点实例化迷雾节点——ADR-0031
## 「迷雾遮罩等大面积重复元素合批渲染」的直接验证（AC-3）[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不缓存游戏状态——stub 数据为渲染
## 输入快照（003 接入真实数据后由信号周期重传入）；[code]visited/fog[/code] 为
## 渲染参数非游戏状态。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——纯 [code]_draw()[/code] 响应
## [code]queue_redraw()[/code]。
##
## [br]来源: ADR-0031、design/gdd/exploration-ui-system.md §2、
## exploration-ui Story 001（R-05 行为关卡）。

## === Visual 常量（数据驱动——GDD 调优参数表）===========================

## 节点图标显示边长（px）——GDD 调优参数「节点图标大小 48×48px」。
const NODE_SIZE: float = 48.0
## 层间距（px）——GDD 调优参数「节点间距（最小）80px」的纵向分量。
const LAYER_GAP: float = 110.0
## 同层节点间距（px）——横向分量。
const NODE_GAP: float = 90.0
## 节点连线线宽（px）——GDD「节点连线线宽 2px」。
const EDGE_WIDTH: float = 2.0
## 虚线段长（未访问路径——GDD「暗色虚线」）。
const DASH_LENGTH: float = 8.0
## 迷雾底色——深色覆盖（GDD「迷雾节点：深色覆盖 + ❓标记」——❓标记归
## 揭雾动画 story，本 stub 以遮罩挖孔近似）。
const FOG_COLOR: Color = Color(0.05, 0.06, 0.08, 0.72)
## 迷雾挖孔半径——已访问/已揭示节点区域从遮罩中挖出（px）。
const FOG_HOLE_RADIUS: float = 34.0
## 已访问路径连线色——金色实线（GDD 连线规则）。
const EDGE_VISITED_COLOR: Color = Color("#C8A84E")
## 未访问路径连线色——暗灰（GDD 连线规则）。
const EDGE_UNVISITED_COLOR: Color = Color(0.30, 0.30, 0.32, 0.85)
## 已访问节点边框色——绿色（GDD 界面规则「已访问：绿色边框 + ✓」——✓ stub 略）。
const NODE_VISITED_BORDER: Color = Color("#44CC66")
## 当前节点边框色——金色（GDD「当前节点：金色边框」）。
const NODE_CURRENT_BORDER: Color = Color("#FFD700")
## 未知类型边框色——中性暗（迷雾内节点不显示类型色）。
const NODE_DEFAULT_BORDER: Color = Color(0.45, 0.45, 0.48)
## 迷雾节点图集 region——❓占位（stub：暗灰底白环，类型不暴露）。
const FOG_GLYPH_REGION_COL: int = 4  # 复用事件 ring 图形 + 灰色（见 _draw_node）

## === 渲染输入（stub 数据——003 接真实源）=================================

## 邻接表 {node_id: [child_id, ...]}——ExplorationSystem.generate_map().graph 同构。
var graph: Dictionary = {}
## 节点详情 {node_id: {type, layer, idx, ...}}——同构 node_details。
var nodes: Dictionary = {}
## 已访问节点集合（Array——含到达节点）。
var visited: Array = []
## 当前节点 ID（金色边框 + 迷雾豁免）。
var current_node: int = -1
## 文字标签显隐——缩放联动（Viewport 在 50% 缩放时置 false——模式库「画布缩放平移」
## 「50% 时隐藏节点文字标签只留图标」）。
var show_labels: bool = true

## === 内部 ===================================================================

## 节点中心坐标缓存——setup 时布局计算（零轮询：不每帧重算）。
var _positions: Dictionary = {}
## 内容包围盒——Viewport 整图适配基准（复位/初始 fit 用）。
var _content_rect: Rect2 = Rect2()


## 注入 stub DAG 数据并重布局。[br]
## [param graph]: 邻接表。[br][param nodes]: 节点详情（含 layer/idx）。[br]
## [param visited]: 已访问节点 ID 列表。[br][param current_node]: 当前节点 ID。
func setup(graph: Dictionary, nodes: Dictionary, visited: Array = [], current_node: int = -1) -> void:
	self.graph = graph
	self.nodes = nodes
	self.visited = visited
	self.current_node = current_node
	_layout()
	queue_redraw()


## 节点中心坐标（布局：layer 纵向 / idx 横向居中排布）。
func get_node_position(node_id: int) -> Vector2:
	return _positions.get(node_id, Vector2.ZERO)


## 内容包围盒（节点 + 边距）——Viewport 整图适配的计算基准。
func get_content_rect() -> Rect2:
	return _content_rect


## === 绘制（合批核心——全部元素单 _draw）===================================

func _draw() -> void:
	if nodes.is_empty():
		return
	_draw_edges()
	for node_id: int in nodes.keys():
		_draw_node(node_id)
	_draw_fog()


## 绘制全部连线（已访问金色实线 / 未访问暗色虚线）。
func _draw_edges() -> void:
	for from_id: int in graph.keys():
		var from_pos: Vector2 = get_node_position(from_id)
		for to_id: int in graph[from_id]:
			var to_pos: Vector2 = get_node_position(to_id)
			if _is_edge_visited(from_id, to_id):
				draw_line(from_pos, to_pos, EDGE_VISITED_COLOR, EDGE_WIDTH)
			else:
				_draw_dashed_line(from_pos, to_pos, EDGE_UNVISITED_COLOR)


## 单节点绘制：图集 region（1 笔）+ 边框（1 笔）+ 文字（1 笔）。
func _draw_node(node_id: int) -> void:
	var pos: Vector2 = get_node_position(node_id)
	var rect := Rect2(pos.x - NODE_SIZE * 0.5, pos.y - NODE_SIZE * 0.5, NODE_SIZE, NODE_SIZE)
	var detail: Dictionary = nodes.get(node_id, {})
	var type_id: int = int(detail.get("type", 1))
	var is_fogged: bool = _is_fogged(node_id)

	# 图标：迷雾节点不显示类型——统一灰底（类型不暴露，GDD 界面规则）
	if is_fogged:
		# 迷雾灰底 + 问号环 glyph（draw_texture_rect_region 无 modulate 参数——
		# 4.6 API 探测确认；先画灰底再叠白环图形近似「类型不暴露」）
		draw_rect(rect, Color(0.22, 0.23, 0.26))
		var hole_rect := Rect2(pos.x - 12.0, pos.y - 12.0, 24.0, 24.0)
		draw_texture_rect_region(NodeIconAtlas.get_atlas(), hole_rect,
				NodeIconAtlas.get_region(FOG_GLYPH_REGION_COL))
	else:
		draw_texture_rect_region(NodeIconAtlas.get_atlas(), rect, NodeIconAtlas.get_region(type_id))

	# 边框：当前 > 已访问 > 类型色暗化
	var border_color: Color = NODE_DEFAULT_BORDER
	if node_id == current_node:
		border_color = NODE_CURRENT_BORDER
	elif visited.has(node_id):
		border_color = NODE_VISITED_BORDER
	elif not is_fogged:
		border_color = NodeIconAtlas.get_color(type_id).darkened(0.25)
	draw_rect(rect, border_color, false, 2.0)

	# 文字标签（缩放联动——50% 隐藏）
	if show_labels and not is_fogged:
		var label: String = str(detail.get("label", NodeIconAtlas.get_label(type_id)))
		draw_string(_label_font(), Vector2(pos.x - NODE_SIZE * 0.5, pos.y + NODE_SIZE * 0.5 + 14.0),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)


## 迷雾整体覆盖层——单节点绘制（AC-3 合批验证核心）。[br]
## 一块全画布遮罩 + 已访问/相邻区域挖孔（[code]draw_rect[/code] 覆盖 +
## 挖孔以 lighter 混合近似——stub 实现；真实揭雾渐变动画归后续 story）。
func _draw_fog() -> void:
	if _fogged_positions().is_empty():
		return  # 无迷雾——不产生任何绘制
	var fog_rect := Rect2(_content_rect.position - Vector2(40, 40),
			_content_rect.size + Vector2(80, 80))
	draw_rect(fog_rect, FOG_COLOR)
	# 挖孔：已访问 + 当前节点的可见区域以背景色圆近似「揭开的洞」
	for hole_pos: Vector2 in _revealed_positions():
		draw_circle(hole_pos, FOG_HOLE_RADIUS, Color(0.08, 0.09, 0.12))


## === 内部辅助 ===============================================================

## 布局计算——layer 纵向、idx 横向居中；同步内容包围盒。
func _layout() -> void:
	_positions.clear()
	if nodes.is_empty():
		_content_rect = Rect2()
		return
	var layer_counts: Dictionary = {}
	var max_layer: int = 0
	for node_id: int in nodes.keys():
		var layer: int = int(nodes[node_id].get("layer", 0))
		layer_counts[layer] = int(layer_counts.get(layer, 0)) + 1
		max_layer = maxi(max_layer, layer)
	# 每层节点 idx → 横向居中偏移
	var idx_in_layer: Dictionary = {}
	for node_id: int in nodes.keys():
		var layer: int = int(nodes[node_id].get("layer", 0))
		var idx: int = int(nodes[node_id].get("idx", 0))
		idx_in_layer[node_id] = idx
	var bounds := Rect2()
	var initialized: bool = false
	for node_id: int in nodes.keys():
		var layer: int = int(nodes[node_id].get("layer", 0))
		var idx: int = int(idx_in_layer[node_id])
		var count: int = int(layer_counts.get(layer, 1))
		var row_width: float = (float(count) - 1.0) * NODE_GAP
		var pos := Vector2(
				(row_width * 0.5) - (float(idx) * NODE_GAP),
				float(layer) * LAYER_GAP)
		_positions[node_id] = pos
		if not initialized:
			bounds = Rect2(pos, Vector2.ZERO)
			initialized = true
		else:
			bounds = bounds.expand(pos)
	_content_rect = bounds.grow(NODE_SIZE)


## 边是否已访问（两端均在 visited——走过路径）。
func _is_edge_visited(from_id: int, to_id: int) -> bool:
	return visited.has(from_id) and visited.has(to_id)


## 节点是否迷雾覆盖（未访问且非当前且非已访问邻接揭示区——stub 近似：
## visited ∪ {current} ∪ 其相邻节点之外均为迷雾）。
func _is_fogged(node_id: int) -> bool:
	return not _revealed_set().has(node_id)


## 已揭示集合：已访问 + 当前节点 + 当前节点的邻接（前向 + 后向）。
func _revealed_set() -> Array:
	var revealed: Array = visited.duplicate()
	if current_node >= 0 and not revealed.has(current_node):
		revealed.append(current_node)
	if graph.has(current_node):
		for to_id: int in graph[current_node]:
			if not revealed.has(to_id):
				revealed.append(to_id)
	for from_id: int in graph.keys():
		if graph[from_id].has(current_node) and not revealed.has(from_id):
			revealed.append(from_id)
	return revealed


## 迷雾覆盖的节点位置列表（AC-3 采样用——迷雾节点计数）。
func _fogged_positions() -> Array:
	var result: Array = []
	for node_id: int in nodes.keys():
		if _is_fogged(node_id):
			result.append(get_node_position(node_id))
	return result


## 已揭示节点位置列表（迷雾挖孔位置）。
func _revealed_positions() -> Array:
	var revealed: Array = _revealed_set()
	var result: Array = []
	for node_id: int in revealed:
		if _positions.has(node_id):
			result.append(_positions[node_id])
	return result


## 虚线绘制——Godot 4.6 内建 [method draw_dashed_line]（API 探测确认签名：
## from, to, color, width=-1, dash=2.0, aligned=true——dash 为段长）。
func _draw_dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	draw_dashed_line(from, to, color, EDGE_WIDTH, DASH_LENGTH)


## 文字字体——主题默认（真实字体归美术资产管线）。
func _label_font() -> Font:
	var theme_font: Font = get_theme_default_font()
	return theme_font if theme_font != null else ThemeDB.fallback_font
