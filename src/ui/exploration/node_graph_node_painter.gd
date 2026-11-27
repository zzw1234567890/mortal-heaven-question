extends RefCounted
## NodeGraphNodePainter —— 单个节点的绘制编排（legacy + 六态两条分支）。[br]
## [br][b]为什么单独成文件[/b]：[code]node_graph_renderer.gd[/code] 越过单文件
## 300 行软上限（coding-standards）；「一个节点长什么样」占了其中一半篇幅，
## 且与布局、输入、命中检测都没有交集。[br]
## [br][b]★ 本轮再拆一次：徽记那一笔去了 [NodeGraphNodeBadge] ★[/b]（追加地区层与
## 纸片提示后本文件抵到 300 行软上限）。拆的判据是[b]职责[/b]：本文件管「这个节点此刻
## 该画哪几笔、按什么顺序画」（编排），徽记文件管「一枚圆印、一道发光、一个标记本身
## 长什么样」（画法）。改一个标记的造型不必读编排，改绘制顺序不必读像素细节。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不持任何状态——宿主（渲染器）
## 作为 [param p_host] 传入，只[b]读[/b]它的渲染输入快照（nodes/states/visited/…）
## 并把画笔落在它身上。[br]
## [br][b]两条绘制分支[/b]：[method draw_node] 按宿主 [code]states[/code] 是否注入
## 分派六态 / legacy——两条路径互斥，Story 001 基准回归零风险。[br]
## [br]来源: ADR-0031 §5 合批、design/gdd/exploration-ui-system.md §2、
## exploration-ui Story 001 / 003、本轮任务书任务二（地区里的图标仍是圆印）。

## 徽记那一笔（图标 / 底衬 / 发光 / 标记 / 高亮——从本文件拆出，见类文档）。
const Badge := preload("res://src/ui/exploration/node_graph_node_badge.gd")
## 六态样式查询（判定纯函数——绘制侧只消费）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")
## 视觉规格（尺寸/配色常量）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")
## 地标造型与两行文字（地盘 + 地名/类型——从本文件拆出，见类文档）。
const Landmark := preload("res://src/ui/exploration/node_graph_landmark.gd")
## 类型主色（边框 [code]border_is_type[/code] 时取它）。
const NodeIconAtlasScript := preload("res://src/ui/exploration/node_icon_atlas.gd")


## 单节点绘制入口——按宿主是否注入六态分派。[br]
## [br][b]逐层浮现（AC-1）不在这里过滤[/b]：哪些层已显现由渲染器的绘制循环决定
## （与 [method NodeGraphLayout.is_layer_revealed] 同源判定，命中检测也用同一份
## ——可见性与可点性不会打架）；本方法被调用即绘制。
static func draw_node(p_host: Control, p_node_id: int) -> void:
	if p_host.states.has(p_node_id):
		draw_stated(p_host, p_node_id)
	else:
		draw_legacy(p_host, p_node_id)


## Legacy 分支（Story 001 基准——states 未注入时行为与 001 完全一致）。[br]
## [br][b]与六态分支的唯一区别是「样式从哪来」[/b]：这里由 visited / current_node /
## fogged 三个字段就地推出边框色与标记，六态分支查样式表。其余每一笔（地盘 → 图标 →
## 边框 → 标记 → 高亮 → 文字）的[b]顺序一字不差[/b]——两条路径的视觉差只该来自状态
## 判定，不该来自画法。
static func draw_legacy(p_host: Control, p_node_id: int) -> void:
	var pos: Vector2 = p_host.call(&"get_node_position", p_node_id)
	var rect := Rect2(pos.x - Style.NODE_SIZE * 0.5, pos.y - Style.NODE_SIZE * 0.5,
			Style.NODE_SIZE, Style.NODE_SIZE)
	var detail: Dictionary = p_host.nodes.get(p_node_id, {})
	var type_id: int = int(detail.get("type", 1))
	var fogged: bool = p_host.call(&"_is_fogged", p_node_id)

	# 地标底盘（本轮地图化——投影 + 石台，画在图标[b]之下[/b]，见 [NodeGraphLandmark]）
	# 老板 2026-11-27：「节点不需要圆点和方块」——石碑底盘与矩形边框都撤掉，
	# 图标本体直接压在舆图上，状态改由光晕与印章色表达。
	# Landmark.draw_plate(p_host, rect, pos)

	# 图标：迷雾节点不显示类型——统一灰底（类型不暴露，GDD 界面规则）
	# 未揭示节点也画图标（老板 2026-11-27：「每个节点要有图片」）——原先只画一个
	# 空圆环，读起来就是个圆点。压暗改用圆形暗纱，不再用方块遮罩。
	Badge.draw_type_icon(p_host, rect, {}, type_id)

	# 边框已撤（2026-11-27）——矩形框就是老板说的「方块」，状态改由图标本身表达。

	# 两行文字（缩放联动——50% 隐藏）：地名恒显，类型行迷雾时不画
	if p_host.show_labels:
		Landmark.draw_labels(p_host, _place_of(p_host, p_node_id), detail, pos,
				Style.NODE_SIZE, not fogged, type_id)

	# 悬停 / 键盘焦点统一高亮——legacy 路径同样有悬停（[method Badge.draw_highlight]）。
	Badge.draw_highlight(p_host, p_node_id, pos, Style.NODE_SIZE)


## 六态分支——样式经 [NodeStateLogic.node_state_style] 查询后逐项渲染。[br]
## [b]悬停放大[/b]（AC-5）：悬停的可达节点按 [constant Style.HOVER_SCALE_RATIO] 放大
## 绘制（图标 + 边框 + 外发光同步放大——单一视觉来源在渲染层）。[br]
## [br][b]为什么边框与斜线留在这里而不是进徽记模块[/b]：它们是「这一格此刻算什么」
## 的表达（状态轴），而徽记模块管的是「一枚印长什么样」；边框读的是样式表的
## [code]border[/code] / [code]emphasis[/code] 两键，属于[b]判定结果的消费[/b]，
## 与 draw_stated 的其余编排同处一室读起来才连得上。
static func draw_stated(p_host: Control, p_node_id: int) -> void:
	var style: Dictionary = NodeStateLogicScript.node_state_style(
			int(p_host.states[p_node_id]))
	var pos: Vector2 = p_host.call(&"get_node_position", p_node_id)
	# 悬停放大（AC-5）——仅可达态；鼠标悬停优先于键盘焦点（ADR-0031 §4）
	var scale_factor: float = p_host.call(&"get_node_draw_scale", p_node_id)
	var node_size: float = Style.NODE_SIZE * scale_factor
	var rect := Rect2(pos.x - node_size * 0.5, pos.y - node_size * 0.5,
			node_size, node_size)
	var detail: Dictionary = p_host.nodes.get(p_node_id, {})
	var type_id: int = int(detail.get("type", 1))
	var fogged: bool = bool(style.get("fogged", false))

	# 地标底盘（本轮地图化——投影 + 石台，画在图标[b]之下[/b]，见 [NodeGraphLandmark]）
	# 老板 2026-11-27：「节点不需要圆点和方块」——石碑底盘与矩形边框都撤掉，
	# 图标本体直接压在舆图上，状态改由光晕与印章色表达。
	# Landmark.draw_plate(p_host, rect, pos)

	# 未揭示节点也画图标（老板 2026-11-27）——压暗改用圆形暗纱，不用方块遮罩。
	Badge.draw_type_icon(p_host, rect, style, type_id)

	Badge.draw_glow(p_host, style, type_id, pos, node_size, fogged)

	# 边框已撤（2026-11-27）——矩形框就是老板说的「方块」；强调态由 draw_glow 的
	# 外发光强弱表达（emphasis 已在样式表里驱动 glow），不再画框。

	# 行动力不足红色斜线（AC-5）——渡劫台修为未满时跳过（灰斜线优先，避免
	# 同对角线重叠；未满语义「可进入不可触发」强于「行动力不足」）
	var unready: bool = is_tribulation_unready(p_host, detail)
	if bool(style.get("slash", false)) and not unready:
		p_host.draw_line(Vector2(rect.position.x, rect.end.y),
				Vector2(rect.end.x, rect.position.y),
				Style.AP_INSUFFICIENT_SLASH_COLOR, Style.BORDER_WIDTH)

	# 渡劫台「修为尚未圆满」——灰色斜线（AC-8 可进入不可触发）
	if unready:
		p_host.draw_line(Vector2(rect.position.x, rect.end.y),
				Vector2(rect.end.x, rect.position.y),
				Style.TRIBULATION_UNREADY_SLASH_COLOR, Style.BORDER_WIDTH)

	# 状态标记（玩家/✓/锁/❓——AC-1 逐项一致断言目标）
	Badge.draw_state_marker(p_host, str(style.get("marker", "")), pos, rect, node_size)

	# 悬停 / 键盘焦点统一高亮（A3 + AC-10——见 [NodeGraphRenderer.is_node_highlighted]）。
	# 鼠标与键盘走同一条通道，故两者画出来是同一套视觉（双输入对等）。
	Badge.draw_highlight(p_host, p_node_id, pos, node_size)

	# 两行文字（缩放联动——50% 隐藏）：地名恒显，类型行迷雾时不画
	# 锚点跟随悬停缩放（终审 LOW）——放大时标签仍贴合图标下沿，不出现错位
	if p_host.show_labels:
		Landmark.draw_labels(p_host, _place_of(p_host, p_node_id), detail, pos,
				node_size, not fogged, type_id)


## 节点地名——转引宿主 [code]NodeGraphRenderer.place_name_of[/code]。[br]
## [br][b]为什么不在绘制侧直取[/b]：地名的择优（覆盖表 > 地名池）是渲染器的一个
## 公开读法，测试与截图脚本断言的是同一处；绘制侧再判一次会出现「测到的名字和
## 画出来的名字不是一个」——而那种缺陷在截图上极难发现。[br]
## [br][b]宿主没有这个方法时回落空串[/b]（桩宿主：只验绘制的单测会传入裸 Control）——
## 空地名不画文字，不崩溃。
static func _place_of(p_host: Control, p_node_id: int) -> String:
	if not p_host.has_method(&"place_name_of"):
		return ""
	return str(p_host.call(&"place_name_of", p_node_id))


## 渡劫台「修为尚未圆满」判定（AC-8）——委托 [NodeStateLogic] 纯函数
## （渲染层仅消费判定结果——零状态所有权）。
static func is_tribulation_unready(p_host: Control, detail: Dictionary) -> bool:
	return NodeStateLogicScript.is_tribulation_not_ready(detail)
