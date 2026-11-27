extends Control
## IdentityPortraitTile —— 身份卡上的单名角色小块（立绘 or 程序化占位）。
##
## [b]两种形态[/b]（同一控件，按资产有无分派）：[br]
##   · **有立绘** → 挂一个名为 [code]Portrait[/code] 的 [TextureRect] 子节点，
##     [code]STRETCH_KEEP_ASPECT_COVERED[/code] + [code]EXPAND_IGNORE_SIZE[/code]
##     铺满本控件并按中心裁剪——立绘原图是 800×1120 竖版，直接按比例缩放会留白边、
##     [code]KEEP_ASPECT_CENTERED[/code] 会缩到看不清脸，故取「填满 + 裁边」。[br]
##   · **无立绘** → [method _draw] 现画：竖向渐变底（身份配色）+ 印章式圆形纹样 +
##     角色首字。不引入任何新贴图文件（用户约束：没有立绘不许新增 png）。[br]
## [br][b]为什么单独成控件[/b]：立绘与占位是「一个角色的视觉主体」，与「卡片怎么排」
## 是两件事——排布留在 [code]identity_card_factory.gd[/code]，本类只管自己长什么样。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只读传入的 card_id / 配色，不写游戏状态。
##
## [br]来源: ADR-0031 §2/§5、design/gdd/identity-selection-system.md §用户界面需求、
## story-004-identity-select-ui.md。

## 立绘/配色解析（静态纯函数 + 纹理缓存）。
const Resolver := preload("res://src/ui/identity_select/identity_portrait_resolver.gd")

## 立绘子节点名——测试与截图脚本据此判定「有立绘的身份拿到了 TextureRect」。
const PORTRAIT_NODE_NAME: StringName = &"Portrait"

## 卡片内小块默认尺寸（px）——竖长比例贴合立绘原图方向。
const DEFAULT_TILE_SIZE: Vector2 = Vector2(52.0, 58.0)
## 渐变分带数——够平滑且只花十几笔 [method CanvasItem.draw_rect]。
const GRADIENT_BANDS: int = 16
## 印章圆环半径相对短边的比例。[br]
## [br][b]为什么是 0.42 而不是 0.30[/b]：占位的硬性要求是「视觉上不能是空白色块」，
## 早期 0.30 在 104×72 的格子里只画出一个直径 43px 的小圈，缩到整屏看就是一块底。
## 现在印章占满短边八成以上，纹样本身就是主视觉。
const SEAL_RADIUS_RATIO: float = 0.42
## 印章圆环线宽（px）。
const SEAL_RING_WIDTH: float = 2.5
## 印章色填充圆盘的 alpha——给首字垫一层同色底，字才从渐变里「浮」出来。
const SEAL_DISC_ALPHA: float = 0.26
## 印章首字号 = 内环半径 × 本比例（随块尺寸自适应，小到贴纸大也不空）。
const SEAL_FONT_RATIO: float = 1.15
## 首字号下限（px）——再小就没法读了。
const SEAL_FONT_MIN: int = 10
## 印章环的双环内缩量（px——双环更像朱印）。
const SEAL_INNER_GAP: float = 4.0
## 首字下方阴影的偏移（px）与 alpha——深浅底都压得住，字不糊。
const SEAL_SHADOW_OFFSET: float = 1.5
const SEAL_SHADOW_ALPHA: float = 0.55

## 角色卡 id（查立绘用——空 = 无名条目）。
var card_id: String = ""
## 角色显示名（印章首字与下方标签用）。
var display_name: String = ""
## 印章首字（角色名首字；无名时回退身份名首字）。
var seal_char: String = ""
## 配色 [{top, bottom, accent}]。
var palette: Dictionary = Resolver.FALLBACK_PALETTE
## 立绘纹理（null = 走程序化占位）。
var portrait: Texture2D = null


## 配置本块（由 [code]identity_card_factory.gd[/code] 在 [code]new()[/code] 后调用）。[br]
## [br][param p_card_id]: 角色卡 id（决定有没有立绘）。[br]
## [param p_display_name]: 角色显示名。[br]
## [param p_palette]: 占位配色。[br]
## [param p_tile_size]: 块尺寸；[param p_seal_char]: 印章首字（空 = 取显示名首字）。
func setup(p_card_id: String, p_display_name: String, p_palette: Dictionary,
		p_tile_size: Vector2 = DEFAULT_TILE_SIZE, p_seal_char: String = "") -> void:
	card_id = p_card_id
	display_name = p_display_name
	palette = p_palette if not p_palette.is_empty() else Resolver.FALLBACK_PALETTE
	seal_char = p_seal_char if not p_seal_char.is_empty() else _first_char(p_display_name)
	custom_minimum_size = p_tile_size
	size = p_tile_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # 卡片本身收点击，小块不抢
	clip_contents = true  # 立绘按 covered 缩放后裁在块内
	portrait = Resolver.portrait_for(card_id)
	if portrait != null:
		_attach_portrait()
	queue_redraw()


## 是否走立绘路径（测试断言用——等价于「有 Portrait 子节点」）。
func has_portrait() -> bool:
	return portrait != null


## 印章/标签文案（供上方标签与测试读取）。
func label_text() -> String:
	return display_name if not display_name.is_empty() else seal_char


func _attach_portrait() -> void:
	if get_node_or_null(NodePath(String(PORTRAIT_NODE_NAME))) != null:
		return
	var rect: TextureRect = TextureRect.new()
	rect.name = PORTRAIT_NODE_NAME
	rect.texture = portrait
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)


## 无立绘时的程序化占位：竖向渐变底 + 印章圆盘 + 双环 + 首字。[br]
## [br][b]为什么不用背景 [ColorRect][/b]：渐变要分带画，[method _draw] 一次画完
## 十几笔，比叠一堆子节点省事且不吃布局。[br]
## [br][b]绘制顺序[/b]：渐变 → 印章色圆盘（半透，垫出对比）→ 双环 → 首字阴影 →
## 首字。圆盘是关键一层：没有它，浅色渐变上的同色系首字会糊成一片。
func _draw() -> void:
	if portrait != null:
		return  # 立绘由 TextureRect 子节点铺满，本层不再画
	var top: Color = palette.get("top", Resolver.FALLBACK_PALETTE["top"])
	var bottom: Color = palette.get("bottom", Resolver.FALLBACK_PALETTE["bottom"])
	var accent: Color = palette.get("accent", Resolver.FALLBACK_PALETTE["accent"])
	_draw_gradient(top, bottom)
	var center := Vector2(size.x * 0.5, size.y * 0.5)
	var radius: float = minf(size.x, size.y) * SEAL_RADIUS_RATIO
	# 印章色圆盘——半透垫底，把首字从渐变里托出来
	draw_circle(center, radius, Color(accent.r, accent.g, accent.b, SEAL_DISC_ALPHA))
	# 朱印式双环
	draw_arc(center, radius, 0.0, TAU, 48, accent, SEAL_RING_WIDTH)
	draw_arc(center, radius - SEAL_INNER_GAP, 0.0, TAU, 48,
			Color(accent.r, accent.g, accent.b, 0.55), 1.0)
	if seal_char.is_empty():
		return
	var font: Font = _font()
	var font_size: int = maxi(int(radius * SEAL_FONT_RATIO), SEAL_FONT_MIN)
	var text_size: Vector2 = font.get_string_size(seal_char,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := center + Vector2(-text_size.x * 0.5, text_size.y * 0.36)
	# 先画一层深色偏移影——印章色再浅也压得住
	draw_string(font, baseline + Vector2(SEAL_SHADOW_OFFSET, SEAL_SHADOW_OFFSET), seal_char,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size,
			Color(0.05, 0.05, 0.10, SEAL_SHADOW_ALPHA))
	draw_string(font, baseline, seal_char, HORIZONTAL_ALIGNMENT_LEFT, -1,
			font_size, Color(1.0, 1.0, 1.0))


## 竖向渐变——分带插值（[constant GRADIENT_BANDS] 条横带）。
func _draw_gradient(p_top: Color, p_bottom: Color) -> void:
	var band_h: float = size.y / float(GRADIENT_BANDS)
	for i: int in range(GRADIENT_BANDS):
		var t: float = float(i) / float(maxi(GRADIENT_BANDS - 1, 1))
		draw_rect(Rect2(0.0, float(i) * band_h, size.x, band_h + 1.0),
				p_top.lerp(p_bottom, t))


## 主题默认字体（本项目暂无专用 UI 字体资产——先例 node_graph_node_painter）。
func _font() -> Font:
	var theme_font: Font = get_theme_default_font()
	return theme_font if theme_font != null else ThemeDB.fallback_font


## 取首字（空串 → 空串——不凭空造字）。
static func _first_char(p_text: String) -> String:
	return p_text.substr(0, 1) if not p_text.is_empty() else ""
