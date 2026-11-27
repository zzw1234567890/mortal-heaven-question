extends RefCounted
## NodeGraphLayout —— 节点图的几何计算（位置 / 包围盒 / 迷雾集合，纯函数）。[br]
## [br][b]为什么单独成文件[/b]：[code]node_graph_renderer.gd[/code] 越过单文件
## 300 行软上限（coding-standards），而「每个节点摆在哪」「哪些格子在雾里」是
## 纯粹的坐标换算——输入快照、输出数组/字典，与绘制、输入、命中检测都不相交。[br]
## [br][b]纯函数，不持状态[/b]：本模块一个字段都没有，每次调用返回新结果——
## 渲染器自己持有 [code]_positions[/code] / [code]_content_rect[/code]，
## 本模块只负责算出来。[br]
## [br]来源: ADR-0031 §5、design/gdd/exploration-ui-system.md §2、
## exploration-ui Story 001 / 003。

## 六态样式查询（迷雾判定的口径来源）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")
## 视觉规格（间距常量——布局与绘制共用同一份，不各写一遍）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")


## 布局计算——layer 纵向、idx 横向居中、[b]层间蛇形错开[/b]。[br]
## [br][param p_nodes] 节点详情 [code]{node_id: {layer, idx}}[/code]。[br]
## [br][b]返回[/b]：[code]{node_id: Vector2}[/code]（节点中心坐标）；空输入返回空字典。[br]
## [br][b]第二轮地图化（横向铺开）[/b]：第一轮铺完实测内容包围盒 264×606、宽高比
## 0.44——五层摞起来仍是一根竖条，节点像串珠而不像「散落在地图上的一串地标」。
## 本轮把 [constant NodeGraphStyle.NODE_GAP] 拉到 200（横向）、
## [constant NodeGraphStyle.LAYER_GAP] 收到 104（纵向），并给每层加一个
## [method layer_stagger] 的水平错开——包围盒左右边界由不同层贡献，屏幕宽高比
## 实测 1.51（1920×1080）/ 1.28（1280×720），进到 16:9 那一档。[br]
## [br][b]零语义改动[/b]：本方法输出的是纯[b]视觉坐标[/b]——谁在谁的下一层（[code]layer[/code]）、
## 同层第几格（[code]idx[/code]）、行动力消耗、可达判定与 Boss 位置规则分别住在
## [code]exploration_dag_builder.gd[/code] / [code]node_state_logic.gd[/code] /
## [code]exploration_system.gd[/code]，谁都没读这里的坐标值。改间距与错开量
## 只改「画在哪、点在哪」，不改 DAG 本身。[br]
## [br][b]错开的量取负号放在 idx 上而不是加在 y 上[/b]：层序由 y 唯一表达
## （[code]layer * LAYER_GAP[/code]），错开只能动 x；动 y 会让两层挤到同一高度，
## 「下一层在下面」这个唯一的层序读法就没了。
static func compute_positions(p_nodes: Dictionary) -> Dictionary:
	var positions: Dictionary = {}
	if p_nodes.is_empty():
		return positions
	var layer_counts: Dictionary = {}
	for node_id: int in p_nodes.keys():
		var layer: int = int(p_nodes[node_id].get("layer", 0))
		layer_counts[layer] = int(layer_counts.get(layer, 0)) + 1
	for node_id: int in p_nodes.keys():
		var layer: int = int(p_nodes[node_id].get("layer", 0))
		var idx: int = int(p_nodes[node_id].get("idx", 0))
		var count: int = int(layer_counts.get(layer, 1))
		var row_width: float = (float(count) - 1.0) * Style.NODE_GAP
		positions[node_id] = Vector2(
				(row_width * 0.5) - (float(idx) * Style.NODE_GAP)
						+ layer_stagger(layer),
				float(layer) * Style.LAYER_GAP)
	return positions


## 层间水平错开量（px）——第 [param p_layer] 层整体左右平移的幅度。[br]
## [br][b]蛇形（左-右-左-右）而不是单调偏一侧[/b]：单调偏一侧会让整张图斜成一条
## 对角线，包围盒还是一根斜条；蛇形让相邻层反向走位，左右边界交替被撑开，
## 读起来也像「之字形往上爬的山路」而不是「被风吹歪的竖条」。[br]
## [br][b]第 0、1 层错开量为 0[/b]（本条是硬约束，不是取整巧合）：
## [code]test_node_graph_pick_region.gd[/code] 的几何前提是开局那两格以原点为轴
## 一左一右（101 落在正 x、102 落在负 x）——那是 [code]_has_point[/code] 拾取缺陷
## 的现场条件，两层任一被平移都可能把该前提抹平，让回归用例变成永远通过的空断言。
## [br][br][b]返回[/b]：该层的水平偏移（px，右为正）。
static func layer_stagger(p_layer: int) -> float:
	if p_layer <= 1:
		return 0.0
	var direction: float = 1.0 if (p_layer % 2) == 0 else -1.0
	return direction * Style.LAYER_STAGGER


## 内容包围盒——Viewport 整图适配的计算基准（各节点中心的并集外扩一个节点尺寸）。[br]
## [br][b]空输入返回空 [Rect2][/b]（渲染器据此走「无内容」分支）。
static func compute_content_rect(p_positions: Dictionary) -> Rect2:
	if p_positions.is_empty():
		return Rect2()
	var bounds := Rect2()
	var initialized: bool = false
	for pos: Vector2 in p_positions.values():
		if not initialized:
			bounds = Rect2(pos, Vector2.ZERO)
			initialized = true
		else:
			bounds = bounds.expand(pos)
	return bounds.grow(Style.NODE_SIZE)


## 拾取区域——控件自身矩形 ∪ 内容包围盒（两者取并，只增不减）。[br]
## [br][b]为什么必须有这一层[/b]：引擎 GUI 拾取对未覆写 [code]_has_point[/code] 的
## Control 走 [code]Rect2(Vector2.ZERO, size)[/code]——矩形[b]永远从局部原点起[/b]。
## 而 [method compute_positions] 把同层中点右侧的节点摆在[b]局部负 x[/b]，
## [code]NodeGraphViewport[/code] 又把渲染器整个缩放平移（本机实测
## [code]zoom = 1.5[/code] / [code]offset = (960, 316.5)[/code]）——渲染器自己的矩形
## 只覆盖屏幕右半边，负 x 的节点 [code]_draw[/code] 画得出来（溢出不受矩形约束）
## 却收不到事件，玩家看得见点不动。[br]
## [br][b]为什么并上自身矩形而不是只留内容[/b]：既有拾取范围里没有任何一点应当
## 变成不认领（收窄会把空画布上的边缘平移与悬停改道）；并集只增不减。[br]
## [br][b]为什么内容包围盒必定覆盖全部节点中心[/b]：[method compute_content_rect]
## 是各节点中心的并集再外扩一个节点尺寸，而节点命中框半宽最大只有
## [code]NODE_SIZE * 1.1 / 2[/code]——故本区域恒为节点命中框的超集。
static func pick_rect(p_size: Vector2, p_content: Rect2) -> Rect2:
	var own := Rect2(Vector2.ZERO, p_size)
	if p_content.size == Vector2.ZERO:
		return own
	return own.merge(p_content)


## 已揭示集合（legacy 口径）：已访问 + 当前节点 + 当前节点的邻接（前向 + 后向）。[br]
## [br][b]只是 legacy 近似[/b]：states 注入时迷雾以六态判定为准（见
## [method fogged_positions]），本集合只在未注入六态时被读。
static func revealed_set(p_graph: Dictionary, p_visited: Array,
		p_current_node: int) -> Array:
	var revealed: Array = p_visited.duplicate()
	if p_current_node >= 0 and not revealed.has(p_current_node):
		revealed.append(p_current_node)
	if p_graph.has(p_current_node):
		for to_id: int in p_graph[p_current_node]:
			if not revealed.has(to_id):
				revealed.append(to_id)
	for from_id: int in p_graph.keys():
		if p_graph[from_id].has(p_current_node) and not revealed.has(from_id):
			revealed.append(from_id)
	return revealed


## 节点是否被迷雾覆盖（legacy 近似——见 [method revealed_set]）。
static func is_fogged(p_graph: Dictionary, p_visited: Array, p_current_node: int,
		p_node_id: int) -> bool:
	return not revealed_set(p_graph, p_visited, p_current_node).has(p_node_id)


## 迷雾覆盖的节点位置列表（AC-3 采样用——迷雾节点计数）。[br]
## [br]states 注入时以六态 FOGGED 为准（与 [NodeStateLogic] 判定一致）；否则 legacy 近似。[br]
## [br][b]只列有坐标的节点[/b]：布局尚未跑过（[param p_positions] 为空）时不给位置，
## 免得调用方拿到一堆 [constant Vector2.ZERO] 在原点堆成一坨。
static func fogged_positions(p_graph: Dictionary, p_nodes: Dictionary,
		p_positions: Dictionary, p_states: Dictionary, p_visited: Array,
		p_current_node: int) -> Array:
	var result: Array = []
	if not p_states.is_empty():
		for node_id: int in p_nodes.keys():
			if int(p_states.get(node_id, NodeStateLogicScript.NodeState.FOGGED)) \
					!= NodeStateLogicScript.NodeState.FOGGED:
				continue
			if p_positions.has(node_id):
				result.append(p_positions[node_id])
		return result
	var revealed: Array = revealed_set(p_graph, p_visited, p_current_node)
	for node_id: int in p_nodes.keys():
		if revealed.has(node_id):
			continue
		if p_positions.has(node_id):
			result.append(p_positions[node_id])
	return result


## 已揭示节点位置列表（迷雾挖孔位置）。[br]
## [br]states 注入时挖孔 = 全部非迷雾节点；否则 legacy 已揭示集合（口径同
## [method fogged_positions]，两者互补——同一份判定不会一半说亮一半说暗）。
static func revealed_positions(p_graph: Dictionary, p_nodes: Dictionary,
		p_positions: Dictionary, p_states: Dictionary, p_visited: Array,
		p_current_node: int) -> Array:
	var result: Array = []
	if not p_states.is_empty():
		for node_id: int in p_nodes.keys():
			if int(p_states.get(node_id, NodeStateLogicScript.NodeState.FOGGED)) \
					== NodeStateLogicScript.NodeState.FOGGED:
				continue
			if p_positions.has(node_id):
				result.append(p_positions[node_id])
		return result
	var revealed: Array = revealed_set(p_graph, p_visited, p_current_node)
	for node_id: int in revealed:
		if p_positions.has(node_id):
			result.append(p_positions[node_id])
	return result


## 节点是否已显现——逐层展开浮现（AC-1）：超过 [param p_reveal_max_layer] 的层
## 未绘制（负值 = 全部显现）。[br]
## [br][b]命中检测复用同一判定[/b]：未绘制的节点不该可点（可见性与可点性同源）。
static func is_layer_revealed(p_nodes: Dictionary, p_reveal_max_layer: int,
		p_node_id: int) -> bool:
	if p_reveal_max_layer < 0:
		return true
	var layer: int = int(p_nodes.get(p_node_id, {}).get("layer", 0))
	return layer <= p_reveal_max_layer


## 迷雾覆盖区多边形——[b]内容矩形挖掉已揭示圆孔[/b]后的剩余面（可能多块）。[br]
## [br][b]为什么不再「画一块矩形 + 用底色圆盖回去」[/b]：那套做法要求挖孔色等于
## 画布底色，而画布现在是[b]地图插画[/b]——底色圆会在插画上糊出一圈纯色圆盘，
## 每个已揭示节点都像贴了一块补丁（1920×1080 取证图里一眼可见）。真正的挖孔只能
## 靠多边形裁剪：遮罩面本身不带孔，孔里露出的就是下面的地形。[br]
## [br][b]为什么放纯函数模块[/b]：这是一次几何换算（同 [method compute_positions]），
## 输入矩形 + 圆心列表、输出顶点表，不持状态；渲染器负责缓存与失效（见
## [code]NodeGraphGroundLayer._fog_layers[/code]）。[br]
## [br][b]为什么缓存是必需的[/b]：[method Geometry2D.clip_polygons] 是 O(孔数 × 块数)
## 的逐孔裁剪（实测 24 孔 × 20 边形 ≈ 1.2ms），每帧重算会吃掉帧预算的十分之一；
## 而它只在「已揭示集合变了」时才需要重算。[br]
## [br][param p_rect] 内容矩形（遮罩铺满的范围）。[br]
## [param p_revealed] 已揭示节点位置列表（圆心）。[br]
## [param p_radius] 挖孔半径。[br]
## [param p_segments] 圆的边数（20 = 在 60px 半径下已看不出多边形状）。[br]
## [br][b]返回[/b]：多边形数组（每块 ≥ 3 顶点）；[param p_revealed] 为空时是
## 整块矩形本身。
static func fog_polygons(p_rect: Rect2, p_revealed: Array, p_radius: float,
		p_segments: int = 20) -> Array:
	var pieces: Array = [rect_polygon(p_rect)]
	for center: Vector2 in p_revealed:
		var hole: PackedVector2Array = circle_polygon(center, p_radius, p_segments)
		var next: Array = []
		for piece: PackedVector2Array in pieces:
			for remainder: PackedVector2Array in Geometry2D.clip_polygons(piece, hole):
				if remainder.size() >= 3:
					next.append(remainder)
		pieces = next
		if pieces.is_empty():
			break  # 整张图都揭开了——后面没有可裁的东西
	return pieces


## 迷雾[b]柔边分层[/b]——同一块遮罩按「向内缩进」切成若干层，由外向内逐层叠加，
## 叠出来的就是一条从 0 渐升到满浓度的羽化带（本轮：矩形硬边改柔边）。[br]
## [br][b]★ 为什么是「逐层内缩」而不是给顶点刷渐变色 ★[/b]：[code]canvas_item_add_triangle_array[/code]
## 确实接受每顶点一个颜色，但渐变的[b]方向[/b]得逐顶点算出「离边界多远」——而遮罩是
## 「矩形减 24 个圆孔」裁剪出来的，同一块多边形上同时挨着矩形边和孔边，顶点法线方向
## 不一致，刷出来会在孔边出现折角。逐层内缩把这个问题交给几何本身：每层都是同一种
## 「矩形减孔 + 缩进」，孔边与矩形边[b]自动同一条带[/b]。[br]
## [br][b]第 i 层（i = 1..steps）[/b]：矩形四边各内缩 [code]带 / steps × i[/code]、每个
## 孔的半径[b]外扩[/b]同量。于是最外一层（i=1）是一条镶在边界内侧的窄框，最深一层
## （i=steps）只在「离边界 ≥ 整条带」的地方还有面。某点被覆盖的层数 = 它到最近边界的
## 深度，浓度随深度单调上升。[br]
## [br][b]孔边为什么也一起羽化[/b]：孔边同样是硬边（「已揭示区域」与雾的交界）。任务书
## 只点了矩形四条边，但同一条带顺手把孔边也磨掉——两处硬边同源，分两套做法迟早分叉。[br]
## [br][b]矩形边与孔边会互相干扰吗[/b]：不会。窄图（矩形边之间的距离小于两条带）上两
## 侧的带子在中间相遇，那只意味着「这张图大部分在雾里」——正是该有的读法。[br]
## [br][param p_band] 羽化带宽（局部 px）——由调用方按观感常量传入，本函数只做几何。[br]
## [param p_steps] 层数（≥ 1；0 或负按 1 处理，即退回单层满浓度）。[br]
## [br][b]返回[/b]：层数组，[b]由外向内[/b]排列（第 0 层最靠外、浓度最浅）；每层是
## 多边形数组（可能为空——该层被孔啃光了）。整块都揭开时返回空数组。
static func fog_feather_layers(p_rect: Rect2, p_revealed: Array, p_radius: float,
		p_band: float, p_steps: int, p_segments: int = 20) -> Array:
	var steps: int = maxi(p_steps, 1)
	# 带子不能比图还宽——否则雾永远升不到满浓度（等于把雾取消了）。
	var room: float = minf(p_rect.size.x, p_rect.size.y) * 0.25
	var band: float = maxf(minf(p_band, room), 0.0)
	var layers: Array = []
	for i: int in range(1, steps + 1):
		var inset: float = band * float(i) / float(steps)
		var inner: Rect2 = p_rect.grow(-inset)
		if inner.size.x <= 0.0 or inner.size.y <= 0.0:
			break  # 再往里缩就没有面了——后面的层自然也是空的
		# 孔半径随缩进同步外扩：孔边与矩形边处在同一条羽化带上（见函数注记）。
		layers.append(fog_polygons(inner, p_revealed, p_radius + inset, p_segments))
	return layers



## 矩形的多边形顶点（顺时针，4 点）。
static func rect_polygon(p_rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		p_rect.position,
		p_rect.position + Vector2(p_rect.size.x, 0.0),
		p_rect.position + p_rect.size,
		p_rect.position + Vector2(0.0, p_rect.size.y),
	])


## 圆的多边形近似顶点（[param p_segments] 边形）。
static func circle_polygon(p_center: Vector2, p_radius: float,
		p_segments: int = 20) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in maxi(p_segments, 3):
		var angle: float = TAU * float(i) / float(maxi(p_segments, 3))
		points.append(p_center + Vector2(cos(angle), sin(angle)) * p_radius)
	return points
