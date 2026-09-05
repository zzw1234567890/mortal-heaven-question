extends RefCounted
## AlchemyRecipes —— 炼丹炼器配方查询子模块（从 alchemy_system.gd 拆分）。
##
## 纯函数 RefCounted 类——不持有运行时状态，所有方法为 static。[br]
## 包含配方表常量和配方查询 API。[br]
## [br]来源: ADR-0028 §关键接口 / GDD alchemy-crafting-system.md §1a/§2a。[br]
## [br]Sprint 12 Story 1：从 alchemy_system.gd 拆分。


# === 灵材品质常量（与 ResourceSystem.LingCaiQuality 值一致）==================

const LING_CAI_LOW: int = 1
const LING_CAI_MEDIUM: int = 2
const LING_CAI_HIGH: int = 3
const LING_CAI_TOP: int = 4

# === 稀有度常量 ================================================================

const RARITY_WHITE: int = 1
const RARITY_BLUE: int = 2
const RARITY_PURPLE: int = 3
const RARITY_GOLD: int = 4
const RARITY_DARK_GOLD: int = 5


# === 配方表（const Dictionary——编译时常量，运行时只读）=========================

const ALCHEMY_RECIPES: Dictionary = {
	# 回春丹——低级灵材×2，蓝色，回复 4HP
	"hui_chun_dan": {
		"name": "回春丹",
		"materials": {LING_CAI_LOW: 2},
		"rarity": RARITY_BLUE,
		"card_type": "pill",
		"template_id": "pill_hui_chun_dan",
		"base_effect": 4,
		"unlock_level": 0,
		"stack_limit": 3,
	},
	# 玉灵丹——中级灵材×2 + 低级灵材×1，紫色，回复 8HP+驱散1负面
	"yu_ling_dan": {
		"name": "玉灵丹",
		"materials": {LING_CAI_MEDIUM: 2, LING_CAI_LOW: 1},
		"rarity": RARITY_PURPLE,
		"card_type": "pill",
		"template_id": "pill_yu_ling_dan",
		"base_effect": 8,
		"unlock_level": 1,
		"stack_limit": 3,
	},
	# 天罗丹——高级灵材×2 + 中级灵材×1，金色，回复全体 6HP+驱散全部负面
	"tian_luo_dan": {
		"name": "天罗丹",
		"materials": {LING_CAI_HIGH: 2, LING_CAI_MEDIUM: 1},
		"rarity": RARITY_GOLD,
		"card_type": "pill",
		"template_id": "pill_tian_luo_dan",
		"base_effect": 6,
		"unlock_level": 2,
		"stack_limit": 3,
	},
	# 九转金丹——顶级灵材×2 + 高级灵材×1，暗金，永久+1最大HP+回复满血
	"jiu_zhuan_jin_dan": {
		"name": "九转金丹",
		"materials": {LING_CAI_TOP: 2, LING_CAI_HIGH: 1},
		"rarity": RARITY_DARK_GOLD,
		"card_type": "pill",
		"template_id": "pill_jiu_zhuan_jin_dan",
		"base_effect": 1,
		"unlock_level": 3,
		"stack_limit": 1,
	},
}

const ARTIFACT_RECIPES: Dictionary = {
	# 基础法器——低级灵材×3，蓝色
	"ji_chu_fa_qi": {
		"name": "基础法器",
		"materials": {LING_CAI_LOW: 3},
		"rarity": RARITY_BLUE,
		"card_type": "artifact",
		"template_id": "artifact_ji_chu_fa_qi",
		"base_atk": 3,
		"base_def": 2,
		"unlock_level": 0,
	},
	# 中品法器——中级灵材×3，紫色
	"zhong_pin_fa_qi": {
		"name": "中品法器",
		"materials": {LING_CAI_MEDIUM: 3},
		"rarity": RARITY_PURPLE,
		"card_type": "artifact",
		"template_id": "artifact_zhong_pin_fa_qi",
		"base_atk": 4,
		"base_def": 3,
		"unlock_level": 1,
	},
	# 上品法器——高级灵材×3，金色
	"shang_pin_fa_qi": {
		"name": "上品法器",
		"materials": {LING_CAI_HIGH: 3},
		"rarity": RARITY_GOLD,
		"card_type": "artifact",
		"template_id": "artifact_shang_pin_fa_qi",
		"base_atk": 6,
		"base_def": 5,
		"unlock_level": 2,
	},
	# 通天灵宝——顶级灵材×3 + 高级灵材×1，暗金
	"tong_tian_ling_bao": {
		"name": "通天灵宝",
		"materials": {LING_CAI_TOP: 3, LING_CAI_HIGH: 1},
		"rarity": RARITY_DARK_GOLD,
		"card_type": "artifact",
		"template_id": "artifact_tong_tian_ling_bao",
		"base_atk": 10,
		"base_def": 8,
		"unlock_level": 3,
	},
}


# === 配方查询 API =============================================================

static func has_pill_recipe(recipe_id: String) -> bool:
	return ALCHEMY_RECIPES.has(recipe_id)

static func has_artifact_recipe(recipe_id: String) -> bool:
	return ARTIFACT_RECIPES.has(recipe_id)

static func get_pill_recipe(recipe_id: String) -> Dictionary:
	return ALCHEMY_RECIPES.get(recipe_id, {})

static func get_artifact_recipe(recipe_id: String) -> Dictionary:
	return ARTIFACT_RECIPES.get(recipe_id, {})

static func get_all_pill_recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in ALCHEMY_RECIPES:
		var entry: Dictionary = ALCHEMY_RECIPES[key].duplicate()
		entry["recipe_id"] = key
		result.append(entry)
	return result

static func get_all_artifact_recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in ARTIFACT_RECIPES:
		var entry: Dictionary = ARTIFACT_RECIPES[key].duplicate()
		entry["recipe_id"] = key
		result.append(entry)
	return result
