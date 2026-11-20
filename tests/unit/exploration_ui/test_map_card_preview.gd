extends GutTest
## 地图卡片的[b]插图预览块[/b] —— 「地图选择里看不到地图」。[br]
## [br][b]本文件补的缺口[/b]：卡片此前一个图片节点都没有（[code]_build()[/code] 只
## 建七行 Label），玩家看到的是一张只有字的卡；而 17 张插图早已落盘在
## [code]assets/environments/maps/[/code]。[br]
## [br][b]覆盖[/b]：[br]
##   1. 探明表里[b]每一张[/b]地图都有插图登记，且文件真的在盘上——漏一张就是一张
##      没图的卡，而这种缺陷运行时不报错，只让玩家看到占位块；[br]
##   2. 有图时预览块里的 TextureRect 拿到纹理、尺寸合理，且铺满模式为
##      「不参与最小尺寸 + 保持比例铺满」；[br]
##   3. 缺图时退深色占位块 + 居中「暂无图」（不留白）；[br]
##   4. 预览块不与名称行相交（卡片长高了，但各行仍各占各的）。[br]
## [br][b]为什么是控件级[/b]：判据落在 [code]MapCard._build[/code] 建出的预览块与
## 名称标签上；卡片是纯 [Panel]，[code]new()[/code] 即可建，不需要场景与 Autoload。[br]
##
## 来源: design/gdd/exploration-ui-system.md §1 地图选择界面（卡片含地图插图）、
## design/assets/specs/map-card-illustrations-assets.md（ASSET-211~227）、
## ADR-0031 §2、.claude/rules/ui-code.md。

const MapCardScript := preload("res://src/ui/exploration/map_card.gd")
const ArtScript := preload("res://src/ui/exploration/map_card_art.gd")
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")

## 探明表里有所登记、但资产侧故意没有插图的地图 ID（占位路径的用例输入）。[br]
## 用不存在的 ID 而不是「临时从表里删一张」——后者会污染静态常量。
const MAP_WITHOUT_ART: StringName = &"no_such_map_id"

var _card: Panel = null


func after_each() -> void:
	if _card != null and is_instance_valid(_card):
		_card.free()
	_card = null


## 按条目建卡（入树——锚点/偏移才会真的算）。
func _card_of(p_entry: Dictionary) -> Panel:
	_card = MapCardScript.new()
	_card.call(&"setup", p_entry)
	add_child_autofree(_card)
	return _card


## 一份最小条目（只填卡片读的字段）。
func _entry(p_map_id: StringName, p_overrides: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = {
		"map_id": p_map_id, "name": "青云剑宗", "difficulty": 1,
		"is_cleared": false, "clear_count": 0, "is_unlocked": true,
		"reentry_allowed": true, "reentry_total": 0, "is_permanent_free": true,
	}
	for key: Variant in p_overrides.keys():
		entry[key] = p_overrides[key]
	return entry


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 探明表 17 张图逐张有插图、且文件在盘上
# ═══════════════════════════════════════════════════════════════════════════════

func test_every_catalog_map_has_an_illustration_entry() -> void:
	# Assert——缺登记的地图挑出来（探明表加了新图但忘了配插图时，这条会红）
	var missing: Array = []
	for raw_id: Variant in CatalogScript.MAPS.keys():
		if ArtScript.path_of(StringName(str(raw_id))).is_empty():
			missing.append(raw_id)
	assert_eq(missing, [], "探明表里这些地图没有插图登记（卡片会显示占位块）：%s" % [missing])


func test_every_illustration_file_exists_on_disk() -> void:
	# Assert——登记了但文件不在盘上，同样是「看不到地图」（运行时不报错）
	var missing: Array = []
	for raw_id: Variant in CatalogScript.MAPS.keys():
		var path: String = ArtScript.path_of(StringName(str(raw_id)))
		if not path.is_empty() and not ResourceLoader.exists(path):
			missing.append(path)
	assert_eq(missing, [], "这些插图资源加载不到：%s" % [missing])


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 有图：纹理到手、尺寸合理、缩放模式对
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_with_known_map_shows_preview_texture() -> void:
	# Arrange
	var card: Panel = _card_of(_entry(&"qing_yun_jian_zong"))
	await get_tree().process_frame
	# Act
	var art: TextureRect = ArtScript.art_of(card)
	# Assert——纹理非空且尺寸合理（一张真正的插图，不是 1×1 的占位像素）
	assert_not_null(art, "卡片应有插图节点")
	if art == null:
		return
	assert_not_null(art.texture, "青云剑宗应有插图（%s）" % ArtScript.path_of(&"qing_yun_jian_zong"))
	if art.texture == null:
		return
	var size: Vector2 = art.texture.get_size()
	assert_gt(size.x, 128.0, "插图宽度应是一张可用图的尺寸，实际 %.0f" % size.x)
	assert_gt(size.y, 128.0, "插图高度应是一张可用图的尺寸，实际 %.0f" % size.y)


func test_preview_texture_is_covered_not_stretched_free() -> void:
	# Arrange
	var card: Panel = _card_of(_entry(&"yun_lan_cheng"))
	await get_tree().process_frame
	var art: TextureRect = ArtScript.art_of(card)
	assert_not_null(art, "卡片应有插图节点")
	if art == null:
		return
	# Assert——不参与最小尺寸（否则 360×420 的竖图会把卡面顶高）+ 保持比例铺满
	assert_eq(art.expand_mode, TextureRect.EXPAND_IGNORE_SIZE,
			"插图不应参与最小尺寸计算（会顶高卡面）")
	assert_eq(art.stretch_mode, TextureRect.STRETCH_KEEP_ASPECT_COVERED,
			"插图应保持比例铺满（不拉伸变形、不留边）")


func test_preview_block_takes_about_45_percent_of_card_height() -> void:
	# Arrange
	var card: Panel = _card_of(_entry(&"qing_yun_jian_zong"))
	await get_tree().process_frame
	# Act
	var preview: Control = ArtScript.preview_of(card)
	# Assert——预览块高度占卡片高度约 45%（±2px 容差）
	assert_not_null(preview, "卡片应有预览块")
	if preview == null:
		return
	var ratio: float = preview.get_rect().size.y / card.get_rect().size.y
	assert_almost_eq(ratio, MapCardScript.CARD_PREVIEW_RATIO, 0.02,
			"预览块应占卡片高度约 %.0f%%，实际 %.0f%%"
			% [MapCardScript.CARD_PREVIEW_RATIO * 100.0, ratio * 100.0])


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 缺图：深色占位块 + 居中「暂无图」，不留白
# ═══════════════════════════════════════════════════════════════════════════════

func test_missing_illustration_falls_back_to_placeholder_block() -> void:
	# Arrange——未登记插图的地图
	var card: Panel = _card_of(_entry(MAP_WITHOUT_ART))
	await get_tree().process_frame
	# Act
	var art: TextureRect = ArtScript.art_of(card)
	var placeholder: ColorRect = ArtScript.placeholder_of(card)
	var label: Label = ArtScript.placeholder_label_of(card)
	# Assert——占位块在场且可见，插图那层藏起来（两层同显会互相盖住）
	assert_not_null(placeholder, "缺图时应退占位块，而不是留白")
	if placeholder == null:
		return
	assert_true(placeholder.visible, "缺图时占位块应可见")
	assert_eq(placeholder.color, ArtScript.PLACEHOLDER_COLOR,
			"占位块应为约定的深色（与卡面留白区分开）")
	assert_not_null(label, "占位块上应有「暂无图」文案")
	if label != null:
		assert_eq(label.text, ArtScript.TEXT_NO_IMAGE, "占位文案应为「暂无图」")
		assert_eq(label.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, "占位文案应居中")
	if art != null:
		assert_true(art.texture == null, "缺图时插图层不应有纹理")
		assert_false(art.visible, "缺图时插图层应隐藏，只留占位块")


func test_present_illustration_hides_placeholder() -> void:
	## 反向用例——有图的卡不该同时画着占位块（否则深色块会盖在插图上）。
	var card: Panel = _card_of(_entry(&"qing_yun_jian_zong"))
	await get_tree().process_frame
	var placeholder: ColorRect = ArtScript.placeholder_of(card)
	var label: Label = ArtScript.placeholder_label_of(card)
	assert_not_null(placeholder, "有图时占位块仍在树上（只是不可见）——便于两态复用")
	if placeholder != null:
		assert_false(placeholder.visible, "有图时占位块应隐藏")
	if label != null:
		assert_false(label.visible, "有图时「暂无图」应隐藏")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 预览块不与名称行相交
# ═══════════════════════════════════════════════════════════════════════════════

func test_preview_does_not_overlap_name_label() -> void:
	# Arrange
	var card: Panel = _card_of(_entry(&"gui_xu_gu_mo_zhan_chang",
			{"name": "归墟·古魔战场"}))
	await get_tree().process_frame
	# Act——名称行是内容盒里的第一行
	var preview: Control = ArtScript.preview_of(card)
	assert_not_null(preview, "卡片应有预览块")
	if preview == null:
		return
	var name_label: Label = null
	for raw: Variant in _labels_of(card):
		var label: Label = raw as Label
		if label.text == "归墟·古魔战场":
			name_label = label
	assert_not_null(name_label, "卡面应有名称行")
	if name_label == null:
		return
	# Assert——预览块底缘不超过名称行顶缘（相交就是图压在字上）
	assert_lte(preview.get_global_rect().end.y, name_label.get_global_rect().position.y + 0.5,
			"预览块（到 %.0f）不应压住名称行（起于 %.0f）"
			% [preview.get_global_rect().end.y, name_label.get_global_rect().position.y])


## 卡面所有标签（深度优先——内部结构是构建细节，不写死路径）。
func _labels_of(p_node: Node) -> Array:
	var out: Array = []
	for child: Node in p_node.get_children():
		if child is Label:
			out.append(child)
		out.append_array(_labels_of(child))
	return out
