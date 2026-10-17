extends GutTest
## combat-ui-layout Story 002 单元测试：HP 颜色阈值（AC-1）。
##
## QA 规格：0.61/1.0 → 绿；0.6 → 黄；0.31 → 黄；0.30 → 红；0.0 → 红。
## 边界：0.6 恰好黄（>0.6 才绿）、0.3 恰好红（AC 明文）。
## max_hp=0 调用侧守卫（防除零）为组件集成测试覆盖——纯函数契约
## 假设 ratio 已合法。
##
## Story 类型 UI（Logic 内核）——此文件为 BLOCKING 证据。
## 风格先例：tests/unit/combat_ui/test_font_size_responsive.gd。

const Rules := preload("res://src/ui/combat/shared/combat_ui_rules.gd")


func test_hp_bar_color_high_ratio_returns_green() -> void:
	# Then: >0.6 → 绿
	assert_eq(Rules.hp_bar_color(0.61), Rules.HP_COLOR_GREEN, "0.61 应为绿")
	assert_eq(Rules.hp_bar_color(1.0), Rules.HP_COLOR_GREEN, "满血 1.0 应为绿")


func test_hp_bar_color_mid_ratio_returns_yellow() -> void:
	# Then: 0.3 < ratio ≤ 0.6 → 黄
	assert_eq(Rules.hp_bar_color(0.6), Rules.HP_COLOR_YELLOW,
		"0.6 恰好黄（>0.6 才绿——QA 边界）")
	assert_eq(Rules.hp_bar_color(0.31), Rules.HP_COLOR_YELLOW, "0.31 应为黄")
	assert_eq(Rules.hp_bar_color(0.5), Rules.HP_COLOR_YELLOW, "0.5 应为黄")


func test_hp_bar_color_low_ratio_returns_red() -> void:
	# Then: ≤0.3 → 红（0.3 恰好红——AC 明文）
	assert_eq(Rules.hp_bar_color(0.30), Rules.HP_COLOR_RED,
		"0.30 恰好红（AC 明文）")
	assert_eq(Rules.hp_bar_color(0.0), Rules.HP_COLOR_RED, "0.0 空血应为红")
	assert_eq(Rules.hp_bar_color(0.29), Rules.HP_COLOR_RED, "0.29 应为红")


func test_hp_bar_color_thresholds_not_hardcoded_in_consumer() -> void:
	# Then: 阈值常量集中于 CombatUiRules（control-manifest 禁止硬编码 HP 阈值）
	assert_almost_eq(Rules.HP_GREEN_THRESHOLD, 0.6, 0.0001, "绿阈值 = 0.6")
	assert_almost_eq(Rules.HP_RED_THRESHOLD, 0.3, 0.0001, "红阈值 = 0.3")
