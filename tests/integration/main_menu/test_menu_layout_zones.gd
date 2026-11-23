extends GutTest
## 主菜单「左序右境」版式分区回归（2026-11-23 主菜单版式走查）。
##
## [b]背景[/b]：主菜单 [code]LayoutAnchor[/code] 及其全部子节点用
## [code]anchors_preset = 0[/code] + 固定 [code]offset_*[/code]，内容右缘固定落在
## [code]96 + 652 = 748px[/code]，与分辨率无关。1920×1080 下右侧 1172px 是纯底色
## （占屏宽 61%），且 [code]UtilityBox[/code] 的 HBox 最小宽 652 已经溢出了
## [code]LayoutAnchor[/code] 自己的 544 宽（108px）——容器管不住自己的孩子。[br]
## [br][b]依据[/b]：[code]design/ux/main-menu.md[/code] §Layout Zones 选的是
## 方案 B「左序右境」——左约 1/3 几何秩序承载功能，右侧 2/3 有机气韵承载世界
## （水墨云海），中分线「不是硬边线，而是视觉渐变过渡」。
## [code]assets/environments/backgrounds/menu/main_menu_cloud_sea.png[/code] 正是
## 为这一层准备的资产（此前全库无人引用，是孤立资源）。所以这一屏缺的不是
## 「居中」，是那一层世界。[br]
## [br][b]测试口径[/b]：全部判据都写成「两块实测 rect 的相对关系」或
## 「占视口宽/高的几分之几」——本文件要在四档分辨率下同时成立，
## 任何裸像素阈值都会退化成「只为 1920 调过」的假绿灯。[br]
## [br]来源: design/ux/main-menu.md §Layout Zones、§Information Hierarchy；
## design/art/art-bible.md §4.7.1（背景层级）。

const MAIN_MENU_SCENE: PackedScene = preload("res://src/ui/main_menu/MainMenu.tscn")
const Backdrop := preload("res://src/ui/shared/app_backdrop.gd")

## 四档待测分辨率（最小 / 常用 / 设计基准 / 最大）——与 test_menu_text_style 同口径。
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1600, 900), Vector2i(1920, 1080), Vector2i(2560, 1440),
]

## 功能列（LayoutAnchor 及其子块）的节点名。
const NAV_CHILDREN: Array[String] = [
	"TitleLabel", "ButtonBox", "UtilityBox", "NoSaveHintLabel",
]

## 相对误差容限——取视口尺寸的比例而非像素，四档分辨率下同一个值成立。
const EPS_FRAC: float = 0.001


func before_each() -> void:
	pass


func after_each() -> void:
	pass


# ═══════════════════════════════════════════════════════════════════════════════
# 世界展示层（右侧 2/3）
# ═══════════════════════════════════════════════════════════════════════════════

## 云海铺满整屏（[code]KEEP_ASPECT_COVERED[/code] 保证任意长宽比不拉伸、不露底）。
func test_world_display_covers_the_whole_viewport() -> void:
	for res: Vector2i in RESOLUTIONS:
		var menu: Control = await _mount(res)
		var display: Control = menu.get_node_or_null(^"WorldDisplay") as Control
		assert_not_null(display, "[%s] 应有世界展示层 WorldDisplay" % _tag(res))
		if display == null:
			continue
		var rect: Rect2 = display.get_rect()
		assert_lte(absf(rect.position.x), res.x * EPS_FRAC,
				"[%s] 云海左缘应贴屏左" % _tag(res))
		assert_lte(absf(rect.position.y), res.y * EPS_FRAC,
				"[%s] 云海顶缘应贴屏顶" % _tag(res))
		assert_lte(absf(rect.end.x - float(res.x)), res.x * EPS_FRAC,
				"[%s] 云海右缘应贴屏右" % _tag(res))
		assert_lte(absf(rect.end.y - float(res.y)), res.y * EPS_FRAC,
				"[%s] 云海底缘应贴屏底" % _tag(res))


## 世界展示层必须真的带上云海纹理——一个空 TextureRect 也能占满屏，
## 那等于把「右半边空着」从没节点变成有节点没内容。
func test_world_display_actually_carries_the_cloud_sea() -> void:
	var menu: Control = await _mount(RESOLUTIONS[2])
	var display: TextureRect = menu.get_node_or_null(^"WorldDisplay") as TextureRect
	assert_not_null(display, "应有世界展示层 WorldDisplay")
	if display == null:
		return
	assert_not_null(display.texture, "世界展示层应挂上云海纹理，而不是占位空节点")


## 过渡带右缘要落在屏宽 4/5 之内——超出则世界展示区被挤成一条边，
## 云海等于没做（验收标准里的「右侧 2/3 世界展示区」就落空了）。
func test_world_seam_ends_within_the_leading_four_fifths() -> void:
	for res: Vector2i in RESOLUTIONS:
		var menu: Control = await _mount(res)
		var seam: Control = menu.get_node_or_null(^"WorldSeam") as Control
		assert_not_null(seam, "[%s] 应有中分过渡带 WorldSeam" % _tag(res))
		if seam == null:
			continue
		assert_lte(seam.get_rect().end.x / float(res.x), 0.8,
				"[%s] 中分过渡带应在前 4/5 屏宽内收干净" % _tag(res))


# ═══════════════════════════════════════════════════════════════════════════════
# 左侧功能列与中分过渡带的关系
# ═══════════════════════════════════════════════════════════════════════════════

## LayoutAnchor 要真的管得住自己的孩子——此前 UtilityBox（HBox，最小宽 652）
## 溢出了容器 108px，容器右缘是个假边界。
func test_nav_children_stay_inside_their_container() -> void:
	for res: Vector2i in RESOLUTIONS:
		var menu: Control = await _mount(res)
		var anchor: Control = menu.get_node(^"LayoutAnchor") as Control
		var box: Rect2 = anchor.get_rect()
		for child_name: String in NAV_CHILDREN:
			var child: Control = anchor.get_node_or_null(NodePath(child_name)) as Control
			assert_not_null(child, "[%s] %s 应在场" % [_tag(res), child_name])
			if child == null:
				continue
			var child_rect: Rect2 = child.get_rect()
			assert_gte(child_rect.position.x, -res.x * EPS_FRAC,
					"[%s] %s 左缘不该越出容器" % [_tag(res), child_name])
			assert_lte(child_rect.end.x, box.size.x + res.x * EPS_FRAC,
					"[%s] %s 右缘不该越出容器（容器宽 %.1f，子块右缘 %.1f）"
					% [_tag(res), child_name, box.size.x, child_rect.end.x])
			assert_lte(child_rect.end.y, box.size.y + res.y * EPS_FRAC,
					"[%s] %s 下缘不该越出容器" % [_tag(res), child_name])


## 不透明遮罩（WorldScrim）要盖住整条功能列——玩家点按钮的那一片底下
## 必须是实底色，否则文字会压在水墨上，对比度直接崩。
func test_scrim_covers_the_whole_nav_column() -> void:
	for res: Vector2i in RESOLUTIONS:
		var menu: Control = await _mount(res)
		var scrim: Control = menu.get_node_or_null(^"WorldScrim") as Control
		assert_not_null(scrim, "[%s] 应有不透明遮罩 WorldScrim" % _tag(res))
		if scrim == null:
			continue
		var scrim_rect: Rect2 = scrim.get_rect()
		var nav_right: float = _nav_right(menu)
		assert_gte(scrim_rect.end.x, nav_right,
				"[%s] 遮罩右缘(%.1f)应不小于功能列右缘(%.1f)"
				% [_tag(res), scrim_rect.end.x, nav_right])
		assert_lte(absf(scrim_rect.position.x), res.x * EPS_FRAC,
				"[%s] 遮罩应从屏左起" % _tag(res))
		assert_gte(scrim_rect.size.y, res.y * (1.0 - EPS_FRAC),
				"[%s] 遮罩应盖满屏高" % _tag(res))


## 遮罩与过渡带必须严丝合缝——左边缺一段会露出云海硬缘，
## 右边压一段会白白吃掉世界展示区。
func test_seam_starts_exactly_where_the_scrim_ends() -> void:
	for res: Vector2i in RESOLUTIONS:
		var menu: Control = await _mount(res)
		var scrim: Control = menu.get_node_or_null(^"WorldScrim") as Control
		var seam: Control = menu.get_node_or_null(^"WorldSeam") as Control
		assert_not_null(scrim, "[%s] 应有 WorldScrim" % _tag(res))
		assert_not_null(seam, "[%s] 应有 WorldSeam" % _tag(res))
		if scrim == null or seam == null:
			continue
		assert_almost_eq(seam.get_rect().position.x, scrim.get_rect().end.x,
				res.x * EPS_FRAC,
				"[%s] 过渡带左缘应接在遮罩右缘上" % _tag(res))


## 过渡带是「渐隐」而不是「硬边」：左端不透明、右端全透明，且两端同色。
func test_seam_fades_from_opaque_to_transparent_backdrop() -> void:
	var menu: Control = await _mount(RESOLUTIONS[2])
	var seam: TextureRect = menu.get_node_or_null(^"WorldSeam") as TextureRect
	assert_not_null(seam, "应有中分过渡带 WorldSeam")
	if seam == null:
		return
	assert_not_null(seam.texture, "过渡带应挂渐变纹理")
	if seam.texture == null:
		return
	var texture: GradientTexture2D = seam.texture as GradientTexture2D
	assert_not_null(texture, "过渡带纹理应是 GradientTexture2D")
	if texture == null:
		return
	var ramp: Gradient = texture.gradient
	assert_not_null(ramp, "渐变纹理应带 Gradient")
	if ramp == null:
		return
	var head: Color = ramp.sample(0.0)
	var tail: Color = ramp.sample(1.0)
	assert_almost_eq(head.a, 1.0, 0.01, "渐变左端应不透明（压住云海硬缘）")
	assert_almost_eq(tail.a, 0.0, 0.01, "渐变右端应全透明（交还给水墨世界）")
	assert_almost_eq(head.r, tail.r, 0.01, "渐变两端应同色相——只是透明度在变")
	assert_almost_eq(head.g, tail.g, 0.01, "渐变两端应同色相——只是透明度在变")
	assert_almost_eq(head.b, tail.b, 0.01, "渐变两端应同色相——只是透明度在变")


## 过渡带的颜色必须逐位等于主题背板色——不然中分处会浮出一条比背板
## 深一档/浅一档的带子（本项目配色已收进 theme/main.tres 单一来源）。
func test_seam_uses_the_theme_backdrop_color() -> void:
	var menu: Control = await _mount(RESOLUTIONS[2])
	var seam: TextureRect = menu.get_node_or_null(^"WorldSeam") as TextureRect
	assert_not_null(seam, "应有中分过渡带 WorldSeam")
	if seam == null or seam.texture == null:
		return
	var ramp: Gradient = (seam.texture as GradientTexture2D).gradient
	var themed: Color = menu.get_theme_color(
			Backdrop.BACKDROP_KEY, Backdrop.PALETTE_TYPE)
	assert_eq(ramp.sample(0.0).r, themed.r, "过渡带起点应等于主题背板色 R")
	assert_eq(ramp.sample(0.0).g, themed.g, "过渡带起点应等于主题背板色 G")
	assert_eq(ramp.sample(0.0).b, themed.b, "过渡带起点应等于主题背板色 B")


# ═══════════════════════════════════════════════════════════════════════════════
# 四档分辨率下都不挤压
# ═══════════════════════════════════════════════════════════════════════════════

## 功能列必须整体留在视口内——最小分辨率最容易把它顶出下边界。
func test_nav_column_fits_inside_the_viewport() -> void:
	for res: Vector2i in RESOLUTIONS:
		var menu: Control = await _mount(res)
		var anchor: Control = menu.get_node(^"LayoutAnchor") as Control
		var box: Rect2 = anchor.get_rect()
		assert_lte(box.end.x, float(res.x), "[%s] 功能列右缘不该越出视口" % _tag(res))
		assert_lte(box.end.y, float(res.y), "[%s] 功能列下缘不该越出视口" % _tag(res))


## 功能列要留在世界展示区的左侧——否则按钮压在水墨上，且右侧世界被切掉。
func test_nav_column_stays_left_of_the_open_world() -> void:
	for res: Vector2i in RESOLUTIONS:
		var menu: Control = await _mount(res)
		var seam: Control = menu.get_node_or_null(^"WorldSeam") as Control
		assert_not_null(seam, "[%s] 应有 WorldSeam" % _tag(res))
		if seam == null:
			continue
		assert_lte(_nav_right(menu), seam.get_rect().position.x + res.x * EPS_FRAC,
				"[%s] 功能列右缘应落在中分过渡带左缘之内" % _tag(res))


# ═══════════════════════════════════════════════════════════════════════════════
# 辅助
# ═══════════════════════════════════════════════════════════════════════════════

## 把主菜单挂到一个尺寸确定的宿主上——父级给尺寸，四档分辨率各自真实布局。
func _mount(p_res: Vector2i) -> Control:
	var holder: Control = Control.new()
	holder.name = "MenuZoneHolder"
	holder.size = Vector2(p_res)
	add_child_autofree(holder)
	var menu: Control = MAIN_MENU_SCENE.instantiate() as Control
	menu.set(&"animate", false)
	holder.add_child(menu)
	await wait_frames(4)
	return menu


## 功能列三个子块里最靠右的那条边（LayoutAnchor 局部坐标 → 菜单坐标）。
func _nav_right(p_menu: Control) -> float:
	var anchor: Control = p_menu.get_node(^"LayoutAnchor") as Control
	var right: float = anchor.get_rect().end.x
	for child_name: String in NAV_CHILDREN:
		var child: Control = anchor.get_node_or_null(NodePath(child_name)) as Control
		if child == null:
			continue
		right = maxf(right, anchor.get_rect().position.x + child.get_rect().end.x)
	return right


func _tag(p_res: Vector2i) -> String:
	return "%dx%d" % [p_res.x, p_res.y]
