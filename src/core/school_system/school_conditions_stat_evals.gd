## SchoolConditions 数值类条件评估器（继承链第三段）。
##
## [b]本层职责[/b]：六条与「境界 / 炼丹 / 角色 / 费用 / 稀有度」相关的检测条件。[br]
##   · 加权——[method _eval_min_realm]（10）、[method _eval_min_alchemy_count]（10）、
##     [method _eval_required_characters]（30）、[method _eval_avg_card_cost]（20）；[br]
##   · 硬性——[method _eval_min_rarity]（场上不得低于指定稀有度）、
##     [method _eval_max_dark_gold_count]（暗金卡张数上限），两者
##     [code]weight = 0[/code] + [code]skipped = true[/code]。
##
## [method _eval_required_characters] 的「在场或已收藏」双查与
## [method _eval_min_rarity] 的稀有度序表（white→dark_gold）都[b]逐字保留[/b]——
## 它们是 AC 断言的直接对象，搬家不改语义。
##
## 依赖方向：只向下调链首段的 [method _get_tag_display_name]。
extends "res://src/core/school_system/school_conditions_faction_evals.gd"


## 境界条件——{type: "min_realm", value: int}。
func _eval_min_realm(cond: Dictionary, state: Dictionary) -> Dictionary:
	var min_realm: int = int(cond.get("value", 0))
	var player_realm: int = int(state.get("player_realm", 0))
	var satisfied: bool = player_realm >= min_realm
	var ratio: float = 1.0 if satisfied else 0.0
	return {
		satisfied = satisfied,
		weight = 10.0,
		score = 10.0 * ratio,
		missing_text = "境界不足（需 ≥L%d 级，当前 L%d）" % [min_realm, player_realm] if not satisfied else "",
		skipped = false,
	}


## 炼丹次数条件——{type: "min_alchemy_count", value: int}。
func _eval_min_alchemy_count(cond: Dictionary, state: Dictionary) -> Dictionary:
	var min_count: int = int(cond.get("value", 0))
	var alchemy_count: int = int(state.get("alchemy_count", 0))
	var satisfied: bool = alchemy_count >= min_count
	var ratio: float = minf(float(alchemy_count) / float(max(min_count, 1)), 1.0)
	return {
		satisfied = satisfied,
		weight = 10.0,
		score = 10.0 * ratio,
		missing_text = "需进行 ≥%d 次炼丹/炼器（当前 %d/%d）" % [min_count, alchemy_count, min_count] if not satisfied else "",
		skipped = false,
	}


## 必备角色条件——{type: "required_characters", ids: Array[StringName]}。[br]
## 角色需在场（field_characters）或已收藏（collected_characters）。
func _eval_required_characters(cond: Dictionary, state: Dictionary) -> Dictionary:
	var ids: Array = cond.get("ids", [])
	var field_chars: Array = state.get("field_characters", [])
	var collected: Array = state.get("collected_characters", [])
	var total_required: int = ids.size()
	var found: int = 0
	var missing_names: Array[String] = []

	for required_id in ids:
		var found_this: bool = false
		# 检查场上角色
		for char in field_chars:
			var char_id: StringName = char.get("character_id", &"") as StringName
			if char_id == required_id:
				found_this = true
				break
		# 检查已收藏
		if not found_this:
			for collected_id in collected:
				if collected_id == required_id:
					found_this = true
					break
		if found_this:
			found += 1
		else:
			missing_names.append(str(required_id))

	var satisfied: bool = found >= total_required
	var ratio: float = float(found) / float(max(total_required, 1))
	return {
		satisfied = satisfied,
		weight = 30.0,
		score = 30.0 * ratio,
		missing_text = "缺少核心角色: %s" % ", ".join(missing_names) if not satisfied else "",
		skipped = false,
	}


## 平均费用条件——{type: "avg_card_cost", min: float}。[br]
## 计算卡组中所有卡牌费用的平均值。
func _eval_avg_card_cost(cond: Dictionary, state: Dictionary) -> Dictionary:
	var min_avg: float = float(cond.get("min", 0.0))
	var deck_cards: Array = state.get("deck_cards", [])
	var total: int = deck_cards.size()

	if total == 0:
		return {
			satisfied = false,
			weight = 20.0,
			score = 0.0,
			missing_text = "卡组为空，无法计算平均费用",
			skipped = false,
		}

	var total_cost: int = 0
	for card in deck_cards:
		total_cost += int(card.get("cost", 0))

	var avg: float = float(total_cost) / float(total)
	var satisfied: bool = avg >= min_avg
	var ratio: float = minf(avg / maxf(min_avg, 0.01), 1.0)
	return {
		satisfied = satisfied,
		weight = 20.0,
		score = 20.0 * ratio,
		missing_text = "卡组平均费用需 ≥%.1f（当前 %.1f）" % [min_avg, avg] if not satisfied else "",
		skipped = false,
	}


## 最低稀有度条件——{type: "min_rarity", value: String}。[br]
## 硬性条件：场上不能有低于指定稀有度的角色。
func _eval_min_rarity(cond: Dictionary, state: Dictionary) -> Dictionary:
	var min_rarity: String = cond.get("value", "")
	var field_chars: Array = state.get("field_characters", [])
	var rarity_order: Dictionary = {
		"white": 0, "green": 1, "blue": 2, "purple": 3, "gold": 4, "dark_gold": 5,
	}
	var min_level: int = rarity_order.get(min_rarity, 0)
	var has_low_rarity: bool = false

	for char in field_chars:
		var char_rarity: String = char.get("rarity", "white")
		var level: int = rarity_order.get(char_rarity, 0)
		if level < min_level:
			has_low_rarity = true
			break

	return {
		satisfied = not has_low_rarity,
		weight = 0.0,  # 硬性条件——不参与加权
		score = 0.0,
		missing_text = "场上不能有低于%s稀有度的角色" % min_rarity if has_low_rarity else "",
		skipped = true,  # 跳过加权计算
	}


## 暗金卡上限条件——{type: "max_dark_gold_count", value: int}。[br]
## 硬性条件：卡组中暗金卡不超过指定数量。
func _eval_max_dark_gold_count(cond: Dictionary, state: Dictionary) -> Dictionary:
	var max_count: int = int(cond.get("value", 1))
	var deck_cards: Array = state.get("deck_cards", [])
	var dark_gold_count: int = 0

	for card in deck_cards:
		if card.get("rarity", "") == "dark_gold":
			dark_gold_count += 1

	var satisfied: bool = dark_gold_count <= max_count
	return {
		satisfied = satisfied,
		weight = 0.0,  # 硬性条件——不参与加权
		score = 0.0,
		missing_text = "暗金卡不能超过 %d 张（当前 %d 张）" % [max_count, dark_gold_count] if not satisfied else "",
		skipped = true,  # 跳过加权计算
	}
