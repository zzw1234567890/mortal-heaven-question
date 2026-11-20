extends GutTest
## 右下信息组 —— 面板宽度随 AP 段数走（玩家反馈「右下角的显示也有问题，文字显示不全」）。[br]
## [br][b]本文件补的缺口[/b]：分段格是「每格 1 AP」，而境界越高段数越多（炼气 5 格
## → 化神 13 格）。面板此前写死 200px 宽、段条写死 140px 宽，13 格段条实测 252px
## ——它顶出面板右缘 52px 并压住右侧计数「13/13」，正是玩家在右下角看到的
## 「文字显示不全」。[br]
## [br][b]覆盖[/b]：[br]
##   1. 面板宽度按段条 + 计数算得（满格时够宽，低境界回落到最小宽度）；[br]
##   2. 段条与计数不压叠、都在面板内（前一版把它们放在同一行且各自写死宽度）；[br]
##   3. 段条文本在任一境界档下都不宽过自己的 rect（不裁字）；[br]
##   4. 面板底色为深色、字色为浅色且亮度差够（玩家反馈「右下角一块白底很怪」）。[br]
## [br][b]为什么是控件级[/b]：这三条判据落在 [code]ExplorationInfoArea._apply_ap[/code]
## 与 tscn 的锚点/偏移上，脱开控件就没有「拿到多少 / 内容要多少」可言；信息组是
## 纯展示组件（[code]new()[/code] 即可建，不需要场景与 Autoload）。[br]
##
## 来源: design/gdd/hud-system.md §5 探索中 HUD（「AP ██░░ 3/5」）、
## design/ux/exploration-ui.md §节点图主界面（AP 分段格，每格 = 1 AP）、
## ADR-0031 §2、.claude/rules/ui-code.md（最小与最大分辨率都要完整）。

const INFO_SCENE: PackedScene = preload("res://src/ui/hud/ExplorationInfoArea.tscn")
const InfoScript := preload("res://src/ui/hud/exploration_info_area.gd")

## 境界 AP 上限全档（RealmSystem.REALMS 的 action_points：炼气→化神）。
const AP_LADDER: Array[int] = [5, 7, 9, 11, 13]

var info: Control = null


func before_each() -> void:
	info = INFO_SCENE.instantiate()
	add_child_autofree(info)


func _seg() -> Label:
	return info.get_node(^"ApSegmentLabel")


func _count() -> Label:
	return info.get_node(^"ApCountLabel")


## 文本的渲染像素宽——字号取 label_settings 优先（它覆盖主题字号，只读主题会算小）。
func _text_width(p_label: Label, p_text: String) -> float:
	var font: Font = p_label.get_theme_font(&"font")
	assert_not_null(font, "Label 应能取到字体")
	if font == null:
		return 0.0
	return font.get_string_size(p_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			p_label.label_settings.font_size).x


## 应用一档 AP 并等布局落定（最小尺寸变更在下一帧的布局里生效）。
func _apply(p_current: int, p_max: int) -> void:
	info.call(&"_apply_ap", p_current, p_max)
	await get_tree().process_frame


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 面板宽度按内容算
# ═══════════════════════════════════════════════════════════════════════════════

func test_panel_widens_enough_for_thirteen_segments() -> void:
	# Arrange + Act——满格（化神 13 AP）
	await _apply(0, 13)
	# Assert——面板宽度 ≥ 留白 + 段条 + 间隙 + 计数区
	var need: float = InfoScript.PANEL_PAD * 2.0 \
			+ _text_width(_seg(), _seg().text) + InfoScript.AP_GAP \
			+ InfoScript.AP_COUNT_WIDTH
	assert_gte(info.custom_minimum_size.x, need,
			"13 格段条下（%.0fpx）面板应撑到 %.0fpx，实际 %.0fpx"
			% [_text_width(_seg(), _seg().text), need, info.custom_minimum_size.x])


func test_panel_keeps_minimum_width_at_low_realm() -> void:
	# Arrange + Act——炼气 5 格
	await _apply(3, 5)
	# Assert——不收得比最小宽度还窄（否则地图名/层数先被裁）
	assert_eq(info.custom_minimum_size.x, InfoScript.PANEL_MIN_WIDTH,
			"5 格时段条只占 87px，面板应停在最小宽度 %.0f" % InfoScript.PANEL_MIN_WIDTH)


func test_panel_width_tracks_every_realm_step() -> void:
	# Arrange——逐档记录宽度
	var widths: Array[float] = []
	for max_ap: int in AP_LADDER:
		await _apply(max_ap, max_ap)
		widths.append(info.custom_minimum_size.x)
	# Assert——段数越多面板越宽（非递减，且高档确实更宽）
	for i: int in range(1, widths.size()):
		assert_lte(widths[i - 1], widths[i],
				"AP 上限 %d → %d 时段数变多，面板不该反而变窄（%s）"
				% [AP_LADDER[i - 1], AP_LADDER[i], widths])
	assert_gt(widths[widths.size() - 1], widths[0],
			"满档面板应明显宽于最低档（%s）" % [widths])


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 段条与计数不压叠、都在面板内
# ═══════════════════════════════════════════════════════════════════════════════

func test_segment_row_does_not_overlap_count_label() -> void:
	# Arrange + Act——满格：这正是压叠暴露出来的那一档
	await _apply(0, 13)
	# Assert——段条右缘在计数左缘之左
	assert_lte(_seg().get_rect().end.x, _count().get_rect().position.x,
			"段条（到 %.0f）不应压住计数（起于 %.0f）"
			% [_seg().get_rect().end.x, _count().get_rect().position.x])


func test_both_ap_labels_stay_inside_panel() -> void:
	# Arrange + Act
	await _apply(0, 13)
	# Assert——两个标签的 rect 都含在面板矩形里（此前段条宽到 252px 顶出 200px 的面板）
	var panel: Rect2 = Rect2(Vector2.ZERO, info.size)
	assert_true(panel.encloses(_seg().get_rect()),
			"段条 %s 应在面板 %s 内" % [_seg().get_rect(), panel])
	assert_true(panel.encloses(_count().get_rect()),
			"计数 %s 应在面板 %s 内" % [_count().get_rect(), panel])


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 段条文本不宽过自己的 rect（不裁字）
# ═══════════════════════════════════════════════════════════════════════════════

func test_segment_text_fits_its_rect_at_every_realm() -> void:
	# Assert——逐档量「文本要多少 vs 拿到多少」
	for max_ap: int in AP_LADDER:
		await _apply(max_ap, max_ap)
		var need: float = _text_width(_seg(), _seg().text)
		assert_lte(need, _seg().get_rect().size.x + 0.5,
				"AP 上限 %d（%d 格，需 %.0fpx）不应宽过段条 rect（%.0fpx）"
				% [max_ap, max_ap, need, _seg().get_rect().size.x])


func test_segment_and_count_labels_trim_instead_of_widening() -> void:
	# Assert——四个标签都开了裁切：万一将来文案超长，面板不会被顶出去
	for name: StringName in [&"MapLabel", &"ApSegmentLabel", &"ApCountLabel", &"LayerLabel"]:
		var label: Label = info.get_node(NodePath(String(name)))
		assert_true(label.clip_text,
				"%s 应开启 clip_text——否则长文本会把面板顶破（结构性防御）" % name)


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 面板底色与字色（玩家反馈「右下角一块白底很怪」）
# ═══════════════════════════════════════════════════════════════════════════════
# 本组补的缺口：面板此前坐米白半透明底（#F5F0E3 @0.85），而全局 UI 都是深色暗调
# ——玩家看到「一块白底很怪」；同一份 LabelSettings 的字色是墨黑，正好与全局相反。

## 面板背景的底色（Node 已由 ColorRect 改为带 StyleBoxFlat 的 Panel——从样式盒读）。
func _panel_bg() -> Color:
	var panel: Panel = info.get_node(^"PanelBackground") as Panel
	var style: StyleBox = panel.get_theme_stylebox(&"panel")
	return (style as StyleBoxFlat).bg_color


## 感知亮度（Rec. 709 加权——比「三通道均值」更贴近人眼对明暗的判断）。
func _luminance(p_color: Color) -> float:
	return 0.2126 * p_color.r + 0.7152 * p_color.g + 0.0722 * p_color.b


func test_panel_background_is_dark_not_near_white() -> void:
	# Act
	var bg: Color = _panel_bg()
	# Assert——三通道均压到 0.3 以下（米白 #F5F0E3 的三通道都在 0.88 以上）
	assert_lt(bg.r, 0.3, "面板底色 R 通道应为深色，实际 %.3f（底 %s）" % [bg.r, bg])
	assert_lt(bg.g, 0.3, "面板底色 G 通道应为深色，实际 %.3f（底 %s）" % [bg.g, bg])
	assert_lt(bg.b, 0.3, "面板底色 B 通道应为深色，实际 %.3f（底 %s）" % [bg.b, bg])


func test_panel_background_is_mostly_opaque() -> void:
	# Assert——半透明可以（要透出下层场景），但不能薄到读不清字
	assert_gte(_panel_bg().a, 0.75, "面板底色应基本不透明（实际 alpha %.2f）" % _panel_bg().a)


func test_text_luminance_contrasts_with_panel_background() -> void:
	# Arrange——量两个[b]不会被运行时改色[/b]的标签（MapLabel / LayerLabel）。
	# ApSegmentLabel / ApCountLabel 的颜色每次刷新都被 AP_COLORS 覆写
	# （ExploreInfoArea._set_label_color），它们的可读性由下一例单独判。
	var bg: Color = _panel_bg()
	# Assert——字色与底色亮度差 > 0.5（深底浅字，玩家读得清）
	for name: StringName in [&"MapLabel", &"LayerLabel"]:
		var label: Label = info.get_node(NodePath(String(name)))
		var fg: Color = label.label_settings.font_color
		assert_gt(absf(_luminance(fg) - _luminance(bg)), 0.5,
				"%s 字色 %s（亮度 %.2f）与底 %s（亮度 %.2f）的亮度差应 > 0.5"
				% [name, fg, _luminance(fg), bg, _luminance(bg)])


## AP 语义色在深底上的下限（感知亮度差）。[br]
## [br][b]为什么不跟正文一样卡 0.5[/b]：朱砂红 / 琉璃金是[b]有彩色[/b]，
## 感知亮度（Rec.709 加权）的天花板本就低——纯红 #FF0000 的感知亮度只有 0.21，
## 任何红色的 0.5 亮度差在深底上都不可能达到（要凑到只能把红兑成粉，
## 那就不是朱砂红了）。语义色改用「明显亮于底色」的下限，并另在旁边用
## 「色相可区分」保证三态互不混淆（见下一例）。
const AP_COLOR_LUMA_FLOOR: float = 0.25


func test_ap_semantic_colors_are_readable_on_dark_panel() -> void:
	# Arrange
	var bg: Color = _panel_bg()
	# Assert——三档语义色都明显亮于底色（深底上不会糊成一片）
	for state: String in ["normal", "warning", "critical"]:
		var color: Color = InfoScript.AP_COLORS[state]
		assert_gt(_luminance(color) - _luminance(bg), AP_COLOR_LUMA_FLOOR,
				"%s 档字色 %s（亮度 %.2f）应明显亮于底色 %s（亮度 %.2f）"
				% [state, color, _luminance(color), bg, _luminance(bg)])


func test_ap_normal_color_differs_from_warning_color() -> void:
	# Assert——正常态不再是墨黑（深底上会直接消失），且三档两两不同色
	var normal: Color = InfoScript.AP_COLORS["normal"]
	assert_gt(_luminance(normal), 0.5, "正常态字色应为浅色，实际 %s" % normal)
	assert_ne(normal, InfoScript.AP_COLORS["warning"], "正常态与警告态不应同色")
	assert_ne(InfoScript.AP_COLORS["warning"], InfoScript.AP_COLORS["critical"],
			"警告态与紧急态不应同色")
