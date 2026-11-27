extends RefCounted
## NodeGraphNodePainter —— 单个节点的绘制（legacy + 六态两条分支，纯绘制）。[br]
## [br][b]为什么单独成文件[/b]：[code]node_graph_renderer.gd[/code] 越过单文件
## 300 行软上限（coding-standards）；「一个节点长什么样」占了其中一半篇幅，
## 且与布局、输入、命中检测都没有交集。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不持任何状态——宿主（渲染器）
## 作为 [param p_host] 传入，只[b]读[/b]它的渲染输入快照（nodes/states/visited/…）
## 并把画笔落在它身上。[br]
## [br][b]两条绘制分支[/b]：[method draw_node] 按宿主 [code]states[/code] 是否注入
## 分派六态 / legacy——两条路径互斥，Story 001 基准回归零风险。[br]
## [br]来源: ADR-0031 §5 合批、design/gdd/exploration-ui-system.md §2、
## exploration-ui Story 001 / 003。

## 图集（节点图标 region 与类型主色——唯一纹理来源，禁止独立纹理）。
const NodeIconAtlasScript := preload("res://src/ui/exploration/node_icon_atlas.gd")
## 六态样式查询（判定纯函数——绘制侧只消费）。
const NodeStateLogicScript := preload("res://src/ui/exploration/node_state_logic.gd")
## 视觉规格（尺寸/配色常量）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")
## 地标造型与两行文字（地盘 + 地名/类型——从本文件拆出，见类文档）。
const Landmark := preload("res://src/ui/exploration/node_graph_landmark.gd")


## 单节点绘制入口——按宿主是否注入六态分派。[br]
## [br][b]逐层浮现（AC-1）不在这里过滤[/b]：哪些层已显现由渲染器的绘制循环决定
## （与 [method NodeGraphLayout.is_layer_revealed] 同源判定，命中检测也用同一份
## ——可见性与可点性不会打架）；本方法被调用即绘制。
static func draw_node(p_host: Control, p_node_id: int) -> void:
	if p_host.states.has(p_node_id):
		draw_stated(p_host, p_node_id)
	else:
		draw_legacy(p_host, p_node_id)


## Legacy 分支（Story 001 基准——states 未注入时行为与 001 完全一致）。
static func draw_legacy(p_host: Control, p_node_id: int) -> void:
	var pos: Vector2 = p_host.call(&"get_node_position", p_node_id)
	var rect := Rect2(pos.x - Style.NODE_SIZE * 0.5, pos.y - Style.NODE_SIZE * 0.5,
			Style.NODE_SIZE, Style.NODE_SIZE)
	var detail: Dictionary = p_host.nodes.get(p_node_id, {})
	var type_id: int = int(detail.get("type", 1))
	var fogged: bool = p_host.call(&"_is_fogged", p_node_id)

	# 地标底盘（本轮地图化——投影 + 石台，画在图标[b]之下[/b]，见 [NodeGraphLandmark]）
	Landmark.draw_plate(p_host, rect, pos)

	# 图标：迷雾节点不显示类型——统一灰底（类型不暴露，GDD 界面规则）
	if fogged:
		draw_fogged_glyph(p_host, rect, pos)
		# 迷雾个体暗纱——遮罩现在画在节点[b]之下[/b]，这一格得自己压暗，
		# 「亮的=知道 / 暗的=还没走到」才读得出来（见 [method draw_fog]）。
		p_host.draw_rect(rect, Style.FOG_NODE_VEIL_COLOR)
	else:
		# 类型色光晕（与六态分支同款——legacy 路径也要能从暗背景里跳出来）
		var halo: Color = NodeIconAtlasScript.get_color(type_id)
		p_host.draw_rect(rect.grow(Style.TYPE_BACKDROP_GROW),
				Color(halo.r, halo.g, halo.b, Style.TYPE_BACKDROP_ALPHA))
		blit_region(p_host, rect, NodeIconAtlasScript.get_region(type_id))

	# 边框：当前 > 已访问 > 类型色暗化
	var border_color: Color = Style.NODE_DEFAULT_BORDER
	if p_node_id == p_host.current_node:
		border_color = Style.NODE_CURRENT_BORDER
	elif p_host.visited.has(p_node_id):
		border_color = Style.NODE_VISITED_BORDER
	elif not fogged:
		border_color = NodeIconAtlasScript.get_color(type_id).darkened(0.25)
	p_host.draw_rect(rect, border_color, false, Style.BORDER_WIDTH)

	# 两行文字（缩放联动——50% 隐藏）：地名恒显，类型行迷雾时不画
	if p_host.show_labels:
		Landmark.draw_labels(p_host, _place_of(p_host, p_node_id), detail, pos,
				Style.NODE_SIZE, not fogged, type_id)


## 六态分支——样式经 [NodeStateLogic.node_state_style] 查询后逐项渲染。[br]
## [b]悬停放大[/b]（AC-5）：悬停的可达节点按 [constant Style.HOVER_SCALE_RATIO] 放大
## 绘制（图标 + 边框 + 外发光同步放大——单一视觉来源在渲染层）。
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
	Landmark.draw_plate(p_host, rect, pos)

	if fogged:
		draw_fogged_glyph(p_host, rect, pos)
		# 迷雾个体暗纱——遮罩画在节点[b]之下[/b]（见 [method draw_fog]），
		# 这一格得自己压暗，「亮的=知道 / 暗的=还不知道」才读得出来。
		p_host.draw_rect(rect, Style.FOG_NODE_VEIL_COLOR)
	else:
		draw_type_icon(p_host, rect, style, type_id)

	draw_glow(p_host, style, type_id, pos, node_size, fogged)

	# 边框：border_is_type 时用类型主色，否则用样式边框色；
	# 强调态（当前/可达/已访问）加粗一档——见 [NodeStateLogic.node_state_style] 的 emphasis
	var border_color: Color = style.get("border", Style.NODE_DEFAULT_BORDER)
	if bool(style.get("border_is_type", false)):
		border_color = NodeIconAtlasScript.get_color(type_id)
	var border_width: float = Style.EMPHASIS_BORDER_WIDTH \
			if bool(style.get("emphasis", false)) else Style.BORDER_WIDTH
	p_host.draw_rect(rect, border_color, false, border_width)

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
	draw_state_marker(p_host, str(style.get("marker", "")), pos, rect, node_size)

	# 键盘焦点环（A3——松石青外环；鼠标悬停优先显示——ADR-0031 §4）
	if p_node_id == p_host.focused_node and p_node_id != p_host.hovered_node:
		p_host.draw_arc(pos, node_size * 0.5 + Style.FOCUS_RING_MARGIN, 0.0, TAU,
				Style.FOCUS_RING_SEGMENTS, Style.FOCUS_RING_COLOR, Style.BORDER_WIDTH)

	# 两行文字（缩放联动——50% 隐藏）：地名恒显，类型行迷雾时不画
	# 锚点跟随悬停缩放（终审 LOW）——放大时标签仍贴合图标下沿，不出现错位
	if p_host.show_labels:
		Landmark.draw_labels(p_host, _place_of(p_host, p_node_id), detail, pos,
				node_size, not fogged, type_id)


## 迷雾节点图标——灰底方块 + ❓图集 region（类型不暴露）。
static func draw_fogged_glyph(p_host: Control, rect: Rect2, pos: Vector2) -> void:
	p_host.draw_rect(rect, Style.FOGGED_FILL_COLOR)
	var half: float = Style.FOG_GLYPH_SIZE * 0.5
	var glyph_rect := Rect2(pos.x - half, pos.y - half,
			Style.FOG_GLYPH_SIZE, Style.FOG_GLYPH_SIZE)
	blit_region(p_host, glyph_rect,
			NodeIconAtlasScript.get_region(Style.FOG_GLYPH_REGION_COL))


## 类型图标 + 状态底衬 + 状态暗纱。[br]
## [br][b]底衬画在图标之下[/b]：图标是节点类型的信息，底衬是「这格有主了」的信息，
## 底衬盖住图标就等于用状态把类型抹掉了。[br]
## [br][b]四层顺序[/b]（由下到上）：类型色光晕（外扩一圈，让图标从暗背景里跳出来）
## → 状态底衬（实色块——走过/当前）→ 图标本体 → 状态暗纱（veil——按态压暗）。[br]
## [br][b]为什么先画类型色光晕[/b]：节点图标本身就是一块类型色的方片，在深色画布上
## 边缘与背景对比弱；外扩一圈同色半透明带出一圈「光晕」，14 种类型在缩到 50%
## 时也能靠色相区分，而不用凑近读字形。[br]
## [br][b]暗纱压多少（veil）[/b]：由 [NodeStateLogic.node_state_style] 的
## [code]veil[/code] 键给出——当前/可达 0（全亮）、已访问 0.35、不可达 0.55、
## 行动力不足 0.70、迷雾 0.85。亮度本身是一层信息：三米外不用读图标就能分出
## 「跟我有关的亮着 / 跟我无关的暗下去」。已访问的 [code]dim[/code] 与 veil 同值
## 同源（0.35），保留 dim 键只是为既有断言与 legacy 读法留路。
static func draw_type_icon(p_host: Control, rect: Rect2, style: Dictionary,
		type_id: int) -> void:
	var halo: Color = NodeIconAtlasScript.get_color(type_id)
	p_host.draw_rect(rect.grow(Style.TYPE_BACKDROP_GROW),
			Color(halo.r, halo.g, halo.b, Style.TYPE_BACKDROP_ALPHA))
	var plate: Color = style.get("plate", Color.TRANSPARENT)
	if plate.a > 0.0:
		p_host.draw_rect(rect.grow(2.0), plate)
	blit_region(p_host, rect, NodeIconAtlasScript.get_region(type_id))
	# 状态暗纱（AC-4——已访问稍暗；本轮扩展到六态，见上方注记）
	var veil: float = float(style.get("veil", 0.0))
	if veil > 0.0:
		p_host.draw_rect(rect, Color(0.0, 0.0, 0.0, veil))


## 外发光——可达脉冲 / 当前节点金环 / 渡劫台类型恒常金脉冲（三者独立叠加）。
static func draw_glow(p_host: Control, style: Dictionary, type_id: int,
		pos: Vector2, node_size: float, fogged: bool) -> void:
	# 可达节点脉冲外发光（AC-2）——外圈半透光环（静态近似；脉动动画归手动证据）
	if str(style.get("glow", "")) == "pulse_blue":
		p_host.draw_circle(pos, node_size * 0.5 + 4.0, Style.REACHABLE_GLOW_COLOR)
	if str(style.get("glow", "")) == "gold":
		p_host.draw_circle(pos, node_size * 0.5 + 3.0, Style.GOLD_GLOW_COLOR)
	# 渡劫台金色脉冲（AC-11——类型恒常视觉，与当前节点 gold 发光独立叠加；
	# 精英红边框已由 border_is_type 类型主色覆盖）
	if type_id == Style.TRIBULATION_TYPE and not fogged:
		p_host.draw_circle(pos, node_size * 0.5 + 5.0, Style.TRIBULATION_GLOW_COLOR)


## 状态标记绘制——[code]player[/code]（人形）/ [code]check[/code]（✓）/
## [code]lock[/code]（🔒）/ [code]question[/code]（❓）。
static func draw_state_marker(p_host: Control, marker: String, pos: Vector2,
		rect: Rect2, node_size: float) -> void:
	match marker:
		"player":
			# 人形图标：头 + 身（金色玩家标记，AC-1 当前节点）
			p_host.draw_circle(pos + Vector2(0.0, -10.0), 5.0, Style.NODE_CURRENT_BORDER)
			p_host.draw_rect(Rect2(pos.x - 6.0, pos.y - 2.0, 12.0, 12.0),
					Style.NODE_CURRENT_BORDER)
		"check":
			# ✓ 标记（AC-4 已访问）——两段折线
			var c: Vector2 = pos + Vector2(-7.0, 2.0)
			p_host.draw_line(c, c + Vector2(5.0, 6.0), Style.NODE_VISITED_BORDER,
					Style.BORDER_WIDTH)
			p_host.draw_line(c + Vector2(5.0, 6.0), c + Vector2(14.0, -6.0),
					Style.NODE_VISITED_BORDER, Style.BORDER_WIDTH)
		"lock":
			# 🔒 标记（AC-5 不可达）——锁体 + 锁梁
			p_host.draw_rect(Rect2(pos.x - 7.0, pos.y - 1.0, 14.0, 11.0),
					Style.MARKER_GRAY)
			p_host.draw_arc(pos + Vector2(0.0, -1.0), 6.0, PI, TAU, 12,
					Style.MARKER_GRAY, Style.BORDER_WIDTH)
		"question":
			# ❓ 标记（AC-6 迷雾）——沿用图集问号环已在图标层绘制，此处补文字
			pass


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


## 悬停 tooltip（AC-10）——名称 + 描述 + 敌人详情；迷雾显示「?」。[br]
## [br][b]内容源[/b]：[NodeStateLogic.tooltip_text] 纯函数（迷雾判定以六态 FOGGED
## 为准——与渲染器的迷雾集合同源，不会出现「节点画成亮的、tooltip 说不知道」）。[br]
## [br][b]空文案不画[/b]：没有可说的内容时连盒子都不建（免得悬停出一个空格子）。
static func draw_hover_tooltip(p_host: Control, p_node_id: int) -> void:
	var detail: Dictionary = p_host.nodes.get(p_node_id, {})
	var fogged: bool = false
	if p_host.states.has(p_node_id):
		fogged = int(p_host.states[p_node_id]) == NodeStateLogicScript.NodeState.FOGGED
	else:
		fogged = p_host.call(&"_is_fogged", p_node_id)
	var text: String = NodeStateLogicScript.tooltip_text(detail, fogged)
	if text.is_empty():
		return
	var pos: Vector2 = p_host.call(&"get_node_position", p_node_id)
	# tooltip 盒子锚定在节点上方（画布局部坐标——随 renderer.scale 缩放）
	var anchor := Vector2(pos.x - Style.NODE_SIZE * 0.5,
			pos.y - Style.NODE_SIZE * 0.5 - Style.TOOLTIP_ANCHOR_OFFSET)
	var box: Rect2 = tooltip_rect(text, anchor)
	p_host.draw_rect(box, Style.TOOLTIP_BG_COLOR)
	p_host.draw_rect(box, Style.TOOLTIP_BORDER_COLOR, false, 1.0)
	p_host.draw_string(label_font(p_host),
			box.position + Vector2(Style.TOOLTIP_PADDING, Style.TOOLTIP_BASELINE),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.LABEL_FONT_SIZE)


## tooltip 盒子尺寸估算——按文本字符数 × 字体宽度近似（stub；真实测量归
## 字体资产管线）。[br][b]返回[/b]: 以 [param anchor] 为左上角的矩形。
static func tooltip_rect(text: String, anchor: Vector2) -> Rect2:
	var width: float = maxf(Style.TOOLTIP_MIN_WIDTH,
			float(text.length()) * Style.TOOLTIP_CHAR_WIDTH
			+ Style.TOOLTIP_PADDING * 2.0)
	return Rect2(anchor, Vector2(width, Style.TOOLTIP_HEIGHT))


## 迷雾整体覆盖层（AC-3 合批验证核心）。[br]
## [br][b]一块遮罩 + 已揭示区域[b]真挖孔[/b][/b]（本轮地图化改写）：遮罩面本身是
## [param p_polygons]（内容矩形被逐孔裁掉之后剩下的块），孔里露出的是下面的
## [b]地图地形[/b]。[br]
## [br][b]为什么不能再用「画一块矩形 + 用底色圆盖回去」[/b]：那套做法要求挖孔色
## 等于画布底色——而画布现在是一张地图插画，底色圆会在插画上糊出一圈纯色补丁，
## 1920×1080 取证图里每个已揭示节点都像贴了块膏药。真正的挖孔只能靠多边形裁剪
## （[method NodeGraphLayout.fog_polygons]），孔不带色，孔里就是地形。[br]
## [br][b]★ 为什么本方法必须画在连线之上、节点之下 ★[/b]：遮罩负责「雾里 / 雾外」
## 的底色落差，压在[b]连线[/b]上结构才不泄露；节点浮在其上（亮），迷雾节点由
## [method draw_fogged_glyph] 那条路自己叠个体暗纱（暗）——三件事各归各位。
## 画在节点之上会把 14 种类型色全糊掉（那一版实测整幅平均亮度 10.75，几乎全黑）。[br]
## [br][param p_host] 绘制宿主。[br]
## [param p_no_fog] 是否「无迷雾」——true 时整块遮罩都不画。[br]
## [param p_polygons] 遮罩多边形（已挖孔；空 = 全揭示，同样不画）。[br]
## [br][b]为什么没有「铺满的矩形」参数[/b]：遮罩的范围由 [param p_polygons] 自身
## 界定（[method NodeGraphLayout.fog_polygons] 是「矩形减去孔」的结果，矩形信息
## 已在其中）；早先版本多收一个 [code]Rect2[/code] 却从未读它——多一个参数就多一处
## 「两个调用方对同一个矩形各算一次」的分叉点，而那个矩形在
## [NodeGraphGroundLayer] 里恰好是必须与地形逐像素一致的那个。
static func draw_fog(p_host: Control, p_no_fog: bool,
		p_polygons: Array) -> void:
	if p_no_fog or p_polygons.is_empty():
		return  # 无迷雾——不产生任何绘制
	var points := PackedVector2Array()
	var indices := PackedInt32Array()
	for piece: PackedVector2Array in p_polygons:
		append_triangles(points, indices, piece)
	if indices.is_empty():
		return
	# [b]一次[/b]画完整块遮罩：顶点表 + 索引表直接交给底层三角数组。[br]
	# [br][b]为什么不用 [method CanvasItem.draw_polygon][/b]：它内部按[b]三角扇[/b]
	# 连点（0,1,2 / 0,2,3 / …），只对凸多边形成立——挖孔后的块是凹的，用它会连出
	# 一大堆跨孔的三角形，遮罩直接烂掉。[code]draw_colored_polygon[/code] 同样是凸的。
	# 三角化后的索引表只能走这一条路；Godot 自己的 [code]draw_polygon[/code] 走的也是它
	# （同一 RID、同一变换，绘制顺序不变）。[br]
	# [br][b]单色用长度 1 的色表[/b]：底层接受「1 个色」或「每顶点一个色」，前者省一份
	# 与顶点等长的数组。
	RenderingServer.canvas_item_add_triangle_array(p_host.get_canvas_item(),
			indices, points, PackedColorArray([Style.FOG_COLOR]))


## 把一块多边形三角化后[b]追加[/b]进顶点表 / 索引表（两个表都就地增长）。[br]
## [br][b]为什么是索引表而不是逐三角各画一笔[/b]：一个 24 孔的遮罩三角化后约四百个
## 三角，逐笔 [code]draw_colored_polygon[/code] 就是四百次绘制调用（预算 200 整帧，
## 见 R-05 基准）——拼成一张索引表后是[b]一次[/b]（ADR-0031 §5 合批口径）。[br]
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


## 图集 region 绘制——统一走 [NodeIconAtlas] 单图集（同纹理合批，R-02 §3 分组方案）。
static func blit_region(p_host: Control, rect: Rect2,
		region: Rect2) -> void:
	p_host.draw_texture_rect_region(NodeIconAtlasScript.get_atlas(), rect, region)


## 文字字体——主题默认（真实字体归美术资产管线）。
static func label_font(p_host: Control) -> Font:
	var theme_font: Font = p_host.get_theme_default_font()
	return theme_font if theme_font != null else ThemeDB.fallback_font
