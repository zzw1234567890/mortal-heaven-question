extends GutTest
## 地图选择界面的文字容器 —— 标题/余额/底部滚动区与重入弹窗的行宽。[br]
## [br][b]本文件补的缺口[/b]：标题与余额两行此前各写死 360px 宽且不裁切，重入
## 弹窗的四行文案（含「传送费用：N灵石（基础价 N × 倍率 N）」这类会随余额变长的
## 拼接串）挤在 372px 的盒子里也没有兜底。[br]
## [br][b]覆盖[/b]：[br]
##   1. 标题与余额两行都开了裁切 + 省略号，且互不重叠（两行同占顶部一条）；[br]
##   2. 余额行随视口宽度走（贴右留白），不写死像素；[br]
##   3. 重入弹窗四行都开了换行——文案变长时折行而不是被裁；[br]
##   4. 弹窗的 VBox 容得下最长的费用行。[br]
## [br][b]为什么要实例化真实场景[/b]：这几行的锚点/偏移写在
## [code]map_select_screen.tscn[/code] 里，读 [code].tscn[/code] 文本断言属性
## 是绕过引擎的做法；挂起来量 [code]rect[/code] 才是玩家看得见的那个结果。[br]
##
## 来源: design/ux/exploration-ui.md §地图选择界面（顶部条 / 底部提示条）、
## design/gdd/exploration-ui-system.md §1/§6 重入确认弹窗、ADR-0031 §2。

const ScreenScene: PackedScene = preload("res://src/ui/exploration/map_select_screen.tscn")
const DialogScript := preload("res://src/ui/exploration/map_select_reentry_dialog.gd")

## 探明表里最长的一张图（7 字——条件行/地图名会用到）。
const LONGEST_NAME: String = "归墟·古魔战场"
## 大额费用（账号后期会出现——基础价 × 倍率都是四位数）。
const BIG_COST_ENTRY: Dictionary = {
	"name": LONGEST_NAME, "is_cleared": true, "reentry_allowed": true,
	"reentry_total": 123456, "reentry_base": 61728, "reentry_multiplier": 2,
}

var screen: Control = null


func before_each() -> void:
	screen = ScreenScene.instantiate()
	screen.set("animate", false)
	add_child_autofree(screen)
	await get_tree().process_frame


func _title() -> Label:
	return screen.get_node(NodePath("LayoutAnchor/TitleLabel")) as Label


func _balance() -> Label:
	return screen.get_node(NodePath("LayoutAnchor/BalanceLabel")) as Label


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 顶部两行
# ═══════════════════════════════════════════════════════════════════════════════

func test_header_labels_trim_instead_of_overflowing() -> void:
	# Assert——两行都带裁切 + 省略号兜底
	for label: Label in [_title(), _balance()]:
		assert_true(label.clip_text, "「%s」应开启裁切" % label.text)
		assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS,
				"「%s」应配省略号" % label.text)


func test_header_labels_do_not_overlap() -> void:
	# Assert——标题右缘不越过余额左缘（两行同占顶部一条，重叠就是压字）
	assert_lte(_title().get_rect().end.x, _balance().get_rect().position.x,
			"标题（到 %.0f）不应压住余额（起于 %.0f）"
			% [_title().get_rect().end.x, _balance().get_rect().position.x])


func test_balance_label_is_right_anchored_to_viewport() -> void:
	# Assert——余额行右缘贴着内容区右缘（锚点驱动，不写死像素）
	var anchor_rect: Control = screen.get_node(^"LayoutAnchor") as Control
	assert_almost_eq(_balance().get_rect().end.x, anchor_rect.size.x, 1.0,
			"余额行右缘应贴内容区右缘（%.0f）" % anchor_rect.size.x)


func test_balance_label_matches_production_format() -> void:
	# Assert——文案口径不变（既有集成测试按「灵石: N」锁定同一份格式）
	screen.call(&"_refresh_balance")
	assert_true(_balance().text.begins_with("灵石: "),
			"余额行应保持「灵石: N」格式，实际「%s」" % _balance().text)


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 底部滚动区不被顶部条压住
# ═══════════════════════════════════════════════════════════════════════════════

func test_scroll_area_starts_below_the_header() -> void:
	# Assert——卡片列表从标题行下方开始（不压住标题/余额）
	var scroll: ScrollContainer = screen.get_node(
			NodePath("LayoutAnchor/ScrollContainer")) as ScrollContainer
	assert_gte(scroll.get_rect().position.y, _title().get_rect().end.y,
			"滚动区（起于 %.0f）应在标题行（到 %.0f）之下"
			% [scroll.get_rect().position.y, _title().get_rect().end.y])


func test_scroll_area_leaves_bottom_margin() -> void:
	# Assert——滚动区底缘与内容区底缘留出边距（贴边留白）
	var anchor_rect: Control = screen.get_node(^"LayoutAnchor") as Control
	var scroll: ScrollContainer = screen.get_node(
			NodePath("LayoutAnchor/ScrollContainer")) as ScrollContainer
	assert_almost_eq(scroll.get_rect().end.y, anchor_rect.size.y, 1.0,
			"滚动区底缘应贴内容区底缘（%.0f）" % anchor_rect.size.y)


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 重入弹窗的行完整
# ═══════════════════════════════════════════════════════════════════════════════

func _dialog_labels() -> Array:
	var out: Array = []
	for name: String in ["MapLineLabel", "CostDetailLabel", "BalanceLabel", "WarnLabel"]:
		out.append(screen.get_node(NodePath("ReentryDialog/VBox/" + name)) as Label)
	return out


func test_reentry_dialog_lines_autowrap() -> void:
	# Assert——四行都换行（费用行会随余额变长，写死单行迟早裁字）
	for label: Label in _dialog_labels():
		assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART,
				"重入弹窗的 %s 应开启换行" % label.name)


func test_reentry_dialog_fits_biggest_cost_line() -> void:
	# Arrange——填一份大额费用条目
	var dialog_ctl: ConfirmationDialog = screen.get_node(^"ReentryDialog") as ConfirmationDialog
	var box: VBoxContainer = screen.get_node(^"ReentryDialog/VBox") as VBoxContainer
	var filler: RefCounted = DialogScript.new()
	filler.call(&"bind", dialog_ctl, _dialog_labels()[0], _dialog_labels()[1],
			_dialog_labels()[2], _dialog_labels()[3],
			dialog_ctl.get_ok_button())
	filler.call(&"show_for", BIG_COST_ENTRY, 999999, true)
	await get_tree().process_frame
	# Assert——最长的那行（费用明细）实际宽度不超盒子宽（超了就要换行，换行就看不出
	# 「哪一行是费用」；当前盒宽 504px 容得下实测 338px 的大额费用行）
	var cost: Label = _dialog_labels()[1]
	var font: Font = cost.get_theme_font(&"font")
	var need: float = font.get_string_size(cost.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			cost.get_theme_font_size(&"font_size")).x
	assert_lte(need, box.size.x,
			"最长费用行「%s」需 %.0fpx，盒子只有 %.0fpx"
			% [cost.text, need, box.size.x])
