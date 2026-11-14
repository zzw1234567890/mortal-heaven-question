extends RefCounted
## ExplorationCraft —— 炼丹台 / 炼器台节点的[b]炼制结算[/b]（Feature 层）。[br]
## [br][b]职责[/b]：把「到达丹炉/炼器台的可炼配方」落到玩法状态上——校验全部通过
## 后才扣灵材 → 建卡实例 → 走 GSM 原子写入口入收藏。可炼列表的组装在
## [ExplorationCraftList]（只读半边），本文件只管写。[br]
## [br][b]为什么在 Feature 层而不是 UI 里[/b]：扣材料与入收藏是玩法状态变更
## （control-manifest：UI 只发起请求、显示系统返回的文案，不碰 GSM）。[br]
## [br][b]复用的既有设施（不另开第二条通路）[/b]：[br]
##   · 炼制编排——[code]AlchemySystem.craft_pill[/code] /
##     [code]craft_artifact[/code]（ADR-0028 §craft_pill：品质掷骰 + 建实例 +
##     入收藏 + 写卡组）；[br]
##   · 灵材扣减——[code]ResourceSystem.spend_resource[/code]
##     → GSM [code]_set_resource_ling_cai[/code]；[br]
##   · 入收藏——[code]GameStateManager.add_card_to_collection[/code]
##     （ADR-0019 §关键接口）。[br]
## [br][b]为什么还要在调 craft_pill 之前自己校验一遍[/b]：[code]craft_pill[/code]
## 的失败分支发生在[b]扣材料之后[/b]（卡牌系统缺失时它仍返回 SUCCESS 且材料已扣）。
## 「失败不改任何状态」要求拒绝路径全部落在扣材料之前，故本模块把六项前置条件
## （配方存在 / 等级够 / 材料足 / 卡牌系统可用 / 模板已就位 / 收藏未满）先验完，
## 让 craft_pill 的三条失败路径不可能被走到；[method _refund] 是第二道保险。[br]
## [br][b]失败不半完成[/b]：万一 craft_pill 仍报失败或没给出实例 ID，按配方表原样
## 退回已扣灵材（同商店「钱没了卡也没到」的处置口径）。[br]
## [br][b]「收藏已满」的口径[/b]：GDD alchemy-crafting-system.md §边界只说
## 「收藏池允许同名多张」、未给总量上限，而 AC 要求「已满时拒绝且不改状态」。
## 本模块把 [constant COLLECTION_CAP] 定为收藏池容量（一局上限，覆盖全图鉴的
## 215~250 张），与 [code]ExplorationHarvest.LING_CAI_CAP[/code] 同一处置方式：
## 设计未定处取一个可测的口径并显式登记（见类末「已知边界」）。[br]
##
## 来源: design/gdd/alchemy-crafting-system.md §1a/§2a/§3/§4/§边界/AC-1/AC-13、
## ADR-0028 §craft_pill / §craft_artifact、ADR-0019 §关键接口、
## 先例 [code]exploration_harvest.gd[/code]（结算）与
## [code]exploration_shop.gd[/code]（先建实例再扣费）。[br]
## [br][b]已知边界[/b]（本轮未闭合，均不影响点名验收）：[br]
##   · 化神期「丹道大成」（本局首次必升品）无持久化状态位——恒传 false；[br]
##   · 品质加成 [code]quality_bonuses[/code] 恒 0——万象真人本命 +0.15 与
##     「材料品质溢出 +0.10/级」尚未接线；[br]
##   · 炼器产出的法宝白值（GDD §2c [code]forge_artifact_stat[/code]）未写进卡实例
##     ——[code]CardTemplate[/code] 无法宝攻防字段，待法宝系统落地时接入；[br]
##   · [code]craft_pill[/code] 第 6 步会把产出写进卡组一次，卡组满时只留一条
##     push_warning（材料已扣、卡已入库，不影响本次验收）；[br]
##   · [constant COLLECTION_CAP] 的口径见上。

## 配方表与可炼列表组装（配方的唯一真理来源 + 行文案单点）。
const ListScript := preload("res://src/feature/exploration/exploration_craft_list.gd")
## 炼制编排（品质掷骰 + 建实例 + 入收藏 + 写卡组——ADR-0028 §craft_pill）。
const AlchemyScript := preload("res://src/feature/alchemy_system.gd")

## 收藏池容量（见类文档「收藏已满」的口径）。
const COLLECTION_CAP: int = 300

## 外部品质加成——本轮恒 0（见类末「已知边界」）。
const BONUS_NONE: float = 0.0

## 面向玩家的中文提示（面板原样显示——UI 不另写措辞）。
const TEXT_CRAFTED: String = "炼成 %s（%s）"
const TEXT_FAILED: String = "炼制失败，灵材已退回"

## 依赖注入（测试用桩；null 时按 Autoload 查找）。
var resource_system: Node = null
var card_system: Node = null
var gsm: Node = null
## 品质掷骰 RNG——由调用方注入（生产为随机实例，测试注入固定种子）。
var rng: RandomNumberGenerator = null

## 父节点引用——ExplorationSystem 实例（GSM 与 Autoload 的入口）。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# ═══════════════════════════════════════════════════════════════════════════════
# 只读（转发给列表组装——面板的单一数据源）
# ═══════════════════════════════════════════════════════════════════════════════

## 可炼列表（只读——不修改任何状态，面板每次现取即刷新持有量与「已满」态）。[br]
## [br][param p_kind] 配方种类（[code]alchemy[/code] / [code]forge[/code]）。[br]
## [br][b]返回[/b]：同 [method ExplorationCraftList.entries_of]。
func entries(p_kind: StringName) -> Array:
	return ListScript.entries_of(p_kind, balance(), _alchemy_level(),
			_collection_count(), COLLECTION_CAP)


## 各品质档位的灵材持有量（面板顶部摘要——只读 ResourceSystem）。
func balance() -> Dictionary:
	var rs: Node = _rs()
	var counts: Dictionary = {}
	for quality: int in [1, 2, 3, 4]:
		counts[quality] = 0
		if rs != null and rs.has_method(&"get_resource"):
			counts[quality] = int(rs.call(&"get_resource", &"ling_cai", quality))
	return counts


# ═══════════════════════════════════════════════════════════════════════════════
# 炼制结算（校验 → 扣料 → 建实例 → 入收藏）
# ═══════════════════════════════════════════════════════════════════════════════

## 炼制第 [param p_index] 道配方。[br]
## [br][param p_kind] 配方种类。[br]
## [br][b]返回[/b]：[code]{success, reason, message, recipe_id, card_instance_id,
## final_rarity}[/code]——[code]message[/code] 为面向玩家的中文提示。[br]
## [br][b]拒绝路径全在扣料之前[/b]：下标越界 / 等级不足 / 收藏已满 / 灵材不足 /
## 系统不可用 → 不改任何状态。[br]
## [br]来源: GDD §边界（灵材不足时配方选项置灰不可点）、AC-1（扣料 + 入库）。
func craft(p_kind: StringName, p_index: int) -> Dictionary:
	var list: Array = entries(p_kind)
	if p_index < 0 or p_index >= list.size():
		return _fail(ListScript.TEXT_NO_RECIPE)
	var entry: Dictionary = list[p_index]
	if not bool(entry.get("enabled", false)):
		return _fail(str(entry.get("reason", ListScript.TEXT_NO_RECIPE)))

	var recipe_id: String = str(entry.get("recipe_id", ""))
	var recipe: Dictionary = ListScript.recipe_of(p_kind, recipe_id)
	if recipe.is_empty():
		return _fail(ListScript.TEXT_NO_RECIPE)
	# 卡牌系统 / 模板就位——craft_pill 在这两处失败时会「材料已扣却建不出卡」，
	# 故提前验完（本模块的拒绝路径全在扣料之前）。
	if not _card_ready(recipe):
		return _fail(ListScript.TEXT_FULL if _collection_count() >= COLLECTION_CAP \
				else ListScript.TEXT_NO_RECIPE)

	var result: Dictionary = _run_craft(p_kind, recipe_id)
	var inst_id: int = int(result.get("card_instance_id", 0))
	if int(result.get("result", -1)) != AlchemyScript.CraftResult.SUCCESS or inst_id == 0:
		_refund(recipe)
		return _fail(TEXT_FAILED)

	var final_rarity: int = int(result.get("final_rarity", int(recipe.get("rarity", 1))))
	return {
		"success": true,
		"reason": "",
		"message": TEXT_CRAFTED % [str(recipe.get("name", recipe_id)),
				str(ListScript.RARITY_NAMES.get(final_rarity, ""))],
		"recipe_id": recipe_id,
		"card_instance_id": inst_id,
		"final_rarity": final_rarity,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 内部（系统接入）
# ═══════════════════════════════════════════════════════════════════════════════

## 卡牌系统与目标模板是否就位（模板缺失时 craft_pill 会 push_error + 建不出实例）。
func _card_ready(p_recipe: Dictionary) -> bool:
	var cs: Node = card_system if card_system != null else _autoload(&"CardSystem")
	if cs == null or not cs.has_method(&"create_instance"):
		return false
	if not cs.has_method(&"has_template"):
		return true
	return bool(cs.call(&"has_template", StringName(str(p_recipe.get("template_id", "")))))


## 走既有炼制编排（ADR-0028——品质掷骰 / 建实例 / 入收藏 / 写卡组都在里面）。
func _run_craft(p_kind: StringName, p_recipe_id: String) -> Dictionary:
	var generator: RandomNumberGenerator = _rng_instance()
	if p_kind == ListScript.KIND_FORGE:
		return AlchemyScript.craft_artifact(p_recipe_id, BONUS_NONE, generator)
	return AlchemyScript.craft_pill(p_recipe_id, BONUS_NONE, generator)


## 退回按配方表扣掉的灵材（craft_pill 未给出实例 ID 时的第二道保险）。[br]
## [br][b]为什么按配方表退而不是记账[/b]：扣减由 craft_pill 内部完成、不返回明细，
## 而配方表就是它的扣减依据——两边同源，不会退错档位。
func _refund(p_recipe: Dictionary) -> void:
	var rs: Node = _rs()
	if rs == null or not rs.has_method(&"add_resource"):
		push_warning("ExplorationCraft: ResourceSystem 不可用，灵材未能退回")
		return
	var materials: Dictionary = p_recipe.get("materials", {})
	for q: Variant in materials:
		rs.call(&"add_resource", &"ling_cai", int(materials[q]), int(q))


## RNG 实例——注入优先，否则自建一个随机种子的（生产路径）。
func _rng_instance() -> RandomNumberGenerator:
	if rng != null:
		return rng
	var generator := RandomNumberGenerator.new()
	generator.randomize()
	return generator


## 炼丹/炼器等级——境界层级 - 1（ADR-0028 §_get_alchemy_level，与 AlchemySystem 同源）。
func _alchemy_level() -> int:
	var store: Node = _gsm()
	if store == null:
		return 0
	return maxi(0, int(store.get(&"player").get("realm", 1)) - 1)


## 收藏池当前张数（GSM 不可用时按 0——不阻断列表渲染）。
func _collection_count() -> int:
	var store: Node = _gsm()
	if store == null:
		return 0
	return int(store.get(&"collection").get("total_count", 0))


## 拒绝结果（统一形状——面板只读 message）。
static func _fail(p_message: String) -> Dictionary:
	return {"success": false, "reason": p_message, "message": p_message,
			"recipe_id": "", "card_instance_id": 0, "final_rarity": 0}


func _rs() -> Node:
	return resource_system if resource_system != null else _autoload(&"ResourceSystem")


func _gsm() -> Node:
	if gsm != null:
		return gsm
	if _parent != null and _parent.has_method(&"_get_gsm"):
		return _parent.call(&"_get_gsm")
	return _autoload(&"GameStateManager")


## Autoload 动态查找（测试环境缺 Autoload 时返回 null）。
static func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
