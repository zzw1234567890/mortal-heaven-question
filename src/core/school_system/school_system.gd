extends Node
# class_name SchoolSystem —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突，导致 SS_SCRIPT.new() 测试实例无法解析。
# 测试以 var ss: Node 持有 + 动态分派访问（同 GSM/EventSystem/RealmSystem/
# ResourceSystem/CardSystem/FactionSystem/CostSystem/StatusEffectSystem 先例）。

## SchoolSystem —— 流派检测 + 纯查询 API Autoload（#19）。
##
## Core 层 Autoload。持有 [constant SCHOOL_LIBRARY] 编译时常量流派库
## （5 流派完整定义），提供纯计算检测引擎 [method detect] / [method calculate_match]
## 以及纯查询接口 [method get_school_info] / [method get_school_effects] /
## [method get_all_schools]。
##
## [b]纯查询接口[/b]（ADR-0025 §信号策略）——detect()/calculate_match() 为纯计算无副作用。
## [method detect] 本身不发射信号——school_changed 由调用方在状态变更时触发。
## 流派激活状态存 GSM battle.active_school，SchoolSystem 仅查询。
##
## [b]Autoload 顺序[/b]：GSM → ... → StatusEffectSystem → SchoolSystem（#19）
## （在 AISystem #18 之后，CombatSystem 之前——ADR-0025 §Autoload 初始化）。
##
## [b]来源[/b]: ADR-0025 + GDD school-system.md。

# === 信号声明（Cat 2b）============================================================

## 流派激活状态变更时发射——由调用方（CombatSystem/DeckEdit）在状态变更时触发。
## [param old_school_id] 旧流派 ID（首次激活时为空 StringName）。[br]
## [param new_school_id] 新流派 ID（流派失效时为空 StringName）。
signal school_changed(old_school_id: StringName, new_school_id: StringName)


# === 流派库（编译时常量）===========================================================

## 5 流派完整定义——编译时分配，零运行时加载开销。[br]
## [b]只读约定[/b]（ADR-0025）：const Dictionary 并非真正冻结，团队约定运行时不写入。[br]
## [br]结构：每个 school_id → {[br]
##   id, name, tagline, description, priority,[br]
##   detection: {conditions: [...]},[br]
##   effects: [{type, target, value, trigger, ...}],[br]
##   weakness, visual_theme[br]
## }[br]
## [br]优先级（priority 数值小者优先）：归墟(1) > 正道(2) > 魔道(3) > 正邪混合(4) > 百艺(5)。
const SCHOOL_LIBRARY: Dictionary = {
	# =========================================================================
	# ① 归墟真灵流 —— priority 1（条件最苛刻，优先级最高）
	# =========================================================================
	&"spirit_realm_beast": {
		id = &"spirit_realm_beast",
		name = "归墟真灵流",
		tagline = "万灵臣服",
		description = "以归墟/真灵阵营的高阶角色为核心的后期流派，角色单体强度高但成型慢，一旦成型碾压一切。",
		priority = 1,
		detection = {
			conditions = [
				{type = "min_realm", value = 3},  # 金丹期(L≥3)
				{type = "faction_count", tags = [&"guixu_abyss", &"zhenling"], min = 2},  # 归墟/真灵标签 ≥2
				{type = "avg_card_cost", min = 3.0},  # 卡组总费用均值 ≥3.0
				{type = "min_rarity", value = "blue"},  # 场上无低于蓝色稀有度角色
			],
		},
		effects = [
			{type = "stat_boost", target = "spirit", hp = 3, atk = 1},
			{type = "immune_debuff", target = "spirit", debuffs = [&"fear", &"confusion"]},
			{type = "aura_hp", value = 1, per_unit = "spirit"},
		],
		weakness = "成型门槛极高——金丹期前无法激活；被快攻流派克制；卡组费用均值高意味着前期抽牌容易卡手。",
		visual_theme = "银白/星蓝——星辰流转的光效",
	},

	# =========================================================================
	# ② 正道发育流 —— priority 2
	# =========================================================================
	&"righteous_dev": {
		id = &"righteous_dev",
		name = "正道发育流",
		tagline = "稳扎稳打，步步为营",
		description = "以正道阵营角色为核心的防御续航流派，擅长拖长战斗回合数，通过持续回复和治疗耗死对手。",
		priority = 2,
		detection = {
			conditions = [
				{type = "faction_count", tags = [&"zhengdao"], min = 3},  # 正道 ≥3
				{type = "faction_ratio", tag = &"zhengdao", min = 0.6},  # 正道占比 ≥60%
				{type = "excluded_faction", tag = &"modao"},  # 不含魔道阵营限定卡
			],
		},
		effects = [
			{type = "regen", target = "zhengdao", value = 2, trigger = "turn_end"},
			{type = "damage_reduce", target = "zhengdao", value = 1, floor = 1},
			{type = "formation_ease", value = -1},
		],
		weakness = "被高爆发流派克制（回复跟不上爆发伤害）；清场类AOE对续航阵型打击大。",
		visual_theme = "青色/金色——温润的光效",
	},

	# =========================================================================
	# ③ 魔道快攻流 —— priority 3
	# =========================================================================
	&"demonic_aggro": {
		id = &"demonic_aggro",
		name = "魔道快攻流",
		tagline = "先下手为强",
		description = "以魔道阵营角色为核心的快攻流派，前3回合打出成吨伤害，争取在对手站稳前结束战斗。",
		priority = 3,
		detection = {
			conditions = [
				{type = "faction_count", tags = [&"modao"], min = 3},  # 魔道 ≥3
				{type = "faction_ratio", tag = &"modao", min = 0.6},  # 魔道占比 ≥60%
				{type = "card_type_ratio", card_type = "low_cost", min_pct = 0.5},  # 费用≤2的低费卡 ≥50%
			],
		},
		effects = [
			{type = "attack_boost", target = "modao", value = 2, trigger = "first_3_turns", turn_limit = 3},
			{type = "draw_on_kill", target = "modao", value = 1, trigger = "on_kill"},
			{type = "cost_boost", target = "player", value = 1, turn = 1},
		],
		weakness = "被高防御流派克制（单张高伤牌被格挡后节奏断档）；拖到第5回合后输出衰减明显。",
		visual_theme = "赤红/暗紫——凌厉锋锐的光效",
	},

	# =========================================================================
	# ④ 正邪混合流 —— priority 4
	# =========================================================================
	&"mixed_alignment": {
		id = &"mixed_alignment",
		name = "正邪混合流",
		tagline = "不拘一格，为我所用",
		description = "同时使用正道和魔道角色的均衡流派，放弃阵营极致加成换取更高的构筑灵活性和场面适应性。",
		priority = 4,
		detection = {
			conditions = [
				{type = "faction_count", tags = [&"zhengdao"], min = 2},  # 正道 ≥2
				{type = "faction_count", tags = [&"modao"], min = 2},  # 魔道 ≥2
				{type = "faction_ratio", tag = &"zhengdao", min = 0.3, max = 0.7},  # 正道占比 30%~70%
				{type = "faction_ratio", tag = &"modao", min = 0.3, max = 0.7},  # 魔道占比 30%~70%
				{type = "max_dark_gold_count", value = 1},  # 暗金卡不超过1张
			],
		},
		effects = [
			{type = "stat_boost", target = "mixed", atk = 1, def = 1},
			{type = "cost_discount", target = "player", chance = 0.3, value = 1},
			{type = "formation_ease", value = -1},
		],
		weakness = "核心增益依赖双方同时在场——任意一方减员后强度下降明显；被纯阵营流派克制。",
		visual_theme = "青紫交织——阴阳融合的光效",
	},

	# =========================================================================
	# ⑤ 百艺炼丹流 —— priority 5（需运营进度）
	# =========================================================================
	&"alchemy_mastery": {
		id = &"alchemy_mastery",
		name = "百艺炼丹流",
		tagline = "炼丹炼器，以物养战",
		description = "以炼丹炼器为核心的资源转化流派，不靠战斗正面碾压，而是通过制作丹药/法宝卡牌堆叠属性，用资源量压倒对手。",
		priority = 5,
		detection = {
			conditions = [
				{type = "card_type_ratio", card_type = "pill", min_pct = 0.2},  # 丹药卡 ≥20%
				{type = "required_characters", ids = [&"wanxiang_zhenren"]},  # 万象真人在场或已收藏
				{type = "min_alchemy_count", value = 3},  # 本局已进行 ≥3 次炼丹/炼器
			],
		},
		effects = [
			{type = "pill_boost", target = "all", value = 0.2, trigger = "on_pill_use"},
			{type = "cost_reduce", target = "alchemy_material", value = 1, floor = 1},
			{type = "action_recover", target = "player", per_pills = 3, value = 1, max_triggers = 3},
			{type = "pill_breakthrough", target = "player", chance = 0.1},
		],
		weakness = "依赖资源——如果没有足够的灵材/灵石，流派无法发挥作用；前期战力薄弱（卡组中大量丹药卡代替了战斗卡）。",
		visual_theme = "金色/药鼎——炼丹光效",
	},
}


# === 查询 API =====================================================================

## 流派检测——按 priority 升序遍历，返回首个全部条件满足的流派 ID。[br]
## [br][param state] 检测所需状态数据 Dictionary：[br]
##   - [code]field_characters[/code]: Array[Dictionary]——场上角色，每个含 [code]faction_tags[/code]（Array[StringName]）、[br]
##     [code]card_type[/code]（String）、[code]cost[/code]（int）、[code]rarity[/code]（String）[br]
##   - [code]deck_cards[/code]: Array[Dictionary]——卡组卡牌，每个含 [code]card_type[/code]、[code]cost[/code]、[code]rarity[/code]、[code]is_modao_exclusive[/code]（bool）[br]
##   - [code]player_realm[/code]: int——玩家境界等级[br]
##   - [code]alchemy_count[/code]: int——本局炼丹/炼器操作次数[br]
##   - [code]collected_characters[/code]: Array[StringName]——已收藏角色 ID 列表[br]
## [br][b]返回[/b]: 流派 ID（StringName）；无匹配返回 [code]&""[/code]。[br]
## [br][b]复杂度[/b]：最坏 5 流派 × 5 条件 = 25 次检查 <0.001ms。[br]
## [br][b]来源[/b]: ADR-0025 §关键接口。
func detect(state: Dictionary) -> StringName:
	var candidates: Array[Dictionary] = []
	for school_id in SCHOOL_LIBRARY:
		candidates.append(SCHOOL_LIBRARY[school_id])

	# 按 priority 升序排序（数值小者优先）
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a.priority < b.priority
	)

	for school in candidates:
		if _check_all_conditions(school, state):
			return school.id as StringName

	return &""


## 流派匹配度计算——返回加权得分和缺失条件列表。[br]
## [br]权重分配（GDD §公式#1）：阵营人数 40、必备角色 30、卡牌类型占比 20、境界 10。[br]
## [br][param school_id] 流派 ID。[br]
## [param state] 同 [method detect] 的 state 参数。[br]
## [br][b]返回[/b]: [code]{score: float, missing: Array[String]}[/code]——score ∈ [0, 100]，round 至整数。[br]
## [br][b]来源[/b]: ADR-0025 §关键接口 + GDD §公式#1。
func calculate_match(school_id: StringName, state: Dictionary) -> Dictionary:
	if not SCHOOL_LIBRARY.has(school_id):
		return {score = 0.0, missing = ["未知流派: %s" % school_id]}

	var school: Dictionary = SCHOOL_LIBRARY[school_id]
	var total_weight: float = 0.0
	var weighted_score: float = 0.0
	var missing: Array[String] = []

	var conditions: Array = school.detection.get("conditions", [])

	for cond in conditions:
		var cond_type: String = cond.get("type", "")
		var result: Dictionary = _evaluate_condition(cond, state, school_id)

		if result.get("skipped", false):
			continue

		total_weight += result.get("weight", 0.0)
		weighted_score += result.get("score", 0.0)

		if not result.get("satisfied", false):
			missing.append(result.get("missing_text", ""))

	if total_weight > 0:
		var raw_score: float = (weighted_score / total_weight) * 100.0
		return {score = round(raw_score), missing = missing}
	return {score = 0.0, missing = missing}


## 查询流派元数据。[br]
## [br][param school_id] 流派 ID。[br]
## [br][b]返回[/b]: 含 name/tagline/description/effects/weakness/visual_theme 的 Dictionary；[br]
##           未知 school_id 返回空字典（不报错）。[br]
## [br][b]来源[/b]: ADR-0025 §关键接口。
func get_school_info(school_id: StringName) -> Dictionary:
	if not SCHOOL_LIBRARY.has(school_id):
		return {}
	var school: Dictionary = SCHOOL_LIBRARY[school_id]
	return {
		name = school.name,
		tagline = school.tagline,
		description = school.description,
		effects = school.effects,
		weakness = school.weakness,
		visual_theme = school.visual_theme,
	}


## 查询流派增益效果列表。[br]
## [br][param school_id] 流派 ID。[br]
## [br][b]返回[/b]: Array[Dictionary]——增益效果列表；未知 school_id 返回空数组（不报错）。[br]
## [br][b]来源[/b]: ADR-0025 §关键接口。
func get_school_effects(school_id: StringName) -> Array[Dictionary]:
	if not SCHOOL_LIBRARY.has(school_id):
		return []
	var school: Dictionary = SCHOOL_LIBRARY[school_id]
	var effects: Array = school.get("effects", [])
	var result: Array[Dictionary] = []
	for e in effects:
		result.append(e)
	return result


## 获取所有流派 ID 列表。[br]
## [br][b]返回[/b]: Array[StringName]——5 流派 ID（按 priority 升序）。[br]
## [br][b]来源[/b]: ADR-0025 §关键接口。
func get_all_schools() -> Array[StringName]:
	var result: Array[StringName] = []
	for school_id in SCHOOL_LIBRARY:
		result.append(school_id)
	# 按 priority 升序
	result.sort_custom(func(a: StringName, b: StringName) -> bool:
		return SCHOOL_LIBRARY[a].priority < SCHOOL_LIBRARY[b].priority
	)
	return result


# === 内部辅助 =====================================================================

## 检查流派的全部条件是否满足。[br]
## [br][b]返回[/b]: 全部条件满足则 true。
func _check_all_conditions(school: Dictionary, state: Dictionary) -> bool:
	var conditions: Array = school.detection.get("conditions", [])
	if conditions.is_empty():
		return false
	for cond in conditions:
		var result: Dictionary = _evaluate_condition(cond, state, school.id)
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
func _evaluate_condition(cond: Dictionary, state: Dictionary, _school_id: StringName) -> Dictionary:
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