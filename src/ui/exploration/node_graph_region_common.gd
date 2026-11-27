extends RefCounted
## NodeGraphRegionCommon —— 地区层的[b]共享读写口[/b]：分块表、可见集合、六态视觉。[br]
##
## [b]为什么单独一份[/b]：地区要画三笔（底渍 → 墨边 → 地名纸条），三笔分别在三个文件里
## （单文件 300 行软上限，coding-standards），但它们必须回答[b]同一份[/b]「这块地算不算
## 可见」「这块地是什么态」——各写一遍就会出现「底渍按可达画、墨边按不可达画」这种
## 自相矛盾的块，而这类矛盾在 1080p 的截图里一眼可见、在单测里抓不到。[br]
##
## [br][b]为什么不放在 [NodeGraphStyleRegion] 里[/b]：那份是[b]纯数据[/b]规格表
## （常量 + 六态→面视觉映射），一个字段都不读宿主；本文件全部方法都读宿主快照。
## 两者混在一处，规格表就再也没法被「不建节点树」的单测直调。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：宿主（渲染器）经参数传入，只[b]读[/b]
## 它的渲染输入快照并把结果返回；本模块一个字段都没有。[br]
##
## [br]来源: ADR-0031 §2/§5、本轮任务书任务二（地区怎么画）。

## 地区视觉规格（六态→面视觉映射表）。
const RegionStyle := preload("res://src/ui/exploration/node_graph_style_region.gd")
## 六态枚举（映射表按它取键）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")
## Voronoi 分块纯函数模块（暴力半裁剪——见其模块文档）。
const CellsScript := preload("res://src/ui/exploration/node_graph_region_cells.gd")
## 布局判定（逐层显现——与命中检测同源）。
const LayoutScript := preload("res://src/ui/exploration/node_graph_layout.gd")


## 地区分块表（[code]{node_id: PackedVector2Array}[/code]）——绘制前算一次。[br]
## [br][b]为什么由调用方（渲染器）持有结果而不在这里缓存[/b]：同一份分块被[b]三处[/b]读
## ——绘制、命中检测、内容包围盒（地区要铺满可视范围）。三处各算一次就是三次
## O(n²) 裁剪，且三份结果一旦因为输入微差而不同，立刻出现「画在这块地、点那块地」。[br]
## [br][param p_bounds] 分块要铺满的矩形（内容矩形外扩一圈，见 [method bounds_for]）。
static func cells_of_nodes(p_positions: Dictionary, p_bounds: Rect2) -> Dictionary:
	return CellsScript.compute_cell_map(p_positions, p_bounds)


## 地区铺满的矩形——内容包围盒外扩 [constant RegionStyle.BOUNDS_GROW]。[br]
## [br][b]为什么外扩量收在视觉规格里而公式收在这里[/b]：外扩量是观感旋钮（改它只影响
## 「地图铺得多远」），而「分块铺满哪块矩形」是几何口径——命中检测必须用[b]同一个[/b]
## 矩形，否则会出现「画出来的边界之外还能点到地」这种说不清的空白。[br]
## [br][b]空内容返回空矩形[/b]：调用方据此跳过绘制与命中（没有任何节点就没有地区）。
static func bounds_for(p_content_rect: Rect2) -> Rect2:
	if p_content_rect.size == Vector2.ZERO:
		return Rect2()
	return p_content_rect.grow(RegionStyle.BOUNDS_GROW)


## 参与绘制的地区 ID（未显现的层不画——逐层浮现；命中检测复用同一份过滤）。[br]
## [br][b]为什么按层过滤而不是按迷雾过滤[/b]：迷雾地区[b]要画[/b]（玩家得看到「那边
## 还有一片没走到的地」），只是被压暗；逐层浮现是「动画还没轮到这一层」，那才是不画。[br]
## [br][b]为什么排序[/b]：块之间的叠压关系不该随字典键序变——同一份输入必须画出
## 同一张图（否则缓存的作废判据会一直谎报「变了」）。
static func visible_ids(p_host: Control, p_cells: Dictionary) -> Array:
	var out: Array = []
	var nodes: Dictionary = p_host.get(&"nodes")
	var reveal: int = int(p_host.get(&"reveal_max_layer"))
	for node_id: int in p_cells.keys():
		if LayoutScript.is_layer_revealed(nodes, reveal, node_id):
			out.append(node_id)
	out.sort()
	return out


## 该节点地区的六态视觉（映射表在 [NodeGraphStyleRegion.region_visual]）。[br]
## [br][b]为什么三笔都经这里读[/b]：底渍 / 边 / 印记读的是同一份映射，取值入口只有
## 一个，改动口径时三笔一起动（见本文件类文档）。[br]
## [br][b]六态未注入时[/b]（legacy 分支 / 单测只给节点不给 states）按「已揭示的普通
## 地区」画：不压暗、不虚边、无印记——这是「没有信息就别编信息」的那一档。[br]
## [br][param p_node_id] 节点 ID；[b]返回[/b] 视觉键值字典（键见映射表）。
static func visual_of(p_host: Control, p_node_id: int) -> Dictionary:
	var states: Dictionary = p_host.get(&"states")
	if not states.has(p_node_id):
		return RegionStyle.region_visual(NodeStateLogicScript.NodeState.REACHABLE)
	return RegionStyle.region_visual(int(states[p_node_id]))


## 该地区是否正处于悬停 / 焦点高亮——[b]键盘焦点与鼠标悬停走同一条路[/b]。[br]
## [br][b]为什么转发宿主的 [code]is_node_highlighted[/code] 而不是自己判两个字段[/b]：
## 焦点与悬停的优先级（悬停优先、松开悬停回落到焦点）是宿主的判定，绘制侧各判一次
## 就会与宿主的判定漂移——「键盘选中的那块没亮」正是这种漂移的典型症状。
static func highlighted(p_host: Control, p_node_id: int) -> bool:
	return bool(p_host.call(&"is_node_highlighted", p_node_id))


## 点落在哪个[b]地区[/b]——[code]point-in-polygon[/code] 的最近种子实现。[br]
## [br][b]★ 为什么命中检测走最近种子而不是逐块 [method Geometry2D.is_point_in_polygon] ★[/b]：
## 分块裁剪时保留了边界点（见 [method NodeGraphRegionCells._clip_half_plane] 的注记），
## 于是垂直平分线上的点被[b]相邻两块同时包含[/b]——逐块判定会撞出两个命中，而「哪块地
## 该亮」只能有一个答案。最近种子法天然唯一，代价只有 n 次距离比较。[br]
## [br][b]为什么还要判 [param p_bounds][/b]：最近种子在整张平面上都有定义（哪怕点在
## 十万八千里外），而地区只铺到 [method bounds_for] 给的矩形为止——不判的话，
## 「画布上留白的地方」也会认领一个地区，画布拖拽就再也收不到事件了。[br]
## [br][b]与旧 [code]pick_rect[/code] 的关系（迁移注记）[/b]：旧口径是「点是否落在
## 渲染器矩形 ∪ 内容包围盒内」——一个粗粒度的[b]拾取范围[/b]判定，回答「这个控件要不要
## 认领这个事件」。新口径回答的是另一件事：「这个点属于哪个节点的地区」。两者[b]并存[/b]：
## 节流范围（[code]_has_point[/code]）仍按矩形判（否则画布留白处不能拖动），
## 而「点到哪个节点」改按这里判——于是鼠标移到一块地区的[b]任何一处[/b]都能选中该节点，
## 不再要求精确点中那 56px 的圆印。[br]
## [br][param p_positions] 节点坐标表 [code]{node_id: Vector2}[/code]。[br]
## [param p_point] 待判点（渲染器局部坐标）。[br]
## [param p_bounds] 地区铺满的矩形（[method bounds_for] 的结果）。[br]
## [br][b]返回[/b]：节点 ID；无坐标表 / 点在矩形外返回 -1。[br]
## [br][b]键序稳定[/b]：按节点 ID 排序后取最近——平局时取较小 ID（与
## [method NodeGraphRegionCells.nearest_seed_index] 的「平局取较小索引」同一条口径，
## 只把「索引」换成「节点 ID」，因为节点 ID 才是对外的稳定标识）。
static func node_at(p_positions: Dictionary, p_point: Vector2, p_bounds: Rect2) -> int:
	if p_positions.is_empty() or p_bounds.size == Vector2.ZERO:
		return -1
	if not p_bounds.has_point(p_point):
		return -1
	var best_id: int = -1
	var best_dist: float = INF
	for raw_id: Variant in p_positions.keys():
		var node_id: int = int(raw_id)
		var dist: float = (p_positions[raw_id] as Vector2).distance_squared_to(p_point)
		if dist < best_dist or (is_equal_approx(dist, best_dist) and node_id < best_id):
			best_dist = dist
			best_id = node_id
	return best_id
