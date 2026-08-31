extends GutTest
## Story 001 验收测试：配方表（const Dictionary, 8 配方）+ 查询 API。
##
## 覆盖 AC-001 到 AC-012（12 条 AC）。
## 测试策略：
##   - 通过 preload 引用 AlchemySystem 脚本（不依赖 class_name 全局注册）
##   - 验证配方表完整性 + 字段齐全 + GDD 数值 + 查询 API
##
## 设计文档来源：GDD alchemy-crafting-system.md §1a/§2a
## Story 来源：production/epics/alchemy-crafting-system/story-001-recipe-table.md

const AS := preload("res://src/feature/alchemy_system.gd")


# ============================================================================
# AC-001：ALCHEMY_RECIPES 包含恰好 4 个炼丹配方
# ============================================================================

func test_alchemy_recipes_contains_four_pill_recipes() -> void:
	# Act
	var count: int = AS.ALCHEMY_RECIPES.size()

	# Assert
	assert_eq(count, 4, "ALCHEMY_RECIPES 应包含 4 个炼丹配方")


# ============================================================================
# AC-002：ARTIFACT_RECIPES 包含恰好 4 个炼器配方
# ============================================================================

func test_artifact_recipes_contains_four_artifact_recipes() -> void:
	# Act
	var count: int = AS.ARTIFACT_RECIPES.size()

	# Assert
	assert_eq(count, 4, "ARTIFACT_RECIPES 应包含 4 个炼器配方")


# ============================================================================
# AC-003：每个配方含全部必需字段
# ============================================================================

func test_each_recipe_has_all_required_fields() -> void:
	# Arrange
	var required_keys: Array = [
		"name", "materials", "rarity", "card_type",
		"template_id", "unlock_level",
	]

	# Act & Assert——炼丹配方
	for id: String in AS.ALCHEMY_RECIPES:
		var recipe: Dictionary = AS.ALCHEMY_RECIPES[id]
		for key: String in required_keys:
			assert_true(recipe.has(key), "炼丹配方 '%s' 缺少必需字段 '%s'" % [id, key])
		assert_true(recipe.has("base_effect"), "炼丹配方 '%s' 缺少 base_effect" % id)

	# Act & Assert——炼器配方
	for id2: String in AS.ARTIFACT_RECIPES:
		var recipe2: Dictionary = AS.ARTIFACT_RECIPES[id2]
		for key2: String in required_keys:
			assert_true(recipe2.has(key2), "炼器配方 '%s' 缺少必需字段 '%s'" % [id2, key2])
		assert_true(recipe2.has("base_atk"), "炼器配方 '%s' 缺少 base_atk" % id2)
		assert_true(recipe2.has("base_def"), "炼器配方 '%s' 缺少 base_def" % id2)


# ============================================================================
# AC-004：回春丹配方数据符合 GDD
# ============================================================================

func test_hui_chun_dan_matches_gdd() -> void:
	# Act
	var recipe: Dictionary = AS.ALCHEMY_RECIPES["hui_chun_dan"]

	# Assert
	assert_eq(recipe["name"], "回春丹")
	assert_eq(int(recipe["rarity"]), AS.RARITY_BLUE)
	assert_eq(int(recipe["base_effect"]), 4)
	assert_eq(int(recipe["unlock_level"]), 0)
	var materials: Dictionary = recipe["materials"]
	assert_eq(int(materials[AS.LING_CAI_LOW]), 2)


# ============================================================================
# AC-005：九转金丹配方数据符合 GDD
# ============================================================================

func test_jiu_zhuan_jin_dan_matches_gdd() -> void:
	# Act
	var recipe: Dictionary = AS.ALCHEMY_RECIPES["jiu_zhuan_jin_dan"]

	# Assert
	assert_eq(recipe["name"], "九转金丹")
	assert_eq(int(recipe["rarity"]), AS.RARITY_DARK_GOLD)
	assert_eq(int(recipe["base_effect"]), 1)
	assert_eq(int(recipe["unlock_level"]), 3)
	var materials: Dictionary = recipe["materials"]
	assert_eq(int(materials[AS.LING_CAI_TOP]), 2)
	assert_eq(int(materials[AS.LING_CAI_HIGH]), 1)


# ============================================================================
# AC-006：基础法器配方数据符合 GDD
# ============================================================================

func test_ji_chu_fa_qi_matches_gdd() -> void:
	# Act
	var recipe: Dictionary = AS.ARTIFACT_RECIPES["ji_chu_fa_qi"]

	# Assert
	assert_eq(recipe["name"], "基础法器")
	assert_eq(int(recipe["rarity"]), AS.RARITY_BLUE)
	assert_eq(int(recipe["base_atk"]), 3)
	assert_eq(int(recipe["base_def"]), 2)
	assert_eq(int(recipe["unlock_level"]), 0)
	var materials: Dictionary = recipe["materials"]
	assert_eq(int(materials[AS.LING_CAI_LOW]), 3)


# ============================================================================
# AC-007：通天灵宝配方数据符合 GDD
# ============================================================================

func test_tong_tian_ling_bao_matches_gdd() -> void:
	# Act
	var recipe: Dictionary = AS.ARTIFACT_RECIPES["tong_tian_ling_bao"]

	# Assert
	assert_eq(recipe["name"], "通天灵宝")
	assert_eq(int(recipe["rarity"]), AS.RARITY_DARK_GOLD)
	assert_eq(int(recipe["base_atk"]), 10)
	assert_eq(int(recipe["base_def"]), 8)
	assert_eq(int(recipe["unlock_level"]), 3)
	var materials: Dictionary = recipe["materials"]
	assert_eq(int(materials[AS.LING_CAI_TOP]), 3)
	assert_eq(int(materials[AS.LING_CAI_HIGH]), 1)


# ============================================================================
# AC-008：has_pill_recipe(有效ID) 返回 true
# ============================================================================

func test_has_pill_recipe_valid_id_returns_true() -> void:
	# Act
	var result: bool = AS.has_pill_recipe("hui_chun_dan")

	# Assert
	assert_true(result, "有效配方 ID 应返回 true")


# ============================================================================
# AC-009：has_pill_recipe(无效ID) 返回 false
# ============================================================================

func test_has_pill_recipe_invalid_id_returns_false() -> void:
	# Act
	var result: bool = AS.has_pill_recipe("invalid_recipe")

	# Assert
	assert_false(result, "无效配方 ID 应返回 false")


# ============================================================================
# AC-010：get_pill_recipe(有效ID) 返回完整配方数据
# ============================================================================

func test_get_pill_recipe_valid_id_returns_full_data() -> void:
	# Act
	var recipe: Dictionary = AS.get_pill_recipe("yu_ling_dan")

	# Assert
	assert_false(recipe.is_empty(), "有效 ID 应返回非空配方")
	assert_eq(recipe["name"], "玉灵丹")
	assert_true(recipe.has("materials"))
	assert_true(recipe.has("rarity"))
	assert_true(recipe.has("base_effect"))
	assert_true(recipe.has("unlock_level"))


# ============================================================================
# AC-011：get_all_pill_recipes() 返回 4 个条目
# ============================================================================

func test_get_all_pill_recipes_returns_four_entries() -> void:
	# Act
	var recipes: Array = AS.get_all_pill_recipes()

	# Assert
	assert_eq(recipes.size(), 4, "应返回 4 个炼丹配方")


# ============================================================================
# AC-012：get_all_artifact_recipes() 返回 4 个条目
# ============================================================================

func test_get_all_artifact_recipes_returns_four_entries() -> void:
	# Act
	var recipes: Array = AS.get_all_artifact_recipes()

	# Assert
	assert_eq(recipes.size(), 4, "应返回 4 个炼器配方")
