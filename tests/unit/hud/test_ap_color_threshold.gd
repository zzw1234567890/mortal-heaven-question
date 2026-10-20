extends GutTest
## hud Story 006 Logic 内核单测：ApDisplayRules.get_ap_color_threshold 纯函数。
##
## 覆盖 QA Test Cases 的 AC-1（AP 颜色阈值判定——共享纯函数）全部规格与
## edge cases：0/5、1/5、3/5、5/5、max_val=0（防除零）、current>max_val
## （临时 AP 超上限的防御性处理）+ 分段格判定（story L51：分段判定并入
## 纯函数返回）。
##
## 纯函数直调——无需场景树与 Autoload。风格先例：
## tests/unit/hud/test_deck_count_state.gd（arrange/act/assert）。
##
## 阈值 provisional（≤20% 紧急 / ≤50% 警告 / >50% 正常——GDD 未定义，
## game-designer 签批后锁定，story AC 第 3 条）：本测试锁定当前 provisional
## 值的行为，签批后如数值变更须同步更新本测试与常量。

const RULES := preload("res://src/ui/shared/ap_display_rules.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：颜色阈值判定（QA 规格全值表——0/5、1/5、3/5、5/5）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hud_ap_color_zero_of_five_returns_critical() -> void:
	## AC-1: 0/5 → 比例 0.0 ≤ 20% 紧急阈值 → critical
	# Arrange + Act
	var state: Dictionary = RULES.get_ap_color_threshold(0, 5)
	# Assert
	assert_eq(state[&"color"], "critical", "0/5 比例 0% 应为 critical")


func test_hud_ap_color_one_of_five_returns_critical() -> void:
	## AC-1: 1/5 → 比例 0.2 恰等紧急阈值（≤20%）→ critical
	# Arrange + Act
	var state: Dictionary = RULES.get_ap_color_threshold(1, 5)
	# Assert
	assert_eq(state[&"color"], "critical", "1/5 比例恰 20% 应为 critical（≤ 含边界）")


func test_hud_ap_color_three_of_five_returns_warning() -> void:
	## AC-1: 3/5 → 比例 0.6 > 50% 警告阈值 → normal
	# Arrange + Act
	var state: Dictionary = RULES.get_ap_color_threshold(3, 5)
	# Assert
	assert_eq(state[&"color"], "normal", "3/5 比例 60% 应为 normal（>50%）")


func test_hud_ap_color_two_of_five_returns_warning() -> void:
	## AC-1 补充（警告段边界）: 2/5 → 比例 0.4 落入 (20%, 50%] 警告段 → warning
	# Arrange + Act
	var state: Dictionary = RULES.get_ap_color_threshold(2, 5)
	# Assert
	assert_eq(state[&"color"], "warning", "2/5 比例 40% 应为 warning")


func test_hud_ap_color_half_of_max_returns_warning() -> void:
	## AC-1 补充（警告段上边界）: 比例恰 50% → warning（≤50% 含边界）
	# Arrange + Act
	var state: Dictionary = RULES.get_ap_color_threshold(5, 10)
	# Assert
	assert_eq(state[&"color"], "warning", "5/10 比例恰 50% 应为 warning（≤ 含边界）")


func test_hud_ap_color_five_of_five_returns_normal() -> void:
	## AC-1: 5/5 → 满值比例 1.0 → normal
	# Arrange + Act
	var state: Dictionary = RULES.get_ap_color_threshold(5, 5)
	# Assert
	assert_eq(state[&"color"], "normal", "5/5 满值应为 normal")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1 edge cases：防除零 + 超上限防御
# ═══════════════════════════════════════════════════════════════════════════════

func test_hud_ap_color_max_zero_returns_critical_empty_segments() -> void:
	## AC-1 edge: max_val=0 防除零——不崩溃，返回 critical + 空分段 + ratio 0
	# Arrange + Act
	var state: Dictionary = RULES.get_ap_color_threshold(3, 0)
	# Assert
	assert_eq(state[&"color"], "critical", "max_val=0 应为 critical（保守态）")
	assert_eq(state[&"segments"], [], "max_val=0 分段应为空数组")
	assert_eq(state[&"ratio"], 0.0, "max_val=0 比例应为 0.0")


func test_hud_ap_color_negative_max_returns_critical() -> void:
	## AC-1 edge 补充: max_val<0 同防除零防御分支
	# Arrange + Act
	var state: Dictionary = RULES.get_ap_color_threshold(1, -1)
	# Assert
	assert_eq(state[&"color"], "critical", "max_val=-1 应为 critical（保守态）")


func test_hud_ap_color_current_over_max_clamps_to_normal() -> void:
	## AC-1 edge: current>max_val（临时 AP 超上限防御）——比例钳 1.0 判色
	## normal，分段全点亮且长度恒为 max_val（不为超上限渲染额外格）
	# Arrange + Act
	var state: Dictionary = RULES.get_ap_color_threshold(7, 5)
	# Assert
	assert_eq(state[&"color"], "normal", "7/5 超上限应钳比例 1.0 判 normal")
	assert_eq(state[&"ratio"], 1.0, "7/5 比例应钳为 1.0")
	assert_eq((state[&"segments"] as Array).size(), 5, "分段长度应恒为 max_val=5")
	assert_true((state[&"segments"] as Array).all(func(on: bool) -> bool: return on),
			"7/5 全部 5 格应点亮")


func test_hud_ap_color_negative_current_treated_as_zero() -> void:
	## AC-1 edge 补充: current<0 防御——按 0 处理（critical + 全熄灭）
	# Arrange + Act
	var state: Dictionary = RULES.get_ap_color_threshold(-2, 5)
	# Assert
	assert_eq(state[&"color"], "critical", "负 current 应按 0 处理为 critical")
	assert_false((state[&"segments"] as Array).has(true), "负 current 全部格子应熄灭")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1 附带：分段格判定（story L51——分段判定并入纯函数返回；AC-4 消费）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hud_ap_segments_three_of_five_first_three_on() -> void:
	## AC-4 判定源: 3/5 → 前 3 格点亮、后 2 格熄灭（每格 1 AP——QA AC-4 规格
	## 「5 格分段中 3 格点亮、2 格熄灭」的判定逻辑部分）
	# Arrange
	var expected: Array = [true, true, true, false, false]
	# Act
	var state: Dictionary = RULES.get_ap_color_threshold(3, 5)
	# Assert
	assert_eq(state[&"segments"], expected, "3/5 分段应为 [on,on,on,off,off]")


func test_hud_ap_segments_full_and_empty_extremes() -> void:
	## AC-4 判定源边界: 满值全点亮 / 零值全熄灭
	# Arrange + Act
	var full: Dictionary = RULES.get_ap_color_threshold(5, 5)
	var empty: Dictionary = RULES.get_ap_color_threshold(0, 5)
	# Assert
	assert_true((full[&"segments"] as Array).all(func(on: bool) -> bool: return on),
			"5/5 全部格子应点亮")
	assert_false((empty[&"segments"] as Array).has(true), "0/5 全部格子应熄灭")


func test_hud_ap_segments_length_equals_max() -> void:
	## AC-4 判定源: 分段长度恒等于 max_val（每格 1 AP）
	# Arrange
	var max_vals: Array = [1, 5, 10]
	# Act + Assert
	for m: int in max_vals:
		var state: Dictionary = RULES.get_ap_color_threshold(1, m)
		assert_eq((state[&"segments"] as Array).size(), m,
				"max_val=%d 分段长度应为 %d" % [m, m])
