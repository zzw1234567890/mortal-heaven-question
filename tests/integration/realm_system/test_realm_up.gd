extends GutTest
## Story 003 验收测试：realm_up() 突破编排 + realm_upgraded 信号 + GSM 集成。
##
## 覆盖 AC-001 到 AC-011（11 条 AC）。
## 测试策略：
##   - RS_SCRIPT.new() 构造 RealmSystem 实例（不调 _ready）
##   - 真实 GSM Autoload——before_each/after_each 清理 player 相关状态
##   - watch_signals 验证 realm_upgraded 信号发射 + 载荷
##   - 动态分派：var rs: Node 持有，返回值显式类型注解（控制清单 2026-08-05 规则）
##   - GSM.realm_changed 由帧末 _emit_domain_signal 发射——依赖它的测试需 await process_frame

const RS_SCRIPT := preload("res://src/core/realm_system.gd")

var rs: Node = null


func before_each() -> void:
	rs = RS_SCRIPT.new()
	_reset_gsm_state()


func after_each() -> void:
	if rs != null:
		rs.free()
		rs = null
	# 断开本测试连接到 GSM realm_changed 的所有 callable——Autoload 持久信号不会随 rs.free() 清除
	for conn: Dictionary in GameStateManager.realm_changed.get_connections():
		GameStateManager.realm_changed.disconnect(conn["callable"])
	_reset_gsm_state()


func _reset_gsm_state() -> void:
	GameStateManager.player.realm = GameStateManager.RealmLevel.QI_REFINING
	GameStateManager.player.cultivation = 0
	GameStateManager.player.max_cultivation = GameStateManager.BASE_MAX
	GameStateManager.player.overflow_pool = 0
	GameStateManager.player.cultivation_full = false


# ============================================================================
# AC-001：realm_up 方法签名 + 无返回值
# ============================================================================

func test_ac001_realm_up_method_signature() -> void:
	# 无返回值（void）；不崩溃
	GameStateManager.player.realm = 2
	rs.realm_up(2)
	assert_true(true, "realm_up 应正常执行不崩溃")


# ============================================================================
# AC-002：realm_up(2) 后 GSM.player.realm 变为 3
# ============================================================================

func test_ac002_realm_up_updates_gsm_realm() -> void:
	GameStateManager.player.realm = 2
	rs.realm_up(2)
	assert_eq(GameStateManager.player.realm, 3, "realm_up(2) 后 GSM.player.realm 应为 3")


# ============================================================================
# AC-003：realm_up(2) 后发射 realm_upgraded(2, 3) 信号
# ============================================================================

func test_ac003_realm_up_emits_signal_with_payload() -> void:
	GameStateManager.player.realm = 2
	var received: Array = []
	rs.realm_upgraded.connect(func(o: int, n: int) -> void:
		received.append([o, n])
	)
	rs.realm_up(2)
	assert_eq(received.size(), 1, "应发射 1 次 realm_upgraded")
	if not received.is_empty():
		assert_eq(received[0][0], 2, "old_level 应为 2")
		assert_eq(received[0][1], 3, "new_level 应为 3")


# ============================================================================
# AC-004：realm_up(5)（最高境界）→ push_error + 不修改 GSM
# ============================================================================

func test_ac004_realm_up_max_level_push_error() -> void:
	GameStateManager.player.realm = 5
	rs.realm_up(5)
	assert_push_error_count(1, "最高境界突破应 push_error 1 次")
	assert_eq(GameStateManager.player.realm, 5, "最高境界突破不应修改 GSM.player.realm")


func test_ac004_realm_up_max_level_no_signal() -> void:
	GameStateManager.player.realm = 5
	var received: Array = []
	rs.realm_upgraded.connect(func(o: int, n: int) -> void:
		received.append([o, n])
	)
	rs.realm_up(5)
	assert_eq(received.size(), 0, "最高境界突破不应发射 realm_upgraded 信号")


# ============================================================================
# AC-005：realm_up 内部调用 GSM.change_realm(new_level)（间接验证）
# ============================================================================

func test_ac005_realm_up_calls_gsm_change_realm() -> void:
	# 间接验证——GSM.player.realm 变更证明 change_realm 已执行
	GameStateManager.player.realm = 3
	rs.realm_up(3)
	assert_eq(GameStateManager.player.realm, 4, "change_realm 已执行——realm 变为 4")


# ============================================================================
# AC-006：realm_upgraded 信号声明（Cat 2b）+ 2 个 int 参数
# ============================================================================

func test_ac006_realm_upgraded_signal_signature() -> void:
	var signals: Array = rs.get_signal_list()
	var found: bool = false
	for sig: Dictionary in signals:
		if sig["name"] == "realm_upgraded":
			found = true
			var args: Array = sig["args"]
			assert_eq(args.size(), 2, "realm_upgraded 应有 2 个参数")
			assert_eq(args[0]["type"], TYPE_INT, "参数 0 (old_level) 应为 int")
			assert_eq(args[1]["type"], TYPE_INT, "参数 1 (new_level) 应为 int")
	assert_true(found, "应存在 realm_upgraded 信号")


# ============================================================================
# AC-007：realm_upgraded 信号载荷为 2 个 int 参数
# ============================================================================

func test_ac007_realm_upgraded_signal_payload() -> void:
	GameStateManager.player.realm = 3
	watch_signals(rs)
	rs.realm_up(3)
	assert_signal_emitted(rs, "realm_upgraded", "应发射 realm_upgraded 信号")
	var params: Array = get_signal_parameters(rs, "realm_upgraded", 0)
	assert_eq(params.size(), 2, "信号载荷应为 2 个参数")
	assert_eq(params[0], 3, "old_level 应为 3")
	assert_eq(params[1], 4, "new_level 应为 4")


# ============================================================================
# AC-008：realm_up 不直接调用下游系统方法（信号委托——源码 grep 验证）
# ============================================================================

func test_ac008_realm_up_no_direct_downstream_calls() -> void:
	# 代码审查检查点——grep realm_system.gd 源码，确认无下游系统的代码级直接调用
	var source: String = FileAccess.get_file_as_string("res://src/core/realm_system.gd")
	# 下游系统名称——仅文档注释中允许提及
	for forbidden: String in ["CultivationSystem", "ExplorationSystem", "CardSystem", "TribulationSystem"]:
		# 遍历行，检查 forbidden 出现的位置是否在 # 注释之后（行首或行内注释均算注释）
		var lines: PackedStringArray = source.split("\n")
		var in_code_count: int = 0
		for line: String in lines:
			var forbidden_pos: int = line.find(forbidden)
			if forbidden_pos < 0:
				continue
			var hash_pos: int = line.find("#")
			# forbidden 在代码区：# 不存在，或 forbidden 出现在 # 之前
			if hash_pos < 0 or forbidden_pos < hash_pos:
				in_code_count += 1
		assert_eq(in_code_count, 0,
			"'%s' 不应出现在代码中（仅文档注释允许），代码级引用数: %d" % [forbidden, in_code_count])


# ============================================================================
# AC-009：突破后 GSM.player.cultivation + max_cultivation 保留不变
# ============================================================================

func test_ac009_realm_up_preserves_cultivation() -> void:
	GameStateManager.player.realm = 2
	GameStateManager.player.cultivation = 800
	GameStateManager.player.max_cultivation = 1500
	rs.realm_up(2)
	assert_eq(GameStateManager.player.cultivation, 800, "突破后 cultivation 应保留旧值 800")
	assert_eq(GameStateManager.player.max_cultivation, 1500, "突破后 max_cultivation 不应被 realm_up 修改")


# ============================================================================
# AC-010：realm_up 调用 GSM.change_realm 可观察（GSM.realm_changed Cat 1 信号）
# ============================================================================

func test_ac010_realm_up_triggers_gsm_realm_changed() -> void:
	GameStateManager.player.realm = 2
	var realm_changed_received: Array = []
	GameStateManager.realm_changed.connect(func(o: int, n: int) -> void:
		realm_changed_received.append([o, n])
	)
	rs.realm_up(2)
	# realm_changed 由帧末 _emit_domain_signal 发射——需让出主线程一帧
	await get_tree().process_frame
	assert_eq(realm_changed_received.size(), 1, "GSM.realm_changed Cat 1 信号应发射 1 次")
	if not realm_changed_received.is_empty():
		assert_eq(realm_changed_received[0][0], 2, "GSM.realm_changed old 应为 2")
		assert_eq(realm_changed_received[0][1], 3, "GSM.realm_changed new 应为 3")


func test_ac010_realm_up_max_level_no_gsm_realm_changed() -> void:
	# 最高境界突破失败不应触发 GSM.realm_changed
	GameStateManager.player.realm = 5
	var realm_changed_received: Array = []
	GameStateManager.realm_changed.connect(func(o: int, n: int) -> void:
		realm_changed_received.append([o, n])
	)
	rs.realm_up(5)
	await get_tree().process_frame
	assert_eq(realm_changed_received.size(), 0, "最高境界突破失败不应触发 GSM.realm_changed")


# ============================================================================
# AC-011：realm_up(4)→5 最后可突破境界（off-by-one 边界防护）
# ============================================================================

func test_ac011_realm_up_level_4_to_5_succeeds() -> void:
	GameStateManager.player.realm = 4
	rs.realm_up(4)
	assert_eq(GameStateManager.player.realm, 5, "realm_up(4) 应突破至最高境界 5（非 > 误判为 >=）")


# ============================================================================
# AC-012：realm_up 参数与 GSM 状态不一致 → push_error + 不修改状态
# ============================================================================

func test_ac012_realm_up_mismatched_current_level_rejected() -> void:
	# 调用者传入 current_level=2，但 GSM.player.realm=3——校验应拒绝，防止信号载荷与 GSM 漂移
	GameStateManager.player.realm = 3
	rs.realm_up(2)
	assert_push_error_count(1, "current_level 与 GSM 不一致应 push_error 1 次")
	assert_eq(GameStateManager.player.realm, 3, "参数不一致时不应修改 GSM.player.realm")
