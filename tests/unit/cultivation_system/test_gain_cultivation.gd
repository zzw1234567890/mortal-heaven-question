extends GutTest
## Story 001 验收测试：gain_cultivation 统一获取入口 + 溢出判定。
##
## 覆盖 AC-001 到 AC-007（7 条 AC）。
## 测试策略：
##   - 使用 GSM Autoload（非独立实例）
##   - 通过 CultivationSystem.gain_cultivation 委托 GSM
##   - 验证溢出逻辑 + 信号传播 + 查询接口
##
## 设计文档来源：GDD cultivation-system.md §5 修为获取流程
## Story 来源：production/epics/cultivation-system/story-001-gain-cultivation.md

const CS_SCRIPT := preload("res://src/feature/cultivation_system.gd")

var cs: Node = null
var gsm: Node = null
var _cult_changed: Array = []
var _cult_full: Array = []
var _batch_updates: Array = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	gsm = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/GameStateManager")
	if gsm == null:
		fail_test("GSM Autoload 未注册")
		return
	# 重置 player 修为状态
	gsm.player.cultivation = 0
	gsm.player.max_cultivation = 1000
	gsm.player.cultivation_full = false
	gsm.player.overflow_pool = 0
	gsm.set("_signal_chain_depth", 0)
	gsm.get("_signal_router").set("_pending_changes", [])
	_cult_changed.clear()
	_cult_full.clear()
	_batch_updates.clear()
	gsm.cultivation_changed.connect(_on_cultivation_changed)
	gsm.cultivation_full.connect(_on_cultivation_full)
	gsm.batch_updated.connect(_on_batch_updated)


func after_each() -> void:
	if gsm != null:
		if gsm.cultivation_changed.is_connected(_on_cultivation_changed):
			gsm.cultivation_changed.disconnect(_on_cultivation_changed)
		if gsm.cultivation_full.is_connected(_on_cultivation_full):
			gsm.cultivation_full.disconnect(_on_cultivation_full)
		if gsm.batch_updated.is_connected(_on_batch_updated):
			gsm.batch_updated.disconnect(_on_batch_updated)
		gsm.player.cultivation = 0
		gsm.player.max_cultivation = 1000
		gsm.player.cultivation_full = false
		gsm.player.overflow_pool = 0
	if cs != null:
		cs.free()
		cs = null
	_cult_changed.clear()
	_cult_full.clear()
	_batch_updates.clear()


func _on_cultivation_changed(delta: int, new_val: int, max_val: int) -> void:
	_cult_changed.append({"delta": delta, "new_val": new_val, "max": max_val})


func _on_cultivation_full(is_full: bool, max_val: int) -> void:
	_cult_full.append({"is_full": is_full, "max": max_val})


func _on_batch_updated(changes: Dictionary) -> void:
	_batch_updates.append(changes.duplicate(true))


## 刷新 GSM 帧末缓冲。
func _flush() -> void:
	await get_tree().process_frame


# ============================================================================
# AC-001：gain_cultivation 统一入口
# ============================================================================

func test_ac001_gain_cultivation_increases() -> void:
	cs.call("gain_cultivation", 50, "combat")
	await _flush()
	assert_eq(gsm.player.cultivation, 50, "修为增加 50")


func test_ac001_gain_cultivation_multiple_sources() -> void:
	cs.call("gain_cultivation", 30, "combat")
	cs.call("gain_cultivation", 20, "pill")
	cs.call("gain_cultivation", 10, "event")
	await _flush()
	assert_eq(gsm.player.cultivation, 60, "多来源累积 30+20+10=60")


# ============================================================================
# AC-002：溢出判定
# ============================================================================

func test_ac002_overflow_partial() -> void:
	gsm.player.cultivation = 950
	gsm.player.max_cultivation = 1000
	cs.call("gain_cultivation", 100, "combat")  # 50 直接加 + 50 溢出
	await _flush()
	assert_eq(gsm.player.cultivation, 1000, "修为锁死在 max")
	assert_eq(gsm.player.overflow_pool, 50, "溢出 50 存入 overflow_pool")


func test_ac002_overflow_full_already() -> void:
	gsm.player.cultivation = 1000
	gsm.player.cultivation_full = true
	gsm.player.max_cultivation = 1000
	cs.call("gain_cultivation", 100, "combat")
	await _flush()
	assert_eq(gsm.player.cultivation, 1000, "已满不再增加")
	assert_eq(gsm.player.overflow_pool, 100, "全部溢出")


func test_ac002_overflow_large_amount() -> void:
	gsm.player.cultivation = 900
	gsm.player.max_cultivation = 1000
	cs.call("gain_cultivation", 500, "combat")  # 100 直接加 + 400 溢出
	await _flush()
	assert_eq(gsm.player.cultivation, 1000, "修为锁死")
	assert_eq(gsm.player.overflow_pool, 400, "溢出 400")


# ============================================================================
# AC-003：amount <= 0 拒绝
# ============================================================================

func test_ac003_zero_amount_rejected() -> void:
	var cult_before: int = gsm.player.cultivation
	cs.call("gain_cultivation", 0, "test")
	await _flush()
	assert_eq(gsm.player.cultivation, cult_before, "amount=0 修为不变")


func test_ac003_negative_amount_rejected() -> void:
	var cult_before: int = gsm.player.cultivation
	cs.call("gain_cultivation", -10, "test")
	await _flush()
	assert_eq(gsm.player.cultivation, cult_before, "amount=-10 修为不变")


# ============================================================================
# AC-004：修为满值信号
# ============================================================================

func test_ac004_cultivation_full_signal() -> void:
	gsm.player.cultivation = 950
	gsm.player.max_cultivation = 1000
	cs.call("gain_cultivation", 51, "combat")  # 50 直接加 + 1 溢出 → 触发 cultivation_full
	await _flush()
	# cultivation_full 信号在 _flush_pending_changes 中通过 _emit_domain_signal 发射
	# 但只有当 changes.size() == 1 时才调用 _emit_domain_signal
	# add_cultivation 溢出路径 buffer 了 cultivation + cultivation_full + overflow_pool 3 条 → size=3 → 仅 batch_updated
	# cultivation_full 信号通过 batch_updated 传播验证
	var found_full: bool = false
	for changes in _batch_updates:
		if changes.has("player.cultivation_full"):
			found_full = true
	assert_true(found_full, "batch_updated 含 player.cultivation_full 路径")
	assert_eq(gsm.player.cultivation_full, true, "cultivation_full 已设为 true")


func test_ac004_cultivation_full_not_emitted_when_not_full() -> void:
	gsm.player.cultivation = 100
	gsm.player.max_cultivation = 1000
	cs.call("gain_cultivation", 50, "combat")  # 150 < 1000
	await _flush()
	assert_eq(_cult_full.size(), 0, "未满不发射 cultivation_full")


# ============================================================================
# AC-005：cultivation_changed 信号
# ============================================================================

func test_ac005_cultivation_changed_signal() -> void:
	gsm.player.cultivation = 100
	gsm.player.max_cultivation = 1000
	cs.call("gain_cultivation", 50, "combat")
	await _flush()
	assert_true(_cult_changed.size() > 0, "cultivation_changed 信号发射")
	assert_eq(_cult_changed[0]["delta"], 50, "delta=50")
	assert_eq(_cult_changed[0]["new_val"], 150, "new_val=150")
	assert_eq(_cult_changed[0]["max"], 1000, "max=1000")


# ============================================================================
# AC-006：check_cultivation_full
# ============================================================================

func test_ac006_check_full_true() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	assert_eq(cs.call("check_cultivation_full"), true, "满值时 true")


func test_ac006_check_full_false() -> void:
	gsm.player.cultivation = 800
	gsm.player.max_cultivation = 1000
	assert_eq(cs.call("check_cultivation_full"), false, "未满时 false")


func test_ac006_check_full_at_max() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	assert_eq(cs.call("check_cultivation_full"), true, "恰好满值 true")


# ============================================================================
# AC-007：get_cultivation_status
# ============================================================================

func test_ac007_get_status() -> void:
	gsm.player.cultivation = 800
	gsm.player.max_cultivation = 1000
	gsm.player.overflow_pool = 50
	var status: Dictionary = cs.call("get_cultivation_status")
	assert_eq(status["current"], 800, "current=800")
	assert_eq(status["max"], 1000, "max=1000")
	assert_eq(status["overflow_pool"], 50, "overflow_pool=50")
	assert_eq(status["is_full"], false, "is_full=false")


func test_ac007_get_status_full() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	gsm.player.overflow_pool = 200
	var status: Dictionary = cs.call("get_cultivation_status")
	assert_eq(status["current"], 1000, "current=1000")
	assert_eq(status["max"], 1000, "max=1000")
	assert_eq(status["overflow_pool"], 200, "overflow_pool=200")
	assert_eq(status["is_full"], true, "is_full=true")
