extends GutTest
## combat-ui-layout Story 001 Logic 内核测试：font_size_responsive 纯函数。
##
## 覆盖 AC-8（共享纯函数模块建立）——QA 规格 AC-1 全部边界值。
## 纯函数零依赖：直接静态调用断言（无场景树交互）。
##
## Story 类型 UI（含 Integration + Logic 内核）——此文件为 BLOCKING 证据。

const FontMod := preload("res://src/ui/combat/shared/combat_ui_font.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 三档基准映射（QA AC-1 Then 分支）
# ═══════════════════════════════════════════════════════════════════════════════

func test_font_size_responsive_full_hd_returns_base() -> void:
	# Arrange / Act / Assert——1080 基准分辨率返回原值
	assert_eq(FontMod.font_size_responsive(14, 1080), 14, "1080 → 原值（满档不缩放）")
	assert_eq(FontMod.font_size_responsive(20, 1440), 20, "1440 超基准 → 原值")
	assert_eq(FontMod.font_size_responsive(20, 2160), 20, "2160 4K → 原值（不做放大）")


func test_font_size_responsive_scaled_tier_applies_85_percent() -> void:
	# 1079 → 85% 档（4K 以下、720 及以上）
	assert_eq(FontMod.font_size_responsive(20, 1079), 17, "1079 → ×0.85 = 17")
	assert_eq(FontMod.font_size_responsive(20, 720), 17, "720 → ×0.85 = 17")
	assert_eq(FontMod.font_size_responsive(30, 900), 26, "900 → round(25.5) = 26（四舍五入）")


func test_font_size_responsive_below_720_floors_to_12() -> void:
	# <720 → 保底 12pt（不支持 720 以下——防御性保底）
	assert_eq(FontMod.font_size_responsive(14, 719), 12, "719 → 保底 12")
	assert_eq(FontMod.font_size_responsive(24, 600), 12, "600 → 保底 12（非 20）")
	assert_eq(FontMod.font_size_responsive(100, 100), 12, "极小屏 → 保底 12")


# ═══════════════════════════════════════════════════════════════════════════════
# QA 规格 Edge cases（AC-1 边界值清单）
# ═══════════════════════════════════════════════════════════════════════════════

func test_font_size_responsive_edge_base14_at_720_floors() -> void:
	# base=14@720 → round(14×0.85)=round(11.9)=12（保底截断规格值）
	assert_eq(FontMod.font_size_responsive(14, 720), 12, "base=14@720 → max(11.9, 12) = 12")


func test_font_size_responsive_edge_base100_at_720() -> void:
	assert_eq(FontMod.font_size_responsive(100, 720), 85, "base=100@720 → 85")


func test_font_size_responsive_edge_base12_at_1080() -> void:
	assert_eq(FontMod.font_size_responsive(12, 1080), 12, "base=12@1080 → 12 原值")


# ═══════════════════════════════════════════════════════════════════════════════
# 防御边界（QA 规格未列——纯函数健壮性）
# ═══════════════════════════════════════════════════════════════════════════════

func test_font_size_responsive_boundary_exact_1080_no_scaling() -> void:
	# 1080 与 1079 的档位分界（>=1080 满档）
	assert_eq(FontMod.font_size_responsive(20, 1080), 20, "恰好 1080 → 原值")
	assert_eq(FontMod.font_size_responsive(20, 1079), 17, "1079 → 85% 档（分界下侧）")


func test_font_size_responsive_boundary_exact_720_scaled() -> void:
	# 720 与 719 的档位分界（>=720 缩放档）
	assert_eq(FontMod.font_size_responsive(20, 720), 17, "恰好 720 → 85% 档")
	assert_eq(FontMod.font_size_responsive(20, 719), 12, "719 → 保底 12（分界下侧）")
