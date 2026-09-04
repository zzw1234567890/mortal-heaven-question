class_name AlchemyQualityRoller
extends RefCounted
## AlchemyQualityRoller —— 炼丹炼器品质掷骰纯函数子模块（从 alchemy_system.gd 拆分）。
##
## 纯函数类——品质掷骰、品质倍率、丹药效果缩放、法宝属性生成、九转金丹阈值。[br]
## 所有方法为 static，不持有任何状态。[br]
## [br]来源: GDD alchemy-crafting-system.md §1-3 + ADR-0028 §quality_roll §pill_effect。[br]
## [br]Sprint 9 Story 5：从 alchemy_system.gd 拆分。


# === 品质倍率映射（与 AlchemySystem.QUALITY_MOD 一致）==========================

## 品质掷骰结果 → 品质倍率映射（GDD §0 品质掷骰→品质倍率映射）。
const QUALITY_MOD: Dictionary = {
	-1: 0.8,   # DOWNGRADE
	0: 1.0,    # STANDARD
	1: 1.3,    # UPGRADE
}


# === 品质掷骰纯函数 ==============================================================

## 品质掷骰——首次掷骰（GDD §1 品质概率公式）。[br]
## [br][param recipe_base_rarity] 配方基础稀有度 [1, 5]。[br]
## [br][param alchemy_level] 当前炼丹/炼器等级 [0, 4]。[br]
## [br][param bonuses] 外部加成（万象真人+0.15 + 材料溢出+0.10/级）。[br]
## [br][param rng] 独立 RNG 实例。[br]
## [br][b]返回[/b]: int——-1(DOWNGRADE)/0(STANDARD)/1(UPGRADE)。[br]
## [br]来源: GDD §1 品质概率公式 + ADR-0028 §quality_roll。
static func quality_roll(recipe_base_rarity: int, alchemy_level: int, bonuses: float, rng: RandomNumberGenerator) -> int:
	var high_chance: float = minf(0.10 + alchemy_level * 0.05 + bonuses, 0.8)
	var low_chance: float = 0.1 if recipe_base_rarity > 1 else 0.0
	var roll: float = rng.randf()
	if roll < low_chance:
		return -1  # DOWNGRADE
	if roll < low_chance + high_chance:
		return 1   # UPGRADE
	return 0       # STANDARD


## 品质重掷——玩家选择重掷后的二次掷骰（GDD §1b 品质重掷公式）。[br]
## [br]升品概率 +15%，降品概率升至 25%。[br]
## [br][param recipe_base_rarity] 配方基础稀有度。[br]
## [br][param alchemy_level] 当前炼丹/炼器等级。[br]
## [br][param bonuses] 外部加成。[br]
## [br][param rng] 独立 RNG 实例。[br]
## [br][b]返回[/b]: int——-1(DOWNGRADE)/0(STANDARD)/1(UPGRADE)。[br]
## [br]来源: GDD §1b 品质重掷公式 + ADR-0028 §quality_reroll。
static func quality_reroll(recipe_base_rarity: int, alchemy_level: int, bonuses: float, rng: RandomNumberGenerator) -> int:
	var high_chance: float = minf(0.10 + alchemy_level * 0.05 + bonuses + 0.15, 0.8)
	var low_chance: float = 0.25 if recipe_base_rarity > 1 else 0.0
	var roll: float = rng.randf()
	if roll < low_chance:
		return -1  # DOWNGRADE
	if roll < low_chance + high_chance:
		return 1   # UPGRADE
	return 0       # STANDARD


## 获取品质修改后的稀有度（GDD §1 品质概率公式）。[br]
## [br][param recipe_base_rarity] 配方基础稀有度。[br]
## [br][param outcome] 品质掷骰结果（-1/0/1）。[br]
## [br][b]返回[/b]: 最终稀有度（钳制在 [1, 5]）。[br]
## [br]来源: GDD §1 + ADR-0028 §resolve_final_rarity。
static func resolve_final_rarity(recipe_base_rarity: int, outcome: int) -> int:
	match outcome:
		-1:  # DOWNGRADE
			return maxi(recipe_base_rarity - 1, 1)
		1:   # UPGRADE
			return mini(recipe_base_rarity + 1, 5)
		_:
			return recipe_base_rarity


## 品质倍率映射——outcome → float。[br]
## [br][param outcome] 品质掷骰结果（-1/0/1）。[br]
## [br][b]返回[/b]: 0.8 / 1.0 / 1.3。[br]
## [br]来源: GDD §0 + ADR-0028 §QUALITY_MOD。
static func quality_mod_from_outcome(outcome: int) -> float:
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
