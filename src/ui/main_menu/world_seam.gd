extends TextureRect
## WorldSeam —— 主菜单「左序右境」的中分过渡带。[br]
## [br][b]为什么需要它[/b]：[code]design/ux/main-menu.md[/code] §Layout Zones 选的是
## 方案 B「左序右境」，并明确「中分线不是硬边线，而是视觉渐变过渡——左侧几何区域
## 渐变透明融入右侧水墨世界」。硬切一条边会让人一眼看出「左边是 UI、右边是图」，
## 渐变才是设计要的那一句。[br]
## [br][b]为什么在 [method Node._init] 里建渐变[/b]：与
## [code]app_backdrop.gd[/code] 同源——[code].tscn[/code] 写不了
## [code]Color("#hex")[/code]（本项目配色已收进 [code]theme/main.tres[/code] 单一
## 来源），写十进制字面量又会踩 float32 精度，造成「中分处浮出一条比背板深一档的
## 带子」。[method Node._init] 里读主题 + 让引擎自己序列化渐变，两端色逐位等于背板色。[br]
## [br][b]只写渐变、不动布局[/b]：锚点 / [member Control.mouse_filter] 由
## [code].tscn[/code] 声明。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只读主题、只写自己的绘制属性。
##
## 来源: design/ux/main-menu.md §Layout Zones、design/art/art-bible.md §4.7.1、
## ADR-0031 §1。

## 承载背板色的自定义 type 与槽位名（与 [code]theme/main.tres[/code] 同源）。
const PALETTE_TYPE: StringName = &"GamePalette"
const BACKDROP_KEY: StringName = &"backdrop"

## 主题查不到该 token 时的兜底色（同 [code]app_backdrop.gd[/code]）。
const FALLBACK_COLOR: Color = Color("#0E0F16")

## 渐变左端不透明度——满不透明，把云海的硬缘压在自己的左侧边缘之下。
const HEAD_ALPHA: float = 1.0
## 渐变右端不透明度——全透明，把画面交还给水墨世界。
const TAIL_ALPHA: float = 0.0
## 渐变纹理宽度（px）——横向一维渐变，纵向由 [code]STRETCH_SCALE[/code] 拉伸。
const RAMP_WIDTH: int = 256
const RAMP_HEIGHT: int = 4


func _init() -> void:
	var themed: Color = get_theme_color(BACKDROP_KEY, PALETTE_TYPE)
	var base: Color = FALLBACK_COLOR if themed == Color.BLACK else themed
	var ramp: Gradient = Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 1.0])
	ramp.colors = PackedColorArray([
		Color(base.r, base.g, base.b, HEAD_ALPHA),
		Color(base.r, base.g, base.b, TAIL_ALPHA),
	])
	var gradient: GradientTexture2D = GradientTexture2D.new()
	gradient.gradient = ramp
	gradient.fill = GradientTexture2D.FILL_LINEAR
	gradient.fill_from = Vector2(0.0, 0.5)
	gradient.fill_to = Vector2(1.0, 0.5)
	gradient.width = RAMP_WIDTH
	gradient.height = RAMP_HEIGHT
	texture = gradient
