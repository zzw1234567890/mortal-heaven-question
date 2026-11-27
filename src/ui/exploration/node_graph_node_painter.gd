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

## 图集（类型主色 / 类型短标签 / 迷雾❓占位——图集仍供着「色与字」）。
const NodeIconAtlasScript := preload("res://src/ui/exploration/node_icon_atlas.gd")
## 类型图标（14 张水墨线稿——「图」这一件事从图集 glyph 换成它，见模块文档）。
const NodeIconArtScript := preload("res://src/ui/exploration/node_icon_art.gd")
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
		# 类型图标（光晕 + 底衬 + 图标本体——与六态分支同一个入口，legacy 传空样式）
		draw_type_icon(p_host, rect, {}, type_id)

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

	# 悬停 / 键盘焦点统一高亮——legacy 路径同样有悬停（[method draw_highlight]）。
	draw_highlight(p_host, p_node_id, pos, Style.NODE_SIZE)


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

	# 悬停 / 键盘焦点统一高亮（A3 + AC-10——见 [NodeGraphRenderer.is_node_highlighted]）。
	# 鼠标与键盘走同一条通道，故两者画出来是同一套视觉（双输入对等）。
	draw_highlight(p_host, p_node_id, pos, node_size)

	# 两行文字（缩放联动——50% 隐藏）：地名恒显，类型行迷雾时不画
	# 锚点跟随悬停缩放（终审 LOW）——放大时标签仍贴合图标下沿，不出现错位
	if p_host.show_labels:
		Landmark.draw_labels(p_host, _place_of(p_host, p_node_id), detail, pos,
				node_size, not fogged, type_id)


## 迷雾节点图标——中性灰圆盘 + ❓图集 region（类型不暴露）。[br]
## [br][b]为什么这里仍用图集 glyph 而不是线稿[/b]：迷雾语义就是「你还不知道这儿是什么」，
## 给一张类型图标等于把类型泄露出去。14 张线稿里没有「未知」这一张，故❓继续走图集。[br]
## [br][b]为什么是圆盘而不是方块[/b]：本轮起已揭示节点是「圆形印章」，迷雾节点若还是
## 方块，同一张图上就并存两种形状语言；圆盘保持「每个节点都是一枚印」的统一读法，而
## 中性灰 + ❓仍然只回答「这儿有个东西」，不回答「是什么」。
static func draw_fogged_glyph(p_host: Control, rect: Rect2, pos: Vector2) -> void:
	p_host.draw_circle(rect.get_center(), rect.size.x * 0.5, Style.FOGGED_FILL_COLOR)
	var half: float = Style.FOG_GLYPH_SIZE * 0.5
	var glyph_rect := Rect2(pos.x - half, pos.y - half,
			Style.FOG_GLYPH_SIZE, Style.FOG_GLYPH_SIZE)
	blit_region(p_host, glyph_rect,
			NodeIconAtlasScript.get_region(Style.FOG_GLYPH_REGION_COL))


## 类型图标 + 状态底衬 + 状态暗纱。[br]
## [br][b]★ 合成顺序（由下到上，五层）★[/b]：[br]
##   1. 类型色光晕（圆形，外扩一圈——让节点从暗背景里跳出来）；[br]
##   2. 状态底衬（圆形——走过/当前的实色）；[br]
##   3. 图标深色底盘（圆形——压住地图插画的花纹，给线稿一个稳定对比底）；[br]
##   4. 图标本体（圆形水墨印章，不透明度 [constant Style.ICON_ALPHA]）；[br]
##   5. 状态暗纱（veil——按态压暗）。[br]
## [br][b]为什么「状态都在图标之下、暗纱在图标之上」[/b]：底衬与光晕回答的是「这格跟我
## 什么关系」，它们盖住图标就等于用状态把类型抹掉（类型也要读）；而暗纱是「压暗」不是
## 「覆盖」，它必须压在图标[b]之上[/b]才连图标一起压下去——否则已访问/不可达的节点
## 图标仍是全亮的，亮度这条状态轴就废了。[br]
## [br][b]为什么光晕与底衬是圆而不是方[/b]：方形光晕的四角会从圆盘后面露出来，「一枚
## 圆印」立刻读回「一个方块 + 一个圆」（反馈原话：「不能用简单的方块/圆圈/线条」）。[br]
## [br][b]暗纱压多少（veil）[/b]：由 [NodeStateLogic.node_state_style] 的
## [code]veil[/code] 键给出（逐态数值的唯一出处是那张表，此处不重复）。亮度本身是
## 一层信息：三米外不用读图标就能分出「跟我有关的亮着 / 跟我无关的暗下去」。[br]
## [br][b]暗纱为什么仍是方形[/b]：它压的是[b]整个节点格[/b]（含边框与文字所在的方块），
## 不是图标那一圈——按圆压会留下四角未压的亮块，反而更花。
static func draw_type_icon(p_host: Control, rect: Rect2, style: Dictionary,
		type_id: int) -> void:
	var center: Vector2 = rect.get_center()
	var half: float = rect.size.x * 0.5
	var halo: Color = NodeIconAtlasScript.get_color(type_id)
	p_host.draw_circle(center, half + Style.TYPE_BACKDROP_GROW,
			Color(halo.r, halo.g, halo.b, Style.TYPE_BACKDROP_ALPHA))
	var plate: Color = style.get("plate", Color.TRANSPARENT)
	if plate.a > 0.0:
		p_host.draw_circle(center, half + 2.0, plate)
	var edge: float = rect.size.x * Style.ICON_EDGE_RATIO
	p_host.draw_circle(center, edge * 0.5 * Style.ICON_DISC_SCALE,
			Style.ICON_DISC_COLOR)
	blit_type_icon(p_host, Rect2(center - Vector2(edge, edge) * 0.5,
			Vector2(edge, edge)), type_id)
	# 状态暗纱（AC-4——已访问稍暗；本轮扩展到六态，见上方注记）
	var veil: float = float(style.get("veil", 0.0))
	if veil > 0.0:
		p_host.draw_rect(rect, Color(0.0, 0.0, 0.0, veil))


## 类型图标本体——优先水墨印章（[NodeIconArt]），缺图回退图集 glyph。[br]
## [br][b]为什么要留回退[/b]：缺一张 PNG 在运行时不报错（只是画成旧样子），而「某个
## 类型永远没图标」正是本轮要消灭的缺陷——回退让「暂时缺图」退化成「画得丑」而不是
## 「画不出来」；真正的兜底是一条按映射表逐类查盘的单测。[br]
## [br][b]回退仍按图集 region 裁切[/b]：图集是 32px 格子，直接铺进 [param rect] 会拉伸
## 变形，故用 [method blit_region]（region 取样，等比铺满目标矩形）。
static func blit_type_icon(p_host: Control, rect: Rect2, type_id: int) -> void:
	var stamp: Texture2D = NodeIconArtScript.stamp_of(type_id)
	if stamp != null:
		p_host.draw_texture_rect(stamp, rect, false,
				Color(1.0, 1.0, 1.0, Style.ICON_ALPHA))
		return
	blit_region(p_host, rect, NodeIconAtlasScript.get_region(type_id))


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


## 悬停 / 键盘焦点统一高亮——[b]外发光 + 外环[/b]，画在节点[b]之外[/b]。[br]
## [br][b]★ 两层顺序（由下到上）★[/b]：外发光（半透明青色面）→ 高亮环（松石青细环）。[br]
## [br][b]为什么画在节点之外[/b]（任务书硬约束「高亮不得破坏六态区分」）：六态的画法在
## [method draw_type_icon] / [method draw_glow] / 边框那几笔里，改动任何一笔都会与
## 「亮度 / 描边粗细 / 是否发光」三根状态轴纠缠。把高亮推到节点以外，三根轴一个像素
## 没动——高亮是「包围盒」而不是「重涂」。环色取松石青（六态配色表里没有的色相），
## 线宽取 3.5（边框表只有 2.5 / 4.5 两档）——两个值都不与任何状态撞，见
## [constant Style.HIGHLIGHT_RING_WIDTH] 的注记。[br]
## [br][b]为什么还要一层发光[/b]：环只有 3.5px，自动适配缩放下落到屏幕不足 3px；
## 发光是一块面，把节点周围的局部亮度整体抬起来，「鼠标移上去节点要亮」才兑现得了。[br]
## [br][param p_host] 绘制宿主。[br][param p_node_id] 节点 ID（高亮判定按它问宿主）。[br]
## [param p_pos] 节点中心。[br][param p_node_size] 节点边长（已含可达态的悬停放大）。
static func draw_highlight(p_host: Control, p_node_id: int, p_pos: Vector2,
		p_node_size: float) -> void:
	if not bool(p_host.call(&"is_node_highlighted", p_node_id)):
		return
	var half: float = p_node_size * 0.5
	p_host.draw_circle(p_pos, half + Style.HIGHLIGHT_GLOW_GROW,
			Style.HIGHLIGHT_GLOW_COLOR)
	p_host.draw_arc(p_pos, half + Style.FOCUS_RING_MARGIN, 0.0, TAU,
			Style.FOCUS_RING_SEGMENTS, Style.FOCUS_RING_COLOR,
			Style.HIGHLIGHT_RING_WIDTH)


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


## 图集 region 绘制——统一走 [NodeIconAtlas] 单图集（同纹理合批，R-02 §3 分组方案）。
static func blit_region(p_host: Control, rect: Rect2,
		region: Rect2) -> void:
	p_host.draw_texture_rect_region(NodeIconAtlasScript.get_atlas(), rect, region)
