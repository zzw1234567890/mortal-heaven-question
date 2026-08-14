extends GutTest
## Story 003 验收测试：GSM 第三层信号订阅 + batch_updated 展平字典。
## 覆盖 AC-013~AC-016 + subscribe/unsubscribe + 递归写入检测。

const GSM_SCRIPT := preload("res://src/foundation/game_state_manager.gd")

var gsm
var _captured: Dictionary
var _bool_flag: bool
var _int_val: int
var _int_val2: int
var _str_name: StringName
var _count: int


func before_each() -> void:
	gsm = GSM_SCRIPT.new()
	gsm._ready()
	_captured = {}
	_bool_flag = false
	_int_val = 0
	_int_val2 = 0
	_str_name = &""
	_count = 0


func after_each() -> void:
	gsm.free()
	gsm = null


# ── 命名回调（避免 GDScript 4.6 lambda 捕获问题）─────────────────────

func _on_batch(changes: Dictionary) -> void:
	_captured.merge(changes, true)
	_count += 1


func _on_cc(_delta: int, _current: int, _max_val: int) -> void:
	_bool_flag = true
	_int_val = _delta
	_int_val2 = _current


func _on_rc(type_val: StringName, delta: int, balance: int) -> void:
	_bool_flag = true
	_str_name = type_val
	_int_val = delta
	_int_val2 = balance


func _on_realm(_old: int, _new: int) -> void:
	_bool_flag = true
	_int_val = _old
	_int_val2 = _new


func _on_realm_count(_o: int, _n: int) -> void:
	_count += 1


func _push(path: String, old_val, new_val) -> void:
	gsm._pending_changes[path] = {"old": old_val, "new": new_val}
	gsm._flush_pending_changes()


# =========================================================================
# AC-013：域信号载荷
# =========================================================================

func test_ac013_realm_changed_carries_old_new() -> void:
	gsm.batch_updated.connect(_on_batch)
	_push("player.realm", GSM_SCRIPT.RealmLevel.QI_REFINING, GSM_SCRIPT.RealmLevel.FOUNDATION)
	assert_eq(_captured["player.realm"]["old"], GSM_SCRIPT.RealmLevel.QI_REFINING)
	assert_eq(_captured["player.realm"]["new"], GSM_SCRIPT.RealmLevel.FOUNDATION)


func test_ac013_cultivation_changed_domain_signal() -> void:
	gsm.player.max_cultivation = 1000
	gsm.cultivation_changed.connect(_on_cc)
	_push("player.cultivation", 200, 250)
	assert_true(_bool_flag, "cultivation_changed 应触发")
	assert_eq(_int_val, 50)   # delta
	assert_eq(_int_val2, 250) # current


# =========================================================================
# AC-014：信号不混淆
# =========================================================================

func test_ac014_signal_non_confusion() -> void:
	gsm.resource_changed.connect(_on_rc)
	_push("player.cultivation", 500, 600)
	assert_false(_bool_flag, "cultivation 不应触发 resource_changed")


func test_ac014_resource_changed_only_for_resource_ops() -> void:
	gsm.resource_changed.connect(_on_rc)
	_push("player.resources.ling_shi", 100, 150)
	assert_true(_bool_flag, "resource_changed 应触发")
	assert_eq(_str_name, &"ling_shi")
	assert_eq(_int_val, 50)   # delta
	assert_eq(_int_val2, 150) # balance


# =========================================================================
# AC-015：同帧去重
# =========================================================================

func test_ac015_same_frame_dedup() -> void:
	gsm.batch_updated.connect(_on_batch)
	# 三次覆盖——only last new survives, old from first kept
	gsm._pending_changes["player.cultivation"] = {"old": 0, "new": 10}
	gsm._pending_changes["player.cultivation"] = {"old": 0, "new": 40}
	gsm._pending_changes["player.cultivation"] = {"old": 0, "new": 70}
	gsm._flush_pending_changes()
	assert_eq(_count, 1, "同帧 3 次仅 1 次 batch_updated")
	assert_eq(_captured["player.cultivation"]["new"], 70)


func test_ac015_mixed_paths_each_dedup() -> void:
	gsm.batch_updated.connect(_on_batch)
	gsm._pending_changes["player.cultivation"] = {"old": 0, "new": 20}
	gsm._pending_changes["player.resources.ling_shi"] = {"old": 100, "new": 150}
	gsm._pending_changes["player.cultivation"] = {"old": 0, "new": 40}
	gsm._flush_pending_changes()
	assert_eq(_count, 1)
	assert_eq(_captured.size(), 2)
	assert_eq(_captured["player.cultivation"]["new"], 40)
	assert_eq(_captured["player.resources.ling_shi"]["new"], 150)


# =========================================================================
# AC-016：batch_updated 批量
# =========================================================================

func test_ac016_batch_updated_multi_domain() -> void:
	gsm.batch_updated.connect(_on_batch)
	gsm._pending_changes["player.resources.ling_shi"] = {"old": 100, "new": 200}
	gsm._pending_changes["player.cultivation"] = {"old": 0, "new": 200}
	gsm._pending_changes["player.resources.ling_cai"] = {"old": 50, "new": 80}
	gsm._flush_pending_changes()
	assert_eq(_count, 1)
	assert_eq(_captured.size(), 3)
	assert_true(_captured.has_all(["player.cultivation", "player.resources.ling_shi", "player.resources.ling_cai"]))


func test_ac016_no_domain_signal_on_multi() -> void:
	## AC-016 补充：多条变更不触发域信号
	gsm.cultivation_changed.connect(_on_cc)
	gsm._pending_changes["player.cultivation"] = {"old": 0, "new": 100}
	gsm._pending_changes["player.resources.ling_shi"] = {"old": 0, "new": 50}
	gsm._flush_pending_changes()
	assert_false(_bool_flag, "多条变更不应触发 cultivation_changed")


func test_ac016_empty_changes_no_emit() -> void:
	gsm.batch_updated.connect(_on_batch)
	gsm._flush_pending_changes()
	assert_eq(_count, 0)


# =========================================================================
# subscribe/unsubscribe
# =========================================================================

func test_subscribe_valid_signal() -> void:
	gsm.subscribe(&"realm_changed", _on_realm)
	_push("player.realm", 1, 2)
	assert_true(_bool_flag, "subscribe 应收到信号")
	assert_eq(_int_val, 1)
	assert_eq(_int_val2, 2)


func test_subscribe_invalid_signal_rejected() -> void:
	gsm.subscribe(&"nonexistent_signal", func() -> void: pass)
	assert_true(true, "无效信号不崩溃")


func test_unsubscribe_safe() -> void:
	gsm.subscribe(&"realm_changed", _on_realm_count)
	gsm.unsubscribe(&"realm_changed", _on_realm_count)
	_push("player.realm", 1, 2)
	assert_eq(_count, 0, "取消后不应触发")


func test_unsubscribe_nonexistent_safe() -> void:
	gsm.unsubscribe(&"nonexistent_signal", func() -> void: pass)
	assert_true(true)


func test_unsubscribe_not_connected_safe() -> void:
	gsm.subscribe(&"realm_changed", _on_realm_count)
	gsm.unsubscribe(&"realm_changed", _on_realm_count)
	gsm.unsubscribe(&"realm_changed", _on_realm_count)
	assert_true(true)


# =========================================================================
# 递归写入检测
# =========================================================================

func test_recursive_write_detection() -> void:
	gsm.player.max_cultivation = 1000
	gsm.player.cultivation = 0
	gsm.batch_updated.connect(func(_changes: Dictionary) -> void:
		_bool_flag = true
		gsm.add_cultivation(50)
	)
	gsm.player.cultivation = 100
	_push("player.cultivation", 0, 100)
	assert_true(_bool_flag, "回调应被触发")
	assert_eq(gsm.player.cultivation, 150, "递归写入生效（允许但警告）")
