class_name SettlementFrame
extends RefCounted
## SettlementFrame —— 结算/撤退/警示面板共用外框构建器（combat-ui-layout Story 008）。
##
## [b]职责[/b]：把「背景压暗 + 居中外框 + 内边距 + 纵向内容容器」这套三处重复的
## 控件结构收在一处（[SettlementPanel] / [RetreatDialog] /
## [TribulationWarningDialog] 共用）。不含判定逻辑、不含信号接线。[br]
## [br][b]不覆盖全屏[/b]（control-manifest：弹窗在节点附近弹出/不覆盖全屏）：
## 外框固定宽度居中、高度按面板种类给定；遮罩只做视觉隔离，不改变外框尺寸。[br]
## [br][b]边框可变色[/b]：渡劫变体走朱砂红（AC-7），其余淡墨——颜色由调用侧
## 按 [RetreatRules.retreat_border_color] 传入，本构建器不判断变体。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §9/§10、combat-ui-layout Story 008。

const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")
const UiFont := preload("res://src/ui/combat/shared/combat_ui_font.gd")

## 内容内边距（px）。
const PANEL_PADDING: float = 32.0
## 边框厚度（px——渡劫变体加粗另计）。
const BORDER_WIDTH: float = 1.5


## 构建外框并挂到 [param root]。[br]
## [param frame_size]: 外框尺寸（px——小于视口即满足「不覆盖全屏」）。[br]
## [param border_color]: 边框色（渡劫变体传朱砂红）。[br]
## [br][b]返回[/b]: [code]{backdrop, frame, margin, body_box}[/code]。
static func build(root: Control, frame_size: Vector2,
		border_color: Color = Rules.COLOR_PANEL_BORDER) -> Dictionary:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Rules.COLOR_BACKDROP
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(backdrop)

	var frame := Panel.new()
	frame.name = "Frame"
	_apply_frame_box(frame, frame_size)
	frame.add_theme_stylebox_override("panel", make_stylebox(border_color))
	root.add_child(frame)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, int(PANEL_PADDING))
	frame.add_child(margin)

	var body_box := VBoxContainer.new()
	body_box.name = "Body"
	body_box.add_theme_constant_override("separation", 10)
	margin.add_child(body_box)

	return {"backdrop": backdrop, "frame": frame, "margin": margin,
			"body_box": body_box}


## 面板样式盒（深底 + 指定色边框）。
static func make_stylebox(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Rules.COLOR_PANEL_BG
	style.border_color = border_color
	style.set_border_width_all(int(BORDER_WIDTH))
	style.set_corner_radius_all(4)
	return style


## 重设外框尺寸（换面板种类时调用——居中保持）。[br]
## [param frame]: [method build] 返回的 frame。[br]
## [param frame_size]: 新尺寸。
static func resize(frame: Control, frame_size: Vector2) -> void:
	if frame == null:
		return
	_apply_frame_box(frame, frame_size)


## 重设边框色（渡劫变体切换——同一外框复用，不重建控件树）。
static func set_border_color(frame: Control, border_color: Color) -> void:
	if frame == null:
		return
	frame.add_theme_stylebox_override("panel", make_stylebox(border_color))


## 响应式字号下发（[b]共享纯函数唯一落地处[/b]——combat-ui-layout Story 001
## 强制条款：后续 story 不得各自内联字号缩放）。[br]
## [param control]: 目标控件（Label / Button 等带 [code]font_size[/code] 主题项的控件）。[br]
## [param base_size]: 1920×1080 基准字号（pt）。[br]
## [param screen_height]: 屏幕高度（px——调用侧经 [method viewport_height] 取得）。[br]
## 三面板的统一入口，避免第四个面板再抄一遍 [method CombatUiFont.font_size_responsive]。
static func apply_font(control: Control, base_size: int, screen_height: int) -> void:
	if control == null:
		return
	control.add_theme_font_size_override("font_size",
			UiFont.font_size_responsive(base_size, screen_height))


## 屏幕高度（无窗口/未入树时回退 1080 基准——[method CombatUiFont.font_size_responsive] 输入）。[br]
## [param control]: 任一已入树控件（取所属 Viewport）。[br]
## [br][b]返回[/b]: 视口高度（px），异常时 [constant CombatUiFont.TIER_FULL_HEIGHT]。
static func viewport_height(control: Control) -> int:
	if control == null or control.get_viewport() == null:
		return UiFont.TIER_FULL_HEIGHT
	var h: float = control.get_viewport().get_visible_rect().size.y
	return int(h) if h > 0.0 else UiFont.TIER_FULL_HEIGHT


## 居中尺寸应用（PRESET_CENTER + 半尺寸偏移——外框不会撑满视口）。
static func _apply_frame_box(frame: Control, frame_size: Vector2) -> void:
	frame.set_anchors_preset(Control.PRESET_CENTER)
	frame.custom_minimum_size = frame_size
	frame.size = frame_size
	frame.position = -frame_size * 0.5
