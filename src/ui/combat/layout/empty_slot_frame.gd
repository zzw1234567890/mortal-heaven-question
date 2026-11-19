class_name EmptySlotFrame
extends Control
## EmptySlotFrame —— 阵亡空位虚线框（combat-ui-layout Story 003 AC-4）。
##
## [b]职责[/b]：角色阵亡移除后在其阵位显示的空位占位框——四边虚线自绘
## （与后排边框同族的蓝色系，虚线语义=「可补位空位」，区别于实线占位），
## 外加一条「已阵亡」戳记文字。[br]
## [b]为什么要文字[/b]：虚线框只说「这一格空着可以补位」，不说「这里原本的人没了」；
## 灰度模式或缩放到 50% 时虚线更接近一块空白——一条实色戳记是这一格里唯一
## 还读得出来的信息（同 [code]CombatCardDefeatMarker[/code] 在卡上挂戳记的理由）。[br]
## [b]零轮询[/b]：无 [code]_process()[/code]——纯静态绘制，无动画
## （减少动态天然满足——空位框本身即阵亡动画的静态替代终态）。[br]
## 由 [code]CombatDeathHandoff[/code] 在阵亡流程完成时创建、定位并填字。
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

## 戳记文字色（暖白——同 [code]CombatCardDefeatMarker.STAMP_TEXT_COLOR[/code]
## 的对比度口径，深色底上 ≥4.5:1）。
const STAMP_TEXT_COLOR: Color = Color(0.96, 0.94, 0.88)
## 戳记字号（pt——框内居中，非响应式分档：空位只有一条短文案，字号随分辨率
## 分档的收益不抵「框内字号与相邻卡上戳记不一致」的代价）。
const STAMP_FONT_SIZE: int = 14
## 戳记条高（px——文案容器高度，居中摆放）。
const STAMP_HEIGHT: float = 22.0

## 戳记 Label（[method set_defeat_text] 写入；空文案时隐藏）。
var _stamp: Label = null


## _init 构建子节点（不依赖场景树时序——同 [code]CharacterStatusCard[/code] 先例）。
func _init() -> void:
	_stamp = Label.new()
	_stamp.name = "DefeatStamp"
	_stamp.visible = false
	_stamp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_stamp)


## 设置空位上的阵亡戳记文字（空串 = 不显示，框回到「只是一格空位」）。[br]
## [br][b]调用时机[/b]：由 [code]CombatDeathHandoff[/code] 在框摆好位置之后调用
## ——文字条按 [member size] 居中，尺寸没定就先填字会摆错地方。
func set_defeat_text(p_text: String) -> void:
	if _stamp == null:
		return
	_stamp.text = p_text
	_stamp.visible = not p_text.is_empty()
	if p_text.is_empty():
		return
	_stamp.add_theme_font_size_override("font_size", STAMP_FONT_SIZE)
	_stamp.add_theme_color_override("font_color", STAMP_TEXT_COLOR)
	_stamp.size = Vector2(size.x, STAMP_HEIGHT)
	_stamp.position = Vector2(0.0, (size.y - STAMP_HEIGHT) * 0.5)


## 当前戳记文字（空串 = 无）——测试与调试读取，避免用例去翻子节点树。
func get_defeat_text() -> String:
	return "" if _stamp == null else _stamp.text


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
