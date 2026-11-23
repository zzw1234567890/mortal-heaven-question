extends GutTest
## 主菜单文字色与列宽对齐回归（一周目界面走查 2026-11-22）。
##
## [b]背景[/b]：主菜单此前没有任何 [code]theme_override_colors[/code]，文字色全部
## 落到 Godot [b]内置默认主题[/b]——标题实测 9.30% 像素是纯白 RGB(255,255,255)，
## 按钮文字 4.33% 是冷灰 RGB(204,204,204)。项目无自定义 Theme 资源
## （[code]project.godot[/code] 无 [code]gui/theme/custom[/code]），所以暗底上
## 出现纯白/冷灰完全是「没覆写」的后果，与 art-bible 的四级暖色文字色不符。[br]
## [br]依据：[code]design/art/art-bible.md[/code] §4.7.2（文字色阶 T-0…T-3）、
## §4.7.3（按钮默认 T-1、悬停/按下/聚焦 T-0、禁用 T-3）。[br]
## [br][b]为什么同时验列宽[/b]：同一轮的像素走查发现 [code]UtilityBox[/code] 两枚
## 按钮（行囊与道友 / 读档）的 [code]custom_minimum_size.x[/code] 是 314，而主按钮列是
## 320——同屏两列按钮右边界差 7px（409 vs 416）。统一为 320 后列宽一致。[br]
## [br][b]2026-11-23 主题化后的两处调整[/b]：[br]
## ① [b]要进场景树[/b]。原先本文件不进树，断言的是 [code].tscn[/code] 里逐节点写的
## [code]theme_override_colors[/code]——那是节点自己的属性，脱树也在。改成主题
## [code]theme_type_variation[/code] 后，变体的解析需要 [code]ThemeDB[/code] 的上下文，
## [b]脱树解析不到[/b]（实测：脱树的 [code]CaptionText[/code] 标签回落到基类
## [code]Label[/code] 的 T-1，本用例当场红）。进树 + [code]animate = false[/code]
## （不播入场 Tween），断言口径不变——仍然只读主题色，不验 [code]_ready[/code] 后的
## 行为（那由 [code]test_menu_navigation.gd[/code] 覆盖）。[br]
## ② 色阶常量改用 [code]Color("#hex")[/code] 写法。原先是十进制字面量
## （[code]0.941176[/code] 等），换成主题后比的是主题里 [code]Color("#F0EBE0")[/code]
## 序列化出的 float32 值——两者[b]小数点后第七位不同[/b]，[code]==[/code] 判假却打印
## 一模一样。改用 hex 写法后与 art-bible、与生成器三处同一口径，逐位相等。[br]
## [br]依据：[code]design/art/art-bible.md[/code] §4.7.2、§4.7.3；主题落点
## [code]theme/main.tres[/code]（生成器 [code]tools/gen_theme.gd[/code]）。

const MAIN_MENU_SCENE: PackedScene = preload("res://src/ui/main_menu/MainMenu.tscn")

## art-bible §4.7.2 文字色阶（暖色四级）——hex 口径与主题生成器同源。
const T0: Color = Color("#F0EBE0")  # 主标题 / 高亮
const T1: Color = Color("#C8C4BC")  # 正文
const T2: Color = Color("#98948C")  # 次要说明
const T3: Color = Color("#68645C")  # 禁用

## 项目深色基底（[code]theme/main.tres[/code] 的 [code]GamePalette/backdrop[/code]）。
const BG: Color = Color("#0E0F16")

const MAIN_BUTTONS: Array[String] = [
	"NewGameButton", "ContinueButton", "SettingsButton", "DeckEditButton", "QuitButton",
]
const UTILITY_BUTTONS: Array[String] = ["InventoryButton", "LoadButton"]
## 说明性标签的完整节点路径（存档摘要挂在按钮列里，另两枚在 LayoutAnchor 与根下）。
const INFO_LABEL_PATHS: Array[String] = [
	"LayoutAnchor/ButtonBox/SaveSummaryLabel",
	"LayoutAnchor/NoSaveHintLabel",
	"VersionLabel",
]

var _menu: Control = null


func before_each() -> void:
	_menu = MAIN_MENU_SCENE.instantiate() as Control
	# animate = false：不播 0.8s 入场 Tween（本用例只看配色，不看动画）；进树原因见文件头。
	_menu.animate = false
	add_child(_menu)


func after_each() -> void:
	if _menu != null and is_instance_valid(_menu):
		_menu.free()
	_menu = null


# ═══════════════════════════════════════════════════════════════════════════════
# 文字色阶
# ═══════════════════════════════════════════════════════════════════════════════

func test_title_uses_primary_text_color_t0() -> void:
	var title: Label = _menu.get_node(NodePath("LayoutAnchor/TitleLabel")) as Label
	assert_not_null(title, "标题节点应在场")
	assert_eq(title.get_theme_color(&"font_color"), T0,
			"标题应为 T-0 暖白，而不是内置默认主题的纯白")


func test_main_buttons_default_to_secondary_color_t1() -> void:
	for button_name: String in MAIN_BUTTONS:
		var button: Button = _button(button_name)
		assert_not_null(button, "%s 应在场" % button_name)
		if button == null:
			continue
		assert_eq(button.get_theme_color(&"font_color"), T1,
				"%s 默认文字色应为 T-1" % button_name)


func test_utility_buttons_default_to_secondary_color_t1() -> void:
	for button_name: String in UTILITY_BUTTONS:
		var button: Button = _button(button_name)
		assert_not_null(button, "%s 应在场" % button_name)
		if button == null:
			continue
		assert_eq(button.get_theme_color(&"font_color"), T1,
				"%s 默认文字色应为 T-1" % button_name)


## §4.7.3：悬停 / 按下 / 聚焦三种交互态一律提到最高一级 T-0。
func test_buttons_highlight_to_t0_on_interaction() -> void:
	for button_name: String in MAIN_BUTTONS + UTILITY_BUTTONS:
		var button: Button = _button(button_name)
		assert_not_null(button, "%s 应在场" % button_name)
		if button == null:
			continue
		assert_eq(button.get_theme_color(&"font_hover_color"), T0,
				"%s 悬停应提亮到 T-0" % button_name)
		assert_eq(button.get_theme_color(&"font_pressed_color"), T0,
				"%s 按下应提亮到 T-0" % button_name)
		assert_eq(button.get_theme_color(&"font_focus_color"), T0,
				"%s 聚焦应提亮到 T-0" % button_name)


func test_buttons_dim_to_t3_when_disabled() -> void:
	for button_name: String in MAIN_BUTTONS + UTILITY_BUTTONS:
		var button: Button = _button(button_name)
		assert_not_null(button, "%s 应在场" % button_name)
		if button == null:
			continue
		assert_eq(button.get_theme_color(&"font_disabled_color"), T3,
				"%s 禁用应降到 T-3" % button_name)


func test_info_labels_use_tertiary_color_t2() -> void:
	for path: String in INFO_LABEL_PATHS:
		var label: Label = _menu.get_node(NodePath(path)) as Label
		assert_not_null(label, "%s 应在场" % path)
		if label == null:
			continue
		assert_eq(label.get_theme_color(&"font_color"), T2,
				"%s 属说明性文字，应为 T-2" % path)


# ═══════════════════════════════════════════════════════════════════════════════
# 色阶与对比度（程序可判定的部分）
# ═══════════════════════════════════════════════════════════════════════════════

## 四级色阶必须单调递暗——层级靠明度差表达，不能靠肉眼「差不多」。
func test_text_scale_is_monotonic_in_luminance() -> void:
	assert_gt(_luminance(T0), _luminance(T1), "T-0 应亮于 T-1")
	assert_gt(_luminance(T1), _luminance(T2), "T-1 应亮于 T-2")
	assert_gt(_luminance(T2), _luminance(T3), "T-2 应亮于 T-3")


## 正文及以上三级对深色基底须过 WCAG AA（4.5:1）；禁用色不承载信息，只要可见。
func test_text_colors_meet_contrast_on_dark_backdrop() -> void:
	assert_gt(_contrast(T0, BG), 4.5, "T-0 对基底应达 AA")
	assert_gt(_contrast(T1, BG), 4.5, "T-1 对基底应达 AA")
	assert_gt(_contrast(T2, BG), 4.5, "T-2 对基底应达 AA")
	assert_gt(_contrast(T3, BG), 2.0, "T-3 虽为禁用态也须可辨")


# ═══════════════════════════════════════════════════════════════════════════════
# 列宽对齐
# ═══════════════════════════════════════════════════════════════════════════════

## 工具按钮与主按钮列同宽——否则同屏两条纵向按钮列的右边界错开。
func test_utility_buttons_align_with_main_button_column() -> void:
	var reference_button: Button = _button("NewGameButton")
	assert_not_null(reference_button, "主按钮应在场")
	if reference_button == null:
		return
	var reference: float = reference_button.custom_minimum_size.x
	assert_gt(reference, 0.0, "主按钮应有显式最小宽度")
	for button_name: String in MAIN_BUTTONS + UTILITY_BUTTONS:
		var button: Button = _button(button_name)
		assert_not_null(button, "%s 应在场" % button_name)
		if button == null:
			continue
		assert_almost_eq(button.custom_minimum_size.x, reference, 0.001,
				"%s 应与主按钮列同宽" % button_name)


func test_button_height_meets_minimum_click_target() -> void:
	for button_name: String in MAIN_BUTTONS + UTILITY_BUTTONS:
		var button: Button = _button(button_name)
		assert_not_null(button, "%s 应在场" % button_name)
		if button == null:
			continue
		assert_gte(button.custom_minimum_size.y, 44.0,
				"%s 高度应满足指针最小点击区" % button_name)


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════════════════

func _node(p_relative: String) -> Node:
	return _menu.get_node(NodePath("LayoutAnchor/" + p_relative))


## 按名取按钮，自动补 ButtonBox / UtilityBox 前缀。
func _button(p_name: String) -> Button:
	var prefix: String = "UtilityBox/" if UTILITY_BUTTONS.has(p_name) else "ButtonBox/"
	return _node(prefix + p_name) as Button


## WCAG 相对亮度（sRGB 线性化后加权）。
func _luminance(p_color: Color) -> float:
	var channels: Array[float] = [p_color.r, p_color.g, p_color.b]
	var linear: Array[float] = []
	for raw: float in channels:
		linear.append(raw / 12.92 if raw <= 0.03928 else pow((raw + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


## WCAG 对比度 (L1 + 0.05) / (L2 + 0.05)。
func _contrast(p_a: Color, p_b: Color) -> float:
	var la: float = _luminance(p_a)
	var lb: float = _luminance(p_b)
	var hi: float = maxf(la, lb)
	var lo: float = minf(la, lb)
	return (hi + 0.05) / (lo + 0.05)
