class_name EnemyActionBanner
extends Control
## EnemyActionBanner —— 敌方战报的单行背板（纯渲染视图）。
##
## [b]职责[/b]：在战斗界面底部居中显示一行战报；显示/隐藏由
## [code]enemy_action_broadcast.gd[/code] 的队列节奏驱动。[br]
## [b]零状态所有权[/b]：只持有当前文本与背板节点，不读战斗数据、不播动画。[br]
## [b]为什么不并入播报组件[/b]：背板是「怎么画」，队列是「什么时候播」——
## 拆开后播报组件守在 300 行软上限内，渲染参数也只在一处。
##
## 来源: design/gdd/combat-ui-system.md §回合切换与敌方行动的可观测性。

## 背板 / 文字渲染参数。
const BANNER_BG: Color = Color(0.05, 0.06, 0.09, 0.86)
const BANNER_TEXT_COLOR: Color = Color(0.95, 0.93, 0.86)
const BANNER_FONT_SIZE: int = 20

var _panel: PanelContainer = null
var _label: Label = null


func _init() -> void:
	_build()


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel = PanelContainer.new()
	_panel.name = "BroadcastPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.anchor_left = 0.15
	_panel.anchor_right = 0.85
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = -116.0
	_panel.offset_bottom = -60.0
	_panel.add_theme_stylebox_override("panel", _make_style())
	add_child(_panel)
	_label = Label.new()
	_label.name = "BroadcastText"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", BANNER_FONT_SIZE)
	_label.add_theme_color_override("font_color", BANNER_TEXT_COLOR)
	_panel.add_child(_label)
	_panel.visible = false


## 显示一行战报。
func show_line(p_text: String) -> void:
	if _label == null or _panel == null:
		return
	_label.text = p_text
	_panel.visible = true


## 收起背板（批次结束 / 战斗结束 / 场景退场）。
func hide_banner() -> void:
	if _panel != null:
		_panel.visible = false


## 当前文本（测试断言用）。
func text() -> String:
	return _label.text if _label != null else ""


## 背板样式（纯色半透明 + 圆角 + 内边距）。
func _make_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BANNER_BG
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
