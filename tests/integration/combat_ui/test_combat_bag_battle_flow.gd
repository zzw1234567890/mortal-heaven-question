extends "res://tests/integration/combat_ui/combat_bag_battle_fixture.gd"
## 战斗内行囊的[b]端到端[/b]用例——真实战斗 + 真实存档 + 真实面板控件。[br]
## [br][b]覆盖本轮点名验收[/b]：[br]
##   ① 打开行囊冻结出牌输入、关闭解冻；[br]
##   ② 用丹药回血且卡实例减少；[br]
##   ③ 灵力不足的条目禁用且不扣费；[br]
##   ④ 用完之后回合状态照常推进；[br]
##   ⑤ 空行囊显示空态文案。[br]
## [br][b]与单元用例的分工[/b]：单元侧证明「算得对」（判据各分支、数值口径、
## 消耗顺序），本文件证明「接得上」——面板挂在战场根上、入口按钮连着宿主、
## 冻结走的是同一个输入层、扣的灵力与出牌是同一本账。装配点漏接不会报错、
## 只会静默降级，那类问题只有这条路径能看见。[br]
## [br][b]装置见 [combat_bag_battle_fixture.gd][/b]。
##
## 来源: 本轮任务书第 1-4 条、先例
## [code]tests/integration/combat_ui/test_combat_click_play_end_to_end.gd[/code]。

const RulesScript := preload("res://src/feature/combat/combat_bag_rules.gd")


func before_each() -> void:
	setup()


func after_each() -> void:
	await teardown()


# ═══════════════════════════════════════════════════════════════════════════════
# 点名验收 ①：打开冻结出牌输入、关闭解冻
# ═══════════════════════════════════════════════════════════════════════════════

func test_bag_entry_button_opens_the_panel_and_freezes_play_input() -> void:
	## 面板盖住了手牌区——不冻结就会出现「隔面板点穿出牌」：玩家点的是行囊里的
	## 一行，打出去的却是手牌。
	# Arrange
	assert_false(is_bag_open(), "前置：初始是关着的")
	assert_true(input_enabled(), "前置：出牌阶段输入应放行")
	# Act——点底部条的「行囊」入口
	press_bag_button()
	# Assert
	assert_true(is_bag_open(), "点入口应打开面板")
	assert_false(input_enabled(), "打开行囊应冻结出牌输入")


func test_closing_the_bag_unfreezes_play_input() -> void:
	# Arrange
	press_bag_button()
	assert_false(input_enabled(), "前置：已冻结")
	# Act——再点一次同一个入口（开关走同一个出口）
	press_bag_button()
	# Assert
	assert_false(is_bag_open(), "再点一次应关闭")
	assert_true(input_enabled(), "关闭应解冻出牌输入")


func test_back_button_closes_the_bag_and_unfreezes_input() -> void:
	## 「返回」是玩家的另一条退出路径——它也必须解冻（否则面板关了却点不动牌）。
	# Arrange
	press_bag_button()
	# Act
	panel().call(&"press_back")
	# Assert
	assert_false(is_bag_open(), "「返回」应关闭面板")
	assert_true(input_enabled(), "「返回」也应解冻出牌输入")


func test_bag_panel_is_drawn_above_the_play_input_layer() -> void:
	## 顺序即绘制层级：面板必须排在输入层之后（否则看得见点不着）。
	# Arrange
	var panel_index: int = panel().get_index()
	var layer_index: int = (layout.call(&"interaction").call(&"get_input_layer") as Node).get_index()
	# Act / Assert
	assert_gt(panel_index, layer_index,
			"行囊面板应排在出牌输入层之后（后被绘制 = 盖在上面）")


# ═══════════════════════════════════════════════════════════════════════════════
# 点名验收 ②：用丹药回血且卡实例减少
# ═══════════════════════════════════════════════════════════════════════════════

func test_bag_lists_the_pill_held_in_the_real_collection() -> void:
	## 条目读的是真实收藏，不是硬编码的清单。
	# Arrange
	press_bag_button()
	# Assert
	assert_eq(int(panel().call(&"entry_count")), 1,
			"收藏里有一枚回春丹，行囊就该列出一行")
	var texts: Array = panel().call(&"entry_texts")
	assert_true(str(texts[0]).contains("回春丹"), "行文案应含真实名称：%s" % str(texts[0]))
	assert_true(str(texts[0]).contains("回复 4 点生命"),
			"效果数值应来自模板：%s" % str(texts[0]))


func test_using_a_pill_heals_the_character_and_consumes_one_copy() -> void:
	## 本轮的核心闭环：面板确认 → 结算层 → 回血 + 少一枚 + 扣灵力 + 中文提示。
	# Arrange
	var hp_before: int = hp_now()
	var cost_before: int = CostSystem.get_current_cost()
	assert_eq(owned_count(PILL_HEAL), 1, "前置：收藏里有一枚")
	press_bag_button()
	var index: int = row_index(true)
	assert_gte(index, 0, "前置：应有一行可用条目")
	# Act——确认那一行
	press_row(index)
	# Assert——回血走的是战斗内的真实状态表
	assert_gt(hp_now(), hp_before, "用药后应回血（%d → %d）" % [hp_before, hp_now()])
	assert_eq(hp_now(), min(hp_before + 4, CHAR_MAX_HP), "回血量取自模板（4 点，夹上限）")
	# Assert——存档侧真的少了一枚
	assert_eq(owned_count(PILL_HEAL), 0, "收藏里应少一枚")
	# Assert——扣的是与出牌同一本灵力账
	assert_eq(CostSystem.get_current_cost(), cost_before - 1, "应扣掉模板 cost 的 1 点灵力")
	# Assert——中文提示
	var message: String = str(panel().call(&"message_text"))
	assert_true(message.contains("回春丹"), "应给中文提示：%s" % message)
	assert_true(message.contains("回复"), "提示应说明效果：%s" % message)


func test_used_pill_disappears_from_the_bag_on_the_next_refresh() -> void:
	## 用完一枚之后，行囊里不该还留着那一行（零缓存：每次打开现读）。
	# Arrange
	press_bag_button()
	press_row(row_index(true))
	# Act——关掉再开（现读一次）
	press_bag_button()
	press_bag_button()
	# Assert
	assert_eq(int(panel().call(&"entry_count")), 0, "用尽的条目不该还列着")
	assert_eq(str(panel().call(&"message_text")), RulesScript.TEXT_EMPTY,
			"应显示空态文案（收藏里确实一枚不剩）")


func test_artifact_use_buffs_attack_without_touching_hp() -> void:
	## 法宝走增益（落状态表），不写 HP——两条效果通路各归各的。
	# Arrange——中途再放一件法器（不重挂场景：重挂会让上一个实例的句柄全部失联）
	give(ARTIFACT_BUFF)
	var hp_before: int = hp_now()
	var atk_before: int = int(cs.call("get_roster_state").call(&"get_atk", char_id))
	press_bag_button()
	# Act——行囊里丹药在前、法宝在后，取最后一行
	press_row(int(panel().call(&"entry_count")) - 1)
	# Assert
	assert_eq(int(cs.call("get_roster_state").call(&"get_atk", char_id)),
			atk_before + 3, "攻击力应 +3（模板 buff 3）")
	assert_eq(hp_now(), hp_before, "法宝不该动 HP")
	assert_eq(owned_count(ARTIFACT_BUFF), 0, "法宝应被消耗掉")


# ═══════════════════════════════════════════════════════════════════════════════
# 点名验收 ③：灵力不足的条目禁用且不扣费
# ═══════════════════════════════════════════════════════════════════════════════

func test_entry_is_disabled_with_a_reason_when_cost_is_insufficient() -> void:
	# Arrange——把灵力花光
	drain_cost()
	assert_eq(CostSystem.get_current_cost(), 0, "前置：灵力应为 0")
	# Act
	press_bag_button()
	# Assert——灰显且写明原因
	assert_eq(int(panel().call(&"entry_count")), 1, "条目仍应列出（只是不可用）")
	assert_true(bool(panel().call(&"is_row_disabled", 0)), "灵力不足的条目应灰显")
	var texts: Array = panel().call(&"entry_texts")
	assert_true(str(texts[0]).contains("灵力不足"),
			"原因应写进行文本（色盲可读）：%s" % str(texts[0]))
	assert_eq(int(panel().call(&"focused_index")), -1,
			"无可用行时游标应为 -1（键盘路径也点不到）")


func test_disabled_entry_cannot_be_used_and_nothing_is_charged() -> void:
	## 界面拦住只是第一道——面板点不到不等于结算层不拒绝，两边都要验。
	# Arrange
	drain_cost()
	press_bag_button()
	var hp_before: int = hp_now()
	# Act——直调面板的确认出口（绕过灰显，模拟「万一被点到」）
	press_row(0)
	# Assert——什么都没动
	assert_eq(owned_count(PILL_HEAL), 1, "拒绝时不该消耗实物")
	assert_eq(hp_now(), hp_before, "拒绝时不该回血")
	assert_eq(CostSystem.get_current_cost(), 0, "拒绝时不该扣费（也不该变成负数）")
	var message: String = str(panel().call(&"message_text"))
	assert_true(message.contains("灵力不足"), "应给出拒绝原因：%s" % message)


func test_entry_becomes_usable_again_when_cost_is_restored() -> void:
	## 灵力回满之后同一枚丹又该是可点的——灰显是即时判据，不是一次性的。
	# Arrange——用 0 费的方式回灵力：直接把上限灌满（走真实 init_for_battle 口径）
	drain_cost()
	press_bag_button()
	assert_true(bool(panel().call(&"is_row_disabled", 0)), "前置：已灰显")
	# Act
	CostSystem.init_for_battle(5)
	panel().call(&"refresh")
	# Assert
	assert_false(bool(panel().call(&"is_row_disabled", 0)), "灵力回满后应恢复可点")


# ═══════════════════════════════════════════════════════════════════════════════
# 点名验收 ④：用完之后回合状态正确推进
# ═══════════════════════════════════════════════════════════════════════════════

func test_using_a_pill_does_not_advance_the_phase_or_the_turn() -> void:
	## 行囊只花灵力——阶段与回合数由战斗系统既有节奏驱动（本链路没有「行动点」）。
	# Arrange
	var phase_before: int = phase_now()
	var turn_before: int = turn_now()
	press_bag_button()
	# Act
	press_row(row_index(true))
	# Assert
	assert_eq(phase_now(), phase_before, "用药不该改阶段")
	assert_eq(turn_now(), turn_before, "用药不该推进回合")


func test_turn_can_still_be_ended_after_using_a_pill() -> void:
	## 「用后回合状态正确推进」：用完药之后，结束出牌仍要把阶段推下去，
	## 整个回合循环照常走到下一回合。
	# Arrange
	press_bag_button()
	press_row(row_index(true))
	press_bag_button()  # 关掉行囊（解冻）
	# Act——点「结束出牌」
	var advanced: bool = press_end_turn()
	# Assert
	assert_true(advanced, "使用行囊后「结束出牌」仍应把阶段 2 推进到 3")
	assert_eq(phase_now(), 3, "应进入攻击声明阶段")
	# Act——继续走完这一回合
	if phase_now() == 3:
		cs.call("confirm_attack_targets")
	for _i: int in range(16):
		if turn_now() > 1 or not bool(cs.call("is_battle_active")):
			break
		if phase_now() == 2:
			break
		advance()
	# Assert
	assert_eq(turn_now(), 2, "整轮走完后应进入第 2 回合（若战斗未先结束）")


func test_bag_use_and_card_play_share_the_same_cost_pool() -> void:
	## 用药与出牌花的是同一本灵力账——两处各扣各的会让玩家看到「灵力对不上」。
	# Arrange
	var cost_before: int = CostSystem.get_current_cost()
	press_bag_button()
	press_row(row_index(true))
	# Assert
	assert_eq(CostSystem.get_current_cost(), cost_before - 1,
			"行囊扣费落回 CostSystem 单例（与出牌同源）")


# ═══════════════════════════════════════════════════════════════════════════════
# 点名验收 ⑤：空行囊显示空态文案
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_bag_shows_the_empty_state_text() -> void:
	# Arrange——把丹药从收藏里拿走（不重挂场景：重挂会让上一个实例的句柄全部失联）
	take_all(PILL_HEAL)
	# Act
	press_bag_button()
	# Assert
	assert_eq(int(panel().call(&"entry_count")), 0, "空行囊不该有行")
	assert_eq(str(panel().call(&"message_text")), RulesScript.TEXT_EMPTY,
			"应显示空态文案")
	assert_eq(int(panel().call(&"focused_index")), -1, "无行时游标应为 -1")


func test_empty_bag_still_freezes_and_unfreezes() -> void:
	## 空行囊也是打开状态——它同样盖住手牌区，冻结与解冻不能因为「没东西」而省掉。
	# Arrange
	take_all(PILL_HEAL)
	# Act
	press_bag_button()
	# Assert
	assert_false(input_enabled(), "空行囊打开时也应冻结")
	# Act
	press_bag_button()
	# Assert
	assert_true(input_enabled(), "关闭后应解冻")


# ═══════════════════════════════════════════════════════════════════════════════
# 装配：入口按钮只在出牌阶段可见（与「结束出牌」同一时机）
# ═══════════════════════════════════════════════════════════════════════════════

func test_bag_entry_follows_the_phase_signal() -> void:
	## 出牌阶段是玩家唯一能支配灵力的那段时间——行囊与「结束出牌」同生共死。
	# Arrange
	var bar: Variant = layout.get(&"combat_bottombar")
	var icon: Variant = bar.get("bag_button")
	# Act / Assert——出牌阶段可见
	icon.call(&"apply_phase", 2)
	assert_true(bool(icon.call(&"is_visible_in_phase")), "出牌阶段入口应可见")
	# Act / Assert——其余阶段隐藏
	for phase: int in [0, 1, 3, 4, 5, 6]:
		icon.call(&"apply_phase", phase)
		assert_false(bool(icon.call(&"is_visible_in_phase")),
				"阶段 %d 入口应隐藏（那时玩家没有可支配的灵力）" % phase)


func test_bag_entry_visibility_follows_the_real_phase_signal() -> void:
	## 接线正确性的实证：阶段信号真的驱动了入口显隐（不是只有直调 apply_phase 才行）。
	# Arrange——底部条订阅本场战斗的阶段信号
	var bar: Variant = layout.get(&"combat_bottombar")
	var icon: Variant = bar.get("bag_button")
	bar.call(&"bind_signals", cs, CostSystem)
	assert_true(bool(icon.call(&"is_visible_in_phase")), "前置：出牌阶段入口可见")
	# Act——点「结束出牌」推进到攻击声明阶段
	press_end_turn()
	# Assert
	assert_eq(phase_now(), 3, "前置：应已离开出牌阶段")
	assert_false(bool(icon.call(&"is_visible_in_phase")), "离开出牌阶段入口应隐藏")
