extends GutTest
## main-menu Story 003 单元测试：分辨率过滤与回退纯函数（QA AC-1）。
##
## 覆盖 QA 规格全部场景与 edge cases：[br]
##   - R∈L → resolved=R、fallback_used=false（快乐路径）[br]
##   - R∉L 且 previous∈L → resolved=previous、fallback_used=true[br]
##   - R∉L 且 previous∉L → resolved=1920×1080、fallback_used=true[br]
##   - L 为空 → 回退链终止到 1920×1080[br]
##   - R 恰为 L 最小项 → 通过不误回退[br]
##   - 宽高比不匹配项剔除（filter_by_aspect_ratio：16:9 vs 4:3）[br]
##   - previous 无效/不在 L → 直接回退默认[br]
##
## 纯函数直调——无场景树依赖。风格先例：test_db_from_percent.gd
## （arrange/act/assert + 常量文件注记）。

const Logic := preload("res://src/ui/main_menu/settings_graphics_logic.gd")

## 16:9 可用列表（升序——enumeration 惯例；边界值本身即测试点，
## 测试隔离规则例外声明：允许内联魔数）。
const LIST_16_9: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
]


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：filter_resolutions 三入参判定
# ═══════════════════════════════════════════════════════════════════════════════

func test_filter_requested_in_list_resolves_to_requested() -> void:
	## AC-1: R∈L → resolved=R、fallback_used=false（快乐路径）。
	# Arrange
	var requested: Vector2i = Vector2i(1920, 1080)
	var previous: Vector2i = Vector2i(1280, 720)
	# Act
	var result: Dictionary = Logic.filter_resolutions(requested, LIST_16_9, previous)
	# Assert
	assert_eq(result["resolved"], requested, "请求项在列表内应直接采用")
	assert_false(bool(result["fallback_used"]), "请求项可用时不应标记回退")


func test_filter_requested_missing_previous_in_list_falls_back_to_previous() -> void:
	## AC-1: R∉L 且 previous∈L → resolved=previous、fallback_used=true。
	# Arrange
	var requested: Vector2i = Vector2i(1440, 900)  # 不在列表
	var previous: Vector2i = Vector2i(1920, 1080)  # 在列表
	# Act
	var result: Dictionary = Logic.filter_resolutions(requested, LIST_16_9, previous)
	# Assert
	assert_eq(result["resolved"], previous, "请求不可用应回退上一生效分辨率")
	assert_true(bool(result["fallback_used"]), "回退到 previous 应标记 fallback_used")


func test_filter_requested_and_previous_missing_falls_back_to_default() -> void:
	## AC-1: R∉L 且 previous∉L → resolved=1920×1080、fallback_used=true。
	# Arrange
	var requested: Vector2i = Vector2i(1024, 768)
	var previous: Vector2i = Vector2i(800, 600)
	# Act
	var result: Dictionary = Logic.filter_resolutions(requested, LIST_16_9, previous)
	# Assert
	assert_eq(result["resolved"], Logic.RESOLUTION_FALLBACK,
			"两者皆不可用应回退默认 1920×1080")
	assert_true(bool(result["fallback_used"]), "终极回退应标记 fallback_used")


func test_filter_empty_list_terminates_to_fallback_default() -> void:
	## AC-1 edge: L 为空 → 回退链终止到 1920×1080。
	# Arrange
	var requested: Vector2i = Vector2i(1920, 1080)
	var previous: Vector2i = Vector2i(1280, 720)
	# Act
	var result: Dictionary = Logic.filter_resolutions(requested, [], previous)
	# Assert
	assert_eq(result["resolved"], Logic.RESOLUTION_FALLBACK, "空列表应回退默认")
	assert_true(bool(result["fallback_used"]), "空列表应标记回退")


func test_filter_requested_is_smallest_item_passes_no_false_fallback() -> void:
	## AC-1 edge: R 恰为 L 最小项 → 通过不误回退（边界值精确匹配）。
	# Arrange
	var requested: Vector2i = Vector2i(1280, 720)  # 列表最小项
	var previous: Vector2i = Vector2i(1920, 1080)
	# Act
	var result: Dictionary = Logic.filter_resolutions(requested, LIST_16_9, previous)
	# Assert
	assert_eq(result["resolved"], requested, "最小项请求应精确通过")
	assert_false(bool(result["fallback_used"]), "最小项可用不应误回退")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1 edge：宽高比过滤（filter_by_aspect_ratio）
# ═══════════════════════════════════════════════════════════════════════════════

func test_filter_by_aspect_ratio_removes_mismatched_items() -> void:
	## AC-1 edge: 16:9 列表混入 4:3 → 4:3 项被剔除（±5% 容差外）。
	# Arrange
	var mixed: Array[Vector2i] = [
		Vector2i(1280, 720),    # 16:9（保留）
		Vector2i(1600, 1200),   # 4:3（剔除）
		Vector2i(1920, 1080),   # 16:9（保留）
		Vector2i(1024, 768),    # 4:3（剔除）
	]
	var base: Vector2i = Vector2i(1920, 1080)
	# Act
	var filtered: Array[Vector2i] = Logic.filter_by_aspect_ratio(
			mixed, base, Logic.ASPECT_TOLERANCE)
	# Assert
	assert_eq(filtered.size(), 2, "应仅保留 16:9 两项")
	assert_eq(filtered[0], Vector2i(1280, 720), "首项应保留 1280×720")
	assert_eq(filtered[1], Vector2i(1920, 1080), "次项应保留 1920×1080")


func test_filter_by_aspect_ratio_keeps_same_ratio_items() -> void:
	## AC-1 edge: 全 16:9 列表 → 全部保留（同比例不误剔除）。
	# Arrange
	var all_16_9: Array[Vector2i] = [
		Vector2i(1280, 720),
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
	]
	# Act
	var filtered: Array[Vector2i] = Logic.filter_by_aspect_ratio(
			all_16_9, Vector2i(1920, 1080), Logic.ASPECT_TOLERANCE)
	# Assert
	assert_eq(filtered.size(), 3, "同比例列表应全部保留")


func test_filter_by_aspect_ratio_invalid_base_returns_original() -> void:
	## AC-1 edge: base 无效（零尺寸/headless）→ 跳过过滤返回原列表副本。
	# Arrange
	var res: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 1200)]
	# Act
	var filtered: Array[Vector2i] = Logic.filter_by_aspect_ratio(
			res, Vector2i(0, 0), Logic.ASPECT_TOLERANCE)
	# Assert —— 基准零尺寸应跳过过滤（副本等价）
	assert_eq(filtered, res, "基准零尺寸应返回原列表（跳过过滤）")
