extends "res://tests/integration/tribulation/tribulation_reward_fixture.gd"
## 渡劫金卡奖励——降级路径（GDD §未决问题 2 的数据缺口，不是实现缺陷）。[br]
## [br][b]覆盖[/b]：模板池里没有金档 / CardSystem 整个取不到时——不抛错、不 push_error、
## 给出中文「未发放」原因，且渡劫本身照常成功（进境不受影响）。[br]
## [br][b]为什么把降级单列一个文件[/b]：这组用例测的是「数据不全时的行为」，
## 与 [code]test_tribulation_rewards.gd[/code] 的「正常口径」是两件事；
## 混在一起会让后者读起来像在夹带边界。[br]
## [br]来源: design/gdd/tribulation-system.md §6 + §未决问题 2、
## ADR-0021 §_handle_tribulation_success、先例 combat_reward_roller 的 cards_failed 口径。


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 池子里一张金档都没有
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_gold_pool_reports_chinese_reason_without_crashing() -> void:
	# Arrange——把夹具里的金档全摘掉（只剩白/暗金）
	cs.templates.erase(GOLD_A)
	cs.templates.erase(GOLD_B)
	_enter_combat()
	# Act
	var report: Dictionary = ts.call("_handle_tribulation_success")
	# Assert——不崩、有中文原因、没有到手卡
	assert_eq((report[PoolScript.KEY_CARDS] as Array).size(), 0, "池空时不应有到手卡")
	var failed: Array = report[PoolScript.KEY_FAILED]
	assert_eq(failed.size(), 1, "池空应记一条未发放")
	assert_false(str(failed[0].get("reason", "")).is_empty(), "未发放必须带原因")
	assert_string_contains(str(failed[0].get("reason")), "金档",
			"原因应说明是池子里没有金档：%s" % str(failed[0].get("reason")))


func test_empty_gold_pool_still_levels_realm() -> void:
	# Arrange
	cs.templates.erase(GOLD_A)
	cs.templates.erase(GOLD_B)
	_enter_combat()
	# Act
	ts.call("_handle_tribulation_success")
	# Assert——发不出金卡不影响进境（奖励缺口不是结算失败）
	assert_eq(_realm(), 2, "发不出金卡不影响进境")


func test_empty_gold_pool_does_not_grant_white_or_dark_gold() -> void:
	# Arrange——池里只剩白档与暗金（两者都不该被顺手发出去）
	cs.templates.erase(GOLD_A)
	cs.templates.erase(GOLD_B)
	var before: int = _owned_count()
	_enter_combat()
	# Act
	ts.call("_handle_tribulation_success")
	# Assert
	assert_eq(_owned_count(), before, "没有金档时不得降级发白卡或暗金")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. CardSystem 缺席 / 半个系统
# ═══════════════════════════════════════════════════════════════════════════════

func test_missing_card_system_degrades_with_reason() -> void:
	# Arrange——注入一个没有 templates 字段的替身（模拟系统缺席 / 半个系统）
	var stub: Node = Node.new()
	ts.set("_card_override", stub)
	_enter_combat()
	# Act
	var report: Dictionary = ts.call("_handle_tribulation_success")
	# Assert
	assert_eq((report[PoolScript.KEY_CARDS] as Array).size(), 0, "无模板注册表时无到手卡")
	assert_eq((report[PoolScript.KEY_FAILED] as Array).size(), 1, "应记一条未发放")
	assert_eq(_realm(), 2, "系统缺席不影响进境")
	stub.free()


func test_null_card_system_degrades_with_reason() -> void:
	# Arrange——覆盖引用置空（走 Autoload 查找；查不到即 null）
	var before: int = _owned_count()
	ts.set("_card_override", null)
	_enter_combat()
	# Act
	var report: Dictionary = ts.call("_handle_tribulation_success")
	# Assert——报告仍成形（两键恒在），渡劫照样进境
	assert_true(report.has(PoolScript.KEY_CARDS), "无系统时报告仍应有 cards 键")
	assert_true(report.has(PoolScript.KEY_FAILED), "无系统时报告仍应有 cards_failed 键")
	assert_eq(_realm(), 2, "无系统不影响进境")
	# 收藏可能被发过（Autoload 里真有 CardSystem 时按真池发）——只断言不重复
	assert_true(_owned_count() >= before, "收藏张数不应因降级而减少")


func test_report_always_carries_both_keys() -> void:
	# Arrange——空池与正常两条路都要给得出两个键（消费方无需判 null）
	cs.templates.erase(GOLD_A)
	cs.templates.erase(GOLD_B)
	_enter_combat()
	# Act
	var report: Dictionary = ts.call("_handle_tribulation_success")
	# Assert
	assert_true(report.has(PoolScript.KEY_CARDS), "报告应有 cards 键")
	assert_true(report.has(PoolScript.KEY_FAILED), "报告应有 cards_failed 键")
	assert_true(report[PoolScript.KEY_CARDS] is Array, "cards 应为数组")
	assert_true(report[PoolScript.KEY_FAILED] is Array, "cards_failed 应为数组")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 越阶渡劫在空池下同样只记一条未发放
# ═══════════════════════════════════════════════════════════════════════════════

func test_cross_realm_empty_pool_records_single_failed_entry() -> void:
	# Arrange——越阶要发 2 张，池空时是「一个名目一张都发不出」，
	# 记成两条重复条目会让结算屏写两遍同一句话
	cs.templates.erase(GOLD_A)
	cs.templates.erase(GOLD_B)
	_enter_combat(true)
	# Act
	var report: Dictionary = ts.call("_handle_tribulation_success")
	# Assert
	assert_eq((report[PoolScript.KEY_FAILED] as Array).size(), 1,
			"池空是一个名目（渡劫金卡），应只记一条")
	assert_eq(_realm(), 2, "越阶渡劫在空池下照样进境")
