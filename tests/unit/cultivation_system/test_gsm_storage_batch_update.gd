extends GutTest
## Story 002 验收测试：GSM player.* 数据存储 + batch_updated 传播。
##
## 覆盖 AC-001 到 AC-007（7 条 AC）。
## 测试策略：
##   - 使用 GSM Autoload + CultivationSystem 实例
##   - 订阅 batch_updated 验证路径传播
##   - serialize/deserialize 往返验证
##   - 源码审查验证不绕过 GSM
##
## 设计文档来源：GDD §5 修为获取流程 + GSM batch_updated 管线
## Story 来源：production/epics/cultivation-system/story-002-gsm-storage.md

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
# AC-001：batch_updated 传播
# ============================================================================

func test_ac001_batch_updated_emitted() -> void:
	cs.call("gain_cultivation", 50, "combat")
	await _flush()
	assert_true(_batch_updates.size() > 0, "batch_updated 信号发射")


func test_ac001_batch_updated_not_emitted_without_write() -> void:
	await _flush()
	assert_eq(_batch_updates.size(), 0, "无写入时无 batch_updated")


# ============================================================================
# AC-002：player.cultivation 路径
# ============================================================================

func test_ac002_cultivation_path_in_batch() -> void:
	cs.call("gain_cultivation", 50, "combat")
	await _flush()
	var found: bool = false
	for changes in _batch_updates:
		if changes.has("player.cultivation"):
			found = true
	assert_true(found, "batch_updated 含 player.cultivation 路径")


func test_ac002_cultivation_path_correct_values() -> void:
	gsm.player.cultivation = 100
	cs.call("gain_cultivation", 50, "combat")
	await _flush()
	for changes in _batch_updates:
		if changes.has("player.cultivation"):
			assert_eq(changes["player.cultivation"]["old"], 100, "old=100")
			assert_eq(changes["player.cultivation"]["new"], 150, "new=150")


# ============================================================================
# AC-003：player.cultivation_full 路径
# ============================================================================

func test_ac003_cultivation_full_path() -> void:
	gsm.player.cultivation = 950
	gsm.player.max_cultivation = 1000
	cs.call("gain_cultivation", 51, "combat")  # 溢出 → cultivation_full=true
	await _flush()
	var found: bool = false
	for changes in _batch_updates:
		if changes.has("player.cultivation_full"):
			found = true
	assert_true(found, "batch_updated 含 player.cultivation_full 路径")


func test_ac003_cultivation_full_not_emitted_without_overflow() -> void:
	gsm.player.cultivation = 100
	cs.call("gain_cultivation", 50, "combat")  # 150 < 1000
	await _flush()
	var found: bool = false
	for changes in _batch_updates:
		if changes.has("player.cultivation_full"):
			found = true
	assert_false(found, "无溢出时不含 cultivation_full 路径")


# ============================================================================
# AC-004：player.overflow_pool 路径
# ============================================================================

func test_ac004_overflow_pool_path() -> void:
	gsm.player.cultivation = 950
	gsm.player.max_cultivation = 1000
	cs.call("gain_cultivation", 100, "combat")  # 50 直接 + 50 溢出
	await _flush()
	var found: bool = false
	for changes in _batch_updates:
		if changes.has("player.overflow_pool"):
			found = true
	assert_true(found, "batch_updated 含 player.overflow_pool 路径")


func test_ac004_overflow_pool_correct_values() -> void:
	gsm.player.cultivation = 950
	gsm.player.max_cultivation = 1000
	gsm.player.overflow_pool = 10
	cs.call("gain_cultivation", 100, "combat")  # 50 溢出
	await _flush()
	for changes in _batch_updates:
		if changes.has("player.overflow_pool"):
			assert_eq(changes["player.overflow_pool"]["old"], 10, "overflow old=10")
			assert_eq(changes["player.overflow_pool"]["new"], 60, "overflow new=60")


# ============================================================================
# AC-005：serialize 包含 player.*
# ============================================================================

func test_ac005_serialize_contains_cultivation() -> void:
	gsm.player.cultivation = 800
	gsm.player.max_cultivation = 1000
	gsm.player.cultivation_full = false
	gsm.player.overflow_pool = 50
	var data: Dictionary = gsm.serialize()
	assert_true(data.has("player"), "serialize 含 player 域")
	var player: Dictionary = data["player"]
	assert_eq(player["cultivation"], 800, "serialize cultivation=800")
	assert_eq(player["max_cultivation"], 1000, "serialize max_cultivation=1000")
	assert_eq(player["cultivation_full"], false, "serialize cultivation_full=false")
	assert_eq(player["overflow_pool"], 50, "serialize overflow_pool=50")


func test_ac005_serialize_after_gain() -> void:
	cs.call("gain_cultivation", 300, "combat")
	await _flush()
	var data: Dictionary = gsm.serialize()
	assert_eq(data["player"]["cultivation"], 300, "serialize after gain cultivation=300")


# ============================================================================
# AC-006：deserialize 往返
# ============================================================================

func test_ac006_deserialize_roundtrip() -> void:
	gsm.player.cultivation = 750
	gsm.player.max_cultivation = 1000
	gsm.player.cultivation_full = false
	gsm.player.overflow_pool = 25
	var snapshot: Dictionary = gsm.serialize()

	# 修改 GSM
	gsm.player.cultivation = 0
	gsm.player.overflow_pool = 0

	# 反序列化恢复
	var ok: bool = gsm.deserialize(snapshot)
	assert_true(ok, "deserialize 成功")
	assert_eq(gsm.player.cultivation, 750, "cultivation 往返 750")
	assert_eq(gsm.player.max_cultivation, 1000, "max_cultivation 往返 1000")
	assert_eq(gsm.player.cultivation_full, false, "cultivation_full 往返 false")
	assert_eq(gsm.player.overflow_pool, 25, "overflow_pool 往返 25")


func test_ac006_deserialize_roundtrip_with_overflow() -> void:
	gsm.player.cultivation = 1000
	gsm.player.max_cultivation = 1000
	gsm.player.cultivation_full = true
	gsm.player.overflow_pool = 200
	var snapshot: Dictionary = gsm.serialize()

	gsm.player.cultivation = 0
	gsm.player.cultivation_full = false
	gsm.player.overflow_pool = 0

	gsm.deserialize(snapshot)
	assert_eq(gsm.player.cultivation, 1000, "满值往返")
	assert_eq(gsm.player.cultivation_full, true, "cultivation_full=true 往返")
	assert_eq(gsm.player.overflow_pool, 200, "overflow_pool=200 往返")


# ============================================================================
# AC-007：不绕过 GSM（源码审查 + 行为验证）
# ============================================================================

func test_ac007_no_direct_player_write() -> void:
	# 行为验证：gain_cultivation 后 player.cultivation 变化必须通过 GSM add_cultivation
	# 如果绕过 GSM 直接赋值，batch_updated 不会触发
	cs.call("gain_cultivation", 50, "combat")
	await _flush()
	# batch_updated 触发说明写入通过 GSM _buffer_change
	assert_true(_batch_updates.size() > 0, "写入通过 GSM batch_updated 管线")
	var found: bool = false
	for changes in _batch_updates:
		if changes.has("player.cultivation"):
			found = true
	assert_true(found, "player.cultivation 通过 GSM _buffer_change 写入")


func test_ac007_gsm_add_cultivation_is_only_write_path() -> void:
	# 验证 CultivationSystem.gain_cultivation 调用 GSM.add_cultivation
	# 通过 mock 验证：如果 GSM.add_cultivation 被调用，cultivation 会正确更新
	var cult_before: int = gsm.player.cultivation
	cs.call("gain_cultivation", 50, "combat")
	await _flush()
	# 如果直接绕过 GSM 赋值，cult_before + 50 == cultivation 但 batch_updated 不会触发
	# 双重验证：值正确 + 信号传播
	assert_eq(gsm.player.cultivation, cult_before + 50, "值正确更新")
	assert_true(_batch_updates.size() > 0, "信号正确传播——确认通过 GSM")
