## CombatCardResolver —— 出牌结算子模块（RefCounted）。
##
## 从 combat_system.gd 提取的出牌结算逻辑。[br]
## 持有父节点 CombatSystem 引用，通过它访问牌库/手牌/回调/Autoload。[br]
## [br]来源: ADR-0008 §出牌结算流程 / GDD combat-system.md §2。[br]
## [br]Sprint 8 Story 8-10：从 combat_system.gd 拆分。
extends RefCounted


## 父节点引用——CombatSystem Autoload 实例。
var _parent: Node = null

## 「打出即生效」效果执行端子模块——惰性创建（DEBT-CBT-018-10 执行端）。
var _on_play_effects: RefCounted = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 玩家打出卡牌——由 CombatUI 触发（AC-001~007）。[br]
## [br][b]确定性流程[/b]（顺序不可更改，ADR-0008 §出牌结算流程）：[br]
##   1. 阶段守卫——非 PLAY 阶段 push_warning + return false[br]
##   2. 卡牌获取——_get_card_instance(card_instance_id) → null 则 return false[br]
##   3. 费用验证——CostSystem.can_afford(cost) → false 则 return false（不扣费）[br]
##   4. 目标验证——_validate_targets(card, targets) → false 则 return false（不扣费）[br]
##   5. 扣费——CostSystem.spend(cost)（直接调用——需要保证）[br]
##   6. 效果结算——_resolve_effects(card, targets) 返回结果列表[br]
##   6b. 打出即生效效果——_collect_on_play_effects()（倍率伤害并入同一批落库、
##      target=self 的治疗在伤害落库后落施法者——DEBT-CBT-018-10 执行端）[br]
##   7. 阵亡检查——_check_and_process_deaths()（击杀触发条目在此结算治疗）[br]
##   8. 自动推进判定——hand_empty && !can_afford_any → advance_phase()[br]
## [br][param card_instance_id] 卡牌实例 ID。[br]
## [br][param target_indices] 目标索引列表。[br]
## [br][param caster_id] 施法者角色 ID——倍率伤害的 ATK 取数对象与打出治疗 /
## 击杀回血的落点；缺省 -1 时两者都不结算（不猜「谁出的牌」）。[br]
## [br][b]返回[/b]: true 出牌成功，false 被拒绝。
func play_card(card_instance_id: int, target_indices: Array, caster_id: int = -1) -> bool:
	# AC-001：阶段守卫
	if _parent.get("_phase") != _parent.CombatPhase.PLAY:
		push_warning("CombatSystem: play_card() called outside PLAY phase (current=%d)" % _parent.get("_phase"))
		return false

	# 卡牌获取
	var card = _get_card_instance(card_instance_id)
	if card == null:
		push_warning("CombatSystem: play_card() card_instance_id=%d not found" % card_instance_id)
		return false

	var cost: int = int(_get_card_cost(card))

	# AC-002：费用验证——不通过不扣费不结算
	if not _can_afford(cost):
		push_warning("CombatSystem: play_card() cost=%d unaffordable" % cost)
		return false

	# AC-003：目标验证——不通过不扣费
	var targets = _resolve_targets(card, target_indices)
	if not _validate_targets(card, targets):
		push_warning("CombatSystem: play_card() target validation failed")
		return false

	# AC-004：扣费（直接调用——需要保证）
	_spend(cost)

	# AC-005：效果结算（直接调用——需要结果列表）
	var results = _resolve_effects(card, targets)

	# DEBT-CBT-018-10 执行端：打出即生效的伤害/治疗（CardEffectEngine.resolve 尚未实现，
	# 倍率伤害与 heal 此前只在评估层算出、从未落库）。伤害结果项并入同一批统一落库
	# （上下文补全由 _check_and_process_deaths 统一做）；治疗在伤害落库之后才执行，
	# 保证「先掉血、后回血」的广播顺序。
	var on_play: Dictionary = _collect_on_play_effects(card, targets, caster_id)
	results.append_array(on_play.get("damage_results", []))

	# AC-006：阵亡检查（带出牌卡与施法者上下文——击杀类条目要据此落库治疗）
	_check_and_process_deaths(results, card, caster_id)

	# 本条卡自己的回复（target="self" 的 heal 条目）——阵亡/击杀回血之后。
	_get_on_play_effects().call(&"apply_heals", on_play.get("heals", []))

	# 从手牌移除已打出的卡牌
	_remove_card_from_hand(card_instance_id)

	# AC-007：空手牌 + 无费可出 → 自动结束出牌
	var hand: Array = _parent.get("_hand")
	if hand.is_empty() and not _parent.call("_can_afford_any_card"):
		_parent.call("advance_phase")

	return true


## 获取卡牌实例——优先注入回调，回退到 CardSystem Autoload，再回退内部缓存。
func _get_card_instance(card_instance_id: int) -> Variant:
	var cb: Callable = _parent.get("get_card_instance_cb")
	if cb.is_valid():
		return cb.call(card_instance_id)
	# 回退到 CardSystem Autoload
	var cs = _parent.call("_get_card_system")
	if cs != null and cs.has_method("get_template_by_instance_id"):
		var result = cs.get_template_by_instance_id(card_instance_id)
		if result != null:
			return result
	return _parent.get("_card_instances").get(card_instance_id, null)


## 获取卡牌费用——从卡牌数据中读取 cost 字段。[br]
## [br][b]桩实现[/b]——Story 003 接线 CardSystem 后卡牌结构标准化。[br]
## [br]当前策略：读取 card["cost"] 或 card.template["cost"]，默认 0。
func _get_card_cost(card: Variant) -> int:
	if card is Dictionary:
		if card.has("cost"):
			return int(card["cost"])
		if card.has("template") and card["template"] is Dictionary and card["template"].has("cost"):
			return int(card["template"]["cost"])
	# 对象类型——尝试动态分派
	if card.has_method("get_cost"):
		return int(card.get_cost())
	push_warning("CombatSystem: _get_card_cost unrecognized card format, defaulting to 0")
	return 0


## 费用验证——通过 CostSystem Autoload 检查。[br]
## [br][b]桩实现[/b]——CostSystem 不可用时返回 true（0 费卡牌始终可出）。
func _can_afford(cost: int) -> bool:
	var cs = _parent.call("_get_cost_system")
	if cs != null and cs.has_method("can_afford"):
		return cs.can_afford(cost)
	return true  # 桩——无 CostSystem 时不限制


## 扣费——通过 CostSystem Autoload 执行。[br]
## [br][b]桩实现[/b]——CostSystem 不可用时静默跳过。
func _spend(cost: int) -> void:
	var cs = _parent.call("_get_cost_system")
	if cs != null and cs.has_method("spend"):
		cs.spend(cost)


## 目标解析——将 target_indices 转换为目标对象列表。[br]
## [br][b]桩实现[/b]——Story 003 接线后由 CardEffectEngine 验证目标合法性。[br]
## [br]当前策略：直接返回 target_indices（测试桩不解析角色/阵位）。
func _resolve_targets(card: Variant, target_indices: Array) -> Array:
	return target_indices.duplicate()


## 目标验证——通过注入回调或 CardEffectEngine 验证。[br]
## [br]优先 Callable 注入，回退到 CardEffectEngine Autoload，再回退 true。
func _validate_targets(card: Variant, targets: Array) -> bool:
	var cb: Callable = _parent.get("validate_targets_cb")
	if cb.is_valid():
		return bool(cb.call(card, targets))
	var cee = _parent.call("_get_card_effect_engine")
	if cee != null and cee.has_method("validate_targets"):
		return bool(cee.validate_targets(card, targets))
	return true


## 效果结算——通过注入回调或 CardEffectEngine 执行。[br]
## [br]优先 Callable 注入，回退到 CardEffectEngine Autoload，再回退空 Array。[br]
## [br][b]返回[/b]: 结果列表 Array[Dictionary]。
func _resolve_effects(card: Variant, targets: Array) -> Array:
	var cb: Callable = _parent.get("resolve_cb")
	if cb.is_valid():
		return cb.call(card, targets)
	var cee = _parent.call("_get_card_effect_engine")
	if cee != null and cee.has_method("resolve"):
		return cee.resolve(card, targets)
	return []


## 阵亡检查——遍历结算结果，落库 HP 并处理阵亡（Sprint 18 / DEBT-CBT-018-1）。[br]
## [br][b]此前为桩[/b]：只读结果项的 [code]is_kill[/code] 直接发信号，不改角色 HP——
## 生产路径下「打牌击杀」不会让阵位变空，END 判负不可达。[br]
## [br][b]现在[/b]：交 [code]combat_damage_settlement.gd[/code] 落库
## （[code]damage[/code] 字段为伤害，缺省读 [code]value[/code]，负值为治疗），
## HP 归零才发 [code]character_died[/code]；结果项未带可信 HP 时回退其
## [code]is_kill[/code]（信息不足原则——同 [code]combat_end_check.gd[/code]）。[br]
## [br][b]击杀触发的上下文补全[/b]（DEBT-CBT-018-10 执行端）：落库侧判断「本次是否击杀」后
## 需要拿「哪张卡 / 谁打的」才能结算 [code]trigger="kill"[/code] 条目，故此处把打出卡
## 补进结果项（[code]card_data[/code]，卡牌字典另透传 [code]card_id[/code] /
## [code]template_id[/code] / [code]caster_id[/code]）——[b]只补缺失的键[/b]，
## 已有值（CardEffectEngine 自带）优先。补不出上下文的条目按「不触发」处理，不臆造。[br]
## [br]信号后由 CombatSystem 自己的 [code]_on_character_died[/code] 调
## [code]DeploymentSystem.remove_character()[/code] 清位。
## [br][param caster_id] 施法者角色 ID（可选）——击杀触发治疗落库的对象；
## 缺省 -1 时只用结果项 / 卡牌自带的 [code]caster_id[/code]，
## 都取不到则击杀条目不结算（信息不足不臆造施法者）。
func _check_and_process_deaths(results: Array, card: Variant = null,
		caster_id: int = -1) -> void:
	_parent.call("_get_damage_settlement").settle_effect(
			_with_card_context(results, card, caster_id))


## 收集本节「打出即生效」的伤害/治疗（DEBT-CBT-018-10 执行端）。[br]
## [br][b]为什么在这里接[/b]：效果结算走 [code]CardEffectEngine.resolve[/code]，但该
## Autoload 上没有这个方法（回退返回空数组）——[code]damage_multiplier[/code] 与
## [code]heal[/code] 只在评估层算过、从未落库。本方法经 [code]combat_on_play_effects.gd[/code]
## 补齐执行端，[b]只收集不落库[/b]：伤害并入数组统一交落库链路，治疗等伤害落库后再执行。[br]
## [br][b]在扣费之后、阵亡检查之前[/b]：顺序与 ADR-0008 §出牌结算流程一致——被拒绝的
## 出牌（阶段/费用/目标校验不过）不会落任何伤害或治疗。[br]
## [br]无倍率无治疗的卡（含只给 [code]template_id[/code] 的测试桩）返回空，行为逐位不变。
func _collect_on_play_effects(card: Variant, targets: Array, caster_id: int) -> Dictionary:
	return _get_on_play_effects().call(&"collect", card, targets, caster_id)


## 惰性获取「打出即生效」执行端子模块（DEBT-CBT-018-10 执行端）。
func _get_on_play_effects() -> RefCounted:
	if _on_play_effects == null:
		_on_play_effects = preload("res://src/feature/combat/combat_on_play_effects.gd").new(_parent)
	return _on_play_effects


## 给结果项补上打出卡的上下文（原地不改入参——返回浅拷贝列表）。[br]
## [br]卡牌为 Resource（CardTemplate）时写 [code]card_data[/code]；为 Dictionary
## （测试桩 / CardEffectEngine 的宽松载荷）时按存在的键透传，由落库侧自行查模板。[br]
## [br][b]字典卡带内联效果时整份作为 card_data[/b]：出牌执行端
## （[code]combat_on_play_effects.gd[/code]）读的就是内联 [code]effects[/code]；
## 若只透传 template_id，击杀触发（[code]combat_kill_trigger.gd[/code]）会去 CardSystem
## 查一个测试桩里并不存在的模板而拿 null → [b]同一张卡，打出即生效的条目生效、
## 击杀条目静默失效[/b]。两条路径必须读同一份效果数据。
func _with_card_context(results: Array, card: Variant, caster_id: int) -> Array:
	var enriched: Array = []
	for result: Variant in results:
		if not (result is Dictionary):
			enriched.append(result)
			continue
		var item: Dictionary = (result as Dictionary).duplicate()
		if card is Object:
			_fill_missing(item, "card_data", card)
		elif card is Dictionary:
			var declared: Dictionary = card
			if declared.has("effects") or declared.has("effect_type"):
				_fill_missing(item, "card_data", declared)
			for key: String in ["card_id", "template_id", "caster_id", "attacker_id"]:
				_fill_missing(item, key, declared.get(key, null))
		if caster_id >= 0:
			_fill_missing(item, "caster_id", caster_id)
		enriched.append(item)
	return enriched


## 只在键缺失（或为 null）时写入——已有值优先，不覆盖上游给的口径。
func _fill_missing(target: Dictionary, key: String, value: Variant) -> void:
	if value == null or target.has(key):
		return
	target[key] = value


## 从手牌移除已打出的卡牌。
func _remove_card_from_hand(card_instance_id: int) -> void:
	var hand: Array = _parent.get("_hand")
	for i in range(hand.size() - 1, -1, -1):
		var card = hand[i]
		# 兼容 Dictionary 和对象类型
		var cid: Variant = null
		if card is Dictionary:
			cid = card.get("card_instance_id", card.get("instance_id", -1))
		elif card.has_method("get"):
			cid = card.get("card_instance_id", -1)
		if cid == card_instance_id:
			hand.remove_at(i)
			return
	push_warning("CombatSystem: _remove_card_from_hand card_instance_id=%d not found in hand" % card_instance_id)
