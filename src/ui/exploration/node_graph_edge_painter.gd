extends RefCounted
## NodeGraphEdgePainter —— 节点图的[b]小径[/b]绘制（已走过 / 未走过 / 雾中三条路）。[br]
##
## [b]为什么单独成文件[/b]：[code]node_graph_renderer.gd[/code] 越过单文件 300 行软
## 上限（coding-standards），本轮地图化又给连线加了「踩实的路更宽」这根轴；而
## 「两个节点之间那条线长什么样」与「节点长什么样」（[NodeGraphNodePainter]）、
## 「画布垫什么」（[NodeGraphGroundLayer]）是三件互不相干的事。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：宿主（渲染器）作为 [param p_host] 传入，
## 本模块只[b]读[/b]它的渲染输入快照（graph / visited / positions）并把画笔落在它
## 身上——不缓存任何东西。[br]
##
## [br][b]两条轴区分走过 / 没走过[/b]（不只靠亮度）：线宽（[constant WALKED_WIDTH]
## vs [constant WIDTH]）+ 虚实（实线 vs 虚线）。色觉障碍下土黄与土灰可能同亮度，
## 宽度与虚实是另外两根独立的轴。[br]
##
## [br]来源: 本轮任务书任务三（路径画成踩出来的小径）、ADR-0031 §5 合批、
## design/gdd/exploration-ui-system.md §2。

## 视觉规格（尺寸/配色常量唯一来源）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")

## 小径线宽（px）——未走过的路。
const WIDTH: float = Style.EDGE_WIDTH
## 已走过小径的线宽（px）——踩实的路更宽。
const WALKED_WIDTH: float = Style.EDGE_WALKED_WIDTH
## 虚线段长（px）——未走过的路。
const DASH_LENGTH: float = Style.DASH_LENGTH


## 绘制全部连线。[br]
## [br][param p_host] 绘制宿主（渲染器——提供 [code]graph[/code] /
## [code]get_node_position[/code] / [code]_is_edge_visited[/code]）。[br]
## [param p_fogged] 迷雾覆盖的节点[b]位置[/b]列表（[method NodeGraphLayout.fogged_positions]
## 的结果——本模块不自己判迷雾，口径与挖孔同源）。[br]
## [br][b]为什么连线要自己判一次「两端是否都在雾里」[/b]：迷雾遮罩铺在连线[b]之下[/b]
## （顺序见 [method NodeGraphRenderer._draw] 注记），而遮罩只能整体压暗它覆盖的范围——
## 一条从雾外伸进雾里的线，两端处在遮罩的两种底色上，不在雾里的那半段仍要能读出来。[br]
## [br][b]为什么按位置判而不是按 ID[/b]：迷雾集合以坐标列表给出（它已经是渲染层的
## 口径），再按 ID 重判一次等于把同一个判定写两处。
static func draw_edges(p_host: Control, p_fogged: Array) -> void:
	for from_id: int in p_host.graph.keys():
		var from_pos: Vector2 = p_host.call(&"get_node_position", from_id)
		for to_id: int in p_host.graph[from_id]:
			var to_pos: Vector2 = p_host.call(&"get_node_position", to_id)
			if bool(p_host.call(&"_is_edge_visited", from_id, to_id)):
				p_host.draw_line(from_pos, to_pos, Style.EDGE_VISITED_COLOR, WALKED_WIDTH)
			elif _in_fog(p_fogged, from_pos, to_pos):
				draw_trail(p_host, from_pos, to_pos, Style.EDGE_FOGGED_COLOR)
			else:
				draw_trail(p_host, from_pos, to_pos, Style.EDGE_UNVISITED_COLOR)


## 一条连线的[b]两端[/b]是否都埋在雾里。[br]
## [br][b]返回[/b]: true 表示两端位置都在 [param p_fogged] 内。
static func _in_fog(p_fogged: Array, p_from: Vector2, p_to: Vector2) -> bool:
	return p_fogged.has(p_from) and p_fogged.has(p_to)


## 虚线段绘制——Godot 4.6 内建 [method CanvasItem.draw_dashed_line]
## （API 探测确认签名：from, to, color, width=-1, dash=2.0, aligned=true——dash 为段长）。
static func draw_trail(p_host: Control, p_from: Vector2, p_to: Vector2,
		p_color: Color) -> void:
	p_host.draw_dashed_line(p_from, p_to, p_color, WIDTH, DASH_LENGTH)
