extends GutTest
## 身份选择详情面板「提示层」文字色的收口回归（全库最后一处硬编码
## [code]theme_override_colors[/code]）。
##
## [b]背景[/b]：[code]identity_select.tscn[/code] 的 [code]HintLabel[/code]（显示身份的
## 「出牌风格提示」[code]playstyle_hint[/code]）写死了
## [code]theme_override_colors/font_color = Color(0.42, 0.4, 0.37, 1)[/code]——≈[code]#6B6660[/code]，
## 比主题的 T-3 禁用档 [code]#68645C[/code] 还暗。它是四屏主题化那一轮刻意留着的
## 「待定夺」项（[code]docs/auditoria-ui-theme-2026-11-23.md[/code] §五 第 1 条）。[br]
## [br][b]本轮定夺：改用 [code]CaptionText[/code] 变体（T-2 [code]#98948C[/code]）[/b]，
## 判据三条：[br]
##   ① [b]语义档位对不上[/b]：art-bible §4.7.2 的四级是「主标题 / 正文 / 次要说明 /
##      [b]禁用[/b]」——T-3 是[b]禁用[/b]档。这条提示在身份已选中时照常显示，不是
##      禁用态；比禁用档更暗等于「一个可读的信息被画得比不能用的东西还弱」。[br]
##   ② [b]它同屏的兄弟都是「次要说明」[/b]：[code]NameLabel[/code] 20 / 另外三个 14，
##      只有它是 13 且无变体——挂 [code]CaptionText[/code] 正好对上它自己已经在用的
##      13 号字档（[code]CaptionText[/code] 的 font_size 就是 13）。[br]
##   ③ [b]全库唯一性[/b]：收掉它之后 [code]src/[/code] 下再无
##      [code]theme_override_colors[/code]——配色只有一个出处（主题）。
##
## [b]不选 DisabledText 的原因[/b]：那个变体虽然色值（T-3）比原来「亮」一点点，
## 但它表达的是「不能操作」。提示层要说的是「这是补充信息」，不是「这条不能点」。[br]
## [br]依据：art-bible §4.7.2；[code]theme/main.tres[/code]；
## [code]docs/auditoria-ui-theme-2026-11-23.md[/code] §五。

const IDENTITY_SCENE: PackedScene = preload("res://src/ui/identity_select/identity_select.tscn")

## art-bible §4.7.2 的 T-2（次要说明）——[code]CaptionText[/code] 的取值。
const T2: Color = Color("#98948C")

## 需要扫的源码根（判「全库最后一处」用）。
const SCAN_ROOTS: Array[String] = ["res://src"]

var _screen: Control = null


func before_each() -> void:
	_screen = IDENTITY_SCENE.instantiate() as Control
	add_child_autofree(_screen)


## 提示标签（详情面板下）。
func _hint() -> Label:
	return _screen.get_node_or_null(
			^"LayoutAnchor/DetailPanel/HintLabel") as Label


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 提示层落到主题的次要说明档
# ═══════════════════════════════════════════════════════════════════════════════

func test_identity_hint_uses_theme_caption_variation() -> void:
	# Arrange —— before_each 已实例化并进树（变体解析需要树的上下文）
	var hint: Label = _hint()
	# Assert
	assert_not_null(hint, "详情面板下应有 HintLabel")
	assert_eq(hint.theme_type_variation, &"CaptionText",
			"提示层应挂 CaptionText 变体，而不是靠节点覆写色值")


func test_identity_hint_color_comes_from_theme_tier_two() -> void:
	# Arrange
	var hint: Label = _hint()
	if hint == null:
		fail_test("详情面板下应有 HintLabel")
		return
	# Act —— 主题解析（进树后变体生效）。对照组：同一棵树下的一枚「裸 Label」
	# （无变体）——它解析到基类档 T-1。两值不等才说明变体真的生效了。
	var resolved: Color = hint.get_theme_color(&"font_color")
	var control: Label = Label.new()
	hint.add_child(control)
	var base_tier: Color = control.get_theme_color(&"font_color")
	control.queue_free()
	# Assert
	assert_eq(resolved, T2, "提示层颜色应为主题 T-2（#98948C）")
	assert_ne(resolved, base_tier,
			"CaptionText 应覆盖基类 Label 档（%.4f vs %.4f）——相等说明变体没生效"
			% [resolved.r, base_tier.r])


func test_identity_hint_keeps_its_thirteen_pixel_tier() -> void:
	# Arrange
	var hint: Label = _hint()
	if hint == null:
		fail_test("详情面板下应有 HintLabel")
		return
	# Assert —— 字号没被顺手改掉（CaptionText 的 font_size 本就是 13）
	assert_eq(hint.get_theme_font_size(&"font_size"), 13,
			"提示层字号应仍是 13（换变体只应改色，不应改排版）")


func test_identity_hint_is_brighter_than_the_disabled_tier() -> void:
	# Arrange —— 这条是本轮定夺的判据：提示不是禁用态，不该比禁用档还暗
	var hint: Label = _hint()
	if hint == null:
		fail_test("详情面板下应有 HintLabel")
		return
	# Act
	var hint_luma: float = _luminance(hint.get_theme_color(&"font_color"))
	var disabled_luma: float = _luminance(Color("#68645C"))
	# Assert
	assert_gt(hint_luma, disabled_luma,
			"提示层亮度（%.4f）应高于 T-3 禁用档（%.4f）——它不是禁用态"
			% [hint_luma, disabled_luma])


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 全库不再有节点级配色覆写
# ═══════════════════════════════════════════════════════════════════════════════

## 扫 [code]src/[/code] 下全部 [code].tscn[/code]，找 [code]theme_override_colors[/code]。[br]
## 这一案在改 [code]identity_select.tscn[/code] 之前[b]会红[/b]（那处就是最后一例），
## 改完转绿——是「收干净了」这句结论的可执行形式，而不是靠人记着。[br]
## [br][b]为什么是 [code].tscn[/code] 全扫而不是只查这一个文件[/b]：任务原话是「这是全库
## 最后一处」，那就得按全库验；只查单文件的话下次谁再写一处也不会红。
func test_no_scene_declares_node_level_color_overrides() -> void:
	# Arrange
	var offenders: Array[String] = []
	# Act
	for root: String in SCAN_ROOTS:
		_scan_for_override(root, offenders)
	# Assert
	assert_eq(offenders, [] as Array[String],
			"场景里不该再有 theme_override_colors（配色统一走 theme/main.tres）；"
			+ "违规处：%s" % str(offenders))


## 递归扫目录，把含 [code]theme_override_colors[/code] 的 [code].tscn[/code] 记进
## [param p_out]（值里带行号，失败信息能直接定位）。
func _scan_for_override(p_dir: String, p_out: Array[String]) -> void:
	var dir: DirAccess = DirAccess.open(p_dir)
	if dir == null:
		fail_test("目录打不开：%s" % p_dir)
		return
	for sub: String in dir.get_directories():
		_scan_for_override(p_dir.path_join(sub), p_out)
	for file: String in dir.get_files():
		if not file.ends_with(".tscn"):
			continue
		var path: String = p_dir.path_join(file)
		var text: String = FileAccess.get_file_as_string(path)
		var lines: PackedStringArray = text.split("\n")
		for i: int in range(lines.size()):
			if lines[i].contains("theme_override_colors"):
				p_out.append("%s:%d" % [path, i + 1])


## WCAG 相对亮度（sRGB 线性化后加权）——与 [code]test_theme_resource.gd[/code] 同口径。
func _luminance(p_color: Color) -> float:
	var linear: Array[float] = []
	for raw: float in [p_color.r, p_color.g, p_color.b]:
		linear.append(raw / 12.92 if raw <= 0.03928 else pow((raw + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
