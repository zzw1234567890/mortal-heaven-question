extends RefCounted
## MapClearPanelLayout —— 地图通关结算面板的控件树与行构建。[br]
## [br][b]为什么单独一处[/b]：与 [code]meditation_panel_layout.gd[/code] 同源理由——
## 「控件怎么搭、行怎么画」与「结算怎么确认」是两件事，且面板脚本要守在 300 行软
## 上限内（.claude/docs/coding-standards.md）。[br]
## [br][b]与商店/打坐面板同构[/b]：遮罩 + 居中面板 + 标题 + 摘要 + 行列表 + 文案 +
## 底栏，尺寸/边距/焦点环全部复用 [ShopPanelLayout] 的常量与样式助手——四处不各画
## 一套（焦点环颜色或行高改一次即多处生效）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：只 new 节点与 StyleBox，不持有任何引用
## （[method build] 把引用交回面板）。[br]
## [br][b]金色边框是首通行的专属标记[/b]（GDD exploration-ui-system.md §7「首次通关
## 额外奖励高亮展示（金色边框）」）：色值 [code]#C8A84E[/code] 是美术圣经「墨骨丹青」
## 的金色档，探索 UI 里统一用它（[code]map_card.gd[/code] 的推荐边框同值），
## 不新造一个金色。[br]
## [br][b]文字即标记[/b]：首通行除了边框，段标题本身就写着「⭐ 首次通关奖励」——
## 色盲玩家不靠颜色也能分辨这一段。[br]
##
## 来源: design/gdd/exploration-ui-system.md §7 地图通关结算、
## ADR-0031 §2、.claude/rules/ui-code.md（双输入 + 焦点可见 + 色盲可读）、
## 先例 [code]meditation_panel_layout.gd[/code] / [code]shop_panel_layout.gd[/code]。

## 控件树样式来源（尺寸与焦点环只在那一处定义）。
const ShopLayoutScript := preload("res://src/ui/exploration/shop_panel_layout.gd")

const FONT_SIZE_BODY: int = ShopLayoutScript.FONT_SIZE_BODY
const ITEM_HEIGHT: int = ShopLayoutScript.ITEM_HEIGHT
## 面板比商店略窄：本面板只有一两段文本与一行卡牌，不需要货架的横向空间。
const PANEL_WIDTH: int = 640
const PANEL_HEIGHT: int = 460

## 标题行高度（比正文行高——与商店标题字号配套）。
const TITLE_HEIGHT: int = 40
## 段标题行高度。
const SECTION_HEIGHT: int = 32
## 只读文本行高度（比可点行矮）。
const LINE_HEIGHT: int = 26
## 卡牌行前的小额缩进（首通行缩进更明显，视觉上从属于段标题）。
const INDENT_CARD: int = 12
const INDENT_FIRST: int = 24

## 「下一张去哪」行的字色（同推荐卡边框的金色——两处指向同一件事）。
const NEXT_MAP_COLOR: Color = Color("#C8A84E")

## 首通行的金色边框（GDD §7 明文要求；色值同 node_graph_renderer 的已访问边）。
const FIRST_CLEAR_BORDER_COLOR: Color = Color("#C8A84E")
const FIRST_CLEAR_BORDER_WIDTH: int = 2
const FIRST_CLEAR_CORNER_RADIUS: int = 4
## 首通行底色（极淡金——与边框组成双通道标记，不只靠边框颜色）。
const FIRST_CLEAR_BG_COLOR: Color = Color(0.78, 0.66, 0.31, 0.14)


## 构建面板控件树（复用商店布局——标题与「确认」按钮的意图出口同源）。[br]
## [br][param p_panel] 面板根节点。[br]
## [br][b]「确认」语义[/b]：本面板只有一个出口，故 [param p_confirm_signal] 直接转发
## 面板自己声明的信号名（默认 [code]&"confirmed"[/code]）。[b]必须传已声明的信号[/b]
## ——[method Object.emit_signal] 对未声明的名字不报编译错、只在运行时静默失败
## （[code]ERR_UNAVAILABLE[/code]），届时按钮点了没反应。[br]
## [br][b]返回[/b]：[code]{panel, title_label, map_label, count_label, item_box,
## message_label, leave_button}[/code]——面板持有这些引用（不按控件路径查找）。[br]
## [br][b]为什么复用商店布局的 [code]balance_label[/code] 位当地图名[/b]：它是标题行
## 右侧的横向填充位，本面板没有余额可显示，空着不如放地图名（GDD §7 线框第二行）。
static func build(p_panel: Control, p_title: String,
		p_confirm_signal: StringName = &"confirmed",
		p_confirm_text: String = "") -> Dictionary:
	var parts: Dictionary = ShopLayoutScript.build(p_panel, p_title, p_confirm_signal)
	var leave: Button = parts["leave_button"] as Button
	leave.name = "ConfirmButton"
	if not p_confirm_text.is_empty():
		leave.text = p_confirm_text

	var title_label: Label = parts["title_label"] as Label
	title_label.custom_minimum_size = Vector2(0.0, TITLE_HEIGHT)
	# 地图名——标题行右侧（线框第二行）；不叫 balance 是因为本面板没有余额语义。
	var map_label: Label = parts["balance_label"] as Label
	return {
		"panel": parts["panel"],
		"title_label": title_label,
		"map_label": map_label,
		"item_box": parts["item_box"],
		"message_label": parts["message_label"],
		"leave_button": leave,
	}


## 追加一行只读文本（地图名下方的次数行 / 无奖励兜底）。[br]
## [br][b]不是 [Button][/b]：纯文本不可点——游标（[ShopPanelNavigator]）会把非
## [Button] 的行当禁用跳过，键盘不会停在没有动作的行上。
static func add_status_line(p_item_box: VBoxContainer, p_text: String) -> Label:
	var label := Label.new()
	label.name = "Status%d" % p_item_box.get_child_count()
	label.text = p_text
	label.custom_minimum_size = Vector2(0.0, LINE_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	p_item_box.add_child(label)
	return label


## 追加一个段标题（📦 通关奖励 / ⭐ 首次通关奖励）。[br]
## [br][param p_gold] true 时套首通金色标记（边框 + 底色）——纯文本行也能带框，
## 因为它被包进 [PanelContainer]（[Button] 的样式槽不适用于只读文本）。[br]
## [br][b]返回[/b]：段容器（卡牌行挂进它，视觉上从属于段标题）。
static func add_section(p_item_box: VBoxContainer, p_text: String,
		p_gold: bool = false) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.name = "Section%d" % p_item_box.get_child_count()
	box.add_theme_constant_override("separation", 6)
	if p_gold:
		var frame := PanelContainer.new()
		frame.name = "GoldFrame"
		frame.add_theme_stylebox_override(&"panel", first_clear_stylebox())
		box.add_child(frame)
		var heading := _make_heading(p_text)
		frame.add_child(heading)
	else:
		box.add_child(_make_heading(p_text))
	p_item_box.add_child(box)
	return box


## 追加一段只读奖励行（灵石/修为）。[br]
## [br][param p_target] 段落容器（[method add_section] 的返回值——不传时挂到列表根）。[br]
## [br][b]缩进[/b]：首通段的行缩进更明显，一眼看出从属于哪个段标题。
static func add_reward_line(p_target: Node, p_text: String, p_gold: bool = false) -> Label:
	var label := Label.new()
	label.name = "Reward%d" % p_target.get_child_count()
	label.text = p_text
	label.custom_minimum_size = Vector2(0.0, LINE_HEIGHT)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE_BODY)
	if p_gold:
		label.add_theme_color_override(&"font_color", FIRST_CLEAR_BORDER_COLOR)
	var margin := _indent_of(label, INDENT_FIRST if p_gold else INDENT_CARD)
	p_target.add_child(margin)
	return label


## 追加一行卡牌（可点——GDD §7「点击奖励卡牌可查看详情」）。[br]
## [br][b]为什么是可点的 [Button][/b]：卡牌详情要能点开，且键盘/手柄也要能选中
## （[code]focus_mode = FOCUS_ALL[/code] + 焦点环）。[br]
## [br][param p_on_pressed] 点击/确认回调 [code]func() -> void[/code]。
static func add_card_row(p_target: Node, p_text: String,
		p_on_pressed: Callable, p_gold: bool = false) -> Button:
	var button := Button.new()
	button.name = "Card%d" % p_target.get_child_count()
	button.text = p_text
	button.custom_minimum_size = Vector2(0.0, ITEM_HEIGHT)
	button.focus_mode = Control.FOCUS_ALL
	ShopLayoutScript.apply_focus_ring(button)
	if p_gold:
		button.add_theme_stylebox_override(&"normal", first_clear_stylebox())
		button.add_theme_color_override(&"font_color", FIRST_CLEAR_BORDER_COLOR)
	button.pressed.connect(func() -> void: p_on_pressed.call())
	var margin := _indent_of(button, INDENT_FIRST if p_gold else INDENT_CARD)
	p_target.add_child(margin)
	return button


## 按结算载荷填两个奖励段（基础段 + 首通段）——[b]段与行的排版全在本模块[/b]。[br]
## [br][b]为什么整段下放到这里[/b]：面板脚本要守在 300 行软上限内，而「每段画成什么
## 样」本身就是排版（本模块的职责）；面板只拿到画好的行去登记游标。[br]
## [br][param p_rules] 文案内核脚本（[code]map_clear_panel_rules.gd[/code]——段标题、
## 段内行文本都由它给，本模块不另写措辞）。[br]
## [param p_on_card] 卡牌行被点击/确认的回调 [code]func(index: int) -> void[/code]
## ——[code]index[/code] 是本方法返回的行序（基础段在前、首通段在后）。[br]
## [br][b]返回[/b]：[code]{titles: Array, buttons: Array, entries: Array}[/code]——
## 三者同序；[code]entries[/code] 是各卡牌行的载荷条目（面板点开详情时取它）。[br]
## [br][b]首通段只在载荷要求时画[/b]（判据是 [code]is_first_clear[/code]，见 Rules 类文档
## ——用「奖励是否为空」当判据会把「首通但配置漏写」也一并藏掉）。
static func fill_sections(p_item_box: VBoxContainer, p_view: Dictionary,
		p_rules: GDScript, p_on_card: Callable) -> Dictionary:
	var result: Dictionary = {"titles": [], "buttons": [], "entries": []}
	var flags: Array = [false]
	if p_rules.shows_first_section(p_view):
		flags.append(true)
	for first: Variant in flags:
		var gold: bool = bool(first)
		var title: String = p_rules.TEXT_FIRST_SECTION if gold else p_rules.TEXT_BASE_SECTION
		var section: VBoxContainer = add_section(p_item_box, title, gold)
		(result["titles"] as Array).append(title)
		for line: Variant in p_rules.section_amount_lines(p_view, gold):
			add_reward_line(section, str(line), gold)
		for entry: Variant in p_rules.section_cards(p_view, gold):
			var index: int = (result["buttons"] as Array).size()
			(result["entries"] as Array).append(entry)
			(result["buttons"] as Array).append(add_card_row(section,
					p_rules.card_row_text(entry),
					func() -> void: p_on_card.call(index), gold))
	return result


## 追加「下一张去哪」引导行（GDD §7 面板之后的去向——措辞由 Rules 给）。[br]
## [br][b]不可点[/b]：它是导航提示而非入口（点了既不会进图也不该关面板）；
## 真正的入口是底下的地图卡片。[br]
## [br][b]空文本不出行[/b]：调用方与 Rules 之间多一层保护，空串不占版面。
static func add_next_line(p_item_box: VBoxContainer, p_text: String) -> Label:
	var label: Label = add_status_line(p_item_box, p_text)
	if label != null:
		label.add_theme_color_override(&"font_color", NEXT_MAP_COLOR)
	return label


## 首通段的金色标记样式（边框 + 淡金底——双通道，不只靠颜色）。[br]
## [br][b]幂等[/b]：每次返回新实例但只覆盖同一个样式槽，不叠加。
static func first_clear_stylebox() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = FIRST_CLEAR_BG_COLOR
	box.set_border_width_all(FIRST_CLEAR_BORDER_WIDTH)
	box.border_color = FIRST_CLEAR_BORDER_COLOR
	box.set_corner_radius_all(FIRST_CLEAR_CORNER_RADIUS)
	box.content_margin_left = 10.0
	box.content_margin_right = 10.0
	box.content_margin_top = 6.0
	box.content_margin_bottom = 6.0
	return box


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 段标题标签（字号略大于正文，左对齐）。
static func _make_heading(p_text: String) -> Label:
	var heading := Label.new()
	heading.name = "Heading"
	heading.text = p_text
	heading.custom_minimum_size = Vector2(0.0, SECTION_HEIGHT)
	heading.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", FONT_SIZE_BODY + 2)
	return heading


## 给控件套一层左缩进（缩进是排版细节，不该让每个调用点各写一遍 MarginContainer）。[br]
## [br][b]缩进挂在 [MarginContainer] 上而不是控件自身[/b]：控件最小宽度由内容决定，
## 直接改 offset 会被容器的布局重算覆盖掉。
static func _indent_of(p_control: Control, p_pixels: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.name = "Indent"
	margin.add_theme_constant_override(&"margin_left", p_pixels)
	margin.add_child(p_control)
	return margin
