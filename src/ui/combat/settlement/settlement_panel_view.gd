class_name SettlementPanelView
extends RefCounted
## SettlementPanelView —— 结算面板控件树构建器（combat-ui-layout Story 008）。
##
## [b]职责[/b]：只把胜利/战败面板的控件树建出来并回传引用字典；不含判定逻辑、
## 不含信号接线、不读数据——判定在 [SettlementRules]，编排在 [SettlementPanel]。
## 拆分理由：coding-standards 单文件 ≤300 行软上限（面板编排 + 控件构建曾同处一文件，
## 同 [DeployPanelView] 先例）。[br]
## [br][b]外框[/b]交给 [SettlementFrame]（与撤退/警示弹窗共用同一套
## 「压暗 + 居中 + 内边距」结构）。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §9 战斗结算面板、
## combat-ui-layout Story 008（AC-1/AC-5）。

const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")
const Frame := preload("res://src/ui/combat/settlement/settlement_frame.gd")
const CardScript := preload("res://src/ui/combat/settlement/loot_option_card.gd")

## === 布局常量（1920×1080 基准）=============================================

const TITLE_HEIGHT: float = 44.0
const HINT_HEIGHT: float = 24.0
const BUTTON_WIDTH: float = 150.0
const BUTTON_HEIGHT: float = 40.0
const TITLE_BASE_SIZE: int = 26
const BODY_BASE_SIZE: int = 16
const HINT_BASE_SIZE: int = 14


## 构建控件树并挂到 [param root]。[br]
## [param frame_size]: 初始外框尺寸（胜利面板高度）。[br]
## [br][b]返回[/b]: [code]{frame, body_box, title_label, hint_label, loot_grid,
## defeat_lines, confirm_button, skip_button, loot_delay_timer}[/code]。
static func build(root: Control, frame_size: Vector2) -> Dictionary:
	var parts: Dictionary = Frame.build(root, frame_size)
	var body_box: VBoxContainer = parts["body_box"] as VBoxContainer

	var title_label := Label.new()
	title_label.name = "Title"
	title_label.custom_minimum_size = Vector2(0, TITLE_HEIGHT)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_color_override("font_color", Rules.COLOR_TITLE)
	body_box.add_child(title_label)

	var hint_label := Label.new()
	hint_label.name = "LootHint"
	hint_label.custom_minimum_size = Vector2(0, HINT_HEIGHT)
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", Rules.COLOR_BODY)
	body_box.add_child(hint_label)

	var loot_grid := VBoxContainer.new()
	loot_grid.name = "LootGrid"
	loot_grid.add_theme_constant_override("separation", int(Rules.LOOT_GAP))
	loot_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_box.add_child(loot_grid)

	var defeat_lines := Label.new()
	defeat_lines.name = "DefeatLines"
	defeat_lines.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	defeat_lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
	defeat_lines.add_theme_color_override("font_color", Rules.COLOR_BODY)
	defeat_lines.visible = false
	body_box.add_child(defeat_lines)

	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	body_box.add_child(buttons)

	var confirm_button := Button.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.text = Rules.TEXT_CONFIRM_LOOT
	confirm_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	confirm_button.disabled = true
	buttons.add_child(confirm_button)

	var skip_button := Button.new()
	skip_button.name = "SkipButton"
	skip_button.text = Rules.TEXT_SKIP_LOOT
	skip_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	buttons.add_child(skip_button)

	# 0.5s 延迟计时器（一次性——到点翻转可点态，不轮询）
	var delay_timer := Timer.new()
	delay_timer.name = "LootDelayTimer"
	delay_timer.wait_time = Rules.LOOT_CLICK_DELAY_SEC
	delay_timer.one_shot = true
	root.add_child(delay_timer)

	return {
		"frame": parts["frame"], "body_box": body_box,
		"title_label": title_label, "hint_label": hint_label,
		"loot_grid": loot_grid, "defeat_lines": defeat_lines,
		"confirm_button": confirm_button, "skip_button": skip_button,
		"loot_delay_timer": delay_timer,
	}


## 响应式字号下发（[SettlementFrame.apply_font] 统一入口——本 story 不内联
## 字号缩放；[param parts] 为 [method build] 返回的引用字典）。[br]
## [br][b]时机[/b]：面板入树后调用（[method Node._ready]），此时才能拿到真实
## 视口高度；未入树时按 1080 基准（[constant CombatUiFont.TIER_FULL_HEIGHT]）。
static func apply_fonts(parts: Dictionary, screen_height: int) -> void:
	Frame.apply_font(parts.get("title_label") as Control, TITLE_BASE_SIZE, screen_height)
	Frame.apply_font(parts.get("hint_label") as Control, HINT_BASE_SIZE, screen_height)
	Frame.apply_font(parts.get("defeat_lines") as Control, BODY_BASE_SIZE, screen_height)
	Frame.apply_font(parts.get("confirm_button") as Control, BODY_BASE_SIZE, screen_height)
	Frame.apply_font(parts.get("skip_button") as Control, BODY_BASE_SIZE, screen_height)


## 战利品卡片重建（每次打开重排——数量随载荷变化）。[br]
## 卡片按 [constant SettlementRules.LOOT_COLUMNS] 列分行，每张等分行宽
## （GDD §边界情况「均匀网格」）。[br]
## [br][b]返回[/b]: 按选项顺序排列的卡片数组（调用侧持有用于状态下发）。[br]
## [br][param on_pressed]: 卡片点击回调（面板判定选中）。[br]
## [param deck_count]: 当前卡组张数。[br]
## [param deck_limit]: 当前卡组上限。
static func rebuild_loot_cards(grid: VBoxContainer, options: Array,
		deck_count: int, deck_limit: int, on_pressed: Callable) -> Array:
	clear_grid(grid)
	var cards: Array = []
	var row: HBoxContainer = null
	for i: int in range(options.size()):
		if i % Rules.LOOT_COLUMNS == 0:
			row = HBoxContainer.new()
			row.name = "LootRow%d" % int(i / Rules.LOOT_COLUMNS)
			row.add_theme_constant_override("separation", int(Rules.LOOT_GAP))
			grid.add_child(row)
		var card: Control = CardScript.new()
		card.name = "LootOption%d" % i
		# 均匀等宽：每张卡等分行宽（不假设固定像素宽）
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var option: Dictionary = options[i]
		card.apply_option(i, option,
				Rules.loot_option_state(option, deck_count, deck_limit))
		card.pressed.connect(on_pressed)
		row.add_child(card)
		cards.append(card)
	return cards


## 延迟窗口提示的视觉态（等待期灰 / 就绪期正文色）。[br]
## [param label]: 提示文本控件。[br]
## [param ready]: 是否已过 0.5s 延迟窗口。
static func apply_hint_style(label: Label, ready: bool) -> void:
	if label == null:
		return
	label.add_theme_color_override("font_color",
			Rules.COLOR_BODY if ready else Rules.COLOR_MUTED)


## 初始焦点（键盘可达性——优先第一张战利品卡，无卡时落到 [param fallback]）。[br]
## [br][b]未入树时跳过[/b]：纯逻辑测试里面板不入树，[code]grab_focus()[/code]
## 会打印错误并无效，此处显式守卫。
static func grab_initial_focus(cards: Array, fallback: Control) -> void:
	if not cards.is_empty() and (cards[0] as Control).is_inside_tree():
		(cards[0] as Control).grab_focus()
	elif fallback != null and fallback.is_inside_tree():
		fallback.grab_focus()


## 战利品卡等宽值（[method SettlementRules.loot_grid_layout] 口径：
## 面板内容宽 - 列间隔，按列数等分）。[br]
## [param panel_width]: 面板外框宽度（px）。
static func loot_cell_width(panel_width: float) -> float:
	var content_width: float = panel_width - Frame.PANEL_PADDING * 2.0
	return float(Rules.loot_grid_layout(content_width)["cell_width"])


## 清空网格（行容器整批移除——卡片随父节点释放）。[br]
## [param grid]: 战利品网格（行/卡片的父级）。
static func clear_grid(grid: VBoxContainer) -> void:
	if grid == null:
		return
	for row: Node in grid.get_children():
		grid.remove_child(row)
		row.queue_free()


## 键盘焦点环（.claude/rules/ui-code.md「交互元素必须同时支持键盘与手柄」）。[br]
## [br][b]为什么需要显式成环[/b]：战利品卡是自绘 Control，容器不自动推导其焦点邻接，
## 键盘玩家会卡在第一个可聚焦控件里（「焦点陷阱」）。此处按「卡片 → 确认 → 跳过」
## 顺序串成闭环，两端互指。[br]
## [param cards]: 当前战利品卡（可为空——战败面板无卡片）。[br]
## [param confirm]: 确认按钮。[br]
## [param skip]: 跳过按钮（胜利面板外为 null——单独成环）。
static func wire_focus_chain(cards: Array, confirm: Control, skip: Control) -> void:
	var ring: Array = []
	for card: Variant in cards:
		if card is Control:
			ring.append(card)
	for button: Variant in [confirm, skip]:
		if button is Control and (button as Control).visible:
			ring.append(button)
	if ring.is_empty():
		return
	# 相对 NodePath 需同处一棵场景树——未入树时跳过（宿主在 _ready 装配，生产路径恒在树内）
	if not (ring[0] as Control).is_inside_tree():
		return
	for i: int in range(ring.size()):
		var node: Control = ring[i]
		node.focus_next = node.get_path_to(ring[(i + 1) % ring.size()])
		node.focus_previous = node.get_path_to(ring[(i - 1 + ring.size()) % ring.size()])
