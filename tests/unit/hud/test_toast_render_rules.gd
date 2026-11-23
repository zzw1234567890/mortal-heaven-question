extends GutTest
## Toast 渲染件的[b]纯计算[/b]部分单元测试（拆档位后新增——见
## [code]notification_toast_area.gd[/code]「三件外援」注记）。
##
## [b]为什么现在才补[/b]：行数推算原先长在组件方法 [code]toast_height[/code] 里，
## 要先实例化 [code]NotificationToastArea.tscn[/code] 拿到 [code]StackContainer[/code]
## 的主题字体才能调——只能做控件级断言。拆出 [method
## NotificationToastRender.line_count_for_width] 之后，「宽度 → 行数」这段不再需要
## 控件树、不再需要字体，可以逐条摆数字。[br]
## [br][b]不重复什么[/b]：[code]test_toast_text_fit.gd[/code]（控件级）已覆盖
## 「短句单行 / 长句更高 / 开启折行」；本案只钉纯函数的边界，不动那些既有用例。[br]
## [br]依据：design/gdd/hud-system.md §4、编码标准「公式与边缘情况需单元测试」。

const RenderScript := preload("res://src/ui/hud/notification_toast_render.gd")

## 可用宽（= 最小宽 360 减两侧各 12——由常量推导，不写字面量）。
const AVAIL: float = RenderScript.TOAST_TEXT_WIDTH


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 宽度 → 行数
# ═══════════════════════════════════════════════════════════════════════════════

func test_line_count_rounds_up_at_the_boundary() -> void:
	# Arrange + Act —— 恰好等于可用宽时仍是 1 行；多 0.1px 就要 2 行
	# Assert —— 若改成 floor 或写死 1，本案在第二个断言转红
	assert_eq(RenderScript.line_count_for_width(AVAIL, AVAIL), 1,
			"恰好占满可用宽应算 1 行（不应提前折行）")
	assert_eq(RenderScript.line_count_for_width(AVAIL + 0.1, AVAIL), 2,
			"超出可用宽哪怕 0.1px 也应算 2 行（向上取整，宁可多给空白也不裁字）")


func test_line_count_is_at_least_one_for_empty_or_zero_width() -> void:
	# Arrange + Act + Assert —— 空串 / 零宽 / 负的可用宽都不会算出 0 行
	# （0 行在布局上等于「不可见」，不是我们要的）
	assert_eq(RenderScript.line_count_for_width(0.0, AVAIL), 1,
			"空文本应算 1 行")
	assert_eq(RenderScript.line_count_for_width(500.0, 0.0), 1,
			"可用宽为 0 时应安全回退 1 行（除零不成立）")
	assert_eq(RenderScript.line_count_for_width(500.0, -10.0), 1,
			"可用宽为负时应安全回退 1 行")


func test_line_count_grows_monotonically_with_width() -> void:
	# Arrange —— 三档宽度：一行内 / 两行 / 三行
	var cases: Array = [[AVAIL * 0.5, 1], [AVAIL * 1.5, 2], [AVAIL * 2.5, 3]]
	# Act + Assert
	for case: Array in cases:
		var width: float = case[0]
		var expected: int = case[1]
		assert_eq(RenderScript.line_count_for_width(width, AVAIL), expected,
				"宽 %.1f 在可用宽 %.1f 下应为 %d 行" % [width, AVAIL, expected])


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 行数 → 高度（单一出处：holder 占位与内层排版用同一组常量）
# ═══════════════════════════════════════════════════════════════════════════════

func test_height_scales_by_line_height_constant() -> void:
	# Arrange + Act + Assert —— 高度 = 行数 × 单行高（不在别处再写一份 32）
	assert_almost_eq(RenderScript.height_for_lines(2),
			RenderScript.TOAST_LINE_HEIGHT * 2.0, 0.01,
			"两行高应为单行高的两倍")
	assert_almost_eq(RenderScript.height_for_lines(0),
			RenderScript.TOAST_LINE_HEIGHT, 0.01,
			"0 行应兜到 1 行高（不允许算出 0 高度）")


func test_height_for_text_without_font_falls_back_to_single_line() -> void:
	# Arrange —— 没有字体就没有折行信息
	# Act + Assert —— 兜成一行高，而不是崩或返回 0
	assert_almost_eq(RenderScript.height_for_text("很长很长的一段提示文字", null),
			RenderScript.TOAST_LINE_HEIGHT, 0.01,
			"字体为 null 时应兜到单行高（少给不如给一行）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. color 标识 → 颜色
# ═══════════════════════════════════════════════════════════════════════════════

func test_color_lookup_falls_back_for_unknown_key() -> void:
	# Arrange + Act —— 试一个不存在的标识
	var unknown: Color = RenderScript.color_for("no_such_color")
	# Assert —— 落到 white（淡墨），而不是透明或黑色
	# （透明会让文字凭空消失——这是「未知类型安全默认」的最后一层兜底）
	assert_eq(unknown, RenderScript.TEXT_COLORS[RenderScript.DEFAULT_COLOR_KEY],
			"未知 color 标识应兜到默认键（%s）" % RenderScript.DEFAULT_COLOR_KEY)
	assert_gt(unknown.a, 0.0, "兜底色不得是透明的（透明等于文字消失）")


func test_known_color_keys_map_to_art_bible_hex_values() -> void:
	# Arrange —— 与 art-bible §4.1 同源的 hex 口径
	var expected: Dictionary = {
		"green": Color("#4A9494"),
		"gold": Color("#C8A84E"),
		"red": Color("#C23B3B"),
	}
	# Act + Assert
	for key: String in expected.keys():
		assert_eq(RenderScript.color_for(key), expected[key],
				"color 标识 %s 应映射到 art-bible 的 %s" % [key, expected[key]])
