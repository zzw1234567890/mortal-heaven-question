class_name NodeGraphRenderer
extends "res://src/ui/exploration/node_graph_renderer_decl.gd"
## NodeGraphRenderer —— 节点图渲染基座[b]方法面[/b]（继承链尾段——声明面见
## [code]node_graph_renderer_decl.gd[/code]）。
##
## [b]职责[/b]：接收 DAG 数据（[code]setup(graph, nodes)[/code]），渲染地形 + 小径 +
## 节点 + 迷雾，作为缩放平移容器 [NodeGraphViewport] 的内容宿主。[br]
## [br][b]S16-3 状态接入[/b]：[method set_states]——六态样式经 [NodeStateLogic] 纯函数
## 判定后由宿主（NodeGraphScreen）注入。注入后节点绘制走六态分支（边框/标记/暗化/
## 斜线/发光）；未注入时保留 Story 001 legacy 分支（[code]_is_fogged[/code]/
## visited/current 直判）——两者绘制路径互斥。[br]
## [br][b]绘制内容已分四块[/b]（本文件守 300 行软上限）：[br]
##   - 视觉常量 + 信号 + 渲染输入字段 → [code]node_graph_renderer_decl.gd[/code]（链首）；[br]
##   - 几何换算（坐标 / 包围盒 / 迷雾集合）→ [code]node_graph_layout.gd[/code]；[br]
##   - 单节点绘制（地标 + 两行文字）→ [code]node_graph_node_painter.gd[/code]；[br]
##   - 地形 + 迷雾挖孔 → [code]node_graph_ground_layer.gd[/code]；[br]
##   - 小径 → [code]node_graph_edge_painter.gd[/code]。[br]
## 本文件剩下的是「什么时候画什么」——绘制编排、输入驱动、命中检测与外部契约。[br]
## [br][b]绘制策略[/b]（ADR-0031 §5 合批）：[br]
##   - **节点**：单一自绘 [code]_draw()[/code]——每节点 3-4 笔（图集 region + 边框 +
##     文字 + 标记）；图标统一走 [NodeIconAtlas] 图集[br]
##   - **小径**：同一次 [code]_draw()[/code] 内自绘（已走过金色实线 / 未走过淡土灰
##     虚线 / 雾中暗土灰虚线）[br]
##   - **迷雾**：整块遮罩（多边形挖孔，压在[b]小径之上、节点之下[/b]）+ 迷雾节点
##     个体暗纱 + ❓标记——ADR-0031「迷雾遮罩等大面积重复元素合批渲染」的直接验证
##     （分层顺序的理由见 [method _draw]）[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不缓存游戏状态——数据为渲染输入快照；
## [code]states[/code] 为纯函数判定结果（渲染参数非游戏状态）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——纯 [code]_draw()[/code] 响应
## [code]queue_redraw()[/code]。
##
## [br]来源: ADR-0031、design/gdd/exploration-ui-system.md §2、
## exploration-ui Story 001 / 003。

## 注入 DAG 数据并重布局。[br]
## [param graph]: 邻接表。[br][param nodes]: 节点详情（含 layer/idx）。[br]
## [param visited]: 已访问节点 ID 列表。[br][param current_node]: 当前节点 ID。[br]
## [param p_map_id]: 地图 ID（地形插画与节点地名用；缺省空 = 不覆盖已有值）。
## [br][b]空值不覆盖[/b]：[method NodeGraphScreen._on_node_moved] 重下发快照时
## 不一定带 map_id，把地形抹成空白等于「走一步地图就没了」。
func setup(graph: Dictionary, nodes: Dictionary, visited: Array = [],
		current_node: int = -1, p_map_id: StringName = &"") -> void:
	self.graph = graph
	self.nodes = nodes
	self.visited = visited
	self.current_node = current_node
	if not str(p_map_id).is_empty():
		self.map_id = p_map_id
	_layout()
	queue_redraw()


## 注入地名覆盖表（[code]{node_id: 地名}[/code]）——空字典回到地名池。[br]
## [br][b]为什么留这个口子[/b]：截图脚本与单测需要[b]确定性[/b]的地名（不随节点
## 排布变化），而真实地图的地名由池 + 节点 ID 决定（见
## [code]ExplorationPlaceCatalog.place_for[/code]）。覆盖表只影响绘制，不写任何状态。
func set_place_overrides(overrides: Dictionary) -> void:
	place_overrides = overrides
	queue_redraw()


## 节点地名（覆盖表优先，否则走地名池）——[b]绘制与断言共用的唯一入口[/b]。[br]
## [br][b]返回[/b]：地名（未登记地图为「无名之地 %d」）。
func place_name_of(node_id: int) -> String:
	if place_overrides.has(node_id):
		return str(place_overrides[node_id])
	var detail: Dictionary = nodes.get(node_id, {})
	return PlaceCatalogScript.place_for(map_id, node_id,
			int(detail.get("place_seed", 0)))


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
	# ★ 顺序即语义 ★（本轮地图化后为五层，由下到上）：[br]
	#   1. 地形底图（插画 + 压暗 + 暗角）——「这是一张地图」的底；[br]
	#   2. 迷雾遮罩（挖掉已揭示区域）——压暗[b]连线[/b]，本轮起改为多边形挖孔（见
	#      [code]NodeGraphLayout.fog_polygons[/code]），孔里露出的是地形而不是补丁；[br]
	#   3. 连线（小径）——走在雾[b]上[/b]，于是雾里的路被遮罩压暗、雾外的路是亮的；[br]
	#   4. 节点（地标）——浮在一切之上；[br]
	#   5. 悬停 tooltip——最上。[br]
	# [br][b]为什么不能把迷雾画在最后[/b]（更早一轮修的 bug）：原先 [code]_draw_fog()[/code]
	# 排在节点循环之后，而挖孔用的是近黑底色——1920×1080 取证图里每个已揭示节点都被
	# 那层近黑圆盘重涂了一遍，14 种类型色一个不剩，整幅平均亮度 10.75（几乎全黑）。
	# [br][b]为什么迷雾仍必须在连线之上[/b]：遮罩负责「雾里 / 雾外」的底色落差，压在
	# 连线上才能让结构不泄露；节点浮在其上（亮）、迷雾节点自己叠个体暗纱（暗）。
	_draw_ground()
	_draw_edges()
	for node_id: int in nodes.keys():
		if not Layout.is_layer_revealed(nodes, reveal_max_layer, node_id):
			continue  # 逐层展开浮现（AC-1）——未显现的层不绘制
		Painter.draw_node(self, node_id)
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


## 绘制全部连线（小径）——转引 [NodeGraphEdgePainter]。[br]
## [br][b]为什么留一层转发[/b]：宿主（本类）才是持有渲染输入快照的那一个，绘制
## 模块只读不写；转发方法让「谁画线」可以继续演进而不牵动调用方。[br]
## [br][b]迷雾位置列表在调用点现取[/b]（不缓存）：它的口径与挖孔同源
## （[method NodeGraphLayout.fogged_positions] 用的是同一份六态），缓存出第二份
## 就会分叉——那种分叉的表现是「线比雾亮一格」，肉眼几乎看不出来。
func _draw_edges() -> void:
	EdgePainter.draw_edges(self, _fogged_positions())


## 悬停 tooltip 绘制（AC-10）——内容组装与盒子绘制委托 [NodeGraphTooltipPainter]
## （与节点绘制分开一层：两者共用 [NodeStateLogic.tooltip_text] 的口径，但一个每帧画满
## 整图、一个只在鼠标停住时画一次）。
func _draw_hover_tooltip(node_id: int) -> void:
	Tooltip.draw_hover_tooltip(self, node_id)


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


## 地面层绘制——整块地图插画 + 压暗 + 暗角 + 迷雾遮罩（见 [NodeGraphGroundLayer]）。[br]
## [br][b]铺的矩形 = 可视区域[/b]（[method visible_local_rect]），不是内容包围盒。[br]
## [br][b]★ 两个矩形不同源 ★[/b]（第二轮地图化）：地形按[b]可视区域[/b]铺（地图铺满
## 整块画布、左右不再有黑带），迷雾按[b]内容包围盒[/b]铺（雾只压还没走到的那片山域）。
## 把迷雾也铺满视口会得到「除已揭示节点周围一小圈之外全屏皆雾」——开局只揭示 5 个
## 节点，整幅图会压成一片近黑。两个矩形的分工与读数见
## [constant NodeGraphStyle.FOG_MARGIN] 的注记。[br]
## [br][b]顺序语义[/b]：地面在连线[b]之下[/b]——遮罩压暗的是它盖住的连线，而孔里
## 露出的地形是亮的；节点再画在其上（见 [method _draw]）。
func _draw_ground() -> void:
	_ground.call(&"draw", self, visible_local_rect(), _content_rect, map_id,
			_fogged_positions().is_empty(), _revealed_positions())


## 当前[b]可视区域[/b]（渲染器局部坐标）——地形与迷雾的铺满矩形。[br]
## [br][b]换算[/b]：屏幕坐标 = 局部坐标 × zoom + offset（见 [NodeGraphViewport] 的
## 变换口径），故局部可视矩形 = [code](-offset / zoom, size / zoom)[/code]——
## 渲染器由 [code]PRESET_FULL_RECT[/code] 铺满视口，[member size] 就是视口尺寸。[br]
## [br][b]为什么由渲染器自己推[/b]：变换的两半（[code]zoom[/code]/[code]offset[/code]）
## 分别住在视口上，[member scale] 与 [member position] 是它们的写入结果——从自己的
## 变换反推可视区域，就不必给「谁把矩形传进来」再开一条跨模块的参数通道。[br]
## [br][b]退化保护[/b]：缩放为 0（进树前 / 折叠视口）时返回 [Rect2]，调用方据此跳过
## 绘制，免得除零炸出一片 NaN 顶点。[br]
## [br][b]返回[/b]：可视区域（可能含负宽高之外的位置——位置本身可以为负，这正是
## 「画布比视口大」的正常情形）。
func visible_local_rect() -> Rect2:
	if scale.x <= 0.0 or scale.y <= 0.0:
		return Rect2()
	return Rect2(-position.x / scale.x, -position.y / scale.y,
			size.x / scale.x, size.y / scale.y)


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


## 迷雾覆盖多边形（带缓存——见 [member NodeGraphGroundLayer._fog_polygons]）。[br]
## [br][b]为什么把这个口子留在渲染器上[/b]：单测要按「同一份输入只算一次」断言缓存
## 生效（见 [code]test_fog_polygon_cache.gd[/code]）；实现体在 [NodeGraphGroundLayer]，
## 本方法是纯转发。
func fog_polygon_cache_size(p_area: Rect2) -> int:
	return (_ground.call(&"polygons_for", p_area, _revealed_positions()) as Array).size()
