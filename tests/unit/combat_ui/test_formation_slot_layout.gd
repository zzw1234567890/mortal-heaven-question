extends GutTest
## combat-ui-layout Story 007 单元测试：境界→阵位布局映射（AC-4）。
##
## QA 规格（story QA Test Cases AC-2）：炼气(2,1)/筑基(2,2)/金丹(2,2)/
## 元婴(3,2)/化神(3,3)；slots 总数 ≥ max_deploy 不变量。
## 边缘：未知 realm → 显式报错（非静默默认）。
## manifest 禁令：映射必须数据驱动——五境界全枚举断言同时锁定表驱动语义。
##
## Story 类型 UI（Logic 内核）——此文件为 BLOCKING 证据。

const Rules := preload("res://src/ui/combat/shared/deploy_panel_rules.gd")
const RealmSystemScript := preload("res://src/core/realm_system.gd")
## 部署系统前端配额表（[b]取真源常量[/b]——审查 H4：不在测试内复制表值，
## 否则生产表改动时本测试仍全绿，等于只验证了自己）。
const DeploymentSystemScript := preload("res://src/feature/deployment_system.gd")


# ═══════════════════════════════════════════════════════════════════════════════
# 五境界逐项映射（GDD §8 明文）
# ═══════════════════════════════════════════════════════════════════════════════

func test_formation_slot_layout_qi_refining_returns_two_and_one() -> void:
	# Act
	var layout: Dictionary = Rules.formation_slot_layout(1)
	# Assert: 炼气 前2后1
	assert_eq(layout["front"], 2, "炼气期前排应为 2")
	assert_eq(layout["back"], 1, "炼气期后排应为 1")
	assert_eq(layout["total"], 3, "炼气期总阵位数应为 3")


func test_formation_slot_layout_foundation_returns_two_and_two() -> void:
	# Act
	var layout: Dictionary = Rules.formation_slot_layout(2)
	# Assert: 筑基 前2后2
	assert_eq(layout["front"], 2, "筑基期前排应为 2")
	assert_eq(layout["back"], 2, "筑基期后排应为 2")
	assert_eq(layout["total"], 4, "筑基期总阵位数应为 4")


func test_formation_slot_layout_golden_core_returns_two_and_two() -> void:
	# Act
	var layout: Dictionary = Rules.formation_slot_layout(3)
	# Assert: 金丹 前2后2
	assert_eq(layout["front"], 2, "金丹期前排应为 2")
	assert_eq(layout["back"], 2, "金丹期后排应为 2")


func test_formation_slot_layout_nascent_soul_returns_three_and_two() -> void:
	# Act
	var layout: Dictionary = Rules.formation_slot_layout(4)
	# Assert: 元婴 前3后2
	assert_eq(layout["front"], 3, "元婴期前排应为 3")
	assert_eq(layout["back"], 2, "元婴期后排应为 2")
	assert_eq(layout["total"], 5, "元婴期总阵位数应为 5")


func test_formation_slot_layout_spirit_severing_returns_three_and_three() -> void:
	# Act
	var layout: Dictionary = Rules.formation_slot_layout(5)
	# Assert: 化神 前3后3
	assert_eq(layout["front"], 3, "化神期前排应为 3")
	assert_eq(layout["back"], 3, "化神期后排应为 3")
	assert_eq(layout["total"], 6, "化神期总阵位数应为 6")


func test_formation_slot_layout_echoes_realm_id() -> void:
	# Act / Assert: 回显境界 ID（调用侧无需另存）
	for realm_id: int in range(1, 6):
		assert_eq(Rules.formation_slot_layout(realm_id)["realm_id"], realm_id,
				"布局应回显境界 ID %d" % realm_id)


# ═══════════════════════════════════════════════════════════════════════════════
# 不变量：slots 总数 ≥ max_deploy（QA 规格明文，炼气 3≥2）
# ═══════════════════════════════════════════════════════════════════════════════

func test_formation_slot_layout_total_covers_max_deploy_all_realms() -> void:
	# Arrange: RealmSystem.realm_table 是 max_deploy 的唯一真理来源
	var realm_table: Dictionary = RealmSystemScript.realm_table
	# Act / Assert: 逐境界校验 total ≥ max_deploy
	for realm_id: int in realm_table.keys():
		var max_deploy: int = int(realm_table[realm_id]["max_deploy"])
		var total: int = int(Rules.formation_slot_layout(int(realm_id))["total"])
		assert_true(total >= max_deploy,
				"境界 %d 阵位总数 %d 应 ≥ max_deploy %d" % [realm_id, total, max_deploy])


func test_formation_slot_layout_front_never_exceeds_deployment_front_capacity() -> void:
	# Arrange: DeploymentSystem 前排配额表（ADR-0016 阵位分布规则——取真源常量）
	var front_capacity: Dictionary = DeploymentSystemScript.FRONT_CAPACITY_BY_MAX_DEPLOY
	var realm_table: Dictionary = RealmSystemScript.realm_table
	# Act / Assert: 面板预览前排位数不得超过实际可部署前排配额（防预览与实际不符）
	for realm_id: int in realm_table.keys():
		var max_deploy: int = int(realm_table[realm_id]["max_deploy"])
		var front: int = int(Rules.formation_slot_layout(int(realm_id))["front"])
		var capacity: int = int(front_capacity.get(max_deploy, -1))
		assert_eq(front, capacity,
				"境界 %d 预览前排 %d 应等于部署系统前排配额 %d" % [realm_id, front, capacity])


func test_formation_slot_layout_covers_all_realm_table_entries() -> void:
	# Assert: 映射表覆盖 RealmSystem 全部境界（新增境界时此测试红——数据驱动守护）
	var realm_table: Dictionary = RealmSystemScript.realm_table
	assert_eq(Rules.FORMATION_SLOT_TABLE.size(), realm_table.size(),
			"阵位映射表条目数应与境界表一致")


# ═══════════════════════════════════════════════════════════════════════════════
# 边缘：未知境界显式报错（QA 规格：非静默默认）
# ═══════════════════════════════════════════════════════════════════════════════

func test_formation_slot_layout_unknown_realm_returns_empty() -> void:
	# Act: 未知境界
	var layout: Dictionary = Rules.formation_slot_layout(99)
	# Assert: 显式报错 + 返回空字典
	assert_push_error_count(1, "未知境界应 push_error 1 次（非静默默认）")
	assert_true(layout.is_empty(), "未知境界应返回空字典")


func test_formation_slot_layout_zero_realm_returns_empty() -> void:
	# Act / Assert: 0 不是合法境界 ID
	assert_true(Rules.formation_slot_layout(0).is_empty(), "境界 0 应返回空字典")
	assert_push_error_count(1, "境界 0 应 push_error 1 次")


func test_formation_slot_layout_negative_realm_returns_empty() -> void:
	# Act / Assert: 负值非法
	assert_true(Rules.formation_slot_layout(-1).is_empty(), "负境界应返回空字典")
	assert_push_error_count(1, "负境界应 push_error 1 次")


# ═══════════════════════════════════════════════════════════════════════════════
# 表驱动结构断言（manifest 禁令：禁止 if-elif 硬编码链）
# ═══════════════════════════════════════════════════════════════════════════════

func test_formation_slot_table_is_data_driven_dictionary() -> void:
	# Assert: 映射以 const Dictionary 承载（新增境界只改表不改函数体）
	assert_true(Rules.FORMATION_SLOT_TABLE is Dictionary, "阵位映射应为 Dictionary 常量")
	for realm_id: int in range(1, 6):
		var row: Dictionary = Rules.FORMATION_SLOT_TABLE[realm_id]
		assert_true(row.has("front") and row.has("back"),
				"境界 %d 表项应含 front/back 两键" % realm_id)


func test_formation_slot_table_rows_are_positive() -> void:
	# Assert: 每行前后排位数均为正（无 0 排的退化布局）
	for realm_id: int in Rules.FORMATION_SLOT_TABLE.keys():
		var row: Dictionary = Rules.FORMATION_SLOT_TABLE[realm_id]
		assert_gt(int(row["front"]), 0, "境界 %d 前排位数应为正" % realm_id)
		assert_gt(int(row["back"]), 0, "境界 %d 后排位数应为正" % realm_id)
