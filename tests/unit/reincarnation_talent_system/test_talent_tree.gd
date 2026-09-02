extends GutTest
## Story 7-6 验收测试：ReincarnationTalentSystem 天赋树 + 查询 API。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 直接使用 const TALENT_TREE 验证天赋树定义
##   - 注入 ProgressionSystem mock
##   - 验证查询 API 和分支解锁规则
##
## 设计文档来源：GDD reincarnation-talent-system.md §3
## Story 来源：production/epics/reincarnation-talent-system/story-001-talent-tree.md

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
# AC-001：TALENT_TREE const 包含 20 个天赋节点
# ============================================================================

func test_talent_tree_has_20_nodes() -> void:
	# Act + Assert
	assert_eq(RTS.TALENT_TREE.size(), 20, "TALENT_TREE 应包含 20 个天赋节点")


# ============================================================================
# AC-002：get_talent_def("cultivation_1") 返回天赋定义
# ============================================================================

func test_get_talent_def() -> void:
	# Act
	var def: Dictionary = RTS.get_talent_def("cultivation_1")

	# Assert
	assert_eq(str(def["id"]), "cultivation_1", "应返回 id")
	assert_eq(str(def["name"]), "勤修苦练", "应返回 name")
	assert_eq(int(def["cost"]), 8, "应返回 cost=8")
	assert_eq(str(def["branch"]), "cultivation", "应返回 branch")
	assert_eq(int(def["layer"]), 1, "应返回 layer=1")
	assert_true(def.has("effect"), "应包含 effect")


# ============================================================================
# AC-003：get_branch_talents("cultivation") 返回 4 个天赋
# ============================================================================

func test_get_branch_talents() -> void:
	# Act
	var talents: Array = RTS.get_branch_talents("cultivation")

	# Assert
	assert_eq(talents.size(), 4, "cultivation 分支应有 4 个天赋")
	assert_eq(int(talents[0]["layer"]), 1, "第一个应为 L1")
	assert_eq(int(talents[1]["layer"]), 2, "第二个应为 L2")
	assert_eq(int(talents[2]["layer"]), 3, "第三个应为 L3")
	assert_eq(int(talents[3]["layer"]), 4, "第四个应为 L4")


# ============================================================================
# AC-004：get_full_tree_state() 返回完整状态
# ============================================================================

func test_get_full_tree_state() -> void:
	# Arrange
	_progression_mock._unlocked = ["cultivation_1", "resource_1"]
	_progression_mock._points = 25

	# Act
	var state: Dictionary = RTS.get_full_tree_state()

	# Assert
	assert_true(state.has("branches"), "应包含 branches")
	assert_true(state.has("unlocked"), "应包含 unlocked")
	assert_eq(int(state["points"]), 25, "应返回 points=25")
	assert_eq(int(state["branches"]["cultivation"]), 1, "cultivation 分支应解锁到 L1")
	assert_eq(int(state["branches"]["resource"]), 1, "resource 分支应解锁到 L1")
	assert_eq(int(state["branches"]["combat"]), 0, "combat 分支应为 0")


# ============================================================================
# AC-005：5 个分支各有 4 层
# ============================================================================

func test_five_branches_four_layers() -> void:
	for branch: String in ["cultivation", "resource", "combat", "card", "reincarnation"]:
		var talents: Array = RTS.get_branch_talents(branch)
		assert_eq(talents.size(), 4, "%s 分支应有 4 层" % branch)
		var layers: Array = []
		for t: Dictionary in talents:
			layers.append(int(t["layer"]))
		assert_eq(layers, [1, 2, 3, 4], "%s 分支层级应为 1-2-3-4" % branch)


# ============================================================================
# AC-006：L1 cost=8, L2 cost=12, L3 cost=18, L4 cost=25~35
# ============================================================================

func test_layer_costs() -> void:
	# L1 全部 cost=8
	for branch: String in ["cultivation", "resource", "combat", "card", "reincarnation"]:
		var l1: Dictionary = RTS.get_talent_def(branch + "_1")
		assert_eq(int(l1["cost"]), 8, "%s L1 cost 应为 8" % branch)

	# L2 全部 cost=12
	for branch: String in ["cultivation", "resource", "combat", "card"]:
		var l2: Dictionary = RTS.get_talent_def(branch + "_2")
		assert_eq(int(l2["cost"]), 12, "%s L2 cost 应为 12" % branch)

	# reincarnation L2 cost=14（特殊）
	var r2: Dictionary = RTS.get_talent_def("reincarnation_2")
	assert_eq(int(r2["cost"]), 14, "reincarnation L2 cost 应为 14")

	# L3——cultivation/resource/combat/card cost=18, reincarnation cost=20（特殊）
	for branch: String in ["cultivation", "resource", "combat", "card"]:
		var l3: Dictionary = RTS.get_talent_def(branch + "_3")
		assert_eq(int(l3["cost"]), 18, "%s L3 cost 应为 18" % branch)
	var r3: Dictionary = RTS.get_talent_def("reincarnation_3")
	assert_eq(int(r3["cost"]), 20, "reincarnation L3 cost 应为 20")

	# L4 cost 在 25~35 范围
	for branch: String in ["cultivation", "resource", "combat", "card", "reincarnation"]:
		var l4: Dictionary = RTS.get_talent_def(branch + "_4")
		var cost: int = int(l4["cost"])
		assert_true(cost >= 25 and cost <= 35, "%s L4 cost 应在 25~35 范围，实际 %d" % [branch, cost])


# ============================================================================
# AC-007：天赋总成本 = 333 点
# ============================================================================

func test_total_cost_333() -> void:
	# Act
	var total: int = 0
	for talent_id: String in RTS.TALENT_TREE:
		total += int(RTS.TALENT_TREE[talent_id]["cost"])

	# Assert
	assert_eq(total, RTS.TOTAL_COST, "天赋总成本应为 TOTAL_COST")
	assert_eq(total, 337, "天赋总成本应为 337")


# ============================================================================
# AC-008：can_unlock("cultivation_2") 在 L1 未解锁时返回 false
# ============================================================================

func test_can_unlock_prereq_not_met() -> void:
	# Arrange——_progression_mock 默认 unlocked 为空
	# Act
	var result: bool = RTS.can_unlock("cultivation_2")

	# Assert
	assert_false(result, "L1 未解锁时 L2 不可解锁")


# ============================================================================
# AC-009：can_unlock("cultivation_2") 在 L1 已解锁时返回 true
# ============================================================================

func test_can_unlock_prereq_met() -> void:
	# Arrange
	_progression_mock._unlocked = ["cultivation_1"]

	# Act
	var result: bool = RTS.can_unlock("cultivation_2")

	# Assert
	assert_true(result, "L1 已解锁时 L2 可解锁")


# ============================================================================
# AC-010：初始化时调用 ProgressionSystem.register_talent() 注册全部 20 个天赋
# ============================================================================

func test_initialize_registers_all_talents() -> void:
	# Arrange
	_progression_mock._registered_talents.clear()

	# Act
	RTS.initialize()

	# Assert
	assert_eq(_progression_mock._registered_talents.size(), 20, "应注册全部 20 个天赋")
	assert_true(_progression_mock._registered_talents.has("cultivation_1"), "应包含 cultivation_1")
	assert_true(_progression_mock._registered_talents.has("reincarnation_4"), "应包含 reincarnation_4")
