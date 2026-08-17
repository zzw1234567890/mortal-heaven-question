extends GutTest
## Story 001 验收测试：内部状态机 + 阵位数据管理（STANDBY→READY→ACTED）。
##
## 覆盖 AC-001 到 AC-018（18 条 AC）。
## 测试策略：
##   - DS_SCRIPT.new() 构造 DeploymentSystem 实例（不调 _ready，_init 已初始化 6 空位）
##   - 真实 RealmSystem Autoload + GSM Autoload——before_each 设置 player.realm 控制 max_deploy
##   - 动态分派：var ds: Node 持有，返回值显式类型注解（控制清单 2026-08-05 规则）
##   - FieldState 枚举经 DS_SCRIPT.FieldState 访问（preload 脚本 + 枚举，同 EventEnumsClass 先例）
##
## 设计文档来源：ADR-0016 §验证标准 §阵位数据模型 §关键接口
## Story 来源：production/epics/deployment-system/story-001-internal-state-machine.md

const DS_SCRIPT := preload("res://src/feature/deployment_system.gd")

var ds: Node = null


func before_each() -> void:
	ds = DS_SCRIPT.new()


func after_each() -> void:
	_reset_realm()
	if ds != null:
		ds.free()
		ds = null


func _set_realm(level: int) -> void:
	GameStateManager.player.realm = level


func _reset_realm() -> void:
	GameStateManager.player.realm = GameStateManager.RealmLevel.QI_REFINING


# ============================================================================
# AC-001：炼气期（max_deploy=2）自动分配前 2 后 0
# ============================================================================

func test_ac001_qi_refining_two_chars_all_front() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)  # max_deploy=2
	var ok: bool = ds.setup_field([101, 102], {})
	assert_true(ok, "2 人应成功上场")
	var field: Array = ds.get_field()
	assert_eq(field[0]["character_id"], 101, "slot 0 → 101")
	assert_eq(field[1]["character_id"], 102, "slot 1 → 102")
	assert_true(field[0]["is_front"], "slot 0 前排")
	assert_true(field[1]["is_front"], "slot 1 前排")
	for i in range(2, 6):
		assert_eq(field[i]["character_id"], -1, "slot %d 空位" % i)
		assert_eq(field[i]["state"], DS_SCRIPT.FieldState.EMPTY, "slot %d EMPTY" % i)


# ============================================================================
# AC-002：金丹期（max_deploy=4）自动分配前 2 后 2
# ============================================================================

func test_ac002_golden_core_four_chars_front2_back2() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)  # max_deploy=4
	var ok: bool = ds.setup_field([101, 102, 103, 104], {})
	assert_true(ok, "4 人应成功上场")
	var field: Array = ds.get_field()
	assert_true(field[0]["is_front"] and field[1]["is_front"], "slot 0/1 前排")
	assert_false(field[3]["is_front"], "slot 3 后排")
	assert_false(field[4]["is_front"], "slot 4 后排")
	assert_eq(field[2]["character_id"], -1, "slot 2 空位（前排末）")
	assert_eq(field[5]["character_id"], -1, "slot 5 空位（后排末）")
	assert_eq(field[3]["character_id"], 103, "slot 3 → 103")
	assert_eq(field[4]["character_id"], 104, "slot 4 → 104")


# ============================================================================
# AC-003：化神期（max_deploy=6）满阵
# ============================================================================

func test_ac003_spirit_transformation_six_chars_full_field() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)  # max_deploy=6
	var ok: bool = ds.setup_field([101, 102, 103, 104, 105, 106], {})
	assert_true(ok, "6 人应成功上场")
	var empty: Array = ds.get_empty_slots()
	assert_eq(empty.size(), 0, "满阵无空位")
	for i in range(3):
		assert_true(ds.get_field()[i]["is_front"], "slot %d 前排" % i)
	for i in range(3, 6):
		assert_false(ds.get_field()[i]["is_front"], "slot %d 后排" % i)


# ============================================================================
# AC-004：上场人数可少于上限（前 2 后 1）
# ============================================================================

func test_ac004_fewer_than_max_allowed() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)  # max_deploy=4
	var ok: bool = ds.setup_field([101, 102, 103], {})
	assert_true(ok, "3 人（< 4 上限）应成功")
	var field: Array = ds.get_field()
	assert_eq(field[0]["character_id"], 101, "slot 0 → 101")
	assert_eq(field[1]["character_id"], 102, "slot 1 → 102")
	assert_eq(field[3]["character_id"], 103, "slot 3 → 103（后排首）")
	assert_eq(field[2]["character_id"], -1, "slot 2 空位")
	assert_eq(field[4]["character_id"], -1, "slot 4 空位")
	assert_eq(field[5]["character_id"], -1, "slot 5 空位")


# ============================================================================
# AC-005：空选择拒绝
# ============================================================================

func test_ac005_empty_selection_rejected() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	var ok: bool = ds.setup_field([], {})
	assert_false(ok, "空数组应返回 false")
	# 阵位保持空置
	assert_eq(ds.get_empty_slots().size(), 6, "全部 6 阵位空置")


# ============================================================================
# AC-006：手动布局覆盖自动分配
# ============================================================================

func test_ac006_manual_layout_overrides_auto() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)  # max_deploy=4
	var ok: bool = ds.setup_field([101, 102, 103, 104], {101: false, 102: false})
	assert_true(ok, "手动布局应成功")
	var field: Array = ds.get_field()
	assert_false(ds.get_field()[ds.get_character_slot(101)]["is_front"], "101 手动后排")
	assert_false(ds.get_field()[ds.get_character_slot(102)]["is_front"], "102 手动后排")
	assert_true(ds.get_field()[ds.get_character_slot(103)]["is_front"], "103 自动前排")
	assert_true(ds.get_field()[ds.get_character_slot(104)]["is_front"], "104 自动前排")


# ============================================================================
# AC-007：人数超上限拒绝
# ============================================================================

func test_ac007_over_max_rejected() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)  # max_deploy=4
	var ok: bool = ds.setup_field([101, 102, 103, 104, 105], {})
	assert_false(ok, "5 人（> 4 上限）应返回 false")
	assert_eq(ds.get_empty_slots().size(), 6, "失败后阵位保持空置")


# ============================================================================
# AC-008：is_front 边界判定（slot 0/1/2 vs 3/4/5）
# ============================================================================

func test_ac008_is_front_boundary() -> void:
	# 未 setup_field 的空位也有正确 is_front（_reset_field 设置）
	var field: Array = ds.get_field()
	for i in range(3):
		assert_true(field[i]["is_front"], "slot %d 前排" % i)
	for i in range(3, 6):
		assert_false(field[i]["is_front"], "slot %d 后排" % i)


# ============================================================================
# AC-009：setup_field 后全部 STANDBY
# ============================================================================

func test_ac009_all_standby_after_setup() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.setup_field([101, 102], {})
	var field: Array = ds.get_field()
	for i in range(2):
		assert_eq(field[i]["state"], DS_SCRIPT.FieldState.STANDBY, "上场角色 state==STANDBY")


# ============================================================================
# AC-010：is_standby 查询
# ============================================================================

func test_ac010_is_standby_query() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102], {})
	assert_true(ds.is_standby(101), "STANDBY 角色 → true")
	# 手动将 102 置 READY
	ds._field[ds.get_character_slot(102)]["state"] = DS_SCRIPT.FieldState.READY
	assert_false(ds.is_standby(102), "READY 角色 → false")
	assert_false(ds.is_standby(999), "未上场角色 → false")


# ============================================================================
# AC-011：set_acted 状态转换
# ============================================================================

func test_ac011_set_acted_ready_to_acted() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.setup_field([101], {})
	var slot: int = ds.get_character_slot(101)
	ds._field[slot]["state"] = DS_SCRIPT.FieldState.READY
	ds.set_acted(101)
	assert_eq(ds._field[slot]["state"], DS_SCRIPT.FieldState.ACTED, "READY → ACTED")


func test_ac011_set_acted_non_ready_unchanged() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.setup_field([101], {})
	var slot: int = ds.get_character_slot(101)
	# STANDBY 状态调用 set_acted 不应改变
	ds.set_acted(101)
	assert_eq(ds._field[slot]["state"], DS_SCRIPT.FieldState.STANDBY, "STANDBY 不变")
	# 未上场角色调用 set_acted 无副作用
	ds.set_acted(999)


func test_ac011_set_acted_dead_and_empty_unchanged() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102], {})  # slot 0、1 前排
	var slot: int = ds.get_character_slot(101)
	ds._field[slot]["state"] = DS_SCRIPT.FieldState.DEAD
	ds.set_acted(101)
	assert_eq(ds._field[slot]["state"], DS_SCRIPT.FieldState.DEAD, "DEAD 不变")
	# 空位（character_id=-1）调用 set_acted 无副作用——不应改变任何阵位
	ds.set_acted(-1)
	assert_eq(ds._field[slot]["state"], DS_SCRIPT.FieldState.DEAD, "空位 set_acted 无副作用")


# ============================================================================
# AC-012：get_field 结构与排序
# ============================================================================

func test_ac012_get_field_structure_and_order() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)
	ds.setup_field([101, 102, 103], {})
	var field: Array = ds.get_field()
	assert_eq(field.size(), 6, "返回 6 项")
	for i in range(6):
		assert_eq(field[i]["slot_index"], i, "按 slot_index 升序")
		assert_true(field[i].has("character_id"), "含 character_id")
		assert_true(field[i].has("is_front"), "含 is_front")
		assert_true(field[i].has("state"), "含 state")
		assert_true(field[i].has("deploy_turn"), "含 deploy_turn")
	# 空位 deploy_turn == -1
	assert_eq(field[2]["deploy_turn"], -1, "空位 deploy_turn=-1")
	assert_eq(field[2]["character_id"], -1, "空位 character_id=-1")
	assert_eq(field[2]["state"], DS_SCRIPT.FieldState.EMPTY, "空位 EMPTY")


# ============================================================================
# AC-013：get_character_slot 查询
# ============================================================================

func test_ac013_get_character_slot() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds.setup_field([101, 102], {})
	assert_eq(ds.get_character_slot(101), 0, "101 在 slot 0")
	assert_eq(ds.get_character_slot(102), 1, "102 在 slot 1")
	assert_eq(ds.get_character_slot(999), -1, "未上场 → -1")


# ============================================================================
# AC-014：get_front_count 存活/占用计数
# ============================================================================

func test_ac014_get_front_count_alive_vs_occupied() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	ds.setup_field([101, 102, 103], {})  # 前 3 全前排
	# 将 1 人置 DEAD
	ds._field[1]["state"] = DS_SCRIPT.FieldState.DEAD
	assert_eq(ds.get_front_count(true), 2, "存活前排 2")
	assert_eq(ds.get_front_count(false), 3, "占用前排 3（含 DEAD）")


func test_ac014_get_front_count_all_dead_returns_zero() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	ds.setup_field([101, 102, 103], {})  # 前 3 全前排
	for i in range(3):
		ds._field[i]["state"] = DS_SCRIPT.FieldState.DEAD
	assert_eq(ds.get_front_count(true), 0, "前排全灭存活计数 0（front_line_breached 触发条件）")
	assert_eq(ds.get_front_count(false), 3, "占用计数仍 3")


# ============================================================================
# AC-015：get_empty_slots 前排优先
# ============================================================================

func test_ac015_get_empty_slots_front_first() -> void:
	_set_realm(GameStateManager.RealmLevel.GOLDEN_CORE)  # max_deploy=4，前排配额 2
	# 4 人自动分配占 slot 0,1（前排）+ slot 3,4（后排）→ 空 slot 2,5
	ds.setup_field([101, 102, 103, 104], {})
	var empty: Array = ds.get_empty_slots()
	assert_eq(empty, [2, 5], "空位前排优先：[2, 5]")


# ============================================================================
# AC-016：can_deploy 结果结构
# ============================================================================

func test_ac016_can_deploy_result() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)  # max_deploy=6
	ds.setup_field([101, 102, 103, 104], {})  # 已上场 4 人
	var result: Dictionary = ds.can_deploy()
	assert_true(result["can_deploy"], "有 2 空位且未满 → true")
	assert_eq(result["empty_slots"], 2, "empty_slots=2")
	assert_eq(result["max_deploy"], 6, "max_deploy=6")
	assert_true(result["reason"] is String, "reason 是 String")


func test_ac016_can_deploy_full_rejected() -> void:
	_set_realm(GameStateManager.RealmLevel.SPIRIT_TRANSFORMATION)
	ds.setup_field([101, 102, 103, 104, 105, 106], {})
	var result: Dictionary = ds.can_deploy()
	assert_false(result["can_deploy"], "满员 → false")
	assert_eq(result["empty_slots"], 0, "empty_slots=0")


# ============================================================================
# AC-017：front_line_breached 标志重置
# ============================================================================

func test_ac017_front_line_breached_flag_reset() -> void:
	_set_realm(GameStateManager.RealmLevel.QI_REFINING)
	ds._front_line_breached_emitted = true
	ds.setup_field([101], {})
	assert_false(ds._front_line_breached_emitted, "setup_field 重置标志为 false")


# ============================================================================
# AC-018：extends Node + 不声明 class_name
# ============================================================================

func test_ac018_extends_node_no_class_name() -> void:
	var script: GDScript = load("res://src/feature/deployment_system.gd")
	assert_eq(script.get_instance_base_type(), "Node", "DeploymentSystem 应继承 Node")
	assert_eq(ds.get_class(), "Node", "实例应为 Node 类型")
