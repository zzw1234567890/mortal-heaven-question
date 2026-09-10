extends GutTest
## hud Story 003 Logic 内核单测：LingshiFormatter.format_lingshi 纯函数。
##
## 覆盖 QA Test Cases 的 AC-1（灵石 k 格式化）全部规格与 edge cases
## （story 2026-09-10 QL-STORY-READY G2 裁决修订版：10000+ 延续 k 格式）。
##
## 纯函数直调——无需场景树与 Autoload。风格先例：
## tests/unit/hud/test_cultivation_bar_state.gd（arrange/act/assert）。

const F := preload("res://src/ui/hud/lingshi_formatter.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：灵石 k 格式化（QA 规格 Then 全值表）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hud_lingshi_zero_returns_plain() -> void:
	## AC-1 edge: 0 → "0"（原数字，k 阈值之下）
	# Arrange + Act
	var text: String = F.format_lingshi(0)
	# Assert
	assert_eq(text, "0", "0 应显示为 \"0\"")


func test_hud_lingshi_small_values_return_plain() -> void:
	## AC-1: <1000 原数字（1、500、998 三点）
	# Arrange
	var cases: Array = [[1, "1"], [500, "500"], [998, "998"]]
	for c: Array in cases:
		# Act
		var text: String = F.format_lingshi(c[0])
		# Assert
		assert_eq(text, c[1], "%d 应显示为 \"%s\"" % [c[0], c[1]])


func test_hud_lingshi_999_returns_plain() -> void:
	## AC-1: 999 → "999"（k 阈值之下最大值）
	# Arrange + Act
	var text: String = F.format_lingshi(999)
	# Assert
	assert_eq(text, "999", "999 应显示为 \"999\"（阈值之下）")


func test_hud_lingshi_1000_returns_1_0k() -> void:
	## AC-1: 1000 → "1.0k"（k 阈值之上最小值——边界含 1000）
	# Arrange + Act
	var text: String = F.format_lingshi(1000)
	# Assert
	assert_eq(text, "1.0k", "1000 应显示为 \"1.0k\"（阈值含 1000）")


func test_hud_lingshi_1250_returns_1_2k() -> void:
	## AC-1: 1250 → "1.2k"（QA 规格原值——GDD §3 示例）
	# Arrange + Act
	var text: String = F.format_lingshi(1250)
	# Assert
	assert_eq(text, "1.2k", "1250 应显示为 \"1.2k\"")


func test_hud_lingshi_1255_truncates_to_1_2k() -> void:
	## AC-1 补充: 一位小数向下截断——1255 → "1.2k"（不进位；QA 规格
	## 9999→9.9k 锁定截断语义，浮点 %.1f 会因二进制近似误差误截）
	# Arrange + Act
	var text: String = F.format_lingshi(1255)
	# Assert
	assert_eq(text, "1.2k", "1255 应截断为 \"1.2k\"")


func test_hud_lingshi_9999_returns_9_9k() -> void:
	## AC-1: 9999 → "9.9k"（四位之内最大值——与 10000 衔接点）
	# Arrange + Act
	var text: String = F.format_lingshi(9999)
	# Assert
	assert_eq(text, "9.9k", "9999 应显示为 \"9.9k\"")


func test_hud_lingshi_10000_returns_10_0k() -> void:
	## AC-1（G2 裁决 2026-09-10）: 10000 → "10.0k"——延续 k 格式，
	## 不引入万单位（关闭 GDD L237 待澄清项）
	# Arrange + Act
	var text: String = F.format_lingshi(10000)
	# Assert
	assert_eq(text, "10.0k", "10000 应显示为 \"10.0k\"（G2 裁决延续 k 格式）")


func test_hud_lingshi_12500_returns_12_5k() -> void:
	## AC-1（G2 裁决）: 12500 → "12.5k"
	# Arrange + Act
	var text: String = F.format_lingshi(12500)
	# Assert
	assert_eq(text, "12.5k", "12500 应显示为 \"12.5k\"")


func test_hud_lingshi_large_value_keeps_k_format() -> void:
	## AC-1（G2 裁决补充）: 大额延续 k 格式——999999 → "999.9k"
	## （截断语义全范围一致：999999/1000=999.999 向下截断一位小数 = 999.9k，
	## 与 9999→9.9k 同理；无上限切换点，不引入 M/万单位）
	# Arrange + Act
	var text: String = F.format_lingshi(999999)
	# Assert
	assert_eq(text, "999.9k", "999999 应显示为 \"999.9k\"（k 格式无上限切换）")


func test_hud_lingshi_negative_returns_raw_number() -> void:
	## AC-1 edge: 负数防御性处理——按原数字返回（GSM 写入侧已有 maxi(0, value)
	## 非负守卫，正常数据流不产生负值；此处防御性直显使异常数据可见而非被
	## 静默钳 0 吞掉——行为由本单测锁定）
	# Arrange
	var cases: Array = [[-1, "-1"], [-999, "-999"], [-1250, "-1250"]]
	for c: Array in cases:
		# Act
		var text: String = F.format_lingshi(c[0])
		# Assert
		assert_eq(text, c[1], "%d 应防御性直显为 \"%s\"" % [c[0], c[1]])
