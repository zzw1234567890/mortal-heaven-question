extends GutTest
## hud Story 003 Logic 内核单测：LingshiFormatter.get_deck_count_state 纯函数。
##
## 覆盖 QA Test Cases 的 AC-2（卡组计数状态判定）全部规格与 edge cases
## （story 2026-09-10 QL-STORY-READY G3 裁决：cap<=0 防御分支）。
##
## 纯函数直调——无需场景树与 Autoload。风格先例：
## tests/unit/hud/test_cultivation_bar_state.gd（arrange/act/assert）。

const F := preload("res://src/ui/hud/lingshi_formatter.gd")

# ═══════════════════════════════════════════════════════════════════════════════
# AC-2：卡组计数三态判定（QA 规格 Then 全值表）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hud_deck_count_below_cap_returns_normal() -> void:
	## AC-2: count<cap → color "normal"（0/20、28/30 两点——GDD 边界情况：
	## 未获得卡牌时 0/20 正常显示不触发异常）
	# Arrange
	var cases: Array = [[0, 20], [28, 30]]
	for c: Array in cases:
		# Act
		var state: Dictionary = F.get_deck_count_state(c[0], c[1])
		# Assert
		assert_eq(state[&"color"], "normal",
				"%d/%d 应为 normal" % [c[0], c[1]])
		assert_false(state[&"flashing"],
				"%d/%d 不应闪烁" % [c[0], c[1]])
		assert_false(state[&"overlimit"],
				"%d/%d 不应超限标记" % [c[0], c[1]])


func test_hud_deck_count_zero_over_twenty_label_format() -> void:
	## AC-2 edge: 0/20 → label "0/20"（GDD 边界情况——未获得卡牌正常显示）
	# Arrange + Act
	var state: Dictionary = F.get_deck_count_state(0, 20)
	# Assert
	assert_eq(state[&"label"], "0/20", "0/20 label 应为 \"0/20\"")


func test_hud_deck_count_mid_value_label_format() -> void:
	## AC-2: 28/30 → label "28/30"
	# Arrange + Act
	var state: Dictionary = F.get_deck_count_state(28, 30)
	# Assert
	assert_eq(state[&"label"], "28/30", "28/30 label 应为 \"28/30\"")


func test_hud_deck_count_equal_cap_returns_yellow() -> void:
	## AC-2: count==cap → "yellow"（达上限——30/30）
	# Arrange + Act
	var state: Dictionary = F.get_deck_count_state(30, 30)
	# Assert
	assert_eq(state[&"color"], "yellow", "30/30 达上限应为 yellow")
	assert_false(state[&"flashing"], "30/30 达上限不应闪烁")
	assert_false(state[&"overlimit"], "30/30 达上限不应超限标记")
	assert_eq(state[&"label"], "30/30", "30/30 label 应为 \"30/30\"")


func test_hud_deck_count_over_cap_returns_red_flashing_overlimit() -> void:
	## AC-2: count>cap → "red"+flashing+overlimit（超限——32/30）
	# Arrange + Act
	var state: Dictionary = F.get_deck_count_state(32, 30)
	# Assert
	assert_eq(state[&"color"], "red", "32/30 超限应为 red")
	assert_true(state[&"flashing"], "32/30 超限应闪烁")
	assert_true(state[&"overlimit"], "32/30 超限应显示超限标记")
	assert_eq(state[&"label"], "32/30", "32/30 label 应为 \"32/30\"")


func test_hud_deck_count_over_cap_one_card() -> void:
	## AC-2 edge: 超限最小越界——31/30 → red+flashing+overlimit
	# Arrange + Act
	var state: Dictionary = F.get_deck_count_state(31, 30)
	# Assert
	assert_eq(state[&"color"], "red", "31/30 应为 red")
	assert_true(state[&"flashing"], "31/30 应闪烁")
	assert_true(state[&"overlimit"], "31/30 应超限标记")


# ═══════════════════════════════════════════════════════════════════════════════
# AC-2 edge：cap<=0 防御分支（G3 裁决 2026-09-10）
# ═══════════════════════════════════════════════════════════════════════════════

func test_hud_deck_count_cap_zero_returns_normal_not_yellow() -> void:
	## AC-2 edge（G3 裁决）: cap=0 → 防御返回 normal——count==cap==0 不得落入
	## yellow（系统 get_deck_limit() 最低返回 20，此分支不可达，单测仅防御性
	## 锁定行为）
	# Arrange + Act
	var state: Dictionary = F.get_deck_count_state(0, 0)
	# Assert
	assert_eq(state[&"color"], "normal", "0/0 防御分支应为 normal（不入 yellow）")
	assert_false(state[&"flashing"], "0/0 不应闪烁")
	assert_false(state[&"overlimit"], "0/0 不应超限标记")


func test_hud_deck_count_cap_negative_returns_normal() -> void:
	## AC-2 edge（G3 裁决）: cap<0 → 同防御返回 normal（含 count>cap 形式上
	## 成立的 5/-1——防御分支优先于超限判定）
	# Arrange
	var cases: Array = [[0, -1], [5, -1]]
	for c: Array in cases:
		# Act
		var state: Dictionary = F.get_deck_count_state(c[0], c[1])
		# Assert
		assert_eq(state[&"color"], "normal",
				"%d/%d 防御分支应为 normal" % [c[0], c[1]])
		assert_false(state[&"flashing"], "%d/%d 不应闪烁" % [c[0], c[1]])
		assert_false(state[&"overlimit"], "%d/%d 不应超限标记" % [c[0], c[1]])


func test_hud_deck_count_cap_zero_with_cards_returns_normal() -> void:
	## AC-2 edge（G3 裁决补充）: cap=0 且 count>0（3/0）→ 防御 normal——
	## 不因形式上 count>cap 落入 red（DeckEditingSystem 不可用时 UI 兜底显示，
	## 不触发超限警报）
	# Arrange + Act
	var state: Dictionary = F.get_deck_count_state(3, 0)
	# Assert
	assert_eq(state[&"color"], "normal", "3/0 防御分支应为 normal（不入 red）")
	assert_false(state[&"flashing"], "3/0 不应闪烁")
	assert_false(state[&"overlimit"], "3/0 不应超限标记")
	assert_eq(state[&"label"], "3/0", "3/0 label 应为 \"3/0\"")
