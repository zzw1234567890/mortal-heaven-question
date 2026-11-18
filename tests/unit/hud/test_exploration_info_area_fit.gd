extends GutTest
## 右下信息组 —— 面板宽度随 AP 段数走（玩家反馈「右下角的显示也有问题，文字显示不全」）。[br]
## [br][b]本文件补的缺口[/b]：分段格是「每格 1 AP」，而境界越高段数越多（炼气 5 格
## → 化神 13 格）。面板此前写死 200px 宽、段条写死 140px 宽，13 格段条实测 252px
## ——它顶出面板右缘 52px 并压住右侧计数「13/13」，正是玩家在右下角看到的
## 「文字显示不全」。[br]
## [br][b]覆盖[/b]：[br]
##   1. 面板宽度按段条 + 计数算得（满格时够宽，低境界回落到最小宽度）；[br]
##   2. 段条与计数不压叠、都在面板内（前一版把它们放在同一行且各自写死宽度）；[br]
##   3. 段条文本在任一境界档下都不宽过自己的 rect（不裁字）。[br]
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
