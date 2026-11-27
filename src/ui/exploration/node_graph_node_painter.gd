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

	# 文字标签（缩放联动——50% 隐藏）
	if p_host.show_labels and not fogged:
		draw_node_label(p_host, p_node_id, detail, type_id, pos, Style.NODE_SIZE)


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

	# 文字标签（缩放联动——50% 隐藏；迷雾不显示类型标签）
	# 锚点跟随悬停缩放（终审 LOW）——放大时标签仍贴合图标下沿，不出现错位
	if p_host.show_labels and not fogged:
		draw_node_label(p_host, p_node_id, detail, type_id, pos, node_size)


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


## 节点文字标签——类型短标签（入口/战斗/事件/商店/营地/入口/Boss…），
## 居中排在图标[b]正下方[/b]，锚点跟随悬停缩放（放大时仍贴合图标下沿）。[br]
## [br][b]为什么带描边[/b]：标签一半压在图标下沿、一半落在深色画布上，两侧底色
## 一深一亮，纯前景色在任一侧都会糊。先画一圈深色描边再画暖白字，两种底上都读得清。[br]
## [br][b]为什么居中不左对齐[/b]：左对齐的标签从图标左沿起笔，两字标签（战斗）
## 与三字标签（渡劫台）视觉重心各偏一边——居中让每个标签都以节点为轴。
static func draw_node_label(p_host: Control, p_node_id: int, detail: Dictionary,
		type_id: int, pos: Vector2, node_size: float) -> void:
	var label: String = str(detail.get("label",
			NodeIconAtlasScript.get_label(type_id)))
	var box_width: float = node_size * Style.LABEL_BOX_RATIO
	var anchor := Vector2(pos.x - box_width * 0.5,
			pos.y + node_size * 0.5 + Style.LABEL_BASELINE_OFFSET)
	var font: Font = label_font(p_host)
	p_host.draw_string_outline(font, anchor, label, HORIZONTAL_ALIGNMENT_CENTER,
			box_width, Style.LABEL_FONT_SIZE, Style.LABEL_OUTLINE_SIZE,
			Style.LABEL_OUTLINE_COLOR)
	p_host.draw_string(font, anchor, label, HORIZONTAL_ALIGNMENT_CENTER,
			box_width, Style.LABEL_FONT_SIZE, Style.LABEL_COLOR)


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


## 迷雾整体覆盖层——单节点绘制（AC-3 合批验证核心）。[br]
## [br][b]一块全画布遮罩 + 已揭示区域挖孔[/b]（[code]draw_rect[/code] 覆盖 +
## 挖孔以画布底色圆近似——stub 实现；真实揭雾渐变动画归后续 story）。[br]
## [br][b]★ 为什么本方法必须画在节点之下 ★[/b]（[method NodeGraphRenderer._draw]
## 的调用顺序是本轮修的 bug 本体）：遮罩画在节点[b]之上[/b]时，挖孔用的是近黑
## 底色 [code]Color(0.08,0.09,0.12)[/code]——每个已揭示节点都被这层近黑圆盘
## 重涂了一遍，14 种类型色一个不剩。1920×1080 取证图里整幅只剩 1388 个金色
## 边缘像素，平均亮度 10.75（几乎全黑），底就是这里打下的。[br]
## [br]现在遮罩在节点之下：遮罩给出「雾里 / 雾外」的底色落差，节点画在其上，
## 已揭示的节点保持自己的亮度，迷雾节点由 [method draw_fogged_glyph] 那条路
## 自己叠一层个体暗纱（[constant Style.FOG_NODE_VEIL_COLOR]）。[br]
## [br][b]挖孔仍然要挖[/b]：遮罩压在[b]连线[/b]上，不挖孔的话已揭示区域的连线
## 会跟迷雾区域一样暗——走过的金色路径是玩家最该一眼看到的东西。
static func draw_fog(p_host: Control, p_content_rect: Rect2,
		p_fogged: Array, p_revealed: Array) -> void:
	if p_fogged.is_empty():
		return  # 无迷雾——不产生任何绘制
	var margin: Vector2 = Vector2(Style.FOG_MARGIN, Style.FOG_MARGIN)
	p_host.draw_rect(Rect2(p_content_rect.position - margin,
			p_content_rect.size + margin * 2.0), Style.FOG_COLOR)
	# 挖孔：已揭示区域以画布底色圆盖回遮罩——「把雾拿掉」，不是「再盖一层近黑」
	for hole_pos: Vector2 in p_revealed:
		p_host.draw_circle(hole_pos, Style.FOG_HOLE_RADIUS, Style.FOG_HOLE_COLOR)


## 图集 region 绘制——统一走 [NodeIconAtlas] 单图集（同纹理合批，R-02 §3 分组方案）。
static func blit_region(p_host: Control, rect: Rect2,
		region: Rect2) -> void:
	p_host.draw_texture_rect_region(NodeIconAtlasScript.get_atlas(), rect, region)


## 文字字体——主题默认（真实字体归美术资产管线）。
static func label_font(p_host: Control) -> Font:
	var theme_font: Font = p_host.get_theme_default_font()
	return theme_font if theme_font != null else ThemeDB.fallback_font
