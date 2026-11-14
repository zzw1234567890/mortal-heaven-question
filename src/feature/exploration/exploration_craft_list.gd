extends RefCounted
## ExplorationCraftList —— 炼丹台 / 炼器台的[b]可炼列表组装[/b]
## （从 [ExplorationCraft] 拆出的只读半边）。[br]
## [br][b]为什么单独一处[/b]：「配方 → 可炼行」的翻译（材料需求 × 持有量 ×
## 解锁等级 × 收藏余量 → 行文案与禁用原因）是纯查表与纯格式化，与「怎么扣材料、
## 怎么建卡、怎么入收藏」是两件事；且结算侧要守在 300 行软上限内
## （.claude/docs/coding-standards.md，同 [code]harvest_panel_layout.gd[/code] 拆分先例）。[br]
## [br][b]配方来自既有配方资源[/b]：[code]AlchemyRecipes[/code] 的
## [code]ALCHEMY_RECIPES[/code] / [code]ARTIFACT_RECIPES[/code] 是配方的唯一
## 真理来源（GDD §1a/§2a 的数据落点）——本模块[b]不硬编码任何配方[/b]。[br]
## [br][b]只读[/b]：本模块不写任何状态，也不查 GSM 之外的系统——持有量由调用方
## 读好后传入（[code]ExplorationCraft.balance[/code]），故可 GUT 直调。[br]
##
## 来源: design/gdd/alchemy-crafting-system.md §1a/§2a/§3/§4/§边界/AC-1、
## 先例 [code]exploration_harvest_table.gd[/code]（查表与文案单点）。

## 配方表（配方的唯一真理来源）。
const RecipeScript := preload("res://src/feature/alchemy/alchemy_recipes.gd")
## 灵材品质中文名（与采集点同一张表——不另建一份词条）。
const TableScript := preload("res://src/feature/exploration/exploration_harvest_table.gd")

## 配方种类——与节点交互类型同名（[code]alchemy[/code] = 炼丹台 / [code]forge[/code] = 炼器台）。
const KIND_ALCHEMY: StringName = &"alchemy"
const KIND_FORGE: StringName = &"forge"

## 稀有度中文名（[code]CardTemplate.Rarity[/code] 1-5——与商店/战斗奖励同口径）。
const RARITY_NAMES: Dictionary = {1: "白", 2: "蓝", 3: "紫", 4: "金", 5: "暗金"}

## 境界名（解锁提示用——与 [code]node_combat_preview_rules.REALM_NAMES[/code] 同源）。
const REALM_NAMES: Dictionary = {
	1: "炼气", 2: "筑基", 3: "金丹", 4: "元婴", 5: "化神",
}

## 面向玩家的中文提示（面板原样显示——UI 不另写措辞）。
const TEXT_NO_RECIPE: String = "没有这道配方"
const TEXT_LOCKED: String = "需突破至%s期方可炼制"
const TEXT_FULL: String = "收藏已满，无法炼制"
const TEXT_SHORT: String = "灵材不足：%s"


## 配方清单——种类未知时返回空数组（面板显示「无方可炼」而非崩溃）。
static func recipes_of(p_kind: StringName) -> Array:
	if p_kind == KIND_FORGE:
		return RecipeScript.get_all_artifact_recipes()
	if p_kind == KIND_ALCHEMY:
		return RecipeScript.get_all_pill_recipes()
	return []


## 按 recipe_id 取完整配方（可炼行只带展示字段，结算侧需要原始 materials）。[br]
## [br][b]两份表都要查[/b]：配方 ID 在炼丹与炼器表之间不重名，但调用方给错
## [code]kind[/code] 时按「另一个表也查一遍」兜底比返回空更接近玩家预期。
static func recipe_of(p_kind: StringName, p_recipe_id: String) -> Dictionary:
	var recipe: Dictionary = {}
	if p_kind == KIND_FORGE:
		recipe = RecipeScript.get_artifact_recipe(p_recipe_id)
	else:
		recipe = RecipeScript.get_pill_recipe(p_recipe_id)
	if recipe.is_empty():
		recipe = RecipeScript.get_pill_recipe(p_recipe_id)
	if recipe.is_empty():
		recipe = RecipeScript.get_artifact_recipe(p_recipe_id)
	return recipe


## 可炼列表。[br]
## [br][param p_kind] 配方种类。[br]
## [param p_counts] 各品质档位的灵材持有量 [code]{quality: count}[/code]。[br]
## [param p_level] 当前炼丹/炼器等级（与 [code]recipe.unlock_level[/code] 比较）。[br]
## [param p_collection_count] 收藏池当前张数（与 [param p_cap] 比较判满）。[br]
## [param p_cap] 收藏池容量。[br]
## [br][b]返回[/b]：条目数组，每条 [code]{index, recipe_id, name, rarity, rarity_name,
## cost_text, costs, locked, lock_reason, full, affordable, enabled, reason}[/code]。[br]
## [br][b]材料与持有量[/b]：[code]cost_text[/code] 是「所需 × 持有」的现成文案、
## [code]costs[/code] 是结构化的 [code]{quality, quality_name, need, held, enough}[/code]
## ——面板直接渲染，不做数值判断（UI 零数值计算）。[br]
## [br][b]禁用原因只有一条[/b]（等级 > 收藏 > 灵材）：行文本容量有限，
## 玩家看到第一条就该知道下一步做什么。
static func entries_of(p_kind: StringName, p_counts: Dictionary, p_level: int,
		p_collection_count: int, p_cap: int) -> Array:
	var full: bool = p_collection_count >= p_cap
	var out: Array = []
	var recipes: Array = recipes_of(p_kind)
	for i: int in recipes.size():
		out.append(entry_of(recipes[i], i, p_counts, p_level, full))
	return out


## 单条配方 → 可炼行。[br]
## [br][param p_recipe] [method recipes_of] 的条目（含 [code]recipe_id[/code]）。[br]
## [param p_index] 行号（结算时回传）。[br]
## [param p_counts] 各品质档位的持有量。[br]
## [param p_level] 当前炼丹/炼器等级。[br]
## [param p_full] 收藏池是否已满。
static func entry_of(p_recipe: Dictionary, p_index: int, p_counts: Dictionary,
		p_level: int, p_full: bool) -> Dictionary:
	var recipe_id: String = str(p_recipe.get("recipe_id", ""))
	var rarity: int = int(p_recipe.get("rarity", 1))
	var costs: Array = costs_of(p_recipe.get("materials", {}), p_counts)
	var unlock: int = int(p_recipe.get("unlock_level", 0))
	var locked: bool = p_level < unlock
	var short_text: String = short_text_of(costs)
	var lock_reason: String = TEXT_LOCKED % str(REALM_NAMES.get(unlock + 1, ""))

	var reason: String = ""
	if locked:
		reason = lock_reason
	elif p_full:
		reason = TEXT_FULL
	elif not short_text.is_empty():
		reason = TEXT_SHORT % short_text

	return {
		"index": p_index,
		"recipe_id": recipe_id,
		"name": str(p_recipe.get("name", recipe_id)),
		"rarity": rarity,
		"rarity_name": str(RARITY_NAMES.get(rarity, "")),
		"cost_text": cost_text_of(costs),
		"costs": costs,
		"locked": locked,
		"lock_reason": lock_reason if locked else "",
		"full": p_full,
		"affordable": short_text.is_empty(),
		"enabled": reason.is_empty(),
		"reason": reason,
	}


## 逐档材料的「所需 / 持有 / 是否够」（按品质升序——面板行序稳定）。
static func costs_of(p_materials: Dictionary, p_counts: Dictionary) -> Array:
	var qualities: Array = p_materials.keys()
	qualities.sort()
	var out: Array = []
	for q: Variant in qualities:
		var quality: int = int(q)
		var need: int = int(p_materials[q])
		var held: int = int(p_counts.get(quality, 0))
		out.append({
			"quality": quality,
			"quality_name": str(TableScript.QUALITY_NAMES.get(quality, "")),
			"need": need,
			"held": held,
			"enough": held >= need,
		})
	return out


## 材料清单文案——「下品×2（持 5）· 中品×1（持 0）」（所需与持有并排，
## 玩家不必自己减）。
static func cost_text_of(p_costs: Array) -> String:
	var parts: Array = []
	for raw: Variant in p_costs:
		var c: Dictionary = raw
		parts.append("%s×%d（持 %d）" % [str(c.get("quality_name", "")),
				int(c.get("need", 0)), int(c.get("held", 0))])
	return " · ".join(parts)


## 缺口文案——「下品 ×2 · 中品 ×1」；材料齐备时空串。
static func short_text_of(p_costs: Array) -> String:
	var parts: Array = []
	for raw: Variant in p_costs:
		var c: Dictionary = raw
		if bool(c.get("enough", false)):
			continue
		parts.append("%s ×%d" % [str(c.get("quality_name", "")),
				int(c.get("need", 0)) - int(c.get("held", 0))])
	return " · ".join(parts)
