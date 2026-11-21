extends "res://tests/integration/tribulation/tribulation_reward_fixture.gd"
## 渡劫金卡奖励——文案与结算屏（GDD §6「获得：×××（金）」）。[br]
## [br][b]覆盖[/b]：[br]
##   1. 文案内核 [code]TribulationRewardLines.card_lines[/code]：有奖励时出「获得：」行
##      且含卡名与稀有度，未发放时出「未发放：」行且含原因，空报告不产生任何行；[br]
##   2. 结算面板 [code]SettlementHost[/code]：有奖励时那行真的渲染到
##      [code]reward_lines_label[/code]，没有奖励时不建该行；[br]
##   3. 载荷：报告随 [code]battle_ended[/code] 下发，结算屏（[code]CombatResultView[/code]）
##      读得到；失败时载荷里没有这一段。[br]
## [br][b]面板用例为什么也用 VICTORY(1)[/b]：面板路由走
## [code]SettlementRules.panel_kind_for[/code]，它按真实 [code]CombatResult[/code]
## 判 kind——两个入口（渡劫战斗委托与结算宿主）现在取的是同一个枚举值，
## 不再有「渡劫侧私有约定」那一层。[br]
## [br]来源: design/gdd/tribulation-system.md §6、ADR-0031 §2（Logic 内核）、
## ADR-0021 §_on_battle_ended。

const HostScript := preload("res://src/ui/combat/settlement/settlement_host.gd")
const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 文案内核——纯函数（无场景树依赖）
# ═══════════════════════════════════════════════════════════════════════════════

func test_card_lines_show_gain_with_name_and_rarity() -> void:
	# Arrange
	_enter_combat()
	# Act
	var report: Dictionary = ts.call("_handle_tribulation_success")
	var lines: Array = LinesScript.card_lines(report)
	# Assert
	assert_eq(lines.size(), 1, "一张到手卡 → 一行")
	assert_string_contains(str(lines[0]), "获得：", "应出现「获得」：%s" % str(lines[0]))
	assert_string_contains(str(lines[0]), str(report[PoolScript.KEY_CARDS][0].get("name")),
			"应含卡名：%s" % str(lines[0]))
	assert_string_contains(str(lines[0]), "金", "应含稀有度：%s" % str(lines[0]))


func test_card_lines_show_not_granted_with_reason() -> void:
	# Arrange——池空
	cs.templates.erase(GOLD_A)
	cs.templates.erase(GOLD_B)
	_enter_combat()
	# Act
	var report: Dictionary = ts.call("_handle_tribulation_success")
	var lines: Array = LinesScript.card_lines(report)
	# Assert
	assert_eq(lines.size(), 1, "一条未发放 → 一行")
	assert_string_contains(str(lines[0]), "未发放", "应说明未发放：%s" % str(lines[0]))
	assert_string_contains(str(lines[0]), "金档", "应含原因：%s" % str(lines[0]))


func test_card_lines_empty_when_no_report() -> void:
	# 无报告 / 空报告 / 非字典——都不产生行（结算屏据此「不建那一行」）
	assert_eq(LinesScript.card_lines(null), [], "无报告不产生行")
	assert_eq(LinesScript.card_lines({}), [], "空报告不产生行")
	assert_eq(LinesScript.card_lines("not-a-dict"), [], "非字典不崩且不产生行")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 结算面板——真有奖励时写出那一行，没有时不建
# ═══════════════════════════════════════════════════════════════════════════════

func test_settlement_panel_shows_tribulation_reward_line() -> void:
	# Arrange——宿主入树（需要场景树才能建面板）
	var host: Node = HostScript.new()
	add_child_autofree(host)
	_enter_combat()
	var report: Dictionary = ts.call("_handle_tribulation_success")
	var rewards: Dictionary = {"lingshi": 12, "cultivation": 4,
			PoolScript.KEY_PAYLOAD: report}
	# Act——真枚举的 VICTORY（见文件头说明）
	host.call("on_battle_ended", COMBAT_VICTORY, rewards)
	var text: String = str(host.settlement_panel.reward_lines_label.text)
	# Assert
	assert_string_contains(text, "获得：", "结算面板应写出「获得」行：%s" % text)
	assert_string_contains(text, str(report[PoolScript.KEY_CARDS][0].get("name")),
			"面板文案应含卡名：%s" % text)


func test_settlement_panel_omits_reward_line_when_absent() -> void:
	# Arrange——普通战斗载荷（没有渡劫奖励那一段）
	var host: Node = HostScript.new()
	add_child_autofree(host)
	# Act
	host.call("on_battle_ended", COMBAT_VICTORY, {"lingshi": 12, "cultivation": 4})
	# Assert
	var text: String = str(host.settlement_panel.reward_lines_label.text)
	assert_false(text.contains("获得："), "没有渡劫奖励时不得凭空出现「获得」行：%s" % text)


func test_panel_lines_helper_returns_empty_without_payload_key() -> void:
	# Arrange
	var host: Node = HostScript.new()
	add_child_autofree(host)
	# Act / Assert——普通战斗载荷恒为空（宿主的取键包装层）
	assert_eq(host.call("tribulation_reward_lines", {"lingshi": 3}), [],
			"载荷无渡劫段时应返回空数组")
	assert_eq(host.call("tribulation_reward_lines", {}), [], "空载荷同样为空数组")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 载荷——报告随 battle_ended 下发，结算屏读得到
# ═══════════════════════════════════════════════════════════════════════════════

func test_battle_ended_payload_carries_reward_report() -> void:
	# Arrange
	_enter_combat()
	var rewards: Dictionary = {}
	# Act——渡劫战斗委托的结算入口（真实路径：battle_ended 载荷就地补键）
	ts.call("_on_battle_ended", COMBAT_VICTORY, rewards)
	# Assert
	assert_true(rewards.has(PoolScript.KEY_PAYLOAD), "载荷应带渡劫奖励报告")
	var report: Dictionary = rewards[PoolScript.KEY_PAYLOAD]
	assert_eq((report[PoolScript.KEY_CARDS] as Array).size(), PoolScript.CARDS_NORMAL,
			"载荷里的到手卡张数应与规则一致")


func test_battle_ended_payload_has_no_report_on_failure() -> void:
	# Arrange
	_enter_combat()
	var rewards: Dictionary = {}
	# Act——失败（真实枚举的 DEFEAT——渡劫战里撤退不可用，故只验这一支）
	ts.call("_on_battle_ended", COMBAT_DEFEAT, rewards)
	# Assert——失败不发卡，也不该有奖励段（结算屏「不建那一行」的根据）
	assert_false(rewards.has(PoolScript.KEY_PAYLOAD), "失败不发卡，也不该有奖励段")


func test_battle_ended_victory_payload_lines_readable_for_result_screen() -> void:
	# Arrange——结算屏读的是 CombatResultView（跨场景只读快照）
	_enter_combat()
	var rewards: Dictionary = {"lingshi": 3}
	ts.call("_on_battle_ended", COMBAT_VICTORY, rewards)
	# Act
	var view: RefCounted = ViewScript.from_battle_ended(COMBAT_VICTORY, rewards)
	var lines: Array = view.call("reward_lines")
	# Assert
	assert_true(lines.has("灵石 +3"), "普通奖励行照旧：%s" % str(lines))
	var found: bool = false
	for line: Variant in lines:
		if str(line).contains("获得："):
			found = true
	assert_true(found, "结算屏应能读出渡劫金卡那一行：%s" % str(lines))


func test_result_screen_has_no_tribulation_line_for_normal_battle() -> void:
	# Arrange——普通战斗载荷（无渡劫段）
	var view: RefCounted = ViewScript.from_battle_ended(COMBAT_VICTORY, {"lingshi": 3})
	# Act
	var lines: Array = view.call("reward_lines")
	# Assert
	assert_eq(lines, ["灵石 +3"], "普通战斗的行数组应逐条不变：%s" % str(lines))
