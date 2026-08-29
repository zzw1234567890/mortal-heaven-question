extends GutTest
## Story 004 验收测试：realm_upgraded 信号订阅 + check_breakthrough。
##
## 覆盖 AC-001 到 AC-006（6 条 AC）。
## 测试策略：
##   - 使用 GSM Autoload + CultivationSystem 实例
##   - 验证 realm_changed 信号订阅 + 回调
##   - 验证 check_breakthrough + request_breakthrough + get_breakthrough_status
##
## 设计文档来源：GDD §4-6 修为满值提示 + 突破后修为处理
## Story 来源：production/epics/cultivation-system/story-004-realm-upgraded-check-breakthrough.md

const CS_SCRIPT := preload("res://src/feature/cultivation_system.gd")

var cs: Node = null
var gsm: Node = null
var _batch_updates: Array = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		fail_test("GSM Autoload 未注册")
		return
	gsm.player.cultivation = 0
	gsm.player.max_cultivation = 1000
	gsm.player.cultivation_full = false
	gsm.player.overflow_pool = 0
	gsm.player.realm = 1
	gsm.set("_signal_chain_depth", 0)
	gsm.get("_signal_router").set("_pending_changes", [])
	_batch_updates.clear()
	gsm.batch_updated.connect(_on_batch_updated)


func after_each() -> void:
	if gsm != null:
		if cs != null and gsm.realm_changed.is_connected(cs.on_realm_changed):
			gsm.realm_changed.disconnect(cs.on_realm_changed)
		if gsm.batch_updated.is_connected(_on_batch_updated):
			gsm.batch_updated.disconnect(_on_batch_updated)
		gsm.player.cultivation = 0
		gsm.player.max_cultivation = 1000
		gsm.player.cultivation_full = false
		gsm.player.overflow_pool = 0
		gsm.player.realm = 1
	if cs != null:
		cs.free()
		cs = null
	_batch_updates.clear()


func _on_batch_updated(changes: Dictionary) -> void:
	_batch_updates.append(changes.duplicate(true))


func _flush() -> void:
	await get_tree().process_frame


# ============================================================================
# AC-001：_ready 订阅 realm_changed
# ============================================================================

func test_ac001_ready_subscribes_realm_changed() -> void:
	# _ready 在 Autoload 场景下由引擎调用，但 ES_SCRIPT.new() 不触发 _ready
	# 手动调用 _ready 模拟 Autoload 就绪
	cs.call("_ready")
	assert_true(gsm.realm_changed.is_connected(cs.on_realm_changed), "_ready 后 realm_changed 已订阅")


func test_ac001_ready_idempotent() -> void:
	cs.call("_ready")
	cs.call("_ready")  # 重复调用不应报错
	assert_true(gsm.realm_changed.is_connected(cs.on_realm_changed), "重复 _ready 仍连接")


# ============================================================================
# AC-002：check_breakthrough 返回正确 bool
# ============================================================================

func test_ac002_check_breakthrough_true_when_full() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	assert_eq(cs.call("check_breakthrough"), true, "满值时可突破")


func test_ac002_check_breakthrough_false_when_not_full() -> void:
	gsm.player.cultivation = 800
	gsm.player.max_cultivation = 1000
	assert_eq(cs.call("check_breakthrough"), false, "未满不可突破")


# ============================================================================
# AC-003：on_realm_changed 更新 max_cultivation
# ============================================================================

func test_ac003_on_realm_changed_updates_max() -> void:
	gsm.player.realm = 1
	gsm.player.overflow_pool = 0
	cs.call("on_realm_changed", 1, 2)  # 炼气→筑基
	await _flush()
	assert_eq(gsm.player.max_cultivation, 1500, "筑基 max_cultivation=1500")


func test_ac003_on_realm_changed_settles_overflow() -> void:
	gsm.player.realm = 1
	gsm.player.overflow_pool = 350
	cs.call("on_realm_changed", 1, 2)
	await _flush()
	# update_max_cultivation 触发 settle_overflow: 350 mod 100 = 50
	assert_eq(gsm.player.overflow_pool, 50, "on_realm_changed 触发 settle_overflow")


func test_ac003_realm_changed_signal_triggers_callback() -> void:
	cs.call("_ready")
	gsm.player.overflow_pool = 0
	# 触发 realm_changed 信号（通过 change_realm）
	gsm.change_realm(2)
	await _flush()
	assert_eq(gsm.player.max_cultivation, 1500, "realm_changed 信号触发 max_cultivation 更新")


# ============================================================================
# AC-004：request_breakthrough 返回完整信息
# ============================================================================

func test_ac004_request_breakthrough_can_break() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	gsm.player.realm = 2
	gsm.player.overflow_pool = 50
	var req: Dictionary = cs.call("request_breakthrough")
	assert_eq(req["can_breakthrough"], true, "can_breakthrough=true")
	assert_eq(req["current_realm"], 2, "current_realm=2")
	assert_eq(req["cultivation"], 1000, "cultivation=1000")
	assert_eq(req["max_cultivation"], 1000, "max_cultivation=1000")
	assert_eq(req["overflow_pool"], 50, "overflow_pool=50")


func test_ac004_request_breakthrough_cannot_break() -> void:
	gsm.player.cultivation = 500
	gsm.player.max_cultivation = 1000
	gsm.player.realm = 1
	var req: Dictionary = cs.call("request_breakthrough")
	assert_eq(req["can_breakthrough"], false, "can_breakthrough=false")
	assert_eq(req["current_realm"], 1, "current_realm=1")


# ============================================================================
# AC-005：境界变化后 batch_updated 传播 max_cultivation
# ============================================================================

func test_ac005_batch_updated_max_cultivation() -> void:
	cs.call("on_realm_changed", 1, 2)
	await _flush()
	var found: bool = false
	for changes in _batch_updates:
		if changes.has("player.max_cultivation"):
			found = true
	assert_true(found, "batch_updated 含 player.max_cultivation 路径")


func test_ac005_batch_updated_correct_values() -> void:
	gsm.player.max_cultivation = 1000
	cs.call("on_realm_changed", 1, 2)
	await _flush()
	for changes in _batch_updates:
		if changes.has("player.max_cultivation"):
			assert_eq(changes["player.max_cultivation"]["old"], 1000, "old=1000")
			assert_eq(changes["player.max_cultivation"]["new"], 1500, "new=1500")


# ============================================================================
# AC-006：get_breakthrough_status 返回正确结构
# ============================================================================

func test_ac006_get_breakthrough_status_can_break() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	gsm.player.cultivation_full = true
	gsm.player.realm = 1
	gsm.player.overflow_pool = 200
	var status: Dictionary = cs.call("get_breakthrough_status")
	assert_eq(status["can_breakthrough"], true, "can_breakthrough=true")
	assert_eq(status["realm"], 1, "realm=1")
	assert_eq(status["cultivation_full"], true, "cultivation_full=true")
	assert_eq(status["overflow_pool"], 200, "overflow_pool=200")


func test_ac006_get_breakthrough_status_cannot_break() -> void:
	gsm.player.cultivation = 300
	gsm.player.max_cultivation = 1000
	gsm.player.cultivation_full = false
	gsm.player.realm = 2
	var status: Dictionary = cs.call("get_breakthrough_status")
	assert_eq(status["can_breakthrough"], false, "can_breakthrough=false")
	assert_eq(status["realm"], 2, "realm=2")
	assert_eq(status["cultivation_full"], false, "cultivation_full=false")
