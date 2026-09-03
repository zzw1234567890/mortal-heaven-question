## CombatCardResolver —— 出牌结算子模块（RefCounted）。
##
## 从 combat_system.gd 提取的出牌结算逻辑。[br]
## 持有父节点 CombatSystem 引用，通过它访问牌库/手牌/回调/Autoload。[br]
## [br]来源: ADR-0008 §出牌结算流程 / GDD combat-system.md §2。[br]
## [br]Sprint 8 Story 8-10：从 combat_system.gd 拆分。
extends RefCounted


## 父节点引用——CombatSystem Autoload 实例。
var _parent: Node = null


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
##   7. 阵亡检查——_check_and_process_deaths()[br]
##   8. 自动推进判定——hand_empty && !can_afford_any → advance_phase()[br]
## [br][param card_instance_id] 卡牌实例 ID。[br]
## [br][param target_indices] 目标索引列表。[br]
## [br][b]返回[/b]: true 出牌成功，false 被拒绝。
func play_card(card_instance_id: int, target_indices: Array) -> bool:
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

	# AC-006：阵亡检查
	_check_and_process_deaths(results)

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


## 阵亡检查——遍历结算结果，处理 HP ≤ 0 的角色。[br]
## [br][b]桩实现[/b]——Story 004 接线 character_died 信号发射。[br]
## [br]当前策略：遍历 results 检查 is_kill 字段，发射 character_died 信号。
func _check_and_process_deaths(results: Array) -> void:
	for result in results:
		if result is Dictionary and result.get("is_kill", false):
			var char_id: int = int(result.get("target_id", -1))
			if char_id < 0:
				push_warning("CombatSystem: _check_and_process_deaths skipping result with invalid target_id")
				continue
			var side: int = int(result.get("side", 0))
			var binding_ids: Array = result.get("binding_card_ids", [])
			_parent.call("_emit_safe", &"character_died", [char_id, side, binding_ids])


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
