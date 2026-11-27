extends RefCounted
## NodeGraphGroundLayer —— 节点图的[b]地面层[/b]：地形底图 + 迷雾遮罩（含多边形挖孔缓存）。[br]
##
## [b]为什么单独成文件[/b]：[code]node_graph_renderer.gd[/code] 此前已越过单文件
## 300 行软上限（coding-standards），本轮地图化又给它加了地形与真挖孔两段；而
## 「画布垫什么、雾盖在哪」与「节点怎么画、点得中点不中」是两件事——前者是[b]地面[/b]，
## 后者是[b]浮在地面上的东西[/b]。[br]
##
## [br][b]为什么地形与迷雾合成一层[/b]：两者是同一支笔的先后两笔——挖孔之后
## 「孔里露出的就是地形」，地形若不先铺在底下，孔里就是画布底色而不是地图。
## 顺序（地形 → 遮罩）与共享的 [constant NodeGraphStyle.GROUND_MARGIN] /
## [constant NodeGraphStyle.FOG_MARGIN] 都收在本层，分开写迟早会分叉。[br]
## [br][b]但两者的矩形[b]不同源[/b][/b]（第二轮地图化）：地形按[b]可视区域[/b]铺
## （铺满画布、左右无黑带），迷雾按[b]内容包围盒[/b]铺（只压还没走到的那片山域）。
## 见 [method draw] 的注记。[br]
##
## [br][b]持有缓存，但不持游戏状态[/b]（ADR-0031 §2）：[member _fog_polygons] 是
## 纯几何换算的结果缓存（[method NodeGraphLayout.fog_polygons]），输入是渲染器给的
## 快照；没有任何玩法状态住在这里。[br]
##
## 来源: 本轮任务书任务三（背景铺图 + 迷雾不破坏）、ADR-0031 §2/§5、
## design/gdd/exploration-ui-system.md §2。

## 视觉规格（尺寸/配色常量唯一来源）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")
## 几何换算（迷雾多边形裁剪，纯函数）。
const Layout := preload("res://src/ui/exploration/node_graph_layout.gd")
## 地形底图绘制（插画 + 压暗 + 暗角）。
const Terrain := preload("res://src/ui/exploration/node_graph_terrain.gd")
## 迷雾遮罩绘制（柔边分层——三角汤，凹多边形一次画完）。
const Painter := preload("res://src/ui/exploration/node_graph_fog_painter.gd")

## 迷雾[b]柔边分层[/b]缓存（[code]Array[Array[PackedVector2Array]][/code]，
## 由外向内——最后一层最深）。[br]
## [br][b]为什么必须缓存[/b]：[method NodeGraphLayout.fog_feather_layers] 要逐层做
## [method Geometry2D.clip_polygons]（实测 24 孔 × 20 边形 ≈ 1.2ms，12 层即十余毫秒），
## 每帧重算会吃掉整个帧预算；而它只在「已揭示集合 / 内容矩形变了」时才需重算
## （迷雾按[b]内容包围盒[/b]铺，不跟着视口平移——所以拖动画布不会让缓存失效）。
var _fog_layers: Array = []
## 上次算雾分层时的输入指纹（见 [member _fog_layers]）。
var _fog_key: String = ""


## 画整块地面：地形 → 迷雾遮罩（顺序即语义——遮罩压在地形之上、连线之下）。[br]
## [br][b]★ 两个矩形不同源，这是刻意的 ★[/b]（第二轮地图化）：[br]
##   - 地形按 [param p_visible_rect]（可视区域）铺——地图铺满整块画布，左右不再有
##     纯黑带；[br]
##   - 迷雾按 [param p_content_rect]（内容包围盒）铺——雾只压「还没走到的那片山域」，
##     而山域的边界是节点图本身，不是屏幕。[br]
## 把迷雾也铺满视口会得到「除已揭示节点周围一小圈之外全屏皆雾」——开局只有 5 个
## 节点揭示，整幅图压成一片近黑（左右竖带「亮度>60 占比」实测 0.00%，与第一轮的
## 纯黑带读数一模一样）。详见 [constant NodeGraphStyle.FOG_MARGIN] 的注记。[br]
## [br][param p_host] 绘制宿主（渲染器）。[br]
## [param p_visible_rect] 可视区域（渲染器局部坐标——见
## [method NodeGraphRenderer.visible_local_rect]）。[br]
## [param p_content_rect] 内容包围盒（节点中心并集外扩一个节点尺寸）。[br]
## [param p_map_id] 当前地图 ID（地形插画；空/未登记走纯底色）。[br]
## [param p_no_fog] 是否「无迷雾」（迷雾节点集为空）。[br]
## [param p_revealed] 已揭示节点位置列表（挖孔圆心）。[br]
## [br][b]注意[/b]：本方法[b]不画连线也不画节点[/b]——调用方（渲染器）负责顺序。
func draw(p_host: Control, p_visible_rect: Rect2, p_content_rect: Rect2,
		p_map_id: StringName, p_no_fog: bool, p_revealed: Array) -> void:
	if p_visible_rect.size.x <= 0.0 or p_visible_rect.size.y <= 0.0:
		return
	Terrain.draw(p_host, p_visible_rect.grow(Style.GROUND_MARGIN), p_map_id)
	if p_content_rect.size == Vector2.ZERO:
		return
	var fog_area: Rect2 = p_content_rect.grow(Style.FOG_MARGIN)
	Painter.draw_fog(p_host, p_no_fog, layers_for(fog_area, p_revealed))


## 迷雾柔边分层（带缓存——见 [member _fog_layers]）。[br]
## [br][b]失效口径[/b]：与 [member _fog_key] 比对——键是「铺满矩形 + 已揭示位置
## 列表」的字符串指纹，两者都没变就直接复用。[br]
## [br][b]为什么用指纹而不是「在 set_states 里手动置脏」[/b]：揭示集合由六态、
## visited、current_node 三处共同决定，逐个追着置脏迟早漏一处——而漏了的表现是
## 「雾没跟着消散」（本项目在迷雾上踩过的同类 bug）。[br]
## [br][b]为什么拖画布不会让缓存失效[/b]：进键的是迷雾矩形
## [code]content_rect.grow(FOG_MARGIN)[/code]——它以[b]内容包围盒[/b]为准，与
## 视口的 [code]zoom[/code] / [code]offset[/code] 无关，平移到哪都一样；键真正会变的
## 时机只有「揭示集合变了」与「换图重布局了」。地形虽然跟着视口走，但它不参与挖孔、
## 不进缓存（[method NodeGraphTerrain.draw] 每帧现算 cover 矩形，只是一次乘除）。[br]
## [br][b]公开[/b]：渲染器的 [code]fog_polygon_cache_size[/code] 转发本方法，
## 单测据此断言「同一份输入只算一次」。[br]
## [br][b]返回[/b]：分层数组（层内是多边形数组；已揭示为空时每层都是整块矩形本身）。
func layers_for(p_area: Rect2, p_revealed: Array) -> Array:
	var key: String = "%s|%s" % [str(p_area), str(p_revealed)]
	if key == _fog_key:
		return _fog_layers
	_fog_key = key
	_fog_layers = Layout.fog_feather_layers(p_area, p_revealed, Style.FOG_HOLE_RADIUS,
			Style.FOG_FEATHER_BAND, Style.FOG_FEATHER_STEPS)
	return _fog_layers
