class_name DeployCharacterCard
extends Control
## DeployCharacterCard —— 备战面板角色缩略卡（combat-ui-layout Story 007）。
##
## [b]职责[/b]：单角色缩略卡自绘——头像块 / 角色名 / HP / ATK / 绑定概览角标 /
## 4 态标记（✓ ☐ ⊕ 💀）。备战用缩略卡为独立实现（Out of Scope 明文：
## Story 002 角色状态卡不复用）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：角色数据（HP/ATK/绑定/阵亡）由
## [DeployRosterReader] 读取后经 [method apply_data] 下发；本组件只持渲染快照。
## 选中态为面板级瞬态交互状态——本卡只渲染不决策。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——每次状态变化由面板调用
## [method set_selection_state] 触发 [method queue_redraw]。[br]
## [br][b]文字即标记[/b]：✓ ☐ ⊕ 💀 走 [method CanvasItem.draw_string]（非独立纹理），
## 满足 control-manifest「绝不使用独立纹理渲染 UI 图标」。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §8 备战阶段UI、
## combat-ui-layout Story 007（AC-1/AC-2）。

const Rules := preload("res://src/ui/combat/shared/deploy_panel_rules.gd")
const UiFont := preload("res://src/ui/combat/shared/combat_ui_font.gd")

## === 尺寸常量（缩略卡——GDD §8 角色选择网格）=================================

const CARD_WIDTH: float = 112.0
const CARD_HEIGHT: float = 150.0
## 头像块高度（顶部）。
const AVATAR_HEIGHT: float = 72.0
## 内边距。
const PADDING: float = 6.0
## 绑定角标尺寸（右下角）。
const BADGE_SIZE: float = 18.0

## === 基准字号（经 [CombatUiFont.font_size_responsive] 按分辨率缩放）===========

const MARK_BASE_SIZE: int = 16
const NAME_BASE_SIZE: int = 13
const STAT_BASE_SIZE: int = 12
const BADGE_BASE_SIZE: int = 11

## 焦点环颜色（松石青——与 [code]hand_card.gd[/code] / [code]map_card.gd[/code] 同色，
## 全项目「这一格是键盘游标所在」只用这一种颜色）。
const FOCUS_RING_COLOR: Color = Color(0.35, 0.85, 0.8)
## 焦点环线宽（px——比状态边框粗，一眼分得出「边框」与「焦点」）。
const FOCUS_RING_WIDTH: float = 3.0

## === 状态视觉常量（GDD §8 4 态表）==========================================

## 已选边框色（金色高亮）。
const SELECTED_BORDER_COLOR: Color = Color("#E8C06A")
## 可替换边框色（⊕——正常色 + 淡金提示）。
const REPLACEABLE_BORDER_COLOR: Color = Color("#B8A060")
## 可选边框色（正常墨色）。
const NORMAL_BORDER_COLOR: Color = Color(0.55, 0.55, 0.58)
## 不可用边框色（灰）。
const UNAVAILABLE_BORDER_COLOR: Color = Color(0.35, 0.35, 0.38)
## 头像底色（占位——真实立绘走资产管线）。
const AVATAR_COLOR: Color = Color(0.20, 0.26, 0.34)
## 不可用头像底色（灰化）。
const AVATAR_DEAD_COLOR: Color = Color(0.22, 0.22, 0.24)
## 名称文本色。
const NAME_COLOR: Color = Color(0.92, 0.92, 0.90)
## 数值文本色。
const STAT_COLOR: Color = Color(0.80, 0.82, 0.86)
## 不可用文本色（灰）。
const DEAD_TEXT_COLOR: Color = Color(0.55, 0.55, 0.58)
## 绑定角标底色。
const BADGE_COLOR: Color = Color(0.35, 0.30, 0.22)

## === 状态标记符号（GDD §8 4 态表）==========================================

const MARK_SELECTED: String = "✓"
const MARK_SELECTABLE: String = "☐"
const MARK_REPLACEABLE: String = "⊕"
const MARK_UNAVAILABLE: String = "💀"

## === 实例状态 ==============================================================

## 角色实例 ID（card_instance_id）。
var character_id: int = -1
## 玩家左键点了这张卡——由 [DeployPanel] 接住去 [code]toggle_selection[/code]。[br]
## [br][b]为什么需要这条信号[/b]：卡片此前只接了 [code]mouse_entered[/code] /
## [code]mouse_exited[/code]（悬停提示），而 [code]mouse_filter = STOP[/code] 会把
## 左键[b]吞掉[/b]——玩家点卡什么都不发生。备战阶段玩家唯一能做的事就是改选出战
## 角色，点不动等于这一屏只有「确认出战」可操作。[br]
## [br][b]本卡不决策[/b]（零状态所有权）：能不能选、超没超上限、要不要走替换流程
## 全归面板的 [code]toggle_selection[/code]，本卡只上报「有人点了这张」。
signal card_pressed


## 渲染快照（由 [method apply_data] 下发）。
var data: Dictionary = {}
## 当前 4 态（[DeployPanelRules] 常量之一）。
var selection_state: String = Rules.STATE_SELECTABLE


func _init() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size = custom_minimum_size
	# 鼠标左键由卡自己收（见 [signal card_pressed]）——悬停提示与点选同属本卡。
	# [b]STOP 是必需的[/b]：IGNORE 会让点击穿透到面板底下，玩家点卡仍然什么都不发生。
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# 键盘/手柄（.claude/rules/ui-code.md 双输入）：纯 Control 默认 FOCUS_NONE，
	# 显式开启才能被 Tab 走到、才收得到 ui_accept；焦点环自绘（引擎不为自绘控件
	# 画焦点视觉，同 [code]hand_card.gd[/code] 口径）。
	focus_mode = Control.FOCUS_ALL
	focus_entered.connect(_on_focus_changed)
	focus_exited.connect(_on_focus_changed)
	gui_input.connect(_on_gui_input)
	# 绘制入口——状态变化只需 queue_redraw（零轮询）
	draw.connect(_draw_card)


## 应用角色数据快照。[br]
## [param p_character_id]: 角色实例 ID。[br]
## [param p_data]: [code]{display_name, hp, attack, binding_count, faction_tags, is_dead}[/code]。
func apply_data(p_character_id: int, p_data: Dictionary) -> void:
	character_id = p_character_id
	data = p_data
	queue_redraw()


## 设置 4 态（面板判定后下发——本组件不自行判定）。
func set_selection_state(p_state: String) -> void:
	if selection_state == p_state:
		return
	selection_state = p_state
	queue_redraw()


## 当前显示名（测试与面板协同信息消费）。
func get_display_name() -> String:
	return str(data.get("display_name", ""))


## 角色实例 ID（面板以 [code]Control[/code] 持有卡片时经此类型化访问——
## 审查 M7：避免面板侧对 Control 直接读脚本自定义成员）。
func get_character_id() -> int:
	return character_id


## 当前 4 态字符串（面板经此读态，避免静态类型信息丢失）。
func get_state() -> String:
	return selection_state


## 角色阵营标签列表（协同信息计算用）。
func get_faction_tags() -> Array:
	var tags: Variant = data.get("faction_tags", [])
	return (tags as Array).duplicate() if tags is Array else []


## 是否阵亡（面板用于排除不可选角色）。
func is_dead() -> bool:
	return bool(data.get("is_dead", false))


## === 内部：绘制 ============================================================

func _draw_card() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var dead: bool = selection_state == Rules.STATE_UNAVAILABLE
	# 头像块（占位底色——真实立绘走资产管线）
	var avatar_color: Color = AVATAR_DEAD_COLOR if dead else AVATAR_COLOR
	draw_rect(Rect2(0, 0, size.x, AVATAR_HEIGHT), avatar_color)
	# 边框（状态色 + 已选加粗）
	var border_color: Color = _border_color_for(selection_state)
	var border_width: float = 2.5 if selection_state == Rules.STATE_SELECTED else 1.5
	draw_rect(Rect2(Vector2.ZERO, size), border_color, false, border_width)
	# 状态标记（右上角）
	var mark: String = _mark_for(selection_state)
	draw_string(ThemeDB.fallback_font, Vector2(size.x - 20, 18), mark,
			HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size(MARK_BASE_SIZE), border_color)
	# 角色名（头像底部）
	var name_color: Color = DEAD_TEXT_COLOR if dead else NAME_COLOR
	draw_string(ThemeDB.fallback_font, Vector2(PADDING, AVATAR_HEIGHT + 16),
			get_display_name(), HORIZONTAL_ALIGNMENT_LEFT,
			size.x - PADDING * 2.0, _font_size(NAME_BASE_SIZE), name_color)
	# HP / ATK（两行）
	var stat_color: Color = DEAD_TEXT_COLOR if dead else STAT_COLOR
	draw_string(ThemeDB.fallback_font, Vector2(PADDING, AVATAR_HEIGHT + 36),
			"HP:%d" % int(data.get("hp", 0)), HORIZONTAL_ALIGNMENT_LEFT,
			size.x - PADDING * 2.0, _font_size(STAT_BASE_SIZE), stat_color)
	draw_string(ThemeDB.fallback_font, Vector2(PADDING, AVATAR_HEIGHT + 54),
			"ATK:%d" % int(data.get("attack", 0)), HORIZONTAL_ALIGNMENT_LEFT,
			size.x - PADDING * 2.0, _font_size(STAT_BASE_SIZE), stat_color)
	# 绑定概览角标（右下角——绑定数量 > 0 才画）
	var binding_count: int = int(data.get("binding_count", 0))
	if binding_count > 0:
		var badge_rect := Rect2(size.x - BADGE_SIZE - 2,
				size.y - BADGE_SIZE - 2, BADGE_SIZE, BADGE_SIZE)
		draw_rect(badge_rect, BADGE_COLOR)
		draw_string(ThemeDB.fallback_font,
				Vector2(badge_rect.position.x + 3, badge_rect.position.y + 13),
				str(binding_count), HORIZONTAL_ALIGNMENT_LEFT, -1,
				_font_size(BADGE_BASE_SIZE), Color(0.95, 0.85, 0.55))
	# 焦点环画在最后（压在所有内容之上——键盘游标所在的那一格要一眼找得到）
	if has_focus():
		draw_rect(Rect2(Vector2.ZERO, size), FOCUS_RING_COLOR, false, FOCUS_RING_WIDTH)


## === 内部：输入 ============================================================

## 左键点击 / 键盘确认（Tab 走到本卡后按 Enter / 空格）。
## [br][b]只上报不决策[/b]：选中与否归面板的 [code]toggle_selection[/code]。
## [br][b]为什么同时认 [code]ui_accept[/code][/b]：焦点在纯 [Control] 上时引擎内置的
## 焦点导航不会替它把确认键翻译成点击（那是 [Button] 的行为），不显式处理等于
## 键盘玩家能选中这一格却按不动。
func _on_gui_input(p_event: InputEvent) -> void:
	if p_event is InputEventMouseButton:
		var mouse: InputEventMouseButton = p_event
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			accept_event()
			card_pressed.emit()
		return
	if p_event.is_action_pressed(&"ui_accept"):
		accept_event()
		card_pressed.emit()


## 焦点进出——重画焦点环（引擎不为自绘控件画焦点视觉）。
func _on_focus_changed() -> void:
	queue_redraw()


## 响应式字号——统一经 [CombatUiFont]（story 001 共享模块条款：组件内禁内联字号）。
func _font_size(base_size: int) -> int:
	return UiFont.font_size_responsive(base_size, _screen_height())


## 屏幕高度——取视口高度（无窗口时回退 1080 基准）。
func _screen_height() -> int:
	var vp: Viewport = get_viewport()
	if vp == null:
		return UiFont.TIER_FULL_HEIGHT
	var h: float = vp.get_visible_rect().size.y
	return int(h) if h > 0.0 else UiFont.TIER_FULL_HEIGHT


## 4 态 → 边框色。
func _border_color_for(p_state: String) -> Color:
	match p_state:
		Rules.STATE_SELECTED:
			return SELECTED_BORDER_COLOR
		Rules.STATE_REPLACEABLE:
			return REPLACEABLE_BORDER_COLOR
		Rules.STATE_UNAVAILABLE:
			return UNAVAILABLE_BORDER_COLOR
		_:
			return NORMAL_BORDER_COLOR


## 4 态 → 标记符号。
func _mark_for(p_state: String) -> String:
	match p_state:
		Rules.STATE_SELECTED:
			return MARK_SELECTED
		Rules.STATE_REPLACEABLE:
			return MARK_REPLACEABLE
		Rules.STATE_UNAVAILABLE:
			return MARK_UNAVAILABLE
		_:
			return MARK_SELECTABLE
