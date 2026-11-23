extends GutTest
## 四屏（+ 渡劫 / 身份选择）接到统一主题上的回归。
##
## [b]背景[/b]（一周目界面走查 2026-11-22）：项目此前没有 Theme 资源，屏幕底色在六个
## [code].tscn[/code] 里各写一份 [code]ColorRect[/code] 字面量，其中节点图那份漂成了
## [code]Color(0.055, 0.06, 0.086)[/code]（其余五份是 [code]0.071, 0.071, 0.086[/code]）
## ——同一支「项目深色」在屏幕上呈三支（第三支是战斗 / 渡劫原本的引擎清屏灰
## [code]Color(0.3, 0.3, 0.3)[/code]，已由上一轮补掉）。[br]
## [br][b]本轮做法[/b]：底色收进 [code]theme/main.tres[/code] 的
## [code]GamePalette/backdrop[/code]，[code]project.godot[/code] 设
## [code]gui/theme/custom[/code] 为全局默认；背板色因为没有主题槽
## （[code]ColorRect.color[/code] 是普通属性），由 [code]AppBackdrop[/code] 脚本从主题读。
## 主题里的 token 与色值由 [code]test_theme_resource.gd[/code] 守，本文件守「接线」。[br]
## [br][b]两种挂载姿势，各有理由[/b]（实测差异）：[br]
## ① [b]脱树[/b]（[code]instantiate()[/code] 后不挂）：基础类型槽（[code]Label[/code] /
## [code]Button[/code]）经 [code]ThemeDB[/code] 的项目主题照常解析——这正是「全局默认」
## 与「节点自挂 theme」的区别所在；背板色由 [code]AppBackdrop[/code] 在
## [method Node._init] 读取，脱树也已就位。本文件绝大多数断言走这条，因为脱树不会触发
## [code]_ready[/code]（战斗 / 渡劫容器一进树就开战，测试里不该开）。[br]
## ② [b]进树[/b]：只有 [code]theme_type_variation[/code] 的解析必须在树内——脱树时
## 变体名不被采纳，节点回落到基类槽（实测 [code]NavButton[/code] 按钮脱树读到
## [code]Button[/code] 的 16 而非变体的 18）。故验证体档位的那一案显式进树，
## 并另立一案把这个「脱树回落」的边界正面钉住。[br]
## [br]依据：art-bible §4.7.1、ADR-0031、[code]docs/auditoria-ui-theme-2026-11-23.md[/code]。

## 本轮接线涉及的界面（各自有一个名为 [code]Background[/code] 的背板节点）。
## 前四项是任务点名的四屏；渡劫是战斗的孪生容器（同一支底色）；身份选择是本轮一并收编的
## 第六处同值字面量。
const WIRED_SCREENS: Array[String] = [
	"res://src/ui/main_menu/MainMenu.tscn",
	"res://src/ui/exploration/map_select_screen.tscn",
	"res://src/ui/exploration/node_graph_screen.tscn",
	"res://src/feature/combat/combat_scene.tscn",
	"res://src/feature/tribulation/tribulation_scene.tscn",
	"res://src/ui/identity_select/identity_select.tscn",
]

## 任务点名的四屏（「同一色系」判据在这四屏上跑）。
const FOUR_SCREENS: Array[String] = [
	"res://src/ui/main_menu/MainMenu.tscn",
	"res://src/ui/exploration/map_select_screen.tscn",
	"res://src/ui/exploration/node_graph_screen.tscn",
	"res://src/feature/combat/combat_scene.tscn",
]

const MENU_SCENE: String = "res://src/ui/main_menu/MainMenu.tscn"

## 主题给的文字兜底色（T-1）——用来判「全局默认生效了没有」。
const T1: Color = Color("#C8C4BC")

## 「同一色系」判据：相对亮度差与色相角差。
## 阈值宽到容得下「同色系内的深浅差」，严到挡得住本次走查暴露的漂移
## （[code]0.071[/code] 与 [code]0.055[/code] 两支在 RGB 上很接近，色相都落蓝紫段，
## 光看亮度差抓不动——所以两条一起判；下面是
## [code]test_same_family_criterion_rejects_the_audited_drift[/code] 的自检）。
const LUMINANCE_TOLERANCE: float = 0.05
const HUE_TOLERANCE_DEG: float = 15.0

## 本用例实例化过的根节点——[code]after_each[/code] 统一释放（漏释放会污染全量的
## orphans 计数）。
var _roots: Array[Node] = []


func after_each() -> void:
	for root: Node in _roots:
		if is_instance_valid(root):
			root.free()
	_roots.clear()


# ═══════════════════════════════════════════════════════════════════════════════
# 一、全局默认主题在四屏上生效
# ═══════════════════════════════════════════════════════════════════════════════

## 四屏都不在根节点挂 [code]theme[/code]——生效的是 [code]gui/theme/custom[/code] 全局默认。
## 判据用「[code]Label[/code] 的 [code]font_color[/code] 等于 T-1」：引擎内置默认是近白，
## 主题生效才会落到 T-1，两者不会混淆。
func test_screens_inherit_global_default_theme() -> void:
	for path: String in FOUR_SCREENS:
		var root: Control = _spawn(path)
		if root == null:
			continue
		assert_null(root.theme,
				"%s 根节点不应自挂 theme（配色走全局默认，避免出现多份主题）" % path)
		assert_eq(root.get_theme_color(&"font_color", &"Label"), T1,
				"%s 的 Label 应解析到主题 T-1，而不是引擎默认的近白色" % path)


## 脱树时 [code]theme_type_variation[/code] 不解析，回落基类 [code]Button[/code] 档位。[br]
## 与下一案成对读：一正一反才说明「变体生效」这件事，免得后来者把「变体没生效」
## 误判成主题坏了。
func test_variation_falls_back_to_base_type_when_off_tree() -> void:
	var button: Button = _menu_button(_spawn(MENU_SCENE))
	if button == null:
		return
	assert_false(button.is_inside_tree(), "本用例的前提是节点不在树内")
	assert_eq(button.theme_type_variation, &"NavButton", "按钮上挂的变体名应仍是 NavButton")
	assert_eq(button.get_theme_font_size(&"font_size"), 16,
			"脱树时变体不解析，应回落到基类 Button 的 16——变体的解析需要树的上下文")


## 变体档位必须进树才解析——本文件唯一需要挂树的用例（原因见文件头）。
func test_menu_button_font_size_comes_from_nav_variation() -> void:
	var menu: Control = _spawn(MENU_SCENE)
	if menu == null:
		return
	menu.animate = false  # 不播 0.8s 入场 Tween（本用例只看档位）
	add_child(menu)       # 进树才会解析变体；释放归 after_each
	var button: Button = _menu_button(menu)
	if button == null:
		return
	assert_eq(button.theme_type_variation, &"NavButton", "导航按钮应挂 NavButton 变体")
	assert_eq(button.get_theme_font_size(&"font_size"), 18,
			"触发解析后应拿到变体档位 18（而不是基类兜底的 16）——字号来自主题，"
			+ "不再靠场景内的 theme_override_*")


# ═══════════════════════════════════════════════════════════════════════════════
# 二、背板：同一个 token
# ═══════════════════════════════════════════════════════════════════════════════

## 六块背板逐位等于主题 token——「改配色只改一处」的可断言形式。
func test_all_backdrops_equal_the_palette_token() -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	assert_not_null(theme, "项目主题应在场")
	if theme == null:
		return
	var backdrop: Color = theme.get_color(&"backdrop", &"GamePalette")
	for path: String in WIRED_SCREENS:
		assert_eq(_backdrop_color(path), backdrop,
				"%s 的背板应等于 GamePalette/backdrop" % path.get_file())


## 背板仍是全屏、不拦鼠标、且排在最底层。
func test_backdrop_still_covers_screen_and_ignores_mouse() -> void:
	for path: String in WIRED_SCREENS:
		var root: Control = _spawn(path)
		if root == null:
			continue
		var bg: Control = root.get_node_or_null(NodePath("Background")) as Control
		assert_not_null(bg, "%s 应有 Background 节点" % path.get_file())
		if bg == null:
			continue
		assert_eq(root.get_child(0).name, StringName("Background"),
				"%s 的背板必须是第一个子节点（否则会盖在内容之上）" % path.get_file())
		assert_almost_eq(bg.anchor_right, 1.0, 0.001, "背板应右锚到满屏")
		assert_almost_eq(bg.anchor_bottom, 1.0, 0.001, "背板应下锚到满屏")
		assert_eq(bg.mouse_filter, Control.MOUSE_FILTER_IGNORE, "背板不得拦截鼠标")


# ═══════════════════════════════════════════════════════════════════════════════
# 三、四屏背板属于同一色系（本轮走查暴露的「三支深色」的正向判据）
# ═══════════════════════════════════════════════════════════════════════════════

## 判据：两两之间「相对亮度差 ≤ 0.05 且色相角差 ≤ 15°」。
## 不是「不等于默认灰」那种反向断言——它正向要求四块底色彼此够近。
func test_four_backdrops_are_same_color_family() -> void:
	var colors: Array[Color] = []
	for path: String in FOUR_SCREENS:
		colors.append(_backdrop_color(path))
	for i: int in colors.size():
		for j: int in range(i + 1, colors.size()):
			var lum_delta: float = absf(_luminance(colors[i]) - _luminance(colors[j]))
			var hue_delta: float = _hue_delta_deg(colors[i], colors[j])
			assert_lte(lum_delta, LUMINANCE_TOLERANCE,
					"%s 与 %s 的相对亮度差 %.4f 应在 %.2f 内"
					% [FOUR_SCREENS[i].get_file(), FOUR_SCREENS[j].get_file(),
					lum_delta, LUMINANCE_TOLERANCE])
			assert_lte(hue_delta, HUE_TOLERANCE_DEG,
					"%s 与 %s 的色相角差 %.1f° 应在 %.0f° 内"
					% [FOUR_SCREENS[i].get_file(), FOUR_SCREENS[j].get_file(),
					hue_delta, HUE_TOLERANCE_DEG])


## 判据本身得能判——拿本轮走查的真实漂移值自检，确认阈值挡得住。
func test_same_family_criterion_rejects_the_audited_drift() -> void:
	var audited_old: Color = Color(0.071, 0.071, 0.086, 1.0)  # 五屏旧值
	var audited_deep: Color = Color(0.055, 0.06, 0.086, 1.0)  # 节点图旧值（最深那支）
	var engine_gray: Color = Color(0.3, 0.3, 0.3, 1.0)        # 引擎清屏灰（战斗/渡劫旧值）
	assert_gt(_hue_delta_deg(audited_old, engine_gray), HUE_TOLERANCE_DEG,
			"旧值对引擎灰的色相角差应超出阈值（判据有区分力）")
	assert_gt(absf(_luminance(audited_deep) - _luminance(engine_gray)),
			LUMINANCE_TOLERANCE, "节点图旧值对引擎灰的亮度差应超出阈值")
	assert_lte(_hue_delta_deg(audited_old, audited_deep), HUE_TOLERANCE_DEG,
			"两支旧值色相接近属预期——正因如此单靠色相抓不动，判据必须双条同判")


## 背板色不得回落到引擎默认清屏灰——本轮的起点就是那块灰。
func test_backdrop_is_not_engine_default_clear_color() -> void:
	var theme: Theme = ThemeDB.get_project_theme()
	assert_not_null(theme, "项目主题应在场")
	if theme == null:
		return
	assert_ne(theme.get_color(&"backdrop", &"GamePalette"), Color(0.3, 0.3, 0.3),
			"背板不得等于 Godot 默认清屏色")


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════════════════

## 主菜单的「新游戏」按钮（挂 [code]NavButton[/code] 变体的那一类）。
func _menu_button(p_menu: Control) -> Button:
	if p_menu == null:
		return null
	var button: Button = p_menu.get_node_or_null(
			NodePath("LayoutAnchor/ButtonBox/NewGameButton")) as Button
	assert_not_null(button, "新游戏按钮应在场")
	return button


## 实例化场景并读它 [code]Background[/code] 的实测颜色。[br]
## 脱树实例化即可——背板色由 [code]AppBackdrop[/code] 在 [method Node._init] 从主题读，
## 不需要树上下文（实测），所以这里不会触发战斗 / 渡劫的 [code]_ready[/code]。
func _backdrop_color(p_path: String) -> Color:
	var root: Control = _spawn(p_path)
	if root == null:
		return Color.BLACK
	var bg: ColorRect = root.get_node_or_null(NodePath("Background")) as ColorRect
	assert_not_null(bg, "%s 应有 Background 背板" % p_path)
	return Color.BLACK if bg == null else bg.color


## 实例化场景，登记以便 [code]after_each[/code] 统一释放。
func _spawn(p_path: String) -> Control:
	var packed: PackedScene = load(p_path) as PackedScene
	assert_not_null(packed, "%s 应能加载" % p_path)
	if packed == null:
		return null
	var root: Control = packed.instantiate() as Control
	_roots.append(root)
	return root


## WCAG 相对亮度（sRGB 线性化后加权）——与 art-bible 的对比度口径一致。
func _luminance(p_color: Color) -> float:
	var linear: Array[float] = []
	for raw: float in [p_color.r, p_color.g, p_color.b]:
		linear.append(raw / 12.92 if raw <= 0.03928 else pow((raw + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]


## 两色的色相角差（度），取环上最短弧。
func _hue_delta_deg(p_a: Color, p_b: Color) -> float:
	var diff: float = absf(p_a.h * 360.0 - p_b.h * 360.0)
	return minf(diff, 360.0 - diff)
