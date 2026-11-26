## SchoolConditions 阵营与类型条件评估器（继承链第二段）。
##
## [b]本层职责[/b]：四条与「阵营 / 卡牌类型」相关的检测条件。[br]
##   · [method _eval_faction_count]（权重 40）——场上命中标签的角色数；[br]
##   · [method _eval_faction_ratio]（权重 40）——该阵营占比落在 [code]min~max[/code] 区间；[br]
##   · [method _eval_excluded_faction]（[b]硬性[/b]）——卡组不得含阵营限定卡；[br]
##   · [method _eval_card_type_ratio]（权重 20）——指定类型卡占比，含 [code]low_cost[/code]
##     与 [code]pill[/code] 两条特判。
##
## 统一返回结构 [code]{satisfied, weight, score, missing_text, skipped}[/code]；硬性条件
## 以 [code]weight = 0[/code] + [code]skipped = true[/code] 表达「不参与加权」，
## 由 [code]school_system.gd:calculate_match[/code] 跳过（GDD §公式#1 的权重分配）。
##
## 依赖方向：只向下调链首段的 [method _char_matches_tags] / [method _tags_display] /
## [method _get_tag_display_name]。
extends "res://src/core/school_system/school_conditions_tag_rules.gd"


# --- 条件评估器 -------------------------------------------------------------------

## 阵营人数条件——{type: "faction_count", tags: Array[StringName], min: int}。[br]
## 场上角色任一 faction_tag 匹配 tags 中任一项即计入一次。
func _eval_faction_count(cond: Dictionary, state: Dictionary) -> Dictionary:
	var tags: Array = cond.get("tags", [])
	var min_count: int = int(cond.get("min", 0))
	var field_chars: Array = state.get("field_characters", [])
	var count: int = 0

	for char in field_chars:
		if _char_matches_tags(char, tags):
			count += 1

	var satisfied: bool = count >= min_count
	var ratio: float = minf(float(count) / float(max(min_count, 1)), 1.0)
	var tag_names: String = _tags_display(tags)
	return {
		satisfied = satisfied,
		weight = 40.0,
		score = 40.0 * ratio,
		missing_text = "需 %d 个%s角色（当前 %d/%d）" % [min_count, tag_names, count, min_count],
		skipped = false,
	}


## 阵营占比条件——{type: "faction_ratio", tag: StringName, min: float, max?: float}。[br]
## 计算场上角色的阵营占比（含该阵营或其门派标签的角色数 / 总角色数）。
func _eval_faction_ratio(cond: Dictionary, state: Dictionary) -> Dictionary:
	var tag: StringName = cond.get("tag", &"") as StringName
	var min_pct: float = float(cond.get("min", 0.0))
	var max_pct: float = float(cond.get("max", 1.0))
	var field_chars: Array = state.get("field_characters", [])
	var total: int = field_chars.size()

	if total == 0:
		return {
			satisfied = false,
			weight = 40.0,
			score = 0.0,
			missing_text = "场上无角色，无法计算%s占比" % tag,
			skipped = false,
		}

	var count: int = 0
	for char in field_chars:
		if _char_matches_tags(char, [tag]):
			count += 1

	var actual_pct: float = float(count) / float(total)
	var satisfied: bool = actual_pct >= min_pct and actual_pct <= max_pct
	var ratio: float = 0.0
	if satisfied:
		ratio = 1.0
	elif actual_pct > 0:
		ratio = minf(actual_pct / min_pct, 1.0) if actual_pct < min_pct else 1.0

	var tag_name: String = _get_tag_display_name(tag)
	return {
		satisfied = satisfied,
		weight = 40.0,
		score = 40.0 * ratio,
		missing_text = "%s占比需在 %.0f%%~%.0f%%（当前 %.0f%%）" % [tag_name, min_pct * 100, max_pct * 100, actual_pct * 100],
		skipped = false,
	}


## 排除阵营条件——{type: "excluded_faction", tag: StringName}。[br]
## 硬性条件：卡组中不能有该阵营的阵营限定卡。
func _eval_excluded_faction(cond: Dictionary, state: Dictionary) -> Dictionary:
	var tag: StringName = cond.get("tag", &"") as StringName
	var deck_cards: Array = state.get("deck_cards", [])
	var has_excluded: bool = false

	for card in deck_cards:
		var is_exclusive: bool = bool(card.get("is_modao_exclusive", false))
		if is_exclusive and tag == &"modao":
			has_excluded = true
			break

	var tag_name: String = _get_tag_display_name(tag)
	return {
		satisfied = not has_excluded,
		weight = 0.0,  # 硬性条件——不参与加权
		score = 0.0,
		missing_text = "卡组中不能有%s阵营限定卡" % tag_name if has_excluded else "",
		skipped = true,  # 跳过加权计算
	}


## 卡牌类型占比条件——{type: "card_type_ratio", card_type: String, min_pct: float}。[br]
## 计算卡组中指定类型卡牌的占比。
func _eval_card_type_ratio(cond: Dictionary, state: Dictionary) -> Dictionary:
	var card_type: String = cond.get("card_type", "")
	var min_pct: float = float(cond.get("min_pct", 0.0))
	var deck_cards: Array = state.get("deck_cards", [])
	var total: int = deck_cards.size()

	if total == 0:
		return {
			satisfied = false,
			weight = 20.0,
			score = 0.0,
			missing_text = "卡组为空，无法计算%s卡占比" % card_type,
			skipped = false,
		}

	var count: int = 0
	for card in deck_cards:
		if card_type == "low_cost":
			# 费用 ≤2 的低费卡
			if int(card.get("cost", 999)) <= 2:
				count += 1
		elif card_type == "pill":
			# 丹药卡
			var ct: String = card.get("card_type", "")
			if ct == "pill" or ct == "丹药":
				count += 1
		elif card.get("card_type", "") == card_type:
			count += 1

	var actual_pct: float = float(count) / float(total)
	var satisfied: bool = actual_pct >= min_pct
	var ratio: float = minf(actual_pct / maxf(min_pct, 0.01), 1.0)
	var type_display: String = "低费(≤2费)" if card_type == "low_cost" else card_type

	return {
		satisfied = satisfied,
		weight = 20.0,
		score = 20.0 * ratio,
		missing_text = "%s卡占比需 ≥%.0f%%（当前 %.0f%%）" % [type_display, min_pct * 100, actual_pct * 100],
		skipped = false,
	}
