class_name DeployFormationPreview
extends Control
## DeployFormationPreview —— 备战面板阵位布局预览（combat-ui-layout Story 007）。
##
## [b]职责[/b]：按境界布局（前 N / 后 M）绘制两行阵位框，已选角色按顺序
## 填入前排再后排；未填位置画空位虚线框。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：槽位内容由面板经
## [method apply_preview] 下发（角色名列表 + 布局），本组件只绘制。[br]
## [br][b]数据驱动[/b]：前/后排位数来自 [DeployPanelRules.formation_slot_layout]，
## 本组件不内含境界映射。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]——选择变化由面板触发
## [method apply_preview] → [method queue_redraw]（信号驱动，≤1 帧）。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §8 阵位布局预览、
## combat-ui-layout Story 007（AC-4/AC-6）。

## === 尺寸/视觉常量 =========================================================

## 单槽位高度。
const SLOT_HEIGHT: float = 28.0
## 单槽位最小宽度。
const SLOT_MIN_WIDTH: float = 96.0
## 槽位间距。
const SLOT_GAP: float = 8.0
## 行间距。
const ROW_GAP: float = 10.0
## 行标签宽度（「前排」/「后排」）。
const LABEL_WIDTH: float = 48.0
## 空位框颜色（浅蓝虚线——空位语义，与阵法区灰虚线区分）。
const EMPTY_FRAME_COLOR: Color = Color(0.45, 0.58, 0.72, 0.7)
## 已填入槽位底色（淡金）。
const FILLED_COLOR: Color = Color(0.22, 0.19, 0.12)
## 已填入边框色（金）。
const FILLED_BORDER_COLOR: Color = Color("#E8C06A")
## 行标签文本色。
const LABEL_COLOR: Color = Color(0.80, 0.80, 0.78)
## 角色名文本色。
const NAME_COLOR: Color = Color(0.94, 0.92, 0.86)

## 基准字号（经 [CombatUiFont.font_size_responsive] 按分辨率缩放——
## story 001 共享模块条款：组件内禁内联字号）。
const LABEL_BASE_SIZE: int = 12
const NAME_BASE_SIZE: int = 12

const UiFont := preload("res://src/ui/combat/shared/combat_ui_font.gd")

## === 渲染快照 ==============================================================

## 布局 [code]{front, back}[/code]（[DeployPanelRules.formation_slot_layout] 结果）。
var layout: Dictionary = {}
## 已选角色名（顺序即填入顺序——前排优先）。
var selected_names: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	draw.connect(_draw_preview)


## 下发预览数据。[br]
## [param p_layout]: [code]{front, back, total}[/code]。[br]
## [param p_selected_names]: 已选角色显示名列表（按填入顺序）。
func apply_preview(p_layout: Dictionary, p_selected_names: Array) -> void:
	layout = p_layout
	selected_names = p_selected_names.duplicate()
	custom_minimum_size = _measure()
	# 非容器子节点不会自动撑开——同步 size 才能在裁剪/命中测试下正确
	size = custom_minimum_size
	queue_redraw()


## 取第 [param row_index] 行（0 = 前排，1 = 后排）已填入的角色名（测试断言用）。
## [br][b]返回[/b]: Array[String]——该行的名字列表（可能短于该行槽位数）。
func get_row_names(row_index: int) -> Array:
	var front: int = int(layout.get("front", 0))
	if row_index == 0:
		return selected_names.slice(0, mini(front, selected_names.size()))
	return selected_names.slice(mini(front, selected_names.size()))


## === 内部 ==================================================================

## 尺寸 = 标签宽 + 该行最大槽位数 × (槽宽 + 间距)，两行 + 行距。
func _measure() -> Vector2:
	var front: int = int(layout.get("front", 0))
	var back: int = int(layout.get("back", 0))
	var cols: int = maxi(front, back)
	if cols <= 0:
		return Vector2(LABEL_WIDTH, 0.0)
	var width: float = LABEL_WIDTH + cols * SLOT_MIN_WIDTH + (cols - 1) * SLOT_GAP
	return Vector2(width, SLOT_HEIGHT * 2.0 + ROW_GAP)


func _draw_preview() -> void:
	var front: int = int(layout.get("front", 0))
	var back: int = int(layout.get("back", 0))
	if front + back <= 0:
		return
	_draw_row(0, front, "前排")
	_draw_row(1, back, "后排")


## 绘制单行：标签 + N 个槽位（前 N 个填入已选名，其余空位虚线框）。
func _draw_row(row_index: int, slot_count: int, label: String) -> void:
	if slot_count <= 0:
		return
	var font_size: int = _font_size()
	var y: float = row_index * (SLOT_HEIGHT + ROW_GAP)
	draw_string(ThemeDB.fallback_font, Vector2(0, y + SLOT_HEIGHT * 0.68), label,
			HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH - 4.0, font_size, LABEL_COLOR)
	var names: Array = get_row_names(row_index)
	for i: int in range(slot_count):
		var x: float = LABEL_WIDTH + i * (SLOT_MIN_WIDTH + SLOT_GAP)
		var rect := Rect2(x, y, SLOT_MIN_WIDTH, SLOT_HEIGHT)
		if i < names.size():
			draw_rect(rect, FILLED_COLOR)
			draw_rect(rect, FILLED_BORDER_COLOR, false, 1.5)
			draw_string(ThemeDB.fallback_font,
					Vector2(x + 6, y + SLOT_HEIGHT * 0.68),
					str(names[i]), HORIZONTAL_ALIGNMENT_LEFT,
					SLOT_MIN_WIDTH - 12.0, font_size, NAME_COLOR)
		else:
			_draw_dashed_rect(rect)


## 响应式字号——统一经 [CombatUiFont]。
func _font_size() -> int:
	var vp: Viewport = get_viewport()
	var h: int = UiFont.TIER_FULL_HEIGHT
	if vp != null:
		var visible_h: float = vp.get_visible_rect().size.y
		if visible_h > 0.0:
			h = int(visible_h)
	return UiFont.font_size_responsive(NAME_BASE_SIZE, h)


## 空位虚线框。
func _draw_dashed_rect(rect: Rect2) -> void:
	var tl := rect.position
	var tr := Vector2(rect.end.x, rect.position.y)
	var br := rect.end
	var bl := Vector2(rect.position.x, rect.end.y)
	draw_dashed_line(tl, tr, EMPTY_FRAME_COLOR, 1.0, 4.0, true)
	draw_dashed_line(tr, br, EMPTY_FRAME_COLOR, 1.0, 4.0, true)
	draw_dashed_line(br, bl, EMPTY_FRAME_COLOR, 1.0, 4.0, true)
	draw_dashed_line(bl, tl, EMPTY_FRAME_COLOR, 1.0, 4.0, true)
