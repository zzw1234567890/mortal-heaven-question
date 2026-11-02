class_name NodeGraphRenderer
extends Control
## NodeGraphRenderer —— 节点图渲染基座（exploration-ui Story 001 stub + S16-3 状态接入）。
##
## [b]职责[/b]：接收 DAG 数据（[code]setup(graph, nodes)[/code]），渲染节点 +
## 连线 + 迷雾覆盖，作为缩放平移容器 [NodeGraphViewport] 的内容宿主。[br]
## [br][b]S16-3 状态接入[/b]：新增 [method set_states]——六态样式经
## [NodeStateLogic] 纯函数判定后由宿主（NodeGraphScreen）注入。注入后
## [method _draw_node] 走六态分支（边框/标记/暗化/斜线/发光）；未注入时保留
## Story 001 legacy 分支（[code]_is_fogged[/code]/visited/current 直判）——两者
## 绘制路径互斥，Story 001 基准回归零风险。[br]
## [br][b]绘制策略[/b]（ADR-0031 §5 合批）：[br]
##   - **节点**：单一自绘 [code]_draw()[/code]——每节点 3-4 笔（图集 region + 边框 +
## 文字 + 标记）；图标统一走 [NodeIconAtlas] 图集（禁止独立纹理）[br]
##   - **连线**：同节点自绘 [code]draw_line[/code]（已访问金色实线 / 未访问暗色虚线）[br]
##   - **迷雾**：整体覆盖层单节点（[code]FogOverlay[/code] 内类——一块全画布
## 半透遮罩，访问过的节点区域挖孔）+ 迷雾节点个体 ❓ 标记。不逐节点实例化
## 迷雾节点——ADR-0031「迷雾遮罩等大面积重复元素合批渲染」的直接验证[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不缓存游戏状态——数据为渲染输入快照；
## [code]states[/code] 为纯函数判定结果（渲染参数非游戏状态）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——纯 [code]_draw()[/code] 响应
## [code]queue_redraw()[/code]。
##
## [br]来源: ADR-0031、design/gdd/exploration-ui-system.md §2、
## exploration-ui Story 001 / 003。

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
## 迷雾底色——深色覆盖（GDD「迷雾节点：深色覆盖 + ❓标记」）。
const FOG_COLOR: Color = Color(0.05, 0.06, 0.08, 0.72)
## 迷雾挖孔半径——已访问/已揭示节点区域从遮罩中挖出（px）。
const FOG_HOLE_RADIUS: float = 34.0
## 已访问路径连线色——金色实线（GDD 连线规则）。
const EDGE_VISITED_COLOR: Color = Color("#C8A84E")
## 未访问路径连线色——暗灰（GDD 连线规则）。
const EDGE_UNVISITED_COLOR: Color = Color(0.30, 0.30, 0.32, 0.85)
## NodeStateLogic 脚本常量——六态样式查询（class_name 在 headless 动态加载下
## 不可靠，preload 脚本常量——S16-1/2 先例）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")
## 已访问节点边框色——绿色（GDD 界面规则「已访问：绿色边框 + ✓」）。
const NODE_VISITED_BORDER: Color = Color("#44CC66")
## 当前节点边框色——金色（GDD「当前节点：金色边框」）。
const NODE_CURRENT_BORDER: Color = Color("#FFD700")
## 未知类型边框色——中性暗（迷雾内节点不显示类型色）。
const NODE_DEFAULT_BORDER: Color = Color(0.45, 0.45, 0.48)
## 迷雾节点图集 region——❓占位（stub：暗灰底白环，类型不暴露）。
const FOG_GLYPH_REGION_COL: int = 4  # 复用事件 ring 图形 + 灰色（见 _draw_node）

## 可达节点脉冲发光外圈色（AC-2——白色/蓝色脉冲外发光；静态近似，动画归手动证据）。
const REACHABLE_GLOW_COLOR: Color = Color(0.35, 0.55, 1.0, 0.45)
## 行动力不足红色斜线色（AC-5——灰色 + 红色斜线）。
const AP_INSUFFICIENT_SLASH_COLOR: Color = Color(0.85, 0.20, 0.20)
## 渡劫台「修为尚未圆满」灰色斜线色（AC-8——与 AP 不足红色斜线区分：
## 红=行动力不足不可达，灰=可进入不可触发）。
const TRIBULATION_UNREADY_SLASH_COLOR: Color = Color(0.55, 0.55, 0.58)
## 渡劫台金色脉冲外发光色（AC-11——类型恒常视觉「金色脉冲」，与精英⚡区分；
## 色取自渡劫台类型主色 #FFAA00 带透明度）。
const TRIBULATION_GLOW_COLOR: Color = Color(1.0, 0.667, 0.0, 0.4)
## 渡劫台节点类型 ID——锚定 [code]ExplorationSystem.NodeType.TRIBULATION[/code]
##（=9）。GDD 界面规则表「渡劫台：⚡图标 + 金色脉冲」的类型恒常视觉判定。
const TRIBULATION_TYPE: int = 9
## 已访问节点暗化强度（AC-4——稍暗）。
const VISITED_DIM_ALPHA: float = 0.35

## === 渲染输入（stub 数据——003 接真实源）=================================

## 邻接表 {node_id: [child_id, ...]}——ExplorationSystem.generate_map().graph 同构。
var graph: Dictionary = {}
## 节点详情 {node_id: {type, layer, idx, ...}}——同构 node_details。
var nodes: Dictionary = {}
## 已访问节点集合（Array——含到达节点）。
var visited: Array = []
## 当前节点 ID（金色边框 + 迷雾豁免）。
var current_node: int = -1
## 六态样式映射 {node_id: NodeState 枚举值}——[method set_states] 注入
## （S16-3；空字典走 legacy 分支）。
var states: Dictionary = {}
## 文字标签显隐——缩放联动（Viewport 在 50% 缩放时置 false——模式库「画布缩放平移」）。
var show_labels: bool = true
## 已揭示的最大层索引（-1 = 全部揭示）。逐层展开浮现动画（0.8s）由宿主 tween
## 驱动本字段逐步递增——超过该层的节点不绘制（AC-1 逐层浮现；动画时序归手动证据）。
var reveal_max_layer: int = -1
## 当前悬停节点 ID（-1 = 无）——[method hit_test_node] 命中检测维护，
## [method _draw_hover_tooltip] 绘制悬停预览（AC-10；0.3s 浮出时序归手动证据）。
var hovered_node: int = -1

## === 内部 ===================================================================

## 节点中心坐标缓存——setup 时布局计算（零轮询：不每帧重算）。
var _positions: Dictionary = {}
## 内容包围盒——Viewport 整图适配基准（复位/初始 fit 用）。
var _content_rect: Rect2 = Rect2()


## 注入 DAG 数据并重布局。[br]
## [param graph]: 邻接表。[br][param nodes]: 节点详情（含 layer/idx）。[br]
## [param visited]: 已访问节点 ID 列表。[br][param current_node]: 当前节点 ID。
func setup(graph: Dictionary, nodes: Dictionary, visited: Array = [], current_node: int = -1) -> void:
	self.graph = graph
	self.nodes = nodes
	self.visited = visited
	self.current_node = current_node
	_layout()
	queue_redraw()


## 注入六态样式映射（S16-3）——宿主经 [NodeStateLogic] 判定后传入。[br]
## [b]空字典[/b] = 回退 legacy 直判分支（Story 001 基准路径）。
func set_states(state_map: Dictionary) -> void:
	states = state_map
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
	if hovered_node >= 0:
		_draw_hover_tooltip(hovered_node)


func _gui_input(event: InputEvent) -> void:
	# 悬停命中检测（AC-10）——纯输入驱动（无 _process 轮询），维护
	# [member hovered_node] 并触发重绘。
	if event is InputEventMouseMotion:
		var new_hover: int = _hit_test_any(event.position)
		if new_hover != hovered_node:
			hovered_node = new_hover
			queue_redraw()


func _mouse_exited() -> void:
	if hovered_node != -1:
		hovered_node = -1
		queue_redraw()


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


## 单节点绘制——S16-3 六态分支（states 注入）优先，否则 legacy 直判分支。
func _draw_node(node_id: int) -> void:
	# 逐层展开浮现（AC-1）——超过 reveal_max_layer 的层不绘制
	if reveal_max_layer >= 0:
		var layer: int = int(nodes.get(node_id, {}).get("layer", 0))
		if layer > reveal_max_layer:
			return
	if states.has(node_id):
		_draw_node_stated(node_id)
	else:
		_draw_node_legacy(node_id)


## Legacy 分支（Story 001 基准——states 未注入时行为与 001 完全一致）。
func _draw_node_legacy(node_id: int) -> void:
	var pos: Vector2 = get_node_position(node_id)
	var rect := Rect2(pos.x - NODE_SIZE * 0.5, pos.y - NODE_SIZE * 0.5, NODE_SIZE, NODE_SIZE)
	var detail: Dictionary = nodes.get(node_id, {})
	var type_id: int = int(detail.get("type", 1))
	var is_fogged: bool = _is_fogged(node_id)

	# 图标：迷雾节点不显示类型——统一灰底（类型不暴露，GDD 界面规则）
	if is_fogged:
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


## S16-3 六态分支——样式经 [NodeStateLogic.node_state_style] 查询后逐项渲染。
func _draw_node_stated(node_id: int) -> void:
	var style: Dictionary = NodeStateLogicScript.node_state_style(int(states[node_id]))
	var pos: Vector2 = get_node_position(node_id)
	var rect := Rect2(pos.x - NODE_SIZE * 0.5, pos.y - NODE_SIZE * 0.5, NODE_SIZE, NODE_SIZE)
	var detail: Dictionary = nodes.get(node_id, {})
	var type_id: int = int(detail.get("type", 1))
	var fogged: bool = bool(style.get("fogged", false))

	# 图标：迷雾节点不显示类型——灰底 + ❓（GDD 界面规则）；否则类型图集 region
	if fogged:
		draw_rect(rect, Color(0.22, 0.23, 0.26))
		var hole_rect := Rect2(pos.x - 12.0, pos.y - 12.0, 24.0, 24.0)
		draw_texture_rect_region(NodeIconAtlas.get_atlas(), hole_rect,
				NodeIconAtlas.get_region(FOG_GLYPH_REGION_COL))
	else:
		draw_texture_rect_region(NodeIconAtlas.get_atlas(), rect, NodeIconAtlas.get_region(type_id))
		# 已访问稍暗（AC-4）——半透黑叠加（draw_texture_rect_region 无 modulate）
		if bool(style.get("dim", false)):
			draw_rect(rect, Color(0.0, 0.0, 0.0, VISITED_DIM_ALPHA))

	# 可达节点脉冲外发光（AC-2）——外圈半透光环（静态近似；脉动动画归手动证据）
	if str(style.get("glow", "")) == "pulse_blue":
		draw_circle(pos, NODE_SIZE * 0.5 + 4.0, REACHABLE_GLOW_COLOR)
	if str(style.get("glow", "")) == "gold":
		draw_circle(pos, NODE_SIZE * 0.5 + 3.0, Color(1.0, 0.84, 0.0, 0.35))
	# 渡劫台金色脉冲（AC-11——类型恒常视觉，与当前节点 gold 发光独立叠加；
	# 精英红边框已由下方 border_is_type 类型主色 #FF4444 覆盖）
	if type_id == TRIBULATION_TYPE and not fogged:
		draw_circle(pos, NODE_SIZE * 0.5 + 5.0, TRIBULATION_GLOW_COLOR)

	# 边框：border_is_type 时用类型主色，否则用样式边框色
	var border_color: Color = style.get("border", NODE_DEFAULT_BORDER)
	if bool(style.get("border_is_type", false)):
		border_color = NodeIconAtlas.get_color(type_id)
	draw_rect(rect, border_color, false, 2.0)

	# 行动力不足红色斜线（AC-5）——渡劫台修为未满时跳过（灰斜线优先，避免
	# 同对角线重叠；未满语义「可进入不可触发」强于「行动力不足」）
	if bool(style.get("slash", false)) and not _is_tribulation_unready(detail):
		draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y),
				AP_INSUFFICIENT_SLASH_COLOR, 2.0)

	# 渡劫台「修为尚未圆满」——灰色斜线（AC-8 可进入不可触发；与 AP 不足红色
	# 斜线区分，纯函数 [NodeStateLogic.is_tribulation_not_ready] 判定）
	if _is_tribulation_unready(detail):
		draw_line(Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y),
				TRIBULATION_UNREADY_SLASH_COLOR, 2.0)

	# 状态标记（玩家/✓/锁/❓——AC-1 逐项一致断言目标）
	_draw_state_marker(str(style.get("marker", "")), pos, rect)

	# 文字标签（缩放联动——50% 隐藏；迷雾不显示类型标签）
	if show_labels and not fogged:
		var label: String = str(detail.get("label", NodeIconAtlas.get_label(type_id)))
		draw_string(_label_font(), Vector2(pos.x - NODE_SIZE * 0.5, pos.y + NODE_SIZE * 0.5 + 14.0),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12)


## 渡劫台「修为尚未圆满」判定（AC-8）——type==渡劫台(9) 且
## [code]tribulation_ready=false[/code]（委托 [NodeStateLogic.is_tribulation_not_ready]
## 纯函数，渲染层仅消费判定结果——零状态所有权）。
func _is_tribulation_unready(detail: Dictionary) -> bool:
	return NodeStateLogicScript.is_tribulation_not_ready(detail)


## 悬停 tooltip 绘制（AC-10）——节点命中检测维护的 [member hovered_node] 渲染
## 预览（名称 + 描述 + 敌人详情；迷雾显示「?」）。[br]
## [b]内容源[/b]：[NodeStateLogic.tooltip_text] 纯函数（迷雾判定以六态 FOGGED
## 为准——与 [method _fogged_positions] 同源）。
func _draw_hover_tooltip(node_id: int) -> void:
	var detail: Dictionary = nodes.get(node_id, {})
	var fogged: bool = false
	if states.has(node_id):
		fogged = int(states[node_id]) == NodeStateLogicScript.NodeState.FOGGED
	else:
		fogged = _is_fogged(node_id)
	var text: String = NodeStateLogicScript.tooltip_text(detail, fogged)
	if text.is_empty():
		return
	var pos: Vector2 = get_node_position(node_id)
	# tooltip 盒子锚定在节点上方（画布局部坐标——随 renderer.scale 缩放）
	var anchor := Vector2(pos.x - NODE_SIZE * 0.5, pos.y - NODE_SIZE * 0.5 - 30.0)
	var box: Rect2 = _tooltip_rect(text, anchor)
	draw_rect(box, Color(0.08, 0.09, 0.12, 0.94))
	draw_rect(box, Color(0.55, 0.55, 0.58), false, 1.0)
	draw_string(_label_font(), box.position + Vector2(8.0, 16.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12)


## tooltip 盒子尺寸估算——按文本字符数 × 字体宽度近似（stub；真实测量归
## 字体资产管线）。[br][b]返回[/b]: 以 [param anchor] 为左上角的矩形。
func _tooltip_rect(text: String, anchor: Vector2) -> Rect2:
	var width: float = maxf(64.0, float(text.length()) * 12.0 + 16.0)
	return Rect2(anchor, Vector2(width, 24.0))


## 节点命中检测——[param point]（画布局部坐标）是否落在 [param node_id] 的
## 图标矩形内（AC-10 悬停触发判定；仅统计未迷雾节点——迷雾节点悬停也显示
## 「?」故同样命中）。[br][b]返回[/b]: true 命中。
func hit_test_node(node_id: int, point: Vector2) -> bool:
	var pos: Vector2 = get_node_position(node_id)
	var rect := Rect2(pos.x - NODE_SIZE * 0.5, pos.y - NODE_SIZE * 0.5, NODE_SIZE, NODE_SIZE)
	return rect.has_point(point)


## 命中检测遍历——返回 [param point] 命中的节点 ID（无命中返回 -1）。
## 逐层展开未显现的层（[member reveal_max_layer]）跳过（未绘制不悬停）。
func _hit_test_any(point: Vector2) -> int:
	for node_id: int in nodes.keys():
		if reveal_max_layer >= 0:
			var layer: int = int(nodes.get(node_id, {}).get("layer", 0))
			if layer > reveal_max_layer:
				continue
		if hit_test_node(node_id, point):
			return node_id
	return -1


## 状态标记绘制——[code]player[/code]（人形）/ [code]check[/code]（✓）/
## [code]lock[/code]（🔒）/ [code]question[/code]（❓）。
func _draw_state_marker(marker: String, pos: Vector2, rect: Rect2) -> void:
	match marker:
		"player":
			# 人形图标：头 + 身（金色玩家标记，AC-1 当前节点）
			draw_circle(pos + Vector2(0.0, -10.0), 5.0, NODE_CURRENT_BORDER)
			draw_rect(Rect2(pos.x - 6.0, pos.y - 2.0, 12.0, 12.0), NODE_CURRENT_BORDER)
		"check":
			# ✓ 标记（AC-4 已访问）——两段折线
			var c: Vector2 = pos + Vector2(-7.0, 2.0)
			draw_line(c, c + Vector2(5.0, 6.0), NODE_VISITED_BORDER, 2.0)
			draw_line(c + Vector2(5.0, 6.0), c + Vector2(14.0, -6.0), NODE_VISITED_BORDER, 2.0)
		"lock":
			# 🔒 标记（AC-5 不可达）——锁体 + 锁梁
			draw_rect(Rect2(pos.x - 7.0, pos.y - 1.0, 14.0, 11.0), Color(0.78, 0.78, 0.80))
			draw_arc(pos + Vector2(0.0, -1.0), 6.0, PI, TAU, 12,
					Color(0.78, 0.78, 0.80), 2.0)
		"question":
			# ❓ 标记（AC-6 迷雾）——沿用图集问号环已在图标层绘制，此处补文字
			pass


## 迷雾整体覆盖层——单节点绘制（AC-3 合批验证核心）。[br]
## 一块全画布遮罩 + 已访问/相邻区域挖孔（[code]draw_rect[/code] 覆盖 +
## 挖孔以背景色圆近似——stub 实现；真实揭雾渐变动画归后续 story）。
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


## 节点是否迷雾覆盖（legacy 近似：visited ∪ {current} ∪ 其相邻节点之外均为迷雾）。
func _is_fogged(node_id: int) -> bool:
	return not _revealed_set().has(node_id)


## 已揭示集合（legacy）：已访问 + 当前节点 + 当前节点的邻接（前向 + 后向）。
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


## 迷雾覆盖的节点位置列表（AC-3 采样用——迷雾节点计数）。[br]
## states 注入时以六态 FOGGED 为准（与 NodeStateLogic 判定一致）；否则 legacy 近似。
func _fogged_positions() -> Array:
	var result: Array = []
	if not states.is_empty():
		for node_id: int in nodes.keys():
			if int(states.get(node_id, NodeStateLogicScript.NodeState.FOGGED)) \
					== NodeStateLogicScript.NodeState.FOGGED:
				if _positions.has(node_id):
					result.append(_positions[node_id])
		return result
	for node_id: int in nodes.keys():
		if _is_fogged(node_id):
			result.append(get_node_position(node_id))
	return result


## 已揭示节点位置列表（迷雾挖孔位置）。[br]
## states 注入时挖孔 = 全部非迷雾节点；否则 legacy 已揭示集合。
func _revealed_positions() -> Array:
	var result: Array = []
	if not states.is_empty():
		for node_id: int in nodes.keys():
			if int(states.get(node_id, NodeStateLogicScript.NodeState.FOGGED)) \
					!= NodeStateLogicScript.NodeState.FOGGED:
				if _positions.has(node_id):
					result.append(_positions[node_id])
		return result
	var revealed: Array = _revealed_set()
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
