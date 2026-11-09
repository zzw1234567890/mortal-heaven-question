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
## [b]效果词表[/b]（DEBT-CBT-018-8 补齐）：[code]effect_type[/code] 按字符串前缀归类，
## 见 [method _category_for]——[b]具体前缀必须先于泛前缀判定[/b]（[code]damage_reduce[/code]
## 不能被 [code]damage[/code] 吞掉）。三个易混类别严格区分：[br]
##   · [constant EffectCategory.BUFF] —— 面板 ATK [b]增量[/b]，写 [code]stat_changes[/code]；[br]
##   · [constant EffectCategory.DAMAGE_REDUCE] —— [b]受到[/b]伤害按比例降低，只写减伤字段，[b]绝不写 ATK[/b]；[br]
##   · [constant EffectCategory.DAMAGE_MULTIPLIER] —— 打出卡的[b]伤害倍率[/b]（×攻击力系数）。
##
## 未知/留空的 [code]effect_type[/code] 一律落 [constant EffectCategory.UNEVALUABLE]，
## 返回空评估——[b]不静默降级成 buff[/b]，让调用方看见「尚未建模」而不是拿着错数值继续算。
##
## [b]本命覆盖[/b]：卡牌数据带 [code]is_native=true[/code]（由 BindingManager 判定后传入）且
## 声明了 [code]native_effect_value > 0[/code] 时，按本命数值原值采用并[b]跳过绑定倍率[/b]——
## GDD 的「10%→15%」「30%→50%」不是线性倍率，统一 ×1.5 会算错。
##
## 来源: ADR-0009 §AI 评估接口 / GDD §10 / GDD combat-system.md §百分比减伤。
class_name CardEffectEvaluator
extends RefCounted


# === 枚举 =========================================================================

## 效果类型标签（GDD §10 get_effect_categories）。[br]
## [b]前 9 个值的编号固定[/b]（已有调用点与断言依赖）；新增类别一律追加在末尾。
enum EffectCategory {
	DAMAGE, HEAL, BUFF, DEBUFF, CONTROL, DRAW, BIND, FORMATION, UNEVALUABLE,
	DAMAGE_REDUCE, DAMAGE_MULTIPLIER, DAMAGE_BONUS, HEAL_BONUS, FORMATION_ATTUNE,
}

## 百分比减伤上限——GDD combat-system.md §公式「伤害减免叠加采用乘算，上限60%」。
const DAMAGE_REDUCTION_CAP_PCT: float = 60.0


# === 核心评估 =====================================================================

## 评估一张卡牌对目标的确定性效果。[br]
## [br][b]各分支的数值口径[/b]：[br]
##   · DAMAGE / HEAL / BUFF / DEBUFF —— [code]effect_value[/code] 为绝对点数，乘绑定倍率；[br]
##   · DAMAGE_REDUCE —— [code]effect_value[/code] 为[b]百分比整数[/b]（10 = -10%），钳制到 [0, 60]；[br]
##   · DAMAGE_MULTIPLIER —— [code]effect_value[/code] 为[b]百分比整数[/b]（150 = ×1.5），
##     伤害 = [code]floori(攻击力 × 倍率)[/code]；攻击力优先读 [code]attacker_atk[/code]，缺省回退目标快照；[br]
##   · DAMAGE_BONUS / HEAL_BONUS / FORMATION_ATTUNE —— [code]effect_value[/code] 为绝对点数。[br]
## [br][b]纯计算[/b]——不修改 [param snapshot] 与 [param card_data]。[br]
## [br][param card_data] 卡牌效果数据——[code]{effect_type, effect_value, ...}[/code]
## 或 CardTemplate（含同名字段）。[br]
## [br][param target_id] 目标角色 ID。[br]
## [br][param snapshot] 不可变快照。[br]
## [br][b]返回[/b]: [EffectEvaluation]（未知类型返回空评估）。
func evaluate_effect(card_data: Variant, target_id: int, snapshot: GameStateSnapshot) -> EffectEvaluation:
	var raw_value: int = _resolved_value(card_data)
	var effective: int = raw_value if _has_native_override(card_data) \
		else floori(raw_value * snapshot.get_binding_multiplier(target_id))
	var category: EffectCategory = _category_for(card_data)
	var target_hp: int = snapshot.get_hp(target_id)

	var eval := EffectEvaluation.new()
	match category:
		EffectCategory.DAMAGE:
			eval.damage = effective
			eval.is_overkill = effective > target_hp
		EffectCategory.DAMAGE_MULTIPLIER:
			var multiplier: float = clampf(float(raw_value) / 100.0, 0.0, 99.0)
			eval.damage_multiplier = multiplier
			eval.damage = floori(float(_attacker_atk(card_data, target_id, snapshot)) * multiplier)
			eval.is_overkill = eval.damage > target_hp
		EffectCategory.DAMAGE_REDUCE:
			# 受到伤害按比例降低——只写减伤字段，绝不写 stat_changes（与 BUFF 的 ATK 增量严格区分）。
			var pct: float = clampf(float(raw_value), 0.0, DAMAGE_REDUCTION_CAP_PCT)
			eval.damage_reduction_pct = pct
			eval.damage_reduction_multiplier = 1.0 - pct / 100.0
		EffectCategory.DAMAGE_BONUS:
			eval.damage_bonus = raw_value
		EffectCategory.HEAL_BONUS:
			eval.healing_bonus = raw_value
		EffectCategory.FORMATION_ATTUNE:
			eval.formation_attunement = raw_value
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


## 评估含触发概率的完整概率分布。[br]
## [br]读 [code]trigger_chance[/code]（0..1，[b]0 = 未声明概率 → 必定触发[/b]；本命匹配时读
## [code]native_trigger_chance[/code]）：[br]
##   · 0 或 ≥1 → 单一确定性结果（probability = 1.0）；[br]
##   · 0 < chance < 1 → 两个分支：命中（完整效果，概率 chance）+ 落空（空效果，概率 1-chance）。[br]
## [br][b]确定性[/b]：本方法不掷骰，只展开分布——掷骰由调用方用 PRD 引擎按分布抽样。[br]
## [br][b]返回[/b]: [code]Array[Dictionary][/code]——每项 [code]{outcome: EffectEvaluation, probability: float}[/code]。
func evaluate_effect_probabilistic(card_data: Variant, target_id: int, snapshot: GameStateSnapshot) -> Array:
	var outcome: EffectEvaluation = evaluate_effect(card_data, target_id, snapshot)
	var chance: float = _resolved_trigger_chance(card_data)
	if chance <= 0.0 or chance >= 1.0:
		return [{"outcome": outcome, "probability": 1.0}]
	return [
		{"outcome": outcome, "probability": chance},
		{"outcome": EffectEvaluation.new(), "probability": 1.0 - chance},
	]


## 合成多条百分比减伤——GDD combat-system.md §公式：乘算叠加（0.9 × 0.85 …），上限 60%。[br]
## [br][param pcts] 各来源的减伤百分比（如 [code][10, 15][/code]）；单条超出 [0,100] 的部分先钳制。[br]
## [br][b]返回[/b]: [code]{multiplier: float, reduction_pct: float}[/code]——受击伤害应乘的系数与等效减伤百分比。
static func combine_damage_reduction(pcts: Array) -> Dictionary:
	var multiplier: float = 1.0
	for p in pcts:
		multiplier *= 1.0 - clampf(float(p), 0.0, 100.0) / 100.0
	# 上限 60% → 系数下限 0.4
	multiplier = maxf(multiplier, 1.0 - DAMAGE_REDUCTION_CAP_PCT / 100.0)
	return {"multiplier": multiplier, "reduction_pct": (1.0 - multiplier) * 100.0}


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

## 从卡牌数据推导效果类型标签。[br]
## [br][b]顺序即语义[/b]：具体前缀（[code]damage_reduce[/code]/[code]damage_multiplier[/code]/
## [code]damage_bonus[/code]/[code]heal_bonus[/code]/[code]formation_attune[/code]）必须先于
## 泛前缀（[code]damage[/code]/[code]heal[/code]/[code]formation[/code]）判定，否则会被吞掉。[br]
## 中文别名同理——「受到伤害降低」含「伤害」二字，必须先判减伤再判伤害。[br]
## 全部不匹配 → [constant EffectCategory.UNEVALUABLE]（绝不猜成 buff）。
func _category_for(card_data: Variant) -> EffectCategory:
	var effect_type: String = str(_stringname_field(card_data, "effect_type")).to_lower()
	if effect_type.begins_with("damage_reduce") or effect_type.contains("受到伤害降低") \
			or effect_type.contains("减伤"):
		return EffectCategory.DAMAGE_REDUCE
	if effect_type.begins_with("damage_multiplier") or effect_type.contains("伤害倍率"):
		return EffectCategory.DAMAGE_MULTIPLIER
	if effect_type.begins_with("damage_bonus") or effect_type.contains("伤害加成"):
		return EffectCategory.DAMAGE_BONUS
	if effect_type.begins_with("damage") or effect_type.contains("伤害"):
		return EffectCategory.DAMAGE
	if effect_type.begins_with("heal_bonus") or effect_type.contains("额外回复"):
		return EffectCategory.HEAL_BONUS
	if effect_type.begins_with("heal") or effect_type.contains("治疗"):
		return EffectCategory.HEAL
	if effect_type.begins_with("formation_attune") or effect_type.contains("视为满足"):
		return EffectCategory.FORMATION_ATTUNE
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


## 本命数值覆盖是否生效——[code]is_native[/code] 为真且声明了正的 [code]native_effect_value[/code]。
func _has_native_override(card_data: Variant) -> bool:
	return _bool_field(card_data, "is_native") and _int_field(card_data, "native_effect_value") > 0


## 解析效果数值——本命覆盖优先，否则读 [code]effect_value[/code]（均为原始值，未乘绑定倍率）。
func _resolved_value(card_data: Variant) -> int:
	if _has_native_override(card_data):
		return _int_field(card_data, "native_effect_value")
	return _int_field(card_data, "effect_value")


## 解析触发概率——本命匹配时优先 [code]native_trigger_chance[/code]，否则 [code]trigger_chance[/code]。
## [br]返回值已钳制到 [0, 1]；0 = 未声明（调用方视为必定触发）。
func _resolved_trigger_chance(card_data: Variant) -> float:
	var chance: float = _float_field(card_data, "trigger_chance")
	if _bool_field(card_data, "is_native"):
		var native_chance: float = _float_field(card_data, "native_trigger_chance")
		if native_chance > 0.0:
			chance = native_chance
	return clampf(chance, 0.0, 1.0)


## 攻击力读取——优先 [code]attacker_atk[/code]（打出者，AI 干跑可显式传入），
## 缺省回退目标快照的 ATK（GDD 约定 ATK ≥ 1，故 0 视为未提供）。
func _attacker_atk(card_data: Variant, target_id: int, snapshot: GameStateSnapshot) -> int:
	var atk: int = _int_field(card_data, "attacker_atk")
	return atk if atk > 0 else snapshot.get_atk(target_id)


## 读取布尔字段——兼容 CardTemplate（Resource 属性访问）与 Dictionary（键访问）。
func _bool_field(card_data: Variant, key: String) -> bool:
	if card_data is Dictionary:
		return bool(card_data.get(key, false))
	if card_data != null:
		return bool(card_data.get(key))
	return false


## 读取浮点字段——兼容 CardTemplate（Resource 属性访问）与 Dictionary（键访问）。
## [br]Object 分支用 [code]get(key)[/code]（[code]in[/code] 运算符不适用于 Object 属性成员测试）；
## 属性缺失时 [code]get[/code] 返回 null，[code]float(null)=0.0[/code]。
func _float_field(card_data: Variant, key: String) -> float:
	if card_data is Dictionary:
		return float(card_data.get(key, 0.0))
	if card_data != null:
		return float(card_data.get(key))
	return 0.0


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
