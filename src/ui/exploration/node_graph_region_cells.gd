extends RefCounted
## NodeGraphRegionCells —— 节点图的[b]地区分块[/b]（Voronoi 暴力半平面裁剪，纯函数）。[br]
## [br][b]为什么需要它[/b]（本轮反馈原话「我想要一个节点一块地区，鼠标移上去都能高亮
## 有交互的那种」「现在这个看起来还是太简陋了」）：节点此前是[b]一个小方块图标[/b]浮在
## 地图上，能交互的只有那 56×56 的一块。老板要的是[b]势力范围[/b]——每个节点占据地图上
## 一整片地，鼠标移到那片地里的任何一处，那片地整体亮起来。[br]
## [br][b]★ 为什么是 Voronoi ★[/b]：分块规则必须满足两条互相牵制的性质——[br]
##   1. [b]铺满[/b]：所有块合起来正好是地图可视矩形，块与块之间不留缝（留缝就成了
##      「一堆多边形贴纸」，正是要消灭的观感）；[br]
##   2. [b]归谁明确[/b]：任意一点属于「离它最近的那个节点」，这样「鼠标在哪块地」
##      与「哪块地该亮」不会有第二种答案。[br]
## Voronoi 图（以节点坐标为种子）恰好是唯一同时满足这两条的划分。[br]
## [br][b]★ 暴力半平面裁剪，不上 Delaunay ★[/b]：种子只有 8~15 个，每个种子的单元 =
## 「矩形」被其余每个种子的[b]垂直平分线[/b]依次裁掉一半（Sutherland–Hodgman 逐边
## 裁剪，O(n²)），15 个种子下是 15×14 = 210 次裁剪、每次几十个顶点——一次布局只算
## 一次（缓存在渲染器上），完全不必引入 Delaunay 三角剖分及其退化情形处理。[br]
## [br][b]确定性[/b]（硬要求，单测逐顶点断言）：同输入必然同输出——不掷骰子、不遍历
## 哈希表键序（[method compute_cell_map] 先排键）。[br]
## [br][b]退化策略[/b]（注释写清，见 [method _clip_by_bisector]）：两个种子坐标完全重合
## 时垂直平分线无定义——取[b]索引小者全取该区域、索引大者判空[/b]，保证「合起来铺满」
## 这条性质不被破坏，且结果与遍历顺序无关之外的确定性成立（索引是输入序）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块一个字段都没有，纯几何换算——与
## [code]node_graph_layout.gd[/code] 同一条「输入快照、输出几何」的口径。[br]
## [br]来源: 本轮任务书任务一（地区生成：Voronoi 纯函数、可测）、
## ADR-0031 §2/§5、design/gdd/exploration-ui-system.md §2。

## 坐标重合判定阈值（平方）——小于它就当作同一个种子（见类文档的退化策略）。
## [br][b]为什么用平方[/b]：省掉开方（同 [code]node_icon_art.gd[/code] 的圆掩膜口径）。
const TIE_EPS_SQ: float = 0.0001


## 全部地区多边形——与 [param p_seeds] [b]同序[/b]（第 i 块 = 第 i 个种子的地盘）。[br]
## [br][param p_seeds] 种子坐标（节点中心）。[br]
## [param p_bounds] 可切片的矩形（地区铺满它）。[br]
## [br][b]返回[/b]：多边形数组；空输入 / 空矩形返回空数组（调用方据此跳过绘制），
## 退化到零面积的块也会给出一条（可能为空的）[PackedVector2Array]，[b]长度恒等于
## 种子数[/b]——调用方按索引取用时不必先查长度。[br]
## [br][b]每块都是凸的[/b]：起点是矩形（凸），半平面裁剪保持凸性——这条性质是单测
## 的第一条断言，也是绘制侧「可以用三角扇」的前提。
static func compute_cells(p_seeds: Array, p_bounds: Rect2) -> Array:
	var cells: Array = []
	if p_seeds.is_empty() or p_bounds.size.x <= 0.0 or p_bounds.size.y <= 0.0:
		return cells
	var count: int = p_seeds.size()
	for i: int in count:
		var poly: PackedVector2Array = rect_polygon(p_bounds)
		for j: int in count:
			if j == i:
				continue
			poly = _clip_by_bisector(poly, p_seeds[i], p_seeds[j], i > j)
			if poly.is_empty():
				break  # 已被裁空——后面的种子再裁也还是空
		cells.append(poly)
	return cells


## 地区多边形映射——[code]{节点 ID: 多边形}[/code]。[br]
## [br][b]为什么单开一个入口[/b]：绘制与命中检测都按节点 ID 取块，而
## [method compute_cells] 只能给「同序数组」。[br]
## [br][b]键序稳定[/b]：先对节点 ID 排序再取种子——字典键序在 GDScript 里是实现细节，
## 直接遍历会让「同输入同输出」这条确定性承诺落空（单测第 4 条正是断言它）。[br]
## [br][b]返回[/b]：空输入返回空字典。
static func compute_cell_map(p_positions: Dictionary, p_bounds: Rect2) -> Dictionary:
	var result: Dictionary = {}
	if p_positions.is_empty():
		return result
	var ids: Array = p_positions.keys()
	ids.sort()
	var seeds: Array = []
	for node_id: int in ids:
		seeds.append(p_positions[node_id])
	var cells: Array = compute_cells(seeds, p_bounds)
	for i: int in ids.size():
		result[int(ids[i])] = cells[i]
	return result


## 点落在哪个地区——[b]最近的种子[/b]（[param p_point] 在 [param p_bounds] 内时
## 等同「包含该点的多边形索引」，两条口径由单测第三条锁定同源）。[br]
## [br][b]平局取较小索引[/b]：两点等距（正落在垂直平分线上）时按输入序取前者——
## 确定性优先于「更公平」（后者在几何上没有定义）。[br]
## [br][b]返回[/b]：种子索引；空输入返回 -1。[br]
## [br][b]为什么命中检测走它而不是逐块 [method Geometry2D.is_point_in_polygon][/b]：
## 多边形在平分线上是「两边都包含」（Sutherland–Hodgman 保留边界点），逐块判定会
## 撞出两个命中；最近种子法天然唯一，且代价只有 n 次距离比较。
static func nearest_seed_index(p_seeds: Array, p_point: Vector2) -> int:
	var best: int = -1
	var best_dist: float = INF
	for i: int in p_seeds.size():
		var dist: float = (p_seeds[i] as Vector2).distance_squared_to(p_point)
		if dist < best_dist:
			best_dist = dist
			best = i
	return best


## 多边形面积（绝对值——鞋带公式）。[br]
## [br][b]为什么取绝对值[/b]：顶点序（顺/逆时针）由裁剪过程决定，语义上不该影响面积；
## 单测第二条「面积总和 = 矩形面积」靠它。
static func polygon_area(p_points: PackedVector2Array) -> float:
	var n: int = p_points.size()
	if n < 3:
		return 0.0
	var twice: float = 0.0
	for i: int in n:
		var a: Vector2 = p_points[i]
		var b: Vector2 = p_points[(i + 1) % n]
		twice += a.x * b.y - b.x * a.y
	return absf(twice) * 0.5


## 多边形是否凸（允许共线）。[br]
## [br][b]返回[/b]：全部叉积同号（或为零）→ true；顶点数 < 4 恒为 true（三角形与
## 退化情形都算凸）。[br]
## [br][b]为什么要这条断言[/b]：绘制侧按凸多边形铺色（三角扇），凹块会画成一团乱线——
## 本函数是「凸性」这条前提的机器可验形式。
static func is_convex(p_points: PackedVector2Array) -> bool:
	var n: int = p_points.size()
	if n < 4:
		return true
	var sign_seen: int = 0
	for i: int in n:
		var a: Vector2 = p_points[i]
		var b: Vector2 = p_points[(i + 1) % n]
		var c: Vector2 = p_points[(i + 2) % n]
		var cross: float = (b - a).cross(c - b)
		if is_zero_approx(cross):
			continue
		var s: int = 1 if cross > 0.0 else -1
		if sign_seen == 0:
			sign_seen = s
		elif s != sign_seen:
			return false
	return true


## 矩形的多边形顶点（顺时针，4 点）——与 [code]node_graph_layout.gd[/code] 的同名
## 函数形状一致（那边给迷雾裁剪用，这里给分块起点用）。[br]
## [br][b]为什么不互相引用[/b]：两处都只有四行且都是「矩形 → 顶点表」的直译，
## 跨模块引用会把「分块」与「迷雾」两件事绑在一起；单测各自钉形状即可。
static func rect_polygon(p_rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		p_rect.position,
		p_rect.position + Vector2(p_rect.size.x, 0.0),
		p_rect.position + p_rect.size,
		p_rect.position + Vector2(0.0, p_rect.size.y),
	])


## 用「本种子 vs 另一种子」的垂直平分线裁掉不属于本种子的一半。[br]
## [br][b]保留侧[/b]：靠本种子那一侧，即 [code](p - mid) · (other - self) <= 0[/code]
## ——法线指向另一种子，靠本种子的一侧就是法线的反向。[br]
## [br][b]退化（两种子重合）[/b]：法线为零向量，平分线无定义。稳定策略见类文档——
## [param p_self_is_later] 为真（本块索引更大）时判空，否则原样返回（本块全取）。[br]
## [br][param p_self_is_later] 本种子在输入序里是否排在 [param p_other] 之后。
static func _clip_by_bisector(p_poly: PackedVector2Array, p_self: Vector2,
		p_other: Vector2, p_self_is_later: bool) -> PackedVector2Array:
	var normal: Vector2 = p_other - p_self
	if normal.length_squared() <= TIE_EPS_SQ:
		return PackedVector2Array() if p_self_is_later else p_poly
	# grow(0.0) 无关——此处只是取中点，写成显式表达式避免读者以为有容差
	var mid: Vector2 = (p_self + p_other) * 0.5
	return _clip_half_plane(p_poly, mid, normal)


## Sutherland–Hodgman 半平面裁剪——保留 [code](p - p_mid) · p_normal <= 0[/code] 的
## 那一侧。[br]
## [br][b]为什么 <= 而不是 <[/b]：边界点必须落在块内，否则相邻块之间会露出一条零宽
## 的缝（栅格化时按像素可见）。代价是平分线上的点被两块同时「包含」——命中检测因此
## 不走逐块判定（见 [method nearest_seed_index]）。[br]
## [br][b]交点用线性插值求[/b]：符号变化的那条边上，零点参数
## [code]t = d_cur / (d_cur - d_nxt)[/code]，分母恒非零（两个 d 异号）。[br]
## [br][b]返回[/b]：裁剪后的凸多边形（可能为空）。
static func _clip_half_plane(p_poly: PackedVector2Array, p_mid: Vector2,
		p_normal: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = p_poly.size()
	if n == 0:
		return out
	for i: int in n:
		var cur: Vector2 = p_poly[i]
		var nxt: Vector2 = p_poly[(i + 1) % n]
		var d_cur: float = (cur - p_mid).dot(p_normal)
		var d_nxt: float = (nxt - p_mid).dot(p_normal)
		if d_cur <= 0.0:
			out.append(cur)
		if (d_cur < 0.0 and d_nxt > 0.0) or (d_cur > 0.0 and d_nxt < 0.0):
			out.append(cur.lerp(nxt, d_cur / (d_cur - d_nxt)))
	return out
