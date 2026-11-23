extends GutTest
## 统一主题资源（[code]theme/main.tres[/code]）本身的回归——色值、档位、基础样式。
##
## [b]背景[/b]（一周目界面走查 2026-11-22）：项目此前[b]没有[/b]任何 Theme 资源，
## [code]project.godot[/code] 无 [code]gui/theme/custom[/code]。于是所有没写
## [code]theme_override_colors[/code] 的文字落到引擎内置默认主题：主菜单标题实测
## 纯白 RGB(255,255,255)、按钮文字冷灰 RGB(204,204,204)——与 art-bible 的暖色四级
## 色阶无关。[br]
## [br][b]本轮做法[/b]：配色收进 [code]theme/main.tres[/code]（生成器
## [code]tools/gen_theme.gd[/code]，色值取自 [code]design/art/art-bible.md[/code]
## §4.1/§4.7）。本文件守「主题里有什么、值对不对」；「四屏有没有真的接上」由
## [code]test_theme_wiring.gd[/code] 守。[br]
## [br][b]为什么主题是被生成出来的[/b]：Godot 的 [code].tres[/code] 解析器[b]不接受[/b]
## [code]Color("#hex")[/code] 写法（实测加载返回 null），手写就得自己做 hex→十进制浮点
## 的换算，而六位小数的字面量与 hex 值的 float32 结果不等（[code]0.784314[/code] 与
## [code]#C8C4BC[/code] 打印一模一样却 [code]==[/code] 判假）。让引擎序列化就没有抄错
## 这回事。故本文件的断言口径也一律是 [code]Color("#hex")[/code]——与 art-bible、
## 与生成器三处同源，逐位相等。[br]
## [br][b]不进场景树[/b]：本文件只读主题资源对象，与场景无关。[br]
## [br]依据：art-bible §4.1、§4.7.1、§4.7.2、§4.7.3、§3.3.1。

## 主题资源路径（唯一落点）。
const THEME_PATH: String = "res://theme/main.tres"

## art-bible §4.7.2 文字四级色阶。
const T0: Color = Color("#F0EBE0")
const T1: Color = Color("#C8C4BC")
const T2: Color = Color("#98948C")
const T3: Color = Color("#68645C")
## art-bible §4.7.1 背景层级（BG-1 未单独成 token，故不列）。
const BG_0: Color = Color("#141414")
const BG_2: Color = Color("#282826")
const BG_3: Color = Color("#363634")
const BG_4: Color = Color("#4A4A46")
## art-bible §4.1 主色调色板。
const VERMILLION: Color = Color("#C23B3B")
const TURQUOISE: Color = Color("#4A9494")
const GLAZED_GOLD: Color = Color("#C8A84E")

## 文字档位变体名（顺序即字号由大到小）。
const TEXT_TIERS: Array[StringName] = [
	&"DisplayText", &"TitleText", &"SubtitleText", &"BodyText", &"CaptionText",
]

var _theme: Theme = null


func before_each() -> void:
	# CACHE_MODE_IGNORE：绕开资源缓存，确保读的是磁盘上这一份
	#（同进程内若先生成再读，缓存里那份可能是改动前的）。
	_theme = ResourceLoader.load(THEME_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme


func after_each() -> void:
	_theme = null


# ═══════════════════════════════════════════════════════════════════════════════
# 一、主题资源本身
# ═══════════════════════════════════════════════════════════════════════════════

func test_theme_file_exists_on_disk() -> void:
	assert_true(FileAccess.file_exists(THEME_PATH),
			"%s 应存在于磁盘（UI 配色的唯一落点）" % THEME_PATH)


func test_theme_loads_as_theme_resource() -> void:
	assert_not_null(_theme, "%s 应能 ResourceLoader.load 成 Theme" % THEME_PATH)
	assert_true(_theme is Theme, "加载结果的类型应为 Theme")


## 资源头就得声明 Theme——防「后缀是 .tres、内容却是别的资源」。
func test_theme_file_declares_theme_type() -> void:
	var text: String = FileAccess.get_file_as_string(THEME_PATH)
	assert_true(text.begins_with("[gd_resource type=\"Theme\""),
			"资源头应声明 type=\"Theme\"（本文件由 tools/gen_theme.gd 生成，改配色要重跑）")


func test_project_default_theme_is_main_tres() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom"), THEME_PATH,
			"project.godot 的 gui/theme/custom 应指向唯一主题——这样四屏不必各挂 theme")
	var project_theme: Theme = ThemeDB.get_project_theme()
	assert_not_null(project_theme, "ThemeDB 应能拿到项目主题")
	if project_theme == null:
		return
	# 比 resource_path 而不是比对象：本文件用 CACHE_MODE_IGNORE 重读了一份，
	# 与缓存里那份是两个实例（正是为了确认磁盘内容，不能反过来靠缓存）。
	assert_eq(project_theme.resource_path, THEME_PATH,
			"ThemeDB 拿到的项目主题应就是磁盘上这一份")


## 反向断言：查不到的 token 返回引擎默认（纯黑），而不是某个近似的近色。
## [code]AppBackdrop[/code] 的兜底判据正是靠这条性质——「查不到」的返回值是确定的。
func test_unknown_token_lookup_falls_back_to_engine_default() -> void:
	assert_eq(_theme.get_color(&"no_such_token", &"GamePalette"), Color.BLACK,
			"查不到的 token 应回落到引擎默认纯黑")


# ═══════════════════════════════════════════════════════════════════════════════
# 二、调色板 token 与 art-bible 逐位一致
# ═══════════════════════════════════════════════════════════════════════════════

func test_palette_background_tokens_match_art_bible() -> void:
	assert_eq(_token(&"panel"), BG_2, "面板色应为 BG-2")
	assert_eq(_token(&"panel_border"), BG_4, "面板描边应为 BG-4")
	assert_eq(_token(&"control"), BG_3, "控件底应为 BG-3")
	assert_eq(_token(&"disabled_fill"), BG_0, "禁用填充应为 BG-0")


func test_palette_text_tokens_match_art_bible() -> void:
	assert_eq(_token(&"text_primary"), T0, "主要文字应为 T-0")
	assert_eq(_token(&"text_secondary"), T1, "次要文字应为 T-1")
	assert_eq(_token(&"text_tertiary"), T2, "辅助文字应为 T-2")
	assert_eq(_token(&"text_disabled"), T3, "禁用文字应为 T-3")


func test_palette_accent_tokens_use_art_bible_hues() -> void:
	assert_eq(_token(&"accent_success"), TURQUOISE, "成功色应为松石青")
	assert_eq(_token(&"accent_warning"), GLAZED_GOLD, "警告色应为琉璃金")
	assert_eq(_token(&"accent_danger"), VERMILLION, "失败色应为朱砂红")


## 背板 token 得是最深的那一支——BG-0 要留给对话框遮罩这类更深的层。
func test_backdrop_token_is_deepest_layer() -> void:
	var backdrop: Color = _token(&"backdrop")
	assert_lt(_luminance(backdrop), _luminance(BG_0),
			"背板应暗于 BG-0，否则对话框遮罩压不住底")


# ═══════════════════════════════════════════════════════════════════════════════
# 三、文字档位
# ═══════════════════════════════════════════════════════════════════════════════

## 三档以上字号阶梯——「别只有一档」的可断言形式。[br]
## 同时钉住「用变体而不是每场景写 [code]theme_override_*[/code]」：每个档位都得是挂在
## [code]Label[/code] 上的 type variation。
func test_text_tiers_provide_at_least_three_distinct_sizes() -> void:
	var sizes: Array[int] = []
	for variation: StringName in TEXT_TIERS:
		assert_eq(_theme.get_type_variation_base(variation), &"Label",
				"%s 应挂在 Label 上（变体，而非场景内覆写）" % variation)
		sizes.append(_theme.get_font_size(&"font_size", variation))
	var unique: Array[int] = []
	for size: int in sizes:
		if not unique.has(size):
			unique.append(size)
	assert_gte(unique.size(), 3, "字号档位应至少三档互不相同，实际 %s" % str(unique))
	assert_true(sizes[0] > sizes[2] and sizes[2] > sizes[4],
			"档位应单调递小（标题 > 副标题 > 说明），实际 %s" % str(sizes))


## 语义色文字两档取代了原先散在 [code].tscn[/code] 里的字面量金色
## （那两处写的是 [code]Color(0.9, 0.75, 0.3)[/code]，与 §4.1 的琉璃金不符）。
func test_semantic_text_variations_use_palette_accents() -> void:
	assert_eq(_theme.get_type_variation_base(&"WarningText"), &"Label", "警告档应挂 Label")
	assert_eq(_theme.get_color(&"font_color", &"WarningText"), GLAZED_GOLD,
			"警告文字应为琉璃金")
	assert_eq(_theme.get_type_variation_base(&"DangerText"), &"Label", "失败档应挂 Label")


# ═══════════════════════════════════════════════════════════════════════════════
# 四、基础样式：Button / Label / Panel / RichTextLabel
# ═══════════════════════════════════════════════════════════════════════════════

## §4.7.3：按钮默认 T-1 / 悬停·按下·聚焦 T-0 / 禁用 T-3。
func test_button_text_colors_follow_interaction_tiers() -> void:
	assert_eq(_theme.get_color(&"font_color", &"Button"), T1, "按钮默认应为 T-1")
	assert_eq(_theme.get_color(&"font_hover_color", &"Button"), T0, "悬停应为 T-0")
	assert_eq(_theme.get_color(&"font_pressed_color", &"Button"), T0, "按下应为 T-0")
	assert_eq(_theme.get_color(&"font_focus_color", &"Button"), T0, "聚焦应为 T-0")
	assert_eq(_theme.get_color(&"font_disabled_color", &"Button"), T3, "禁用应为 T-3")
	assert_eq(_theme.get_color(&"font_color", &"Label"), T1, "Label 兜底应为 T-1")


func test_button_defines_four_state_styleboxes() -> void:
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled"]:
		assert_not_null(_theme.get_stylebox(state, &"Button"), "Button 应有 %s 样式盒" % state)


func test_panel_and_rich_text_labels_are_styled() -> void:
	assert_eq(_theme.get_stylebox(&"panel", &"PanelContainer").get_minimum_size(),
			Vector2.ZERO, "面板最小尺寸应保持 (0,0)")
	assert_eq(_theme.get_stylebox(&"panel", &"Panel").get_minimum_size(),
			Vector2.ZERO, "面板最小尺寸应保持 (0,0)")
	assert_eq(_theme.get_color(&"default_color", &"RichTextLabel"), T1,
			"富文本默认色应为 T-1")


## 主题只换颜色、不挪布局：样式盒最小尺寸与引擎默认逐值一致。[br]
## [br][b]为什么这条必须存在[/b]（探针实测）：[code]StyleBoxFlat[/code] 的
## [code]content_margin[/code] 缺省值是 -1，含义是「跟随边框」——只加 1px 边框就会把每个
## [code]PanelContainer[/code] 的最小尺寸从 [code](0,0)[/code] 抬成 [code](2,2)[/code]，
## 内容区四周各缩 1px，顺着版面往下传。生成器显式写了 [code]set_content_margin_all(0)[/code]；
## 这条用例是那个决定的可执行形式。
func test_stylebox_geometry_matches_engine_default() -> void:
	assert_eq(_theme.get_stylebox(&"normal", &"Button").get_minimum_size(), Vector2(8, 8),
			"按钮最小尺寸应与引擎默认 (8,8) 一致，配色变更不得改变控件几何")


## 焦点槽刻意留空：项目既有的焦点环由 [code]shop_panel_layout.apply_focus_ring[/code]
## 插件式覆盖，主题里另立一套会让「焦点长什么样」出现两个来源。[br]
## [br][b]判据用 has_stylebox 而不是 get_stylebox[/b]：[code]Theme.get_stylebox[/code]
## 在槽位缺失时会[b]回落到引擎默认主题[/b]（实测返回那圈 2px 红框
## [code](1, 0.365, 0.365)[/code]），直接读值会误判成「主题自带焦点框」。
func test_button_focus_slot_is_left_to_the_project_focus_ring() -> void:
	assert_false(_theme.has_stylebox(&"focus", &"Button"),
			"主题不得自带按钮焦点边框（焦点环的唯一来源是 shop_panel_layout）")
	assert_false(_theme.has_stylebox(&"focus", &"NavButton"),
			"NavButton 变体同样不得自带焦点边框")


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════════════════

## 取调色板 token（自定义 type [code]GamePalette[/code] 下的颜色槽）。
func _token(p_name: StringName) -> Color:
	return _theme.get_color(p_name, &"GamePalette")


## WCAG 相对亮度（sRGB 线性化后加权）——与 art-bible 的对比度口径一致。
func _luminance(p_color: Color) -> float:
	var linear: Array[float] = []
	for raw: float in [p_color.r, p_color.g, p_color.b]:
		linear.append(raw / 12.92 if raw <= 0.03928 else pow((raw + 0.055) / 1.055, 2.4))
	return 0.2126 * linear[0] + 0.7152 * linear[1] + 0.0722 * linear[2]
