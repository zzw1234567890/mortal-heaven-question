extends GutTest
## 节点图「地区分块」单元测试（Voronoi 纯函数——本轮任务书任务一）。[br]
## [br][b]四条硬断言[/b]（任务书逐条点名）：[br]
##   1. 每块多边形顶点数 ≥ 3 且是[b]凸的[/b]；[br]
##   2. 面积总和 = 矩形面积（误差 < 0.5%）；[br]
##   3. 任意两两种子的「归属」判定与多边形一致（200 个采样点逐点断言
##      「最近种子」=「包含该点的多边形索引」）；[br]
##   4. 同输入两次结果[b]逐顶点相等[/b]（确定性）。[br]
## [br][b]为什么这四条足够[/b]：它们正好钉住「铺满」「归谁明确」「能画（凸）」
## 「可复现」四件事——而这四件就是 Voronoi 分块的全部用途（底色铺满、悬停命中、
## 三角扇绘制、缓存指纹）。任何一条松了，对应的可见缺陷是：露缝、悬停高亮错块、
## 画成乱线、缩放平移时闪变。[br]
## [br]来源: 本轮任务书任务一（地区生成：Voronoi 纯函数、可测）、
## ADR-0031 §2（零状态所有权）、design/gdd/exploration-ui-system.md §2。

const Cells := preload("res://src/ui/exploration/node_graph_region_cells.gd")

## 采样点数量（任务书点名 200）。
const SAMPLE_COUNT: int = 200
## 采样用的固定种子——[b]测试可掷骰子，被测模块不行[/b]（模块侧不许随机，
## 这里用固定种子是为了让失败可复现：同一个种子永远同一批采样点）。
const SAMPLE_SEED: int = 20261127
## 边界点容差（px）——落在垂直平分线上的点被两块同时「包含」，见断言三。
const BOUNDARY_EPS: float = 0.001


## 造一组互不重合的种子（8 个——任务书区间 8~15 的下限）。
func _seeds() -> Array:
	return [
		Vector2(0.0, 0.0), Vector2(200.0, 20.0), Vector2(-200.0, -30.0),
		Vector2(40.0, 104.0), Vector2(-160.0, 130.0), Vector2(230.0, 140.0),
		Vector2(0.0, 208.0), Vector2(120.0, 300.0),
	]


## 测试用矩形——刻意用「非正方形 + 非原点起」的框，免得原点起点的巧合掩盖换算错误。
func _bounds() -> Rect2:
	return Rect2(Vector2(-300.0, -120.0), Vector2(640.0, 520.0))


# ═══════════════════════════════════════════════════════════════════════════════
# 一、每块 ≥3 顶点且凸（绘制侧「三角扇铺色」的前提）
# ═══════════════════════════════════════════════════════════════════════════════

## 全部地区块都是顶点数 ≥ 3 的凸多边形。[br]
## [b]为什么凸性必须机器可验[/b]：绘制按三角扇连点，凹块会连出跨区的三角形——
## 肉眼看到的是「一块地区的颜色涂到隔壁去了」，而源头是几何而非配色。
func test_every_cell_is_a_convex_polygon_with_at_least_three_vertices() -> void:
	# Act
	var cells: Array = Cells.compute_cells(_seeds(), _bounds())
	# Assert
	assert_eq(cells.size(), _seeds().size(), "块数应等于种子数（含退化块——长度恒定）")
	for i: int in cells.size():
		var poly: PackedVector2Array = cells[i]
		assert_true(poly.size() >= 3, "第 %d 块应有 ≥3 个顶点（实测 %d）" % [i, poly.size()])
		assert_true(Cells.is_convex(poly), "第 %d 块应是凸的（三角扇绘制前提）" % i)


## 凸性判定本身可信——正方形凸、凹四边形不凸（防「恒返回 true」的假通过）。
func test_convexity_check_rejects_a_concave_quad() -> void:
	# Arrange——一个箭头形（凹）
	var concave := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(100.0, 0.0), Vector2(50.0, 40.0),
		Vector2(100.0, 100.0), Vector2(0.0, 100.0),
	])
	# Assert
	assert_true(Cells.is_convex(Cells.rect_polygon(Rect2(0.0, 0.0, 10.0, 10.0))),
			"矩形应判凸")
	assert_false(Cells.is_convex(concave), "凹多边形必须被判出来（否则上面那条是空断言）")


# ═══════════════════════════════════════════════════════════════════════════════
# 二、面积总和 = 矩形面积（「铺满」——不留缝）
# ═══════════════════════════════════════════════════════════════════════════════

## 全部地区块面积之和等于矩形面积（误差 < 0.5%）。[br]
## [b]这条守的是「不留缝」[/b]：块与块之间只要露一条缝，玩家就会在缝里看到底色，
## 读到「一堆多边形贴纸」——正是本轮要消灭的观感。
func test_cell_areas_sum_to_the_bounds_area() -> void:
	# Arrange
	var bounds: Rect2 = _bounds()
	var target: float = bounds.size.x * bounds.size.y
	# Act
	var cells: Array = Cells.compute_cells(_seeds(), bounds)
	var total: float = 0.0
	for poly: PackedVector2Array in cells:
		total += Cells.polygon_area(poly)
	# Assert
	var drift: float = absf(total - target) / target
	assert_lt(drift, 0.005, "面积总和应等于矩形面积（实测偏差 %.4f%%）" % (drift * 100.0))


## 单块面积不为零、也不等于整块矩形（防「一块吃掉全部 / 全是空块」两种假通过）。
func test_cells_are_a_real_partition_not_a_single_blob() -> void:
	# Arrange
	var bounds: Rect2 = _bounds()
	var whole: float = bounds.size.x * bounds.size.y
	# Act
	var cells: Array = Cells.compute_cells(_seeds(), bounds)
	var nonempty: int = 0
	for poly: PackedVector2Array in cells:
		var area: float = Cells.polygon_area(poly)
		assert_lt(area, whole * 0.999, "没有任何一块该吃掉整张矩形")
		if area > 0.0:
			nonempty += 1
	# Assert——8 个互异种子必然各自分到一块非零面积
	assert_eq(nonempty, _seeds().size(), "每个互异种子都应分到非零面积的一块地")


# ═══════════════════════════════════════════════════════════════════════════════
# 三、归属判定与多边形一致（悬停高亮「亮错块」的护栏）
# ═══════════════════════════════════════════════════════════════════════════════

## 200 个采样点逐点断言：「最近种子」落在「包含该点的多边形」集合里。[br]
## [br][b]为什么断言「落在集合里」而不是「等于某个索引」[/b]：多边形裁剪保留边界点
## （[code]<= 0[/code] 而非 [code]< 0[/code]，否则相邻块之间会露零宽缝），故正落在
## 垂直平分线上的点被两块同时包含——这是[b]有意[/b]的，命中检测因此不走逐块判定
## 而走最近种子法（见 [method Cells.nearest_seed_index]）。测试要锁的正是
## 「两种口径不会分家」，而不是「平分线上归谁」这种几何上无定义的事。[br]
## [br][b]采样点用固定种子[/b]：失败必须可复现（随机种子会让这条用例偶发红）。
func test_nearest_seed_agrees_with_the_containing_cell_on_sampled_points() -> void:
	# Arrange
	var seeds: Array = _seeds()
	var bounds: Rect2 = _bounds()
	var cells: Array = Cells.compute_cells(seeds, bounds)
	var rng := RandomNumberGenerator.new()
	rng.seed = SAMPLE_SEED
	# Act + Assert
	var checked: int = 0
	for _i: int in SAMPLE_COUNT:
		var p := Vector2(
				rng.randf_range(bounds.position.x, bounds.end.x),
				rng.randf_range(bounds.position.y, bounds.end.y))
		var containing: Array = []
		for i: int in cells.size():
			if _contains(cells[i], p):
				containing.append(i)
		assert_false(containing.is_empty(),
				"采样点 %s 应至少落在一块地区内（铺满性）" % p)
		if containing.is_empty():
			continue
		var nearest: int = Cells.nearest_seed_index(seeds, p)
		assert_true(containing.has(nearest),
				"点 %s 的最近种子 %d 应落在包含它的块 %s 里" % [p, nearest, containing])
		checked += 1
	assert_eq(checked, SAMPLE_COUNT, "全部 %d 个采样点都应被校验到" % SAMPLE_COUNT)


## 最近种子法本身可信——种子原地返回自己索引，且平局取较小索引。[br]
## [b]防「恒返回 0」[/b]：不查这一条，上面那条断言在恒返回 0 时也可能通过。
func test_nearest_seed_index_returns_the_seed_itself_and_breaks_ties_low() -> void:
	# Arrange
	var seeds: Array = [Vector2(10.0, 10.0), Vector2(90.0, 10.0)]
	# Act + Assert
	assert_eq(Cells.nearest_seed_index(seeds, Vector2(12.0, 10.0)), 0,
			"靠近 0 号种子的点应归 0 号")
	assert_eq(Cells.nearest_seed_index(seeds, Vector2(88.0, 10.0)), 1,
			"靠近 1 号种子的点应归 1 号")
	assert_eq(Cells.nearest_seed_index(seeds, Vector2(50.0, 10.0)), 0,
			"正落在平分线上应取较小索引（确定性优先）")
	assert_eq(Cells.nearest_seed_index([], Vector2.ZERO), -1, "空种子应返回 -1")


# ═══════════════════════════════════════════════════════════════════════════════
# 四、确定性（缓存指纹 / 缩放平移不闪变的前提）
# ═══════════════════════════════════════════════════════════════════════════════

## 同输入两次调用，结果逐顶点相等。[br]
## [br][b]为什么必须锁死[/b]：块表会被渲染器缓存（一次布局算一次），而键是快照指纹；
## 如果同输入能算出两份不同结果，「缓存没失效」与「几何本身变了」就无法区分——那种
## 缺陷的表现是「拖动画布时地区闪一下」，且极难复现。[br]
## [br][b]同时锁 [method Cells.compute_cell_map] 的键序稳定性[/b]：它先排键再取种子，
## 而 GDScript 字典键序是实现细节——不排序的实现同样能通过「两次相等」，
## 却会在节点增删后给出错位的块（块跟着索引漂，不跟着节点走）。
func test_same_input_produces_identical_cells() -> void:
	# Arrange
	var seeds: Array = _seeds()
	var bounds: Rect2 = _bounds()
	# Act
	var first: Array = Cells.compute_cells(seeds, bounds)
	var second: Array = Cells.compute_cells(seeds, bounds)
	# Assert——逐块逐顶点
	assert_eq(first.size(), second.size(), "两次调用的块数应相同")
	for i: int in first.size():
		var a: PackedVector2Array = first[i]
		var b: PackedVector2Array = second[i]
		assert_eq(a.size(), b.size(), "第 %d 块两次的顶点数应相同" % i)
		for k: int in a.size():
			assert_eq(a[k], b[k], "第 %d 块第 %d 个顶点两次应逐位相等" % [i, k])


## 映射入口按节点 ID 稳定归块——种子顺序变化不影响「哪个节点拿到哪块」。[br]
## [br][b]反向对照[/b]：同一份坐标但插入顺序不同，两份映射必须逐键相等。
func test_cell_map_is_keyed_by_node_id_regardless_of_insertion_order() -> void:
	# Arrange
	var bounds: Rect2 = _bounds()
	var forward: Dictionary = {
		0: Vector2(0.0, 0.0), 101: Vector2(200.0, 20.0), 102: Vector2(-200.0, -30.0),
		201: Vector2(40.0, 104.0), 202: Vector2(-160.0, 130.0),
	}
	var backward: Dictionary = {
		202: Vector2(-160.0, 130.0), 201: Vector2(40.0, 104.0),
		102: Vector2(-200.0, -30.0), 101: Vector2(200.0, 20.0), 0: Vector2(0.0, 0.0),
	}
	# Act
	var a: Dictionary = Cells.compute_cell_map(forward, bounds)
	var b: Dictionary = Cells.compute_cell_map(backward, bounds)
	# Assert
	assert_eq(a.size(), 5, "五个节点应有五块地")
	for node_id: int in a.keys():
		assert_eq(a[node_id], b[node_id],
				"节点 %d 的地块不应随字典插入顺序变化" % node_id)


# ═══════════════════════════════════════════════════════════════════════════════
# 五、退化与空输入（不许崩、不许给假答案）
# ═══════════════════════════════════════════════════════════════════════════════

## 空种子 / 零面积矩形返回空数组（调用方据此跳过绘制）。
func test_empty_input_returns_empty_cells() -> void:
	assert_eq(Cells.compute_cells([], _bounds()).size(), 0, "空种子应返回空数组")
	assert_eq(Cells.compute_cells(_seeds(), Rect2()).size(), 0, "空矩形应返回空数组")
	assert_eq(Cells.compute_cell_map({}, _bounds()).size(), 0, "空坐标表应返回空字典")


## 种子坐标重合时仍是合法划分——不崩、不平局丢地。[br]
## [br][b]退化策略[/b]（见模块文档）：索引小者全取该区域、索引大者判空；
## 「铺满」这条性质因此不被破坏（面积总和仍等于矩形）。
func test_duplicate_seeds_degrade_without_breaking_the_partition() -> void:
	# Arrange——两个种子落在同一点
	var seeds: Array = [Vector2(50.0, 50.0), Vector2(50.0, 50.0), Vector2(300.0, 90.0)]
	var bounds: Rect2 = Rect2(Vector2.ZERO, Vector2(400.0, 200.0))
	# Act
	var cells: Array = Cells.compute_cells(seeds, bounds)
	# Assert
	assert_eq(cells.size(), 3, "块数仍应等于种子数（长度恒定——调用方按索引取用）")
	assert_true((cells[1] as PackedVector2Array).is_empty(),
			"重合种子中索引大的那块应判空")
	var total: float = 0.0
	for poly: PackedVector2Array in cells:
		total += Cells.polygon_area(poly)
	assert_almost_eq(total, 400.0 * 200.0, 1.0,
			"退化后面积总和仍应等于矩形面积（不平局丢地）")


## 点在多边形内判定（测试装置）——[b]包含边界[/b]。[br]
## [br][b]为什么自己写边界容差[/b]：[method Geometry2D.is_point_in_polygon]
## 对边界点的行为没有承诺，而本模块的块[b]故意[/b]包含平分线（否则露缝）——
## 用不容差的判定会把「有意的重叠」误判成「没铺满」。
func _contains(p_poly: PackedVector2Array, p_point: Vector2) -> bool:
	if p_poly.size() < 3:
		return false
	if Geometry2D.is_point_in_polygon(p_point, p_poly):
		return true
	for i: int in p_poly.size():
		var a: Vector2 = p_poly[i]
		var b: Vector2 = p_poly[(i + 1) % p_poly.size()]
		if Geometry2D.get_closest_point_to_segment(p_point, a, b) \
				.distance_to(p_point) <= BOUNDARY_EPS:
			return true
	return false
