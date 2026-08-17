## CardEffectEvaluator —— AI 干跑评估（纯计算，不修改任何状态）。
##
## 在不可变 [GameStateSnapshot] 上执行评估。本 Story 的评估逻辑是
## [b]简化确定性模型[/b]——伤害/治疗由卡牌 [code]effect_value[/code] 与
## 目标快照数据推导（含 binding_multiplier floor 取整），完整的效果结算
## （状态施加/阵法/触发链）在 CardEffectEngine Autoload 层接线后由 Story 后续展开。
##
## [b]确定性契约[/b]（ADR-0009 §验证标准）：同一输入 → 同一输出，与运行时结算一致。
##
## [b]无 GSM 依赖[/b]：本类只读快照，不接触任何 Autoload。
##
## 来源: ADR-0009 §AI 评估接口 / GDD §10。
class_name CardEffectEvaluator
extends RefCounted


# === 枚举 =========================================================================

## 效果类型标签（GDD §10 get_effect_categories）。
enum EffectCategory {
	DAMAGE, HEAL, BUFF, DEBUFF, CONTROL, DRAW, BIND, FORMATION, UNEVALUABLE,
}


# === 核心评估 =====================================================================

## 评估一张卡牌对目标的确定性效果。[br]
## [br][b]伤害/治疗推导[/b]：[code]effective = floori(effect_value × binding_multiplier)[/code]。
## 效果类型由 [method _category_for] 按 [code]effect_type[/code] 字符串推导
## （简化模型——未读 CardTemplate.CardType，接线后 Story 修正）。[br]
## [br][b]纯计算[/b]——不修改 [param snapshot] 与 [param card_data]。传入的 [param card_data] 是
## 卡牌效果字段的只读数据源（可传 CardTemplate 或其简化 Dictionary）。[br]
## [br][param card_data] 卡牌效果数据——[code]{effect_type, effect_value}[/code]
## 或 CardTemplate（含同名字段）。[br]
## [br][param target_id] 目标角色 ID。[br]
## [br][param snapshot] 不可变快照。[br]
## [br][b]返回[/b]: [EffectEvaluation]。
func evaluate_effect(card_data: Variant, target_id: int, snapshot: GameStateSnapshot) -> EffectEvaluation:
	var effect_value: int = _int_field(card_data, "effect_value")
	var binding_multiplier: float = snapshot.get_binding_multiplier(target_id)
	var effective: int = floori(effect_value * binding_multiplier)
	var category: EffectCategory = _category_for(card_data)
	var target_hp: int = snapshot.get_hp(target_id)

	var eval := EffectEvaluation.new()
	match category:
		EffectCategory.DAMAGE:
			eval.damage = effective
			eval.is_overkill = effective > target_hp
		EffectCategory.HEAL:
			eval.healing = effective
			eval.is_overheal = target_hp + effective > snapshot.get_max_hp(target_id)
		EffectCategory.BUFF, EffectCategory.DEBUFF:
			# 属性变更类效果——stat_changes 由 effect_type 决定方向/属性（简化：单属性 ATK）。
			var delta: int = effective if category == EffectCategory.BUFF else -effective
			eval.stat_changes = {"ATK": delta}
		EffectCategory.CONTROL:
			# 控制类效果——施加状态（effect_type 为状态模板 ID）。
			var status_id: StringName = _stringname_field(card_data, "effect_type")
			if status_id != &"":
				eval.statuses_applied.append(status_id)
		_:
			pass  # DRAW/BIND/FORMATION/UNEVALUABLE——本 Story 简化评估为空
	return eval


## 评估含 RNG 效果的完整概率分布。[br]
## [br]本 Story 简化：非 RNG 效果返回单一确定性结果（probability=1.0）。
## RNG 概率分布的完整展开（复用 PRD 分布，Story 004）在 CardEffectEngine 接线后由后续 story 补充。[br]
## [br][b]返回[/b]: [code]Array[Dictionary][/code]——每项 [code]{outcome: EffectEvaluation, probability: float}[/code]。
func evaluate_effect_probabilistic(card_data: Variant, target_id: int, snapshot: GameStateSnapshot) -> Array:
	var outcome: EffectEvaluation = evaluate_effect(card_data, target_id, snapshot)
	return [{"outcome": outcome, "probability": 1.0}]


## 模拟打出此卡后的完整触发链。[br]
## [br]本 Story 简化：无触发链（[code]chain[/code] 仅含根效果，[code]would_overflow=false[/code]）。
## 触发链模拟（复用 Story 003 深度 10 语义）在 CardEffectEngine 接线后由后续 story 补充。[br]
## [br][b]返回[/b]: [code]Dictionary[/code]——[code]{chain: [{step, source, effect, probability}], would_overflow: bool}[/code]。
func simulate_chain(card_data: Variant, target_id: int, snapshot: GameStateSnapshot, max_depth: int = 10) -> Dictionary:
	var outcome: EffectEvaluation = evaluate_effect(card_data, target_id, snapshot)
	var source: StringName = _stringname_field(card_data, "card_id")
	var chain: Array = [{
		"step": 1,
		"source": source,
		"effect": outcome,
		"probability": 1.0,
	}]
	return {"chain": chain, "would_overflow": false}


## 获取效果类型标签。[br]
## [br][param card_data] 卡牌效果数据。[br]
## [br][b]返回[/b]: [code]Array[EffectCategory][/code]。
func get_effect_categories(card_data: Variant) -> Array:
	return [_category_for(card_data)]


# === 内部 =========================================================================

## 从卡牌数据推导效果类型标签（简化：按 effect_type 字符串前缀或 card_type）。
func _category_for(card_data: Variant) -> EffectCategory:
	var effect_type: String = str(_stringname_field(card_data, "effect_type")).to_lower()
	if effect_type.begins_with("damage") or effect_type.contains("伤害"):
		return EffectCategory.DAMAGE
	if effect_type.begins_with("heal") or effect_type.contains("治疗"):
		return EffectCategory.HEAL
	if effect_type.begins_with("buff") or effect_type.contains("增益"):
		return EffectCategory.BUFF
	if effect_type.begins_with("debuff") or effect_type.contains("减益"):
		return EffectCategory.DEBUFF
	if effect_type.begins_with("control") or effect_type.contains("控制"):
		return EffectCategory.CONTROL
	if effect_type.begins_with("draw") or effect_type.contains("抽牌"):
		return EffectCategory.DRAW
	if effect_type.begins_with("bind") or effect_type.contains("绑定"):
		return EffectCategory.BIND
	if effect_type.begins_with("formation") or effect_type.contains("阵法"):
		return EffectCategory.FORMATION
	return EffectCategory.UNEVALUABLE


## 读取整数字段——兼容 CardTemplate（Resource 属性访问）与 Dictionary（键访问）。
## [br]Object 分支用 [code]get(key)[/code]（[code]in[/code] 运算符不适用于 Object 属性成员测试）；
## 属性缺失时 [code]get[/code] 返回 null，[code]int(null)=0[/code]。
func _int_field(card_data: Variant, key: String) -> int:
	if card_data is Dictionary:
		return int(card_data.get(key, 0))
	if card_data != null:
		return int(card_data.get(key))
	return 0


## 读取 StringName 字段——兼容 CardTemplate 与 Dictionary。
## [br]Object 分支用 [code]get(key)[/code]；[code]str(null)[/code] 会得到字符串 [code]"null"[/code]，
## 但 CardTemplate 恒定声明本方法读取的字段（effect_type/effect_value/card_id），故该路径安全。
func _stringname_field(card_data: Variant, key: String) -> StringName:
	if card_data is Dictionary:
		return StringName(str(card_data.get(key, "")))
	if card_data != null:
		return StringName(str(card_data.get(key)))
	return &""
