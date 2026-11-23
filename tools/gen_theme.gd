extends SceneTree
## 一次性生成器：按 art-bible §4.7 构建 [code]theme/main.tres[/code]。[br]
## [br][b]为什么用生成器而不是手写 .tres[/b]：手写要自己把 [code]#RRGGBB[/code] 换算成
## 十进制浮点字面量，而 Godot 的 [code].tres[/code] 解析器[b]不接受[/b] [code]Color("#hex")[/code]
## 写法（实测加载返回 null）；手抄十进制又会踩 float32 精度——[code]0.784314[/code] 与
## [code]#C8C4BC[/code] 的 float32 值不等（[code]==[/code] 判假，只有
## [code]is_equal_approx[/code] 为真），测试里就会得到「左边右边打印一模一样却不相等」的
## 假失败。让引擎自己序列化，就没有抄错这一回事。[br]
## [br]色值一律走 [code]Color("#hex")[/code] 构造：hex 是 art-bible 的原始口径，
## 也是测试断言的同一支口径，两边逐位相等。[br]
## [br]用法：[code]godot --headless -s tools/gen_theme.gd[/code]（改配色后重跑）。

const OUT := "res://theme/main.tres"

## art-bible §4.7.1 背景层级。
const BG_0 := "#141414"  ## 最深层
const BG_1 := "#1E1E1C"  ## 面板基底
const BG_2 := "#282826"  ## 抬升层
const BG_3 := "#363634"  ## 交互准备层（按钮默认底）
const BG_4 := "#4A4A46"  ## 分隔与边界

## art-bible §4.7.2 文字层级。
const T_0 := "#F0EBE0"  ## 主要文字
const T_1 := "#C8C4BC"  ## 次要文字
const T_2 := "#98948C"  ## 辅助文字
const T_3 := "#68645C"  ## 禁用 / 占位

## art-bible §4.1 主色调色板。
const INK_BLACK := "#1A1A1A"      ## 墨黑
const VERMILLION := "#C23B3B"     ## 朱砂红
const TURQUOISE := "#4A9494"      ## 松石青
const GLAZED_GOLD := "#C8A84E"    ## 琉璃金

## 深层基底（四个界面的背板色）。[br]
## [br][b]为什么不是 BG-0 的 [code]#141414[/code][/b]：屏幕基底比「最深的那块」浅一档
## 是有意的——BG-0 要留给「对话框背后的遮罩」这类更深的层，否则遮罩压不住底；
## 取值是四屏里最深的那一支（节点图），另四屏原先各写一份、其中三份漂到了
## [code]0.071[/code] 附近（见一周目走查 2026-11-22）。
const BACKDROP := "#0E0F16"


func _palette(p_th: Theme, p_name: String, p_hex: String) -> void:
	p_th.set_color(p_name, "GamePalette", Color(p_hex))


## 按钮状态样式盒——几何照抄引擎默认（内容边距 4 + 边框 1 = 最小 8×8，实测同值），
## 只换颜色，做到「零布局位移」（art-bible §4.7.3 的灰阶状态语言）。
func _button_box(p_bg: Color, p_border: Color, p_width: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = p_bg
	sb.border_color = p_border
	sb.set_border_width_all(p_width)
	sb.set_content_margin_all(4)
	sb.set_corner_radius_all(2)  # art-bible §3.3.1 全微圆角 2px
	return sb


## 面板样式盒——[b]内容边距必须显式写 0[/b]，不能省。[br]
## [br][b]为什么[/b]（探针 [code]tools/probe_theme_min.gd[/code] 实测）：
## [code]StyleBoxFlat[/code] 的 [code]content_margin[/code] 缺省值是 -1，含义是「跟随
## 边框」；于是只加 1px 边框就会让每个 [code]PanelContainer[/code] 的最小尺寸从
## [code](0,0)[/code] 变成 [code](2,2)[/code]、内容区四周各缩 1px——全库面板都在内部
## 自带 [code]MarginContainer[/code]，这 2px 会顺着版面往下传（本轮只收敛配色，不挪布局）。
## 显式写 0 后 [code]get_margin[/code] 直接返回 0，最小尺寸回到 [code](0,0)[/code]，
## 边框只是画在面板自己的边缘像素上。
func _panel_box(p_bg: Color, p_border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = p_bg
	sb.border_color = p_border
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(0)
	return sb


func _initialize() -> void:
	var th := Theme.new()

	# ── 调色板 token（自定义 type，只作数据容器——节点不直接戴它）──────────
	_palette(th, "backdrop", BACKDROP)
	_palette(th, "panel", BG_2)
	_palette(th, "panel_border", BG_4)
	_palette(th, "control", BG_3)
	_palette(th, "control_border", BG_4)
	_palette(th, "disabled_fill", BG_0)
	_palette(th, "ink_black", INK_BLACK)
	_palette(th, "text_primary", T_0)
	_palette(th, "text_secondary", T_1)
	_palette(th, "text_tertiary", T_2)
	_palette(th, "text_disabled", T_3)
	_palette(th, "accent_success", TURQUOISE)
	_palette(th, "accent_warning", GLAZED_GOLD)
	_palette(th, "accent_danger", VERMILLION)
	# 朱砂红的「软」变体：#B3424A 是项目既有的警报编码（lingshi_deck_bar /
	# settlement_rules / node_interaction_rules 三处同源），比 #C23B3B 暗一档、
	# 更适合大面积文字——两者都在朱砂红语义域内，不是新颜色。
	_palette(th, "accent_danger_soft", "#B3424A")

	# ── 文字档位（变体挂在 Label 上）───────────────────────────────────────
	# 字号取各界面既有值（本轮只收敛配色、不动排版），故三档之间是既有排版实际用到的
	# 三档：48 主标题 / 32 屏内标题 / 16 正文 / 13 说明。
	var tiers: Array = [
		["DisplayText", 48, "text_primary"],     # 主菜单标题
		["TitleText", 32, "text_primary"],       # 屏内标题
		["SubtitleText", 22, "text_primary"],    # 标题右侧数值行（灵石余额）
		["BodyText", 16, "text_secondary"],      # 正文
		["CaptionText", 13, "text_tertiary"],    # 说明 / 版本号
	]
	for tier: Array in tiers:
		th.set_type_variation(tier[0], "Label")
		th.set_color("font_color", tier[0], th.get_color(tier[2], "GamePalette"))
		th.set_font_size("font_size", tier[0], tier[1])
	th.set_type_variation("DisabledText", "Label")
	th.set_color("font_color", "DisabledText", th.get_color("text_disabled", "GamePalette"))
	th.set_font_size("font_size", "DisabledText", 13)
	# 语义色文字两档——取代散落在 .tscn 里的字面色值（原先两份金色字面量
	# 0.9/0.75/0.3 与 art-bible 琉璃金 #C8A84E 不符）。
	th.set_type_variation("WarningText", "Label")
	th.set_color("font_color", "WarningText", th.get_color("accent_warning", "GamePalette"))
	th.set_font_size("font_size", "WarningText", 16)
	th.set_type_variation("DangerText", "Label")
	th.set_color("font_color", "DangerText", th.get_color("accent_danger_soft", "GamePalette"))
	th.set_font_size("font_size", "DangerText", 16)

	# ── 基础样式：Label ────────────────────────────────────────────────────
	th.set_color("font_color", "Label", th.get_color("text_secondary", "GamePalette"))
	th.set_font_size("font_size", "Label", 16)

	# ── 基础样式：Button ──────────────────────────────────────────────────
	# §4.7.3：默认 T-1 / 悬停·按下·聚焦 T-0 / 禁用 T-3。
	th.set_color("font_color", "Button", th.get_color("text_secondary", "GamePalette"))
	th.set_color("font_hover_color", "Button", th.get_color("text_primary", "GamePalette"))
	th.set_color("font_pressed_color", "Button", th.get_color("text_primary", "GamePalette"))
	th.set_color("font_focus_color", "Button", th.get_color("text_primary", "GamePalette"))
	th.set_color("font_disabled_color", "Button", th.get_color("text_disabled", "GamePalette"))
	th.set_font_size("font_size", "Button", 16)
	var control: Color = th.get_color("control", "GamePalette")
	var control_border: Color = th.get_color("control_border", "GamePalette")
	th.set_stylebox("normal", "Button", _button_box(control, control_border, 1))
	th.set_stylebox("hover", "Button", _button_box(
			control.lightened(0.08), control_border.lightened(0.15), 2))
	th.set_stylebox("pressed", "Button", _button_box(
			control.darkened(0.15), control_border.lightened(0.25), 2))
	th.set_stylebox("disabled", "Button", _button_box(
			th.get_color("disabled_fill", "GamePalette"), control_border, 1))
	# [b]focus 槽不在此处定义[/b]：项目既有的焦点环是松石青 3px 圆角 4
	# （[code]shop_panel_layout.apply_focus_ring[/code]，插件式覆盖到需要的控件上），
	# 主题里另立一套会让「焦点长什么样」出现两个来源。
	th.set_type_variation("NavButton", "Button")
	th.set_font_size("font_size", "NavButton", 18)

	# ── 基础样式：Panel / PanelContainer ──────────────────────────────────
	var panel_bg: Color = th.get_color("panel", "GamePalette")
	var panel_border: Color = th.get_color("panel_border", "GamePalette")
	th.set_stylebox("panel", "Panel", _panel_box(panel_bg, panel_border))
	th.set_stylebox("panel", "PanelContainer", _panel_box(panel_bg, panel_border))

	# ── 基础样式：RichTextLabel ───────────────────────────────────────────
	th.set_color("default_color", "RichTextLabel", th.get_color("text_secondary", "GamePalette"))
	th.set_font_size("normal_font_size", "RichTextLabel", 16)

	var err: int = ResourceSaver.save(th, OUT)
	print("save err=", err, " → ", OUT)

	# ── 回读自检：从磁盘重读（绕开资源缓存——同进程内 save 后 load 会拿到旧缓存），
	#    任一 token 与 art-bible 原值不等就报出来 ─────────────────────────────
	var back: Theme = ResourceLoader.load(OUT, "", ResourceLoader.CACHE_MODE_IGNORE) as Theme
	var checks: Array = [
		["backdrop 已写入", back.has_color("backdrop", "GamePalette")],
		["backdrop == " + BACKDROP, back.get_color("backdrop", "GamePalette") == Color(BACKDROP)],
		["T-1 == " + T_1, back.get_color("text_secondary", "GamePalette") == Color(T_1)],
		["T-0 == " + T_0, back.get_color("text_primary", "GamePalette") == Color(T_0)],
		["DisplayText base == Label",
				back.get_type_variation_base("DisplayText") == &"Label"],
		["DisplayText size == 48", back.get_font_size("font_size", "DisplayText") == 48],
		["Button normal bg == " + BG_3,
				(back.get_stylebox("normal", "Button") as StyleBoxFlat).bg_color == Color(BG_3)],
		# 面板最小尺寸必须是 (0,0)——缺省 content_margin = -1 会跟随边框，把全库面板
		# 的最小尺寸从 (0,0) 抬成 (2,2)，等于挪布局（探针 probe_theme_min.gd 实测）。
		["PanelContainer 最小尺寸 == (0,0)",
				back.get_stylebox("panel", "PanelContainer").get_minimum_size() == Vector2.ZERO],
		["Panel 最小尺寸 == (0,0)",
				back.get_stylebox("panel", "Panel").get_minimum_size() == Vector2.ZERO],
		# 按钮最小尺寸与引擎默认一致（8,8）——主题只换颜色，不动几何。
		["Button normal 最小尺寸 == (8,8)",
				back.get_stylebox("normal", "Button").get_minimum_size() == Vector2(8, 8)],
	]
	var bad: int = 0
	for c: Array in checks:
		if not bool(c[1]):
			bad += 1
			print("  !! 自检失败: ", c[0])
	print("自检: %d/%d 通过" % [checks.size() - bad, checks.size()])
	quit()
