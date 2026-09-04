extends RefCounted
## SchoolConditions —— 流派检测条件评估引擎（从 school_system.gd 拆分）。
##
## 纯函数类——_check_all_conditions + _evaluate_condition 分派器 + 10 个 _eval_* 评估器 + 辅助方法。[br]
## 所有评估器接收 (cond, state) 返回统一结构 {satisfied, weight, score, missing_text, skipped}。[br]
## [br]来源: ADR-0025 §关键接口 + GDD school-system.md §公式#1。[br]
## [br]Sprint 9 Story 2：从 school_system.gd 拆分。

## 检查流派的全部条件是否满足。[br]
## [br][b]返回[/b]: 全部条件满足则 true。
func check_all_conditions(school: Dictionary, state: Dictionary) -> bool:
	var conditions: Array = school.detection.get("conditions", [])
	if conditions.is_empty():
		return false
	for cond in conditions:
		var result: Dictionary = evaluate_condition(cond, state, school.id)
		if not result.get("satisfied", false):
			return false
	return true


## 评估单个检测条件——返回 {satisfied, weight, score, missing_text, skipped}。[br]
## [br]条件类型映射：[br]
##   - [code]faction_count[/code] → 阵营人数条件（权重 40）[br]
##   - [code]faction_ratio[/code] → 阵营占比条件（权重 40）[br]
##   - [code]excluded_faction[/code] → 排除阵营条件（硬性，不参与加权）[br]
##   - [code]card_type_ratio[/code] → 卡牌类型占比（权重 20）[br]
##   - [code]min_realm[/code] → 境界条件（权重 10）[br]
##   - [code]min_alchemy_count[/code] → 炼丹次数（权重 10）[br]
##   - [code]required_characters[/code] → 必备角色（权重 30）[br]
##   - [code]avg_card_cost[/code] → 平均费用（权重 20）[br]
##   - [code]min_rarity[/code] → 最低稀有度（硬性，不参与加权）[br]
##   - [code]max_dark_gold_count[/code] → 暗金卡上限（硬性，不参与加权）[br]
## [br][b]来源[/b]: ADR-0025 §关键接口 + GDD §公式#1（权重分配）。
func evaluate_condition(cond: Dictionary, state: Dictionary, _school_id: StringName) -> Dictionary:
	var cond_type: String = cond.get("type", "")

	match cond_type:
		"faction_count":
			return _eval_faction_count(cond, state)
		"faction_ratio":
			return _eval_faction_ratio(cond, state)
		"excluded_faction":
			return _eval_excluded_faction(cond, state)
		"card_type_ratio":
			return _eval_card_type_ratio(cond, state)
		"min_realm":
			return _eval_min_realm(cond, state)
		"min_alchemy_count":
			return _eval_min_alchemy_count(cond, state)
		"required_characters":
			return _eval_required_characters(cond, state)
		"avg_card_cost":
			return _eval_avg_card_cost(cond, state)
		"min_rarity":
			return _eval_min_rarity(cond, state)
		"max_dark_gold_count":
			return _eval_max_dark_gold_count(cond, state)

	return {satisfied = false, weight = 0.0, score = 0.0, missing_text = "未知条件类型: %s" % cond_type, skipped = false}


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


# --- 辅助方法 ---------------------------------------------------------------------

## 检查角色是否匹配 tags 中任一标签。[br]
## 对 tags 中的每个 tag，检查角色 faction_tags 中是否有直接匹配或可推导为该大阵营的标签。
func _char_matches_tags(char: Dictionary, tags: Array) -> bool:
	var char_tags: Array = char.get("faction_tags", [])
	for char_tag in char_tags:
		for target_tag in tags:
			if char_tag == target_tag:
				return true
			# 门派推导为大阵营——简化版：如果角色标签的 parent 是目标标签
			# 委托 FactionSystem 的 derive_major_alignment 逻辑
			if _is_tag_under_alignment(char_tag, target_tag):
				return true
	return false


## 判定某标签是否属于指定大阵营。[br]
## 简化版推导——基于 SCHOOL_LIBRARY 不依赖 FactionSystem。[br]
## 内置映射：门派标签 → 大阵营。
func _is_tag_under_alignment(tag: StringName, alignment: StringName) -> bool:
	# 门派 → 大阵营映射（与 FactionSystem.FACTION_LIBRARY 一致）
	const TAG_TO_MAJOR: Dictionary = {
		# 正道门派
		&"qixuanmen": &"zhengdao",
		&"dangxia_valley": &"zhengdao",
		&"xuanbing_palace": &"zhengdao",
		&"dongyu": &"zhengdao",
		&"xingdou_sect": &"zhengdao",
		&"wei_family": &"zhengdao",
		# 魔道门派
		&"xuehai_temple": &"modao",
		&"meiying_pavilion": &"modao",
		&"samsara_hall": &"modao",
		&"xuesha_cult": &"modao",
		&"heisha_cult": &"modao",
		&"yunmeng": &"modao",
	}
	var derived: StringName = TAG_TO_MAJOR.get(tag, &"") as StringName
	if derived.is_empty():
		return false
	return derived == alignment


## 获取标签的显示名称（用于 missing_text）。
func _get_tag_display_name(tag: StringName) -> String:
	const TAG_NAMES: Dictionary = {
		&"zhengdao": "正道",
		&"modao": "魔道",
		&"guixu_abyss": "归墟",
		&"zhenling": "真灵",
	}
	return TAG_NAMES.get(tag, str(tag))


## 标签列表显示名（用于 missing_text）。
func _tags_display(tags: Array) -> String:
	var names: Array[String] = []
	for tag in tags:
		names.append(_get_tag_display_name(tag))
	return "/".join(names)
