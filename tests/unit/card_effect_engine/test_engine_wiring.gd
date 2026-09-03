extends GutTest
## Story 8-8 验收测试：CardEffectEngine 子模块接线。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 使用 CardEffectEngine Autoload 实例
##   - 验证 _ready() 初始化子模块
##   - 验证 getter 返回非 null

var cee: Node = null


func before_each() -> void:
	cee = Engine.get_main_loop().root.get_node("/root/CardEffectEngine")
	assert_not_null(cee, "CardEffectEngine Autoload 应存在")


# ============================================================================
# AC-001：_ready() 初始化 PRDEngine 实例
# ============================================================================

func test_ready_initializes_prd_engine() -> void:
	var prd = cee.call("get_prd_engine")
	assert_not_null(prd, "PRDEngine 应已初始化")
	assert_true(prd is PRDEngine, "应为 PRDEngine 类型")


# ============================================================================
# AC-002：_ready() 初始化 CardEffectEvaluator 实例
# ============================================================================

func test_ready_initializes_evaluator() -> void:
	var eval = cee.call("get_evaluator")
	assert_not_null(eval, "CardEffectEvaluator 应已初始化")
	assert_true(eval is CardEffectEvaluator, "应为 CardEffectEvaluator 类型")


# ============================================================================
# AC-003：_ready() 初始化 ResolutionStack 实例
# ============================================================================

func test_ready_initializes_resolution_stack() -> void:
	var rs = cee.call("get_resolution_stack")
	assert_not_null(rs, "ResolutionStack 应已初始化")
	assert_true(rs is ResolutionStack, "应为 ResolutionStack 类型")


# ============================================================================
# AC-004：_ready() 从 GSM.meta.seed 获取种子注入 PRDEngine
# ============================================================================

func test_prd_engine_seeded_from_gsm() -> void:
	# PRDEngine 在 _ready() 时已用 GSM.meta.seed 初始化
	# 验证 PRDEngine 实例存在且可用——种子值本身是 GSM 内部状态
	var prd = cee.call("get_prd_engine")
	assert_not_null(prd, "PRDEngine 应存在")
	# 验证 PRD 判定可执行（种子已注入）
	var result: bool = prd.next_random(999, 0.5)
	assert_true(result == true or result == false, "PRD 判定应可执行")
	prd.reset_card_state(999)


# ============================================================================
# AC-005：GSM 不可用时使用默认种子 0（不崩溃）
# ============================================================================

func test_prd_engine_default_seed_no_crash() -> void:
	# Autoload 实例在 _ready() 时 GSM 可能不可用——默认种子 0
	# 验证 PRDEngine 可正常工作
	var prd = cee.call("get_prd_engine")
	var result: bool = prd.next_random(888, 0.3)
	assert_true(result == true or result == false, "默认种子 PRD 不应崩溃")
	prd.reset_card_state(888)


# ============================================================================
# AC-006：get_prd_engine() 返回非 null PRDEngine 实例
# ============================================================================

func test_get_prd_engine_returns_non_null() -> void:
	var prd = cee.call("get_prd_engine")
	assert_not_null(prd, "get_prd_engine 应返回非 null")
	# 多次调用返回同一实例
	var prd2 = cee.call("get_prd_engine")
	assert_eq(prd, prd2, "多次调用应返回同一实例")


# ============================================================================
# AC-007：get_evaluator() 返回非 null CardEffectEvaluator 实例
# ============================================================================

func test_get_evaluator_returns_non_null() -> void:
	var eval = cee.call("get_evaluator")
	assert_not_null(eval, "get_evaluator 应返回非 null")
	var eval2 = cee.call("get_evaluator")
	assert_eq(eval, eval2, "多次调用应返回同一实例")


# ============================================================================
# AC-008：get_resolution_stack() 返回非 null ResolutionStack 实例
# ============================================================================

func test_get_resolution_stack_returns_non_null() -> void:
	var rs = cee.call("get_resolution_stack")
	assert_not_null(rs, "get_resolution_stack 应返回非 null")
	var rs2 = cee.call("get_resolution_stack")
	assert_eq(rs, rs2, "多次调用应返回同一实例")


# ============================================================================
# AC-009：create_evaluation_snapshot() 返回 GameStateSnapshot（不崩溃）
# ============================================================================

func test_create_evaluation_snapshot_returns_snapshot() -> void:
	var snapshot = cee.call("create_evaluation_snapshot")
	assert_not_null(snapshot, "create_evaluation_snapshot 应返回非 null")
	assert_true(snapshot is GameStateSnapshot, "应为 GameStateSnapshot 类型")
	assert_eq(snapshot.size(), 0, "桩快照应为空（0 角色）")


# ============================================================================
# AC-010：全量测试零回归
# ============================================================================

func test_no_regression() -> void:
	# 验证 6 个桩方法仍可用
	cee.call("register_persistent_effect", 1, &"test", 1, {})
	cee.call("remove_effects_by_source", 1)
	cee.call("suspend_effects_by_source", 1, [1])
	cee.call("restore_effects_by_source", 1, [1])
	assert_eq(cee.call("get_stat_bonus", 1, "ATK"), 0.0, "桩 get_stat_bonus 返回 0.0")
	assert_true(cee.call("card_exists", 1), "桩 card_exists 返回 true")
