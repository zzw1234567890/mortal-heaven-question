extends GutTest
## 战斗结局行文案内核的单测（[code]combat_outcome_lines.gd[/code]）。[br]
## [br][b]背景[/b]：顶部条此前在 [code]battle_ended[/code] 上只清日志、不记结局——
## 玩家翻开战斗日志，看不到「刚才那场是不是渡劫、赢没赢」。本轮把结局写成一条
## 日志条目，文案口径集中在本文件覆盖的这个纯函数模块里。[br]
## [br][b]为什么单独测文案内核[/b]：判定与措辞是纯映射（[code]result + 渡劫标识
## → 一行中文[/code]），可以脱离场景断言每一档；顶部条那一侧只验「有没有落进
## 日志、有没有清零」，两件事分开测，失败时一眼能看出是文案错还是接线错。[br]
## [br][b]渡劫战的两套语汇不许混用[/b]：渡劫战胜了要写「渡劫功成」而不是「战斗
## 胜利」（玩家问的是「我这关过没过」，不是「谁把谁打没了」）；反过来普通战斗
## 也绝不能出现「渡劫」字样。
##
## Story 类型 Logic（Unit）——纯函数，零依赖零副作用。
## 风格先例：tests/unit/combat_ui/test_settlement_rules.gd。

const Lines := preload("res://src/ui/combat/shared/combat_outcome_lines.gd")
## 战斗结果枚举的出处（[code]battle_ended[/code] 载荷的取值）。
const CombatScript := preload("res://src/feature/combat_system.gd")
## 结算文案内核——普通战斗的结局行转引它，两处不许各写一份。
const SettlementRules := preload("res://src/ui/combat/shared/settlement_rules.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 普通战斗：三档结局各一行
# ═══════════════════════════════════════════════════════════════════════════════

func test_normal_victory_line_matches_settlement_title() -> void:
	# Act —— 普通战斗胜利
	var line: String = Lines.outcome_entry(CombatScript.CombatResult.VICTORY, false)
	# Assert —— 前缀可辨 + 文案与结算面板同源（转引，不各写一份）
	assert_true(line.begins_with(Lines.PREFIX), "结局行应带可辨识前缀：%s" % line)
	assert_true(line.contains(SettlementRules.TEXT_VICTORY_TITLE),
			"普通战斗胜利用语应与结算面板同源（实际：%s）" % line)


func test_normal_defeat_line_matches_settlement_title() -> void:
	# Act
	var line: String = Lines.outcome_entry(CombatScript.CombatResult.DEFEAT, false)
	# Assert
	assert_true(line.begins_with(Lines.PREFIX), "结局行应带可辨识前缀：%s" % line)
	assert_true(line.contains(SettlementRules.TEXT_DEFEAT_TITLE),
			"普通战斗战败用语应与结算面板同源（实际：%s）" % line)


func test_normal_retreat_line_distinct_from_defeat() -> void:
	# Act
	var victory: String = Lines.outcome_entry(CombatScript.CombatResult.VICTORY, false)
	var defeat: String = Lines.outcome_entry(CombatScript.CombatResult.DEFEAT, false)
	var retreat: String = Lines.outcome_entry(CombatScript.CombatResult.RETREAT, false)
	# Assert —— 三档互不相同（玩家一眼能分清「赢了」「打没了」「自己走的」）
	assert_ne(victory, defeat, "胜利与战败不该写成同一行")
	assert_ne(retreat, defeat, "撤退与战败不该写成同一行")
	assert_ne(retreat, victory, "撤退与胜利不该写成同一行")


# ═══════════════════════════════════════════════════════════════════════════════
# 渡劫战：另一套语汇，且不与普通战斗撞车
# ═══════════════════════════════════════════════════════════════════════════════

func test_tribulation_victory_line_says_success_not_battle_victory() -> void:
	# Act —— 渡劫战胜利
	var line: String = Lines.outcome_entry(CombatScript.CombatResult.VICTORY, true)
	# Assert —— 不借普通战斗的标题：渡劫战的头等事实是「过没过这关」
	assert_false(line.contains(SettlementRules.TEXT_VICTORY_TITLE),
			"渡劫战胜利不该复用「战斗胜利」的措辞（实际：%s）" % line)
	assert_true(line.contains(Lines.TEXT_TRIB_VICTORY),
			"渡劫战胜利应写「%s」（实际：%s）" % [Lines.TEXT_TRIB_VICTORY, line])


func test_tribulation_failure_line_says_failure() -> void:
	# Act
	var line: String = Lines.outcome_entry(CombatScript.CombatResult.DEFEAT, true)
	# Assert
	assert_false(line.contains(SettlementRules.TEXT_DEFEAT_TITLE),
			"渡劫战失败不该复用「战败」的措辞（实际：%s）" % line)
	assert_true(line.contains(Lines.TEXT_TRIB_FAILURE),
			"渡劫战失败应写「%s」（实际：%s）" % [Lines.TEXT_TRIB_FAILURE, line])


## 渡劫战撤退：规则上不可用（[code]TribulationCombat[/code] 把非 VICTORY 一律判失败），
## 但显示层仍按真实结果记载——「渡劫中断」说的是「这关没过完」。[br]
## [br][b]为什么不断言「等于渡劫失败」[/b]：那条路径真的发生时，日志该反映实际发生了什么
## （自己退的 ≠ 被打死），与战斗域「非胜利即失败」的判定分层，互不冒充。
func test_tribulation_retreat_line_says_interrupted() -> void:
	# Act
	var line: String = Lines.outcome_entry(CombatScript.CombatResult.RETREAT, true)
	# Assert
	assert_true(line.contains(Lines.TEXT_TRIB_RETREAT),
			"渡劫战撤退应写「%s」（实际：%s）" % [Lines.TEXT_TRIB_RETREAT, line])


# ═══════════════════════════════════════════════════════════════════════════════
# 边界：未知结果 / 缺省渡劫标识 / 互斥性质
# ═══════════════════════════════════════════════════════════════════════════════

## 未知结果不臆造结局：仍返回一条可读的「战斗结束」行，不返回空串。[br]
## [br][b]为什么不能返回空串[/b]：调用方（顶部条）拿空串就等于「没记」，玩家翻日志
## 只看到一场没有结尾的战斗；[code]CombatResult.NONE[/code] 在正常路径不会到达
## [code]battle_ended[/code]，但对老调用方 / 测试直发的载荷要有个不冒犯的落点。
func test_unknown_result_still_returns_readable_line() -> void:
	# Act
	var none_line: String = Lines.outcome_entry(CombatScript.CombatResult.NONE, false)
	var bogus_line: String = Lines.outcome_entry(999, false)
	# Assert
	for line: String in [none_line, bogus_line]:
		assert_false(line.strip_edges().is_empty(), "未知结果也应有可读结局行，不该是空串")
		assert_true(line.begins_with(Lines.PREFIX), "未知结果同样带前缀：%s" % line)


## 渡劫标识缺省即普通战斗（调用方少传一个参数不该被当成渡劫）。[br]
func test_missing_tribulation_flag_defaults_to_normal() -> void:
	# Act —— 不传第二个参数
	var line: String = Lines.outcome_entry(CombatScript.CombatResult.VICTORY)
	# Assert
	assert_eq(line, Lines.outcome_entry(CombatScript.CombatResult.VICTORY, false),
			"缺省渡劫标识应与显式 false 完全一致")


## 任何一档结局都不许同时带上「渡劫」字样（两套语汇互斥）。[br]
func test_normal_lines_never_mention_tribulation() -> void:
	# Act
	var results: Array = [CombatScript.CombatResult.VICTORY,
			CombatScript.CombatResult.DEFEAT, CombatScript.CombatResult.RETREAT]
	# Assert
	for result: int in results:
		var line: String = Lines.outcome_entry(result, false)
		assert_false(line.contains(Lines.TEXT_TRIB_VICTORY)
				or line.contains(Lines.TEXT_TRIB_FAILURE)
				or line.contains(Lines.TEXT_TRIB_RETREAT),
				"普通战斗的结局行不该出现渡劫语汇（实际：%s）" % line)
