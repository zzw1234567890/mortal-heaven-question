extends GutTest
## combat-ui-layout Story 004 集成测试：阶段指示器信号驱动（AC-1）。
##
## 覆盖：phase_changed 信号 0→6 逐段更新（名称/进度格/回合编号）、
## 节点树无倒计时 Timer UI 元素、同阶段重复信号无变化、回合号递增。
##
## Story 类型 UI（Integration）——此文件为 BLOCKING 证据。
## 风格先例：tests/integration/combat_ui/test_layout_skeleton.gd
## （真实组件脚本 new + mock 信号源）。

const Topbar := preload("res://src/ui/combat/layout/combat_topbar.gd")
const MockSignals := preload("res://tests/integration/combat_ui/mocks/mock_topbar_signals.gd")
## 战斗结果枚举的出处（[code]battle_ended[/code] 载荷的取值）。
const CombatScript := preload("res://src/feature/combat_system.gd")
## 结局行文案内核（顶部条接线侧断言用——与生产同一份口径，不各抄一份）。
const OutcomeLines := preload("res://src/ui/combat/shared/combat_outcome_lines.gd")
## 结算面板文案内核（普通战斗结局行与它同源）。
const SettlementRules := preload("res://src/ui/combat/shared/settlement_rules.gd")

var topbar: CombatTopbar = null
var _mock_combat: Node = null


func before_each() -> void:
	topbar = Topbar.new()
	add_child_autofree(topbar)
	topbar.set_reduce_motion(true)  # 跳过动画——测试断言渲染态终值
	_mock_combat = MockSignals.new()
	add_child_autofree(_mock_combat)
	topbar.bind_signals(_mock_combat, null)


func after_each() -> void:
	_mock_combat = null


# ═══════════════════════════════════════════════════════════════════════════════
# AC-1：阶段指示器信号驱动
# ═══════════════════════════════════════════════════════════════════════════════

func test_phase_indicator_signal_updates_name_and_turn() -> void:
	# When: phase_changed 0→2（进入出牌阶段）
	_mock_combat.phase_changed.emit(1, 2, 1)
	# Then: 阶段名更新为「出牌」（PHASE_NAMES[2]）+ 回合编号更新
	assert_eq(topbar.phase_indicator.get_phase(), 2, "阶段应推进到 2")
	assert_eq(topbar.phase_indicator.phase_label.text, "出牌",
			"阶段名应为「出牌」：%s" % topbar.phase_indicator.phase_label.text)
	assert_eq(topbar.phase_indicator.turn_label.text, "第 1 回合",
			"回合编号应为第 1 回合")


func test_phase_indicator_signal_sequence_0_to_6() -> void:
	# When: 阶段依次 0→1→2→3→4→5→6
	var expected_names: Array = ["准备", "抽牌", "出牌", "攻击声明", "攻击结算", "敌方行动", "结束"]
	for i: int in range(7):
		_mock_combat.phase_changed.emit(i - 1, i, 1)
		assert_eq(topbar.phase_indicator.get_phase(), i, "阶段应推进到 %d" % i)
		assert_eq(topbar.phase_indicator.phase_label.text, expected_names[i],
				"阶段 %d 名称应为「%s」：%s" % [i, expected_names[i],
					topbar.phase_indicator.phase_label.text])


func test_phase_indicator_turn_increments() -> void:
	# When: 回合编号递增（END→PREPARATION 跨回合）
	_mock_combat.phase_changed.emit(6, 0, 2)
	# Then: 回合编号更新为 2
	assert_eq(topbar.phase_indicator.turn_label.text, "第 2 回合",
			"回合编号应递增为第 2 回合")


func test_phase_indicator_same_phase_signal_no_change() -> void:
	# When: 同阶段重复信号（AC-1 edge——无变化）
	_mock_combat.phase_changed.emit(1, 2, 1)
	var name_before: String = topbar.phase_indicator.phase_label.text
	_mock_combat.phase_changed.emit(1, 2, 1)
	# Then: 状态不变（重复信号不重复触发副作用）
	assert_eq(topbar.phase_indicator.phase_label.text, name_before,
			"同阶段重复信号名称不变")


func test_phase_indicator_no_timer_driven_ui() -> void:
	# Then: 节点树无倒计时 Timer UI 元素（GDD 明文——阶段 2 无倒计时）
	var phase_node: Control = topbar.phase_indicator
	assert_null(phase_node.get_node_or_null("Timer"),
			"阶段指示器节点树不应有 Timer 子节点")
	# Then: 无 _process 轮询（源码检查——脚本 source_code 不含重写，规避
	# has_method 对 Node 内置虚方法恒真的误判）
	var source: String = (Topbar as GDScript).source_code
	assert_false(source.contains("func _process"), "不应有 _process 轮询")
	assert_false(source.contains("func _physics_process"), "不应有 _physics_process 轮询")


func test_phase_indicator_progress_step_states() -> void:
	# AC-1 进度条 7 格位置指示（QA 缺口 #8）：当前高亮(2)/已过淡青(1)/未来暗灰(0)
	_mock_combat.phase_changed.emit(2, 3, 1)
	var states: Array[int] = topbar.phase_indicator.get_step_states()
	assert_eq(states.size(), 7, "进度条应为 7 格")
	assert_eq(states[0], 1, "格 0 已过（淡青）")
	assert_eq(states[1], 1, "格 1 已过（淡青）")
	assert_eq(states[2], 1, "格 2 已过（淡青）")
	assert_eq(states[3], 2, "格 3 当前（高亮）")
	assert_eq(states[4], 0, "格 4 未来（暗灰）")
	assert_eq(states[6], 0, "格 6 未来（暗灰）")


func test_phase_audio_callback_fires_on_real_phase_change() -> void:
	# AC-2 阶段切换音（QA 缺口 #6）：真实阶段变化触发一次 (old, new)
	var calls: Array = []
	topbar.phase_indicator.set_phase_audio_callback(func(o: int, n: int) -> void:
		calls.append([o, n]))
	_mock_combat.phase_changed.emit(1, 2, 1)
	assert_eq(calls.size(), 1, "真实阶段变化应触发一次切换音")
	assert_eq(calls[0], [1, 2], "切换音载荷应为 (old=1, new=2)")
	# 同阶段重复信号不触发
	_mock_combat.phase_changed.emit(1, 2, 1)
	assert_eq(calls.size(), 1, "同阶段重复信号不应再触发切换音")


func test_phase_anim_tween_created_and_reduce_motion_skips() -> void:
	# AC-2 切换动画 0.2s（QA 缺口 #7）：非 reduce_motion 创建 Tween，reduce_motion 跳过
	var topbar_anim := Topbar.new()
	add_child_autofree(topbar_anim)
	topbar_anim.bind_signals(_mock_combat, null)
	# 非 reduce_motion：动画 Tween 创建
	_mock_combat.phase_changed.emit(1, 2, 1)
	assert_not_null(topbar_anim.phase_indicator._anim_tween,
			"非 reduce_motion 应创建切换动画 Tween")
	# reduce_motion：跳过动画（无 Tween）
	var topbar_rm := Topbar.new()
	add_child_autofree(topbar_rm)
	topbar_rm.set_reduce_motion(true)
	topbar_rm.bind_signals(_mock_combat, null)
	_mock_combat.phase_changed.emit(1, 2, 1)
	assert_null(topbar_rm.phase_indicator._anim_tween,
			"reduce_motion 应跳过切换动画")


func test_battle_started_sets_initial_phase() -> void:
	# 初始阶段落定（code-review 阻塞项 #4）：battle_started → 阶段 0「准备」+ 回合 1
	_mock_combat.battle_started.emit({})
	assert_eq(topbar.phase_indicator.get_phase(), 0, "battle_started 应落定阶段 0")
	assert_eq(topbar.phase_indicator.phase_label.text, "准备",
			"初始阶段名应为「准备」：%s" % topbar.phase_indicator.phase_label.text)
	assert_eq(topbar.phase_indicator.turn_label.text, "第 1 回合",
			"初始回合编号应为第 1 回合")


# ═══════════════════════════════════════════════════════════════════════════════
# 组装器整合：日志阶段 2 自动收起经 CombatTopbar 路由（AC-2 集成侧）
# ═══════════════════════════════════════════════════════════════════════════════

func test_topbar_routes_phase2_to_log_autocollapse() -> void:
	# Arrange —— 展开日志（经 topbar.combat_log）
	topbar.combat_log.expand()
	assert_true(topbar.combat_log.is_expanded(), "前置：日志已展开")
	# When: phase_changed 到阶段 2（经 topbar 路由）
	_mock_combat.phase_changed.emit(1, 2, 1)
	# Then: 日志自动收起 + 阶段指示器推进
	assert_false(topbar.combat_log.is_expanded(), "阶段 2 经 topbar 路由应收起日志")
	assert_eq(topbar.phase_indicator.get_phase(), 2, "阶段指示器应同步推进到 2")


## 战后清理：过程播报清零，但[b]补上一条结局行[/b]。[br]
## [br][b]断言调整说明（旧值 → 新值）[/b]：本用例原先断言
## [code]get_entries().size() == 0[/code]（战后日志全空）。本轮起
## [code]battle_ended[/code] 在清空之后写一条结局行（「刚才那场赢没赢、
## 是不是渡劫」正是玩家此刻要的答案——清空与写结局是同一次收尾的两半），
## 故新值为 [code]size() == 1[/code] 且那唯一一条是结局行、过程播报条目已不在。
## 「清空」这件事本身没有被放弃，只是从「空表」改成「只剩结局行」来断言。
func test_topbar_battle_ended_clears_log() -> void:
	# Arrange —— 追加日志 + 展开
	topbar.combat_log.append_entry("[1·抽牌] 林渊 → 抽牌 → 手牌 → 2张")
	assert_eq(topbar.combat_log.get_entries().size(), 1, "前置：有 1 条日志")
	# When: battle_ended 信号（经 topbar 路由）
	_mock_combat.battle_ended.emit(CombatScript.CombatResult.VICTORY, {})
	# Then: 过程播报已清 + 只剩一条结局行
	var entries: Array = topbar.combat_log.get_entries()
	assert_eq(entries.size(), 1, "战斗结束后应只剩结局行（原过程播报已清）")
	assert_false(entries.has("[1·抽牌] 林渊 → 抽牌 → 手牌 → 2张"),
			"过程播报条目不应留在战后日志里")
	assert_true(OutcomeLines.is_outcome_entry(str(entries[0])),
			"战后日志唯一那条应是结局行：%s" % str(entries[0]))


# ═══════════════════════════════════════════════════════════════════════════════
# 战后结局行：渡劫 / 普通两套语汇（顶部条接线侧）
# ═══════════════════════════════════════════════════════════════════════════════

## 渡劫战胜利 → 顶栏日志出现渡劫相关字样。[br]
## [br][b]这条用例守的是什么[/b]：顶部条此前把 [code]battle_ended[/code] 的整个
## 结果丢掉（只清日志），玩家翻日志看不到「刚才那场是不是渡劫、过没过」。
## 渡劫标识在开战载荷里定格（[code]is_tribulation[/code]），结局行据此换一套语汇。
func test_topbar_tribulation_victory_logs_tribulation_wording() -> void:
	# Arrange —— 渡劫战开战（开战载荷带 is_tribulation）
	_mock_combat.battle_started.emit({"is_tribulation": true})
	# Act —— 渡劫战胜利
	_mock_combat.battle_ended.emit(CombatScript.CombatResult.VICTORY, {})
	# Then: 日志有且仅有一条结局行，且出现渡劫字样
	var entries: Array = topbar.combat_log.get_entries()
	assert_eq(entries.size(), 1, "战后应写一条结局行：%s" % str(entries))
	var line: String = str(entries[0])
	assert_true(OutcomeLines.is_outcome_entry(line), "应是结局行：%s" % line)
	assert_true(OutcomeLines.mentions_tribulation(line),
			"渡劫战胜利的结局行应出现渡劫字样：%s" % line)
	assert_true(line.contains(OutcomeLines.TEXT_TRIB_VICTORY),
			"渡劫战胜利应写「%s」：%s" % [OutcomeLines.TEXT_TRIB_VICTORY, line])


## 非渡劫战斗 → 结局行不出现渡劫字样（三档结局逐一验）。[br]
## [br][b]为什么三档都验[/b]：渡劫语汇若漏进普通战斗，玩家会以为自己在渡劫——
## 胜/败/退任一条都可能是漏点。
func test_topbar_normal_battle_never_logs_tribulation_wording() -> void:
	# Arrange —— 普通战斗开战（载荷不带 is_tribulation——生产普通开战即如此）
	_mock_combat.battle_started.emit({"character_ids": [101, 202]})
	# Act + Then —— 三档结局各发一次
	var results: Array = [CombatScript.CombatResult.VICTORY,
			CombatScript.CombatResult.DEFEAT, CombatScript.CombatResult.RETREAT]
	for result: int in results:
		_mock_combat.battle_ended.emit(result, {})
		var entries: Array = topbar.combat_log.get_entries()
		assert_eq(entries.size(), 1,
				"每场结束应只有一条结局行（结果 %d）：%s" % [result, str(entries)])
		var line: String = str(entries[0])
		assert_true(OutcomeLines.is_outcome_entry(line), "应是结局行：%s" % line)
		assert_false(OutcomeLines.mentions_tribulation(line),
				"非渡劫战斗的结局行不该出现渡劫字样（结果 %d）：%s" % [result, line])


## 渡劫标识只在开战载荷里认——[code]battle_ended[/code] 载荷带了同名键也不改判。[br]
## [br][b]为什么钉住这条[/b]：结局行是「本场是什么仗」的表述，本场性质开战即定；
## 若改成从结束载荷里读，一个上游字段改名的失误就能把普通战斗写成一渡劫记录。
func test_topbar_tribulation_flag_fixed_at_battle_start() -> void:
	# Arrange —— 普通战斗开战
	_mock_combat.battle_started.emit({})
	# Act —— 结束载荷里塞一个 is_tribulation（本组件不该据此改判）
	_mock_combat.battle_ended.emit(CombatScript.CombatResult.DEFEAT,
			{"is_tribulation": true})
	# Then —— 仍按普通战斗措辞
	var line: String = str(topbar.combat_log.get_entries()[0])
	assert_false(OutcomeLines.mentions_tribulation(line),
			"本场性质开战即定，结束载荷不该改判：%s" % line)
	assert_true(line.contains(SettlementRules.TEXT_DEFEAT_TITLE),
			"普通战斗战败仍应用结算面板同源措辞：%s" % line)
