extends RefCounted
## NodeGraphGroundLayer —— 节点图的[b]地面层[/b]：地形底图 + 迷雾遮罩（含几何缓存）。[br]
##
## [b]为什么单独成文件[/b]：[code]node_graph_renderer.gd[/code] 此前已越过单文件
## 300 行软上限（coding-standards）；而「画布垫什么、雾盖在哪」与「节点怎么画、点得中
## 点不中」是两件事——前者是[b]地面[/b]，后者是[b]浮在地面上的东西[/b]。[br]
##
## [br][b]★ 本轮起地形与迷雾是[b]两次独立调用[/b] ★[/b]（地区化）：绘制顺序是
## 地形 → 地区（底渍/墨边/纸条）→ 迷雾 → 节点。地区必须夹在地形与迷雾之间——铺在地形
## 上（否则疆域盖不住插画）、压在雾下（否则未探明区域的形状会从「哪几块地的边是暗的」
## 泄底）。合在一次调用里就没地方插进去，故 [method draw_terrain] 与 [method draw_fog]
## 分开。[br]
##
## [br][b]★ 迷雾的铺法本轮整体换掉 ★[/b]：旧做法是「内容矩形减圆孔 + 逐层内缩」——
## 那是[b]矩形[/b]语言，在地图化的画面上读成一块盖在地图上的补丁；且两块相邻的未探明
## 区域各自羽化，共边处两侧都是最浅的一档，会亮出一条缝。新做法是「[b]所有雾中地区的
## 并集[/b]向内羽化」（见 [NodeGraphFogRegion]）：并集让内部边界整体消失，接缝问题
## 从根上不存在。[br]
##
## [br][b]★ 第三轮：档数由 12 提到 256 ★[/b]：每一档是一次常量 alpha 填充，栅格化后
## 相邻像素的 alpha 差在档边界处正好等于阶高 α/N（档内为 0）。验收线是「相邻像素差
## ≤1/255」，反推得 N ≥ α×255 ≈ 194；12 档的阶高是 16.15/255——近二十倍，正是反馈里
## 「成片亮暗补丁」的来源。256 档的阶高是 0.757/255，留一档余量。代价只在缓存期
## （多算一遍内缩，12 块并集实测 7ms）；每帧不变——环进了缓存，绘制仍是[b]一次[/b]
## 合批（见 [method NodeGraphFogRegion.draw_fog_union]）。[br]
##
## [br][b]持有缓存，但不持游戏状态[/b]（ADR-0031 §2）：[member _fog_layers] 是纯几何
## 换算的结果缓存，输入是渲染器给的分块表与六态；没有任何玩法状态住在这里。[br]
##
## 来源: 本轮任务书任务三（迷雾跟随地区边界 + 连续可量）、ADR-0031 §2/§5、
## design/gdd/exploration-ui-system.md §2。

## 视觉规格（尺寸/配色常量唯一来源）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")
## 地形底图绘制（插画 + 压暗 + 暗角）。
const Terrain := preload("res://src/ui/exploration/node_graph_terrain.gd")
## 迷雾几何 + 绘制（并集 + 逐档内缩 + 逐档浓度——见 [NodeGraphFogRegion]）。
const FogRegion := preload("res://src/ui/exploration/node_graph_fog_region.gd")

## 迷雾[b]并集 + 羽化环[/b]缓存（[code]{ids, union, rings}[/code]）。[br]
## [br][b]为什么必须缓存[/b]：[method Geometry2D.merge_polygons]（十几块两两归并）+
## [method Geometry2D.offset_polygon]（每档逐块内缩）在 15 块地 × 128 档下是[b]上千次[/b]
## 多边形运算（实测 6~12ms）——每帧重算会吃掉整个帧预算；而它只在「雾中地区集合 /
## 疆域变了」时才需重算。[br]
## [br][b]为什么拖画布不会让缓存失效[/b]：进键的是[b]分块表与六态[/b]，两者都随布局
## （换图 / 重布局）变，与视口的 [code]zoom[/code] / [code]offset[/code] 无关。[br]
## [br][b]为什么键里放分块几何而不是坐标[/b]：分块是「哪块地在哪」，坐标只是它的输入；
## 按最终几何进键，则任何导致疆域变化的改动都会失效缓存，不必逐条追因。
var _fog_layers: Dictionary = {}
## 上次算雾时的输入指纹（见 [member _fog_layers]）。
var _fog_key: String = ""


## 画地形底图（地面层的[b]下半[/b]）——地区与迷雾之下。[br]
## [br][b]★ 本轮起地形与迷雾分成两次调用 ★[/b]：地区层（疆域底渍）必须夹在两者之间
## ——地形在最下（地区铺在地形上），迷雾在最上（雾压住疆域，否则未探明区域的边界
## 会把迷雾的形状泄底）。合在 [method draw] 里就没法把地区插进中间。[br]
## [br][b]铺的矩形 = 可视区域[/b]（[param p_visible_rect]）：地图铺满整块画布、左右
## 不再有纯黑带。[br]
## [br][param p_host] 绘制宿主（渲染器）；[param p_map_id] 当前地图 ID（插画；
## 空/未登记走纯底色）。
func draw_terrain(p_host: Control, p_visible_rect: Rect2, p_map_id: StringName) -> void:
	if p_visible_rect.size.x <= 0.0 or p_visible_rect.size.y <= 0.0:
		return
	Terrain.draw(p_host, p_visible_rect.grow(Style.GROUND_MARGIN), p_map_id)


## 画迷雾遮罩（地面层的[b]上半[/b]）——压在地区与节点之下、地形之上。[br]
## [br][b]★ 本轮起迷雾跟随[b]地区边界[/b]，不再是一块矩形挖孔 ★[/b]（老板 2026-11-27
## 「没探明的地方看不清」+ 任务书「覆盖跟随地区边界、必须连续」）：雾 = 所有 FOGGED
## 地区的[b]并集[/b]向内羽化。并集这一步让相邻未探明地区之间的接缝从根上消失——两块
## 雾若各自羽化，共边处两侧都是最浅的一档，会亮出一条线（看起来像一条能走的路）。
## 细读见 [NodeGraphFogRegion]。[br]
## [br][b]铺的范围不再由内容矩形决定[/b]：雾只铺在真正未探明的地区上，探明的孔不再需要
## 「挖」——没有雾多边形的地方自然透出地形。旧的「矩形减 24 个圆孔」整套做法连同
## [constant NodeGraphStyle.FOG_MARGIN] 的铺满口径一并退场。[br]
## [br][param p_no_fog] 是否「无迷雾」（雾中地区集为空）；[param p_cells] 地区分块表；
## [param p_states] 六态映射。
func draw_fog(p_host: Control, p_no_fog: bool, p_cells: Dictionary,
		p_states: Dictionary) -> void:
	if p_no_fog or p_cells.is_empty():
		return
	var layers: Dictionary = layers_for(p_cells, p_states)
	if (layers.get("rings", []) as Array).is_empty():
		return
	FogRegion.draw_fog_union(p_host, layers.get("rings", []), Style.FOG_COLOR.a,
			Style.FOG_FEATHER_STEPS)


## 迷雾几何（并集 + 羽化环，带缓存——见 [member _fog_layers]）。[br]
## [br][b]失效口径[/b]：与 [member _fog_key] 比对——键是「雾中地区 ID 列表 + 这些地区的
## 分块几何」的字符串指纹。[br]
## [br][b]为什么用指纹而不是「在 set_states 里手动置脏」[/b]：雾中集合由六态与 visited /
## current_node 共同决定，逐个追着置脏迟早漏一处——而漏了的表现是「雾没跟着消散」
## （本项目在迷雾上踩过的同类 bug）。[br]
## [br][b]为什么拖画布不会让缓存失效[/b]：进键的是分块几何与六态，两者都只随布局变；
## 平移到哪都一样。[br]
## [br][b]公开[/b]：渲染器的 [code]fog_geometry_steps[/code] 转发本方法，
## 单测据此断言「同一份输入只算一次」。[br]
## [br][b]返回[/b]：[code]{union: Array, rings: Array, ids: Array}[/code]。
func layers_for(p_cells: Dictionary, p_states: Dictionary) -> Dictionary:
	var ids: Array = FogRegion.fogged_ids(p_cells, p_states)
	var key: String = "%s|%s" % [str(ids), _geometry_fingerprint(p_cells, ids)]
	if key == _fog_key:
		return _fog_layers
	_fog_key = key
	var union: Array = FogRegion.union_of(p_cells, ids)
	_fog_layers = {
		"ids": ids,
		"union": union,
		"rings": FogRegion.feather_rings(union, Style.FOG_FEATHER_BAND,
				Style.FOG_FEATHER_STEPS),
	}
	return _fog_layers


## 分块几何指纹（只取雾中那几块——全表进键会让「亮着的地动了」也误报失效）。[br]
## [br][b]为什么指数字节数而不是逐顶点拼字符串[/b]：顶点有几百个，逐点拼串的代价与被
## 缓存的那次多边形运算同量级；顶点数与各点坐标做一次滚动混合即可——它只需要「变了
## 就不同」，不需要抗碰撞。
static func _geometry_fingerprint(p_cells: Dictionary, p_ids: Array) -> String:
	var h: int = 0
	for node_id: int in p_ids:
		var poly: PackedVector2Array = p_cells.get(node_id, PackedVector2Array())
		h = (h * 31 + poly.size()) & 0x7FFFFFFF
		for p: Vector2 in poly:
			h = (h * 31 + int(round(p.x * 4.0))) & 0x7FFFFFFF
			h = (h * 31 + int(round(p.y * 4.0))) & 0x7FFFFFFF
	return str(h)
