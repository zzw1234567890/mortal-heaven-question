extends GutTest
## Story 003 验收测试：settle_overflow + 突破后溢出结算。
##
## 覆盖 AC-001 到 AC-007（7 条 AC）。
## 测试策略：
##   - 使用 GSM Autoload + CultivationSystem 实例
##   - 设置 overflow_pool 后调用 settle_overflow
##   - 验证 pill_count 计算 + remaining 保留 + batch_updated 传播
##
## 设计文档来源：GDD §6-7 溢出结算 + §公式 2
## Story 来源：production/epics/cultivation-system/story-003-settle-overflow.md

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
	gsm.set("_signal_chain_depth", 0)
	gsm.get("_signal_router").set("_pending_changes", [])
	_batch_updates.clear()
	gsm.batch_updated.connect(_on_batch_updated)


func after_each() -> void:
	if gsm != null:
		if gsm.batch_updated.is_connected(_on_batch_updated):
			gsm.batch_updated.disconnect(_on_batch_updated)
		gsm.player.cultivation = 0
		gsm.player.max_cultivation = 1000
		gsm.player.cultivation_full = false
		gsm.player.overflow_pool = 0
	if cs != null:
		cs.free()
		cs = null
	_batch_updates.clear()


func _on_batch_updated(changes: Dictionary) -> void:
	_batch_updates.append(changes.duplicate(true))


func _flush() -> void:
	await get_tree().process_frame


# ============================================================================
# AC-001：settle_overflow 计算 pill_count
# ============================================================================

func test_ac001_settle_overflow_450() -> void:
	gsm.player.overflow_pool = 450
	var result: Dictionary = cs.call("settle_overflow")
	await _flush()
	assert_eq(result["pill_count"], 4, "450 → 4 属性丹")


func test_ac001_settle_overflow_large() -> void:
	gsm.player.overflow_pool = 1000
	var result: Dictionary = cs.call("settle_overflow")
	await _flush()
	assert_eq(result["pill_count"], 10, "1000 → 10 属性丹")


func test_ac001_settle_overflow_exact_multiple() -> void:
	gsm.player.overflow_pool = 300
	var result: Dictionary = cs.call("settle_overflow")
	await _flush()
	assert_eq(result["pill_count"], 3, "300 → 3 属性丹（整除）")


# ============================================================================
# AC-002：保留余数
# ============================================================================

func test_ac002_remaining_50() -> void:
	gsm.player.overflow_pool = 450
	var result: Dictionary = cs.call("settle_overflow")
	await _flush()
	assert_eq(result["remaining_overflow"], 50, "450 mod 100 = 50")
	assert_eq(gsm.player.overflow_pool, 50, "GSM overflow_pool 保留 50")


func test_ac002_remaining_zero_exact() -> void:
	gsm.player.overflow_pool = 500
	var result: Dictionary = cs.call("settle_overflow")
	await _flush()
	assert_eq(result["remaining_overflow"], 0, "500 mod 100 = 0（整除）")
	assert_eq(gsm.player.overflow_pool, 0, "GSM overflow_pool 为 0")


# ============================================================================
# AC-003：返回结构
# ============================================================================

func test_ac003_return_structure() -> void:
	gsm.player.overflow_pool = 250
	var result: Dictionary = cs.call("settle_overflow")
	assert_true(result.has("pill_count"), "含 pill_count")
	assert_true(result.has("remaining_overflow"), "含 remaining_overflow")
	assert_eq(result["pill_count"], 2, "pill_count=2")
	assert_eq(result["remaining_overflow"], 50, "remaining_overflow=50")


# ============================================================================
# AC-004：overflow_pool = 0
# ============================================================================

func test_ac004_zero_overflow() -> void:
	gsm.player.overflow_pool = 0
	var result: Dictionary = cs.call("settle_overflow")
	await _flush()
	assert_eq(result["pill_count"], 0, "overflow=0 → pill_count=0")
	assert_eq(result["remaining_overflow"], 0, "remaining=0")
	assert_eq(gsm.player.overflow_pool, 0, "GSM overflow_pool 仍为 0")


# ============================================================================
# AC-005：overflow_pool < 100
# ============================================================================

func test_ac005_less_than_100() -> void:
	gsm.player.overflow_pool = 50
	var result: Dictionary = cs.call("settle_overflow")
	await _flush()
	assert_eq(result["pill_count"], 0, "50 < 100 → pill_count=0")
	assert_eq(result["remaining_overflow"], 50, "remaining 保留 50")
	assert_eq(gsm.player.overflow_pool, 50, "GSM overflow_pool 保留 50")


func test_ac005_99_overflow() -> void:
	gsm.player.overflow_pool = 99
	var result: Dictionary = cs.call("settle_overflow")
	await _flush()
	assert_eq(result["pill_count"], 0, "99 < 100 → pill_count=0")
	assert_eq(result["remaining_overflow"], 99, "remaining 保留 99")


# ============================================================================
# AC-006：update_max_cultivation 触发 settle_overflow
# ============================================================================

func test_ac006_update_max_cultivation_realm_2() -> void:
	# 筑基 max_cultivation = 1000 × 1.5^1 = 1500
	gsm.player.overflow_pool = 250
	cs.call("update_max_cultivation", 2)
	await _flush()
	assert_eq(gsm.player.max_cultivation, 1500, "筑基 max_cultivation=1500")
	assert_eq(gsm.player.overflow_pool, 50, "settle_overflow 被触发：250→50")


func test_ac006_update_max_cultivation_realm_3() -> void:
	# 金丹 max_cultivation = 1000 × 1.5^2 = 2250
	gsm.player.overflow_pool = 0
	cs.call("update_max_cultivation", 3)
	await _flush()
	assert_eq(gsm.player.max_cultivation, 2250, "金丹 max_cultivation=2250")


func test_ac006_update_max_cultivation_triggers_settle() -> void:
	gsm.player.overflow_pool = 350
	cs.call("update_max_cultivation", 2)
	await _flush()
	# update_max_cultivation 应触发 settle_overflow
	assert_eq(gsm.player.overflow_pool, 50, "350 mod 100 = 50（settle 被触发）")


# ============================================================================
# AC-007：batch_updated 传播 overflow_pool 变更
# ============================================================================

func test_ac007_batch_updated_overflow_path() -> void:
	gsm.player.overflow_pool = 450
	cs.call("settle_overflow")
	await _flush()
	var found: bool = false
	for changes in _batch_updates:
		if changes.has("player.overflow_pool"):
			found = true
	assert_true(found, "batch_updated 含 player.overflow_pool 路径")


func test_ac007_batch_updated_correct_values() -> void:
	gsm.player.overflow_pool = 450
	cs.call("settle_overflow")
	await _flush()
	for changes in _batch_updates:
		if changes.has("player.overflow_pool"):
			assert_eq(changes["player.overflow_pool"]["old"], 450, "old=450")
			assert_eq(changes["player.overflow_pool"]["new"], 50, "new=50")


func test_ac007_batch_updated_max_cultivation_path() -> void:
	gsm.player.overflow_pool = 0
	cs.call("update_max_cultivation", 2)
	await _flush()
	var found: bool = false
	for changes in _batch_updates:
		if changes.has("player.max_cultivation"):
			found = true
	assert_true(found, "batch_updated 含 player.max_cultivation 路径")
