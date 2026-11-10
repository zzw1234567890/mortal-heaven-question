extends GutTest
## 出牌结果与拒绝原因（combat-ui-interaction 001）。[br]
## [br][b]背景[/b]：`play_card()` 此前只返回 bool——「费用不足」与「阶段不对」
## 在调用方看来完全一样，UI 无从给提示，玩家点了没反应只能猜。[br]
## [br][b]本文件锁定三条语义[/b]：[br]
##   1. 结果字典形状稳定（ok / reason / message / context 恒在）；[br]
##   2. 费用不足的提示文本[b]含具体数字[/b]（需要多少 / 当前多少）；[br]
##   3. 未知原因返回[b]空串[/b]（不臆造文案——调用方以空串判定「无提示」）。[br]
## [br]纯函数——零依赖。

const PlayResult := preload("res://src/feature/combat/combat_play_result.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 结果形状
# ═══════════════════════════════════════════════════════════════════════════════

## 成功结果——ok=true、reason 为 OK 哨兵、四个标准键齐备。
func test_ok_result_shape() -> void:
	# Act
	var out: Dictionary = PlayResult.ok({"cost": 3})
	# Assert
	assert_true(out["ok"], "ok 为 true")
	assert_eq(out["reason"], PlayResult.REASON_OK, "reason 为成功哨兵")
	assert_true(out.has("message") and out.has("context"), "message / context 键存在")
	assert_eq(int(out["cost"]), 3, "附加字段被带出")


## 失败结果——ok=false、message 由原因生成、context 原样带出。
func test_fail_result_shape() -> void:
	# Act
	var out: Dictionary = PlayResult.fail(PlayResult.REASON_BAD_TARGET,
			{"targets": [101]})
	# Assert
	assert_false(out["ok"], "ok 为 false")
	assert_eq(out["reason"], PlayResult.REASON_BAD_TARGET, "原因原样")
	assert_eq(out["context"], {"targets": [101]}, "上下文原样带出")
	assert_false(String(out["message"]).is_empty(), "失败必带提示文本")


## 附加字段[b]不覆盖[/b]三个标准键——防下游把 ok 改成 false 却仍报成功。
func test_extra_cannot_override_standard_keys() -> void:
	# Act——恶意/失误地传 ok=false
	var out: Dictionary = PlayResult.ok({"ok": false, "reason": &"hacked"})
	# Assert
	assert_true(out["ok"], "标准键不被附加字段覆盖")
	assert_eq(out["reason"], PlayResult.REASON_OK, "reason 也不被覆盖")


## is_ok 对非字典输入返回 false（防崩——调用方可能是宽松载荷）。
func test_is_ok_tolerates_non_dictionary() -> void:
	# Assert
	assert_true(PlayResult.is_ok(PlayResult.ok()), "成功结果为 true")
	assert_false(PlayResult.is_ok(null), "null → false")
	assert_false(PlayResult.is_ok(true), "bool → false")
	assert_false(PlayResult.is_ok({}), "空字典 → false")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 费用不足的提示文本（本轮要求的重点）
# ═══════════════════════════════════════════════════════════════════════════════

## 费用不足 → 提示含「需要多少 / 当前多少」两个数字。[br]
## [br][b]为什么要求含数字[/b]：只说「灵力不足」玩家不知道差多少，还得自己心算；
## 文案由本模块集中生成，UI 只显示不拼串（避免同一原因多处不同措辞）。
func test_cost_message_contains_both_numbers() -> void:
	# Act
	var out: Dictionary = PlayResult.fail(PlayResult.REASON_COST_NOT_ENOUGH,
			{"cost": 5, "current": 2})
	# Assert
	var msg: String = String(out["message"])
	assert_true(msg.contains("5"), "提示含所需费用")
	assert_true(msg.contains("2"), "提示含当前费用")
	assert_false(msg.is_empty(), "非空提示")


## 费用不足但未给数字 → 不崩（回退 0）。
func test_cost_message_without_context_does_not_crash() -> void:
	# Act
	var out: Dictionary = PlayResult.fail(PlayResult.REASON_COST_NOT_ENOUGH)
	# Assert
	assert_false(String(out["message"]).is_empty(), "仍给出可显示的文本")


## 每种已知原因都有非空文案。
func test_every_known_reason_has_message() -> void:
	# Arrange
	var reasons: Array = [
		PlayResult.REASON_WRONG_PHASE,
		PlayResult.REASON_CARD_NOT_FOUND,
		PlayResult.REASON_COST_NOT_ENOUGH,
		PlayResult.REASON_BAD_TARGET,
		PlayResult.REASON_NO_COMBAT,
		PlayResult.REASON_SYSTEM_REJECTED,
	]
	# Assert
	for reason: StringName in reasons:
		assert_false(PlayResult.message_for(reason).is_empty(),
				"原因 %s 应有提示文本" % reason)


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 未知原因：不臆造文案
# ═══════════════════════════════════════════════════════════════════════════════

## 未知原因 → 空串（调用方以空串判定「无提示可显示」）。[br]
## [br][b]为什么不回退成通用提示[/b]：通用兜底文案会把「我们没覆盖这个原因」
## 藏起来——显示一句没信息量的话比不显示更让人困惑。
func test_unknown_reason_yields_empty_message() -> void:
	# Assert
	assert_eq(PlayResult.message_for(&"totally_unknown"), "", "未知原因 → 空串")
	assert_eq(PlayResult.message_for(&""), "", "空原因 → 空串")


## 成功哨兵没有提示文本（成功不该弹提示）。
func test_ok_reason_has_no_message() -> void:
	# Assert
	assert_eq(PlayResult.message_for(PlayResult.REASON_OK), "", "成功不产生提示")
