extends GutTest
## Story 001 验收测试：ResourceSystem Autoload + 读写 API。
##
## 覆盖 AC-001 到 AC-022（22 条 AC，含 AC-018b）。
## 测试策略：
##   - RS_SCRIPT.new() 构造 ResourceSystem 实例（不调 _ready，避免连接 EventSystem）
##   - 真实 GSM Autoload——before_each/after_each 清理 player.resources 域
##   - 动态分派：var rs: Node 持有，返回值显式类型注解（控制清单 2026-08-05 规则）
##   - 信号测试需 await process_frame（batch_updated/resource_changed 帧末发射）

const RS_SCRIPT := preload("res://src/core/resource_system.gd")

var rs: Node = null
var _signal_callables: Array = []


func before_each() -> void:
	rs = RS_SCRIPT.new()
	_signal_callables.clear()
	_reset_gsm_resources()


func after_each() -> void:
	if rs != null:
		rs.free()
		rs = null
	# 仅断开本套件创建的 callable——避免清除其他套件的持久连接（Autoload 信号不会随 rs.free() 清除）
	for callable: Callable in _signal_callables:
		if GameStateManager.resource_changed.is_connected(callable):
			GameStateManager.resource_changed.disconnect(callable)
		if GameStateManager.batch_updated.is_connected(callable):
			GameStateManager.batch_updated.disconnect(callable)
	_signal_callables.clear()
	_reset_gsm_resources()


## 连接 GSM 信号并追踪 callable，便于 after_each 精确断开（不污染其他套件）。
func _track_gsm_signal(sig: Signal, callable: Callable) -> void:
	sig.connect(callable)
	_signal_callables.append(callable)


func _reset_gsm_resources() -> void:
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	GameStateManager.player.resources.ling_shi = 0
	GameStateManager.player.resources.ling_cai = {
		"low": 0, "medium": 0, "high": 0, "top": 0,
	}
	GameStateManager.player.resources.dan_yao_sui_pian = 0


# ============================================================================
# AC-001：ResourceSystem extends Node，不声明 class_name
# ============================================================================

func test_ac001_extends_node_no_class_name() -> void:
	# Arrange + Act
	var script: GDScript = RS_SCRIPT
	# Assert
	assert_eq(script.get_instance_base_type(), "Node", "ResourceSystem 应 extends Node")
	# 源码无 class_name 声明（排除注释——注释中提及 class_name 是说明性文字）
	var source: String = FileAccess.get_file_as_string("res://src/core/resource_system.gd")
	var has_class_name_decl: bool = false
	var regex: RegEx = RegEx.new()
	regex.compile("^\\s*class_name\\b")
	for line: String in source.split("\n"):
		if regex.search(line) != null:
			has_class_name_decl = true
			break
	assert_false(has_class_name_decl, "源码不应声明 class_name（注释提及可接受）")


# ============================================================================
# AC-002：LingCaiQuality 枚举 {LOW=1, MEDIUM=2, HIGH=3, TOP=4}
# ============================================================================

func test_ac002_ling_cai_quality_enum_values() -> void:
	# Arrange + Act
	var enum_dict: Dictionary = RS_SCRIPT.LingCaiQuality
	# Assert
	assert_eq(enum_dict.size(), 4, "LingCaiQuality 应有 4 个常量")
	assert_eq(enum_dict.LOW, 1, "LOW 应为 1")
	assert_eq(enum_dict.MEDIUM, 2, "MEDIUM 应为 2")
	assert_eq(enum_dict.HIGH, 3, "HIGH 应为 3")
	assert_eq(enum_dict.TOP, 4, "TOP 应为 4")


# ============================================================================
# AC-003：add_resource 方法签名 (type: StringName, amount: int, quality: int = -1) -> bool
# ============================================================================

func test_ac003_add_resource_method_signature() -> void:
	# Arrange
	# Act
	var ok: bool = rs.add_resource(&"ling_shi", 25)
	# Assert
	assert_eq(typeof(ok), TYPE_BOOL, "add_resource 应返回 bool")


# ============================================================================
# AC-004：add_resource(&"ling_shi", 25) 当 ling_shi=10 → ling_shi=35, true
# ============================================================================

func test_ac004_add_ling_shi_increases_value() -> void:
	# Arrange
	GameStateManager.player.resources.ling_shi = 10
	# Act
	var ok: bool = rs.add_resource(&"ling_shi", 25)
	# Assert
	assert_true(ok, "应返回 true")
	assert_eq(GameStateManager.player.resources.ling_shi, 35, "灵石应从 10 增加到 35")


# ============================================================================
# AC-005：add_resource(&"ling_cai", 3, LOW) → 低级灵材 +3, true
# ============================================================================

func test_ac005_add_ling_cai_low_quality() -> void:
	# Arrange —— ling_cai.low = 0
	# Act
	var ok: bool = rs.add_resource(&"ling_cai", 3, RS_SCRIPT.LingCaiQuality.LOW)
	# Assert
	assert_true(ok, "应返回 true")
	assert_eq(GameStateManager.player.resources.ling_cai.low, 3, "low 品质灵材应 +3")
	# 其他品质不受影响
	assert_eq(GameStateManager.player.resources.ling_cai.medium, 0, "medium 不应变")
	assert_eq(GameStateManager.player.resources.ling_cai.high, 0, "high 不应变")
	assert_eq(GameStateManager.player.resources.ling_cai.top, 0, "top 不应变")


# ============================================================================
# AC-006：add_resource(&"ling_cai", 1, 5) 无效品质 → false
# ============================================================================

func test_ac006_add_ling_cai_invalid_quality_rejected() -> void:
	# Arrange + Act
	var ok: bool = rs.add_resource(&"ling_cai", 1, 5)
	# Assert
	assert_false(ok, "无效品质 5 应返回 false")


func test_ac006_add_ling_cai_quality_zero_rejected() -> void:
	var ok: bool = rs.add_resource(&"ling_cai", 1, 0)
	assert_false(ok, "品质 0 应返回 false")


func test_ac006_add_ling_cai_quality_negative_rejected() -> void:
	var ok: bool = rs.add_resource(&"ling_cai", 1, -1)
	assert_false(ok, "品质 -1 应返回 false")


# ============================================================================
# AC-007：spend_resource 方法签名 (type: StringName, amount: int, quality: int = -1) -> bool
# ============================================================================

func test_ac007_spend_resource_method_signature() -> void:
	# Arrange
	GameStateManager.player.resources.ling_shi = 50
	# Act
	var ok: bool = rs.spend_resource(&"ling_shi", 30)
	# Assert
	assert_eq(typeof(ok), TYPE_BOOL, "spend_resource 应返回 bool")


# ============================================================================
# AC-008：spend_resource(&"ling_shi", 30) 当 ling_shi=50 → true, ling_shi=20
# ============================================================================

func test_ac008_spend_ling_shi_success() -> void:
	# Arrange
	GameStateManager.player.resources.ling_shi = 50
	# Act
	var ok: bool = rs.spend_resource(&"ling_shi", 30)
	# Assert
	assert_true(ok, "余额充足应返回 true")
	assert_eq(GameStateManager.player.resources.ling_shi, 20, "灵石应从 50 扣除到 20")


# ============================================================================
# AC-009：spend_resource(&"ling_shi", 30) 当 ling_shi=20 → false, ling_shi 仍=20
# ============================================================================

func test_ac009_spend_ling_shi_insufficient_funds() -> void:
	# Arrange
	GameStateManager.player.resources.ling_shi = 20
	# Act
	var ok: bool = rs.spend_resource(&"ling_shi", 30)
	# Assert
	assert_false(ok, "余额不足应返回 false")
	assert_eq(GameStateManager.player.resources.ling_shi, 20, "余额不足时灵石应不变")


# ============================================================================
# AC-010：spend_resource(&"ling_cai", 2, LOW) 当 low=5 → true, low=3
# ============================================================================

func test_ac010_spend_ling_cai_low_success() -> void:
	# Arrange
	GameStateManager.player.resources.ling_cai.low = 5
	# Act
	var ok: bool = rs.spend_resource(&"ling_cai", 2, RS_SCRIPT.LingCaiQuality.LOW)
	# Assert
	assert_true(ok, "应返回 true")
	assert_eq(GameStateManager.player.resources.ling_cai.low, 3, "low 品质应从 5 扣除到 3")


# ============================================================================
# AC-011：spend_resource(&"ling_cai", 5, LOW) 当 low=3 → false, low 仍=3
# ============================================================================

func test_ac011_spend_ling_cai_insufficient_funds() -> void:
	# Arrange
	GameStateManager.player.resources.ling_cai.low = 3
	# Act
	var ok: bool = rs.spend_resource(&"ling_cai", 5, RS_SCRIPT.LingCaiQuality.LOW)
	# Assert
	assert_false(ok, "余额不足应返回 false")
	assert_eq(GameStateManager.player.resources.ling_cai.low, 3, "余额不足时 low 应不变")


# ============================================================================
# AC-012：can_spend 余额校验
# ============================================================================

func test_ac012_can_spend_true_when_sufficient() -> void:
	# Arrange
	GameStateManager.player.resources.ling_shi = 50
	# Act
	var ok: bool = rs.can_spend(&"ling_shi", 30)
	# Assert
	assert_true(ok, "50 >= 30 应为 true")


func test_ac012_can_spend_false_when_insufficient() -> void:
	# Arrange
	GameStateManager.player.resources.ling_shi = 50
	# Act
	var ok: bool = rs.can_spend(&"ling_shi", 60)
	# Assert
	assert_false(ok, "50 < 60 应为 false")


func test_ac012_can_spend_ling_cai_by_quality() -> void:
	# Arrange
	GameStateManager.player.resources.ling_cai.high = 10
	# Act
	var ok: bool = rs.can_spend(&"ling_cai", 5, RS_SCRIPT.LingCaiQuality.HIGH)
	# Assert
	assert_true(ok, "high=10 >= 5 应为 true")


# ============================================================================
# AC-013：get_resource 查询方法
# ============================================================================

func test_ac013_get_ling_shi_balance() -> void:
	# Arrange
	GameStateManager.player.resources.ling_shi = 100
	# Act
	var val: int = rs.get_resource(&"ling_shi")
	# Assert
	assert_eq(val, 100, "应返回灵石余额 100")


func test_ac013_get_ling_cai_single_quality() -> void:
	# Arrange
	GameStateManager.player.resources.ling_cai.medium = 7
	# Act
	var val: int = rs.get_resource(&"ling_cai", RS_SCRIPT.LingCaiQuality.MEDIUM)
	# Assert
	assert_eq(val, 7, "应返回 medium 品质数量 7")


# ============================================================================
# AC-014：get_resource(&"ling_cai") 不传 quality → 所有品质总和
# ============================================================================

func test_ac014_get_ling_cai_total_without_quality() -> void:
	# Arrange
	GameStateManager.player.resources.ling_cai = {
		"low": 2, "medium": 3, "high": 1, "top": 0,
	}
	# Act
	var val: int = rs.get_resource(&"ling_cai")
	# Assert
	assert_eq(val, 6, "应返回四品质总和 2+3+1+0=6")


# ============================================================================
# AC-015：资源变更通过 GSM batch_updated Cat 1 信号传播
# ============================================================================

func test_ac015_batch_updated_emitted_on_spend() -> void:
	# Arrange
	GameStateManager.player.resources.ling_shi = 50
	# Array 捕获——GDScript lambda 对引用类型变异可靠传播（同 test_ac020 模式）
	var received: Array = []
	_track_gsm_signal(GameStateManager.batch_updated, func(c: Dictionary) -> void:
		received.append(c)
	)
	# Act
	rs.spend_resource(&"ling_shi", 30)
	# batch_updated 由 GSM 帧末 _do_flush 发射——直接同步刷新避免帧时序不确定性
	GameStateManager._flush_pending_changes()
	# Assert
	assert_eq(received.size(), 1, "batch_updated 应发射 1 次")
	if not received.is_empty():
		assert_true((received[0] as Dictionary).has("player.resources.ling_shi"), "载荷应含 player.resources.ling_shi 路径")


# ============================================================================
# AC-016：GSM 第二层新增 _set_resource_ling_shi
# ============================================================================

func test_ac016_gsm_has_set_resource_ling_shi() -> void:
	# Act
	var has_method: bool = GameStateManager.has_method("_set_resource_ling_shi")
	# Assert
	assert_true(has_method, "GSM 应有 _set_resource_ling_shi 方法")


func test_ac016_set_resource_ling_shi_writes_value() -> void:
	# Act
	GameStateManager._set_resource_ling_shi(200)
	# Assert
	assert_eq(GameStateManager.player.resources.ling_shi, 200, "应写入 200")


# ============================================================================
# AC-017：GSM 第二层新增 _set_resource_ling_cai
# ============================================================================

func test_ac017_gsm_has_set_resource_ling_cai() -> void:
	var has_method: bool = GameStateManager.has_method("_set_resource_ling_cai")
	assert_true(has_method, "GSM 应有 _set_resource_ling_cai 方法")


func test_ac017_set_resource_ling_cai_writes_each_quality() -> void:
	# Act
	GameStateManager._set_resource_ling_cai(1, 10)
	GameStateManager._set_resource_ling_cai(2, 20)
	GameStateManager._set_resource_ling_cai(3, 30)
	GameStateManager._set_resource_ling_cai(4, 40)
	# Assert
	assert_eq(GameStateManager.player.resources.ling_cai.low, 10, "quality=1 → low=10")
	assert_eq(GameStateManager.player.resources.ling_cai.medium, 20, "quality=2 → medium=20")
	assert_eq(GameStateManager.player.resources.ling_cai.high, 30, "quality=3 → high=30")
	assert_eq(GameStateManager.player.resources.ling_cai.top, 40, "quality=4 → top=40")


# ============================================================================
# AC-018：_set_resource_ling_shi 非负守卫
# ============================================================================

func test_ac018_set_resource_ling_shi_negative_guard() -> void:
	# Act
	GameStateManager._set_resource_ling_shi(-50)
	# Assert
	assert_eq(GameStateManager.player.resources.ling_shi, 0, "max(0, -50) = 0，非负守卫生效")


# ============================================================================
# AC-018b：_set_resource_ling_cai 非负守卫
# ============================================================================

func test_ac018b_set_resource_ling_cai_negative_guard() -> void:
	# Act
	GameStateManager._set_resource_ling_cai(1, -50)
	# Assert
	assert_eq(GameStateManager.player.resources.ling_cai.low, 0, "max(0, -50) = 0，非负守卫生效")


func test_ac018b_set_resource_ling_cai_negative_guard_all_qualities() -> void:
	GameStateManager._set_resource_ling_cai(2, -10)
	GameStateManager._set_resource_ling_cai(3, -20)
	GameStateManager._set_resource_ling_cai(4, -30)
	assert_eq(GameStateManager.player.resources.ling_cai.medium, 0, "medium 非负守卫")
	assert_eq(GameStateManager.player.resources.ling_cai.high, 0, "high 非负守卫")
	assert_eq(GameStateManager.player.resources.ling_cai.top, 0, "top 非负守卫")


# ============================================================================
# AC-019：ResourceSystem 不发射自有 resource_changed 信号
# ============================================================================

func test_ac019_no_resource_changed_signal_on_rs() -> void:
	# Act
	var signals: Array = rs.get_signal_list()
	# Assert
	for sig: Dictionary in signals:
		assert_ne(sig["name"], "resource_changed",
				"ResourceSystem 不应声明 resource_changed 信号（该信号是 GSM Cat 1 域信号）")


# ============================================================================
# AC-020：GSM resource_changed 域信号正向触发
# ============================================================================

func test_ac020_resource_changed_emitted_on_spend_ling_shi() -> void:
	# Arrange
	GameStateManager.player.resources.ling_shi = 50
	var received: Array = []
	_track_gsm_signal(GameStateManager.resource_changed, func(t: StringName, d: int, b: int) -> void:
		received.append([t, d, b])
	)
	# Act
	rs.spend_resource(&"ling_shi", 30)
	# 帧末刷新——直接同步调用 _flush_pending_changes 保证时序稳定（与 AC-015 一致）
	GameStateManager._flush_pending_changes()
	# Assert
	assert_eq(received.size(), 1, "resource_changed 应发射 1 次")
	if not received.is_empty():
		assert_eq(received[0][0], &"ling_shi", "type 应为 ling_shi")
		assert_eq(received[0][1], -30, "delta 应为 -30")
		assert_eq(received[0][2], 20, "balance 应为 20")


func test_ac020_resource_changed_emitted_on_add_ling_cai() -> void:
	# Arrange
	var received: Array = []
	_track_gsm_signal(GameStateManager.resource_changed, func(t: StringName, d: int, b: int) -> void:
		received.append([t, d, b])
	)
	# Act
	rs.add_resource(&"ling_cai", 5, RS_SCRIPT.LingCaiQuality.HIGH)
	GameStateManager._flush_pending_changes()
	# Assert
	assert_eq(received.size(), 1, "resource_changed 应发射 1 次")
	if not received.is_empty():
		assert_eq(received[0][0], &"ling_cai", "type 应为 ling_cai")
		assert_eq(received[0][1], 5, "delta 应为 +5")
		assert_eq(received[0][2], 5, "balance 应为 5（HIGH 单品质余额，非四品质总和）")


# ============================================================================
# AC-021：负数 amount 拒绝
# ============================================================================

func test_ac021_spend_negative_amount_rejected() -> void:
	# Arrange
	GameStateManager.player.resources.ling_shi = 50
	# Act
	var ok: bool = rs.spend_resource(&"ling_shi", -10)
	# Assert
	assert_false(ok, "负数 amount 应返回 false")
	assert_eq(GameStateManager.player.resources.ling_shi, 50, "负数消费不应修改状态")


func test_ac021_add_negative_amount_rejected() -> void:
	# Arrange
	GameStateManager.player.resources.ling_shi = 50
	# Act
	var ok: bool = rs.add_resource(&"ling_shi", -25)
	# Assert
	assert_false(ok, "负数 amount 应返回 false")
	assert_eq(GameStateManager.player.resources.ling_shi, 50, "负数增加不应修改状态")


func test_ac021_add_zero_amount_returns_true() -> void:
	# Arrange
	GameStateManager.player.resources.ling_shi = 50
	# Act
	var ok: bool = rs.add_resource(&"ling_shi", 0)
	# Assert
	assert_true(ok, "amount=0 应返回 true（无操作但有效）")
	assert_eq(GameStateManager.player.resources.ling_shi, 50, "amount=0 不应改变值")


# ============================================================================
# AC-补：无效 type / dan_yao_sui_pian 拒绝路径 + 余额不足不发射信号 + quality 越界守卫
# ============================================================================

func test_invalid_type_add_returns_false() -> void:
	# Arrange + Act
	var ok: bool = rs.add_resource(&"unknown_resource", 10)
	# Assert
	assert_false(ok, "未知资源类型应返回 false")
	assert_push_error_count(1, "未知类型应 push_error 1 次")


func test_invalid_type_spend_returns_false() -> void:
	# Arrange + Act
	var ok: bool = rs.spend_resource(&"unknown_resource", 10)
	# Assert
	assert_false(ok, "未知资源类型应返回 false")
	assert_push_error_count(1, "未知类型应 push_error 1 次")


func test_invalid_type_get_returns_zero() -> void:
	# Act
	var val: int = rs.get_resource(&"unknown_resource")
	# Assert
	assert_eq(val, 0, "未知资源类型查询应返回 0")
	assert_push_error_count(1, "未知类型应 push_error 1 次")


func test_dan_yao_sui_pian_add_rejected_with_warning() -> void:
	# Act——dan_yao_sui_pian 是已知类型但未实现，返回 false + push_warning（非 push_error）
	var ok: bool = rs.add_resource(&"dan_yao_sui_pian", 10)
	# Assert
	assert_false(ok, "dan_yao_sui_pian 暂未通过 ResourceSystem 管理，应返回 false")
	assert_push_warning_count(1, "应 push_warning 1 次（已知类型未实现）")


func test_spend_insufficient_does_not_emit_signals() -> void:
	# Arrange
	GameStateManager.player.resources.ling_shi = 20
	var batch_received: Array = []
	_track_gsm_signal(GameStateManager.batch_updated, func(c: Dictionary) -> void:
		batch_received.append(c)
	)
	var rc_received: Array = []
	_track_gsm_signal(GameStateManager.resource_changed, func(t: StringName, d: int, b: int) -> void:
		rc_received.append([t, d, b])
	)
	# Act——余额不足（20 < 30）
	var ok: bool = rs.spend_resource(&"ling_shi", 30)
	GameStateManager._flush_pending_changes()
	# Assert
	assert_false(ok, "余额不足应返回 false")
	assert_eq(GameStateManager.player.resources.ling_shi, 20, "余额不足不应修改状态")
	assert_eq(batch_received.size(), 0, "余额不足时不应发射 batch_updated")
	assert_eq(rc_received.size(), 0, "余额不足时不应发射 resource_changed")


func test_gsm_set_resource_ling_cai_invalid_quality_guarded() -> void:
	# Act——quality=0 / quality=5 应被 GSM _set_resource_ling_cai 守卫拒绝，不崩溃不静默写入
	GameStateManager._set_resource_ling_cai(0, 10)
	GameStateManager._set_resource_ling_cai(5, 10)
	# Assert
	assert_eq(GameStateManager.player.resources.ling_cai.low, 0, "quality=0 不应写入 top（防负索引静默错误）")
	assert_eq(GameStateManager.player.resources.ling_cai.top, 0, "quality=5 不应越界崩溃")
	assert_push_error_count(2, "两次无效 quality 应各 push_error 1 次")
