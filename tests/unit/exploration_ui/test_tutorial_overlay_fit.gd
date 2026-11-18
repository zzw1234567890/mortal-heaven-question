extends GutTest
## 教程提示条 —— 贴底、完整、不盖住节点图（玩家反馈「字挡着、显示不全」的复现与防护）。[br]
## [br][b]本文件补的缺口[/b]：提示 Label 曾在正中央（盖在节点图上），改到底部后
## 宽度写死——三步文案里最长的一句实测 411px，而 Label 恰好是 411px：零余量，
## 字号或文案任一变动就裁字，且没有任何断言盯着它。[br]
## [br][b]覆盖[/b]：[br]
##   1. 宽度随视口走（不是写死的像素）且左右留白对等——提示条居中；[br]
##   2. 三步文案在最小支持分辨率（1280×720）下都完整显示（宽过 rect 才是裁字）；[br]
##   3. 底边贴地且整条在视口内（不越过下沿、不压到节点图上）。[br]
## [br][b]为什么是控件级[/b]：[code]NodeTutorialOverlay[/code] 自建控件树，
## [code]new()[/code] 即可建；读的是 [code]size[/code]/[code]offset[/code] 这类
## 可断言属性，不靠截图。[br]
##
## 来源: design/ux/exploration-ui.md §节点图主界面 States「教程覆盖（首次进入）」、
## ADR-0031 §2、.claude/rules/ui-code.md（最小与最大分辨率都要测）。

const OverlayScript := preload("res://src/ui/exploration/node_tutorial_overlay.gd")

## 最小支持分辨率（.claude/docs/technical-preferences.md —— PC 目标平台下限）。
const MIN_VIEWPORT: Vector2 = Vector2(1280.0, 720.0)

var host: Control = null
var overlay: Control = null
var label: Label = null


func before_each() -> void:
	# 宿主容器钉成最小分辨率——覆盖层在 [code]_init[/code] 里设了 FULL_RECT 锚，
	# 它的尺寸跟着宿主走（直接给它 size 会被锚点布局覆盖，引擎也会告警）。
	host = Control.new()
	host.name = "ViewportHost"
	host.size = MIN_VIEWPORT
	add_child_autofree(host)
	overlay = OverlayScript.new()
	host.add_child(overlay)
	label = overlay.get(&"_label") as Label
	assert_not_null(label, "教程覆盖应自建提示 Label")


## 把宿主缩到指定尺寸并等布局落定。
func _resize(p_size: Vector2) -> void:
	host.size = p_size
	await get_tree().process_frame


## 文本的渲染像素宽（教程提示走 theme override 字号，无 label_settings）。
func _text_width(p_text: String) -> float:
	var font: Font = label.get_theme_font(&"font")
	return font.get_string_size(p_text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			label.get_theme_font_size(&"font_size")).x


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 宽度随视口走
# ═══════════════════════════════════════════════════════════════════════════════

func test_label_width_tracks_viewport_not_a_fixed_pixel() -> void:
	# Arrange + Act——宿主在最小分辨率
	await _resize(MIN_VIEWPORT)
	# Assert——宽度 = 视口宽 − 两侧留白（写成固定像素时这条立刻失败）
	var expected: float = MIN_VIEWPORT.x - OverlayScript.TEXT_MARGIN * 2.0
	assert_almost_eq(label.size.x, expected, 1.0,
			"提示条宽应随视口走（期望 %.0f，实际 %.0f）" % [expected, label.size.x])


func test_label_margins_are_symmetric() -> void:
	# Arrange + Act
	await _resize(MIN_VIEWPORT)
	# Assert——左右留白对等（贴着一边会让居中失效）
	var left: float = label.position.x
	var right: float = overlay.size.x - label.get_rect().end.x
	assert_almost_eq(left, right, 1.0,
			"左右留白应相等（左 %.0f / 右 %.0f）" % [left, right])
	assert_almost_eq(left, OverlayScript.TEXT_MARGIN, 1.0,
			"左右留白应等于常量 TEXT_MARGIN（%.0f）" % OverlayScript.TEXT_MARGIN)


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 三步文案都完整显示
# ═══════════════════════════════════════════════════════════════════════════════

func test_every_step_text_fits_at_minimum_resolution() -> void:
	# Assert——逐句量「要多少 vs 拿到多少」
	var available: float = MIN_VIEWPORT.x - OverlayScript.TEXT_MARGIN * 2.0
	for raw: Variant in OverlayScript.STEP_TEXTS:
		var text: String = str(raw)
		var need: float = _text_width(text)
		assert_lte(need, available,
				"教程句「%s」需 %.0fpx，提示条只有 %.0fpx——会被裁掉"
				% [text, need, available])


func test_label_autowraps_so_longer_copy_wraps_instead_of_clipping() -> void:
	# Assert——换行开启：将来换词变长时向上长高，而不是裁掉后半句
	assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART,
			"提示条应开启智能换行（文案变长时折行而非裁字）")
	assert_eq(label.grow_vertical, Control.GROW_DIRECTION_BEGIN,
			"折行应向上生长（底边钉住，提示条不往下顶出屏幕）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 贴底且在视口内
# ═══════════════════════════════════════════════════════════════════════════════

func test_label_sits_above_the_bottom_edge_within_viewport() -> void:
	# Arrange + Act
	await _resize(MIN_VIEWPORT)
	# Assert——整条含在视口内（此前锚在正中，直接盖在节点图上）
	var viewport: Rect2 = Rect2(Vector2.ZERO, MIN_VIEWPORT)
	assert_true(viewport.encloses(label.get_rect()),
			"提示条 %s 应在视口 %s 内" % [label.get_rect(), viewport])


func test_label_bottom_stays_clear_of_the_viewport_edge() -> void:
	# Arrange + Act
	await _resize(MIN_VIEWPORT)
	# Assert——底边离视口下沿留出 [constant TEXT_BOTTOM_CLEARANCE]（贴边留白）
	var clearance: float = MIN_VIEWPORT.y - label.get_rect().end.y
	assert_almost_eq(clearance, clear_of(), 1.0,
			"提示条底边应离视口下沿 %.0fpx（实际 %.0f）" % [clear_of(), clearance])


## 提示条底边与视口下沿的应有间距——由两个版式常量合成（不另立一个数）。
func clear_of() -> float:
	return -OverlayScript.TEXT_BOTTOM_OFFSET


func test_label_is_horizontally_centered() -> void:
	# Assert——文案居中（提示条横跨整幅，靠对齐而不是靠位置表达居中）
	assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER,
			"教程文案应水平居中")
