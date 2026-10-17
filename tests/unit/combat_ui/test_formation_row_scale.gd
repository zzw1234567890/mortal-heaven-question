extends GutTest
## combat-ui-layout Story 002 单元测试：前后排缩放（AC-2）。
##
## QA 规格：is_front_row true/false → 1.0 / 0.85。
## 边框样式为独立属性不经此函数（QA 规格明文）。
##
## Story 类型 UI（Logic 内核）——此文件为 BLOCKING 证据。

const Rules := preload("res://src/ui/combat/shared/combat_ui_rules.gd")


func test_formation_row_scale_front_row_returns_full() -> void:
	# Then: 前排 100%
	assert_almost_eq(Rules.formation_row_scale(true), 1.0, 0.0001,
		"前排应为 1.0")


func test_formation_row_scale_back_row_returns_85_percent() -> void:
	# Then: 后排 85%
	assert_almost_eq(Rules.formation_row_scale(false), 0.85, 0.0001,
		"后排应为 0.85")


func test_formation_row_scale_constants_exposed_for_component() -> void:
	# Then: 常量导出供组件消费（边框样式为组件独立属性——QA 规格明文
	# 不经此函数，函数仅返回缩放系数）
	assert_almost_eq(Rules.FRONT_ROW_SCALE, 1.0, 0.0001, "前排常量 = 1.0")
	assert_almost_eq(Rules.BACK_ROW_SCALE, 0.85, 0.0001, "后排常量 = 0.85")
