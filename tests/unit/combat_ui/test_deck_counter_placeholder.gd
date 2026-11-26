extends GutTest
## DEBT-CUI-010 单测：DeckCounter 的「未接线占位」与「有数据渲染」两态。[br]
## [br][b]为什么需要这两态[/b]：计数组件此前把 [_deck_count] 默认成 0 并直接渲染
## 成「≡牌库:0」——牌库系统还没接线时，玩家看到的是一个[b]假数字[/b]，与
## 「确实一张牌都没有」在屏幕上长得一模一样。本文件钉住：没有数据源时显示 `-`，
## 真来了数（哪怕就是 0）才显示数字。[br]
## [br]Story 类型 UI（Logic 内核）——此文件为 BLOCKING 证据。
## 风格先例：tests/integration/combat_ui/test_cost_display.gd。

const CounterScript := preload("res://src/ui/combat/layout/deck_counter.gd")

var counter: Control = null


func before_each() -> void:
	counter = CounterScript.new()
	add_child_autofree(counter)


# ═══════════════════════════════════════════════════════════════════════════════
# 未接线态：不许假装 0
# ═══════════════════════════════════════════════════════════════════════════════

func test_placeholder_before_any_data() -> void:
	# Then: 从未推过数据时，两个数字位都是占位符而不是 0
	assert_eq(counter.get_deck_text(), "≡牌库:-", "未接线时牌库位应为占位符")
	assert_eq(counter.get_discard_text(), "弃:-", "未接线时弃牌位应为占位符")


func test_placeholder_survives_zero_like_defaults() -> void:
	# When: 反复读取（不给数据）
	counter.get_deck_text()
	counter.get_deck_text()
	# Then: 仍然是占位符——默认值不得被渲染成数字
	assert_eq(counter.get_deck_text(), "≡牌库:-", "多次读取不应把默认值渲染成 0")
	assert_eq(counter.get_discard_count(), 0, "查询口仍返回 0（占位只影响文本）")


# ═══════════════════════════════════════════════════════════════════════════════
# 有数据态：按数渲染
# ═══════════════════════════════════════════════════════════════════════════════

func test_counts_rendered_after_data() -> void:
	# When: 推入真实计数
	counter.set_deck_counts(12, 3)
	# Then: 文本与查询口一致
	assert_eq(counter.get_deck_text(), "≡牌库:12", "牌库文本应 12")
	assert_eq(counter.get_discard_text(), "弃:3", "弃牌文本应 3")
	assert_eq(counter.get_deck_count(), 12, "牌库查询口应 12")
	assert_eq(counter.get_discard_count(), 3, "弃牌查询口应 3")


func test_real_zero_renders_as_zero_not_placeholder() -> void:
	# When: 真实计数就是 0（牌库抽空）
	counter.set_deck_counts(0, 0)
	# Then: 显示 0——「确实是 0」与「还不知道」在屏幕上是两回事
	assert_eq(counter.get_deck_text(), "≡牌库:0", "真实 0 张应显示 0")
	assert_eq(counter.get_discard_text(), "弃:0", "真实 0 张应显示 0")


func test_negative_counts_clamped() -> void:
	# When: 负值防御性钳制（计数不可能为负）
	counter.set_deck_counts(-1, -5)
	# Then: 钳制为 0
	assert_eq(counter.get_deck_count(), 0, "负牌库应钳制为 0")
	assert_eq(counter.get_discard_count(), 0, "负弃牌应钳制为 0")
	assert_eq(counter.get_deck_text(), "≡牌库:0", "钳制后应渲染 0")
	assert_eq(counter.get_discard_text(), "弃:0", "钳制后应渲染 0")


func test_later_push_overwrites_earlier() -> void:
	# When: 连续两次推数
	counter.set_deck_counts(7, 0)
	counter.set_deck_counts(5, 2)
	# Then: 终值生效（渲染快照——只持展示值，无累加）
	assert_eq(counter.get_deck_text(), "≡牌库:5", "后一次推数应覆盖前一次")
	assert_eq(counter.get_discard_text(), "弃:2", "后一次推数应覆盖前一次")
