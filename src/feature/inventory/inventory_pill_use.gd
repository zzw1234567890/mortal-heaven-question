extends RefCounted
## InventoryPillUse —— 背包内「直接使用丹药」的结算层。[br]
## [br][b]为什么需要它[/b]：丹药卡在 GDD 里本就是一次性消耗品，使用时机写明
## 「战斗中或背包」（design/gdd/alchemy-crafting-system.md §1c）——背包是它的一条
## 正当入口，而不是战斗界面的附属功能。本条路径此前完全缺失：面板只有只读行。[br]
## [br][b]效果读模板、结算走既有设施（一规则两来源都没有）[/b]：[br]
##   · [b]数值[/b]——经 [code]CardEffectEvaluator.evaluate_effects[/code] 汇总
##     [code]effects[/code] / 扁平字段，取 [code]healing[/code]。丹药的数值只在模板里，
##     本模块一个数都不写（也不认识「回春丹是 4 点」）。[br]
##   · [b]写入[/b]——经 [CombatHpCarryover.write_back]（该模块自述为
##     [code]player.character_hp[/code] 的唯一写侧，内部走 GSM 第二层原子方法
##     [code]_set_player_character_hp[/code]）。上限夹取由那一层负责。[br]
##   · [b]消耗[/b]——经 [code]GSM.remove_card_from_collection[/code]（ADR-0006 的
##     权威移除入口，按 [code]card_instance_id[/code]）。[br]
## [br][b]只治「账本里有记录且未满血」的角色[/b]：没记过账 = 从没受过伤（模板满血基准），
## 治它等于给一个本来就没缺口的人加血。这与回复点（[code]ExplorationRest.plan[/code]）
## 是同一口径——稀疏表里没有的条目不是「零血」而是「没数据」。[br]
## [br][b]目标怎么定（本轮裁定，不是新规则）[/b]：[code]target_type[/code] 是模板既有字段，
## 本模块只解释它——[code]all_allies[/code]（天罗丹）治全队可治者；其余（
## [code]single_ally[/code] / [code]self[/code]）治[b]首个需要的人[/b]（角色 ID 升序）。
## 依据是既有先例 [code]CombatCasterRules.resolve_caster[/code]：在没有「选中目标」交互
## 的阶段，一律按标识升序取第一个符合条件者，出手选择 UI 落地后这里换成显式传入。[br]
## [br][b]阵亡不复活[/b]：[code]current_hp <= 0[/code] 的角色既不是治疗对象，也不会被
## 顺带复活（复活是 [code]DeploymentSystem.revive_character[/code] 的职责）。[br]
## [br][b]失败不半完成[/b]：[b]先写血、再取出丹药[/b]；取出失败则按原值回滚血量。
## 反过来的顺序（先取丹药）一旦写入失败就找不回那枚丹——丹药是有限资源，宁可
## 丢掉一次回血也不能凭空吞掉玩家的物品。[br]
## [br][b]返回形状[/b]：[code]{ok, consumed, healed, message}[/code]——面板只负责
## 显示 [code]message[/code]，判断「要不要刷新」看 [code]consumed[/code]（一句话
## 说清结果，界面不做措辞判断，ADR-0031 §2）。[br]
## [br][b]文案本地化豁免[/b]：与 inventory_catalog / inventory_screen 同源口径。[br]
##
## 来源: design/gdd/alchemy-crafting-system.md §1c 丹药效果定义（使用时机「战斗中或背包」）
## / §边界、ADR-0006 §GSM 集成合约、ADR-0031 §2、先例
## [code]exploration_rest.gd[/code]（读 → 计划 → 写回）、
## [code]combat_caster_rules.gd[/code]（无目标选择时的取值先例）。

## 分类表（非丹药提示文案的唯一来源）。
const CatalogScript := preload("res://src/feature/inventory/inventory_catalog.gd")
## 跨战斗 HP 持久化的读写口（读 [code]read_all[/code] / 写 [code]write_back[/code]）。
const CarryoverScript := preload("res://src/feature/combat/combat_hp_carryover.gd")
## 效果评估层（丹药数值的唯一来源）。
const EvaluatorScript := preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")
## 评估快照（纯数据容器——丹药不在场，快照里没有目标也无妨，见 [method _heal_amount]）。
const SnapshotScript := preload("res://src/feature/card_effect_engine/game_state_snapshot.gd")

## [code]CardTemplate.CardType.PILL[/code] 的字面值（不引那个类——模板系统未加载时
## 本条路径也要能判「这不是丹药」，同 [code]InventoryCatalog.CATEGORIES[/code] 的注记）。
const CARD_TYPE_PILL: int = 4

## 模板 [code]target_type[/code] 的「全体友方」取值（其余取值按单目标处理）。
const TARGET_ALL_ALLIES: StringName = &"all_allies"

## 结果文案（本模块是这些句子的唯一来源）。
const TEXT_NO_RECORD: String = "这枚丹药的丹方已散佚——暂时用不了。"
const TEXT_EFFECT_UNKNOWN: String = "这枚丹药的效用尚未参透——暂时用不了。"
const TEXT_NOBODY_NEEDS: String = "此刻无人需要这枚丹药——全队气机完足。"
const TEXT_WRITE_FAILED: String = "此刻气机紊乱，丹药未能入腹——已原样留在行囊里。"
const TEXT_CONSUME_FAILED: String = "丹药未能从行囊中取出——队伍气机已复原。"

## 依赖注入（测试用桩；null 时按 Autoload 查找）。
var gsm: Node = null
var card_system: Node = null
## HP 账本读写口（[code]CombatHpCarryover[/code] 形态：有 [code]read_all[/code] /
## [code]write_back[/code]）。可注入——单测不必去改真实存档（同
## [code]CharacterStatusModel.hp_carryover[/code] 的注记）。
var hp_carryover: RefCounted = null


## 构造——两个依赖都可后置注入（[method set_dependencies]）。
func _init(p_gsm: Node = null, p_card_system: Node = null) -> void:
	gsm = p_gsm
	card_system = p_card_system


## 后置注入（生产路径：Autoload 就绪后再接上）。
func set_dependencies(p_gsm: Node, p_card_system: Node) -> void:
	gsm = p_gsm
	card_system = p_card_system


# ═══════════════════════════════════════════════════════════════════════════════
# 对外
# ═══════════════════════════════════════════════════════════════════════════════

## 使用一条背包条目。[br]
## [br][param p_entry] [code]InventoryModel.category_entries[/code] 的条目（需含
## [code]card_type[/code] / [code]template_id[/code] / [code]instance_ids[/code]）。[br]
## [br][b]返回[/b]: [code]{ok, consumed, healed, message}[/code]——[code]consumed[/code]
## 为真表示行囊里少了一枚（面板据此刷新）。[br]
## [br][b]校验全在动手之前[/b]：类型、模板、实例、缺口四道门全过才开始写状态——
## 任何一道没过，存档一字未动。
func use_entry(p_entry: Dictionary) -> Dictionary:
	if int(p_entry.get("card_type", -1)) != CARD_TYPE_PILL:
		return _failed(CatalogScript.TEXT_NOT_A_PILL)
	var instance_ids: Array = p_entry.get("instance_ids", [])
	if instance_ids.is_empty():
		return _failed(TEXT_NO_RECORD)
	var template: Variant = _template_of(str(p_entry.get("template_id", "")))
	if template == null:
		return _failed(TEXT_NO_RECORD)

	var heal: int = _heal_amount(template)
	if heal <= 0:
		# 模板存在却给不出治疗量 = 效果类型未建模（如九转金丹的「永久 +1 最大生命」）
		# 或该条目不是治疗类——一律如实说「用不了」，不拿 0 点回血冒充成功。
		return _failed(TEXT_EFFECT_UNKNOWN)

	var carryover: RefCounted = _resolve_carryover()
	var table: Dictionary = carryover.call(&"read_all")
	var targets: Array = _targets(template, table)
	if targets.is_empty():
		return _failed(TEXT_NOBODY_NEEDS)

	var entries: Array = _heal_entries(table, targets, heal)
	# 实际回复量必须在写回[b]之前[/b]算：写回之后账本已经是新值，「新减旧」恒为 0。
	var healed: int = _healed_total(table, entries)
	if int(carryover.call(&"write_back", entries)) < 0:
		return _failed(TEXT_WRITE_FAILED)
	if not _consume(int(instance_ids[0])):
		_rollback(carryover, table, targets)
		return _failed(TEXT_CONSUME_FAILED)

	return {
		"ok": true,
		"consumed": true,
		"healed": healed,
		"message": "%s已服下 · 回复 %d 点生命" % [str(template.get("name")), healed],
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 丹药的治疗量——经既有效果评估层汇总（模板的 [code]effects[/code] 或扁平字段）。[br]
## [br][b]快照里没有目标也无妨[/b]：评估只把目标用于「是否溢出」的标记，治疗量本身
## 只取决于 [code]effect_value[/code] 与该目标的绑定乘数；目标不在快照内时乘数取
## 缺省 1.0（[code]GameStateSnapshot.get_binding_multiplier[/code]），正是背包里
## 「不挂在任何人身上」的应有之义。
func _heal_amount(p_template: Variant) -> int:
	var evaluator: RefCounted = EvaluatorScript.new()
	var outcome: RefCounted = evaluator.call(&"evaluate_effects", p_template, 0,
			SnapshotScript.new({}))
	return maxi(int(outcome.get("healing")), 0)


## 可治疗的角色的 ID（升序）；[code]all_allies[/code] 取全部，其余取首个。[br]
## [br][b]跳过谁[/b]：账本里没记录的（没数据，不是零血）、阵亡的（[code]<= 0[/code]，
## 复活不归本模块）、已满血的（无缺口）。见类文档。
func _targets(p_template: Variant, p_table: Dictionary) -> Array:
	var candidates: Array = []
	for key: Variant in p_table.keys():
		var character_id: int = _id_of(key)
		if character_id < 0:
			continue
		var entry: Variant = p_table[key]
		if not (entry is Dictionary):
			continue
		var max_hp: int = maxi(int((entry as Dictionary).get("max_hp", 0)), 0)
		var current: int = clampi(int((entry as Dictionary).get("current_hp", 0)), 0, max_hp)
		if current <= 0 or current >= max_hp:
			continue
		candidates.append(character_id)
	candidates.sort()
	if str(p_template.get("target_type")) == str(TARGET_ALL_ALLIES):
		return candidates
	return [int(candidates[0])] if not candidates.is_empty() else []


## 组装写回条目——每人取 [code]min(治疗量, 自身缺口)[/code]（不超上限，GSM 还会再夹一次）。[br]
## [br][b]逐人取 min 而不是直接加治疗量[/b]：治疗量是模板给定值，缺口是每人各自的——
## 给满血边缘的人加满就够，多出来的部分不该挤进 max_hp 以上（那会被 GSM 夹掉，
## 但显示的实际回复量会虚高）。
func _heal_entries(p_table: Dictionary, p_targets: Array, p_heal: int) -> Array:
	var entries: Array = []
	for raw_id: Variant in p_targets:
		var character_id: int = int(raw_id)
		var before: Dictionary = p_table.get(character_id, {})
		var max_hp: int = maxi(int(before.get("max_hp", 0)), 0)
		var current: int = clampi(int(before.get("current_hp", 0)), 0, max_hp)
		entries.append({
			"side": CarryoverScript.SIDE_PLAYER,
			"known": true,
			"character_id": character_id,
			"current_hp": current + mini(p_heal, max_hp - current),
			"max_hp": max_hp,
		})
	return entries


## 实际写入的回复总量——写回条目与[b]写前[/b]账本原值的差（不虚报被上限吃掉的部分）。[br]
## [br][param p_table] [code]write_back[/code] [b]之前[/b]读到的那份账本：写入是就地生效的，
## 写后再读拿到的已是新值，「新减旧」恒为 0——那样报出来的回复量永远是 0 点。
## 故原值必须由调用方在写之前留好并传进来。
func _healed_total(p_table: Dictionary, p_entries: Array) -> int:
	var total: int = 0
	for raw: Variant in p_entries:
		var entry: Dictionary = raw
		var character_id: int = int(entry.get("character_id", -1))
		var before: Dictionary = p_table.get(character_id, {})
		total += maxi(int(entry.get("current_hp", 0))
				- int(before.get("current_hp", 0)), 0)
	return total


## 回滚一批写回——按账本原值写回去（取出丹药失败时用，见类文档「失败不半完成」）。
func _rollback(p_carryover: RefCounted, p_table: Dictionary, p_targets: Array) -> void:
	var entries: Array = []
	for raw_id: Variant in p_targets:
		var before: Dictionary = p_table.get(int(raw_id), {})
		if before.is_empty():
			continue
		entries.append({
			"side": CarryoverScript.SIDE_PLAYER,
			"known": true,
			"character_id": int(raw_id),
			"current_hp": int(before.get("current_hp", 0)),
			"max_hp": int(before.get("max_hp", 0)),
		})
	if not entries.is_empty():
		p_carryover.call(&"write_back", entries)


## 从收藏移除一张该模板的实例（同名多张时只少一张）。
func _consume(p_instance_id: int) -> bool:
	var store: Node = _resolve_gsm()
	if store == null or not store.has_method(&"remove_card_from_collection"):
		return false
	return bool(store.call(&"remove_card_from_collection", p_instance_id))


## 按 [code]template_id[/code] 查模板——卡牌系统缺失或 ID 为空时返回 null。
func _template_of(p_template_id: String) -> Variant:
	if p_template_id.is_empty():
		return null
	var system: Node = _resolve_card_system()
	if system == null or not system.has_method(&"get_template"):
		return null
	return system.call(&"get_template", StringName(p_template_id))


## 失败结果（存档一字未动——[code]consumed[/code] 恒为假）。
static func _failed(p_message: String) -> Dictionary:
	return {"ok": false, "consumed": false, "healed": 0, "message": p_message}


## 存储键 → 角色 ID（兼容整数键与数字字符串键；非数字键返回 -1）。
static func _id_of(p_key: Variant) -> int:
	if p_key is int:
		return p_key if p_key >= 0 else -1
	var text: String = str(p_key).strip_edges()
	if not text.is_valid_int():
		return -1
	var parsed: int = text.to_int()
	return parsed if parsed >= 0 else -1


## GSM——注入优先，否则 Autoload 查找。
func _resolve_gsm() -> Node:
	if gsm != null:
		return gsm
	return _autoload(&"GameStateManager")


## 卡牌系统——同上。
func _resolve_card_system() -> Node:
	if card_system != null:
		return card_system
	return _autoload(&"CardSystem")


## HP 账本读写口——注入优先，否则本地 new（它自己去找 GSM）。[br]
## [br]new 出来的实例无状态（每次现读现写），复用一个实例只是省一次分配。
func _resolve_carryover() -> RefCounted:
	if hp_carryover != null:
		return hp_carryover
	return CarryoverScript.new()


## Autoload 动态查找（无 SceneTree / 未注册时返回 null，不抛错）。
static func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
