extends "res://tests/unit/inventory/inventory_pill_use_fixture.gd"
## InventoryPillUse 单元测试（二）：拒绝路径与文案（本模块是这些句子的唯一来源）。[br]
## [br][b]装置见 [inventory_pill_use_fixture.gd][/b]；数值口径与消耗回滚的用例在
## [code]test_inventory_pill_use.gd[/code]（两个文件共用装置，各自回 300 行内）。[br]
##
## 覆盖本轮点名验收：② 「不是丹药的条目点了给中文提示」。
##
## 来源: 本轮任务书第 2 条、先例 [code]inventory_catalog.gd[/code]（文案单点）。

## 目录里那条「不能直接用」的提示（面板与结算层共用的唯一字符串）。
const CatalogScript := preload("res://src/feature/inventory/inventory_catalog.gd")


## 断言「这次调用什么也没动」——拒绝路径的公共检查（每条拒绝用例都该满足）。
func assert_untouched() -> void:
	assert_eq(hp.writes, 0, "被拒的调用不应写 HP")
	assert_eq(gsm.removals, [], "被拒的调用不应动收藏")


# ═══════════════════════════════════════════════════════════════════════════════
# 非丹药条目
# ═══════════════════════════════════════════════════════════════════════════════

func test_artifact_entry_is_refused_with_the_shared_message() -> void:
	## 法宝条目给统一的中文提示——文案取自分类表（面板与结算层同一个字符串）。
	# Arrange
	set_hp(101, 3, 10)
	# Act
	var result: Dictionary = use.use_entry(entry("artifact_x", [1], CARD_TYPE_ARTIFACT))
	# Assert
	assert_false(bool(result["ok"]), "法宝不能直接使用")
	assert_eq(str(result["message"]), CatalogScript.TEXT_NOT_A_PILL,
			"应给分类表里那条统一提示")
	assert_untouched()


func test_ling_cai_entry_is_refused_with_the_shared_message() -> void:
	## 灵材行（[code]card_type = -1[/code] 的非卡片哨兵）走同一条拒绝路径——
	## 一个 [code]card_type != PILL[/code] 判据覆盖灵材与卡片两条来源。
	# Arrange
	# Act
	var result: Dictionary = use.use_entry(entry("", [], CARD_TYPE_NONE))
	# Assert
	assert_false(bool(result["ok"]), "灵材不能直接使用")
	assert_eq(str(result["message"]), CatalogScript.TEXT_NOT_A_PILL,
			"提示应与法宝条目同一条")
	assert_untouched()


# ═══════════════════════════════════════════════════════════════════════════════
# 脏数据 / 缺依赖
# ═══════════════════════════════════════════════════════════════════════════════

func test_pill_entry_without_instance_ids_is_refused() -> void:
	## 脏存档（收藏条目缺 [code]card_instance_id[/code]）→ 没有可移除的对象，
	## 给中文原因而不是崩掉，也不白回一次血。
	# Arrange
	add_pill("p20", "玉灵丹", 8)
	set_hp(101, 3, 10)
	# Act
	var result: Dictionary = use.use_entry(entry("p20", []))
	# Assert
	assert_false(bool(result["ok"]), "无实例可移除时应拒绝")
	assert_false(str(result["message"]).strip_edges().is_empty(), "应给中文原因")
	assert_untouched()
	assert_eq(int(hp.table[101]["current_hp"]), 3, "血量不应变化")


func test_pill_entry_with_unknown_template_is_refused() -> void:
	## 模板查不到（ID 打错 / 卡牌系统还在异步加载）→ 拒绝，不臆造效果数值。
	# Arrange
	set_hp(101, 3, 10)
	# Act
	var result: Dictionary = use.use_entry(entry("no_such_pill", [201]))
	# Assert
	assert_false(bool(result["ok"]), "模板查不到时应拒绝")
	assert_false(str(result["message"]).strip_edges().is_empty(), "应给中文原因")
	assert_untouched()


func test_missing_hp_ledger_dependency_is_refused_not_crashed() -> void:
	## HP 账本读写口不可用（GSM 缺入口的降级形态）→ 拒绝并给出原因，
	## 不吞掉丹药也不崩。
	# Arrange
	add_pill("p21", "玉灵丹", 8)
	set_hp(101, 3, 10)
	hp.unavailable = true
	# Act
	var result: Dictionary = use.use_entry(entry("p21", [211]))
	# Assert
	assert_false(bool(result["ok"]), "写血不可用时应拒绝")
	assert_false(str(result["message"]).strip_edges().is_empty(), "应给中文原因")
	assert_eq(gsm.removals, [], "不应动收藏")


# ═══════════════════════════════════════════════════════════════════════════════
# 返回形状与重复调用
# ═══════════════════════════════════════════════════════════════════════════════

func test_result_always_carries_the_four_contract_keys() -> void:
	## 成功与失败都返回同一组四个键——面板不必先判有没有这个键（ADR-0006 的
	## 「契约形状固定」口径）。
	# Arrange
	add_pill("p22", "玉灵丹", 8)
	set_hp(101, 3, 10)
	gsm.removable = [221]
	# Act
	var ok_result: Dictionary = use.use_entry(entry("p22", [221]))
	var refused: Dictionary = use.use_entry(entry("p22", [221], CARD_TYPE_ARTIFACT))
	# Assert
	for result: Dictionary in [ok_result, refused]:
		for key: String in ["ok", "consumed", "healed", "message"]:
			assert_true(result.has(key), "结果应含键 '%s'" % key)


func test_second_use_of_the_same_entry_fails_cleanly() -> void:
	## 用完最后一枚之后再确认同一行（行控件还没刷新）：结算层按「实例已不在收藏里」
	## 拒绝，不重复回血——界面刷新前的那一瞬间不能成为白拿一次回血的窗口。
	# Arrange
	add_pill("p23", "玉灵丹", 8)
	set_hp(101, 3, 10)
	gsm.removable = [231]
	var stale: Dictionary = entry("p23", [231])
	# Act
	var first: Dictionary = use.use_entry(stale)
	var second: Dictionary = use.use_entry(stale)
	# Assert
	assert_true(bool(first["ok"]), "第一次应成功")
	assert_eq(int(hp.table[101]["current_hp"]), 10, "第一次应治到满血")
	assert_false(bool(second["ok"]), "第二次应失败（丹药已不在收藏里）")
	assert_eq(int(hp.table[101]["current_hp"]), 10, "第二次不应再加血")
