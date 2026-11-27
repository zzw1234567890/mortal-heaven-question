extends GutTest
## 节点图「一眼分得出类型与状态」单元测试（本轮视觉化）。
##
## [b]覆盖[/b]：节点按类型拿到不同图标（图集 region + 类型色互异）、强调态加粗描边
## 的判定旗标、以及类型色光晕常量在场。[br]
## [br][b]为什么不测绘制结果[/b]：headless 下拿不到真实帧缓冲（同
## [code]ui_pass_shot.gd[/code] 头部注记）；「图标不同」落在图集契约上——14 格
## 各占独立 region、主色两两不同，绘制侧 [code]draw_texture_rect_region[/code]
## 只消费这份映射。真机观感由截图取证（[code]tools/ui_shot_node_graph.png[/code]）。[br]
## [br][b]不碰命中检测[/b]：本轮不动 [code]NodeGraphRenderer._has_point[/code]
## （那是负坐标节点拾取 bug 的修复点），故这里不写任何拾取断言。
##
## 来源: 本轮任务书任务二、ADR-0031 §5、design/gdd/exploration-ui-system.md §公式 1。

const ATLAS := preload("res://src/ui/exploration/node_icon_atlas.gd")
const NODE_LOGIC := preload("res://src/ui/exploration/node_state_logic.gd")
const Style := preload("res://src/ui/exploration/node_graph_style.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 节点按类型拿到不同图标
# ═══════════════════════════════════════════════════════════════════════════════

## 14 类节点各占一个独立图集格——两两 region 不相交，不会出现两种类型同一张图。
func test_every_node_type_gets_distinct_atlas_region() -> void:
	var seen: Dictionary = {}
	for type_id: int in ATLAS.ATLAS_COLS:
		var region: Rect2 = ATLAS.get_region(type_id)
		var key: String = "%d,%d,%d,%d" % [int(region.position.x), int(region.position.y),
				int(region.size.x), int(region.size.y)]
		assert_false(seen.has(key), "类型 %d 的图集 region 与类型 %d 重叠" % [type_id, seen.get(key, -1)])
		seen[key] = type_id


## 14 类节点主色两两不同——缩到看不清字形时还能靠色相认类型。
func test_every_node_type_color_is_unique() -> void:
	var colors: Array[Color] = []
	for type_id: int in ATLAS.ATLAS_COLS:
		var color: Color = ATLAS.get_color(type_id)
		assert_false(colors.has(color), "类型 %d 的主色与既有类型重复" % type_id)
		colors.append(color)


## 14 类节点字形两两不同——同色系的类型（战斗红 / 精英红）靠字形分。
func test_every_node_type_glyph_is_unique() -> void:
	var glyphs: Array[String] = []
	for type_id: int in ATLAS.ATLAS_COLS:
		var glyph: String = str(ATLAS.TYPE_SPECS[type_id]["glyph"])
		assert_false(glyphs.has(glyph), "类型 %d 的字形 '%s' 与既有类型重复" % [type_id, glyph])
		glyphs.append(glyph)


## 图集纹理确实建出来了——不是 null，且宽度容纳全部 14 格。
func test_atlas_texture_covers_all_types() -> void:
	var texture: Texture2D = ATLAS.get_atlas()
	assert_not_null(texture, "图集纹理应可懒加载构建")
	assert_eq(texture.get_width(), ATLAS.CELL * ATLAS.ATLAS_COLS,
			"图集宽度应容纳全部类型格")
	assert_eq(texture.get_height(), ATLAS.CELL, "图集高度应为单格边长")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 状态区分更明显——强调态加粗 + 类型色光晕
# ═══════════════════════════════════════════════════════════════════════════════

## 当前/可达/已访问三种「与我有关」的态都被标记为强调（描边加粗一档）。
func test_emphasis_states_are_current_reachable_visited() -> void:
	for state: int in [NODE_LOGIC.NodeState.CURRENT, NODE_LOGIC.NodeState.REACHABLE,
			NODE_LOGIC.NodeState.VISITED]:
		var style: Dictionary = NODE_LOGIC.node_state_style(state)
		assert_true(bool(style.get("emphasis", false)),
				"状态 %d 应被标为强调态（描边加粗）" % state)


## 不可达/行动力不足/迷雾三种「与我无关」的态不加粗——粗细本身也是一层信息。
func test_non_emphasis_states_stay_thin() -> void:
	for state: int in [NODE_LOGIC.NodeState.UNREACHABLE,
			NODE_LOGIC.NodeState.AP_INSUFFICIENT, NODE_LOGIC.NodeState.FOGGED]:
		var style: Dictionary = NODE_LOGIC.node_state_style(state)
		assert_false(bool(style.get("emphasis", false)),
				"状态 %d 不应加粗（与可达态靠粗细也要分得开）" % state)


## 每种状态的样式都带 emphasis 键——绘制侧 `.get("emphasis", false)` 不会漏读。
func test_every_state_exposes_emphasis_key() -> void:
	for state: int in [NODE_LOGIC.NodeState.CURRENT, NODE_LOGIC.NodeState.REACHABLE,
			NODE_LOGIC.NodeState.VISITED, NODE_LOGIC.NodeState.UNREACHABLE,
			NODE_LOGIC.NodeState.AP_INSUFFICIENT, NODE_LOGIC.NodeState.FOGGED]:
		var style: Dictionary = NODE_LOGIC.node_state_style(state)
		assert_true(style.has("emphasis"), "状态 %d 的样式应含 emphasis 键" % state)


## 强调描边必须真的比普通描边粗（旗标只是判定，尺寸在视觉规格里）。
func test_emphasis_border_width_is_thicker() -> void:
	assert_gt(Style.EMPHASIS_BORDER_WIDTH, Style.BORDER_WIDTH,
			"强调态描边应比普通态粗——否则旗标形同虚设")


## 类型色光晕在场且是「衬底而非实心块」——alpha 明显低于 1，图标仍读得清。
func test_type_backdrop_is_a_translucent_halo() -> void:
	assert_gt(Style.TYPE_BACKDROP_GROW, 0.0, "光晕应比图标外扩一圈")
	assert_gt(Style.TYPE_BACKDROP_ALPHA, 0.0, "光晕必须画得出来（alpha 不能为 0）")
	assert_lt(Style.TYPE_BACKDROP_ALPHA, 0.5, "光晕必须是半透衬底，不能糊住图标")


## 迷雾节点不暴露类型——光晕路径不能被迷雾分支借用（类型色会泄漏）。
func test_fogged_glyph_uses_neutral_fill_not_type_color() -> void:
	# Arrange：迷雾底色与任一类型主色都不同
	var fog_fill: Color = Style.FOGGED_FILL_COLOR
	# Assert
	for type_id: int in ATLAS.ATLAS_COLS:
		assert_ne(fog_fill, ATLAS.get_color(type_id),
				"迷雾底色不该等于类型 %d 的主色（类型会被读出来）" % type_id)
