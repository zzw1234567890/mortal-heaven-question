extends GutTest
## Story 7-3 验收测试：ProgressionSystem talents 领域 API。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 直接实例化 ProgressionSystem
##   - 注册天赋定义后测试 purchase/grant/equip
##
## 设计文档来源：ADR-0012 §关键接口（talents 领域）
## Story 来源：production/epics/progression-system/story-003-talents-api.md

const PS := preload("res://src/meta/progression_system.gd")

var _save_load_mock: Node = null


func before_each() -> void:
	_save_load_mock = Node.new()
	_save_load_mock.set_script(load("res://tests/unit/progression_system/save_load_mock.gd"))


func after_each() -> void:
	if _save_load_mock != null:
		_save_load_mock.free()
		_save_load_mock = null


func _make_ps() -> Node:
	var ps: Node = PS.new()
	ps._save_load_override = _save_load_mock
	ps.initialize({})
	return ps


## 注册 3 个测试天赋。
func _register_test_talents(ps: Node) -> void:
	ps.register_talent("t1", {"name": "勤修苦练", "cost": 8, "branch": "cultivation", "layer": 1})
	ps.register_talent("t2", {"name": "厚积薄发", "cost": 12, "branch": "cultivation", "layer": 2, "prerequisite": "t1"})
	ps.register_talent("t3", {"name": "灵脉感应", "cost": 8, "branch": "resource", "layer": 1})


# ============================================================================
# AC-001：get_talent_points() 返回 _talents["points_available"]
# ============================================================================

func test_get_talent_points() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps._talents["points_available"] = 25

	# Act
	var points: int = ps.get_talent_points()

	# Assert
	assert_eq(points, 25, "应返回 points_available")

	# Cleanup
	ps.free()


# ============================================================================
# AC-002：add_talent_points(10) 递增 points_available + total_earned，_dirty=true
# ============================================================================

func test_add_talent_points() -> void:
	# Arrange
	var ps: Node = _make_ps()
	ps._talents["points_available"] = 5
	ps._talents["total_earned"] = 5

	# Act
	ps.add_talent_points(10)

	# Assert
	assert_eq(int(ps._talents["points_available"]), 15, "points_available 应为 15")
	assert_eq(int(ps._talents["total_earned"]), 15, "total_earned 应为 15")
	assert_true(ps.has_unsaved_changes(), "_dirty 应为 true")

	# Cleanup
	ps.free()


# ============================================================================
# AC-003：purchase_talent("t1") 点数充足 → {success: true}，扣除点数
# ============================================================================

func test_purchase_talent_success() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_talents(ps)
	ps._talents["points_available"] = 20

	# Act
	var result: Dictionary = ps.purchase_talent("t1")

	# Assert
	assert_true(result["success"], "点数充足应返回 success: true")
	assert_eq(int(ps._talents["points_available"]), 12, "应扣除 8 点（20-8=12）")
	assert_true(ps._talents["unlocked"].has("t1"), "t1 应在 unlocked 列表中")

	# Cleanup
	ps.free()


# ============================================================================
# AC-004：purchase_talent 点数不足 → {success: false, reason: "insufficient_points"}
# ============================================================================

func test_purchase_talent_insufficient_points() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_talents(ps)
	ps._talents["points_available"] = 5  # t1 需要 8 点

	# Act
	var result: Dictionary = ps.purchase_talent("t1")

	# Assert
	assert_false(result["success"], "点数不足应返回 success: false")
	assert_eq(str(result["reason"]), "insufficient_points", "reason 应为 insufficient_points")
	assert_eq(int(ps._talents["points_available"]), 5, "点数不应扣除")

	# Cleanup
	ps.free()


# ============================================================================
# AC-005：purchase_talent 已解锁 → {success: false, reason: "already_unlocked"}
# ============================================================================

func test_purchase_talent_already_unlocked() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_talents(ps)
	ps._talents["points_available"] = 100
	ps.purchase_talent("t1")

	# Act
	var result: Dictionary = ps.purchase_talent("t1")

	# Assert
	assert_false(result["success"], "已解锁应返回 success: false")
	assert_eq(str(result["reason"]), "already_unlocked", "reason 应为 already_unlocked")

	# Cleanup
	ps.free()


# ============================================================================
# AC-006：grant_talent("t1") 直接授予不扣点，幂等
# ============================================================================

func test_grant_talent_idempotent() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_talents(ps)
	ps._talents["points_available"] = 20

	# Act——第一次授予
	var result1: Dictionary = ps.grant_talent("t1")

	# Assert
	assert_true(result1["success"], "grant 应返回 success: true")
	assert_eq(int(ps._talents["points_available"]), 20, "grant 不扣点")
	assert_true(ps._talents["unlocked"].has("t1"), "t1 应在 unlocked 中")

	# Act——第二次授予（幂等）
	var result2: Dictionary = ps.grant_talent("t1")

	# Assert
	assert_true(result2["success"], "重复 grant 应返回 success: true（幂等）")

	# Cleanup
	ps.free()


# ============================================================================
# AC-007：get_active_slot_count() 返回 N = 5 + floor(unlocked_count / 4)
# ============================================================================

func test_get_active_slot_count() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_talents(ps)

	# 0 已解锁 → 5 槽位
	assert_eq(ps.get_active_slot_count(), 5, "0 解锁 → 5 槽位")

	# 解锁 4 个 → 5 + 1 = 6 槽位
	ps.grant_talent("t1")
	ps.grant_talent("t2")
	ps.grant_talent("t3")
	# 需要 4 个——注册第 4 个
	ps.register_talent("t4", {"name": "test4", "cost": 8, "branch": "combat", "layer": 1})
	ps.grant_talent("t4")
	assert_eq(ps.get_active_slot_count(), 6, "4 解锁 → 6 槽位")

	# Cleanup
	ps.free()


# ============================================================================
# AC-008：set_equipped_talents 槽位数合法 → {success: true}
# ============================================================================

func test_set_equipped_talents_valid() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_talents(ps)
	ps.grant_talent("t1")
	ps.grant_talent("t3")

	# Act——2 个天赋，槽位 5，合法
	var result: Dictionary = ps.set_equipped_talents(["t1", "t3"])

	# Assert
	assert_true(result["success"], "槽位合法应返回 success: true")
	assert_eq(ps._talents["equipped"].size(), 2, "equipped 应有 2 个")

	# Cleanup
	ps.free()


# ============================================================================
# AC-009：set_equipped_talents 超出槽位 → {success: false, reason: "slot_exceeded"}
# ============================================================================

func test_set_equipped_talents_exceeded() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_talents(ps)
	# 注册 7 个天赋以超出 5 槽位
	ps.register_talent("t4", {"name": "test4", "cost": 8, "branch": "combat", "layer": 1})
	ps.register_talent("t5", {"name": "test5", "cost": 8, "branch": "combat", "layer": 1})
	ps.register_talent("t6", {"name": "test6", "cost": 8, "branch": "combat", "layer": 1})
	ps.register_talent("t7", {"name": "test7", "cost": 8, "branch": "combat", "layer": 1})
	for i: int in range(1, 8):
		ps.grant_talent("t%d" % i)

	# Act——7 个天赋，槽位 5 + floor(7/4) = 5 + 1 = 6，超出
	var result: Dictionary = ps.set_equipped_talents(["t1", "t2", "t3", "t4", "t5", "t6", "t7"])

	# Assert
	assert_false(result["success"], "超出槽位应返回 success: false")
	assert_eq(str(result["reason"]), "slot_exceeded", "reason 应为 slot_exceeded")

	# Cleanup
	ps.free()


# ============================================================================
# AC-010：purchase_talent 发射 talent_purchased(id, points_remaining) 信号
# ============================================================================

func test_purchase_talent_emits_signal() -> void:
	# Arrange
	var ps: Node = _make_ps()
	_register_test_talents(ps)
	ps._talents["points_available"] = 20
	var received: Dictionary = {"id": "", "points": -1, "received": false}
	ps.talent_purchased.connect(func(talent_id: String, points_remaining: int):
		received["id"] = talent_id
		received["points"] = points_remaining
		received["received"] = true
	)

	# Act
	ps.purchase_talent("t1")

	# Assert
	assert_true(received["received"], "应发射 talent_purchased 信号")
	assert_eq(str(received["id"]), "t1", "信号参数 id 应为 t1")
	assert_eq(int(received["points"]), 12, "信号参数 points_remaining 应为 12")

	# Cleanup
	ps.free()
