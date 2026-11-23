class_name LootOptionCard
extends Control
## LootOptionCard —— 战利品选项卡（combat-ui-layout Story 008）。
##
## [b]职责[/b]：单个战利品选项的自绘卡片——卡牌正面标题/副标题（稀有度·流派
## 或「×25」或「消耗品」）+ 3 态视觉（可选 / 已选中 / 卡组已满灰显）。
## 判定逻辑全部委托 [SettlementRules]（Logic 内核，BLOCKING 单测）；
## 本组件只渲染不决策、不发信号（点击流转归 interaction epic）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：选项数据由面板经 [method apply_option]
## 下发；[b]选中态是瞬态交互状态[/b]（§2.1 豁免）——由面板判定后下发。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——状态变化由面板调用
## [method set_state] 触发 [method queue_redraw]。[br]
## [br][b]文字即标记[/b]：全部视觉走 [method CanvasItem.draw_string] /
## [method CanvasItem.draw_rect]（非独立纹理——control-manifest 禁令）。[br]
## [br][b]等宽约束[/b]：宽度由面板按 [method SettlementRules.loot_grid_layout]
## 计算结果下发（GDD §边界情况「均匀网格」），卡片自身不假设宽度。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §9 战斗结算面板 / §边界情况、
## combat-ui-layout Story 008（AC-1/AC-3/AC-4）。

const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")
const UiFont := preload("res://src/ui/combat/shared/combat_ui_font.gd")

## 选项被点击（面板据此判定选中/灰显——本组件不自行决策）。
signal pressed(option_index: int)

## === 内边距与字号 =========================================================

const PADDING: float = 12.0
const TITLE_BASE_SIZE: int = 17
const SUBTITLE_BASE_SIZE: int = 13
const NOTE_BASE_SIZE: int = 13
## 标题基准线距内容块顶部距离（px）。
const TITLE_TOP: float = 28.0
## 副标题相对标题的垂直偏移（px）。
const SUBTITLE_OFFSET: float = 24.0
## 角标相对标题的垂直偏移（px）。
const NOTE_OFFSET: float = 52.0

## === 状态 =================================================================

## 选项下标（面板派发点击时回传）。
var option_index: int = -1
## 选项数据快照（[method apply_option] 下发）。
var option: Dictionary = {}
## 当前 3 态（[SettlementRules.OPTION_*]）。
var state: String = Rules.OPTION_AVAILABLE


func _init() -> void:
	custom_minimum_size = Vector2(0.0, Rules.LOOT_CELL_HEIGHT)
	# 接收点击（判定归面板——本组件只转发下标）
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# 键盘/手柄可达（.claude/rules/ui-code.md「交互元素必须同时支持键盘与手柄」）
	focus_mode = Control.FOCUS_ALL
	# 绘制入口——状态变化只需 queue_redraw（零轮询）
	draw.connect(_draw_card)
	gui_input.connect(_on_gui_input)
	# 焦点环重绘（键盘导航可见性——同样零轮询：焦点信号驱动）
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## 应用选项数据。[br]
## [param p_index]: 选项下标。[br]
## [param p_option]: 选项字典（[code]{kind, name, rarity, school, amount}[/code]）。[br]
## [param p_state]: 初始 3 态（[SettlementRules.loot_option_state] 结果）。
func apply_option(p_index: int, p_option: Dictionary, p_state: String) -> void:
	option_index = p_index
	option = p_option
	state = p_state
	queue_redraw()


## 设置 3 态（面板判定后下发——本组件不自行判定）。
func set_state(p_state: String) -> void:
	if state == p_state:
		return
	state = p_state
	queue_redraw()


## 当前 3 态。
func get_state() -> String:
	return state


## 当前是否可点（[SettlementRules.option_clickable]）。
func is_clickable() -> bool:
	return Rules.option_clickable(state)


## 卡片标题文案（测试与面板读取）。
func get_title_text() -> String:
	return str(Rules.loot_option_label(option)["title"])


## 鼠标左键 / 键盘确认——[b]同源同口径[/b]：都只在可点态转发同一个下标。[br]
## [br][b]为什么键盘走 [method _gui_input] 而非 [method _unhandled_key_input][/b]：
## Godot 4 把键盘事件投递到「当前获得焦点的 Control」的 [method _gui_input]，
## 这是 UI 焦点路径的保证通道；[method _unhandled_key_input] 是树序事件，
## 与焦点无关（会被前置节点抢先消费），用于 UI 控件会产生「聚焦也收不到」的漏洞。
func _on_gui_input(event: InputEvent) -> void:
	var activate: bool = false
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		activate = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		activate = key.pressed and not key.echo and has_focus() \
				and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER
						or key.keycode == KEY_SPACE)
	if not activate:
		return
	# 灰显态（卡组已满）不响应——与渲染态一致（0.5s 延迟窗口由面板裁决）
	if not is_clickable():
		return
	pressed.emit(option_index)
	accept_event()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：绘制
# ═══════════════════════════════════════════════════════════════════════════════

func _draw_card() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var muted: bool = state == Rules.OPTION_DECK_FULL
	var selected: bool = state == Rules.OPTION_SELECTED
	# 卡面底色（灰显态压暗）
	var fill: Color = Rules.COLOR_PANEL_BG
	if muted:
		fill = Color(fill.r * 0.6, fill.g * 0.6, fill.b * 0.6, fill.a)
	draw_rect(Rect2(Vector2.ZERO, size), fill)
	# 边框（已选金色加粗 / 普通淡墨）
	var border: Color = Rules.COLOR_SELECTED if selected else Rules.COLOR_PANEL_BORDER
	if muted:
		border = Rules.COLOR_MUTED
	var border_width: float = 3.0 if selected else 1.5
	draw_rect(Rect2(Vector2.ZERO, size), border, false, border_width)
	# 焦点环（键盘导航可见性——只画在获得焦点时，鼠标玩家不受影响）
	if has_focus():
		draw_rect(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)),
				Rules.COLOR_TITLE, false, 1.5)
	# 标题 + 副标题（垂直居中于卡面——基线口径由内核统一）
	var labels: Dictionary = Rules.loot_option_label(option)
	var block_top: float = Rules.loot_card_content_top(size.y)
	var text_color: Color = Rules.COLOR_MUTED if muted else Rules.COLOR_TITLE
	draw_string(ThemeDB.fallback_font,
			Vector2(PADDING, block_top + TITLE_TOP), str(labels["title"]),
			HORIZONTAL_ALIGNMENT_CENTER, size.x - PADDING * 2.0,
			_font_size(TITLE_BASE_SIZE), text_color)
	var sub_color: Color = Rules.COLOR_MUTED if muted else Rules.COLOR_BODY
	draw_string(ThemeDB.fallback_font,
			Vector2(PADDING, block_top + TITLE_TOP + SUBTITLE_OFFSET),
			str(labels["subtitle"]),
			HORIZONTAL_ALIGNMENT_CENTER, size.x - PADDING * 2.0,
			_font_size(SUBTITLE_BASE_SIZE), sub_color)
	# 角标（已选中 / 卡组已满——居中于副标题下方）
	var note: String = Rules.loot_option_note(state)
	if note.is_empty():
		return
	var note_color: Color = Rules.COLOR_MUTED if muted else Rules.COLOR_SELECTED
	draw_string(ThemeDB.fallback_font,
			Vector2(PADDING, block_top + TITLE_TOP + NOTE_OFFSET), "[%s]" % note,
			HORIZONTAL_ALIGNMENT_CENTER, size.x - PADDING * 2.0,
			_font_size(NOTE_BASE_SIZE), note_color)


## 响应式字号——统一经 [CombatUiFont]（组件内禁内联字号）。
func _font_size(base_size: int) -> int:
	return UiFont.font_size_responsive(base_size, _screen_height())


## 屏幕高度（无窗口时回退 1080 基准）。
func _screen_height() -> int:
	var vp: Viewport = get_viewport()
	if vp == null:
		return UiFont.TIER_FULL_HEIGHT
	var h: float = vp.get_visible_rect().size.y
	return int(h) if h > 0.0 else UiFont.TIER_FULL_HEIGHT
