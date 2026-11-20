class_name DeckCardRow
extends Button
## DeckCardRow —— 卡组查看面板里的[b]卡面行[/b]（样式盒画卡底 + 引擎绘制文本）。[br]
## [br][b]为什么行要做成 [Button] 子类[/b]：卡组面板的键盘游标走
## [code]ShopPanelNavigator[/code]，而它的可选择性判据是 [member Button.disabled]
## （非 [Button] 的行在它眼里一律「不可选」，上下键直接跳过）。做成 [Button] 子类后
## 键盘上下可选中（焦点环随焦点绘制）、鼠标可点、手柄同键位、屏幕阅读器可读
## （[member Button.text] 是要念的内容）——四条同时成立。[br]
## [br][b]为什么不是独立的自绘 [Control][/b]：背包/商店/卡组三处的游标是同一个实现，
## 为了一行改游标认不认识「自绘控件」等于把三处的选择语义一起动
# （[code]LootOptionCard[/code] 那种自绘控件能自收 [code]_gui_input[/code]，
## 但它不进列表游标体系）。[br]
## [br][b]文本交给引擎、底子交给样式盒[/b]：卡名/类型/费用/效果摘要是三行可读文本，
## 交给 [Button] 自己的文本渲染（多行 [code]\n[/code] 在 4.6 下会撑开最小高度，
## 屏幕阅读器与测试读的也都是 [member Button.text]）。[br]
## [br][b]卡底[b]不能[/b]由 [method CanvasItem._draw] 画（曾经是，那是个真 bug）[/b]：
## 实测 4.6.3 下脚本 [method CanvasItem._draw] 的产物落在 [Button] 自身的样式盒与文字
## [b]之上[/b]——原先在这里 [code]draw_rect[/code] 一整块不透明的 [constant CARD_BG]，
## 等于给每一行的字盖了一张不透明的纸：数据层（[member Button.text]、载荷、行数、可见性、
## 尺寸）全都对，屏幕上却一个字都看不见（离屏截图取证：行带内 0 个文本色像素）。
## 所以卡底走[b]五种状态样式盒[/b]——引擎在文字之下画它们——本组件只在
## [method CanvasItem._draw] 里画[b]不压字的[/b]两样：左侧稀有度色条（宽
## [constant BAR_WIDTH]，在文本左边距 [constant TEXT_INSET] 之内）与整圈细描边
## （1px，在行边缘，也够不着字）。[br]
## [br][b]悬停 / 按下 / 焦点不靠自绘[/b]：三种反馈由引擎按状态切样式盒完成
## （卡底混一层半透明白），焦点环复用商店面板的松石青粗边（[code]apply_focus_ring[/code]）
## ——零轮询：状态变化由引擎驱动，本组件没有 [code]_process()[/code]。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：卡面字段由面板经 [method apply_face]
## 下发，本组件不读卡牌系统、不写任何玩法数据。[br]
## [br][b]文案本地化豁免[/b]：本组件不产出句子（文本全部来自
## [code]CardFaceRules[/code]），与 [code]deck_view_rows.gd[/code] 同源口径。[br]
##
## 来源: design/ux/deck-editing-ui.md（§卡组浏览「复用手牌布局的卡片视觉」）、
## design/ux/pause-menu.md（§Interaction Map 战斗中特殊规则）、
## .claude/rules/ui-code.md（双输入 + 焦点可见 + 文字即标记 + 色盲可读）、
## ADR-0031 §2、先例 [code]hand_card.gd[/code]（卡面配色）与
## [code]loot_option_card.gd[/code]（可聚焦自绘控件）。

## 卡面字段与文案的单一来源（本组件不自拼句子——见类文档）。
const FaceRules := preload("res://src/ui/shared/card_face_rules.gd")
## 焦点环样式（与商店 / 背包 / 卡组其他面板同一处定义）。
const ShopLayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")

## 行高（px）——三行文本（卡名 / 类型·稀有度·费用[·标注] / 效果摘要）加留白。
const ROW_HEIGHT: int = 104
## 左侧稀有度色条宽度（px——与整圈 1px 边框构成双通道，不只靠颜色）。
const BAR_WIDTH: float = 6.0
## 卡面边框线宽（px）。
const BORDER_WIDTH: float = 1.0
## 文本左边距（px——让开色条；走样式盒的 content_margin，不靠贴空格）。
const TEXT_INSET: float = 18.0

## 卡面底色（与手牌 [code]HandCard.CARD_BG[/code] 同源——手牌与卡组是同一种视觉语言）。[br]
## [br]走样式盒而不是自绘——见类文档「卡底不能由 _draw 画」。
const CARD_BG: Color = Color(0.16, 0.17, 0.21)

## 文本色（深色卡底上的浅字——与手牌卡名同色系）。
const TEXT_COLOR: Color = Color(0.92, 0.92, 0.88)
## 已禁用时的文本色（压暗——「现在点不动」要看得出来，但字仍要读得出）。
const TEXT_DISABLED_COLOR: Color = Color(0.52, 0.52, 0.54)
## 禁用态卡底的压暗量（[method Color.darkened] 的入参）。
const DISABLED_DARKEN: float = 0.25
## 悬停 / 按下的叠加量（在卡底上混入的白——引擎按状态切样式盒，零重绘）。
const HOVER_MIX: float = 0.10
const PRESSED_MIX: float = 0.20

## 行载荷的元数据键（与 [code]InventoryPanelLayout.META_PAYLOAD[/code] 同一个键
## ——确认时经同一入口读回，面板不必知道这一行是哪种行控件）。
const META_PAYLOAD: StringName = &"row_payload"

## 本行的卡面字段（[method CardFaceRules.fields_of] 的产出——重绘与查询共用）。
var face: Dictionary = {}
## 本行的稀有度等级（1-5——色条与边框取色用）。
var rarity: int = 1


func _init() -> void:
	name = "CardRow"
	custom_minimum_size = Vector2(0.0, ROW_HEIGHT)
	# 左对齐：列表行的观感（按钮默认居中会让卡名在行内漂移）
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	# 键盘/手柄可达（.claude/rules/ui-code.md「交互元素必须同时支持键盘与手柄」）
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 效果摘要仍可能超出行宽——裁掉而不是画出卡面之外（第三行本就按字符数截过，
	# 这是最后一道兜底）。
	clip_text = true
	_apply_transparent_boxes()
	ShopLayoutScript.apply_focus_ring(self)


## 写入一张卡面（面板从 [code]DeckViewRows.build[/code] 的行数据透传）。[br]
## [br][param p_fields] [code]CardFaceRules.fields_of[/code] 的产出。[br]
## [param p_marker] 牌库状态标注（「已抽出」/「仍在牌库」；空串 = 不标）。[br]
## [br][b]标注并进第二行[/b]：见 [code]CardFaceRules.meta_text[/code]——它回答的是
## 「这张在不在手上」，与费用同属这一行的状态，不另占一行高度。
func apply_face(p_fields: Dictionary, p_marker: String = "") -> void:
	face = p_fields
	rarity = int(p_fields.get(FaceRules.KEY_RARITY_LEVEL, 1))
	text = FaceRules.face_text(p_fields, p_marker)
	queue_redraw()


## 本行稀有度边框色（与手牌卡面同源夹取——测试断言用）。
func border_color() -> Color:
	return FaceRules.rarity_color(rarity)


## 五种状态样式盒：底色恒为卡底，悬停 / 按下在卡底上混入白，禁用压暗（见类文档）。[br]
## [br]样式盒由引擎画在[b]文字之下[/b]——这正是卡底该待的层（[method CanvasItem._draw]
## 的产物在上，压字；见类文档）。[br]
## [br][code]content_margin_left[/code] = 文本让开左侧稀有度色条；
## [code]content_margin_top/bottom[/code] 给三行文本上下留白。[br]
## [br][b]文本四态同色、禁用压暗一档[/b]：卡底恒深，字恒浅（浅色主题的默认深字会
## 看不见）；「点不动」与「读不出」是两件事，禁用态只是暗一些、仍然读得出。
func _apply_transparent_boxes() -> void:
	add_theme_stylebox_override(&"normal", _card_box(CARD_BG))
	add_theme_stylebox_override(&"hover", _card_box(_mixed(HOVER_MIX)))
	add_theme_stylebox_override(&"pressed", _card_box(_mixed(PRESSED_MIX)))
	add_theme_stylebox_override(&"disabled", _card_box(CARD_BG.darkened(DISABLED_DARKEN)))
	for key: StringName in [&"font_color", &"font_hover_color", &"font_pressed_color",
			&"font_focus_color"]:
		add_theme_color_override(key, TEXT_COLOR)
	add_theme_color_override(&"font_disabled_color", TEXT_DISABLED_COLOR)


## 卡底混入 [param p_amount] 的白（悬停 / 按下）。
func _mixed(p_amount: float) -> Color:
	return CARD_BG.lerp(Color.WHITE, p_amount)


## 一张卡的底色盒（无边框——描边由 [method CanvasItem._draw] 画在行边缘，见类文档）。[br]
## [br][param p_bg] 该状态下的卡底色（悬停 / 按下已混白，禁用已压暗）。[br]
## [br][b]返回[/b]：除了底色与内边距外一切归零的样式盒。
func _card_box(p_bg: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = p_bg
	box.set_border_width_all(0)
	_apply_margins(box)
	return box


## 文本内边距（左边距最大——让开左侧稀有度色条）。
func _apply_margins(p_box: StyleBox) -> void:
	p_box.content_margin_left = TEXT_INSET
	p_box.content_margin_right = 12.0
	p_box.content_margin_top = 10.0
	p_box.content_margin_bottom = 10.0


## 卡面绘制——[b]只画不压字的两样[/b]：左侧稀有度色条与整圈细描边。[br]
## [br][b]为什么不在这里画卡底[/b]：见类文档「卡底不能由 _draw 画」——本方法的产物
## 在 [Button] 的文字之上，一整块不透明矩形会把三行字全盖掉（这正是本组件曾经的
## 那个 bug）。卡底走样式盒。[br]
## [br][b]色条宽度 < 文本左边距[/b]：两者分别是 [constant BAR_WIDTH] 与
## [constant TEXT_INSET]，色条落在文本左侧的留白里，与字不重叠。[br]
## [br][b]尺寸为 0 直接返回[/b]：未入树 / 未布局时 [member Control.size] 是零，
## 照画会得到一堆零面积矩形（无害但无意义）。
func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var color: Color = border_color()
	# 左侧色条（加粗的稀有度通道——与整圈细描边一起构成双编码）
	draw_rect(Rect2(Vector2.ZERO, Vector2(BAR_WIDTH, size.y)), color)
	draw_rect(Rect2(Vector2.ZERO, size), color, false, BORDER_WIDTH)
