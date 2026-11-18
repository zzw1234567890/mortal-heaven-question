extends GutTest
## 通知 Toast —— 高度随文本行数走（长句不被裁、不压到隔壁 Toast）。[br]
## [br][b]本文件补的缺口[/b]：Toast 的占位高度此前写死 32px 单行，而通知文案来自
## 各系统的拼接串（锁定条件「需筑基期 · 需通关苍玄古战场」、移动失败原因等）——
## 长句只会被裁掉后半句。[br]
## [br][b]覆盖[/b]：[br]
##   1. 高度按字体度量算行数（短句一行、长句按需长高）；[br]
##   2. Toast 文本开启换行——超出可用宽时折行而不是裁字；[br]
##   3. 玩家可见的典型长句在最小分辨率下确实只占一行（当前数据不缩水）。[br]
## [br][b]为什么是控件级[/b]：[code]NotificationToastArea[/code] 是场景组件，
## 实例化即建；断言读 [code]custom_minimum_size[/code] 与标签属性，不靠截图。[br]
##
## 来源: design/gdd/hud-system.md §4 通知系统、design/ux/hud.md 元素 12、
## ADR-0031 §2、.claude/rules/ui-code.md（最小分辨率完整）。

const TOAST_SCENE: PackedScene = preload("res://src/ui/hud/NotificationToastArea.tscn")
const AreaScript := preload("res://src/ui/hud/notification_toast_area.gd")

## 生产里会出现的典型长句（未解锁卡点击提示——Feature 层拼接）。
const LONG_NOTICE: String = "需筑基期 · 需通关苍玄古战场"
## 需要折行的一段（长过最小宽度减两侧留白——实测 436px > 336px，占两行）。
const WRAPPING_NOTICE: String = "行动力不足以抵达 Boss，请先返回地图选择界面再做打算，或先回复行动力"

var area: Control = null


func before_each() -> void:
	area = TOAST_SCENE.instantiate()
	area.animate = false
	add_child_autofree(area)


## 第 [param p_index] 个 Toast 的占位高度（按添加顺序）。
func _toast_height(p_index: int) -> float:
	var box: Node = area.get_node(^"StackContainer")
	var holder: Control = box.get_child(p_index) as Control
	return holder.custom_minimum_size.y


## 第 [param p_index] 个 Toast 的文本标签。
func _toast_label(p_index: int) -> Label:
	var box: Node = area.get_node(^"StackContainer")
	var holder: Control = box.get_child(p_index) as Control
	return (holder.get_node(^"SlidePanel") as Node).get_node(^"Text") as Label


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 高度按行数算
# ═══════════════════════════════════════════════════════════════════════════════

func test_short_notice_keeps_single_line_height() -> void:
	# Arrange + Act——一条很短的提示
	area.call(&"request_notification", "system", "已保存")
	# Assert——单行高度（短提示的观感与改动前一致）
	assert_almost_eq(_toast_height(0), AreaScript.TOAST_LINE_HEIGHT, 0.5,
			"短提示应保持单行高度 %.0f" % AreaScript.TOAST_LINE_HEIGHT)


func test_longer_notice_gets_more_height_than_shorter_one() -> void:
	# Arrange + Act——同一容器里放一条会折行的长句
	area.call(&"request_notification", "system", "已保存")
	area.call(&"request_notification", "system", WRAPPING_NOTICE)
	# Assert——长句占位高度严格大于短句（写死 32px 时两者相等 → 失败）
	assert_gt(_toast_height(1), _toast_height(0),
			"折行的长句（%.0f）应比短提示（%.0f）高"
			% [_toast_height(1), _toast_height(0)])


func test_height_matches_computed_line_count() -> void:
	# Arrange + Act
	area.call(&"request_notification", "system", WRAPPING_NOTICE)
	# Assert——占位高度 == 常量算出的行数 × 单行高（口径单一来源）
	var expected: float = float(area.call(&"toast_height", WRAPPING_NOTICE))
	assert_almost_eq(_toast_height(0), expected, 0.5,
			"占位高度应由 toast_height 算得（期望 %.0f，实际 %.0f）"
			% [expected, _toast_height(0)])


# ═══════════════════════════════════════════════════════════════════════════════
# 2. Toast 文本换行而非裁字
# ═══════════════════════════════════════════════════════════════════════════════

func test_toast_text_autowraps_instead_of_clipping() -> void:
	# Arrange + Act
	area.call(&"request_notification", "system", WRAPPING_NOTICE)
	# Assert——折行开启且不裁切（裁切会直接吃掉后半句）
	var label: Label = _toast_label(0)
	assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART,
			"Toast 文本应开启智能换行")
	assert_false(label.clip_text, "Toast 文本不该裁切——折行已保证放得下")


func test_text_keeps_horizontal_padding() -> void:
	# Arrange + Act
	area.call(&"request_notification", "system", LONG_NOTICE)
	# Assert——文字左右各留 [constant AreaScript.TOAST_PAD_H]，不贴面板边
	var label: Label = _toast_label(0)
	assert_almost_eq(label.offset_left, AreaScript.TOAST_PAD_H, 0.5,
			"文本左留白应为 %.0f" % AreaScript.TOAST_PAD_H)
	assert_almost_eq(label.offset_right, -AreaScript.TOAST_PAD_H, 0.5,
			"文本右留白应为 %.0f" % AreaScript.TOAST_PAD_H)


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 当前数据下不缩水
# ═══════════════════════════════════════════════════════════════════════════════

func test_production_length_notices_still_fit_one_line() -> void:
	# Arrange + Act——两条生产里真实会出现的长句
	area.call(&"request_notification", "system", LONG_NOTICE)
	area.call(&"request_notification", "system", "行动力已耗尽，无法抵达 Boss")
	# Assert——都还是单行（高度没被抬高，观感不变）
	for i: int in [0, 1]:
		assert_almost_eq(_toast_height(i), AreaScript.TOAST_LINE_HEIGHT, 0.5,
				"生产长句 #%d 在 %.0fpx 宽下应仍是单行"
				% [i, AreaScript.TOAST_MIN_WIDTH])
