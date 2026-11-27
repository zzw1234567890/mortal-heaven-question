extends RefCounted
## NodeGraphFogPainter —— 迷雾遮罩的[b]一笔[/b]：把挖好孔的分层多边形画成柔边深色覆盖。[br]
##
## [b]为什么从 [code]node_graph_node_painter.gd[/code] 拆出来[/b]：那份已 344 行、
## 越过 300 行软上限；而「整块雾怎么画」与「单个节点长什么样」是两件事——前者读的是
## 遮罩多边形表，后者读的是六态样式，两者没有一处共享输入。拆完两边都回到上限内。[br]
##
## [br][b]★ 柔边怎么来的（本轮：矩形硬边改渐变）★[/b]：不是拿一层半透明矩形盖住
## 整屏（那是绕过问题），而是[b]用浓度换边[/b]——把同一块遮罩按「向内缩进」切成
## [constant NodeGraphStyle.FOG_FEATHER_STEPS] 层，由外向内逐层叠加同色，
## 某点被覆盖的层数 = 它离开边界的深度，于是浓度随深度连续上升，边界处恰好是 0。[br]
##
## [br][b]每层取多少浓度（[method feather_alphas] 的数学）[/b]：叠 N 层同色做
## [code]over[/code] 合成，累计浓度是 [code]1-(1-a)^N[/code] 而[b]不是[/b]
## [code]N·a[/code]——要让最深处正好等于雾心浓度 α，每层得取
## [code]a = 1-(1-α)^(1/N)[/code]。按 [code]N·a[/code] 取会让雾心比设计值淡掉
## 一大截（N=8 时 8×0.095=0.76 是错的，正确 a=0.163）。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：纯绘制，输入是调用方算好的层表。[br]
##
## [br]来源: 本轮任务书任务一（迷雾矩形硬边改柔边，羽化带宽 ≥ 120px）、
## GDD 界面规则「迷雾节点：深色覆盖 + ❓标记」、ADR-0031 §5 合批。

## 视觉规格（尺寸/配色常量唯一来源）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")


## 逐层浓度——[b]由雾心浓度反推[/b]，不是简单均分（推导见类文档）。[br]
## [br][b]返回[/b]：长度 [param p_layers] 的浓度表（各层同值——对称的层自然取同一个
## 值；保留「逐层一个值」的形状是为了将来要做非线性衰减时不必改调用方）。
static func feather_alphas(p_fog_alpha: float, p_layers: int) -> PackedFloat32Array:
	var n: int = maxi(p_layers, 1)
	var target: float = clampf(p_fog_alpha, 0.0, 1.0)
	var each: float = 1.0 - pow(1.0 - target, 1.0 / float(n))
	var out := PackedFloat32Array()
	for _i: int in n:
		out.append(each)
	return out


## 画整块柔边遮罩——[b]一次调用画一层[/b]，由外向内。[br]
## [br][b]为什么每层要合成一张索引表再一次画[/b]：一个 24 孔的遮罩三角化后约四百个
## 三角（见 [method append_triangles]），逐笔 [code]draw_colored_polygon[/code] 就是
## 四百次绘制调用；拼成一张后[b]每层一次[/b]（本层 8 次，预算 200 整帧——
## ADR-0031 §5 合批口径）。[br]
## [br][b]为什么用底层三角数组而不是 [method CanvasItem.draw_polygon][/b]：后者内部
## 按[b]三角扇[/b]连点（0,1,2 / 0,2,3 / …），只对凸多边形成立——挖孔后的块是凹的，
## 用它会连出一大堆跨孔的三角形，遮罩直接烂掉。[code]draw_colored_polygon[/code]
## 同样是凸的。三角化后的索引表只能走这一条路。[br]
## [br][b]单色用长度 1 的色表[/b]：底层接受「1 个色」或「每顶点一个色」，前者省一份
## 与顶点等长的数组。[br]
## [br][param p_layers] 层表（由外向内；每层是多边形数组，空层跳过）。[br]
## [br][b]为什么没有「铺满的矩形」参数[/b]：遮罩的范围由层自身界定
## （[method NodeGraphLayout.fog_feather_layers] 的输入矩形已在其中）；早先版本多收
## 一个 [code]Rect2[/code] 却从未读它——多一个参数就多一处分叉点，而那个矩形恰好是
## 必须与地形逐像素一致的那一个。
static func draw_fog(p_host: Control, p_no_fog: bool, p_layers: Array) -> void:
	if p_no_fog or p_layers.is_empty():
		return  # 无迷雾——不产生任何绘制
	var alphas: PackedFloat32Array = feather_alphas(Style.FOG_COLOR.a, p_layers.size())
	var canvas: RID = p_host.get_canvas_item()
	for i: int in p_layers.size():
		var points := PackedVector2Array()
		var indices := PackedInt32Array()
		for piece: PackedVector2Array in (p_layers[i] as Array):
			append_triangles(points, indices, piece)
		if indices.is_empty():
			continue
		var color := Color(Style.FOG_COLOR.r, Style.FOG_COLOR.g, Style.FOG_COLOR.b,
				alphas[i])
		RenderingServer.canvas_item_add_triangle_array(canvas, indices, points,
				PackedColorArray([color]))


## 把一块多边形三角化后[b]追加[/b]进顶点表 / 索引表（两个表都就地增长）。[br]
## [br][b]退化块跳过[/b]：[method Geometry2D.triangulate_polygon] 对自交 / 共线多边形
## 返回空表——空表不追加顶点（免得留下永远连不到的孤立点）。
static func append_triangles(p_points: PackedVector2Array, p_indices: PackedInt32Array,
		p_piece: PackedVector2Array) -> void:
	var triangles: PackedInt32Array = Geometry2D.triangulate_polygon(p_piece)
	if triangles.is_empty():
		return
	var base: int = p_points.size()
	p_points.append_array(p_piece)
	for i: int in triangles:
		p_indices.append(base + i)
