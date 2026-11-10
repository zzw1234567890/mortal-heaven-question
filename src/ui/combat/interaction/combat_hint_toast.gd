class_name CombatHintToast
extends Control
## CombatHintToast —— 战斗交互提示条（combat-ui-interaction 001 / 本轮：可读提示）。
##
## [b]职责[/b]：把出牌链路给出的中文提示（费用不足 / 目标已阵亡 / 阶段不对）显示
## 在手牌区上方，若干秒后自动消失——「点了没反应」是此前最糟的失败形态。[br]
## [br][b]文案来源[/b]：只显示 [code]CombatPlayResult.message[/code]，不自己拼串
## （同一原因多处措辞会漂移——文案集中在 result 模块）。[br]
## [br][b]零轮询[/b]（ADR-0031 §3）：无 [code]_process()[/code]——显示与消隐都由
## 一次性 Tween 驱动，重复调用 kill 重建。[br]
## [br][b]零状态所有权[/b]：本组件不判定「该不该提示」，只负责显示与消失。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §手牌交互（拒绝必须有提示）、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md。

## 默认显示时长（秒——足够读完一句「灵力不足：需要 5 点，当前 2 点」）。
const DEFAULT_SEC: float = 2.0
## 淡出时长（秒）。
const FADE_SEC: float = 0.3

## 文案色（暖白——与深色战场底对比足够）。
const TEXT_COLOR: Color = Color(0.98, 0.92, 0.78)
## 背板色（半透明深墨，保证文字可读）。
const BG_COLOR: Color = Color(0.06, 0.06, 0.09, 0.85)
## 字号（pt——经 font_size_responsive 缩放）。
const FONT_SIZE: int = 16
## 内边距（px）。
const PADDING: float = 10.0

## 宿主布局根提供的定位锚（手牌区上方）——由装配侧设置。
var _anchor: Control = null
## 正在显示的 Tween（重入 kill）。
var _tween: Tween = null
## 减少动态（淡出改为瞬时隐藏）。
var _reduce_motion: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var label := Label.new()
	label.name = "Text"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)


## 设置减少动态（淡出瞬时完成）。
func set_reduce_motion(p_reduce_motion: bool) -> void:
	_reduce_motion = p_reduce_motion


## 显示一条提示（空串忽略——「没有可显示的文案」不应变成一个空框）。[br]
## [param p_message] 中文提示文本（来自 [code]CombatPlayResult[/code]）。[br]
## [param p_seconds] 显示时长（秒）。
func show_message(p_message: String, p_seconds: float = DEFAULT_SEC) -> void:
	if p_message.strip_edges().is_empty():
		return
	var label: Label = get_node("Panel/Text") as Label
	label.text = p_message
	# 宽随文本自适应（上限 70% 屏宽——过长不撑爆整屏）
	var viewport_width: float = 1280.0
	if get_viewport() != null:
		viewport_width = get_viewport_rect().size.x
	label.custom_minimum_size = Vector2(0.0, 0.0)
	size = Vector2.ZERO
	custom_minimum_size = Vector2(minf(viewport_width * 0.7, float(p_message.length()) * 16.0 + PADDING * 2.0), 0.0)
	visible = true
	modulate.a = 1.0
	_reposition()
	_kill_tween()
	if _reduce_motion:
		_tween = create_tween()
		_tween.tween_interval(p_seconds)
		_tween.tween_callback(hide)
		return
	_tween = create_tween()
	_tween.tween_interval(p_seconds)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_SEC)
	_tween.tween_callback(hide)


## 立即隐藏并清 Tween（场景退场 / 取消选中时调用）。
func clear() -> void:
	_kill_tween()
	visible = false


## 当前显示的文本（测试断言用；未显示时为空串）。
func current_message() -> String:
	return String((get_node("Panel/Text") as Label).text) if visible else ""


# === 内部 =====================================================================

## 落到手牌区正上方居中（屏幕高度 72%——不遮手牌本体与提示 Label）。
func _reposition() -> void:
	if get_parent() is Control:
		var area: Vector2 = (get_parent() as Control).size
		if area.x <= 0.0 or area.y <= 0.0:
			return
		custom_minimum_size.x = minf(area.x * 0.7, custom_minimum_size.x)
		reset_size()
		position = Vector2((area.x - size.x) * 0.5, area.y * 0.72)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
