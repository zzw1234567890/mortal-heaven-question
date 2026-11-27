extends GutTest
## 节点类型图标的[b]齐备性[/b]——14 个 [code]NodeType[/code] 必须都有图标文件在盘上。[br]
##
## [b]为什么必须有这条断言[/b]：缺一张图在运行时不报错——[code]NodeIconArt.stamp_of[/code]
## 返回 null，绘制回退到图集 glyph，画面照常出来（只是某个类型永远画成旧样子）。这正是
## 「某个类型永远没有图片」这类缺陷的形态：不崩、不报错、只能靠肉眼在 14 个类型里发现
## 那一个不对。所以把「映射表」做成模块级常量（任务书的硬要求），测试逐类查盘。[br]
##
## [br][b]契约两侧对齐[/b]：映射表的键必须与 [code]ExplorationSystem.NodeType[/code]
## 的枚举值逐一对齐——本测试同时读枚举与映射表，两边分叉时这里会红。[br]
##
## [br]来源: 本轮任务书任务二第 5 条（图标齐备性单测）、
## tests/unit/exploration_ui/test_node_type_icons.gd（同一主题的既有测试）。

## 图标来源（映射表 [constant NodeIconArt.TYPE_ICON_NAMES] 的出处）。
const ART := preload("res://src/ui/exploration/node_icon_art.gd")
## 节点类型枚举（键的对齐基准）。
const BASE := preload("res://src/feature/exploration/exploration_system_base.gd")


func test_type_icon_names_covers_every_node_type() -> void:
	var type_count: int = BASE.NodeType.size()
	assert_eq(ART.TYPE_ICON_NAMES.size(), type_count,
			"映射表条数必须与 NodeType 枚举条数一致（少一条 = 某个类型永远没图标）")
	for type_id: int in type_count:
		assert_true(ART.TYPE_ICON_NAMES.has(type_id),
				"NodeType 值 %d 必须在映射表里（否则该类型没有图标）" % type_id)


func test_every_node_type_icon_file_exists_on_disk() -> void:
	for type_id: int in ART.TYPE_ICON_NAMES.keys():
		var path: String = ART.path_of(type_id)
		assert_ne(path, "", "类型 %d 的图标路径为空（文件缺失或未登记）" % type_id)
		assert_true(ResourceLoader.exists(path), "类型 %d 的图标文件不在盘上: %s"
				% [type_id, path])
		assert_true(FileAccess.file_exists(path), "类型 %d 的文件读不到: %s"
				% [type_id, path])


func test_every_node_type_icon_loads_and_is_square() -> void:
	for type_id: int in ART.TYPE_ICON_NAMES.keys():
		var texture: Texture2D = ART.texture_of(type_id)
		assert_ne(texture, null, "类型 %d 的图标应能 load 成 Texture2D" % type_id)
		if texture == null:
			continue
		var size: Vector2 = texture.get_size()
		assert_gt(size.x, 0.0, "类型 %d 的图标宽度应 > 0" % type_id)
		assert_eq(size.x, size.y, "类型 %d 的图标应是正方形（圆形裁切的前提）" % type_id)


func test_every_node_type_has_a_baked_stamp() -> void:
	ART.clear_cache()
	for type_id: int in ART.TYPE_ICON_NAMES.keys():
		var stamp: Texture2D = ART.stamp_of(type_id)
		assert_ne(stamp, null, "类型 %d 应烘出印章贴图" % type_id)
		if stamp == null:
			continue
		assert_eq(stamp.get_size(), Vector2(float(ART.STAMP_SIZE), float(ART.STAMP_SIZE)),
				"印章尺寸应是 %d×%d（烘图口径）" % [ART.STAMP_SIZE, ART.STAMP_SIZE])


## 印章四角必须透明——「裁成圆」这件事的可断言形态。[br]
## [br][b]为什么断言四角而不是「圆外全部透明」[/b]：全透明检查要遍历 16k 像素（在 GUT 里
## 慢且没必要），四角恰好是圆之外最明确的四个点——它们不透明就说明掩膜压根没生效。
func test_stamp_corners_are_transparent_and_center_is_not() -> void:
	ART.clear_cache()
	var stamp: Texture2D = ART.stamp_of(int(BASE.NodeType.ENTRY))
	assert_ne(stamp, null, "入口图标应烘出印章")
	if stamp == null:
		return
	var image: Image = stamp.get_image()
	image.convert(Image.FORMAT_RGBA8)
	var last: int = ART.STAMP_SIZE - 1
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(last, 0),
			Vector2i(0, last), Vector2i(last, last)]:
		assert_almost_eq(image.get_pixelv(corner).a, 0.0, 0.001,
				"印章四角必须透明（圆形裁切）: %s" % str(corner))
	var middle: Color = image.get_pixelv(Vector2i(last / 2, last / 2))
	assert_gt(middle.a, 0.9, "印章中心必须不透明（图标本体在那儿）")


## 未登记的类型（越界 / 负数）不能崩——回退图集 glyph 的前提。[br]
func test_unregistered_type_returns_empty_path_and_null_texture() -> void:
	ART.clear_cache()
	var unknown: int = ART.TYPE_ICON_NAMES.size() + 97
	assert_eq(ART.path_of(unknown), "", "未登记类型应返回空路径（调用方据此回退）")
	assert_eq(ART.texture_of(unknown), null, "未登记类型应返回 null 纹理")
	assert_eq(ART.stamp_of(unknown), null, "未登记类型应返回 null 印章")
	assert_eq(ART.path_of(-1), "", "负数类型同样回退")
