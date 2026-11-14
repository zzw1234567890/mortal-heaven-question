extends RefCounted
## CombatBagEntries —— 「战斗内行囊」条目的只读投影 + 目标候选池。[br]
## [br][b]职责[/b]：把真实收藏里的丹药与法宝读成一列可直接确认的条目（附上「能不能用 /
## 为什么不能用」），并给出当前可施术的目标候选。不硬编码任何物品——读的是
## [code]InventoryModel.category_entries[/code] 的产出，即存档里真实持有的卡实例。[br]
## [br][b]只读，一个字节都不写[/b]：本模块不扣费、不扣卡、不落库。「能不能用」是给游标
## 用的灰显判据，最终动手的是 [code]combat_bag_use.gd[/code]——面板读到 usable 只意味着
## 「这一行可点」，绝不意味着已经发生了什么（ADR-0031 §2）。[br]
## [br][b]判据不在这里[/b]：本模块只负责[b]取数[/b]（模型 / 模板 / 状态表 / 费用），
## 「为什么不能用的那句话」由 [code]combat_bag_rules.gd[/code] 的纯函数给出——两者分开后
## 每个拒绝分支都能脱离 Autoload 单测。[br]
## [br][b]与背包界面同源、不同域[/b]：条目来自同一个 [InventoryModel]（背包与战斗行囊
## 看到的必须是同一份收藏），但可用性判据不同——背包里「不是丹药就不能用」，战斗里
## 还要过灵力、要有需要治疗的人、要有可加持的目标。[br]
## [br][b]为什么用 [method CombatRosterState.snapshot_all] 数人[/b]：战斗内我方角色 ID
## 只存在于状态表里（阵位是另一份数据，且可能已有阵亡清位）。快照是公开契约，不必为了
## 「列出我方」再开一个 API。[br]
##
## 来源: design/gdd/alchemy-crafting-system.md §1c（丹药使用时机「战斗中或背包」）、
## GDD card-system.md §卡牌类型、ADR-0031 §2、先例
## [code]inventory_model.gd[/code]（只读取数半边）、
## [code]combat_play_bridge.enemy_candidates[/code]（候选池 + 存活判定）。

## 分类表（分类 id 的唯一来源——按 id 找分类下标，不写死下标）。
const CatalogScript := preload("res://src/feature/inventory/inventory_catalog.gd")
## 收藏只读取数半边（背包与行囊共用的同一份投影）。
const ModelScript := preload("res://src/feature/inventory/inventory_model.gd")
## 效果评估层（治疗量 / 效果类别的唯一来源——本模块一个数都不写）。
const EvaluatorScript := preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")
## 评估快照（纯数据容器——战斗内目标不在快照里时绑定乘数取缺省 1.0）。
const SnapshotScript := preload("res://src/feature/card_effect_engine/game_state_snapshot.gd")
## 可用性判据与文案（本模块把取数结果喂给它）。
const RulesScript := preload("res://src/feature/combat/combat_bag_rules.gd")
## 阵营枚举（与状态表同源）。
const RosterStateScript := preload("res://src/feature/combat/combat_roster_state.gd")

## 分类表里的分类 id（不写分类下标——下标随分类表顺序变动，id 才是稳定标识）。
const CATEGORY_ID_PILL: StringName = &"pill"
const CATEGORY_ID_ARTIFACT: StringName = &"artifact"

## 依赖注入（测试用桩；null 时按 Autoload / 本地 new 降级——各方法自带空守卫）。
var inventory_model: RefCounted = null
var card_system: Node = null
var cost_source: Node = null
var roster: RefCounted = null


## 构造——依赖可后置注入（[method set_dependencies]）。
func _init(p_inventory_model: RefCounted = null, p_card_system: Node = null,
		p_cost_source: Node = null, p_roster: RefCounted = null) -> void:
	inventory_model = p_inventory_model
	card_system = p_card_system
	cost_source = p_cost_source
	roster = p_roster


## 后置注入（生产路径：Autoload 就绪后再接上）。
func set_dependencies(p_inventory_model: RefCounted, p_card_system: Node,
		p_cost_source: Node, p_roster: RefCounted) -> void:
	inventory_model = p_inventory_model
	card_system = p_card_system
	cost_source = p_cost_source
	roster = p_roster


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 行囊条目（丹药在前、法宝在后；各自按稀有度降序——与背包同一次序）。[br]
## [br][b]返回[/b]：[code]Array[Dictionary][/code]，每条含
## [code]key, kind, name, rarity, rarity_name, count, card_type, template_id,
## instance_id, cost, target_type, effect_kind, effect_value, usable, reason[/code]。[br]
## [br]空行囊返回空数组（面板据此显示 [constant CombatBagRules.TEXT_EMPTY]——
## 本模块不组装面向玩家的空态句子）。[br]
## [br][b]每类只查一次「场上有没有人可施」[/b]：逐条目扫一遍状态表在条目多时是白费的
## 重复读取，且同一类里所有条目共用一个答案。
func entries() -> Array:
	var out: Array = []
	out.append_array(_category_entries(RulesScript.KIND_PILL, CATEGORY_ID_PILL))
	out.append_array(_category_entries(RulesScript.KIND_ARTIFACT, CATEGORY_ID_ARTIFACT))
	return out


## 可施术的目标候选（[code][{character_id, current_hp, max_hp, label}][/code]，ID 升序）。[br]
## [br][param p_for_pill] true = 只列[b]有缺口且存活[/b]的人（满血吃药是无意义操作）；
## false = 列[b]全部存活者[/b]（法宝加的是攻防，满血也吃得着）。[br]
## [br][b]未知角色不列[/b]：状态表里读不到可信数值的人加了也读不回来（同
## [code]combat_roster_state.apply_bonus[/code] 的守卫）。
func targets(p_for_pill: bool) -> Array:
	var out: Array = []
	for entry: Variant in _snapshot():
		if not (entry is Dictionary):
			continue
		var row: Dictionary = entry
		if int(row.get("side", RosterStateScript.SIDE_ENEMY)) \
				!= RosterStateScript.SIDE_PLAYER:
			continue
		if not bool(row.get("known", false)) or not bool(row.get("is_alive", true)):
			continue
		var current: int = int(row.get("current_hp", 0))
		var max_hp: int = int(row.get("max_hp", 0))
		if p_for_pill and current >= max_hp:
			continue
		var character_id: int = int(row.get("character_id", -1))
		out.append({
			"character_id": character_id,
			"current_hp": current,
			"max_hp": max_hp,
			"label": RulesScript.target_label(character_id),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["character_id"]) < int(b["character_id"]))
	return out


## 按 [code]template_id[/code] 查模板——卡牌系统缺失或 ID 为空时返回 null。[br]
## 结算层与投影共用同一次查询口径（本模块产出的条目已带模板结论，见 [method entries]）。
func template_of(p_entry: Dictionary) -> Variant:
	return _template_by_id(str(p_entry.get("template_id", "")))


## 当前可用灵力（只为「灵力不足」的提示取数——判定归费用系统）。
func current_cost() -> int:
	var source: Node = _resolve_cost()
	if source == null or not source.has_method(&"get_current_cost"):
		return 0
	return int(source.call(&"get_current_cost"))


## 该费用是否付得起——费用系统缺失时按「够」放行（桩环境不锁死，同出牌桥口径）。[br]
## 真正的扣费与二次拒绝在 [code]combat_bag_use.gd[/code]——这里只是灰显判据。
func can_afford(p_cost: int) -> bool:
	var source: Node = _resolve_cost()
	if source == null or not source.has_method(&"can_afford"):
		return true
	return bool(source.call(&"can_afford", p_cost))


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：单个分类
# ═══════════════════════════════════════════════════════════════════════════════

## 某分类的条目投影（模型给的条目 → 行囊条目 + 判据结论）。
func _category_entries(p_kind: StringName, p_category_id: StringName) -> Array:
	var out: Array = []
	var model: RefCounted = _resolve_model()
	var index: int = _category_index(p_category_id)
	if model == null or index < 0:
		return out
	var has_target: bool = not targets(p_kind == RulesScript.KIND_PILL).is_empty()
	for raw: Variant in model.call(&"category_entries", index):
		if raw is Dictionary:
			out.append(_to_entry(raw, p_kind, has_target))
	return out


## 模型条目 → 行囊条目（字段补全，可用性交 [code]combat_bag_rules.gd[/code] 裁定）。[br]
## [br][param p_has_target] 场上是否有人可施（每类各查一次，不逐条目重复扫状态表）。
func _to_entry(p_entry: Dictionary, p_kind: StringName, p_has_target: bool) -> Dictionary:
	var template_id: String = str(p_entry.get("template_id", ""))
	var template: Variant = _template_by_id(template_id)
	var instance_ids: Array = p_entry.get("instance_ids", [])
	var cost: int = int(template.get("cost")) if template != null else 0
	var evaluation: Dictionary = _evaluation(template)
	var entry: Dictionary = {
		"key": "%s:%s" % [p_kind, template_id],
		"kind": p_kind,
		"name": str(p_entry.get("name", "")),
		"rarity": int(p_entry.get("rarity", 0)),
		"rarity_name": str(p_entry.get("rarity_name", "")),
		"count": int(p_entry.get("count", 0)),
		"card_type": int(p_entry.get("card_type", -1)),
		"template_id": template_id,
		"instance_id": int(instance_ids[0]) if not instance_ids.is_empty() else -1,
		"cost": cost,
		"target_type": str(template.get("target_type")) if template != null else "",
		"effect_kind": int(evaluation.get("kind", EvaluatorScript.EffectCategory.UNEVALUABLE)),
		"effect_value": int(evaluation.get("value", 0)),
		"stat_changes": evaluation.get("changes", {}),
	}
	entry["reason"] = RulesScript.reason_for(entry, template != null, p_has_target,
			can_afford(cost), current_cost())
	entry["usable"] = str(entry["reason"]).is_empty()
	entry["text"] = RulesScript.row_text(entry)
	return entry


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：取数
# ═══════════════════════════════════════════════════════════════════════════════

## 分类下标——按 id 查（下标随分类表顺序变动，id 才是稳定标识）。找不到返回 -1。
static func _category_index(p_category_id: StringName) -> int:
	for index: int in range(CatalogScript.category_count()):
		if str(CatalogScript.category_at(index).get("id", "")) == str(p_category_id):
			return index
	return -1


## 效果评估——类别 / 数值 / 属性增量一次算齐（评估器无状态，多调一次只是省一次解析）。[br]
## [br][b]返回[/b]：[code]{kind, value, changes}[/code]；模板缺失时全为「不可评估 / 0」。[br]
## [br][b]为什么合成一处[/b]：类别决定判据走哪条、数值决定行文案、增量决定法宝的措辞——
## 三者出自同一次 [code]evaluate_effects[/code]，分开各调一次会读到三份可能不一致的结果。[br]
## [br][b]快照里没有目标也无妨[/b]：评估只把目标用于「是否溢出 / 是否超上限」的标记，
## 数值本身只取决于 [code]effect_value[/code] 与该目标的绑定乘数；目标不在快照内时
## 乘数取缺省 1.0（[code]GameStateSnapshot.get_binding_multiplier[/code]）——正是行囊里
## 「还没挂到任何人身上」的应有之义。
func _evaluation(p_template: Variant) -> Dictionary:
	var empty: Dictionary = {
		"kind": EvaluatorScript.EffectCategory.UNEVALUABLE, "value": 0, "changes": {},
	}
	if p_template == null:
		return empty
	var evaluator: RefCounted = EvaluatorScript.new()
	var outcome: RefCounted = evaluator.call(&"evaluate_effects", p_template, 0,
			SnapshotScript.new({}))
	var changes: Variant = outcome.get("stat_changes")
	return {
		"kind": int(evaluator.call(&"category_of", p_template)),
		"value": maxi(int(outcome.get("healing")), 0),
		"changes": changes if changes is Dictionary else {},
	}


## 我方状态快照（状态表缺失时为空数组——空行囊的诚实表达，不臆造队伍）。
func _snapshot() -> Array:
	if roster == null or not roster.has_method(&"snapshot_all"):
		return []
	var raw: Variant = roster.call(&"snapshot_all")
	return raw if raw is Array else []


## 按 [code]template_id[/code] 查模板——卡牌系统缺失或 ID 为空时返回 null。
func _template_by_id(p_template_id: String) -> Variant:
	if p_template_id.is_empty():
		return null
	var system: Node = _resolve_card_system()
	if system == null or not system.has_method(&"get_template"):
		return null
	return system.call(&"get_template", StringName(p_template_id))


## 收藏投影——注入优先，否则本地 new（它自己去找 Autoload；全缺时其读取返回空）。
func _resolve_model() -> RefCounted:
	if inventory_model != null:
		return inventory_model
	return ModelScript.new()


func _resolve_card_system() -> Node:
	if card_system != null:
		return card_system
	return _autoload(&"CardSystem")


func _resolve_cost() -> Node:
	if cost_source != null:
		return cost_source
	return _autoload(&"CostSystem")


## Autoload 动态查找（无 SceneTree / 未注册时返回 null，不抛错）。
static func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
