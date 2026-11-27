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


## 注入地名覆盖表（[code]{node_id: 地名}[/code]）——空字典回到地名池。[br]
## [br][b]为什么留这个口子[/b]：截图脚本与单测需要[b]确定性[/b]的地名（不随节点
## 排布变化），而真实地图的地名由池 + 节点 ID 决定（见
## [code]ExplorationPlaceCatalog.place_for[/code]）。覆盖表只影响绘制，不写任何状态。[br]
## [br][b]为什么住在中段[/b]：它与 [method place_name_of] 是一对（写覆盖 + 读地名），
## 两者读的是同一份 [member place_overrides]——分到两段里会让人以为可以只改一半。
func set_place_overrides(overrides: Dictionary) -> void:
	place_overrides = overrides
	queue_redraw()


## 节点地名（覆盖表优先，否则走地名池）——[b]绘制与断言共用的唯一入口[/b]。[br]
## [br][b]返回[/b]：地名（未登记地图为「无名之地 %d」）。
func place_name_of(node_id: int) -> String:
	if place_overrides.has(node_id):
		return str(place_overrides[node_id])
	var detail: Dictionary = nodes.get(node_id, {})
	return PlaceCatalogScript.place_for(map_id, node_id,
			int(detail.get("place_seed", 0)))


## 地形底图（绘制顺序的[b]第一层[/b]）——整块地图插画 + 压暗 + 暗角。[br]
## [br][b]铺的矩形 = 可视区域[/b]（[method visible_local_rect]），不是内容包围盒。[br]
## [br][b]★ 两个矩形不同源 ★[/b]（第二轮地图化）：地形按[b]可视区域[/b]铺（地图铺满
## 整块画布、左右不再有黑带），迷雾按[b]内容包围盒[/b]铺（雾只压还没走到的那片山域）。
## 把迷雾也铺满视口会得到「除已揭示节点周围一小圈之外全屏皆雾」——开局只揭示 5 个
## 节点，整幅图会压成一片近黑。两个矩形的分工与读数见
## [constant NodeGraphStyle.FOG_MARGIN] 的注记。[br]
## [br][b]★ 本轮拆成两次调用 ★[/b]：地区层（疆域底渍）必须画在地形[b]之上[/b]、迷雾
## [b]之下[/b]——合成一次调用就没地方插进去（见 [method _draw] 的顺序表）。
func _draw_terrain() -> void:
	_ground.call(&"draw_terrain", self, visible_local_rect(), map_id)


## 迷雾遮罩（绘制顺序的[b]第二层[/b]——地形之上、地区之下）。[br]
## [br][b]★ 本轮起迷雾 = 所有雾中地区的并集向内羽化 ★[/b]，不再是「矩形挖圆孔」：
## 雾跟随地区边界，相邻未探明地区之间无缝（并集让内部边界整体消失）。细读见
## [NodeGraphFogRegion] 与本方法转发到的 [method NodeGraphGroundLayer.draw_fog]。[br]
## [br][b]为什么需要分块表[/b]：并集是拿地区多边形并出来的——没有分块就没有疆域，
## 雾只能退回矩形。分块表由 [method _layout] 与节点坐标一起算好（见 [member cells]）。[br]
## [br][b]为什么排在地区[b]之下[/b][/b]：它压暗的是地形（山），不是疆域——地区那三笔
## 各有自己的六态压暗口径（[code]node_graph_style_region.gd[/code]），被遮罩盖住会
## 一律变黑，「这块地是什么态」当场读不出来。
func _draw_fog_mask() -> void:
	_ground.call(&"draw_fog", self, _fogged_positions().is_empty(), cells, states)


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


## 雾中地区数（带缓存——见 [member NodeGraphGroundLayer._fog_layers]）。[br]
## [br][b]为什么把这个口子留在渲染器上[/b]：单测要按「同一份输入只算一次」断言缓存
## 生效；实现体在 [NodeGraphGroundLayer]，本方法是纯转发。[br]
## [br][b]名字的历史[/b]：原名 [code]fog_polygon_cache_size(p_area)[/code]——它数的是
## 「挖孔那件事算出来的层数」，而旧实现在柔边改造时已更名为 [code]layers_for[/code]，
## 断链（[code]call[/code] 对不存在的方法返回 null，[code].size()[/code] 抛异常）却
## 一直没被撞上，因为全库没有测试引用它。本轮迷雾铺法整体换掉，本方法随之改名为
## 「几何档数」并按新口径回答「算出了几档羽化环」。[br]
## [br][b]返回[/b]：羽化环档数（无雾时为 0）。
func fog_geometry_steps() -> int:
	return (_ground.call(&"layers_for", cells, states) as Dictionary) \
			.get("rings", []).size()


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
