extends GutTest
## Story 001 验收测试：CostSystem Autoload + 内部状态 + 查询/变异 API。
##
## 覆盖 AC-001 到 AC-018（18 条 AC）。
## 测试策略：
##   - CS_SCRIPT.new() 构造 CostSystem 实例（不调 _ready）
##   - 动态分派：var cs: Node 持有，返回值显式类型注解（控制清单 2026-08-05 规则）
##   - GSM _set_battle_cost 方法不存在（Story 002 实现）——_write_cost_to_gsm 用 has_method 守卫跳过，不崩溃
##   - 信号测试：cost_changed 在 cs 实例上直接连接
##
## 设计文档来源：ADR-0015 §验证标准 + GDD cost-system.md §验收标准
## Story 来源：production/epics/cost-system/story-001-cost-system-autoload-query-mutation-api.md

const CS_SCRIPT := preload("res://src/core/cost_system.gd")

var cs: Node = null
var _signal_callables: Array = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	_signal_callables.clear()


func after_each() -> void:
	if cs != null:
		# 断开本套件创建的 callable——避免残留连接
		for callable: Callable in _signal_callables:
			if cs.cost_changed.is_connected(callable):
				cs.cost_changed.disconnect(callable)
		_signal_callables.clear()
		cs.free()
		cs = null


## 连接 cost_changed 信号并追踪 callable，便于 after_each 精确断开。
func _track_signal(callable: Callable) -> void:
	cs.cost_changed.connect(callable)
	_signal_callables.append(callable)


# ============================================================================
# AC-001：init_for_battle(max_cost) 初始化全部状态
# ============================================================================

func test_ac001_init_for_battle_sets_all_internal_state() -> void:
	# Arrange + Act
	cs.init_for_battle(5)
	# Assert
	assert_eq(cs._current_cost, 5, "_current_cost 应为 5")
	assert_eq(cs._max_cost, 5, "_max_cost 应为 5")
	assert_eq(cs._temp_bonus, 0, "_temp_bonus 应为 0")
	assert_eq(cs._temp_bonus_stack.size(), 0, "_temp_bonus_stack 应为空")
	assert_true(cs._is_active, "_is_active 应为 true")


func test_ac001_init_for_battle_max_cost_zero_defensive_floor() -> void:
	# Arrange + Act
	cs.init_for_battle(0)
	# Assert——防御性下限：maxi(0, 1) = 1
	assert_eq(cs._max_cost, 1, "max_cost=0 → 防御性下限应为 1")
	assert_eq(cs._current_cost, 1, "current_cost 应与防御后的 max_cost 一致")


func test_ac001_init_for_battle_max_cost_negative_defensive_floor() -> void:
	# Arrange + Act
	cs.init_for_battle(-3)
	# Assert——maxi(-3, 1) = 1
	assert_eq(cs._max_cost, 1, "max_cost 负数 → 防御性下限应为 1")
	assert_eq(cs._current_cost, 1, "current_cost 应与防御后的 max_cost 一致")


# ============================================================================
# AC-002：境界费用上限公式验证
# ============================================================================

func test_ac002_realm_cost_caps_qi_refining() -> void:
	cs.init_for_battle(2)
	assert_eq(cs.get_max_cost(), 2, "炼气期→2")

func test_ac002_realm_cost_caps_foundation() -> void:
	cs.init_for_battle(5)
	assert_eq(cs.get_max_cost(), 5, "筑基期→5")

func test_ac002_realm_cost_caps_golden_core() -> void:
	cs.init_for_battle(8)
	assert_eq(cs.get_max_cost(), 8, "金丹期→8")

func test_ac002_realm_cost_caps_nascent_soul() -> void:
	cs.init_for_battle(11)
	assert_eq(cs.get_max_cost(), 11, "元婴期→11")

func test_ac002_realm_cost_caps_spirit_transformation() -> void:
	cs.init_for_battle(14)
	assert_eq(cs.get_max_cost(), 14, "化神期→14")


# ============================================================================
# AC-003：can_afford 费用校验
# ============================================================================

func test_ac003_can_afford_true_when_sufficient() -> void:
	cs.init_for_battle(5)
	assert_true(cs.can_afford(3), "_current_cost=5, cost=3 → 应可支付")

func test_ac003_can_afford_false_when_insufficient() -> void:
	cs.init_for_battle(5)
	assert_false(cs.can_afford(6), "_current_cost=5, cost=6 → 应不可支付")


# ============================================================================
# AC-004：0 费卡始终可用 + 负数 cost 视为可用
# ============================================================================

func test_ac004_zero_cost_always_affordable() -> void:
	cs.init_for_battle(0)  # 防御性变 1——但 can_afford(0) 应 true
	assert_true(cs.can_afford(0), "0 费卡始终可用")

func test_ac004_zero_cost_affordable_when_empty() -> void:
	cs.init_for_battle(5)
	cs.spend(5)  # _current_cost = 0
	assert_eq(cs.get_current_cost(), 0, "扣至空费验证")
	assert_true(cs.can_afford(0), "空费时 0 费卡仍可用")

func test_ac004_negative_cost_affordable() -> void:
	cs.init_for_battle(5)
	assert_true(cs.can_afford(-1), "负数 cost 视为 ≤0 → 始终 true")


# ============================================================================
# AC-005：spend 扣费成功
# ============================================================================

func test_ac005_spend_success_returns_true() -> void:
	cs.init_for_battle(5)
	var ok: bool = cs.spend(3)
	assert_true(ok, "余额充足应返回 true")
	assert_eq(cs.get_current_cost(), 2, "5-3=2")


func test_ac005_spend_emits_cost_changed() -> void:
	cs.init_for_battle(5)
	var received: Array = []
	_track_signal(func(c: int, m: int, t: int) -> void: received.append([c, m, t]))
	# Act
	var ok: bool = cs.spend(3)
	# Assert
	assert_true(ok, "spend 应成功")
	assert_eq(received.size(), 1, "cost_changed 应发射 1 次")
	if not received.is_empty():
		assert_eq(received[0][0], 2, "current 应为 2")
		assert_eq(received[0][1], 5, "max 应为 5")
		assert_eq(received[0][2], 5, "total_max 应为 5（无临时加成）")


func test_ac005_spend_zero_amount_returns_true_no_state_change() -> void:
	cs.init_for_battle(5)
	var received: Array = []
	_track_signal(func(c: int, m: int, t: int) -> void: received.append([c, m, t]))
	# Act
	var ok: bool = cs.spend(0)
	# Assert
	assert_true(ok, "spend(0) 应返回 true")
	assert_eq(cs.get_current_cost(), 5, "金额为 0 时 current_cost 不变")
	assert_eq(received.size(), 0, "金额为 0 时不应发射信号（状态未变）")


# ============================================================================
# AC-006：spend 费用不足拒绝
# ============================================================================

func test_ac006_spend_insufficient_returns_false() -> void:
	cs.init_for_battle(1)
	var ok: bool = cs.spend(3)
	assert_false(ok, "余额不足应返回 false")
	assert_eq(cs.get_current_cost(), 1, "余额不足时 current_cost 不变")


func test_ac006_spend_insufficient_no_signal_emitted() -> void:
	cs.init_for_battle(1)
	var received: Array = []
	_track_signal(func(c: int, m: int, t: int) -> void: received.append([c, m, t]))
	# Act
	var ok: bool = cs.spend(3)
	# Assert
	assert_false(ok, "余额不足应返回 false")
	assert_eq(received.size(), 0, "余额不足时不应发射 cost_changed")


func test_ac006_spend_insufficient_push_warning() -> void:
	cs.init_for_battle(1)
	cs.spend(3)
	assert_push_warning_count(1, "余额不足应 push_warning 1 次")


# ============================================================================
# AC-007：非活跃战斗 spend 拒绝
# ============================================================================

func test_ac007_spend_inactive_returns_false() -> void:
	var ok: bool = cs.spend(1)
	assert_false(ok, "未 init_for_battle 的 spend 应返回 false")
	assert_push_warning_count(1, "非活跃 spend 应 push_warning 1 次（与 AC-006 一致）")


func test_ac007_spend_after_clear_returns_false() -> void:
	cs.init_for_battle(5)
	cs.clear_for_battle_end()
	var ok: bool = cs.spend(1)
	assert_false(ok, "clear_for_battle_end 后 spend 应返回 false")


# ============================================================================
# AC-008：CostState 枚举判定 + OVERLIMIT 优先级
# ============================================================================

func test_ac008_cost_state_full() -> void:
	cs.init_for_battle(5)  # _current_cost = 5, _max_cost = 5
	assert_eq(cs.get_cost_state(), CS_SCRIPT.CostState.FULL, "初始满费应为 FULL")


func test_ac008_cost_state_partial() -> void:
	cs.init_for_battle(5)
	cs.spend(2)  # _current_cost = 3
	assert_eq(cs.get_cost_state(), CS_SCRIPT.CostState.PARTIAL, "部分消耗应为 PARTIAL")


func test_ac008_cost_state_empty() -> void:
	cs.init_for_battle(5)
	cs.spend(5)  # _current_cost = 0
	assert_eq(cs.get_cost_state(), CS_SCRIPT.CostState.EMPTY, "空费应为 EMPTY")


func test_ac008_cost_state_overlimit() -> void:
	cs.init_for_battle(5)
	cs.add_temp_bonus(3, "high_pill")  # _current_cost = 8, _max_cost = 5
	assert_eq(cs.get_cost_state(), CS_SCRIPT.CostState.OVERLIMIT, "超限应为 OVERLIMIT")


func test_ac008_overlimit_priority_over_full() -> void:
	# _current_cost=8, _max_cost=5 → 当前费用超过上限，应判定为 OVERLIMIT 而非 FULL
	cs.init_for_battle(5)
	cs.add_temp_bonus(3, "pill")
	assert_eq(cs.get_cost_state(), CS_SCRIPT.CostState.OVERLIMIT, "即使恰好为 max+bonus 仍应判定 OVERLIMIT")


# ============================================================================
# AC-009：is_overlimit 超限判定
# ============================================================================

func test_ac009_is_overlimit_true_with_temp_bonus() -> void:
	cs.init_for_battle(5)
	cs.add_temp_bonus(3, "pill")
	assert_true(cs.is_overlimit(), "有临时加成超限应为 true")


func test_ac009_is_overlimit_false_without_temp_bonus() -> void:
	cs.init_for_battle(5)
	assert_false(cs.is_overlimit(), "无临时加成不应超限")


func test_ac009_is_overlimit_false_after_reset() -> void:
	cs.init_for_battle(5)
	cs.add_temp_bonus(3, "pill")
	assert_true(cs.is_overlimit(), "加成后应为超限")
	cs.reset_for_turn(true, false)
	assert_false(cs.is_overlimit(), "重置后临时加成清零 → 不超限")


# ============================================================================
# AC-010：add_temp_bonus 临时费用加成
# ============================================================================

func test_ac010_add_temp_bonus_increases_bonus_and_cost() -> void:
	cs.init_for_battle(5)
	cs.add_temp_bonus(2, "mid_pill_001")
	assert_eq(cs._temp_bonus, 2, "_temp_bonus 应为 2")
	assert_eq(cs.get_current_cost(), 7, "current_cost 应为 5+2=7（突破上限）")
	assert_eq(cs._temp_bonus_stack.size(), 1, "栈应有 1 条记录")


func test_ac010_add_temp_bonus_stack_contains_source_id() -> void:
	cs.init_for_battle(5)
	cs.add_temp_bonus(2, "mid_pill_001")
	if cs._temp_bonus_stack.size() >= 1:
		var entry: Dictionary = cs._temp_bonus_stack[0]
		assert_eq(entry["source_id"], "mid_pill_001", "source_id 应匹配")
		assert_eq(entry["amount"], 2, "amount 应匹配")


func test_ac010_add_temp_bonus_zero_amount_ignored() -> void:
	cs.init_for_battle(5)
	cs.add_temp_bonus(0, "zero_pill")
	assert_eq(cs._temp_bonus, 0, "amount=0 不应增加 temp_bonus")
	assert_eq(cs._temp_bonus_stack.size(), 0, "amount=0 不应压入栈")


func test_ac010_add_temp_bonus_negative_amount_ignored() -> void:
	cs.init_for_battle(5)
	cs.add_temp_bonus(-1, "negative_pill")
	assert_eq(cs._temp_bonus, 0, "amount<0 不应改变 temp_bonus")
	assert_eq(cs._temp_bonus_stack.size(), 0, "amount<0 不应压入栈")


func test_ac010_add_temp_bonus_inactive_rejected() -> void:
	cs.add_temp_bonus(2, "pill")
	assert_eq(cs._temp_bonus, 0, "非活跃战斗添加 temp_bonus 不应生效")
	assert_push_warning_count(1, "非活跃战斗应 push_warning")


# ============================================================================
# AC-011：多丹药临时费用叠加
# ============================================================================

func test_ac011_multiple_pills_stack() -> void:
	cs.init_for_battle(5)
	cs.add_temp_bonus(1, "low_pill_001")
	cs.add_temp_bonus(2, "mid_pill_001")
	assert_eq(cs._temp_bonus, 3, "1+2=3")
	assert_eq(cs.get_current_cost(), 8, "5+3=8")
	assert_eq(cs._temp_bonus_stack.size(), 2, "栈应为 2")


func test_ac011_total_max_reflects_all_bonuses() -> void:
	cs.init_for_battle(5)
	cs.add_temp_bonus(1, "low")
	cs.add_temp_bonus(2, "mid")
	assert_eq(cs.get_total_max(), 8, "get_total_max() = 5+3 = 8")


# ============================================================================
# AC-012：reset_for_turn 先手全额恢复
# ============================================================================

func test_ac012_reset_first_player_full_restore() -> void:
	cs.init_for_battle(5)
	cs.add_temp_bonus(2, "pill")
	cs.spend(3)  # _current_cost = 4, _temp_bonus = 2
	# Act
	cs.reset_for_turn(true, false)
	# Assert
	assert_eq(cs.get_current_cost(), 5, "先手重置 → current_cost 恢复至 max_cost=5")
	assert_eq(cs._temp_bonus, 0, "临时加成清零")
	assert_eq(cs._temp_bonus_stack.size(), 0, "临时加成栈清空")


func test_ac012_reset_first_player_emits_cost_changed() -> void:
	cs.init_for_battle(5)
	cs.spend(2)  # _current_cost = 3
	var received: Array = []
	_track_signal(func(c: int, m: int, t: int) -> void: received.append([c, m, t]))
	# Act
	cs.reset_for_turn(true, false)
	# Assert
	assert_eq(received.size(), 1, "cost_changed 应发射 1 次")
	if not received.is_empty():
		assert_eq(received[0][0], 5, "current 恢复为 5")
		assert_eq(received[0][1], 5, "max = 5")
		assert_eq(received[0][2], 5, "total_max = 5（无临时加成）")


func test_ac012_reset_inactive_does_nothing() -> void:
	# 未 init_for_battle 时 reset_for_turn 不崩溃
	cs.reset_for_turn(true, false)
	# 状态保持默认值
	assert_eq(cs.get_current_cost(), 0)
	assert_eq(cs.get_max_cost(), 0)


# ============================================================================
# AC-013：reset_for_turn 后手第 1 回合额外 +1
# ============================================================================

func test_ac013_reset_second_player_first_turn_extra_one() -> void:
	cs.init_for_battle(5)
	cs.reset_for_turn(false, true)
	assert_eq(cs.get_current_cost(), 6, "后手第 1 回合 = max_cost + 1 = 5+1=6")
	assert_eq(cs._temp_bonus, 0, "额外 +1 不计入 temp_bonus")
	assert_eq(cs._temp_bonus_stack.size(), 0, "栈应为空")


# ============================================================================
# AC-014：reset_for_turn 后手第 2 回合无额外 +1
# ============================================================================

func test_ac014_reset_second_player_later_turn_no_extra() -> void:
	cs.init_for_battle(5)
	cs.reset_for_turn(false, false)
	assert_eq(cs.get_current_cost(), 5, "后手第 2+ 回合 = max_cost = 5")
	assert_eq(cs._temp_bonus, 0, "无额外加成")


# ============================================================================
# AC-015：clear_for_battle_end 战斗清理
# ============================================================================

func test_ac015_clear_for_battle_end_resets_all() -> void:
	cs.init_for_battle(5)
	cs.add_temp_bonus(2, "pill")
	cs.spend(1)
	# Act
	cs.clear_for_battle_end()
	# Assert
	assert_eq(cs._current_cost, 0, "current_cost 归零")
	assert_eq(cs._max_cost, 0, "max_cost 归零")
	assert_eq(cs._temp_bonus, 0, "temp_bonus 归零")
	assert_eq(cs._temp_bonus_stack.size(), 0, "栈清空")
	assert_false(cs._is_active, "is_active 应为 false")


func test_ac015_clear_then_spend_rejected() -> void:
	cs.init_for_battle(5)
	cs.clear_for_battle_end()
	var ok: bool = cs.spend(1)
	assert_false(ok, "清理后 spend 应被拒绝")


func test_ac015_clear_then_add_temp_bonus_rejected() -> void:
	cs.init_for_battle(5)
	cs.clear_for_battle_end()
	cs.add_temp_bonus(2, "pill")
	assert_eq(cs._temp_bonus, 0, "清理后 add_temp_bonus 不应生效")
	assert_push_warning_count(1, "应 push_warning")


# ============================================================================
# AC-016：get_total_max 总上限
# ============================================================================

func test_ac016_total_max_with_bonus() -> void:
	cs.init_for_battle(5)
	cs.add_temp_bonus(3, "pill")
	assert_eq(cs.get_total_max(), 8, "5+3=8")


func test_ac016_total_max_without_bonus_equals_max() -> void:
	cs.init_for_battle(5)
	assert_eq(cs.get_total_max(), 5, "无加成时 total_max == max_cost")


# ============================================================================
# AC-017：extends Node + 不声明 class_name
# ============================================================================

func test_ac017_extends_node_no_class_name() -> void:
	var script: GDScript = CS_SCRIPT
	assert_eq(script.get_instance_base_type(), "Node", "CostSystem 应 extends Node")

	# 源码无 class_name 声明（排除注释）
	var source: String = FileAccess.get_file_as_string("res://src/core/cost_system.gd")
	var regex: RegEx = RegEx.new()
	regex.compile("^\\s*class_name\\b")
	var has_class_name_decl: bool = false
	for line: String in source.split("\n"):
		if regex.search(line) != null:
			has_class_name_decl = true
			break
	assert_false(has_class_name_decl, "源码不应声明 class_name")


func test_ac017_dynamic_dispatch_works() -> void:
	# 控制清单规则：var cs: Node 持有 + 显式类型注解
	var node: Node = CS_SCRIPT.new()
	assert_not_null(node, "动态分派实例应非空")
	assert_eq(node.get_current_cost(), 0, "默认 current_cost=0")
	var cost: int = node.get_current_cost()
	assert_eq(typeof(cost), TYPE_INT, "返回值类型应为 int")
	node.free()


# ============================================================================
# AC-018：GSM 写委托——双守卫不崩溃
# ============================================================================

func test_ac018_write_to_gsm_does_not_crash_when_gsm_available() -> void:
	# GSM 是 Autoload，但 _set_battle_cost 方法尚未实现（Story 002 实现）
	# has_method 守卫 → 静默跳过，不崩溃
	cs.init_for_battle(5)
	# 若未崩溃，测试通过——_write_cost_to_gsm 的 has_method 守卫生效
	assert_eq(cs.get_current_cost(), 5, "init_for_battle 正常完成")
	# 不检查 GSM battle 值——Story 002 才实现 _set_battle_cost
	pass


func test_ac018_write_to_gsm_silent_when_method_missing() -> void:
	# 确保 has_method("_set_battle_cost") 返回 false 时不崩溃
	var has_method: bool = GameStateManager.has_method("_set_battle_cost")
	if not has_method:
		# 当前 GSM 未实现 _set_battle_cost——桩模式必须不崩溃
		cs.init_for_battle(5)
		# 验证初始化成功（未因 _write_cost_to_gsm 异常而中断）
		assert_eq(cs.get_max_cost(), 5, "初始化成功")
		assert_true(cs._is_active, "is_active 为 true")


func test_ac018_cost_changed_emitted_with_correct_payload() -> void:
	# 即使 GSM 写入跳过（桩模式），cost_changed 信号仍正常发射
	cs.init_for_battle(5)  # current=5, max=5, total_max=5
	var received: Array = []
	_track_signal(func(c: int, m: int, t: int) -> void: received.append([c, m, t]))
	# Act: spend 触发信号
	cs.spend(2)  # current=3, max=5, total_max=5
	# Assert
	assert_eq(received.size(), 1, "cost_changed 应发射 1 次")
	if not received.is_empty():
		assert_eq(received[0][0], 3, "current = 3")
		assert_eq(received[0][1], 5, "max = 5")
		assert_eq(received[0][2], 5, "total_max = 5")


# ============================================================================
# 补充边界测试
# ============================================================================

func test_init_twice_overwrites_previous_state() -> void:
	cs.init_for_battle(5)
	cs.add_temp_bonus(2, "pill")
	cs.spend(1)
	# Act: 第二次 init_for_battle
	cs.init_for_battle(10)
	# Assert
	assert_eq(cs._max_cost, 10, "max_cost 更新")
	assert_eq(cs._current_cost, 10, "current_cost 重置为新的 max")
	assert_eq(cs._temp_bonus, 0, "旧 temp_bonus 清零")
	assert_eq(cs._temp_bonus_stack.size(), 0, "旧栈清空")
	assert_true(cs._is_active, "is_active 仍为 true")


func test_spend_exact_amount_zero_remaining() -> void:
	cs.init_for_battle(5)
	var ok: bool = cs.spend(5)
	assert_true(ok, "恰好扣完应返回 true")
	assert_eq(cs.get_current_cost(), 0, "current_cost = 0")


func test_multiple_spend_sequence() -> void:
	cs.init_for_battle(5)
	var ok1: bool = cs.spend(2)
	var ok2: bool = cs.spend(2)
	assert_true(ok1 and ok2, "连续两次消耗应成功")
	assert_eq(cs.get_current_cost(), 1, "5-2-2=1")
	var ok3: bool = cs.spend(2)
	assert_false(ok3, "第三次消耗余额不足应拒绝")
	assert_eq(cs.get_current_cost(), 1, "余额不足时值不变")


func test_cost_state_empty_after_zero_init() -> void:
	cs.init_for_battle(0)  # 防御性 → max=1, current=1
	# 直接设为 0 测试 EMPTY 判定
	cs._current_cost = 0
	cs._max_cost = 5
	assert_eq(cs.get_cost_state(), CS_SCRIPT.CostState.EMPTY, "_current_cost=0 应判定 EMPTY")


func test_cost_state_partial_edge() -> void:
	cs.init_for_battle(5)
	cs._current_cost = 1  # 直接设置以测试 PARTIAL 最小边界
	assert_eq(cs.get_cost_state(), CS_SCRIPT.CostState.PARTIAL, "1/5 应为 PARTIAL")


func test_add_temp_bonus_emits_cost_changed() -> void:
	cs.init_for_battle(5)
	var received: Array = []
	_track_signal(func(c: int, m: int, t: int) -> void: received.append([c, m, t]))
	# Act
	cs.add_temp_bonus(2, "pill")
	# Assert
	assert_eq(received.size(), 1, "临时加成应发射 cost_changed")
	if not received.is_empty():
		assert_eq(received[0][0], 7, "current = 5+2=7")
		assert_eq(received[0][1], 5, "max = 5")
		assert_eq(received[0][2], 7, "total_max = 5+2=7")


func test_clear_for_battle_end_emits_no_signal() -> void:
	cs.init_for_battle(5)
	var received: Array = []
	_track_signal(func(c: int, m: int, t: int) -> void: received.append([c, m, t]))
	# Act
	cs.clear_for_battle_end()
	# Assert——clear_for_battle_end 不发射信号（由 CombatSystem 在 battle_end 中管理清理）
	assert_eq(received.size(), 0, "clear_for_battle_end 不发射 cost_changed")


func test_reset_for_turn_clears_previous_turn_bonus_then_adds_compensation() -> void:
	cs.init_for_battle(5)
	cs.add_temp_bonus(3, "pill")  # _current_cost = 8, _temp_bonus = 3
	# Act: 后手第 1 回合重置——先清除 temp_bonus，再 +1
	cs.reset_for_turn(false, true)
	# Assert
	assert_eq(cs.get_current_cost(), 6, "max(5) + 补偿(1) = 6，temp_bonus 已清零")
	assert_eq(cs._temp_bonus, 0, "旧临时加成已清除")
	assert_eq(cs._temp_bonus_stack.size(), 0, "栈已清空")


func test_cost_changed_payload_during_overlimit() -> void:
	cs.init_for_battle(5)
	var received: Array = []
	_track_signal(func(c: int, m: int, t: int) -> void: received.append([c, m, t]))
	# Act: 添加临时加成后消耗部分费用
	cs.add_temp_bonus(3, "pill")  # signal[0] = [8, 5, 8]——current=5+3=8
	cs.spend(2)                   # signal[1] = [6, 5, 8]——current=8-2=6，仍超限（6>5）
	assert_eq(received.size(), 2, "应发射 2 次信号")
	if received.size() >= 2:
		assert_eq(received[1][0], 6, "current = 8-2 = 6（仍在超限状态）")
		assert_eq(received[1][1], 5, "max = 5")
		assert_eq(received[1][2], 8, "total_max = 8（仍含临时加成）")
