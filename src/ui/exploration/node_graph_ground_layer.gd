extends RefCounted
## NodeGraphGroundLayer —— 节点图的[b]地面层[/b]：地形底图 + 迷雾遮罩（含多边形挖孔缓存）。[br]
##
## [b]为什么单独成文件[/b]：[code]node_graph_renderer.gd[/code] 此前已越过单文件
## 300 行软上限（coding-standards），本轮地图化又给它加了地形与真挖孔两段；而
## 「画布垫什么、雾盖在哪」与「节点怎么画、点得中点不中」是两件事——前者是[b]地面[/b]，
## 后者是[b]浮在地面上的东西[/b]。[br]
##
## [br][b]为什么地形与迷雾合成一层[/b]：两者的[b]覆盖范围必须逐像素一致[/b]
## （[code]content_rect.grow(FOG_MARGIN)[/code]）——地形比遮罩小一点，雾外就露出
## 没被地图盖住的底色边；分开两处算这个矩形，迟早会分叉。而且挖孔之后「孔里露出
## 的就是地形」，两者本来就是同一层的两个部分。[br]
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
## 迷雾遮罩绘制（三角汤——凹多边形一次画完）。
const Painter := preload("res://src/ui/exploration/node_graph_node_painter.gd")

## 迷雾覆盖区多边形缓存（[code]Array[PackedVector2Array][/code]）。[br]
## [br][b]为什么必须缓存[/b]：[method NodeGraphLayout.fog_polygons] 要逐孔做
## [method Geometry2D.clip_polygons]（实测 24 孔 × 20 边形 ≈ 1.2ms），每帧重算会
## 吃掉 16.6ms 帧预算的十分之一；而它只在「已揭示集合 / 内容矩形变了」时才需重算。
var _fog_polygons: Array = []
## 上次算雾多边形时的输入指纹（见 [member _fog_polygons]）。
var _fog_key: String = ""


## 画整块地面：地形 → 迷雾遮罩（顺序即语义——遮罩压在地形之上、连线之下）。[br]
## [br][param p_host] 绘制宿主（渲染器）。[br]
## [param p_content_rect] 内容包围盒（本层按 [code]Style.FOG_MARGIN[/code] 外扩）。[br]
## [param p_map_id] 当前地图 ID（地形插画；空/未登记走纯底色）。[br]
## [param p_no_fog] 是否「无迷雾」（迷雾节点集为空）。[br]
## [param p_revealed] 已揭示节点位置列表（挖孔圆心）。[br]
## [br][b]注意[/b]：本方法[b]不画连线也不画节点[/b]——调用方（渲染器）负责顺序。
func draw(p_host: Control, p_content_rect: Rect2, p_map_id: StringName,
		p_no_fog: bool, p_revealed: Array) -> void:
	if p_content_rect.size == Vector2.ZERO:
		return
	var margin: Vector2 = Vector2(Style.FOG_MARGIN, Style.FOG_MARGIN)
	var area := Rect2(p_content_rect.position - margin,
			p_content_rect.size + margin * 2.0)
	Terrain.draw(p_host, area, p_map_id)
	Painter.draw_fog(p_host, p_no_fog, polygons_for(area, p_revealed))


## 迷雾覆盖多边形（带缓存——见 [member _fog_polygons]）。[br]
## [br][b]失效口径[/b]：与 [member _fog_key] 比对——键是「铺满矩形 + 已揭示位置
## 列表」的字符串指纹，两者都没变就直接复用。[br]
## [br][b]为什么用指纹而不是「在 set_states 里手动置脏」[/b]：揭示集合由六态、
## visited、current_node 三处共同决定，逐个追着置脏迟早漏一处——而漏了的表现是
## 「雾没跟着消散」（本项目在迷雾上踩过的同类 bug）。[br]
## [br][b]公开[/b]：渲染器的 [code]fog_polygon_cache_size[/code] 转发本方法，
## 单测据此断言「同一份输入只算一次」。[br]
## [br][b]返回[/b]：多边形数组（已揭示为空时是整块矩形本身）。
func polygons_for(p_area: Rect2, p_revealed: Array) -> Array:
	var key: String = "%s|%s" % [str(p_area), str(p_revealed)]
	if key == _fog_key:
		return _fog_polygons
	_fog_key = key
	_fog_polygons = Layout.fog_polygons(p_area, p_revealed, Style.FOG_HOLE_RADIUS)
	return _fog_polygons
