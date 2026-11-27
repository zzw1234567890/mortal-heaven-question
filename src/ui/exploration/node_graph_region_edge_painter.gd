extends RefCounted
## NodeGraphRegionEdgePainter —— 地区层的[b]第二笔：墨边[/b]（细墨线，确定性抖动）。[br]
##
## [b]为什么边界要抖[/b]：Voronoi 的边是直线段，围起来是一张几何网格——「摊开的势力
## 图」读起来像程序生成的图表。舆图上的疆界是手描的：线还在，但每几像素偏一点。[br]
##
## [br][b]★ 抖动的三条硬要求 ★[/b]：[br]
##   1. [b]确定性[/b]——同一份顶点表永远算出同一串偏移。分块进渲染器的缓存指纹，带随机
##      源的话同一份输入会算出两份结果，缓存在每帧失效（拖动画布时整张图闪）；[br]
##   2. [b]共边无缝[/b]——相邻两块共享同一条边，两块各自描边时若把共边推向不同方向，
##      中间就裂出一条缝。偏移量按顶点[b]坐标[/b]哈希（不是按顶点下标），共边的同一
##      几何点无论从哪一块看过去都偏到同一处；[br]
##   3. [b]幅度小[/b]——目的是「不像几何网格」，不是「画歪了」。2.2px 在 50% 缩放下约
##      1px，读成线条不平整而不是位置错误。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：宿主经参数传入，只读快照。[br]
##
## [br]来源: 本轮任务书任务二（地区的边）、ADR-0031 §2。

## 视觉规格（[constant DASH_LENGTH] 与边宽口径与节点连线同源）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")
## 地区视觉规格（边宽 / 边色 / 抖动 / 高亮三样）。
const RegionStyle := preload("res://src/ui/exploration/node_graph_style_region.gd")
## 地区层共享读写口（可见集合与六态视觉）。
const RegionCommon := preload("res://src/ui/exploration/node_graph_region_common.gd")


## 逐地区描边。[br]
## [br][b]高亮时动三样[/b]：线宽换成 [constant RegionStyle.HIGHLIGHT_EDGE_WIDTH]、颜色换成
## 墨黑、整条边[b]向外扩 2px[/b]——三样一起，读成「这片地被框住了」而不是「颜色变了」。[br]
## [br][b]为什么外扩而不是只加粗[/b]：只加粗会让相邻两块的边在共边处叠成一条 8px 的黑带，
## 看起来像「两块都被选中」；外扩让高亮那块把边界往自己这边收，与邻块拉开一条缝。[br]
## [br][b]为什么高亮时不画虚线[/b]：虚线是「这一片去不了」的语义，而能被悬停/聚焦到的
## 地区在画面上是「你正在看它」——两句话不该同时说。高亮优先。[br]
## [br][param p_cells] 分块表；[param p_ids] 参与绘制的地区 ID（已按层过滤并排序）。
static func draw_edges(p_host: Control, p_cells: Dictionary, p_ids: Array) -> void:
	for node_id: int in p_ids:
		var poly: PackedVector2Array = p_cells[node_id]
		if poly.size() < 3:
			continue
		var visual: Dictionary = RegionCommon.visual_of(p_host, node_id)
		var width: float = RegionStyle.EDGE_WIDTH * float(visual.get("edge_grow", 1.0))
		var color: Color = RegionStyle.EDGE_COLOR
		var dashed: bool = bool(visual.get("edge_dashed", false))
		var loop: PackedVector2Array = jittered(poly)
		if RegionCommon.highlighted(p_host, node_id):
			width = RegionStyle.HIGHLIGHT_EDGE_WIDTH
			color = RegionStyle.HIGHLIGHT_EDGE_COLOR
			dashed = false
			loop = offset_outward(loop, RegionStyle.HIGHLIGHT_EDGE_GROW)
		if dashed:
			draw_dashed_loop(p_host, loop, color, width)
		else:
			p_host.draw_polyline(closed(loop), color, width)


## 顶点抖动——[b]确定性[/b]（同坐标永远偏同一方向与幅度）。[br]
## [br][b]为什么是「逐段」而不是「逐顶点」[/b]：逐顶点抖动只改变端点位置，两点之间仍是
## 一条直线；要让边界读成手描的，得在线段上插采样点再逐点偏移——
## [constant RegionStyle.EDGE_JITTER_SEGMENT] 是采样段长（px）。[br]
## [br][b]为什么原始顶点不抖、只有插值点抖[/b]：原始顶点是两块地区的[b]共享[/b]端点，
## 抖它等于把两块的公共角点扯开；而插值点只属于当前这条边，抖了也不会撕开顶点。[br]
## [br][b]边界情形[/b]：顶点数 < 2 时原样返回（退化块由调用方拦下，这里是二层保险）。
static func jittered(p_poly: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = p_poly.size()
	if n < 2:
		return p_poly
	for i: int in n:
		var a: Vector2 = p_poly[i]
		var b: Vector2 = p_poly[(i + 1) % n]
		out.append(a)
		var length: float = a.distance_to(b)
		var steps: int = int(length / RegionStyle.EDGE_JITTER_SEGMENT)
		for s: int in range(1, steps + 1):
			var t: float = float(s) / float(steps + 1)
			out.append(wobble(a.lerp(b, t)))
	return out


## 单点抖动——按坐标的整数哈希在两个方向各偏移一个固定量。[br]
## [br][b]为什么先量化到 0.25px 再哈希[/b]：哈希要对[b]浮点相等[/b]敏感，而共边的两个
## 端点是从两个不同的裁剪过程算出来的，末位可能有 1e-6 的差——量化后它们落进同一个格子，
## 偏到同一处。0.25px 远小于抖动幅度（2.2px），量化误差看不出来。[br]
## [br][b]为什么用两个不同的乘数[/b]：x 与 y 的偏移量若同源，抖动方向会全落在 45° 对角
## 线上，读成「整条边被斜着拉了一下」而不是「线条不平整」。
static func wobble(p_point: Vector2) -> Vector2:
	var ix: int = int(round(p_point.x * 4.0))
	var iy: int = int(round(p_point.y * 4.0))
	var hx: float = float((ix * 73856093) ^ (iy * 19349663)) / 2147483647.0
	var hy: float = float((ix * 83492791) ^ (iy * 2654435761)) / 2147483647.0
	return p_point + Vector2(hx - floor(hx) - 0.5, hy - floor(hy) - 0.5) \
			* 2.0 * RegionStyle.EDGE_JITTER


## 顶点表沿外法线整体外扩（高亮用——见 [method draw_edges]）。[br]
## [br][b]外法线怎么定[/b]：分块是凸多边形，外法线 = 两条邻边方向的垂线之和再按绕行方向
## 取符号。[b]凸性由分块模块的单测保证[/b]（[code]test_node_graph_region_cells.gd[/code]
## 第一条断言），此处不再判——凹多边形上这套算法会自交，而它不会遇到凹多边形。[br]
## [br][b]为什么两条邻边都算再归一化[/b]：只取一条边的法线会让尖角处的偏移量小于平直处
## （角的平分线比单边法线长），框出来的边界在角上塌进去。
static func offset_outward(p_poly: PackedVector2Array, p_grow: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = p_poly.size()
	if n < 3:
		return p_poly
	var sign_: float = winding_sign(p_poly)
	for i: int in n:
		var prev: Vector2 = p_poly[(i + n - 1) % n]
		var cur: Vector2 = p_poly[i]
		var nxt: Vector2 = p_poly[(i + 1) % n]
		var n1: Vector2 = (cur - prev).normalized().orthogonal() * sign_
		var n2: Vector2 = (nxt - cur).normalized().orthogonal() * sign_
		var bisector: Vector2 = n1 + n2
		if bisector.length_squared() > 0.0:
			out.append(cur + bisector.normalized() * p_grow)
		else:
			out.append(cur + n1 * p_grow)  # 顶点处两边反向（退化）——退回单边法线
	return out


## 多边形绕行方向（+1 / -1）——用有向面积定。[br]
## [br][b]为什么需要它[/b]：外法线的方向取决于顶点是顺时针还是逆时针，而分块模块的顶点
## 序由裁剪过程决定（鞋带公式取绝对值，故它不关心方向）；这里补一个符号，绘制侧才有确定
## 的「外」。
static func winding_sign(p_poly: PackedVector2Array) -> float:
	var twice: float = 0.0
	var n: int = p_poly.size()
	for i: int in n:
		var a: Vector2 = p_poly[i]
		var b: Vector2 = p_poly[(i + 1) % n]
		twice += a.x * b.y - b.x * a.y
	return 1.0 if twice >= 0.0 else -1.0


## 虚线闭合环——按段长把每条边切段，隔段画（不可达态）。[br]
## [br][b]为什么不复用 [method CanvasItem.draw_dashed_line][/b]：那个方法对每一条独立线段
## 各自从头起算虚线相位，闭合环的四条边接缝处会出现两段实线粘在一起（读成「边上有块
## 疤」）。这里按累积长度连续推进相位，接缝与别处一样。[br]
## [br][b]为什么不用 [code]draw_polyline[/code] 的虚线变体[/b]：Godot 4.6 没有。[br]
## [br][b]相位怎么推进[/b]：`phase` 是「已经走过的虚线段数 × dash」的余量——实线段走到
## `dash` 就切换为空线段，一个周期是 `2 * dash`。
static func draw_dashed_loop(p_host: Control, p_poly: PackedVector2Array,
		p_color: Color, p_width: float) -> void:
	var n: int = p_poly.size()
	if n < 3:
		return
	var dash: float = maxf(Style.DASH_LENGTH, 1.0)
	for i: int in n:
		var a: Vector2 = p_poly[i]
		var b: Vector2 = p_poly[(i + 1) % n]
		var seg: float = a.distance_to(b)
		if seg <= 0.0:
			continue
		var dir: Vector2 = (b - a) / seg
		var walked: float = 0.0
		while walked < seg:
			var offset: float = fposmod(walked, 2.0 * dash)
			if offset >= dash:
				# 空线段——跳过余下部分（不画）
				walked += minf(2.0 * dash - offset, seg - walked)
				continue
			var run: float = minf(dash - offset, seg - walked)
			p_host.draw_line(a + dir * walked, a + dir * (walked + run), p_color, p_width)
			walked += run


## 顶点表闭合（[method CanvasItem.draw_polyline] 不闭合首尾）。[br]
## [br][b]为什么复制而不是原地追加[/b]：入参的顶点表是渲染器持有的分块表，就地追加会
## 把绘制的副作用写回共享数据——同一帧里命中检测再读它就多了一个点。
static func closed(p_points: PackedVector2Array) -> PackedVector2Array:
	var loop: PackedVector2Array = p_points.duplicate()
	if not loop.is_empty():
		loop.append(loop[0])
	return loop
