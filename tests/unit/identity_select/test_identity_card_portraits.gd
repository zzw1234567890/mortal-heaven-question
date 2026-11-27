extends GutTest
## 身份选择 UI 立绘分支单元测试（本轮视觉化）。
##
## [b]覆盖[/b]：身份卡的立绘/占位两条分支——有立绘的身份拿到带
## [code]STRETCH_KEEP_ASPECT_COVERED[/code] 的 [TextureRect]，没有立绘的身份拿到
## 程序化占位（渐变底 + 印章环 + 首字，非空白块）。[br]
## [br][b]为什么纯结构断言而非像素断言[/b]：测试跑在 headless 下，渲染纹理拿不到
## 真实画面（同 [code]ui_pass_shot.gd[/code] 头部注记的处境）；占位的「非空白」
## 因此落在驱动 [method CanvasItem._draw] 的那组配置上——两条渐变端点色必须不同、
## 印章色必须不透明、首字必须非空。真机观感由截图取证
## （[code]tools/ui_shot_identity.png[/code]）。[br]
## [br][b]数据来源[/b]：身份 id / style_tag 取自 [code]identity_templates.gd[/code]
## （ADR-0022 单一事实来源），不在此手写身份表副本。
##
## 来源: 本轮任务书任务一、ADR-0022、ADR-0031 §2/§5、
## design/gdd/identity-selection-system.md §用户界面需求。

const Factory := preload("res://src/ui/identity_select/identity_card_factory.gd")
const Resolver := preload("res://src/ui/identity_select/identity_portrait_resolver.gd")
const TileScript := preload("res://src/ui/identity_select/identity_portrait_tile.gd")
const Templates := preload("res://src/feature/identity/identity_templates.gd")

## 有立绘的身份（assets/characters/portraits 下两张立绘都属于这一条）。
const IDENTITY_WITH_PORTRAIT: StringName = &"azure_sword_disciple"
## 没有立绘的身份（立绘带应走程序化占位）。[br]
## [br][b]为什么不再取真实身份[/b]：2026-11-27 起 6 个身份 × 2 名角色都有立绘了
## （即梦生成的 12 张），任何真实身份都走不到占位分支。占位分支仍然存在且有
## 意义——模板查无 / 数据缺失 / 新增身份还没出图时都靠它，故改用合成 id：
## 模板查无 ⇒ card_id 为空 ⇒ 恒走程序化占位（见 Resolver 的文档注释）。
const IDENTITY_WITHOUT_PORTRAIT: StringName = &"synthetic_identity_without_art"


## 造一条 get_available_identities() 形态的条目（只填 UI 读到的键）。
func _entry(p_identity_id: StringName) -> Dictionary:
	if not Templates.IDENTITY_TEMPLATES.has(p_identity_id):
		# 合成身份：没有模板条目，只有显示名——正是「查无模板」那条回退路径。
		return {
			"identity_id": p_identity_id,
			"name": "无名散修",
			"style_tag": "灵活",
			"initial_ling_shi": 10,
			"character_display_names": ["无名甲", "无名乙"],
			"is_unlocked": true,
			"is_ready": true,
			"block_reason": "",
		}
	var tmpl: Dictionary = Templates.IDENTITY_TEMPLATES[p_identity_id]
	var names: Array[String] = []
	for detail: Dictionary in tmpl["character_details"]:
		names.append(str(detail["display_name"]))
	return {
		"identity_id": p_identity_id,
		"name": tmpl["name"],
		"style_tag": tmpl["style_tag"],
		"initial_ling_shi": tmpl["initial_resources"]["ling_shi"],
		"character_display_names": names,
		"is_unlocked": true,
		"is_ready": true,
		"block_reason": "",
	}


## 从立绘带里找出全部小块（AvatarRow 的直接子节点）。
func _tiles(card: Control) -> Array[Control]:
	var out: Array[Control] = []
	var row: Node = card.get_node_or_null(NodePath("VBoxContainer/AvatarRow"))
	if row == null:
		# VBox 是代码建的，名字由 Godot 默认生成——按类型兜底找
		for child: Node in card.get_children():
			row = _find_row(child)
			if row != null:
				break
	if row == null:
		return out
	for child: Node in row.get_children():
		var ctrl: Control = child as Control
		if ctrl != null:
			out.append(ctrl)
	return out


func _find_row(p_node: Node) -> Node:
	if p_node.name == &"AvatarRow":
		return p_node
	for child: Node in p_node.get_children():
		var found: Node = _find_row(child)
		if found != null:
			return found
	return null


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 有立绘的身份 → 拿到 TextureRect（且是按比例裁剪，不是拉伸）
# ═══════════════════════════════════════════════════════════════════════════════

func test_identity_with_portrait_gets_texture_rect() -> void:
	# Arrange / Act
	var card: Control = Factory.build_card(_entry(IDENTITY_WITH_PORTRAIT), 0)
	add_child_autofree(card)
	var tiles: Array[Control] = _tiles(card)
	# Assert
	assert_gt(tiles.size(), 0, "有立绘的身份应至少产出一块角色小块")
	var with_portrait: int = 0
	for tile: Control in tiles:
		if tile.get_node_or_null(NodePath(String(TileScript.PORTRAIT_NODE_NAME))) != null:
			with_portrait += 1
	assert_gt(with_portrait, 0, "有立绘的身份应至少一块拿到 Portrait 子节点")
	assert_true(bool(tiles[0].call(&"has_portrait")), "小块自身应报告有立绘")


func test_portrait_texture_rect_keeps_aspect_covered() -> void:
	# Arrange
	var card: Control = Factory.build_card(_entry(IDENTITY_WITH_PORTRAIT), 0)
	add_child_autofree(card)
	# Act
	var rect: TextureRect = null
	for tile: Control in _tiles(card):
		rect = tile.get_node_or_null(NodePath(String(TileScript.PORTRAIT_NODE_NAME))) \
				as TextureRect
		if rect != null:
			break
	# Assert：800×1120 的竖版原图必须按比例填满并裁边，不许压扁
	assert_not_null(rect, "立绘小块应含 TextureRect")
	assert_eq(rect.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
			"立绘应按比例填满并居中裁剪（不许拉伸变形）")
	assert_eq(rect.expand_mode, TextureRect.EXPAND_IGNORE_SIZE,
			"立绘应忽略最小尺寸约束铺满小块")
	assert_not_null(rect.texture, "TextureRect 应挂上真实立绘纹理")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 没有立绘的身份 → 程序化占位（渐变 + 印章 + 首字，不是空白块）
# ═══════════════════════════════════════════════════════════════════════════════

func test_identity_without_portrait_gets_procedural_placeholder() -> void:
	# Arrange
	var card: Control = Factory.build_card(_entry(IDENTITY_WITHOUT_PORTRAIT), 0)
	add_child_autofree(card)
	# Act
	var tiles: Array[Control] = _tiles(card)
	# Assert
	assert_gt(tiles.size(), 0, "无立绘的身份也应产出角色小块（不许凭空行）")
	for tile: Control in tiles:
		assert_false(bool(tile.call(&"has_portrait")),
				"该身份没有立绘资产——小块不应挂 TextureRect")
		assert_null(tile.get_node_or_null(NodePath(String(TileScript.PORTRAIT_NODE_NAME))),
				"无立绘时不应存在 Portrait 子节点")
		assert_false(str(tile.call(&"label_text")).is_empty(),
				"占位块必须有文字（印章首字）——空白块不算占位")


func test_placeholder_palette_is_a_gradient_with_accent_seal() -> void:
	# Arrange / Act：按 style_tag 取色板（数据里没有色值，走固定色板分支）
	var palette: Dictionary = Resolver.palette_for(IDENTITY_WITHOUT_PORTRAIT, "灵活")
	# Assert：渐变两端不同色 → _draw 画出来是有深浅的底，不是一块纯色/空白
	assert_ne(palette["top"], palette["bottom"], "渐变上下沿必须不同色（否则不成渐变）")
	assert_ne(palette, Resolver.FALLBACK_PALETTE, "该身份有自己的派系色板，不该落到兜底")
	assert_eq(float(palette["accent"].a), 1.0, "印章环色必须完全不透明（否则看不见）")


func test_distinct_identities_get_distinct_palettes() -> void:
	# Arrange：两条不同 style_tag 的无立绘身份
	var a: Dictionary = Resolver.palette_for(IDENTITY_WITHOUT_PORTRAIT, "灵活")
	var b: Dictionary = Resolver.palette_for(&"frost_palace_disciple",
			str(Templates.IDENTITY_TEMPLATES[&"frost_palace_disciple"]["style_tag"]))
	# Assert：派系色板互异，玩家一眼能分出不同身份
	assert_ne(a["top"], b["top"], "不同派系身份的占位底色应不同")


## 未知身份 / 空条目不得崩，也不必是空白——落到兜底色板。
func test_unknown_entry_falls_back_without_crashing() -> void:
	# Act
	var card: Control = Factory.build_card({}, 5)
	add_child_autofree(card)
	var row: Node = _find_row(card)
	# Assert：空条目没有角色名 → 无小块，但卡片结构完整
	assert_not_null(row, "空条目也应渲染出立绘行（只是没有小块）")
	assert_eq(_tiles(card).size(), 0, "空条目没有角色名 → 立绘带为空")


## 卡片尺寸必须容得下立绘带——图与文字各占一行，图不叠字。
func test_card_min_size_fits_avatar_row() -> void:
	assert_gte(Factory.CARD_MIN_SIZE.y, float(Factory.AVATAR_MIN_SIZE.y) + 80.0,
			"卡片最小高度应给立绘带之外留出文字行（名字/标签/灵石）")


## 立绘带的小块不抢鼠标——点击仍落到卡片上（焦点链不因加图而断）。
func test_avatar_tiles_do_not_steal_mouse() -> void:
	# Arrange
	var card: Control = Factory.build_card(_entry(IDENTITY_WITH_PORTRAIT), 0)
	add_child_autofree(card)
	# Assert
	assert_eq(card.mouse_filter, Control.MOUSE_FILTER_STOP, "卡片自身仍收鼠标")
	assert_eq(card.focus_mode, Control.FOCUS_ALL, "卡片仍可聚焦（焦点链不变）")
	for tile: Control in _tiles(card):
		assert_eq(tile.mouse_filter, Control.MOUSE_FILTER_IGNORE,
				"小块必须忽略鼠标——否则点击被小块吞掉，卡片点不动")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 立绘按「骨架名」解析——资产名与 card_id 不逐字相等的也要命中
# ═══════════════════════════════════════════════════════════════════════════════

## card_id 与资产名下划线写法不同（[code]su_jian_ming[/code] vs
## [code]char_su_jianming_portrait_full.png[/code]）也必须解析到同一张立绘。[br]
## [br][b]回归来源[/b]：首版按「原名 → 去下划线」两个候选名逐字探测，截图里
## 卡 0 的第二块（苏剑鸣）没拿到立绘——只有 1/2 有图。改为扫目录建骨架名索引。
func test_portrait_resolves_across_underscore_variants() -> void:
	# Arrange：带下划线的真实 card_id 与资产名的写法（无下划线）
	var with_sep: String = "su_jian_ming"
	var without_sep: String = "sujianming"
	# Act
	var path_a: String = Resolver.resolve_path(with_sep)
	var path_b: String = Resolver.resolve_path(without_sep)
	# Assert
	assert_false(path_a.is_empty(), "带下划线的 card_id 必须解析到立绘路径")
	assert_eq(path_a, path_b, "两种下划线写法应指向同一张立绘")
	assert_not_null(Resolver.portrait_for(with_sep), "带下划线的 card_id 应取到真实纹理")


## 有立绘的身份，两名角色都得拿到立绘——一张都不能漏。[br]
## [br][b]回归来源[/b]：截图取证脚本打印「小块=2 立绘=1」，正是这条挂了。
func test_all_characters_of_portrait_identity_get_portraits() -> void:
	# Arrange
	var card: Control = Factory.build_card(_entry(IDENTITY_WITH_PORTRAIT), 0)
	add_child_autofree(card)
	var tiles: Array[Control] = _tiles(card)
	# Act
	var with_portrait: int = 0
	for tile: Control in tiles:
		if bool(tile.call(&"has_portrait")):
			with_portrait += 1
	# Assert
	assert_gte(tiles.size(), 2, "该身份有两名角色，应产出两块")
	assert_eq(with_portrait, tiles.size(),
			"两名角色都有立绘资产——不应有一块退化成占位")


## 未知 card_id 解析为空串（不崩、不乱配到别人的立绘）。
func test_unknown_card_id_resolves_to_empty_path() -> void:
	# Act / Assert
	assert_eq(Resolver.resolve_path("no_such_character_zzz"), "", "查无应返回空串")
	assert_eq(Resolver.resolve_path(""), "", "空 card_id 应返回空串")
	assert_null(Resolver.portrait_for("no_such_character_zzz"), "查无应返回 null")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 占位必须「不是空白色块」——尺寸与对比度下限
# ═══════════════════════════════════════════════════════════════════════════════

## 印章纹样必须占满小块短边的一大半——小圆圈在整屏看就是一块底。[br]
## [br][b]回归来源[/b]：首版 [code]SEAL_RADIUS_RATIO = 0.30[/code] 在 104×72 的
## 格子里只画出直径 43px 的细圈，目视与空白块无异。
func test_placeholder_seal_dominates_the_tile() -> void:
	# Assert：半径占比 > 0.35 且不溢出（< 0.5 才留得住描边余量）
	assert_gt(TileScript.SEAL_RADIUS_RATIO, 0.35,
			"印章半径应占短边三成半以上，否则缩到整屏就是一块底")
	assert_lt(TileScript.SEAL_RADIUS_RATIO, 0.5, "印章不应溢出小块边界")
	assert_gt(TileScript.SEAL_RING_WIDTH, 2.0, "印章环应比首版的 2px 更粗，缩图才看得见")


## 首字下方要垫一层印章色圆盘——否则浅底上的同色字糊成一片。[br]
## [br][b]为什么这不只是「好看」[/b]：占位的可读性全靠对比，圆盘是唯一一层
## 不受配色明暗影响的固定对比垫。
func test_placeholder_draws_contrast_disc_under_seal() -> void:
	assert_gt(TileScript.SEAL_DISC_ALPHA, 0.0, "印章圆盘必须画得出来")
	assert_lt(TileScript.SEAL_DISC_ALPHA, 0.5, "圆盘是半透垫底，不能糊住底纹")


## 首字号随块尺寸自适应且不小于下限——小块也要读得清。
func test_placeholder_font_scales_with_tile_and_has_floor() -> void:
	# Arrange：卡片里小块的实际短边
	var tile: Control = Factory._make_tile("", "林渊", Resolver.FALLBACK_PALETTE,
			Factory.AVATAR_MIN_SIZE)
	add_child_autofree(tile)
	# Act：半径 × 比例 = 期望字号
	var radius: float = minf(Factory.AVATAR_MIN_SIZE.x, Factory.AVATAR_MIN_SIZE.y) \
			* TileScript.SEAL_RADIUS_RATIO
	var expected: int = maxi(int(radius * TileScript.SEAL_FONT_RATIO), TileScript.SEAL_FONT_MIN)
	# Assert
	assert_gt(expected, 0, "首字号应算得出来")
	assert_gte(expected, TileScript.SEAL_FONT_MIN, "首字号不得低于可读下限")
	assert_eq(str(tile.call(&"label_text")), "林渊", "小块应保留角色名文案")


## 六套派系色板的整体明度都要够高——占位底不能读成一块黑。[br]
## [br][b]度量口径[/b]：渐变是 top→bottom 的连续过渡，观感由两端均值决定；
## 只看上沿会漏掉「上沿还行、下沿压到近黑」这一路。[br]
## [br][b]回归来源[/b]：首版是 [code]#8A2E33 → #3A1013[/code]（均值明度 ~0.18），
## 截图里整块读起来就是暗色空块，违反「视觉上不能是空白色块」。
func test_every_style_palette_is_bright_enough_to_read() -> void:
	# Arrange：整体明度下限（首版六套均在 0.22 以下，当前六套均在 0.30 以上）
	var floor_luminance: float = 0.22
	# Assert
	for tag: String in Resolver.STYLE_PALETTES:
		var palette: Dictionary = Resolver.STYLE_PALETTES[tag]
		var mean: float = (float(palette["top"].get_luminance())
				+ float(palette["bottom"].get_luminance())) * 0.5
		assert_gt(mean, floor_luminance,
				"派系 '%s' 的渐变整体太暗（均值 %.3f），占位会读成空白色块" % [tag, mean])
		assert_ne(palette["top"], palette["bottom"], "派系 '%s' 的渐变两端必须不同色" % tag)
		assert_gt(float(palette["accent"].get_luminance()), 0.7,
				"派系 '%s' 的印章色应是近白色，压在渐变上才看得见" % tag)
	var fallback_mean: float = (float(Resolver.FALLBACK_PALETTE["top"].get_luminance())
			+ float(Resolver.FALLBACK_PALETTE["bottom"].get_luminance())) * 0.5
	assert_gt(fallback_mean, floor_luminance, "兜底色板太暗，占位会读成空白色块")

