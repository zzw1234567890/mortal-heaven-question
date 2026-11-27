extends RefCounted
## NodeGraphNodeBadge —— 单个节点的[b]徽记[/b]那一笔（图标 + 底衬 + 光晕 + 边框外标记）。[br]
##
## [b]为什么从 [code]node_graph_node_painter.gd[/code] 拆出来[/b]：那份已抵到单文件
## 300 行软上限（coding-standards），而本轮又要给它加地区层与纸片提示两笔。拆的判据是
## [b]职责[/b]：本文件只管「一枚圆印怎么画」（合成五层、图集回退、发光、状态标记），
## 而「什么时候画、画在哪个坐标、这一格是什么态」仍留在
## [code]node_graph_node_painter.gd[/code]。[br]
##
## [br][b]零状态所有权[/b]（ADR-0031 §2）：宿主（渲染器）作为 [param p_host] 传入，
## 本模块只[b]读[/b]它的渲染输入快照并把画笔落在它身上。[br]
##
## [br]来源: ADR-0031 §5 合批、design/gdd/exploration-ui-system.md §2、
## exploration-ui Story 001 / 003、本轮任务书任务二（地区里的图标仍是圆印）。

## 图集（类型主色 / 类型短标签 / 迷雾❓占位——图集仍供着「色与字」）。
const NodeIconAtlasScript := preload("res://src/ui/exploration/node_icon_atlas.gd")
## 类型图标（14 张水墨线稿——「图」这一件事从图集 glyph 换成它，见模块文档）。
const NodeIconArtScript := preload("res://src/ui/exploration/node_icon_art.gd")
## 视觉规格（尺寸/配色常量）。
const Style := preload("res://src/ui/exploration/node_graph_style.gd")


## 迷雾节点图标——中性灰圆盘 + ❓图集 region（类型不暴露）。[br]
## [br][b]为什么这里仍用图集 glyph 而不是线稿[/b]：迷雾语义就是「你还不知道这儿是什么」，
## 给一张类型图标等于把类型泄露出去。14 张线稿里没有「未知」这一张，故❓继续走图集。[br]
## [br][b]为什么是圆盘而不是方块[/b]：本轮起已揭示节点是「圆形印章」，迷雾节点若还是
## 方块，同一张图上就并存两种形状语言；圆盘保持「每个节点都是一枚印」的统一读法。[br]
## [br][b]地区里的迷雾[/b]：地区的整块压暗由 [code]node_graph_region_painter.gd[/code]
## 负责，这里的暗纱只管[b]这一枚印[/b]——两者叠加才是「这一片地连同里面的印章都暗着」。[br]
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
## 「覆盖」，它必须压在图标[b]之上[/b]才连图标一起压下去。[br]
## [br][b]为什么光晕与底衬是圆而不是方[/b]：方形光晕的四角会从圆盘后面露出来，「一枚
## 圆印」立刻读回「一个方块 + 一个圆」（反馈原话：「不能用简单的方块/圆圈/线条」）。[br]
## [br][b]暗纱为什么仍是方形[/b]：它压的是整个节点格（含边框与文字所在的方块），按圆压
## 会留下四角未压的亮块，反而更花。
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
		# 圆形暗纱——矩形会露出四个直角，读成「一个黑方块」（老板 2026-11-27 的反馈）。
		p_host.draw_circle(center, half, Color(0.0, 0.0, 0.0, veil))


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


## 状态标记绘制——[code]player[/code]（人形）/ [code]check[/code]（✓）/
## [code]lock[/code]（🔒）/ [code]question[/code]（❓）。[br]
## [br][b]标记画在图标[b]之上[/b][/b]：它是「这一格现在算什么」的最后一道标注，
## 被暗纱压住就读不出来了（暗纱在图标层，标记在它之后画）。[br]
## [br][b]为什么「question」是空的[/b]：❓已在图标层由图集 region 画过（迷雾圆盘那一枚），
## 这里再画一次会叠成两个问号。
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
## [br][b]与地区高亮的分工[/b]：地区那一层（[code]node_graph_region_painter.gd[/code]）
## 负责「整片地亮起来」，本方法负责「那枚印被框住」——两者读的是[b]同一个[/b]
## [code]is_node_highlighted[/code]，故鼠标与键盘、悬停与焦点都不会出现「地亮了印没亮」。[br]
## [br][param p_host] 绘制宿主。[br][param p_node_id] 节点 ID（高亮判定按它问宿主）。[br]
## [param p_pos] 节点中心。[param p_node_size] 节点边长（已含可达态的悬停放大）。
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


## 图集 region 绘制——统一走 [NodeIconAtlas] 单图集（同纹理合批，R-02 §3 分组方案）。
static func blit_region(p_host: Control, rect: Rect2,
		region: Rect2) -> void:
	p_host.draw_texture_rect_region(NodeIconAtlasScript.get_atlas(), rect, region)
