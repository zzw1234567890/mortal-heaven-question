extends GutTest
## Story 001 验收测试：RealmSystem Autoload + realm_table 数据表 + 查询接口。
##
## 覆盖 AC-001 到 AC-015（15 条 AC）。
## 测试策略：
##   - RS_SCRIPT.new() 构造 RealmSystem 实例（不调 _ready，纯查询方法无副作用）
##   - 真实 GSM Autoload——before_each/after_each 清理 player.realm 状态
##   - 动态分派：var rs: Node 持有，返回值显式类型注解（控制清单 2026-08-05 规则）

const RS_SCRIPT := preload("res://src/core/realm_system.gd")

var rs: Node = null


func before_each() -> void:
	rs = RS_SCRIPT.new()
	_reset_gsm_state()


func after_each() -> void:
	if rs != null:
		rs.free()
		rs = null
	_reset_gsm_state()


func _reset_gsm_state() -> void:
	GameStateManager.player.realm = GameStateManager.RealmLevel.QI_REFINING


# ============================================================================
# AC-001：RealmSystem extends Node，不声明 class_name
# ============================================================================

func test_ac001_realm_system_extends_node_no_class_name() -> void:
	var script: GDScript = load("res://src/core/realm_system.gd")
	assert_eq(script.get_instance_base_type(), "Node", "RealmSystem 应继承 Node")
	# 源码中无顶层 class_name 声明（多行模式匹配行首）
	var source: String = FileAccess.get_file_as_string("res://src/core/realm_system.gd")
	var regex := RegEx.new()
	regex.compile("(?m)^class_name\\s+\\w+")
	assert_eq(regex.search(source), null, "源码不应有顶层 class_name 声明")
	# 确认使用动态分派模式
	assert_eq(rs.get_class(), "Node", "实例应为 Node 类型")


# ============================================================================
# AC-002：realm_table 含 5 境界 × 12 属性
# ============================================================================

func test_ac002_realm_table_has_five_realms_ten_properties() -> void:
	var table: Dictionary = rs.realm_table
	assert_eq(table.size(), 5, "realm_table 应含 5 个境界")
	# 每个境界的属性 Dictionary 含 12 个键
	var expected_keys: Array = ["name", "max_cultivation", "max_deploy", "cost_per_turn",
		"deck_limit", "action_points", "base_speed", "max_darkgold",
		"card_pool_tier", "map_unlock", "gongfa_slots", "fabao_slots"]
	for level: int in range(1, 6):
		assert_true(table.has(level), "应含境界 %d" % level)
		var realm_data: Dictionary = table[level]
		assert_eq(realm_data.size(), 12, "境界 %d 应含 12 个属性" % level)
		for key: String in expected_keys:
			assert_true(realm_data.has(key), "境界 %d 应含属性 '%s'" % [level, key])


# ============================================================================
# AC-003：L=1 炼气期属性值正确
# ============================================================================

func test_ac003_level1_qi_refining_values() -> void:
	var d: Dictionary = rs.realm_table[1]
	assert_eq(d["name"], "炼气期", "name 应为 炼气期")
	assert_eq(d["max_cultivation"], 1000, "max_cultivation 应为 1000")
	assert_eq(d["max_deploy"], 2, "max_deploy 应为 2")
	assert_eq(d["cost_per_turn"], 2, "cost_per_turn 应为 2")
	assert_eq(d["deck_limit"], 20, "deck_limit 应为 20")
	assert_eq(d["action_points"], 5, "action_points 应为 5")
	assert_eq(d["base_speed"], 1, "base_speed 应为 1")
	assert_eq(d["max_darkgold"], 0, "max_darkgold 应为 0")
	assert_eq(d["card_pool_tier"], 1, "card_pool_tier 应为 1")
	assert_eq(d["map_unlock"], "青云剑宗", "map_unlock 应为 青云剑宗")
	assert_eq(d["gongfa_slots"], 1, "gongfa_slots 应为 1")
	assert_eq(d["fabao_slots"], 1, "fabao_slots 应为 1")


# ============================================================================
# AC-004：L=3 金丹期属性值正确
# ============================================================================

func test_ac004_level3_golden_core_values() -> void:
	var d: Dictionary = rs.realm_table[3]
	assert_eq(d["name"], "金丹期", "name 应为 金丹期")
	assert_eq(d["max_cultivation"], 2250, "max_cultivation 应为 2250")
	assert_eq(d["max_deploy"], 4, "max_deploy 应为 4")
	assert_eq(d["cost_per_turn"], 8, "cost_per_turn 应为 8")
	assert_eq(d["deck_limit"], 30, "deck_limit 应为 30")
	assert_eq(d["action_points"], 9, "action_points 应为 9")
	assert_eq(d["base_speed"], 3, "base_speed 应为 3")
	assert_eq(d["max_darkgold"], 1, "max_darkgold 应为 1")
	assert_eq(d["card_pool_tier"], 3, "card_pool_tier 应为 3")
	assert_eq(d["map_unlock"], "东域", "map_unlock 应为 东域")
	assert_eq(d["gongfa_slots"], 2, "gongfa_slots 应为 2")
	assert_eq(d["fabao_slots"], 2, "fabao_slots 应为 2")


# ============================================================================
# AC-005：L=5 化神期属性值正确
# ============================================================================

func test_ac005_level5_spirit_severing_values() -> void:
	var d: Dictionary = rs.realm_table[5]
	assert_eq(d["name"], "化神期", "name 应为 化神期")
	assert_eq(d["max_cultivation"], 5063, "max_cultivation 应为 5063")
	assert_eq(d["max_deploy"], 6, "max_deploy 应为 6")
	assert_eq(d["cost_per_turn"], 14, "cost_per_turn 应为 14")
	assert_eq(d["deck_limit"], 40, "deck_limit 应为 40")
	assert_eq(d["action_points"], 13, "action_points 应为 13")
	assert_eq(d["base_speed"], 5, "base_speed 应为 5")
	assert_eq(d["max_darkgold"], 2, "max_darkgold 应为 2")
	assert_eq(d["card_pool_tier"], 5, "card_pool_tier 应为 5")
	assert_eq(d["map_unlock"], "最终战场", "map_unlock 应为 最终战场")
	assert_eq(d["gongfa_slots"], 3, "gongfa_slots 应为 3")
	assert_eq(d["fabao_slots"], 3, "fabao_slots 应为 3")


# ============================================================================
# AC-002 补充：L2 筑基期 / L4 元婴期 基准值验证（const 不可变性回归保护）
# ============================================================================

func test_ac002_level2_foundation_values() -> void:
	# S-M1: L2 筑基期 10 属性逐一断言——防止 const 被意外修改
	var d: Dictionary = rs.realm_table[2]
	assert_eq(d["name"], "筑基期", "L2 name 应为 筑基期")
	assert_eq(d["max_cultivation"], 1500, "L2 max_cultivation 应为 1500")
	assert_eq(d["max_deploy"], 3, "L2 max_deploy 应为 3")
	assert_eq(d["cost_per_turn"], 5, "L2 cost_per_turn 应为 5")
	assert_eq(d["deck_limit"], 25, "L2 deck_limit 应为 25")
	assert_eq(d["action_points"], 7, "L2 action_points 应为 7")
	assert_eq(d["base_speed"], 2, "L2 base_speed 应为 2")
	assert_eq(d["max_darkgold"], 0, "L2 max_darkgold 应为 0")
	assert_eq(d["card_pool_tier"], 2, "L2 card_pool_tier 应为 2")
	assert_eq(d["map_unlock"], "碎星群岛", "L2 map_unlock 应为 碎星群岛")
	assert_eq(d["gongfa_slots"], 2, "L2 gongfa_slots 应为 2")
	assert_eq(d["fabao_slots"], 2, "L2 fabao_slots 应为 2")


func test_ac002_level4_nascent_soul_values() -> void:
	# S-M1: L4 元婴期 10 属性逐一断言——防止 const 被意外修改
	var d: Dictionary = rs.realm_table[4]
	assert_eq(d["name"], "元婴期", "L4 name 应为 元婴期")
	assert_eq(d["max_cultivation"], 3375, "L4 max_cultivation 应为 3375")
	assert_eq(d["max_deploy"], 5, "L4 max_deploy 应为 5")
	assert_eq(d["cost_per_turn"], 11, "L4 cost_per_turn 应为 11")
	assert_eq(d["deck_limit"], 35, "L4 deck_limit 应为 35")
	assert_eq(d["action_points"], 11, "L4 action_points 应为 11")
	assert_eq(d["base_speed"], 4, "L4 base_speed 应为 4")
	assert_eq(d["max_darkgold"], 2, "L4 max_darkgold 应为 2")
	assert_eq(d["card_pool_tier"], 4, "L4 card_pool_tier 应为 4")
	assert_eq(d["map_unlock"], "归墟之境", "L4 map_unlock 应为 归墟之境")
	assert_eq(d["gongfa_slots"], 3, "L4 gongfa_slots 应为 3")
	assert_eq(d["fabao_slots"], 3, "L4 fabao_slots 应为 3")


# ============================================================================
# AC-006：get_realm_property O(1) 字典查询
# ============================================================================

func test_ac006_get_realm_property_o1_query() -> void:
	var val: Variant = rs.get_realm_property(3, &"cost_per_turn")
	assert_eq(val, 8, "get_realm_property(3, cost_per_turn) 应返回 8")
	# 验证返回类型——int 字段应为 int
	assert_eq(typeof(val), TYPE_INT, "cost_per_turn 应为 int 类型")


# ============================================================================
# AC-007：get_realm_property(3, &"cost_per_turn") 返回 8
# ============================================================================

func test_ac007_get_realm_property_level3_cost() -> void:
	assert_eq(rs.get_realm_property(3, &"cost_per_turn"), 8, "L3 cost_per_turn 应为 8")


# ============================================================================
# AC-008：get_realm_property(1, &"max_deploy") 返回 2
# ============================================================================

func test_ac008_get_realm_property_level1_max_deploy() -> void:
	assert_eq(rs.get_realm_property(1, &"max_deploy"), 2, "L1 max_deploy 应为 2")


# ============================================================================
# AC-009：get_realm_property(4, &"card_pool_tier") 返回 4
# ============================================================================

func test_ac009_get_realm_property_level4_card_pool_tier() -> void:
	assert_eq(rs.get_realm_property(4, &"card_pool_tier"), 4, "L4 card_pool_tier 应为 4")


# ============================================================================
# AC-010：无效 level → null + push_warning
# ============================================================================

func test_ac010_invalid_level_returns_null_and_warning() -> void:
	var val: Variant = rs.get_realm_property(6, &"name")
	assert_null(val, "无效 level=6 应返回 null")
	assert_push_warning_count(1, "无效 level 应 push_warning 1 次")


func test_ac010_invalid_level_zero_returns_null_and_warning() -> void:
	var val: Variant = rs.get_realm_property(0, &"name")
	assert_null(val, "无效 level=0 应返回 null")
	assert_push_warning_count(1, "无效 level 应 push_warning 1 次")


func test_ac010_negative_level_returns_null_and_warning() -> void:
	var val: Variant = rs.get_realm_property(-1, &"name")
	assert_null(val, "无效 level=-1 应返回 null")
	assert_push_warning_count(1, "无效 level 应 push_warning 1 次")


# ============================================================================
# AC-011：无效 key → null + push_warning
# ============================================================================

func test_ac011_invalid_key_returns_null_and_warning() -> void:
	var val: Variant = rs.get_realm_property(1, &"nonexistent")
	assert_null(val, "无效 key 应返回 null")
	assert_push_warning_count(1, "无效 key 应 push_warning 1 次")


func test_ac011_empty_key_returns_null_and_warning() -> void:
	var val: Variant = rs.get_realm_property(1, &"")
	assert_null(val, "空 key 应返回 null")
	assert_push_warning_count(1, "空 key 应 push_warning 1 次")


# ============================================================================
# AC-012：get_current_property 便捷方法
# ============================================================================

func test_ac012_get_current_property_reads_gsm_realm() -> void:
	GameStateManager.player.realm = 4
	var val: Variant = rs.get_current_property(&"deck_limit")
	assert_eq(val, 35, "realm=4 时 deck_limit 应为 35")


# ============================================================================
# AC-013：get_current_property(&"deck_limit") 当 realm_level=4 返回 35
# ============================================================================

func test_ac013_get_current_property_deck_limit_level4() -> void:
	GameStateManager.player.realm = 4
	assert_eq(rs.get_current_property(&"deck_limit"), 35, "realm=4 时 deck_limit 应为 35")


func test_ac013_get_current_property_various_realms() -> void:
	# 补充：各境界的 deck_limit 一致性
	var expected: Array = [20, 25, 30, 35, 40]
	for level: int in range(1, 6):
		GameStateManager.player.realm = level
		assert_eq(rs.get_current_property(&"deck_limit"), expected[level - 1],
			"realm=%d 时 deck_limit 应为 %d" % [level, expected[level - 1]])


# ============================================================================
# AC-014：GSM 未就绪时 get_current_property 返回 null + push_error
# ============================================================================

func test_ac014_get_current_property_invalid_realm_push_error() -> void:
	# GSM Autoload 必然存在，模拟 player.realm 无效场景（设置为 99）
	GameStateManager.player.realm = 99
	var val: Variant = rs.get_current_property(&"name")
	assert_null(val, "player.realm=99 不在境界表时应返回 null")
	assert_push_error_count(1, "无效 realm 应 push_error 1 次")


# ============================================================================
# AC-015：修为上限公式验证（5 个境界）
# ============================================================================

func test_ac015_max_cultivation_formula() -> void:
	# 公式 max_cultivation(L) = ceil(1000 × 1.5^(L-1))
	# L1=1000, L2=1500, L3=2250, L4=3375, L5=5063
	var expected: Array = [1000, 1500, 2250, 3375, 5063]
	for level: int in range(1, 6):
		var val: Variant = rs.get_realm_property(level, &"max_cultivation")
		assert_eq(val, expected[level - 1],
			"L%d max_cultivation 应为 %d（公式 ceil(1000 × 1.5^(L-1))）" % [level, expected[level - 1]])
