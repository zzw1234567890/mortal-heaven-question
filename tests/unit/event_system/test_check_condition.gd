extends GutTest
## Story 002 AC-008~013：条件判定引擎（check_condition）验证。
##
## 覆盖：
##   - AC-008: REALM 条件（GE/EQ/LT）
##   - AC-009: FACTION 条件（== value_str）
##   - AC-010: RESOURCE 条件（>= value_int）
##   - AC-011: CARD_OWNED 条件
##   - AC-012: FLAG_SET 条件
##   - AC-013: FLAG_NOT_SET 条件
##
## 测试策略：直接调用 es.check_condition(cond)，传入构造好的 EventCondition。
## 每个 AC 测 true + false 两个 case。

const ES_SCRIPT := preload("res://src/foundation/event_system/event_system.gd")
const EventConditionClass := preload("res://src/foundation/event_system/event_condition.gd")
const EventEnumsClass := preload("res://src/foundation/event_system/event_enums.gd")

var es: Node = null


func before_each() -> void:
	es = ES_SCRIPT.new()
	# 重置 GSM 相关域
	GameStateManager.player.realm = GameStateManager.RealmLevel.QI_REFINING
	GameStateManager.player.resources = {
		"ling_shi": 0, "ling_cai": 0, "dan_yao_sui_pian": 0,
	}
	GameStateManager.collection.owned_cards = []
	GameStateManager.narrative.story_flags = {}


func after_each() -> void:
	if es != null:
		es.free()
		es = null
	GameStateManager.collection.owned_cards = []
	GameStateManager.narrative.story_flags = {}


func _make_realm_cond(op: int, threshold: int) -> EventCondition:
	var cond := EventConditionClass.new()
	cond.type = EventEnumsClass.ConditionType.REALM
	cond.operator = op
	cond.value_int = threshold
	return cond


func _make_faction_cond(faction: String) -> EventCondition:
	var cond := EventConditionClass.new()
	cond.type = EventEnumsClass.ConditionType.FACTION
	cond.value_str = faction
	return cond


func _make_resource_cond(target: String, op: int, amount: int) -> EventCondition:
	var cond := EventConditionClass.new()
	cond.type = EventEnumsClass.ConditionType.RESOURCE
	cond.target = target
	cond.operator = op
	cond.value_int = amount
	return cond


func _make_card_owned_cond(card_id: String) -> EventCondition:
	var cond := EventConditionClass.new()
	cond.type = EventEnumsClass.ConditionType.CARD_OWNED
	cond.value_str = card_id
	return cond


func _make_flag_cond(flag_key: String, flag_value: String, expect_set: bool) -> EventCondition:
	var cond := EventConditionClass.new()
	cond.type = EventEnumsClass.ConditionType.FLAG_SET if expect_set \
			else EventEnumsClass.ConditionType.FLAG_NOT_SET
	cond.target = flag_key
	cond.value_str = flag_value
	return cond


# ============================================================================
# AC-008：REALM 条件（GE/EQ/LT）
# ============================================================================

func test_ac008_realm_ge_false_when_below() -> void:
	# Arrange —— realm=2, GE 3
	GameStateManager.player.realm = 2
	var cond := _make_realm_cond(EventEnumsClass.ConditionOperator.GE, 3)

	# Act + Assert
	assert_false(es.check_condition(cond), "realm=2 GE 3 应为 false")


func test_ac008_realm_ge_true_when_equal() -> void:
	# Arrange —— realm=3, GE 3
	GameStateManager.player.realm = 3
	var cond := _make_realm_cond(EventEnumsClass.ConditionOperator.GE, 3)

	# Act + Assert
	assert_true(es.check_condition(cond), "realm=3 GE 3 应为 true")


func test_ac008_realm_ge_true_when_above() -> void:
	# Arrange —— realm=4, GE 3
	GameStateManager.player.realm = 4
	var cond := _make_realm_cond(EventEnumsClass.ConditionOperator.GE, 3)

	# Act + Assert
	assert_true(es.check_condition(cond), "realm=4 GE 3 应为 true")


func test_ac008_realm_eq_true_when_equal() -> void:
	# Arrange
	GameStateManager.player.realm = 3
	var cond := _make_realm_cond(EventEnumsClass.ConditionOperator.EQ, 3)

	# Act + Assert
	assert_true(es.check_condition(cond), "realm=3 EQ 3 应为 true")


func test_ac008_realm_eq_false_when_not_equal() -> void:
	# Arrange
	GameStateManager.player.realm = 2
	var cond := _make_realm_cond(EventEnumsClass.ConditionOperator.EQ, 3)

	# Act + Assert
	assert_false(es.check_condition(cond), "realm=2 EQ 3 应为 false")


func test_ac008_realm_lt_true_when_below() -> void:
	# Arrange
	GameStateManager.player.realm = 2
	var cond := _make_realm_cond(EventEnumsClass.ConditionOperator.LT, 3)

	# Act + Assert
	assert_true(es.check_condition(cond), "realm=2 LT 3 应为 true")


func test_ac008_realm_lt_false_when_equal() -> void:
	# Arrange
	GameStateManager.player.realm = 3
	var cond := _make_realm_cond(EventEnumsClass.ConditionOperator.LT, 3)

	# Act + Assert
	assert_false(es.check_condition(cond), "realm=3 LT 3 应为 false")


# ============================================================================
# AC-009：FACTION 条件
# ============================================================================

func test_ac009_faction_false_when_mismatch() -> void:
	# Arrange —— 玩家正道，条件要求魔道
	GameStateManager.narrative.story_flags["player_faction"] = "zhengdao"
	var cond := _make_faction_cond("modao")

	# Act + Assert
	assert_false(es.check_condition(cond), "faction=zhengdao != modao 应为 false")


func test_ac009_faction_true_when_match() -> void:
	# Arrange —— 玩家魔道，条件要求魔道
	GameStateManager.narrative.story_flags["player_faction"] = "modao"
	var cond := _make_faction_cond("modao")

	# Act + Assert
	assert_true(es.check_condition(cond), "faction=modao == modao 应为 true")


func test_ac009_faction_false_when_flag_unset() -> void:
	# Arrange —— 未设置 player_faction
	var cond := _make_faction_cond("zhengdao")

	# Act + Assert
	assert_false(es.check_condition(cond), "未设置阵营时 != zhengdao 应为 false")


# ============================================================================
# AC-010：RESOURCE 条件
# ============================================================================

func test_ac010_resource_ge_false_when_below() -> void:
	# Arrange —— ling_shi=50, GE 100
	GameStateManager.player.resources["ling_shi"] = 50
	var cond := _make_resource_cond("ling_shi", EventEnumsClass.ConditionOperator.GE, 100)

	# Act + Assert
	assert_false(es.check_condition(cond), "ling_shi=50 GE 100 应为 false")


func test_ac010_resource_ge_true_when_equal() -> void:
	# Arrange —— ling_shi=100, GE 100
	GameStateManager.player.resources["ling_shi"] = 100
	var cond := _make_resource_cond("ling_shi", EventEnumsClass.ConditionOperator.GE, 100)

	# Act + Assert
	assert_true(es.check_condition(cond), "ling_shi=100 GE 100 应为 true")


func test_ac010_resource_ge_true_when_above() -> void:
	# Arrange —— ling_shi=200, GE 100
	GameStateManager.player.resources["ling_shi"] = 200
	var cond := _make_resource_cond("ling_shi", EventEnumsClass.ConditionOperator.GE, 100)

	# Act + Assert
	assert_true(es.check_condition(cond), "ling_shi=200 GE 100 应为 true")


func test_ac010_resource_eq_true_when_equal() -> void:
	# Arrange
	GameStateManager.player.resources["ling_cai"] = 100
	var cond := _make_resource_cond("ling_cai", EventEnumsClass.ConditionOperator.EQ, 100)

	# Act + Assert
	assert_true(es.check_condition(cond), "ling_cai=100 EQ 100 应为 true")


func test_ac010_resource_lt_true_when_below() -> void:
	# Arrange
	GameStateManager.player.resources["ling_shi"] = 50
	var cond := _make_resource_cond("ling_shi", EventEnumsClass.ConditionOperator.LT, 100)

	# Act + Assert
	assert_true(es.check_condition(cond), "ling_shi=50 LT 100 应为 true")


func test_ac010_resource_false_when_target_unknown() -> void:
	# Arrange —— 未知资源类型，get 返回 0
	var cond := _make_resource_cond("unknown_resource",
			EventEnumsClass.ConditionOperator.GE, 100)

	# Act + Assert
	assert_false(es.check_condition(cond), "未知资源类型 GE 100 应为 false（默认 0）")


# ============================================================================
# AC-011：CARD_OWNED 条件
# ============================================================================

func test_ac011_card_owned_true_when_owned() -> void:
	# Arrange —— 拥有卡牌 card_001
	GameStateManager.collection.owned_cards = [
		{"template_id": "card_001", "id": 1},
		{"template_id": "card_002", "id": 2},
	]
	var cond := _make_card_owned_cond("card_001")

	# Act + Assert
	assert_true(es.check_condition(cond), "已拥有 card_001 应为 true")


func test_ac011_card_owned_false_when_not_owned() -> void:
	# Arrange —— 拥有 card_001，查询 card_999
	GameStateManager.collection.owned_cards = [
		{"template_id": "card_001", "id": 1},
	]
	var cond := _make_card_owned_cond("card_999")

	# Act + Assert
	assert_false(es.check_condition(cond), "未拥有 card_999 应为 false")


func test_ac011_card_owned_false_when_collection_empty() -> void:
	# Arrange —— 空收藏
	var cond := _make_card_owned_cond("card_001")

	# Act + Assert
	assert_false(es.check_condition(cond), "空收藏时应为 false")


# ============================================================================
# AC-012：FLAG_SET 条件
# ============================================================================

func test_ac012_flag_set_true_when_value_matches() -> void:
	# Arrange
	GameStateManager.narrative.story_flags["met_boss"] = "true"
	var cond := _make_flag_cond("met_boss", "true", true)

	# Act + Assert
	assert_true(es.check_condition(cond), "flag met_boss=true 且要求 true 应为 true")


func test_ac012_flag_set_false_when_value_mismatch() -> void:
	# Arrange —— flag 存在但值不匹配
	GameStateManager.narrative.story_flags["met_boss"] = "false"
	var cond := _make_flag_cond("met_boss", "true", true)

	# Act + Assert
	assert_false(es.check_condition(cond), "flag met_boss=false 但要求 true 应为 false")


func test_ac012_flag_set_false_when_flag_absent() -> void:
	# Arrange —— flag 不存在
	var cond := _make_flag_cond("met_boss", "true", true)

	# Act + Assert
	assert_false(es.check_condition(cond), "flag 不存在时 FLAG_SET 应为 false")


# ============================================================================
# AC-013：FLAG_NOT_SET 条件
# ============================================================================

func test_ac013_flag_not_set_true_when_flag_absent() -> void:
	# Arrange —— flag 不存在
	var cond := _make_flag_cond("met_boss", "true", false)

	# Act + Assert
	assert_true(es.check_condition(cond), "flag 不存在时 FLAG_NOT_SET 应为 true")


func test_ac013_flag_not_set_true_when_value_mismatch() -> void:
	# Arrange —— flag 存在但值不匹配要求值
	GameStateManager.narrative.story_flags["met_boss"] = "false"
	var cond := _make_flag_cond("met_boss", "true", false)

	# Act + Assert
	assert_true(es.check_condition(cond),
			"flag met_boss=false 但要求 != true 应为 true")


func test_ac013_flag_not_set_false_when_value_matches() -> void:
	# Arrange —— flag 存在且值匹配——FLAG_NOT_SET 应为 false
	GameStateManager.narrative.story_flags["met_boss"] = "true"
	var cond := _make_flag_cond("met_boss", "true", false)

	# Act + Assert
	assert_false(es.check_condition(cond),
			"flag met_boss=true 且要求 != true 应为 false")


# ============================================================================
# 边界：null 条件
# ============================================================================

func test_check_condition_returns_false_for_null() -> void:
	# Act + Assert
	assert_false(es.check_condition(null), "null 条件应返回 false")


func test_check_condition_returns_false_for_unknown_type() -> void:
	# Arrange —— 使用未知 type 值（6 不在枚举内）
	var cond := EventConditionClass.new()
	cond.type = 99  # 超出 ConditionType 范围

	# Act + Assert
	assert_false(es.check_condition(cond), "未知 ConditionType 应返回 false")
