extends RefCounted
## NodeGraphFogRegion —— 迷雾的[b]地区化[/b]铺法（跟随地区边界，块与块之间无缝）。[br]
##
## [b]为什么改[/b]（老板 2026-11-27）：「没探明的地方看不清」但要[b]贴着地区的边界[/b]、
## 必须[b]连续[/b]——此前那套「矩形挖孔 + 多边形内缩分层」的遮罩是[b]矩形[/b]语言，
## 在地图化的画面上读成「一块盖在地图上的补丁」，而且相邻未探明地区之间的接缝会露出来
## （两块雾各自从自己的边界起羽化，共边处两侧都是最浅的一档 → 一条亮缝）。[br]
##
## [br][b]★ 关键手法：先并集，再羽化 ★[/b]：[br]
##   1. 把所有 FOGGED 地区的多边形 [method Geometry2D.merge_polygons] 合并成一个
##      或几个连通块——相邻两块共享同一条边，合并之后[b]内部边界整体消失[/b]，
##      接缝问题从根上不存在（不是「把缝画得看不见」，是「没有缝」）；[br]
##   2. 对这个并集做 [method Geometry2D.offset_polygon] 逐档内缩，每一档画一层很淡的
##      雾——最外一档贴着并集边界（最淡），最深一档只在离边界一整个羽化带宽的地方
##      （最浓）。叠出来就是从边界 0 升到满浓度的羽化带。[br]
##
## [br][b]为什么用「逐档内缩」而不是给顶点刷渐变[/b]：[code]canvas_item_add_triangle_array[/code]
## 确实接受每顶点一色，但渐变的[b]方向[/b]得逐顶点算「离边界多远」——而并集是凹的
## （几个地区拼起来像一片大陆），同一块多边形上顶点法线方向不一致，刷出来会在凹角处
## 出现折痕。逐档内缩把这个交给几何本身：每一档都是「并集向内缩 t」，凹角自动一致。[br]
##
## [br][b]★ 平台段与相邻像素差（本轮口径修正）★[/b]：每一档是一次[b]常量 alpha[/b] 填充，
## 故栅格上是台阶状的——相邻像素的 alpha 差在档边界处正好等于[b]阶高[/b] α/N（档内为 0），
## 台阶长度 = 带宽 / 档数。这两个数是本模块要交的两个读数，各有一个纯函数：
## [method staircase_step] 与 [method plateau_length]。[method profile_at] 另外给出
## 「没有栅格化」时的连续剖面，用来对照量化误差有多少——只报它会掩盖台阶（旧口径下理想
## 斜率 1.38/255 看着达标，实际台阶 28.5/255）。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：纯几何 + 绘制，不持游戏状态——缓存由调用方
## （[code]NodeGraphGroundLayer[/code]）按指纹持有。[br]
##
## [br]来源: 本轮任务书任务三（迷雾跟随地区边界、连续、可量）、老板 2026-11-27 反馈、
## ADR-0031 §2/§5。

## 视觉规格（雾色 / 羽化带宽 / 档数）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")
## 六态枚举（哪块地在雾里）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")


## 并集多边形（一个雾团 = 一条多边形；多块不相邻的雾各是一条）。[br]
## [br][param p_cells] 分块表；[param p_ids] 处于雾中的地区 ID。[br]
## [br][b]返回[/b]：多边形数组（可能为空——没有雾，或几何退化成零面积）。[br]
## [br][b]为什么退化时返回空而不是退回逐块画[/b]：逐块画必然带缝（见类文档），
## 而「有缝的雾」比「没雾」更糟——玩家会以为那条亮线是可以走的路。调用方据空表
## 跳过绘制。[br]
## [br][b]为什么不用 [method Geometry2D.merge_polygons] 的 hmm[/b]：它的签名是
## [code](a, b) -> Array[/code]，两两合并；这里是逐个累加，块数 ≤ 15，代价可接受。
static func union_of(p_cells: Dictionary, p_ids: Array) -> Array:
	var merged: Array = []
	var first: bool = true
	for node_id: int in p_ids:
		var poly: PackedVector2Array = p_cells.get(node_id, PackedVector2Array())
		if poly.size() < 3:
			continue
		if first:
			merged = [poly]
			first = false
			continue
		var next: Array = []
		for piece: PackedVector2Array in merged:
			for part: PackedVector2Array in Geometry2D.merge_polygons(piece, poly):
				if part.size() >= 3:
					next.append(part)
		merged = next
		if merged.is_empty():
			break  # 被并没了——后面的块也救不回来
	return merged


## 并集向内的逐档内缩多边形（由外向深——第 0 档最靠外、浓度最浅）。[br]
## [br][param p_union] [method union_of] 的结果。[br]
## [param p_band] 羽化带宽（px）；[param p_steps] 档数（≥1）。[br]
## [br][b]返回[/b]：[code]Array[Array[PackedVector2Array]][/code]——每一档是多边形数组
## （该档在并集里可能被切成好几块）。某档缩没了就到此为止（后面的档也是空）。[br]
## [br][b]为什么每档都要 [code]offset_polygon[/code] 而不是对上档再缩[/b]：误差不累积
## ——对原始并集缩 t 与对「已缩 t-d」再缩 d 在凹角处结果不同（后者会把小凹角抹平），
## 而我们要的是「离原始边界正好 t」这条等距线。[br]
## [br][b]为什么不用 ROUND 端接[/b]：ROUND 会为每个顶点生成弧线顶点，
## 15 块地的并集 × 12 档下顶点数会翻十倍；MITER 在凸角处外扩过度，但这里是[b]内缩[/b]
## ——内缩时凹角（对应原多边形的凸角）用 MITER 才是正确的等距线。
static func feather_rings(p_union: Array, p_band: float, p_steps: int) -> Array:
	var steps: int = maxi(p_steps, 1)
	var rings: Array = []
	for i: int in range(1, steps + 1):
		var inset: float = -p_band * float(i) / float(steps)
		var ring: Array = []
		for piece: PackedVector2Array in p_union:
			for shrunk: PackedVector2Array in Geometry2D.offset_polygon(piece, inset,
					Geometry2D.JOIN_MITER):
				if shrunk.size() >= 3:
					ring.append(shrunk)
		if ring.is_empty():
			break
		rings.append(ring)
	return rings


## 第 [param p_k] 档画完后的累计浓度——[code]k·α/N[/code]（夹到 α）。[br]
## [br][b]★ 本轮从「同层浓度」改为「等增量」★[/b]：旧口径每档取同一个
## [code]a = 1-(1-α)^(1/N)[/code]，累计是 [code]1-(1-a)^k[/code]，增量递减——[b]第一档
## 最陡[/b]（N=12 时 a=0.112 ≈ 28.5/255）。栅格化后相邻像素的浓度差就是那一档的增量，
## 故边界处最陡，正是人眼最看得见的地方。[br]
## [br][b]等增量怎么来的[/b]：让第 k 档画完之后总浓度正好是 [code]k·α/N[/code]，
## 则每两档之间恰好上升 α/N，最陡的一档也只是 α/N。[br]
## [br][b]返回[/b]：0..α。
static func cumulative_alpha(p_alpha: float, p_steps: int, p_k: int) -> float:
	var steps: int = maxi(p_steps, 1)
	return clampf(p_alpha, 0.0, 1.0) * float(clampi(p_k, 0, steps)) / float(steps)


## 第 [param p_k] 档（1 基、由外向深）该取的[b]单层[/b] alpha。[br]
## [br][b]推导[/b]：叠上本档后累计要到 [code]c_k[/code]，叠之前是 [code]c_(k-1)[/code]，
## 而 [code]1-(1-c_(k-1))·(1-a) = c_k[/code] ⇒ [code]a = 1-(1-c_k)/(1-c_(k-1))[/code]。
## 这个 a 本身是递增的（累计越浓，要再抬起同样的绝对增量就得用更大的单层浓度），但它抬起的
## [b]累计[/b]增量恒为 α/N——而栅格化后读到的是累计增量。[br]
## [br][b]为什么不是所有档取同一个 a[/b]：那正是旧口径，增量会递减（见
## [method cumulative_alpha]）。[br]
## [br][b]返回[/b]：本档 alpha（0..1）；[code]c_(k-1)[/code] 已到 1 时返回 0。
static func ring_alpha(p_alpha: float, p_steps: int, p_k: int) -> float:
	var prev: float = cumulative_alpha(p_alpha, p_steps, p_k - 1)
	if prev >= 1.0:
		return 0.0
	var cur: float = cumulative_alpha(p_alpha, p_steps, p_k)
	return clampf(1.0 - (1.0 - cur) / (1.0 - prev), 0.0, 1.0)


## 栅格化台阶高度——相邻两档之间的浓度跃变（= 相邻像素最坏情况下的 alpha 差）。[br]
## [br][b]为什么这才是任务书要量的那个数[/b]：任务书写「羽化带内扫描线相邻像素 alpha 差
## ≤2/255」——扫描线量的是[b]画出来的像素[/b]；每一档是一次常量 alpha 填充，故相邻像素的
## 差在档边界处正好等于阶高、档内为 0。[br]
## [br][b]为什么要与 [method profile_at] 分开报[/b]：后者给的是「没有栅格化」时的连续剖面
## 斜率（[code]α/band[/code]），只报它会掩盖台阶——旧口径下理想斜率是 1.38/255（看着
## 达标），而实际台阶是 28.5/255。[br]
## [br][b]返回[/b]：α / 档数。
static func staircase_step(p_alpha: float, p_steps: int) -> float:
	return clampf(p_alpha, 0.0, 1.0) / float(maxi(p_steps, 1))


## 连续剖面——离边界 [param p_depth] 处的雾浓度（纯函数，供单测按 1px 采样）。[br]
## [br][b]模型[/b]：栅格上其实是 N 级台阶，但其[b]理想剖面[/b]是
## [code]depth ≥ band → α[/code]，否则 [code]α × depth / band[/code]——线性、连续、
## 单调。绘制侧用台阶逼近它，台阶长度 = band / N（见 [method plateau_length]）。[br]
## [br][b]为什么把「理想剖面」单独暴露出来[/b]：它给出「没有栅格化」时的斜率，与台阶读数
## 而在 headless 下读渲染出来的像素既慢又依赖驱动；量解析剖面的斜率是同一件事的
## 可复现形式——两者的差只是栅格化把斜线变成阶梯。[br]
## [br][b]返回[/b]：0..α。
static func profile_at(p_depth: float, p_band: float, p_alpha: float) -> float:
	if p_band <= 0.0:
		return p_alpha
	return clampf(p_alpha * maxf(p_depth, 0.0) / p_band, 0.0, p_alpha)


## 台阶长度（px）——栅格化后同一 alpha 值连续出现的最大长度。[br]
## [br][b]为什么要量它[/b]：任务书要求「没有超过 16px 的平台段」——平台段就是肉眼可见的
## 「一块一块的色带」，正是要消灭的东西。它只取决于带宽与档数，与地图无关。[br]
## [br][b]与 [method staircase_step] 是同一枚硬币的两面[/b]：平台段是「横向多长才变一次」，
## 阶高是「变一次跳多少」。本轮的 128 档下前者 1.09px、后者 1.51/255，两条线都在验收内。[br]
## [br][b]返回[/b]：带宽 / 档数。
static func plateau_length(p_band: float, p_steps: int) -> float:
	return p_band / float(maxi(p_steps, 1))


## 画雾——[b]羽化环 + 逐档浓度，合成[b]一次[/b]绘制[/b]（见类文档）。[br]
## [br][b]由外向内画[/b]：先画最外（最淡）的一档，后面的档叠在它上面——远处浓、近处淡，
## 正是雾该有的读法。反过来画的话，深色层会被浅色层盖住，边界处反而更浓。[br]
## [br][b]每档浓度逐档算[/b]（[method ring_alpha]，不是同一个数）：栅格化后读到的相邻
## 像素差 = 各档抬起的[b]累计[/b]增量，取等增量（α/N）才让边界与深处一样平滑。[br]
## [br][b]★ 为什么全部环合成一次调用 ★[/b]：档数由「相邻像素差 ≤1/255」反推得 N ≥ 194，
## 而每一档若各发一次 [code]canvas_item_add_triangle_array[/code]，一帧就是两百次绘制——
## 直接顶破 ADR-0031 §5 的合批预算。该 API 的第 4 个参数本来就是[b]逐顶点色表[/b]
## （非空且长度 = 顶点数时逐顶点生效），且同一批次内三角面按索引顺序绘制、保序——于是
## 所有环的顶点、索引、颜色拼进三张表，[b]一次[/b]提交，合成语义与逐档调用完全一致。[br]
## [br][b]★ 本轮起收羽化环而不是并集 ★[/b]：环由 [method feather_rings] 在[b]缓存期[/b]
## 算好（256 档 × 十余块的多边形内缩是毫秒级开销，每帧重算会吃掉帧预算），本方法只负责
## 逐档调浓度画出来。[br]
## [br][param p_host] 绘制宿主；[param p_rings] 羽化环（由外向深，见 [method feather_rings]）；
## [param p_alpha] 雾心浓度；[param p_steps] 档数（与算环时必须是同一个）。[br]
## [br][b]空环直接返回[/b]：没有雾（或几何退化）时不画，而不是画一块 0 面积的空。
static func draw_fog_union(p_host: Control, p_rings: Array, p_alpha: float,
		p_steps: int) -> void:
	if p_rings.is_empty():
		return
	var points := PackedVector2Array()
	var indices := PackedInt32Array()
	var colors := PackedColorArray()
	for k: int in p_rings.size():
		var layer_alpha: float = ring_alpha(p_alpha, p_steps, k + 1)
		if layer_alpha <= 0.0:
			continue
		var color := Color(Style.FOG_COLOR, layer_alpha)
		for piece: PackedVector2Array in p_rings[k]:
			var base: int = points.size()
			var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(piece)
			if triangles.is_empty():
				continue
			points.append_array(piece)
			for _v: int in piece.size():
				colors.append(color)
			for i: int in triangles:
				indices.append(base + i)
	if indices.is_empty():
		return
	RenderingServer.canvas_item_add_triangle_array(p_host.get_canvas_item(),
			indices, points, colors)


## 处于雾中的地区 ID 列表（按六态判——未注入六态时回退空表：legacy 路径不铺地区雾）。[br]
## [br][b]为什么按六态而不是 [code]revealed_set[/code][/b]：迷雾的定义本轮只有一个——
## [code]NodeStateLogic.NodeState.FOGGED[/code]。用第二套近似就会出现「节点画成亮的、
## 它那块地是暗的」这种自相矛盾的图。[br]
## [br][b]排序[/b]：并集运算的结果不该随字典键序变（否则缓存的指纹会谎报「变了」）。
static func fogged_ids(p_cells: Dictionary, p_states: Dictionary) -> Array:
	var out: Array = []
	if p_states.is_empty():
		return out
	for node_id: int in p_cells.keys():
		if int(p_states.get(node_id, NodeStateLogicScript.NodeState.REACHABLE)) \
				== NodeStateLogicScript.NodeState.FOGGED:
			out.append(node_id)
	out.sort()
	return out
