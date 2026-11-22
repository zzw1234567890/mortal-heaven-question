extends RefCounted
## CombatOnPlayEffects —— 出牌「打出即生效」效果的执行端（DEBT-CBT-018-10 第二阶段补链）。[br]
## [br][b]缺在哪一步[/b]：[code]damage_multiplier[/code] 与 [code]heal[/code] 此前只在
## [b]评估层[/b]（[code]CardEffectEvaluator[/code]）算出数值——[code]play_card[/code] 的效果
## 结算走 [code]CardEffectEngine.resolve[/code]，而该 Autoload 上[b]根本没有这个方法[/b]
## （回退返回空数组），于是「倍率伤害」从未落库、「出牌治疗」只有击杀触发那条支路
## （[code]combat_kill_trigger.gd[/code]）会落。本模块补上打出瞬间的执行端。[br]
## [br][b]两段式（先伤害后治疗）[/b]：[method collect] 只算出伤害结果项与待落库的治疗，
## 伤害并入 [code]play_card[/code] 的统一落库链路（[method CombatDamageSettlement.settle_effect]）；
## [method apply_heals] 在伤害落库[b]之后[/b]才执行（[method CombatDamageSettlement.apply_heal]），
## 保证 [code]character_damaged[/code] 广播顺序是「先掉血、后回血」，与击杀触发的顺序一致。[br]
## [br][b]唯一写 HP 的路径不变[/b]：本模块不碰 [code]current_hp[/code]，
## 全部经落库子模块的两个公开入口。[br]
## [br][b]目标裁定[/b]（防误伤）[br]
##   · [code]target = self[/code] 的[b]治疗[/b]——只落施法者；[br]
##   · [code]target = self[/code] 的[b]伤害[/b]——[b]整条跳过[/b]：GDD 无「自伤」模型，
##     既不臆造一条自我伤害规则，也绝不把伤害打到调用方给的目标上；[br]
##   · 未声明 target 的[b]治疗[/b]（旧扁平卡如培元丹只写 [code]target_type[/code]）——
##     落施法者：漏认会让真实资产的治疗静默失效，而误把治疗写给别人并非本模块的路径；[br]
##   · 显式指向他人的[b]治疗[/b]（[code]single_ally[/code] 之类）——跳过并告警，
##     该形态尚无模型，不把治疗写错对象；[br]
##   · 非 self 的[b]伤害[/b]——打调用方解析出的目标列表。[br]
## [br][b]攻击力取数（不臆造）[/b]：优先读战斗状态表 [code]CombatRosterState.get_atk[/code]
## （施法者的现有 ATK 来源——敌方 [code]EnemyBattleState.attack[/code] / 我方模板
## [code]base_attack[/code] / [code]player_stats.atk[/code] 三处汇于此），作为
## [code]attacker_atk[/code] 传给评估器；取不到时[b]不写该键[/b]，让评估器回退快照——
## 而快照里[b]只有施法者带 ATK[/b]，目标条目一律不给，故回退值为 0、伤害为 0、不落库。
## （若给目标也填 ATK，评估器会把防御方的 ATK 当成本次攻击力，凭空造出伤害。）[br]
## [br][b]未建模的类别一律跳过[/b]：增益 / 控制 / 抽牌 / 阵法等尚无执行端，本模块不落库、
## 也不把它们折算成伤害，等对应 epic 接线（不静默降级）。[br]
## [br][b]与旧桩的关系[/b]：无 [code]effects[/code] 且无 [code]effect_type[/code] 的卡
## （如只给 [code]template_id[/code] 的测试桩）经汇总器合成一条空条目，落
## [code]UNEVALUABLE[/code]、零贡献——[b]无倍率无治疗时本模块不产生任何副作用[/b]。[br]
## [br]来源: GDD card-system.md §多效果承载、card-effect-engine.md §1、
## ADR-0008 §出牌结算流程、tech-debt DEBT-CBT-018-10。

## 效果条目类型——触发时机常量（[code]TRIGGER_ON_PLAY[/code]）的唯一来源。
const EntryScript: GDScript = preload("res://src/core/card_system/effect_entry.gd")

## 多效果汇总器——取条目列表（旧扁平卡经它合成一条，旧卡零迁移）。
const ComposerScript: GDScript = preload("res://src/feature/card_effect_engine/card_effect_composer.gd")

## 效果评估器——逐条取数值（效果词表与「ATK × 倍率」公式只有一处实现）。
const EvaluatorScript: GDScript = preload("res://src/feature/card_effect_engine/card_effect_evaluator.gd")

## 评估快照类型。
const SnapshotScript: GDScript = preload("res://src/feature/card_effect_engine/game_state_snapshot.gd")

## Debuff 管理器类型——用于效果类型判断。
const DebuffManagerScript: GDScript = preload("res://src/feature/combat/combat_debuff_manager.gd")

## 指向自身的条目标记——只有它才把效果落在施法者身上。
const TARGET_SELF: String = "self"

## Autoload 查找器——本模块内的查找已收拢到它（唯一实现）。
const AutoloadAccess := preload("res://src/feature/combat/combat_autoload_access.gd")

## 父节点引用——CombatSystem 实例（取战斗状态表与落库子模块）。
var _parent: Node = null

## 效果评估器——惰性创建（无状态，可复用）。
var _evaluator_instance: RefCounted = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 收集一张卡[b]打出即生效[/b]的伤害与治疗（[b]不落库[/b]——落库由调用方分两步执行）。[br]
## [br][param card] 打出的卡牌数据（CardTemplate / 含 [code]effects[/code] 或
## [code]template_id[/code] 的 Dictionary）。[br]
## [param targets] 调用方解析出的目标角色 ID 列表（非 self 伤害的落点）。[br]
## [param caster_id] 施法者角色 ID——倍率取数（ATK）与治疗落库的对象；
## 缺省 -1 时[b]不结算[/b]（不猜「谁出的牌」，与击杀触发的施法者口径一致）。[br]
## [br][b]返回[/b]: [code]{damage_results: Array, heals: Array[Dictionary]}[/code]——[br]
##   · [code]damage_results[/code]: 交 [method CombatDamageSettlement.settle_effect] 的结果项；[br]
##   · [code]heals[/code]: [code][{character_id, amount}][/code]，交 [method apply_heals]。
func collect(card: Variant, targets: Array, caster_id: int) -> Dictionary:
	var outcome: Dictionary = {"damage_results": [], "heals": []}
	if card == null or caster_id < 0:
		return outcome
	var source: Variant = _effect_source(card)
	var snapshot: RefCounted = _snapshot(caster_id, targets)
	var context: Dictionary = _context(caster_id)
	for entry: Variant in ComposerScript.effects_of(source):
		# 击杀类条目（trigger="kill"）不在此结算——那由 combat_kill_trigger.gd 按事实触发。
		if not bool(entry.call("matches_trigger", EntryScript.TRIGGER_ON_PLAY)):
			continue
		# 结算回流计数：进入执行端的条目计一条（含尚无执行端的增益/控制/抽牌——
		# 它们同样是「被这张卡触发」的条目，只是本模块不落库）。[br]
		# 不计数的是[b]空占位条目[/b]：汇总器对「既无 effects 也无 effect_type」的卡
		# （只给 template_id 的测试桩 / 空模板）会合成一条全空条目，它没有声明任何效果，
		# 计进去会让「无效果卡」平白多出 1 条。
		if not String(entry.get("effect_type")).is_empty():
			_note_entry()
		var data: Dictionary = entry.call("to_card_data", context)
		var is_self: bool = String(entry.get("target")) == TARGET_SELF
		var category: int = _evaluator().category_of(data)
		if category == EvaluatorScript.EffectCategory.HEAL:
			var healing: int = _resolve_heal(data, caster_id, snapshot)
			if healing > 0:
				outcome["heals"].append({"character_id": caster_id, "amount": healing})
		elif category == EvaluatorScript.EffectCategory.DEBUFF:
			_apply_debuff_effect(data, is_self, targets, caster_id)
		elif _is_damage(category):
			outcome["damage_results"].append_array(
					_damage_items(data, is_self, targets, caster_id, snapshot))
	return outcome

## 治疗落库——把 [method collect] 算出的治疗交给
## [method CombatDamageSettlement.apply_heal]（治疗在落库侧就是负伤害）。[br]
## [br][param heals] [code][{character_id, amount}][/code] 列表（[method collect] 的产出）。[br]
## [br][b]返回的是实际回血量[/b]：落库结果里的 [code]damage[/code] 已是「夹取前后 HP 差」
## 的取负（满血 / 全额溢出时为 0），故累加 [code]-damage[/code]——申请 3 点但只回 2 点时
## 返回 2，与 [code]character_damaged[/code] 广播的数字一致。角色无信 HP（[code]known=false[/code]，
## 未落库）时计 0——不把没发生过的回血算进总数。
func apply_heals(heals: Array) -> int:
	var total: int = 0
	for raw: Variant in heals:
		if not (raw is Dictionary):
			continue
		var item: Dictionary = raw
		var amount: int = int(item.get("amount", 0))
		var character_id: int = int(item.get("character_id", -1))
		if amount <= 0 or character_id < 0:
			continue
		var outcome: Dictionary = _settlement().call(&"apply_heal", character_id, amount)
		if bool(outcome.get("known", false)):
			total += -int(outcome.get("damage", 0))
	return total


# === 治疗 =========================================================================

## 治疗数值解析（不落库）——[code]heal[/code] 条目按施法者口径评估。[br]
## [br][b]落点裁定[/b]：治疗不会伤到任何一方，故 [code]target = self[/code] 与
## [b]未声明 target[/b]（旧扁平卡如培元丹只写 [code]target_type[/code]，缺失即空）
## 一律落施法者；显式指向他人的治疗（[code]single_ally[/code] 之类）当前无模型——
## 跳过并告警，不把治疗写错对象。[br]
## [br][b]返回[/b]: 治疗量（0 = 跳过）。
func _resolve_heal(data: Dictionary, caster_id: int, snapshot: RefCounted) -> int:
	var target: String = String(data.get("target", ""))
	if not target.is_empty() and target != TARGET_SELF:
		push_warning("CombatOnPlayEffects: heal 条目目标为 %s——执行端只能把治疗落在施法者，跳过" % target)
		return 0
	var evaluation: RefCounted = _evaluator().evaluate_effect(data, caster_id, snapshot)
	return maxi(int(evaluation.get("healing")), 0)


# === 伤害 =========================================================================

## 伤害结果项——对每个解析出的目标评估一次（目标 HP 参与 [code]is_overkill[/code] 口径）。[br]
## [br][b]不写 [code]card_data[/code][/b]：由 [code]play_card[/code] 的上下文补全步骤统一
## 填成「打出的那张卡」——击杀触发要按整张卡取 [code]trigger="kill"[/code] 条目，
## 若此处塞进单条效果数据，击杀回血会被评成 0（静默失效）。[br]
## [br][b]返回[/b]: [code]Array[Dictionary][/code]——落库链路可读的结果项（伤害为 0 的条目跳过）。
func _damage_items(data: Dictionary, is_self: bool, targets: Array, caster_id: int,
		snapshot: RefCounted) -> Array:
	if is_self:
		# 自伤未建模——只保证「不误伤目标」，不替策划造一条自我伤害规则。
		push_warning("CombatOnPlayEffects: 伤害条目目标为 self——无自伤模型，跳过（不影响敌方）")
		return []
	var items: Array = []
	for raw: Variant in targets:
		var target_id: int = int(raw)
		if target_id < 0:
			continue
		var evaluation: RefCounted = _evaluator().evaluate_effect(data, target_id, snapshot)
		var damage: int = int(evaluation.get("damage"))
		if damage <= 0:
			continue
		items.append({"target_id": target_id, "damage": damage, "caster_id": caster_id})
	return items


# === 取数 =========================================================================

## 打出卡的效果数据来源——[br]
##   · 卡牌自带 [code]effects[/code] / [code]effect_type[/code] → 原样使用；[br]
##   · 只给 [code]template_id[/code] / [code]card_id[/code] 的字典 → 经 CardSystem 现查模板
##     （取不到时原样返回 → 落 [code]UNEVALUABLE[/code]、零贡献，与旧桩口径一致）。[br]
func _effect_source(card: Variant) -> Variant:
	if not (card is Dictionary):
		return card
	var data: Dictionary = card
	if data.has("effects") or data.has("effect_type"):
		return card
	var template_id: String = str(data.get("template_id", data.get("card_id", "")))
	if template_id.is_empty():
		return card
	var cs: Node = _autoload(&"CardSystem")
	if cs == null or not cs.has_method(&"get_template"):
		return card
	var template: Variant = cs.call(&"get_template", StringName(template_id))
	return template if template != null else card


## 卡片级评估上下文——倍率条目的 [code]attacker_atk[/code]（施法者的现有 ATK 来源）。[br]
## [br]ATK 未知（≤0）时[b]不写该键[/b]——评估器会回退快照，而快照里目标不带 ATK，
## 回退值为 0、伤害为 0、条目自然不落库（不拿防御方的 ATK 顶替）。
func _context(caster_id: int) -> Dictionary:
	var atk: int = int(_roster().call(&"get_atk", caster_id))
	return {"attacker_atk": atk} if atk > 0 else {}


## 评估快照——施法者带 HP/上限/ATK，目标只带 HP/上限（[b]刻意不给 ATK[/b]，见类文档）。[br]
## 未知角色的 HP 数据不可信（[code]known=false[/code]）时不进快照，读回 0 而非臆造。[br]
## [br]绑定乘数不进快照：出牌伤害本就不乘绑定系数（那是绑定侧数值口径），
## 快照缺省 [code]binding_multiplier = 1.0[/code] 即正确。
func _snapshot(caster_id: int, targets: Array) -> RefCounted:
	var characters: Dictionary = {}
	var caster: Dictionary = _hp_entry(caster_id)
	if not caster.is_empty():
		caster["atk"] = int(_roster().call(&"get_atk", caster_id))
		characters[caster_id] = caster
	for raw: Variant in targets:
		var target_id: int = int(raw)
		if target_id < 0 or characters.has(target_id):
			continue
		var entry: Dictionary = _hp_entry(target_id)
		if not entry.is_empty():
			characters[target_id] = entry
	return SnapshotScript.build(characters)


## 角色 HP/上限快照条目——未知角色返回空字典（不进快照）。
func _hp_entry(character_id: int) -> Dictionary:
	var info: Dictionary = _roster().call(&"read_hp", character_id)
	if not bool(info.get("known", false)):
		return {}
	return {"hp": int(info["current_hp"]), "max_hp": int(info["max_hp"])}


## 是否为伤害类条目（绝对值伤害 / 倍率伤害）——加成类（[code]damage_bonus[/code]）不算。
func _is_damage(category: int) -> bool:
	return category == EvaluatorScript.EffectCategory.DAMAGE \
		or category == EvaluatorScript.EffectCategory.DAMAGE_MULTIPLIER


## 施加 debuff 效果——从 EffectEntry 解析 debuff 参数并施加到目标。[br]
## [br][param data] 效果数据（含 effect_type/duration_turns/value）。[br]
## [param is_self] 是否目标为自身（debuff 不支持自施，跳过）。[br]
## [param targets] 目标角色 ID 列表。[br]
## [param caster_id] 施法者角色 ID。
func _apply_debuff_effect(data: Dictionary, is_self: bool, targets: Array, caster_id: int) -> void:
	if is_self:
		push_warning("CombatOnPlayEffects: debuff 条目目标为 self——无自施 debuff 模型，跳过")
		return
	var effect_type: String = str(data.get("effect_type", "")).to_lower()
	var debuff_type: int = -1
	# 从 effect_type 字符串判断 debuff 类型（与 DebuffConfig 枚举对应）
	if effect_type.contains("atk") or effect_type.contains("攻"):
		debuff_type = DebuffManagerScript.TYPE_ATK
	elif effect_type.contains("def") or effect_type.contains("防"):
		debuff_type = DebuffManagerScript.TYPE_DEF
	else:
		push_warning("CombatOnPlayEffects: 无法识别的 debuff 类型 %s，跳过" % effect_type)
		return
	var duration: int = int(data.get("duration_turns", 1))
	var amount: int = int(data.get("value", 1))
	if amount <= 0:
		return
	var roster: Variant = _roster()
	for raw: Variant in targets:
		var target_id: int = int(raw)
		if target_id < 0:
			continue
		roster.call(&"apply_debuff", target_id, debuff_type, duration, amount, caster_id)


## 惰性获取效果评估器。
func _evaluator() -> RefCounted:
	if _evaluator_instance == null:
		_evaluator_instance = EvaluatorScript.new()
	return _evaluator_instance


## 落库子模块——经父节点取（与出牌/击杀结算共用同一实例，不重复建）。
func _settlement() -> RefCounted:
	return _parent.call(&"_get_damage_settlement")


## 结算回流计数——交父节点的战绩累积器（[code]combat_battle_record.gd[/code]）。[br]
## [br]计数只增不减、失败静默：计数本身不参与战斗逻辑，父节点缺该入口时不应打断结算。
func _note_entry() -> void:
	if _parent.has_method(&"_note_effect_entry"):
		_parent.call(&"_note_effect_entry")


## 战斗状态表——ATK / HP 的现读来源。
func _roster() -> RefCounted:
	return _parent.call(&"_get_roster_state")


## 以 SceneTree.root 查找 Autoload——测试环境缺该 Autoload 时返回 null（不抛错）。
func _autoload(node_name: StringName) -> Node:
	return AutoloadAccess.find(node_name)
