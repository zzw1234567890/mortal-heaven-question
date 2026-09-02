extends GutTest
## Story 7-9 验收测试：AchievementSystem 成就定义 + 解锁状态管理。
##
## 覆盖 AC-001 到 AC-010（10 条 AC）。
## 测试策略：
##   - 直接使用 const ACHIEVEMENT_DEFS 验证成就定义
##   - 注入 ProgressionSystem mock 验证注册
##
## 设计文档来源：GDD achievement-system.md §1~§3
## Story 来源：production/epics/achievement-system/story-001-achievement-instance.md

const AS := preload("res://src/feature/achievement_system.gd")

var _progression_mock: Node = null


func before_each() -> void:
	_progression_mock = Node.new()
	_progression_mock.set_script(load("res://tests/unit/achievement_system/progression_mock.gd"))
	AS._progression_override = _progression_mock


func after_each() -> void:
	AS._progression_override = null
	if _progression_mock != null:
		_progression_mock.free()
		_progression_mock = null


# ============================================================================
# AC-001：ACHIEVEMENT_DEFS const 包含 62 个成就定义
# ============================================================================

func test_achievement_defs_has_62() -> void:
	assert_eq(AS.ACHIEVEMENT_DEFS.size(), 62, "应有 62 个成就定义")


# ============================================================================
# AC-002：7 个类别数量正确
# ============================================================================

func test_category_counts() -> void:
	assert_eq(AS.get_definitions_by_category("combat").size(), 12, "combat 应有 12 个")
	assert_eq(AS.get_definitions_by_category("progression").size(), 10, "progression 应有 10 个")
	assert_eq(AS.get_definitions_by_category("collection").size(), 10, "collection 应有 10 个")
	assert_eq(AS.get_definitions_by_category("exploration").size(), 8, "exploration 应有 8 个")
	assert_eq(AS.get_definitions_by_category("narrative").size(), 8, "narrative 应有 8 个")
	assert_eq(AS.get_definitions_by_category("mastery").size(), 8, "mastery 应有 8 个")
	assert_eq(AS.get_definitions_by_category("challenge").size(), 6, "challenge 应有 6 个")


# ============================================================================
# AC-003：get_achievement_definition 返回完整定义
# ============================================================================

func test_get_achievement_definition() -> void:
	var def: Dictionary = AS.get_achievement_definition("ach_first_realm_break")
	assert_eq(str(def["id"]), "ach_first_realm_break", "应返回 id")
	assert_eq(str(def["name"]), "踏入道途", "应返回 name")
	assert_eq(str(def["category"]), "progression", "应返回 category")
	assert_eq(str(def["tier"]), "bronze", "应返回 tier")


# ============================================================================
# AC-004：get_all_definitions() 返回全部 62 个
# ============================================================================

func test_get_all_definitions() -> void:
	var all: Array = AS.get_all_definitions()
	assert_eq(all.size(), 62, "应返回 62 个定义")


# ============================================================================
# AC-005：get_definitions_by_category("combat") 返回 12 个
# ============================================================================

func test_get_by_category_combat() -> void:
	var combat: Array = AS.get_definitions_by_category("combat")
	assert_eq(combat.size(), 12, "combat 应有 12 个")


# ============================================================================
# AC-006：每个成就定义包含 hidden_until_unlocked 字段
# ============================================================================

func test_all_defs_have_hidden_flag() -> void:
	for ach_id: String in AS.ACHIEVEMENT_DEFS:
		var def: Dictionary = AS.ACHIEVEMENT_DEFS[ach_id]
		assert_true(def.has("hidden_until_unlocked"), "%s 应包含 hidden_until_unlocked" % ach_id)


# ============================================================================
# AC-007：每个成就定义包含 unlock_condition 字段
# ============================================================================

func test_all_defs_have_unlock_condition() -> void:
	for ach_id: String in AS.ACHIEVEMENT_DEFS:
		var def: Dictionary = AS.ACHIEVEMENT_DEFS[ach_id]
		assert_true(def.has("unlock_condition"), "%s 应包含 unlock_condition" % ach_id)
		var cond: Dictionary = def["unlock_condition"]
		assert_true(cond.has("event"), "%s 的 unlock_condition 应包含 event" % ach_id)
		assert_true(cond.has("threshold"), "%s 的 unlock_condition 应包含 threshold" % ach_id)


# ============================================================================
# AC-008：每个成就定义包含 tier 字段（bronze/silver/gold）
# ============================================================================

func test_all_defs_have_valid_tier() -> void:
	var valid_tiers: Array = ["bronze", "silver", "gold"]
	for ach_id: String in AS.ACHIEVEMENT_DEFS:
		var def: Dictionary = AS.ACHIEVEMENT_DEFS[ach_id]
		var tier: String = str(def.get("tier", ""))
		assert_true(tier in valid_tiers, "%s 的 tier 应为 bronze/silver/gold，实际 %s" % [ach_id, tier])


# ============================================================================
# AC-009：initialize() 注册全部 62 个到 ProgressionSystem
# ============================================================================

func test_initialize_registers_all() -> void:
	_progression_mock._registered_achievements.clear()
	AS.initialize()
	assert_eq(_progression_mock._registered_achievements.size(), 62, "应注册 62 个成就")


# ============================================================================
# AC-010：get_definitions_by_category("narrative") 返回 8 个
# ============================================================================

func test_get_by_category_narrative() -> void:
	var narrative: Array = AS.get_definitions_by_category("narrative")
	assert_eq(narrative.size(), 8, "narrative 应有 8 个")
