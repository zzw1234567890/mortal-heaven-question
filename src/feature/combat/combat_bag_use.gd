extends RefCounted
## CombatBagUse —— 战斗内「直接用丹药 / 法宝」的结算层。[br]
## [br][b]职责[/b]：把面板确认的一行真正落地——[br]
##   1. 校验（种类 / 实物 / 模板 / 效果已建模 / 目标 / 灵力）；[br]
##   2. 扣掉那枚实物（[code]GSM.remove_card_from_collection[/code]）；[br]
##   3. 扣灵力（[code]CostSystem.spend[/code]——与出牌同一套规则，不新造「行动点」）；[br]
##   4. 落效果——委托 [code]combat_bag_effect.gd[/code]（丹药治疗 / 法宝加属性）。[br]
## [br][b]为什么数值一个都不写[/b]：效果类别与点数全部经
## [code]CardEffectEvaluator.evaluate_effects[/code] 现算（与界面显示、与出牌结算同一条
## 算法）——本模块不认识「回春丹是 4 点」这种事实。[br]
## [br][b]为什么落效果拆在别处[/b]：[code]combat_bag_effect.gd[/code] 只管「用下去
## 发生什么」（依赖状态表与伤害落库），本模块管「能不能用」（依赖存档 / 费用 / 候选池）。
## 合成一处会越过 300 行软上限（coding-standards），且两半的测试装置完全不同
## （前者要真实状态表，后者要存档与费用桩）。[br]
## [br][b]步骤顺序（失败不半完成）[/b]：校验全在动手之前；动手时[b]先取实物[/b]
## ——它是本链路里唯一会失败的步骤（校验未开启 / 实例已被移除），放最前则「失败」
## 意味着什么都还没发生。[b]扣费在取物之后[/b]：费用不足已在校验期被拒，此处再失败
## 只可能是战斗刚结束，而那时实物已扣——[b]落库必须照做[/b]，否则玩家白白损失一枚丹；
## 故扣费失败只记错误日志、不中断。反过来的顺序（先扣费再取物）一旦取物失败，
## 玩家损失的是灵力——用一次就回的灵力换一枚要炼出来的丹，不划算。[br]
## [br][b]不推进回合[/b]：本链路只花灵力，阶段与回合数由战斗系统既有节奏驱动
## （「消耗一次行动」在战斗域就是「花掉灵力」，探索域的 [code]action_points[/code]
## 不在这条路径上）。[br]
## [br][b]返回形状[/b]：[code]{ok, consumed, healed, message}[/code]——面板只显示
## [code]message[/code]，判断「要不要刷新」看 [code]consumed[/code]（同
## [code]inventory_pill_use.gd[/code] 的契约）。[br]
## [br][b]文案本地化豁免[/b]：与 combat_play_result / combat_bag_rules 同源口径。
##
## 来源: design/gdd/alchemy-crafting-system.md §1c（丹药使用时机「战斗中或背包」）、
## GDD card-system.md §卡牌类型、ADR-0006 §GSM 集成合约、ADR-0031 §2、先例
## [code]inventory_pill_use.gd[/code]（读模板 → 校验 → 写 → 消耗）、
## [code]combat_card_resolver.gd[/code]（阶段/费用/目标的校验次序）。

## 效果落库半边（类别判定 + 治疗 / 加属性 + 成功文案）。
const EffectScript := preload("res://src/feature/combat/combat_bag_effect.gd")
## 行囊条目投影（目标候选池 + 模板查询的唯一入口，避免两处各查一遍导致判定分叉）。
const EntriesScript := preload("res://src/feature/combat/combat_bag_entries.gd")
## 判据与文案（可用性句子只在那一个文件里定义）。
const RulesScript := preload("res://src/feature/combat/combat_bag_rules.gd")

## 结果文案（本模块是这些句子的唯一来源；界面只显示，不自行措辞）。
## [br][b]为什么「种类不对」在这里而不在 [CombatBagRules][/b]：判据表只服务面板里
## 列出的丹与宝，而本入口是公开方法——传进来一条灵材或符箓时判据表根本没有对应词条
## （它在 [method CombatBagRules.reason_for] 的第一道门就被判成「无实物」）。
const TEXT_BAD_KIND: String = "这件事物不能直接使用"
const TEXT_CONSUME_FAILED: String = "未能从行囊中取出——一切照旧"
const TEXT_TARGET_INVALID: String = "所选目标已不可施术"
const TEXT_BUFF_FAILED: String = "此宝未能加身——气机紊乱"

## 依赖注入（测试用桩；null 时按 Autoload 降级——各方法自带空守卫）。
var entries: RefCounted = null
## 效果落库半边（注入优先，否则本地 new——它自己持状态表与落库句柄）。
var effect: RefCounted = null
var gsm: Node = null
var cost_source: Node = null


## 构造——依赖可后置注入（[method set_dependencies]）。
func _init(p_entries: RefCounted = null, p_effect: RefCounted = null,
		p_gsm: Node = null, p_cost_source: Node = null) -> void:
	entries = p_entries
	effect = p_effect
	gsm = p_gsm
	cost_source = p_cost_source


## 后置注入（生产路径：战斗系统与 Autoload 就绪后再接上）。
func set_dependencies(p_entries: RefCounted, p_effect: RefCounted, p_gsm: Node,
		p_cost_source: Node) -> void:
	entries = p_entries
	effect = p_effect
	gsm = p_gsm
	cost_source = p_cost_source


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 使用一条行囊条目。[br]
## [br][param p_entry] [code]CombatBagEntries.entries()[/code] 的条目。[br]
## [param p_target_ids] 玩家显式指定的目标（空 = 按模板目标词取默认：全体效果取全部
## 可施者，单体取 ID 升序第一个可施者）。[br]
## [br][b]返回[/b]: [code]{ok, consumed, healed, message}[/code]——[code]consumed[/code]
## 为真表示行囊里少了一枚（面板据此刷新）。[br]
## [br][b]校验全在动手之前[/b]：种类、实物、模板、效果、目标、灵力六道门全过才开始
## 改状态——任何一道没过，存档与战场一字未动。
func use_entry(p_entry: Dictionary, p_target_ids: Array = []) -> Dictionary:
	var kind: String = str(p_entry.get("kind", ""))
	if kind != str(RulesScript.KIND_PILL) and kind != str(RulesScript.KIND_ARTIFACT):
		return _failed(TEXT_BAD_KIND)
	var instance_id: int = int(p_entry.get("instance_id", -1))
	if instance_id <= 0:
		return _failed(RulesScript.TEXT_NO_INSTANCE)
	var template: Variant = _template_of(p_entry)
	if template == null:
		return _failed(RulesScript.TEXT_NO_TEMPLATE)

	var is_pill: bool = kind == str(RulesScript.KIND_PILL)
	var evaluated: Dictionary = _effect().call(&"evaluate", template)
	var category: int = int(evaluated.get("kind", -1))
	if category != _expected_category(is_pill):
		return _failed(RulesScript.TEXT_PILL_UNKNOWN if is_pill
				else RulesScript.TEXT_ARTIFACT_INERT)

	var targets: Array = _resolve_targets(p_entry, p_target_ids, is_pill)
	if targets.is_empty():
		return _failed(TEXT_TARGET_INVALID if not p_target_ids.is_empty()
				else _nothing_to_apply(is_pill))
	var cost: int = int(p_entry.get("cost", 0))
	if not _can_afford(cost):
		return _failed(RulesScript.TEXT_NO_COST % [cost, _current_cost()])

	# 动手：实物最会失败，放最前。
	if not _consume(instance_id):
		return _failed(TEXT_CONSUME_FAILED)
	_spend(cost)
	var applied: int = int(_effect().call(&"apply", targets, category, evaluated))
	if applied < 0:
		return {"ok": false, "consumed": true, "healed": 0, "message": TEXT_BUFF_FAILED}
	return {
		"ok": true,
		"consumed": true,
		"healed": applied,
		"message": _effect().call(&"success_text", p_entry, kind, evaluated, applied),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：目标
# ═══════════════════════════════════════════════════════════════════════════════

## 目标裁定——显式指定优先，否则按模板目标词取默认。[br]
## [br][b]显式目标也要过候选池[/b]：不在候选池里的 ID（已阵亡 / 满血 / 未知角色）一律
## 剔除——玩家在面板上选的是当时的行，落地的瞬间必须重新对一次状态。[br]
## [br][b]全体效果取全部候选[/b]（[code]all_allies[/code]，如天罗丹）；其余取 ID 升序
## 第一个——依据是既有先例 [code]combat_caster_rules.resolve_caster[/code]：无选中交互时
## 按标识升序取首个符合条件者。
func _resolve_targets(p_entry: Dictionary, p_target_ids: Array,
		p_is_pill: bool) -> Array:
	var pool: Array = _candidates(p_is_pill)
	var allowed: Dictionary = {}
	for raw: Variant in pool:
		allowed[int((raw as Dictionary).get("character_id", -1))] = true
	if not p_target_ids.is_empty():
		var picked: Array = []
		for raw: Variant in p_target_ids:
			var character_id: int = int(raw)
			if allowed.has(character_id) and not picked.has(character_id):
				picked.append(character_id)
		picked.sort()
		return picked
	if RulesScript.is_all_allies(p_entry):
		return pool.map(func(row: Dictionary) -> int: return int(row["character_id"]))
	return [int((pool[0] as Dictionary)["character_id"])] if not pool.is_empty() else []


## 该条目的候选池——丹药只列有缺口者，法宝列全部存活者（口径在
## [method CombatBagEntries.targets]，本模块不重复判一遍）。
func _candidates(p_is_pill: bool) -> Array:
	var source: RefCounted = _get_entries()
	if source == null or not source.has_method(&"targets"):
		return []
	var raw: Variant = source.call(&"targets", p_is_pill)
	return raw if raw is Array else []


## 该种类应有的效果类别（丹药 = 治疗，法宝 = 增益）。
func _expected_category(p_is_pill: bool) -> int:
	return RulesScript.category_for(true if p_is_pill else false)


## 没有目标可施时的原因句（丹药与法宝在玩家听来是两件事）。
static func _nothing_to_apply(p_is_pill: bool) -> String:
	return RulesScript.TEXT_NOBODY_NEEDS if p_is_pill else RulesScript.TEXT_NO_TARGET


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：取数 / 动作
# ═══════════════════════════════════════════════════════════════════════════════

## 从收藏移除一张该模板的实例（同名多张时只少一张）。[br]
## [br][b]唯一会失败的动手步骤[/b]：校验未开启 / 实例已被移除时返回 false——此时
## 什么都还没发生（见类文档「步骤顺序」）。
func _consume(p_instance_id: int) -> bool:
	var store: Node = _resolve_gsm()
	if store == null or not store.has_method(&"remove_card_from_collection"):
		return false
	return bool(store.call(&"remove_card_from_collection", p_instance_id))


## 扣灵力——与出牌共用 [code]CostSystem[/code] 的同一套规则。[br]
## [br][b]失败只记日志不中断[/b]：费用不足已在校验期被拒，此处再失败只可能是战斗刚结束，
## 而实物已扣——落库必须照做（见类文档「步骤顺序」）。
func _spend(p_cost: int) -> void:
	var source: Node = _resolve_cost()
	if source == null or not source.has_method(&"spend"):
		return
	if not bool(source.call(&"spend", p_cost)):
		push_error("CombatBagUse: 灵力扣除失败（cost=%d）——实物已取出，效果照常落库" % p_cost)


## 该费用是否付得起——费用系统缺失时按「够」放行（桩环境不锁死，同出牌桥口径）。
func _can_afford(p_cost: int) -> bool:
	var source: Node = _resolve_cost()
	if source == null or not source.has_method(&"can_afford"):
		return true
	return bool(source.call(&"can_afford", p_cost))


## 当前灵力——只为「灵力不足」的文案取数。
func _current_cost() -> int:
	var source: Node = _resolve_cost()
	if source == null or not source.has_method(&"get_current_cost"):
		return 0
	return int(source.call(&"get_current_cost"))


## 失败结果（[code]consumed[/code] 恒为假——校验没过就什么都没发生）。
static func _failed(p_message: String) -> Dictionary:
	return {"ok": false, "consumed": false, "healed": 0, "message": p_message}


## 效果落库半边——注入优先，否则本地 new（它自己持状态表与落库句柄）。
func _effect() -> RefCounted:
	if effect == null:
		effect = EffectScript.new()
	return effect


## 行囊条目投影——注入优先，否则本地 new（它自己去找 Autoload）。
func _get_entries() -> RefCounted:
	if entries != null:
		return entries
	return EntriesScript.new()


func _resolve_gsm() -> Node:
	if gsm != null:
		return gsm
	return _autoload(&"GameStateManager")


func _resolve_cost() -> Node:
	if cost_source != null:
		return cost_source
	return _autoload(&"CostSystem")


## 按 [code]template_id[/code] 查模板——委托条目投影（两处各查一遍会让判定分叉）。
func _template_of(p_entry: Dictionary) -> Variant:
	var source: RefCounted = _get_entries()
	if source != null and source.has_method(&"template_of"):
		return source.call(&"template_of", p_entry)
	return null


## Autoload 动态查找（无 SceneTree / 未注册时返回 null，不抛错）。
static func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
