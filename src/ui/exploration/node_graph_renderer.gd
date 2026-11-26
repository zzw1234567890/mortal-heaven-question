class_name NodeGraphRenderer
extends Control
## NodeGraphRenderer —— 节点图渲染基座（exploration-ui Story 001 stub + S16-3 状态接入）。
##
## [b]职责[/b]：接收 DAG 数据（[code]setup(graph, nodes)[/code]），渲染节点 +
## 连线 + 迷雾覆盖，作为缩放平移容器 [NodeGraphViewport] 的内容宿主。[br]
## [br][b]S16-3 状态接入[/b]：新增 [method set_states]——六态样式经
## [NodeStateLogic] 纯函数判定后由宿主（NodeGraphScreen）注入。注入后节点绘制
## 走六态分支（边框/标记/暗化/斜线/发光）；未注入时保留 Story 001 legacy 分支
## （[code]_is_fogged[/code]/visited/current 直判）——两者绘制路径互斥。[br]
## [br][b]三块内容已拆出[/b]（本文件守 300 行软上限）：[br]
##   - 视觉常量 → [code]node_graph_style.gd[/code]（本文件以 [code]const[/code]
##     转发其中被外部读到的几个，引用点一字未改）；[br]
##   - 几何换算（坐标/包围盒/迷雾集合）→ [code]node_graph_layout.gd[/code]；[br]
##   - 单节点绘制 → [code]node_graph_node_painter.gd[/code]。[br]
## 本文件剩下的是「什么时候画什么」——绘制编排、输入驱动、命中检测与外部契约。[br]
## [br][b]绘制策略[/b]（ADR-0031 §5 合批）：[br]
##   - **节点**：单一自绘 [code]_draw()[/code]——每节点 3-4 笔（图集 region + 边框 +
## 文字 + 标记）；图标统一走 [NodeIconAtlas] 图集[br]
##   - **连线**：同节点自绘 [code]draw_line[/code]（已访问金色实线 / 未访问暗色虚线）[br]
##   - **迷雾**：整体覆盖层（一块全画布半透遮罩，已访问节点区域挖孔）+ 迷雾节点
## 个体 ❓ 标记——ADR-0031「迷雾遮罩等大面积重复元素合批渲染」的直接验证[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不缓存游戏状态——数据为渲染输入快照；
## [code]states[/code] 为纯函数判定结果（渲染参数非游戏状态）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——纯 [code]_draw()[/code] 响应
## [code]queue_redraw()[/code]。
##
## [br]来源: ADR-0031、design/gdd/exploration-ui-system.md §2、
## exploration-ui Story 001 / 003。

## 视觉规格（常量唯一来源）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")
## 几何换算（坐标 / 包围盒 / 迷雾集合，纯函数）。
const Layout := preload("res://src/ui/exploration/node_graph_layout.gd")
## 单节点绘制（legacy + 六态）。
const Painter := preload("res://src/ui/exploration/node_graph_node_painter.gd")
## 六态样式查询（判定与绘制共用同一套枚举）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")

## === Visual 常量（转发 [NodeGraphStyle]——外部既有引用点不变）==================
## [br][b]为什么留一层转发[/b]：这些常量被测试与相邻 UI 直接读
## （[code]r.TRIBULATION_TYPE[/code] / [code]renderer.HOVER_SCALE_RATIO[/code]
## 等），转发后「常量住在哪」可以继续演进而不牵动调用方。

## 节点图标显示边长（px——GDD 调优参数「节点图标大小 48×48px」）。
const NODE_SIZE: float = Style.NODE_SIZE
## 层间距（px）——GDD 调优参数「节点间距（最小）80px」的纵向分量。
const LAYER_GAP: float = Style.LAYER_GAP
## 同层节点间距（px）——横向分量。
const NODE_GAP: float = Style.NODE_GAP
## 节点连线线宽（px）——GDD「节点连线线宽 2px」。
const EDGE_WIDTH: float = Style.EDGE_WIDTH
## 虚线段长（未访问路径——GDD「暗色虚线」）。
const DASH_LENGTH: float = Style.DASH_LENGTH
## 已访问路径连线色——金色实线（GDD 连线规则）。
const EDGE_VISITED_COLOR: Color = Style.EDGE_VISITED_COLOR
## 未访问路径连线色——暗灰（GDD 连线规则）。
const EDGE_UNVISITED_COLOR: Color = Style.EDGE_UNVISITED_COLOR
## 已访问节点边框色——绿色（GDD 界面规则「已访问：绿色边框 + ✓」）。
const NODE_VISITED_BORDER: Color = Style.NODE_VISITED_BORDER
## 当前节点边框色——金色（GDD「当前节点：金色边框」）。
const NODE_CURRENT_BORDER: Color = Style.NODE_CURRENT_BORDER
## 未知类型边框色——中性暗（迷雾内节点不显示类型色）。
const NODE_DEFAULT_BORDER: Color = Style.NODE_DEFAULT_BORDER
## 迷雾节点图集 region——❓占位（stub：暗灰底白环，类型不暴露）。
const FOG_GLYPH_REGION_COL: int = Style.FOG_GLYPH_REGION_COL
## 渡劫台节点类型 ID——锚定 [code]ExplorationSystem.NodeType.TRIBULATION[/code]（=9）。
const TRIBULATION_TYPE: int = Style.TRIBULATION_TYPE
## 渡劫台金色脉冲外发光色（AC-11——类型恒常视觉）。
const TRIBULATION_GLOW_COLOR: Color = Style.TRIBULATION_GLOW_COLOR
## 悬停可达节点放大倍率（story-005 AC-5——UX 规格 110%）。[br]
## [b]单一视觉来源[/b]：悬停放大归渲染层，交互组件不再叠加放大环。
const HOVER_SCALE_RATIO: float = Style.HOVER_SCALE_RATIO

## === 信号 ==================================================================

## 悬停目标变化（[param node_id] = -1 表示无悬停）。交互层如需响应悬停可订阅；
## 悬停视觉本身由本类绘制（单一来源）。
signal hover_changed(node_id: int)

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
## tooltip 与悬停放大据此绘制（AC-10；0.3s 浮出时序归手动证据）。[br]
## [b]悬停放大[/b]（AC-5）：悬停视觉单一来源在本类（ADR-0031 §4 鼠标悬停态）。
var hovered_node: int = -1
## 键盘焦点节点 ID（-1 = 无）——[method set_focused_node] 注入（A3 键盘路径）。[br]
## 焦点环为松石青 2px 外环（ADR-0031 §4 双焦点双视觉）。鼠标悬停优先显示。
var focused_node: int = -1

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


## 注入键盘焦点节点（A3 键盘路径——方向键游标）。[br]
## [param node_id]: 焦点节点 ID（-1 = 清除焦点）。焦点环由本类绘制
## （ADR-0031 §4 双焦点双视觉——鼠标悬停优先）。
func set_focused_node(node_id: int) -> void:
	if focused_node == node_id:
		return
	focused_node = node_id
	queue_redraw()


## 节点中心坐标（布局：layer 纵向 / idx 横向居中排布）。
func get_node_position(node_id: int) -> Vector2:
	return _positions.get(node_id, Vector2.ZERO)


## 节点绘制缩放倍率——悬停的可达节点按 [constant HOVER_SCALE_RATIO] 放大，
## 其余（含已访问/不可达/未悬停）为 1.0。[br]
## [b]单一来源[/b]：绘制路径与命中检测共用同一判定，悬停指标可被测试直接断言。
func get_node_draw_scale(node_id: int) -> float:
	if node_id == hovered_node and states.has(node_id) \
			and int(states[node_id]) == NodeStateLogicScript.NodeState.REACHABLE:
		return HOVER_SCALE_RATIO
	return 1.0


## 内容包围盒（节点 + 边距）——Viewport 整图适配的计算基准。
func get_content_rect() -> Rect2:
	return _content_rect


## 已访问边判定（走过路径）——转引 [NodeStateLogic.edge_is_walked]。[br]
## [br][b]为什么必须同源[/b]：六态是节点级的，「这条路走没走过」是它旁边的另一格——
## 两者判定分家会出现「节点画成已访问、连着它的线还是虚线」这种自相矛盾的图。
func _is_edge_visited(from_id: int, to_id: int) -> bool:
	return NodeStateLogicScript.edge_is_walked(visited, from_id, to_id)


## 渡劫台「修为尚未圆满」判定（AC-8）——转引绘制模块的同名判定
## （渲染层仅消费纯函数结果——零状态所有权）。
func _is_tribulation_unready(detail: Dictionary) -> bool:
	return Painter.is_tribulation_unready(self, detail)


## === 绘制（合批核心——全部元素单 _draw）===================================

func _draw() -> void:
	if nodes.is_empty():
		return
	_draw_edges()
	for node_id: int in nodes.keys():
		if not Layout.is_layer_revealed(nodes, reveal_max_layer, node_id):
			continue  # 逐层展开浮现（AC-1）——未显现的层不绘制
		Painter.draw_node(self, node_id)
	_draw_fog()
	if hovered_node >= 0:
		_draw_hover_tooltip(hovered_node)


func _gui_input(event: InputEvent) -> void:
	# 悬停命中检测（AC-10）——纯输入驱动（无 _process 轮询），维护
	# [member hovered_node] 并触发重绘。
	if event is InputEventMouseMotion:
		var new_hover: int = hit_test_any(event.position)
		if new_hover != hovered_node:
			hovered_node = new_hover
			queue_redraw()
			hover_changed.emit(hovered_node)


## 悬停离开渲染器——清除悬停态（[b]审查 H2[/b]：Godot 4 的 Control 没有
## [code]_mouse_exited[/code] 虚方法，原先的实现永不触发，导致 tooltip 与
## 110% 放大停留不消失）。改为 `_ready` 连接 [signal Control.mouse_exited]。
func _ready() -> void:
	if not mouse_exited.is_connected(_on_mouse_exited):
		mouse_exited.connect(_on_mouse_exited)


func _on_mouse_exited() -> void:
	if hovered_node != -1:
		hovered_node = -1
		queue_redraw()
		hover_changed.emit(-1)


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


## 悬停 tooltip 绘制（AC-10）——内容组装与盒子绘制委托 [NodeGraphNodePainter]
## （与节点绘制同一处，两者共用 [NodeStateLogic.tooltip_text] 的口径）。
func _draw_hover_tooltip(node_id: int) -> void:
	Painter.draw_hover_tooltip(self, node_id)


## 拾取区域覆写——「画得出来就点得到」（可见性与可点性同源）。[br]
## [br]不覆写时引擎按 [code]Rect2(Vector2.ZERO, size)[/code] 判定，而本控件由
## [NodeGraphViewport] 缩放平移、节点又摆在局部负坐标——负 x 的节点画得出来却
## 收不到事件（成因与真机取证见 [method NodeGraphLayout.pick_rect]）。
func _has_point(point: Vector2) -> bool:
	return Layout.pick_rect(size, _content_rect).has_point(point)


## 节点命中检测——[param point]（画布局部坐标）是否落在 [param node_id] 的
## 图标矩形内（AC-10 悬停触发判定；迷雾节点悬停也显示「?」故同样命中）。[br]
## [b]命中框与绘制同源[/b]（审查 M1）：矩形按 [method get_node_draw_scale]
## 缩放——悬停放大的可达节点命中框同步放大，避免「看得见但悬停不到」的边缘
## 高频振荡。[br][b]返回[/b]: true 命中。
func hit_test_node(node_id: int, point: Vector2) -> bool:
	var pos: Vector2 = get_node_position(node_id)
	var size_px: float = NODE_SIZE * get_node_draw_scale(node_id)
	var rect := Rect2(pos.x - size_px * 0.5, pos.y - size_px * 0.5, size_px, size_px)
	return rect.has_point(point)


## 命中检测遍历——返回 [param point] 命中的节点 ID（无命中返回 -1）。
## 逐层展开未显现的层（[member reveal_max_layer]）跳过（未绘制不悬停）。[br]
## [b]公开入口[/b]：交互层点击命中复用本方法（点中即提交）——单份实现避免
## 「未绘制仍可点」的可见性不一致（click/hover 同源过滤）。
func hit_test_any(point: Vector2) -> int:
	for node_id: int in nodes.keys():
		if not Layout.is_layer_revealed(nodes, reveal_max_layer, node_id):
			continue
		if hit_test_node(node_id, point):
			return node_id
	return -1


## 迷雾整体覆盖层——单节点绘制（AC-3 合批验证核心），委托 [NodeGraphNodePainter]。
func _draw_fog() -> void:
	Painter.draw_fog(self, _content_rect, _fogged_positions(), _revealed_positions())


## === 内部辅助 ===============================================================

## 布局计算——layer 纵向 / idx 横向居中；同步内容包围盒（换算委托
## [NodeGraphLayout]，本类只持有结果——零轮询：不每帧重算）。
func _layout() -> void:
	_positions = Layout.compute_positions(nodes)
	_content_rect = Layout.compute_content_rect(_positions)


## 节点是否迷雾覆盖（legacy 近似——六态注入时不走这里）。
func _is_fogged(node_id: int) -> bool:
	return Layout.is_fogged(graph, visited, current_node, node_id)


## 已揭示集合（legacy）：已访问 + 当前节点 + 当前节点的邻接（前向 + 后向）。
func _revealed_set() -> Array:
	return Layout.revealed_set(graph, visited, current_node)


## 迷雾覆盖的节点位置列表（AC-3 采样用——迷雾节点计数）。
func _fogged_positions() -> Array:
	return Layout.fogged_positions(graph, nodes, _positions, states, visited,
			current_node)


## 已揭示节点位置列表（迷雾挖孔位置）。
func _revealed_positions() -> Array:
	return Layout.revealed_positions(graph, nodes, _positions, states, visited,
			current_node)


## 虚线绘制——Godot 4.6 内建 [method draw_dashed_line]（API 探测确认签名：
## from, to, color, width=-1, dash=2.0, aligned=true——dash 为段长）。
func _draw_dashed_line(from: Vector2, to: Vector2, color: Color) -> void:
	draw_dashed_line(from, to, color, EDGE_WIDTH, DASH_LENGTH)
