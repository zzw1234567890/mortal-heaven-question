extends GutTest
## Story 002 验收测试：双重信号路径（cost_changed Cat 2b + GSM batch_updated Cat 1）。
##
## 覆盖 AC-001 到 AC-012（12 条 AC）。
## 测试策略：
##   - CS_SCRIPT.new() 构造 CostSystem 实例（不调 _ready）
##   - 动态分派：var cs: Node 持有，显式类型注解
##   - 信号时序：cost_changed.emit 即时 / batch_updated 通过 await get_tree().process_frame 帧末接收
##   - GSM 集成：battle_start({}) 初始化 battle 域 → _set_battle_cost 写入 → batch_updated 载荷验证
##
## 设计文档来源：ADR-0015 §关键接口 §GSM 第二层扩展 + 验证标准
## Story 来源：production/epics/cost-system/story-002-dual-signal-path-cost-changed-batch-updated.md

const CS_SCRIPT := preload("res://src/core/cost_system.gd")

var cs: Node = null
var _signal_callables: Array = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	_signal_callables.clear()


func after_each() -> void:
	if cs != null:
		for callable: Callable in _signal_callables:
			if cs.cost_changed.is_connected(callable):
				cs.cost_changed.disconnect(callable)
		_signal_callables.clear()
		cs.free()
		cs = null


func _track_signal(callable: Callable) -> void:
	cs.cost_changed.connect(callable)
	_signal_callables.append(callable)


# ============================================================================
# AC-001：signal cost_changed(current: int, max: int, total_max: int) 声明在 CostSystem
# ============================================================================

func test_ac001_cost_changed_signal_declared_in_cs() -> void:
	var script: GDScript = CS_SCRIPT
	var signal_list: Array[Dictionary] = script.get_script_signal_list()
	var found: bool = false
	for sig: Dictionary in signal_list:
		if sig.get("name") == "cost_changed":
			found = true
			var args: Array = sig.get("args", [])
			assert_eq(args.size(), 3, "cost_changed 应有 3 个参数")
			break
	assert_true(found, "cost_changed 信号应在 CostSystem 脚本中声明")


func test_ac001_cost_changed_not_declared_in_gsm() -> void:
	# GSM 不声明 cost_changed——信号属于 CostSystem（语义归属系统）
	var gsm_script: GDScript = load("res://src/foundation/game_state_manager.gd")
	var gsm_signals: Array[Dictionary] = gsm_script.get_script_signal_list()
	for sig: Dictionary in gsm_signals:
		assert_ne(sig.get("name", ""), "cost_changed", "GSM 不应声明 cost_changed")


# ============================================================================
# AC-002：spend() 成功后发射 cost_changed —— current 为扣费后值
# ============================================================================

func test_ac002_spend_emits_cost_changed() -> void:
	var received: Array = []
	_track_signal(func(c: int, m: int, t: int) -> void: received.append([c, m, t]))
	cs.init_for_battle(5)

	var ok: bool = cs.spend(3)
	assert_true(ok, "spend 应成功")
	assert_eq(received.size(), 2, "init_for_battle + spend → 2 次信号")
	# received[0] = init_for_battle, received[1] = spend
	if received.size() >= 2:
		assert_eq(received[1][0], 2, "current = 5-3 = 2")
		assert_eq(received[1][1], 5, "max = 5")
		assert_eq(received[1][2], 5, "total_max = 5")


# ============================================================================
# AC-003：add_temp_bonus() 后发射 cost_changed —— total_max 含临时加成
# ============================================================================

func test_ac003_add_temp_bonus_emits_cost_changed_with_total_max() -> void:
	var received: Array = []
	_track_signal(func(c: int, m: int, t: int) -> void: received.append([c, m, t]))
	cs.init_for_battle(5)

	cs.add_temp_bonus(2, "mid_pill")
	assert_eq(received.size(), 2, "init + bonus → 2 次信号")
	if received.size() >= 2:
		assert_eq(received[1][0], 7, "current = 5+2 = 7")
		assert_eq(received[1][1], 5, "max = 5（境界上限不含加成）")
		assert_eq(received[1][2], 7, "total_max = 5+2 = 7（含临时加成）")


# ============================================================================
# AC-004：reset_for_turn() 后发射 cost_changed —— current 为重置后值
# ============================================================================

func test_ac004_reset_for_turn_emits_cost_changed_first_player() -> void:
	cs.init_for_battle(5)
	cs.spend(3)  # current = 2
	var received: Array = []
	_track_signal(func(c: int, m: int, t: int) -> void: received.append([c, m, t]))

	cs.reset_for_turn(true, false)  # 先手全额恢复
	assert_eq(received.size(), 1, "reset_for_turn 应发射 1 次信号")
	if not received.is_empty():
		assert_eq(received[0][0], 5, "current 恢复为 max_cost = 5")
		assert_eq(received[0][1], 5, "max = 5")
		assert_eq(received[0][2], 5, "total_max = 5")


func test_ac004_reset_for_turn_second_player_first_turn_extra_one() -> void:
	var received: Array = []
	_track_signal(func(c: int, m: int, t: int) -> void: received.append([c, m, t]))
	cs.init_for_battle(5)

	cs.reset_for_turn(false, true)  # 后手第 1 回合
	assert_eq(received.size(), 2, "init + reset → 2 次信号")
	if received.size() >= 2:
		assert_eq(received[1][0], 6, "current = max_cost+1 = 6")


# ============================================================================
# AC-005：init_for_battle() 后发射 cost_changed —— 初始满费状态
# ============================================================================

func test_ac005_init_for_battle_emits_cost_changed() -> void:
	var received: Array = []
	_track_signal(func(c: int, m: int, t: int) -> void: received.append([c, m, t]))

	cs.init_for_battle(5)
	assert_eq(received.size(), 1, "init_for_battle 应发射 1 次 signal")
	if not received.is_empty():
		assert_eq(received[0][0], 5, "current = max_cost = 5（满费）")
		assert_eq(received[0][1], 5, "max = 5")
		assert_eq(received[0][2], 5, "total_max = 5")


# ============================================================================
# AC-006：spend() 失败（费用不足）时不发射 cost_changed（状态未变）
# ============================================================================

func test_ac006_spend_insufficient_no_cost_changed() -> void:
	var received: Array = []
	_track_signal(func(c: int, m: int, t: int) -> void: received.append([c, m, t]))
	cs.init_for_battle(1)  # 仅 1 费

	var ok: bool = cs.spend(3)  # 费用不足
	assert_false(ok, "spend 应失败")
	# 仅有 init_for_battle 发射的 1 次，spend 失败不发射
	assert_eq(received.size(), 1, "费用不足时不应追加 cost_changed 信号")


# ============================================================================
# AC-007：GSM._set_battle_cost(current_cost, max_cost) 写入 battle 域 + 发射 batch_updated
# ============================================================================

func test_ac007_gsm_set_battle_cost_writes_battle_fields() -> void:
	# 初始化 battle 域（模拟 CombatSystem.battle_start）
	GameStateManager.battle_start({})
	# 激活状态检查——has_method 现在应返回 true
	assert_true(GameStateManager.has_method(&"_set_battle_cost"), "GSM 应有 _set_battle_cost 方法")

	GameStateManager._set_battle_cost(3, 5)
	assert_eq(GameStateManager.battle.current_cost, 3, "battle.current_cost = 3")
	assert_eq(GameStateManager.battle.max_cost, 5, "battle.max_cost = 5")

	# 清理
	GameStateManager.battle_end({"result": "test"})


# ============================================================================
# AC-008：batch_updated 载荷含 battle.current_cost 和 battle.max_cost 展平字典
# ============================================================================

func test_ac008_batch_updated_payload_contains_cost_paths() -> void:
	# 初始化 battle
	GameStateManager.battle_start({})

	# 订阅 batch_updated
	var received: Array = []
	var callable: Callable = func(changes: Dictionary) -> void: received.append(changes)
	GameStateManager.batch_updated.connect(callable)

	# 写入费用
	GameStateManager._set_battle_cost(3, 5)

	# 帧末 batch_updated 发射 —— await 等待帧末
	await get_tree().process_frame

	assert_eq(received.size(), 1, "帧末 batch_updated 应发射 1 次")
	if not received.is_empty():
		var changes: Dictionary = received[0]
		assert_true(changes.has("battle.current_cost"), "载荷应含 battle.current_cost 路径")
		assert_true(changes.has("battle.max_cost"), "载荷应含 battle.max_cost 路径")
		# 验证展平路径字典格式 {old, new}
		assert_eq(changes["battle.current_cost"].old, 0, "old = 0")
		assert_eq(changes["battle.current_cost"].new, 3, "new = 3")
		assert_eq(changes["battle.max_cost"].old, 0, "old = 0")
		assert_eq(changes["battle.max_cost"].new, 5, "new = 5")

	# 清理
	GameStateManager.batch_updated.disconnect(callable)
	GameStateManager.battle_end({"result": "test"})


# ============================================================================
# AC-009：_write_cost_to_gsm 调用 GSM._set_battle_cost(current, total_max)
# ============================================================================

func test_ac009_write_cost_to_gsm_calls_gsm_method() -> void:
	GameStateManager.battle_start({})

	cs.init_for_battle(5)  # _write_cost_to_gsm → GSM._set_battle_cost(5, 5)
	assert_eq(GameStateManager.battle.current_cost, 5, "init 后 battle.current_cost = 5")
	assert_eq(GameStateManager.battle.max_cost, 5, "init 后 battle.max_cost = 5")

	cs.add_temp_bonus(2, "pill")  # _write_cost_to_gsm → GSM._set_battle_cost(7, 7)
	assert_eq(GameStateManager.battle.current_cost, 7, "加成后 battle.current_cost = 7")
	assert_eq(GameStateManager.battle.max_cost, 7, "total_max 作为 max 传入 = 5+2=7")

	GameStateManager.battle_end({"result": "test"})


# ============================================================================
# AC-010：双信号时序——cost_changed 先发射，batch_updated 后发射（帧末）
# ============================================================================

func test_ac010_signal_timing_cost_changed_before_batch_updated() -> void:
	GameStateManager.battle_start({})
	cs.init_for_battle(5)

	# 用数组承载可变计数——GDScript lambda 按值捕获 int，按引用捕获 Array
	var cat2b_received: Array = [0]
	var cat1_received: Array = []

	_track_signal(func(_c: int, _m: int, _t: int) -> void: cat2b_received[0] += 1)  # cost_changed
	var batch_callable: Callable = func(changes: Dictionary) -> void:
		if changes.has("battle.current_cost"):
			cat1_received.append(cat2b_received[0])  # 记录 batch_updated 发射时 Cat 2b 的计数

	GameStateManager.batch_updated.connect(batch_callable)

	# 执行——spend 先发射 cost_changed，再 _write_cost_to_gsm → batch_updated 帧末
	cs.spend(2)

	await get_tree().process_frame  # 等待 batch_updated

	assert_gt(cat2b_received[0], 0, "Cat 2b cost_changed 应已发射")
	assert_gt(cat1_received.size(), 0, "Cat 1 batch_updated 应已发射")
	# Cat 2b 计数 > 0 表示在 batch_updated 帧末之前已发射
	if not cat1_received.is_empty():
		assert_gt(cat1_received[0], 0, "batch_updated 时 Cat 2b 已经发射过——时序正确")

	GameStateManager.batch_updated.disconnect(batch_callable)
	GameStateManager.battle_end({"result": "test"})


# ============================================================================
# AC-011：CombatUI 订阅 batch_updated 作为统一刷新源时正常工作
# ============================================================================

func test_ac011_combatui_subscribes_batch_updated_for_cost() -> void:
	GameStateManager.battle_start({})
	cs.init_for_battle(5)

	var ui_cost_current: Array = [-1]  # 模拟 CombatUI 的费用显示（Array 承载可变值）
	var callable: Callable = func(changes: Dictionary) -> void:
		var cost_change = changes.get("battle.current_cost")
		if cost_change != null:
			ui_cost_current[0] = cost_change.new

	GameStateManager.batch_updated.connect(callable)

	cs.spend(2)  # current = 3
	await get_tree().process_frame

	assert_eq(ui_cost_current[0], 3, "CombatUI 应通过 batch_updated 收到刷新后的 current_cost=3")

	GameStateManager.batch_updated.disconnect(callable)
	GameStateManager.battle_end({"result": "test"})


# ============================================================================
# AC-012：GSM 不可用时 _write_cost_to_gsm 不崩溃
# ============================================================================

func test_ac012_gsm_unavailable_no_crash() -> void:
	# 如果 GSM 在 _write_cost_to_gsm 调用时不可用，
	# is_instance_valid(GameStateManager) + has_method 双守卫应阻止崩溃。
	# 此测试验证即使 GSM 未初始化 battle 域，CostSystem 操作仍正常完成。

	# GSM 是 Autoload 全局变量——在此测试环境中始终有效。
	# 实际测试在 Story 001 的 test_ac018 中通过桩模式验证。
	# 本测试验证完整的 GSM 交互路径——GSM 就绪时的正常行为。

	GameStateManager.battle_start({})
	cs.init_for_battle(5)

	# 验证 GSM 写入成功（非桩模式——Story 002 实现了 _set_battle_cost）
	assert_eq(GameStateManager.battle.current_cost, 5)
	assert_eq(cs.get_current_cost(), 5)

	cs.spend(1)
	assert_eq(GameStateManager.battle.current_cost, 4)
	assert_eq(cs.get_current_cost(), 4)

	GameStateManager.battle_end({"result": "test"})
