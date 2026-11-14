extends "res://tests/unit/exploration_system/breakthrough_fixture.gd"
## 打坐/洞府境界突破 —— 成功扣费升境界、修为不足拒绝、失败按配置扣费不升境界、
## 修为不落负、同种子同结果。[br]
## [br][b]覆盖[/b]（逐条对应本轮点名的五条验收）：[br]
##   · [b]成功[/b]：扣掉配置要求的修为 + 境界 +1 + 属性快照按[b]境界配置表[/b]重算
##     （[code]max_deploy[/code] / [code]deck_limit[/code] / …），且 GSM 里的
##     [code]player.realm[/code] 真的变了（落盘域）；[br]
##   · [b]修为不足[/b]：拒绝且[b]不改任何状态[/b]，且 [code]rolled=false[/code]
##     （证明连骰子都没掷）；[br]
##   · [b]失败[/b]：按配置扣一部分修为、境界不变；[br]
##   · [b]修为不为负[/b]：惩罚大于持有量时夹到 0，提示里的损失量是[b]真实[/b]损失；[br]
##   · [b]同种子同结果[/b]：同一颗种子 + 同一初始状态 → 逐键相同的结果。[br]
## [br][b]装置[/b]在 [code]breakthrough_fixture.gd[/code]（GSM 快照还原 + 种子扫描），
## 数值全部从配置读出——用例里不写死 1000 / 0.10 这类字面量。[br]
## [br]端到端（面板点击 → 转发 → 结算）见
## [code]tests/integration/exploration_ui/test_meditation_node_flow.gd[/code]。
##
## 来源: design/gdd/cultivation-system.md §4/§6/§边界/§调优参数、
## docs/decisions/ADR-0010 §realm_up 编排器、
## 先例 [code]test_exploration_harvest.gd[/code] / [code]test_exploration_craft.gd[/code]。


# ═══════════════════════════════════════════════════════════════════════════════
# 验收 1：成功——扣费 + 升境界 + 属性按配置变化
# ═══════════════════════════════════════════════════════════════════════════════

func test_success_deducts_required_cultivation_and_raises_realm() -> void:
	# Arrange——修为恰好够（扣完归零），种子挑一颗必成的
	_inject_success_seed(REALM_QI)
	# Act
	var result: Dictionary = service.call(&"attempt")
	# Assert——扣费
	assert_true(bool(result["success"]), "种子已确保掷中，突破应成功")
	assert_true(bool(result["rolled"]), "成功路径一定掷过骰")
	assert_eq(int(result["spent"]), required, "消耗应等于配置要求的修为")
	assert_eq(int(result["cultivation_before"]), required, "扣前为满仓")
	assert_eq(int(result["cultivation_after"]), 0, "扣掉全部所需修为")
	assert_eq(int(result["penalty"]), 0, "成功路径没有惩罚")
	assert_true(str(result["message"]).begins_with("突破成功"),
			"提示应为中文成功文案：%s" % result["message"])


func test_success_raises_realm_and_persists_into_game_state() -> void:
	# Arrange
	_inject_success_seed(REALM_QI)
	# Act
	var result: Dictionary = service.call(&"attempt")
	# Assert——境界真的写进了 GSM（player 属落盘域）
	assert_eq(int(result["realm_before"]), REALM_QI, "起手为炼气期")
	assert_eq(int(result["realm_after"]), REALM_QI + 1, "成功后境界 +1")
	assert_eq(int(GameStateManager.player.realm), REALM_QI + 1,
			"境界应写进 GSM.player（随 serialize 落盘）")
	assert_eq(int(GameStateManager.player.cultivation), 0,
			"修为扣减应写进 GSM.player")
	assert_eq(str(result["message"]),
			TableScript.TEXT_SUCCESS % [TableScript.realm_name(REALM_QI),
					TableScript.realm_name(REALM_QI + 1), required],
			"成功提示里的境界名与实际消耗应取自配置")


func test_success_attributes_come_from_realm_config_table() -> void:
	# Arrange
	_inject_success_seed(REALM_QI)
	var before_attrs: Dictionary = service.call(&"attributes_of", REALM_QI)
	# Act
	var result: Dictionary = service.call(&"attempt")
	var attrs: Dictionary = result["attributes"]
	# Assert——逐键等于既有境界配置表的查询值（不是本模块推算出来的）
	for key: String in BreakthroughScript.ATTRIBUTE_KEYS:
		assert_eq(attrs.get(key), RealmScript.realm_table[REALM_QI + 1].get(key),
				"属性 %s 应取自境界配置表的新境界行" % key)
	var gained: int = int(attrs.get("max_deploy", 0)) \
			- int(before_attrs.get("max_deploy", 0))
	assert_true(gained > 0, "出战上限应随境界提升而提高（实得 +%d）" % gained)
	assert_ne(int(attrs.get("deck_limit", 0)), int(before_attrs.get("deck_limit", 0)),
			"卡组上限应随境界提升而改变")


# ═══════════════════════════════════════════════════════════════════════════════
# 验收 2：修为不足——拒绝且状态不变
# ═══════════════════════════════════════════════════════════════════════════════

func test_insufficient_cultivation_is_rejected_without_state_change() -> void:
	# Arrange——差一点
	_reset_player(REALM_QI, required - 1)
	# Act——不注入种子：被拒路径连骰子都不该掷
	var result: Dictionary = service.call(&"attempt")
	# Assert
	assert_false(bool(result["success"]), "修为不足时不得突破")
	assert_eq(str(result["reason"]), "not_enough", "拒绝原因应为 not_enough")
	assert_false(bool(result["rolled"]), "被拒路径不得掷骰（rolled=false）")
	assert_eq(str(result["message"]),
			TableScript.TEXT_NOT_ENOUGH % [required - 1, required],
			"提示应写清当前与所需修为")
	assert_eq(int(GameStateManager.player.cultivation), required - 1,
			"被拒时修为不得变化")
	assert_eq(int(GameStateManager.player.realm), REALM_QI, "被拒时境界不得变化")
	assert_eq(int(result["cultivation_after"]), required - 1, "返回值里的扣后修为不变")
	assert_eq(int(result["spent"]), 0, "被拒时不得记为消耗")


func test_at_max_realm_is_rejected_without_state_change() -> void:
	# Arrange——顶上境界（配置表条目数）
	var top: int = TableScript.max_realm()
	_reset_player(top, TableScript.required_cultivation(top - 1))
	var realm_before: int = int(GameStateManager.player.realm)
	# Act
	var result: Dictionary = service.call(&"attempt")
	# Assert
	assert_false(bool(result["success"]), "最高境界不得再突破")
	assert_eq(str(result["reason"]), "at_max", "拒绝原因应为 at_max")
	assert_false(bool(result["rolled"]), "被拒路径不得掷骰")
	assert_eq(str(result["message"]), TableScript.TEXT_AT_MAX, "提示应为已达最高境界")
	assert_eq(int(GameStateManager.player.realm), realm_before, "境界不得变化")


# ═══════════════════════════════════════════════════════════════════════════════
# 验收 3：失败——按配置扣修为且不升境界
# ═══════════════════════════════════════════════════════════════════════════════

func test_failure_deducts_configured_penalty_and_keeps_realm() -> void:
	# Arrange
	_inject_failure_seed(REALM_QI)
	var expected_penalty: int = TableScript.penalty_for(REALM_QI, required)
	# Act
	var result: Dictionary = service.call(&"attempt")
	# Assert——扣了配置量、境界原地不动
	assert_false(bool(result["success"]), "种子已确保掷空，突破应失败")
	assert_true(bool(result["rolled"]), "失败路径是掷过骰的（与「被拒」区分）")
	assert_eq(str(result["reason"]), "roll_failed", "原因应为掷骰失败")
	assert_eq(int(result["penalty"]), expected_penalty, "惩罚应等于配置算出的量")
	assert_eq(int(result["cultivation_after"]), required - expected_penalty,
			"应按惩罚扣修为")
	assert_eq(int(GameStateManager.player.cultivation), required - expected_penalty,
			"扣减应写进 GSM.player")
	assert_eq(int(result["realm_after"]), REALM_QI, "失败不得升境界")
	assert_eq(int(GameStateManager.player.realm), REALM_QI, "GSM 里境界也不得变")
	assert_eq(int(result["spent"]), 0, "失败不计消耗（那是惩罚，不是花费）")


func test_failure_message_states_the_actual_loss() -> void:
	# Arrange
	_inject_failure_seed(REALM_QI)
	# Act
	var result: Dictionary = service.call(&"attempt")
	var lost: int = required - int(result["cultivation_after"])
	# Assert——提示里的损失量与前后值都与实际一致
	assert_true(str(result["message"]).begins_with("突破失败"), "提示应为中文失败文案")
	assert_true(str(result["message"]).contains(str(lost)),
			"提示应写清损失量 %d：%s" % [lost, result["message"]])
	assert_true(str(result["message"]).contains("境界不变"),
			"提示应说明境界不变：%s" % result["message"])


func test_can_retry_after_failure_when_cultivation_still_sufficient() -> void:
	# Arrange——先失败一次
	_inject_failure_seed(REALM_QI)
	service.call(&"attempt")
	var after_failure: int = int(GameStateManager.player.cultivation)
	assert_true(after_failure < required, "失败后应已跌破所需修为（本用例前提）")
	# Act——补满后再冲一次（成功种子）
	_reset_player(REALM_QI, required)
	_inject_success_seed(REALM_QI)
	var result: Dictionary = service.call(&"attempt")
	# Assert——失败不是「一次性机会」：修为够就能再来
	assert_true(bool(result["success"]), "补满修为后应可再次尝试并成功")
	assert_eq(int(GameStateManager.player.realm), REALM_QI + 1, "这次真的升境界了")


# ═══════════════════════════════════════════════════════════════════════════════
# 验收 4：修为不会被扣成负数
# ═══════════════════════════════════════════════════════════════════════════════

func test_penalty_larger_than_holdings_clamps_cultivation_at_zero() -> void:
	# Arrange——修为上限被撑到远大于持有量，惩罚（按上限算）超过持有量
	var realm: int = REALM_QI + 1
	var holdings: int = TableScript.required_cultivation(realm)
	var huge_max: int = holdings * 100
	_reset_player(realm, holdings, huge_max)
	assert_true(TableScript.penalty_for(realm, huge_max) > holdings,
			"本用例前提：惩罚大于持有量")
	_inject_failure_seed(realm)
	# Act
	var result: Dictionary = service.call(&"attempt")
	# Assert——夹到 0，且提示里的「损失」是真实损失而非算出来的惩罚
	assert_eq(int(result["cultivation_after"]), 0, "修为应夹在 0，不得为负")
	assert_eq(int(GameStateManager.player.cultivation), 0, "GSM 里也不得为负")
	assert_true(int(result["penalty"]) > holdings, "惩罚本身仍按配置算出（大于持有量）")
	assert_true(str(result["message"]).contains("%d → 0" % holdings),
			"提示里的损失应为真实损失 %d → 0：%s" % [holdings, result["message"]])


func test_success_path_never_leaves_negative_cultivation() -> void:
	# Arrange——修为恰好等于所需（扣完为 0，不是负数）
	_inject_success_seed(REALM_QI)
	# Act
	var result: Dictionary = service.call(&"attempt")
	# Assert
	assert_true(int(result["cultivation_after"]) >= 0, "成功路径扣后不得为负")
	assert_true(int(GameStateManager.player.cultivation) >= 0, "GSM 里也不得为负")


func test_status_never_reports_negative_penalty() -> void:
	# Arrange——异常存档值（理论上不该出现，读取面必须不崩且不传染）
	_reset_player(REALM_QI, -50)
	# Act
	var status: Dictionary = service.call(&"status")
	# Assert——如实报告负值（那是存档问题），但不得被当成「可突破」
	assert_false(bool(status["can_breakthrough"]), "负修为不得判定为可突破")
	assert_eq(int(status["cultivation"]), -50, "只读面如实转述存档值，不臆改")
	assert_true(int(status["penalty"]) >= 0, "惩罚不得为负")


# ═══════════════════════════════════════════════════════════════════════════════
# 验收 5：同种子同结果（确定性）
# ═══════════════════════════════════════════════════════════════════════════════

func test_same_seed_yields_identical_result() -> void:
	# Arrange——同一颗种子、同一初始状态，跑两次
	var seed_value: int = find_seed(REALM_QI, true)
	_inject_seed(seed_value)
	var first: Dictionary = service.call(&"attempt")
	_reset_player(REALM_QI, required)
	_inject_seed(seed_value)
	# Act
	var second: Dictionary = service.call(&"attempt")
	# Assert——逐键相同
	assert_eq(first, second, "同种子 + 同初始状态 → 结果应完全一致")
	assert_true(bool(first["success"]), "该种子应命中成功（用例前提）")


func test_same_seed_reproduces_failure_too() -> void:
	# Arrange
	var seed_value: int = find_seed(REALM_QI, false)
	_inject_seed(seed_value)
	var first: Dictionary = service.call(&"attempt")
	_reset_player(REALM_QI, required)
	_inject_seed(seed_value)
	# Act
	var second: Dictionary = service.call(&"attempt")
	# Assert
	assert_eq(first, second, "失败路径同样应逐键可复现")
	assert_false(bool(first["success"]), "该种子应命中失败（用例前提）")


func test_same_seed_reproduces_roll_sequence() -> void:
	# Arrange——同一颗种子连掷，骰子流应可复现
	var rate: float = TableScript.success_rate_for(REALM_QI)
	# Act——两次独立扫描
	var a: Array = _roll_sequence(rate, 20)
	var b: Array = _roll_sequence(rate, 20)
	# Assert
	assert_eq(a, b, "同种子的掷骰序列应逐位相同")
	assert_true(a.has(true) and a.has(false),
			"20 次里应同时出现成功与失败（否则本用例没有区分力）：%s" % str(a))


# ═══════════════════════════════════════════════════════════════════════════════
# 配置读取面（所需修为 / 境界名 / 上限全来自既有境界表）
# ═══════════════════════════════════════════════════════════════════════════════

func test_required_cultivation_reads_existing_realm_table() -> void:
	for level: int in TableScript.max_realm():
		assert_eq(TableScript.required_cultivation(level + 1),
				int(RealmScript.realm_table[level + 1]["max_cultivation"]),
				"第 %d 境所需修为应取自既有境界表" % (level + 1))
		assert_eq(TableScript.realm_name(level + 1),
				str(RealmScript.realm_table[level + 1]["name"]),
				"第 %d 境境界名应取自既有境界表" % (level + 1))


func test_max_realm_follows_realm_table_size() -> void:
	assert_eq(TableScript.max_realm(), RealmScript.realm_table.size(),
			"最高境界 = 既有境界表条目数（新增境界只改那张表）")
	assert_eq(TableScript.required_cultivation(TableScript.max_realm() + 1), 0,
			"表外境界的所需修为为 0（调用方据此判定不可突破）")
	assert_eq(TableScript.realm_name(TableScript.max_realm() + 1), "",
			"表外境界名不臆造")


func test_penalty_basis_is_max_cultivation_not_holdings() -> void:
	# 惩罚以修为上限为基数——压着修为不攒满不能减损（与渡劫同口径）
	var base: int = TableScript.required_cultivation(REALM_QI)
	assert_eq(TableScript.penalty_for(REALM_QI, base),
			int(floor(float(base) * TableScript.failure_ratio_for(REALM_QI))),
			"惩罚 = floor(上限 × 配置比例)")
	assert_eq(TableScript.penalty_for(REALM_QI, 0), 0, "上限为 0 时惩罚为 0")
	assert_eq(TableScript.penalty_for(REALM_QI, -100), 0, "负上限归零，不产生负惩罚")


func test_success_rate_is_bounded_and_defined_for_every_realm() -> void:
	var top: int = TableScript.max_realm()
	for level: int in top:
		var rate: float = TableScript.success_rate_for(level + 1)
		assert_between(rate, 0.0, 1.0, "第 %d 境成功率应在 [0,1]" % (level + 1))
	assert_eq(TableScript.success_rate_for(top), 0.0, "最高境界无下一境界，成功率为 0")
	assert_eq(TableScript.success_rate_for(top + 99),
			TableScript.success_rate_for(top), "越界档位夹到最近一档，不崩")


func test_roll_success_is_exact_at_both_ends() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	assert_false(TableScript.roll_success(rng, 0.0), "成功率 0 恒失败")
	assert_true(TableScript.roll_success(rng, 1.0), "成功率 1 恒成功")
	assert_false(TableScript.roll_success(null, 1.0), "缺随机源时不臆造成功")


# ═══════════════════════════════════════════════════════════════════════════════
# 装置（本文件专用）
# ═══════════════════════════════════════════════════════════════════════════════

## 同一颗种子连掷 [param p_count] 次的结果序列（可复现性实证）。
func _roll_sequence(p_rate: float, p_count: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = find_seed(REALM_QI, true)
	var out: Array = []
	for i: int in p_count:
		out.append(TableScript.roll_success(rng, p_rate))
	return out
