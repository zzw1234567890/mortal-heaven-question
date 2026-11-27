extends "res://src/ui/exploration/node_graph_renderer_decl.gd"
## NodeGraphRenderer 地面层段（继承链中段）——[b]地形铺哪、迷雾挖在哪、谁在雾里[/b]。
##
## [b]为什么再拆一段[/b]：本轮给渲染器加「悬停/焦点统一高亮 + 悬停文案」两个方法，
## 链尾会顶破单文件 300 行软上限（coding-standards）。地面这一块恰好自成一事——
## 它只读快照算几何、把画笔交给 [NodeGraphGroundLayer]，与「什么时候画什么」
## （链尾的绘制编排）和「点得中不中」（命中检测）都没有交集。[br]
##
## [br][b]为什么插在中间而不是链尾之后[/b]：链尾必须留给带 [code]class_name[/code] 的
## 那一段（[code]NodeGraphRenderer[/code] 的对外身份在它身上），本段的职责是「渲染器
## 的进出水口之一」，放在声明面与编排面之间读起来才顺。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本段的方法全是「读快照 → 算几何 → 交给
## 绘制模块」，没有任何玩法状态住在这里；[member _ground] 持有的只是迷雾挖孔的几何缓存
## （输入是渲染快照，见 [NodeGraphGroundLayer]）。[br]
##
## [br]来源: ADR-0031 §2/§5、design/gdd/exploration-ui-system.md §2、
## [code]node_graph_ground_layer.gd[/code]（本轮任务书任务 A 的落点）。


## 地面层绘制——整块地图插画 + 压暗 + 暗角 + 迷雾遮罩（见 [NodeGraphGroundLayer]）。[br]
## [br][b]铺的矩形 = 可视区域[/b]（[method visible_local_rect]），不是内容包围盒。[br]
## [br][b]★ 两个矩形不同源 ★[/b]（第二轮地图化）：地形按[b]可视区域[/b]铺（地图铺满
## 整块画布、左右不再有黑带），迷雾按[b]内容包围盒[/b]铺（雾只压还没走到的那片山域）。
## 把迷雾也铺满视口会得到「除已揭示节点周围一小圈之外全屏皆雾」——开局只揭示 5 个
## 节点，整幅图会压成一片近黑。两个矩形的分工与读数见
## [constant NodeGraphStyle.FOG_MARGIN] 的注记。[br]
## [br][b]顺序语义[/b]：地面在连线[b]之下[/b]——遮罩压暗的是它盖住的连线，而孔里
## 露出的地形是亮的；节点再画在其上（见 [method _draw]）。
func _draw_ground() -> void:
	_ground.call(&"draw", self, visible_local_rect(), _content_rect, map_id,
			_fogged_positions().is_empty(), _revealed_positions())


## 当前[b]可视区域[/b]（渲染器局部坐标）——地形与迷雾的铺满矩形。[br]
## [br][b]换算[/b]：屏幕坐标 = 局部坐标 × zoom + offset（见 [NodeGraphViewport] 的
## 变换口径），故局部可视矩形 = [code](-offset / zoom, size / zoom)[/code]——
## 渲染器由 [code]PRESET_FULL_RECT[/code] 铺满视口，[member size] 就是视口尺寸。[br]
## [br][b]为什么由渲染器自己推[/b]：变换的两半（[code]zoom[/code]/[code]offset[/code]）
## 分别住在视口上，[member scale] 与 [member position] 是它们的写入结果——从自己的
## 变换反推可视区域，就不必给「谁把矩形传进来」再开一条跨模块的参数通道。[br]
## [br][b]退化保护[/b]：缩放为 0（进树前 / 折叠视口）时返回 [Rect2]，调用方据此跳过
## 绘制，免得除零炸出一片 NaN 顶点。[br]
## [br][b]返回[/b]：可视区域（位置本身可以为负，这正是「画布比视口大」的正常情形）。
func visible_local_rect() -> Rect2:
	if scale.x <= 0.0 or scale.y <= 0.0:
		return Rect2()
	return Rect2(-position.x / scale.x, -position.y / scale.y,
			size.x / scale.x, size.y / scale.y)


## 迷雾覆盖层数（带缓存——见 [member NodeGraphGroundLayer._fog_layers]）。[br]
## [br][b]为什么把这个口子留在渲染器上[/b]：单测要按「同一份输入只算一次」断言缓存
## 生效；实现体在 [NodeGraphGroundLayer]，本方法是纯转发。[br]
## [br][b]返回[/b]：柔边分层数（无迷雾时为 0）。[br]
## [br][b]★ 本轮修正（断链）★[/b]：此前本方法转发的名字是 [code]polygons_for[/code]——
## 那是 [NodeGraphGroundLayer] 从没提供过的方法（柔边改造时该方法已更名为
## [code]layers_for[/code]）。[method Object.call] 对不存在的方法返回 [code]null[/code]，
## 于是 [code].size()[/code] 会抛「Invalid call on null instance」——而全库没有任何测试
## 引用过它（只数到定义点），所以这个断链一直没被撞上。现按真名转发。[br]
## [br][b]名字为什么还叫 polygon[/b]：它数的是[b]挖孔那件事算出来的层[/b]，
## 语义没变；更名会牵动注释里已有的引用面，而修正转发目标才是这次修复的实质。
func fog_polygon_cache_size(p_area: Rect2) -> int:
	return (_ground.call(&"layers_for", p_area, _revealed_positions()) as Array).size()


## 节点是否迷雾覆盖（legacy 近似——六态注入时不走这里）。
func _is_fogged(node_id: int) -> bool:
	return Layout.is_fogged(graph, visited, current_node, node_id)


## 已揭示集合（legacy）：已访问 + 当前节点 + 当前节点的邻接（前向 + 后向）。
func _revealed_set() -> Array:
	return Layout.revealed_set(graph, visited, current_node)


## 迷雾覆盖的节点位置列表（AC-3 采样用——迷雾节点计数）。
func _fogged_positions() -> Array:
	return Layout.fogged_positions(graph, nodes, _positions, states, visited,
			current_node)


## 已揭示节点位置列表（迷雾挖孔位置）。
func _revealed_positions() -> Array:
	return Layout.revealed_positions(graph, nodes, _positions, states, visited,
			current_node)
