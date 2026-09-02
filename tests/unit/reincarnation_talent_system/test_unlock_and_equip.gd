extends GutTest
## Story 7-7 验收测试：unlock_talent / get_active_talents。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 注入 ProgressionSystem mock
##   - 验证解锁编排、装备查询、effect 列表
##
## 设计文档来源：GDD reincarnation-talent-system.md §5/§6
## Story 来源：production/epics/reincarnation-talent-system/story-002-unlock-and-active-talents.md

const RTS := preload("res://src/feature/reincarnation_talent_system.gd")

var _progression_mock: Node = null


func before_each() -> void:
	_progression_mock = Node.new()
	_progression_mock.set_script(load("res://tests/unit/reincarnation_talent_system/progression_mock.gd"))
	RTS._progression_override = _progression_mock


func after_each() -> void:
	RTS._progression_override = null
	if _progression_mock != null:
		_progression_mock.free()
		_progression_mock = null


# ============================================================================
# AC-001：unlock_talent("cultivation_1") 点数充足 + 前置满足 → {success: true}
# ============================================================================

func test_unlock_talent_success() -> void:
	# Arrange
	_progression_mock._points = 20
	_progression_mock._purchase_result = {"success": true, "reason": ""}

	# Act
	var result: Dictionary = RTS.unlock_talent("cultivation_1")

	# Assert
	assert_true(result["success"], "点数充足 + 前置满足应返回 success: true")
	assert_eq(_progression_mock._last_purchase_id, "cultivation_1", "应委托 purchase_talent")


# ============================================================================
# AC-002：unlock_talent("cultivation_2") L1 未解锁 → {success: false, reason: "prerequisite_locked"}
# ============================================================================

func test_unlock_talent_prereq_not_met() -> void:
	# Arrange——_progression_mock 默认 unlocked 为空（L1 未解锁）
	_progression_mock._points = 100

	# Act
	var result: Dictionary = RTS.unlock_talent("cultivation_2")

	# Assert
	assert_false(result["success"], "L1 未解锁时 L2 不可解锁")
	assert_eq(str(result["reason"]), "prerequisite_locked", "reason 应为 prerequisite_locked")


# ============================================================================
# AC-003：unlock_talent 点数不足 → {success: false, reason: "insufficient_points"}
# ============================================================================

func test_unlock_talent_insufficient_points() -> void:
	# Arrange
	_progression_mock._points = 5  # cultivation_1 需要 8 点
	_progression_mock._purchase_result = {"success": false, "reason": "insufficient_points"}

	# Act
	var result: Dictionary = RTS.unlock_talent("cultivation_1")

	# Assert
	assert_false(result["success"], "点数不足应返回 success: false")
	assert_eq(str(result["reason"]), "insufficient_points", "reason 应为 insufficient_points")


# ============================================================================
# AC-004：unlock_talent L4 未满足软解锁条件 → {success: false, reason: "condition_not_met"}
# ============================================================================

func test_unlock_talent_condition_not_met() -> void:
	# Arrange——cultivation_4 需 highest_realm>=金丹，但 run_context 为空
	_progression_mock._points = 100
	_progression_mock._unlocked = ["cultivation_1", "cultivation_2", "cultivation_3"]

	# Act——run_context 不含 highest_realm_ever
	var result: Dictionary = RTS.unlock_talent("cultivation_4")

	# Assert
	assert_false(result["success"], "软解锁条件未满足应返回 success: false")
	assert_eq(str(result["reason"]), "condition_not_met", "reason 应为 condition_not_met")


# ============================================================================
# AC-005：unlock_talent("cultivation_1") 委托 ProgressionSystem.purchase_talent
# ============================================================================

func test_unlock_talent_delegates_to_purchase() -> void:
	# Arrange
	_progression_mock._points = 20
	_progression_mock._purchase_result = {"success": true, "reason": ""}
	_progression_mock._last_purchase_id = ""

	# Act
	RTS.unlock_talent("cultivation_1")

	# Assert
	assert_eq(_progression_mock._last_purchase_id, "cultivation_1", "应委托 purchase_talent(cultivation_1)")
	assert_eq(_progression_mock._purchase_call_count, 1, "应调用 purchase_talent 一次")


# ============================================================================
# AC-006：get_equipped_talents() 返回装备天赋的完整定义列表
# ============================================================================

func test_get_equipped_talents() -> void:
	# Arrange
	_progression_mock._equipped = ["cultivation_1", "combat_1"]

	# Act
	var equipped: Array = RTS.get_equipped_talents()

	# Assert
	assert_eq(equipped.size(), 2, "应返回 2 个装备天赋")
	assert_eq(str(equipped[0]["id"]), "cultivation_1", "第一个应为 cultivation_1")
	assert_eq(str(equipped[1]["id"]), "combat_1", "第二个应为 combat_1")


# ============================================================================
# AC-007：get_active_talents() 返回装备天赋的 effect 列表
# ============================================================================

func test_get_active_talents() -> void:
	# Arrange
	_progression_mock._equipped = ["cultivation_1", "combat_1"]

	# Act
	var effects: Array = RTS.get_active_talents()

	# Assert
	assert_eq(effects.size(), 2, "应返回 2 个 effect")
	assert_eq(str(effects[0]["type"]), "cultivation_boost", "第一个 effect type 应为 cultivation_boost")
	assert_eq(str(effects[1]["type"]), "start_cost", "第二个 effect type 应为 start_cost")


# ============================================================================
# AC-008：set_equipped(["cultivation_1"]) 槽位合法 → {success: true}
# ============================================================================

func test_set_equipped_valid() -> void:
	# Arrange
	_progression_mock._unlocked = ["cultivation_1"]
	_progression_mock._equip_result = {"success": true, "reason": ""}

	# Act
	var result: Dictionary = RTS.set_equipped(["cultivation_1"])

	# Assert
	assert_true(result["success"], "槽位合法应返回 success: true")


# ============================================================================
# AC-009：set_equipped 超出槽位 → {success: false, reason: "slot_exceeded"}
# ============================================================================

func test_set_equipped_exceeded() -> void:
	# Arrange
	_progression_mock._unlocked = ["cultivation_1", "combat_1"]
	_progression_mock._equip_result = {"success": false, "reason": "slot_exceeded"}

	# Act
	var result: Dictionary = RTS.set_equipped(["cultivation_1", "combat_1"])

	# Assert
	assert_false(result["success"], "超出槽位应返回 success: false")
	assert_eq(str(result["reason"]), "slot_exceeded", "reason 应为 slot_exceeded")


# ============================================================================
# AC-010：get_active_talents 未装备任何天赋时返回空数组
# ============================================================================

func test_get_active_talents_empty() -> void:
	# Arrange——_progression_mock 默认 equipped 为空

	# Act
	var effects: Array = RTS.get_active_talents()

	# Assert
	assert_eq(effects.size(), 0, "未装备任何天赋时应返回空数组")
