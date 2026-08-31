class_name AlchemySystem
extends RefCounted
## AlchemySystem —— 炼丹炼器系统 RefCounted 工具类（ADR-0028）。
##
## Feature 层 RefCounted（非 Autoload）。持有 8 个配方的 const Dictionary 配方表[br]
## 和纯函数公式（品质掷骰、丹药效果缩放、法宝属性生成）。[br]
## 通过 CardSystem.create_instance() 产出卡牌实例，通过 ResourceSystem.spend_resource()[br]
## 消费灵材，通过 DeckEditingSystem.add_cards_to_deck() 写入卡组。[br]
## 自身不持有任何运行时持久状态。[br]
## [br][b]Story 6-4 范围[/b]：配方表 + 查询 API。[br]
## [br]来源: ADR-0028 §关键接口 / GDD alchemy-crafting-system.md §1-2。


# === 灵材品质常量（与 ResourceSystem.LingCaiQuality 值一致）==================

## 低级灵材品质值。
const LING_CAI_LOW: int = 1
## 中级灵材品质值。
const LING_CAI_MEDIUM: int = 2
## 高级灵材品质值。
const LING_CAI_HIGH: int = 3
## 顶级灵材品质值。
const LING_CAI_TOP: int = 4


# === 稀有度常量 ================================================================

## 白色稀有度。
const RARITY_WHITE: int = 1
## 蓝色稀有度。
const RARITY_BLUE: int = 2
## 紫色稀有度。
const RARITY_PURPLE: int = 3
## 金色稀有度。
const RARITY_GOLD: int = 4
## 暗金稀有度。
const RARITY_DARK_GOLD: int = 5


# === 品质掷骰结果枚举 ==========================================================

## 品质掷骰结果——降品/标准/升品。
enum QualityOutcome {
	DOWNGRADE = -1,  ## 降品——稀有度 -1，品质倍率 0.8
	STANDARD = 0,    ## 标准——稀有度不变，品质倍率 1.0
	UPGRADE = 1,     ## 升品——稀有度 +1，品质倍率 1.3
}

## 炼制结果枚举——成功/灵材不足/配方锁定/无效配方。
enum CraftResult {
	SUCCESS = 0,                ## 炼制成功
	INSUFFICIENT_MATERIALS = 1, ## 灵材不足
	RECIPE_LOCKED = 2,          ## 配方未解锁（炼丹等级不足）
	INVALID_RECIPE = 3,         ## 无效配方 ID
}


# === 品质倍率映射 ==============================================================

## 品质掷骰结果 → 品质倍率映射（GDD §0 品质掷骰→品质倍率映射）。
const QUALITY_MOD: Dictionary = {
	QualityOutcome.DOWNGRADE: 0.8,
	QualityOutcome.STANDARD: 1.0,
	QualityOutcome.UPGRADE: 1.3,
}


# === 配方表（const Dictionary——编译时常量，运行时只读）=========================

## 炼丹配方表——4 个配方（GDD §1a 炼丹配方）。[br]
## 键 = 配方 ID（String），值 = 配方 Dictionary。[br]
## [br]来源: GDD alchemy-crafting-system.md §1a。
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

## 炼器配方表——4 个配方（GDD §2a 炼器配方）。[br]
## 键 = 配方 ID（String），值 = 配方 Dictionary。[br]
## [br]来源: GDD alchemy-crafting-system.md §2a。
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


# === 配方查询 API（Story 6-4）=================================================

## 检查炼丹配方是否存在。[br]
## [br][param recipe_id] 配方 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 配方存在，[code]false[/code] 不存在。[br]
## [br]来源: ADR-0028 §关键接口。
static func has_pill_recipe(recipe_id: String) -> bool:
	return ALCHEMY_RECIPES.has(recipe_id)


## 检查炼器配方是否存在。[br]
## [br][param recipe_id] 配方 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 配方存在，[code]false[/code] 不存在。[br]
## [br]来源: ADR-0028 §关键接口。
static func has_artifact_recipe(recipe_id: String) -> bool:
	return ARTIFACT_RECIPES.has(recipe_id)


## 获取炼丹配方数据。[br]
## [br][param recipe_id] 配方 ID。[br]
## [br][b]返回[/b]: 完整配方 Dictionary，无效 ID 返回空字典。[br]
## [br]来源: ADR-0028 §关键接口。
static func get_pill_recipe(recipe_id: String) -> Dictionary:
	return ALCHEMY_RECIPES.get(recipe_id, {})


## 获取炼器配方数据。[br]
## [br][param recipe_id] 配方 ID。[br]
## [br][b]返回[/b]: 完整配方 Dictionary，无效 ID 返回空字典。[br]
## [br]来源: ADR-0028 §关键接口。
static func get_artifact_recipe(recipe_id: String) -> Dictionary:
	return ARTIFACT_RECIPES.get(recipe_id, {})


## 获取全部炼丹配方列表。[br]
## [br][b]返回[/b]: Array[Dictionary]——4 个配方的列表副本。[br]
## [br]来源: ADR-0028 §关键接口。
static func get_all_pill_recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in ALCHEMY_RECIPES:
		var entry: Dictionary = ALCHEMY_RECIPES[key].duplicate()
		entry["recipe_id"] = key
		result.append(entry)
	return result


## 获取全部炼器配方列表。[br]
## [br][b]返回[/b]: Array[Dictionary]——4 个配方的列表副本。[br]
## [br]来源: ADR-0028 §关键接口。
static func get_all_artifact_recipes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in ARTIFACT_RECIPES:
		var entry: Dictionary = ARTIFACT_RECIPES[key].duplicate()
		entry["recipe_id"] = key
		result.append(entry)
	return result


# === 品质掷骰纯函数（Story 6-6 实现）===========================================

## 品质掷骰——首次掷骰（GDD §1 品质概率公式）。[br]
## [br][param recipe_base_rarity] 配方基础稀有度 [1, 5]。[br]
## [br][param alchemy_level] 当前炼丹/炼器等级 [0, 4]。[br]
## [br][param bonuses] 外部加成（万象真人+0.15 + 材料溢出+0.10/级）。[br]
## [br][param rng] 独立 RNG 实例。[br]
## [br][b]返回[/b]: QualityOutcome——DOWNGRADE/STANDARD/UPGRADE。[br]
## [br]来源: GDD §1 品质概率公式 + ADR-0028 §quality_roll。
static func quality_roll(recipe_base_rarity: int, alchemy_level: int, bonuses: float, rng: RandomNumberGenerator) -> QualityOutcome:
	var high_chance: float = minf(0.10 + alchemy_level * 0.05 + bonuses, 0.8)
	var low_chance: float = 0.1 if recipe_base_rarity > 1 else 0.0
	var roll: float = rng.randf()
	if roll < low_chance:
		return QualityOutcome.DOWNGRADE
	if roll < low_chance + high_chance:
		return QualityOutcome.UPGRADE
	return QualityOutcome.STANDARD


## 品质重掷——玩家选择重掷后的二次掷骰（GDD §1b 品质重掷公式）。[br]
## [br]升品概率 +15%，降品概率升至 25%。[br]
## [br][param recipe_base_rarity] 配方基础稀有度。[br]
## [br][param alchemy_level] 当前炼丹/炼器等级。[br]
## [br][param bonuses] 外部加成。[br]
## [br][param rng] 独立 RNG 实例。[br]
## [br][b]返回[/b]: QualityOutcome。[br]
## [br]来源: GDD §1b 品质重掷公式 + ADR-0028 §quality_reroll。
static func quality_reroll(recipe_base_rarity: int, alchemy_level: int, bonuses: float, rng: RandomNumberGenerator) -> QualityOutcome:
	var high_chance: float = minf(0.10 + alchemy_level * 0.05 + bonuses + 0.15, 0.8)
	var low_chance: float = 0.25 if recipe_base_rarity > 1 else 0.0
	var roll: float = rng.randf()
	if roll < low_chance:
		return QualityOutcome.DOWNGRADE
	if roll < low_chance + high_chance:
		return QualityOutcome.UPGRADE
	return QualityOutcome.STANDARD


## 获取品质修改后的稀有度（GDD §1 品质概率公式）。[br]
## [br][param recipe_base_rarity] 配方基础稀有度。[br]
## [br][param outcome] 品质掷骰结果。[br]
## [br][b]返回[/b]: 最终稀有度（钳制在 [1, 5]）。[br]
## [br]来源: GDD §1 + ADR-0028 §resolve_final_rarity。
static func resolve_final_rarity(recipe_base_rarity: int, outcome: QualityOutcome) -> int:
	match outcome:
		QualityOutcome.DOWNGRADE:
			return maxi(recipe_base_rarity - 1, 1)
		QualityOutcome.UPGRADE:
			return mini(recipe_base_rarity + 1, 5)
		_:
			return recipe_base_rarity


## 品质倍率映射——QualityOutcome → float。[br]
## [br][param outcome] 品质掷骰结果。[br]
## [br][b]返回[/b]: 0.8 / 1.0 / 1.3。[br]
## [br]来源: GDD §0 + ADR-0028 §QUALITY_MOD。
static func _quality_mod_from_outcome(outcome: QualityOutcome) -> float:
	return float(QUALITY_MOD.get(outcome, 1.0))


## 丹药效果缩放（GDD §2 丹药效果缩放）。[br]
## [br][param base_value] 丹药基础效果值。[br]
## [br][param quality_mod] 品质倍率 {0.8, 1.0, 1.3}。[br]
## [br][param bonus_pct] 炼丹精通加成（炼丹等级≥2时+0.1）。[br]
## [br][b]返回[/b]: 最终效果值（至少 1）。[br]
## [br]来源: GDD §2 + ADR-0028 §pill_effect。
static func pill_effect(base_value: int, quality_mod: float, bonus_pct: float) -> int:
	return maxi(1, floori(base_value * quality_mod * (1.0 + bonus_pct)))


## 法宝属性生成（GDD §3 法宝属性生成）。[br]
## [br][param rarity] 产出稀有度 [1, 5]（白=1→暗金=5）。[br]
## [br][param quality_mod] 品质倍率 {0.8, 1.0, 1.3}。[br]
## [br][b]返回[/b]: {atk: int, def: int} Dictionary。[br]
## [br]来源: GDD §3 + ADR-0028 §forge_artifact_stat。
static func forge_artifact_stat(rarity: int, quality_mod: float) -> Dictionary:
	const BASE_ATK: PackedInt32Array = [1, 3, 4, 6, 10]
	const BASE_DEF: PackedInt32Array = [1, 2, 3, 5, 8]
	var idx: int = clampi(rarity, 1, 5) - 1
	return {
		"atk": maxi(1, floori(BASE_ATK[idx] * quality_mod)),
		"def": maxi(0, floori(BASE_DEF[idx] * quality_mod)),
	}


## 九转金丹累积阈值（GDD §5 九转金丹递减收益）。[br]
## [br][param craft_count] 当前累计炼制颗数。[br]
## [br][b]返回[/b]: 第 N 次 +1HP 所需累计颗数 = N×(N+1)/2。[br]
## [br]来源: GDD §5 + ADR-0028 §jindan_cumulative_threshold。
static func jindan_cumulative_threshold(craft_count: int) -> int:
	return craft_count * (craft_count + 1) / 2


# === 炼制编排（Story 6-5）=====================================================

## 执行炼丹——完整编排流程（ADR-0028 §craft_pill）。[br]
## [br][param recipe_id] 配方 ID。[br]
## [br][param quality_bonuses] 外部品质加成。[br]
## [br][param rng] 独立 RNG 实例。[br]
## [br][param is_dadao_active] 化神期丹道大成是否可用（本局首次=必升品）。[br]
## [br][b]返回[/b]: Dictionary——{result, first_roll, card_instance_id, final_rarity, quality_mod}。[br]
## [br][b]流程[/b]: 查配方→检查解锁→校验灵材→扣减灵材→品质掷骰→生成卡牌→写入卡组。[br]
## [br]来源: ADR-0028 §craft_pill + GDD §1b/§1c。
static func craft_pill(recipe_id: String, quality_bonuses: float, rng: RandomNumberGenerator, is_dadao_active: bool = false) -> Dictionary:
	# 1. 查配方
	var recipe: Dictionary = ALCHEMY_RECIPES.get(recipe_id, {})
	if recipe.is_empty():
		return {"result": CraftResult.INVALID_RECIPE}

	# 2. 检查解锁等级
	var alchemy_level: int = _get_alchemy_level()
	if alchemy_level < int(recipe["unlock_level"]):
		return {"result": CraftResult.RECIPE_LOCKED}

	# 3. 校验灵材余额并扣减
	var res_sys: Node = _get_resource_system()
	if res_sys == null:
		return {"result": CraftResult.INVALID_RECIPE}
	for quality: int in recipe["materials"]:
		var qty: int = int(recipe["materials"][quality])
		if not res_sys.can_spend(&"ling_cai", qty, quality):
			return {"result": CraftResult.INSUFFICIENT_MATERIALS}
	for quality2: int in recipe["materials"]:
		var qty2: int = int(recipe["materials"][quality2])
		res_sys.spend_resource(&"ling_cai", qty2, quality2)

	# 4. 品质掷骰
	var outcome: int
	if is_dadao_active:
		outcome = QualityOutcome.UPGRADE
	else:
		outcome = quality_roll(int(recipe["rarity"]), alchemy_level, quality_bonuses, rng)

	# 5. 生成卡牌实例
	var final_rarity: int = resolve_final_rarity(int(recipe["rarity"]), outcome)
	var card_sys: Node = _get_card_system()
	if card_sys == null:
		return {"result": CraftResult.SUCCESS, "first_roll": outcome, "final_rarity": final_rarity, "quality_mod": _quality_mod_from_outcome(outcome)}
	var inst = card_sys.create_instance(StringName(recipe["template_id"]))
	var inst_id: int = 0
	if inst != null:
		inst_id = inst.get("card_instance_id") if "card_instance_id" in inst else int(inst.card_instance_id)
		var gsm: Node = _get_gsm()
		if gsm != null and gsm.has_method("add_card_to_collection"):
			var inst_dict: Dictionary = {
				"card_instance_id": inst_id,
				"template_id": str(recipe["template_id"]),
				"level": 1,
				"inscriptions": [],
				"breakthrough_layers": 0,
				"binding_target_id": &"",
				"acquired_chapter": 0,
				"acquired_event_id": &"",
				"acquired_method": 4,  # CRAFT
			}
			gsm.add_card_to_collection(inst_dict)

	# 6. 写入卡组
	var deck_sys: Node = _get_deck_editing_system()
	if deck_sys != null and deck_sys.has_method("add_cards_to_deck") and inst_id != 0:
		deck_sys.add_cards_to_deck([inst_id], "craft", str(recipe["name"]))

	return {
		"result": CraftResult.SUCCESS,
		"first_roll": outcome,
		"card_instance_id": inst_id,
		"final_rarity": final_rarity,
		"quality_mod": _quality_mod_from_outcome(outcome),
	}


## 执行炼器——与炼丹相同的编排流程（ADR-0028 §craft_artifact）。[br]
## [br][param recipe_id] 配方 ID。[br]
## [br][param quality_bonuses] 外部品质加成。[br]
## [br][param rng] 独立 RNG 实例。[br]
## [br][param is_dadao_active] 化神期丹道大成是否可用。[br]
## [br][b]返回[/b]: Dictionary——{result, first_roll, card_instance_id, final_rarity}。[br]
## [br]来源: ADR-0028 §craft_artifact + GDD §2b。
static func craft_artifact(recipe_id: String, quality_bonuses: float, rng: RandomNumberGenerator, is_dadao_active: bool = false) -> Dictionary:
	# 1. 查配方
	var recipe: Dictionary = ARTIFACT_RECIPES.get(recipe_id, {})
	if recipe.is_empty():
		return {"result": CraftResult.INVALID_RECIPE}

	# 2. 检查解锁等级
	var alchemy_level: int = _get_alchemy_level()
	if alchemy_level < int(recipe["unlock_level"]):
		return {"result": CraftResult.RECIPE_LOCKED}

	# 3. 校验灵材余额并扣减
	var res_sys: Node = _get_resource_system()
	if res_sys == null:
		return {"result": CraftResult.INVALID_RECIPE}
	for quality: int in recipe["materials"]:
		var qty: int = int(recipe["materials"][quality])
		if not res_sys.can_spend(&"ling_cai", qty, quality):
			return {"result": CraftResult.INSUFFICIENT_MATERIALS}
	for quality2: int in recipe["materials"]:
		var qty2: int = int(recipe["materials"][quality2])
		res_sys.spend_resource(&"ling_cai", qty2, quality2)

	# 4. 品质掷骰
	var outcome: int
	if is_dadao_active:
		outcome = QualityOutcome.UPGRADE
	else:
		outcome = quality_roll(int(recipe["rarity"]), alchemy_level, quality_bonuses, rng)

	# 5. 生成卡牌实例
	var final_rarity: int = resolve_final_rarity(int(recipe["rarity"]), outcome)
	var card_sys: Node = _get_card_system()
	if card_sys == null:
		return {"result": CraftResult.SUCCESS, "first_roll": outcome, "final_rarity": final_rarity}
	var inst = card_sys.create_instance(StringName(recipe["template_id"]))
	var inst_id: int = 0
	if inst != null:
		inst_id = inst.get("card_instance_id") if "card_instance_id" in inst else int(inst.card_instance_id)
		var gsm: Node = _get_gsm()
		if gsm != null and gsm.has_method("add_card_to_collection"):
			var inst_dict: Dictionary = {
				"card_instance_id": inst_id,
				"template_id": str(recipe["template_id"]),
				"level": 1,
				"inscriptions": [],
				"breakthrough_layers": 0,
				"binding_target_id": &"",
				"acquired_chapter": 0,
				"acquired_event_id": &"",
				"acquired_method": 4,  # CRAFT
			}
			gsm.add_card_to_collection(inst_dict)

	# 6. 写入卡组
	var deck_sys: Node = _get_deck_editing_system()
	if deck_sys != null and deck_sys.has_method("add_cards_to_deck") and inst_id != 0:
		deck_sys.add_cards_to_deck([inst_id], "craft", str(recipe["name"]))

	return {
		"result": CraftResult.SUCCESS,
		"first_roll": outcome,
		"card_instance_id": inst_id,
		"final_rarity": final_rarity,
	}


# === 系统引用辅助（static——通过 SceneTree Autoload 查找）===================

## 获取炼丹/炼器等级——境界层级 - 1（ADR-0028 §_get_alchemy_level）。[br]
## [br]炼气 L=1 → 等级 0；化神 L=5 → 等级 4。[br]
## [br][b]返回[/b]: 炼丹/炼器等级 [0, 4]。
static func _get_alchemy_level() -> int:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return 0
	var realm_level: int = int(gsm.player.get("realm", 1))
	return maxi(0, realm_level - 1)


## 获取 GSM 引用——通过 SceneTree Autoload。
static func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


## 获取 ResourceSystem 引用——通过 SceneTree Autoload。
static func _get_resource_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/ResourceSystem")


## 获取 CardSystem 引用——通过 SceneTree Autoload。
static func _get_card_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/CardSystem")


## 获取 DeckEditingSystem 引用——通过 SceneTree Autoload。
static func _get_deck_editing_system() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/DeckEditingSystem")


# === 品质重掷（Story 6-7）=====================================================

## 品质重掷——玩家选择重掷后的二次掷骰（ADR-0028 §apply_reroll）。[br]
## [br]灵材已在首次炼制时扣除——重掷不额外消耗灵材。[br]
## [br][param recipe_id] 配方 ID。[br]
## [br][param quality_bonuses] 外部品质加成。[br]
## [br][param rng] 独立 RNG 实例。[br]
## [br][param existing_instance_id] 已有卡牌实例 ID（用于重掷后更新实例数据）。[br]
## [br][b]返回[/b]: Dictionary——{result, final_roll, final_rarity, can_reroll}。[br]
## [br][b]规则[/b]: 重掷后必须接受新结果——无第三次重掷机会。[br]
## [br]来源: ADR-0028 §apply_reroll + GDD §1b 品质重掷公式。
static func apply_reroll(recipe_id: String, quality_bonuses: float, rng: RandomNumberGenerator, existing_instance_id: int = 0) -> Dictionary:
	# 1. 查配方——炼丹和炼器配方都可能重掷
	var recipe: Dictionary = ALCHEMY_RECIPES.get(recipe_id, {})
	if recipe.is_empty():
		recipe = ARTIFACT_RECIPES.get(recipe_id, {})
	if recipe.is_empty():
		return {"result": CraftResult.INVALID_RECIPE}

	# 2. 重掷品质（降品概率 25%，升品概率 +15%）
	var alchemy_level: int = _get_alchemy_level()
	var outcome: int = quality_reroll(int(recipe["rarity"]), alchemy_level, quality_bonuses, rng)

	# 3. 重新计算稀有度
	var final_rarity: int = resolve_final_rarity(int(recipe["rarity"]), outcome)

	return {
		"result": CraftResult.SUCCESS,
		"final_roll": outcome,
		"final_rarity": final_rarity,
		"can_reroll": false,
	}
