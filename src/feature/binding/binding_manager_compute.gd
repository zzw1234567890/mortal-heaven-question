## BindingManager 计算层——[b]叠加放大、加成汇总、减伤来源、预计算上下文[/b]住在这一层。
##
## [b]本层职责[/b]：所有「从绑定表算出个数」的路径——[method compute_effective_value]
## （[code]base × native × stack_multiplier^(stack_count-1)[/code]，向下取整，AC-009）、
## [method get_accumulated_bonus]（逐张累加单卡加成，AC-016）、
## [method get_damage_reduction_pcts]（只收集百分比减伤[b]来源[/b]，乘算叠加与 60% 封顶仍由
## [method CardEffectEvaluator.combine_damage_reduction] 统一负责）、
## [method get_binding_context]（预计算 multiplier 供效果引擎查询，不在引擎里重算）。[br]
## [br][b]数值口径只此一处[/b]：叠层系数取数统一走 [BindingStackFactor]，减伤来源的组装委托给
## [BindingDamageReduction]；本层不另写第二份公式。[br]
## [br][b]存根查询同住[/b]：[method _query_card_exists] / [method _query_stat_bonus] 是
## 计算与恢复两条路径共用的存根回调取值口径，与上列方法同批搬入。[br]
##
## 来源: ADR-0013 §同名叠加乘法公式 / GDD binding-system.md §3 叠加公式 §10 非数值效果叠加 /
## DEBT-CBT-018-8。
extends "res://src/feature/binding/binding_manager_registry.gd"


## 同名叠加乘法公式（AC-009）——[code]effective = base × native × stack_multiplier^(stack_count-1)[/code]，
## 结果向下取整。[br]
## [br][param base_value] 基础数值。[br]
## [br][param native_multiplier] 本命乘数（1.0 或 1.5）。[br]
## [br][param stack_multiplier] 每层叠加乘数（默认 1.5）。[br]
## [br][param stack_count] 叠加张数（≥1）。[br]
## [br][b]返回[/b]: 有效值 int（向下取整）。
func compute_effective_value(base_value: int, native_multiplier: float, stack_multiplier: float, stack_count: int) -> int:
	var mult: float = native_multiplier * pow(stack_multiplier, stack_count - 1)
	return floori(base_value * mult)


## 遍历角色所有绑定卡的数值加成累加（AC-016）——O(k)，k ≤ 6/角色。[br]
## 每张叠层实例的加成由 [member stat_bonus_cb] 提供（Story 004 接效果引擎）。[br]
## [br][param character_id] 目标角色 ID。[br]
## [br][param stat_name] 属性名（如 [code]"ATK"[/code]）。[br]
## [br][b]返回[/b]: 加成累加 float；无绑定或未注入回调返回 0.0。
func get_accumulated_bonus(character_id: int, stat_name: String) -> float:
	var total: float = 0.0
	for binding_id: int in get_binding_ids_by_character(character_id):
		if not _bindings.has(binding_id):
			continue
		var record: BindingRecord = _bindings[binding_id]
		for cid: int in record.stack_slots:
			total += _query_stat_bonus(cid, stat_name)
	return total


## 汇总角色全部生效绑定的[b]百分比减伤[/b]（DEBT-CBT-018-8 残留闭环）。[br]
## [br]来源：绑定卡中 [code]effect_type[/code] 归入减伤类的模板（含本命非线性值），
## 逐条取「受到伤害降低」的百分比，[b]并按同名叠层放大[/b]——
## [code]贡献 = pct × stack_multiplier^(stack_count-1)[/code]（GDD §10「受到伤害降低」
## 属可叠加放大类；系数取模板 [member CardTemplate.stack_multiplier]，默认 1.5）。[br]
## 基础乘算叠加与 60% 封顶仍由
## [method CardEffectEvaluator.combine_damage_reduction] 统一负责——本方法只收集来源。[br]
## [br]战斗 Attack 阶段用它写入攻击队列条目的 [code]damage_reduction_pcts[/code]。[br]
## [br][param character_id] 目标角色 ID。[br]
## [br][b]返回[/b]: [code]Array[float][/code]——各来源百分比（如 [code][10.0, 15.0][/code]）；
## 无绑定 / 无减伤卡 / 模板取不到时返回空数组（缺省即无减伤，不臆造数值）。
func get_damage_reduction_pcts(character_id: int) -> Array:
	return _get_damage_reduction().collect(character_id)


## 惰性获取百分比减伤汇总子模块（DEBT-CBT-018-8 残留闭环）。
func _get_damage_reduction() -> RefCounted:
	if _damage_reduction == null:
		_damage_reduction = load("res://src/feature/binding/binding_damage_reduction.gd").new(self)
	return _damage_reduction


## 查询单条绑定的预计算乘积上下文（AC-009）。[br]
## [code]multiplier = native_multiplier × stack_multiplier^(stack_count-1)[/code]——
## CardEffectEngine 结算时查询此值，不在引擎中重复计算。[br]
## [b]stack_multiplier 取数[/b]：真实读卡牌模板 [member CardTemplate.stack_multiplier]
## （GDD §3 可配置项），模板取不到 / 未声明 / 值 ≤ 0 时回退默认 1.5——
## 与减伤路径共用 [BindingStackFactor]，[b]只有一处取数实现[/b]（DEBT-CBT-018-8 口径收口）。[br]
## [br][param card_instance_id] 卡牌实例 ID。[br]
## [br][b]返回[/b]: [code]{native_multiplier, stack_count, multiplier}[/code]；
## 未找到返回空 Dictionary。
func get_binding_context(card_instance_id: int) -> Dictionary:
	var character_id: int = get_character_by_card(card_instance_id)
	if character_id < 0:
		return {}
	for binding_id: int in get_binding_ids_by_character(character_id):
		if not _bindings.has(binding_id):
			continue
		var record: BindingRecord = _bindings[binding_id]
		if record.stack_slots.has(card_instance_id) or record.card_instance_id == card_instance_id:
			var template: Variant = StackFactor.read_template(record.card_template_id)
			var stack_factor: float = StackFactor.stack_factor(record.stack_count, template)
			var mult: float = record.native_multiplier * stack_factor
			return {"native_multiplier": record.native_multiplier, "stack_count": record.stack_count, "multiplier": mult}
	return {}


## 查询卡牌实例是否存在（存根默认 true）。[br]
## [br][b]返回[/b]: true 表示仍存在。
func _query_card_exists(card_instance_id: int) -> bool:
	if card_exists_cb.is_valid():
		return bool(card_exists_cb.call(card_instance_id))
	return true


## 查询单卡数值加成（存根默认 0.0）。[br]
## [br][b]返回[/b]: 单卡加成 float。
func _query_stat_bonus(card_instance_id: int, stat_name: String) -> float:
	if stat_bonus_cb.is_valid():
		return float(stat_bonus_cb.call(card_instance_id, stat_name))
	return 0.0
