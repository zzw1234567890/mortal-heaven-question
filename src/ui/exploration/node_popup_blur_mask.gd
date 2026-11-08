class_name NodePopupBlurMask
extends Control
## NodePopupBlurMask —— 弹窗背景模糊遮罩（exploration-ui Story 006 AC-11）。
##
## [b]职责[/b]：整屏模糊 + 压暗，弹窗期间覆盖节点图——让背景「可见但退到后面」。
## 不含开合编排（归 [NodeInteractionPopupHost]）。[br]
## [br][b]技术选型[/b]：复用暂停菜单的 [code]pause_blur.gdshader[/code]
## （事实单一归属，不新写 shader）：BackBufferCopy(COPY_MODE_VIEWPORT) 把整视口
## 拷进 BACKBUFFER，其上叠加带 ShaderMaterial 的 ColorRect 做高斯采样。[br]
## [br][b]为何 BackBufferCopy 不设 anchors[/b]：它继承 Node2D（无 Control 的
## anchors API）；COPY_MODE_VIEWPORT 忽略矩形、整视口拷贝，故仅需置于原点。[br]
## [br][b]零轮询[/b]（ADR-0031 §3）：无 [code]_process()[/code]——显隐由宿主
## 在开合时调用 [method show_blur]（Tween 淡入淡出在着色器强度上，非引擎动画）。
##
## 来源: design/gdd/exploration-ui-system.md §4「弹窗背景模糊 40%」、ADR-0031 §3、
## src/ui/hud/pause_blur.gdshader（暂停菜单先例）。

## 背景模糊着色器（与暂停菜单同源）。
const BlurShader: Shader = preload("res://src/ui/hud/pause_blur.gdshader")
## 视觉常量单一来源（模糊 40% / 压暗 25%——GDD §4 + 弹窗规格同归 Rules）。
const Rules := preload("res://src/ui/exploration/node_interaction_rules.gd")
## 模糊半径（像素——与暂停菜单同档；纯渲染采样参数，不属业务规格）。
const BLUR_RADIUS: int = 4

## 模糊矩形（着色器承载面；显隐与强度都改它的材质参数）。
var _blur_rect: ColorRect = null


func _init() -> void:
	name = "PopupMask"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build()


## 遮罩显隐——[param show_it] 为 true 时置顶并设满模糊，否则隐藏并归零强度。[br]
## 置顶由宿主在弹窗打开后再次调用 [method Control.move_to_front] 覆盖。
func show_blur(show_it: bool) -> void:
	if _blur_rect == null:
		return
	visible = show_it
	_blur_rect.material.set_shader_parameter(&"blur_amount",
			Rules.BLUR_AMOUNT if show_it else 0.0)


## 当前模糊强度（测试查询——遮罩可见时为 [constant NodeInteractionRules.BLUR_AMOUNT]）。
func get_blur_amount() -> float:
	if _blur_rect == null or _blur_rect.material == null:
		return 0.0
	return float(_blur_rect.material.get_shader_parameter(&"blur_amount"))


func _build() -> void:
	var back_buffer := BackBufferCopy.new()
	back_buffer.name = "BackBufferCopy"
	# Node2D 无 anchors API——COPY_MODE_VIEWPORT 忽略矩形，整视口拷贝到 BACKBUFFER
	back_buffer.position = Vector2.ZERO
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(back_buffer)

	_blur_rect = ColorRect.new()
	_blur_rect.name = "BlurRect"
	_blur_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_blur_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blur_rect.color = Color(0, 0, 0, 0)
	var material := ShaderMaterial.new()
	material.shader = BlurShader
	material.set_shader_parameter(&"blur_amount", 0.0)
	material.set_shader_parameter(&"blur_radius", BLUR_RADIUS)
	material.set_shader_parameter(&"dim_color", Color(0, 0, 0, Rules.DIM_ALPHA))
	_blur_rect.material = material
	add_child(_blur_rect)
