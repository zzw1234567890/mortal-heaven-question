class_name EmptySlotFrame
extends Control
## EmptySlotFrame —— 阵亡空位虚线框（combat-ui-layout Story 003 AC-4）。
##
## [b]职责[/b]：角色阵亡移除后在其阵位显示的空位占位框——四边虚线自绘
## （与后排边框同族的蓝色系，虚线语义=「可补位空位」，区别于实线占位）。[br]
## [b]零轮询[/b]：无 [code]_process()[/code]——纯静态绘制，无动画
## （减少动态天然满足——空位框本身即阵亡动画的静态替代终态）。[br]
## 由 [code]CombatFeedbackCoordinator[/code] 在阵亡流程完成时创建并定位。
##
## @experimental
## 来源: design/gdd/combat-ui-system.md §角色阵亡 AC（阵位变空——虚线框）、
## combat-ui-layout Story 003（AC-4）。

## 虚线框颜色（后排边框同族蓝——降低透明度表示「空位」语义）。
const FRAME_COLOR: Color = Color(0.45, 0.62, 0.85, 0.6)
## 虚线段长（与角色卡后排边框一致——视觉语言统一）。
const DASH_LENGTH: float = 6.0
## 线宽。
const LINE_WIDTH: float = 2.0


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var w: float = size.x
	var h: float = size.y
	# 四边分段虚线（同色 4 次绘制——直线合批友好，同 CharacterStatusCard 后排边框）
	draw_dashed_line(Vector2(0, 0), Vector2(w, 0), FRAME_COLOR,
		LINE_WIDTH, DASH_LENGTH, true)
	draw_dashed_line(Vector2(w, 0), Vector2(w, h), FRAME_COLOR,
		LINE_WIDTH, DASH_LENGTH, true)
	draw_dashed_line(Vector2(w, h), Vector2(0, h), FRAME_COLOR,
		LINE_WIDTH, DASH_LENGTH, true)
	draw_dashed_line(Vector2(0, h), Vector2(0, 0), FRAME_COLOR,
		LINE_WIDTH, DASH_LENGTH, true)
