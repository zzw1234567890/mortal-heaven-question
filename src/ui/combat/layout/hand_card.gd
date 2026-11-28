class_name HandCard
extends Control
## HandCard —— 手牌缩略卡渲染（combat-ui-layout Story 006）。
##
## [b]职责[/b]：手牌区单张缩略卡的静态渲染——卡名（顶部）、费用（左上角）、
## 类型标签（右下角）、稀有度色边框（描边）。三态视觉（GDD §2 手牌区状态表）：[br]
##   - [b]默认[/b]（阶段 2 内 + 费用充足）→ 彩色，费用正常色[br]
##   - [b]灰显[/b]（阶段 2 内 + 费用不足）→ 整体降饱和（modulate）+ 费用数字红[br]
##   - [b]灵能预览[/b]（阶段 2 外）→ 60% 饱和度近似（modulate）+ 🔒 角标[br]
## [br][b]R-02 §3 合批[/b]：全部文字经 [code]draw_string[/code] 在单一
## [code]_draw()[/code] 内绘制（零独立 Label 子节点——单 CanvasItem 合批，
## 避免 10 张手牌 × 4 Label 的 DC 膨胀）；颜色/尺寸常量集中定义。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：卡牌数据（名称/费用/稀有度/类型）为
## 渲染快照，经 [method set_card_data] 由 [HandArea] 信号驱动写入；本组件不
## 访问卡牌系统。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]。[br]
## [br][b]范围划分[/b]：卡面美术本体归资产管线（story Out of Scope——
## 缩略卡渲染 stub）；悬停放大 1.2×/拖拽归 interaction epic。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §2 手牌区/§手牌区状态、
## design/ux/hud.md §手牌区、production/qa/evidence/r02-batching-spec.md §3、
## combat-ui-layout Story 006（AC-4）。

## 共享字号纯函数（story 001 唯一落地处——禁止内联）。
const UiFont := preload("res://src/ui/combat/shared/combat_ui_font.gd")
## 手牌几何（尺寸/弧形/底栏让位）的唯一真源。
const Rules := preload("res://src/ui/combat/shared/hand_arc_rules.gd")
## 卡面插画解析（专属卡面 → 角色立绘 → 旧插画 → 无图）。
const ArtResolver := preload("res://src/ui/combat/card_art_resolver.gd")

## === 尺寸常量（UX hud.md「手牌中宽度 100px → 高度 140px，宽高比 5:7」）=======

const CARD_WIDTH: float = Rules.DEFAULT_CARD_WIDTH
const CARD_HEIGHT: float = Rules.DEFAULT_CARD_HEIGHT

## 插画区高度占比（上部留 72% 给图，下部 28% 放卡名与类型）。
const ART_HEIGHT_RATIO: float = 0.72
## cover 裁切窗口的纵向偏置（0.5 = 居中；偏小则取更靠上的画面）。
const COVER_BIAS: float = 0.35
## 卡名与插画下沿的间距（px——太贴会读成「贴在图上」）。
const NAME_GAP: float = 22.0
## 费用徽章半径（px）。
const COST_BADGE_RADIUS: float = 13.0
## 费用徽章圆心到左上角的距离（px）。
const COST_BADGE_MARGIN: float = 17.0
## 费用徽章底色（深色半透明——压在任何插画上都读得清）。
const COST_BADGE_BG: Color = Color(0.06, 0.07, 0.10, 0.82)

## === 视觉常量（集中定义——数据驱动条款）=======================================

## 卡面底色（深色——stub 阶段无插画）。
const CARD_BG: Color = Color(0.16, 0.17, 0.21)
## 卡面顶部（近似插画位置——浅色头，stub 占位）。
const CARD_HEAD: Color = Color(0.22, 0.24, 0.30)
## 卡名字色。
const NAME_COLOR: Color = Color(0.92, 0.92, 0.88)
## 费用数字色（正常态）。
const COST_COLOR: Color = Color(0.95, 0.90, 0.55)
## 费用数字色（费用不足态——GDD「费用数字红色」）。
const COST_UNAFFORDABLE_COLOR: Color = Color(0.85, 0.25, 0.22)
## 锁标记色（灵能预览）。
const LOCK_COLOR: Color = Color(0.95, 0.85, 0.40)
## 灰显 modulate（费用不足——整体降饱和）。
const GRAYED_MODULATE: Color = Color(0.55, 0.55, 0.55)
## 灵能预览 modulate（60% 饱和度近似——偏灰仍保留色相）。
const PSYCHIC_MODULATE: Color = Color(0.80, 0.78, 0.74)

## === 键盘焦点视觉（.claude/rules/ui-code.md 双输入）===========================

## 焦点环色（松石青——同商店 / 卡组编辑面板的焦点环，全项目一致）。
const FOCUS_RING_COLOR: Color = Color(0.35, 0.85, 0.8)
## 焦点环线宽（px——比稀有度边框粗，一眼分得出「边框」与「焦点」）。
const FOCUS_RING_WIDTH: float = 3.0

## === 选中态视觉（combat-ui-interaction 001——选中抬起）=========================

## 选中抬起偏移（px——卡牌上移，与相邻卡区分）。
const SELECTED_LIFT: float = 24.0
## 选中描边色（青白高亮，与稀有度边框可区分）。
const SELECTED_BORDER_COLOR: Color = Color(0.45, 0.92, 0.95)
## 选中描边加宽（px——原边框 2.0 之上加粗，双通道：位移 + 描边，不靠单一颜色）。
const SELECTED_BORDER_EXTRA: float = 2.0

## 稀有度边框色（CardTemplate.Rarity 1=白 2=蓝 3=紫 4=金 5=暗金——集中定义）。
const RARITY_BORDER_COLORS: Array[Color] = [
	Color(0.72, 0.72, 0.72),  # 白
	Color(0.35, 0.55, 0.95),  # 蓝
	Color(0.70, 0.42, 0.95),  # 紫
	Color(0.95, 0.78, 0.28),  # 金
	Color(0.90, 0.42, 0.20),  # 暗金
]

## 类型标签文本（CardTemplate.CardType 0-5）。
const TYPE_LABELS: Array[String] = ["角色", "功法", "法宝", "阵法", "丹药", "符箓"]

## 字号基准（pt——经 font_size_responsive 响应式缩放，1280×720 下 ≥12pt）。
const NAME_FONT_SIZE: int = 12
const COST_FONT_SIZE: int = 16
const TYPE_FONT_SIZE: int = 12
const LOCK_FONT_SIZE: int = 14

## 边框线宽。
const BORDER_WIDTH: float = 2.0

## 键盘/手柄确认——聚焦后按 Enter/Space（[code]ui_accept[/code]）发射。[br]
## [br][b]载荷是卡实例 ID[/b]：卡的渲染快照不认识战斗手牌，把「哪张被确认了」原样
## 交回持有者（[HandArea] → 交互接线 → 出牌流程）——组件不自己出牌（零状态所有权，
## ADR-0031 §2）。[br]
## [b]与鼠标的分工[/b]：鼠标手势仍统一由 [code]CombatInputLayer[/code] 接手
## （本卡 [code]mouse_filter = IGNORE[/code]）；键盘这条路径没有坐标，走不了命中
## 测试，故由卡自己接。
signal activated(card_instance_id: int)

## === 渲染快照（零状态所有权——HandArea 写入）==================================

## 卡实例 ID（键盘确认时随 [signal activated] 原样带回——手牌区据此映射回战斗手牌）。
var card_instance_id: int = -1
## 卡名。
var card_name: String = ""
## 灵力消耗。
var cost: int = 0
## 稀有度（1-5）。
var rarity: int = 1
## 卡牌类型（0-5）。
var card_type: int = 0
## 费用是否充足（false → 灰显 + 费用红）。
var is_affordable: bool = true
## 是否灵能预览（阶段 2 外——true 时 60% 饱和 + 🔒）。
var is_psychic: bool = false
## 是否被选中（combat-ui-interaction 001——抬起 + 加粗描边）。
var is_selected: bool = false
## 是否持有键盘焦点（[method _draw] 据此画焦点环——焦点可见性）。
var is_focused: bool = false
## 卡种 ID（[code]basic_attack[/code] 这类模板 ID——卡面找图的键；实例 ID 每张不同，
## 不能当美术键）。
var card_kind: StringName = &""
## 卡面插画（在 [method set_card_data] 里解析好，[method _draw] 只负责画）。[br]
## [br][b]为什么不在 _draw() 里解析[/b]：绘制期间首次 [code]load()[/code] 的贴图要等
## 本帧之后才上传，卡片会一直画成空白（要等下一次重绘才出现）。
var _art: Texture2D = null


func _init() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	# 双焦点（ADR-0004）：纯 Control 默认 FOCUS_NONE，必须显式开启才能 grab_focus；
	# 卡的键盘确认（Enter/Space）经 [method _gui_input] 的 ui_accept。
	# [b]保持 IGNORE[/b]：鼠标手势统一由 CombatInputLayer 接手（命中测试在
	# HandAreaCards），卡自己不认领鼠标事件；实测 mouse_filter=IGNORE 不影响键盘派发。
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 焦点进出都要重画（焦点环随焦点画 / 撤）——引擎只发通知，不自绘焦点。
	focus_entered.connect(_on_focus_changed.bind(true))
	focus_exited.connect(_on_focus_changed.bind(false))


## 设置卡牌数据（渲染快照——HandArea 信号驱动写入）。[br]
## [param p_instance_id]: 卡实例 ID（键盘确认回传用；-1 = 未知）。[br]
## [param p_name]: 卡名。[param p_cost]: 灵力消耗。[param p_rarity]: 稀有度 1-5。
## [param p_type]: 卡牌类型 0-5。
func set_card_data(p_instance_id: int, p_name: String, p_cost: int, p_rarity: int,
		p_type: int, p_kind: StringName = &"") -> void:
	card_instance_id = p_instance_id
	card_name = p_name
	cost = maxi(p_cost, 0)
	rarity = clampi(p_rarity, 1, 5)
	card_type = clampi(p_type, 0, TYPE_LABELS.size() - 1)
	card_kind = p_kind
	_art = ArtResolver.texture_for(p_kind)
	_apply()


## 设置费用充足标志（灰显判定——阶段 2 内有效）。
func set_affordable(p_affordable: bool) -> void:
	is_affordable = p_affordable
	_apply()


## 设置灵能预览（阶段 2 外——60% 饱和 + 🔒）。
func set_psychic(p_psychic: bool) -> void:
	is_psychic = p_psychic
	_apply()


## 设置选中态（combat-ui-interaction 001——抬起 + 青白加粗描边）。[br]
## [br][b]只管视觉[/b]：选中态的真理来源是 [code]HandSelectionModel[/code]；
## 本方法由 [code]HandArea[/code] 按其状态逐个写入，「哪些卡该亮」不在组件内判定。
func set_selected(p_selected: bool) -> void:
	is_selected = p_selected
	_apply()


## 选中抬起偏移量（px——[HandArea] 排位时叠加到弧形终位）。[br]
## [br][b]为什么偏移量暴露而非组件自己动[/b]：位置所有权在 [code]HandArea[/code]
## 的弧形排布（重排动画会重写 position），组件自己动会被下一次排位覆盖。
func get_lift_offset() -> float:
	return SELECTED_LIFT if is_selected else 0.0


## 获取当前 modulate（测试断言用——三态视觉可区分）。
func get_current_modulate() -> Color:
	return modulate


## 锁标记可见性（测试断言用）。
func is_lock_visible() -> bool:
	return is_psychic


## 边框色（测试断言用——选中时替换为高亮色）。
func get_border_color() -> Color:
	if is_selected:
		return SELECTED_BORDER_COLOR
	return RARITY_BORDER_COLORS[clampi(rarity, 1, 5) - 1]


## 边框线宽（测试断言用——选中时加粗）。
func get_border_width() -> float:
	return BORDER_WIDTH + SELECTED_BORDER_EXTRA if is_selected else BORDER_WIDTH


## 费用数字色（测试断言用——费用不足时红）。
func get_cost_color() -> Color:
	return COST_UNAFFORDABLE_COLOR if not is_affordable else COST_COLOR


## 焦点持有态（测试断言用——焦点环可见性据此判定）。
func has_keyboard_focus() -> bool:
	return is_focused


## === 内部 ====================================================================

## 键盘/手柄确认入口（[code]ui_accept[/code] = Enter / 小键盘 Enter / Space，
## 三条绑定同时覆盖键盘与手柄）。[br]
## [br][b]只吃确认键[/b]：Tab 与方向键归引擎的焦点导航（.claude/rules/ui-code.md
## 「所有交互元素必须同时支持键盘/鼠标和手柄输入」的走位那一半），本卡不拦。
func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_accept"):
		activated.emit(card_instance_id)
		accept_event()


## 焦点进出——重画（焦点环的绘制时机由本卡自己把握）。
func _on_focus_changed(p_focused: bool) -> void:
	is_focused = p_focused
	queue_redraw()


## 状态落定（modulate 三态 + 重绘）。
func _apply() -> void:
	# 状态优先级：灵能预览 > 灰显（阶段 2 外统一灵能预览，费用不足仅在阶段 2 内灰显）
	if is_psychic:
		modulate = PSYCHIC_MODULATE
	elif not is_affordable:
		modulate = GRAYED_MODULATE
	else:
		modulate = Color.WHITE
	queue_redraw()


## 屏幕高度（未入树时回退 1080——font_size_responsive 输入）。
func _screen_height() -> int:
	return int(get_viewport_rect().size.y) if get_viewport() != null else 1080


## 卡面绘制（R-02 §3 合批——底色/头部/边框 + draw_string 三文字 + 锁，
## 单一 CanvasItem 零子节点）。
func _draw() -> void:
	# 以 [member size] 为唯一基准——卡的实际尺寸由手牌区按视口算，不再读常量。
	var w: float = maxf(size.x, 1.0)
	var hgt: float = maxf(size.y, 1.0)
	var card_rect: Rect2 = Rect2(0.0, 0.0, w, hgt)
	draw_rect(card_rect, CARD_BG)
	var art_h: float = hgt * ART_HEIGHT_RATIO
	var art_rect: Rect2 = Rect2(0.0, 0.0, w, art_h)
	if _art != null:
		_draw_cover(_art, art_rect)
	else:
		# 缺图（法术/法宝暂无插画）：保留一条浅色头当占位，别空成一整块。
		draw_rect(Rect2(0.0, 0.0, w, minf(24.0, art_h)), CARD_HEAD)
	# 插画下沿分隔线
	draw_rect(Rect2(0.0, art_h, w, 1.0), CARD_HEAD)
	# 稀有度边框（选中：替换边框色 + 加粗）
	draw_rect(card_rect, get_border_color(), false, get_border_width())
	var font: Font = ThemeDB.fallback_font
	var sh: int = _screen_height()
	# 卡名（插画下方一行——太贴会读成贴在图上）
	var name_size: int = UiFont.font_size_responsive(NAME_FONT_SIZE, sh)
	var text_top: float = art_h + float(name_size) + NAME_GAP
	draw_string(font, Vector2(6.0, text_top), card_name, HORIZONTAL_ALIGNMENT_LEFT,
			w - 12.0, name_size, NAME_COLOR)
	# 费用：左上圆形徽章（深底 + 可负担性配色）——数字压在图上也读得清
	var badge_center: Vector2 = Vector2(COST_BADGE_MARGIN, COST_BADGE_MARGIN)
	draw_circle(badge_center, COST_BADGE_RADIUS, COST_BADGE_BG)
	draw_string(font, Vector2(badge_center.x - COST_BADGE_RADIUS, badge_center.y + 6.0),
			str(cost), HORIZONTAL_ALIGNMENT_CENTER, COST_BADGE_RADIUS * 2.0,
			UiFont.font_size_responsive(COST_FONT_SIZE, sh), get_cost_color())
	# 类型标签（右下角）
	draw_string(font, Vector2(6.0, hgt - 6.0), TYPE_LABELS[card_type],
			HORIZONTAL_ALIGNMENT_RIGHT, w - 12.0,
			UiFont.font_size_responsive(TYPE_FONT_SIZE, sh), NAME_COLOR)
	# 锁标记（灵能预览——右上角，加圆底免得压在插画上看不见）
	if is_psychic:
		var lock_center: Vector2 = Vector2(w - 16.0, 16.0)
		draw_circle(lock_center, 9.0, COST_BADGE_BG)
		draw_string(font, Vector2(lock_center.x - 9.0, lock_center.y + 5.0), "🔒",
				HORIZONTAL_ALIGNMENT_CENTER, 18.0, LOCK_FONT_SIZE, LOCK_COLOR)
	# 焦点环（键盘/手柄焦点可见——最后画，压在其余视觉之上）
	if is_focused:
		draw_rect(card_rect, FOCUS_RING_COLOR, false, FOCUS_RING_WIDTH)


## 插画 cover 裁切——按比例铺满矩形，纵向按 [constant COVER_BIAS] 偏上（人物头在
## 画面中上部，取正中会把脸裁掉半张）。不平铺、不拉伸。
func _draw_cover(p_tex: Texture2D, p_rect: Rect2) -> void:
	var src: Vector2 = p_tex.get_size()
	if src.x <= 0.0 or src.y <= 0.0:
		return
	var fit: float = maxf(p_rect.size.x / src.x, p_rect.size.y / src.y)
	var win: Vector2 = Vector2(p_rect.size.x / fit, p_rect.size.y / fit)
	var region: Rect2 = Rect2((src.x - win.x) * 0.5, (src.y - win.y) * COVER_BIAS,
			win.x, win.y)
	draw_texture_rect_region(p_tex, p_rect, region)
