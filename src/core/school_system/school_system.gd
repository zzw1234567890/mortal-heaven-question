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

## 条件评估引擎子模块——惰性初始化（Sprint 9 Story 2 拆分）。
var _conditions: RefCounted = null

## 惰性获取条件评估引擎子模块（Sprint 9 Story 2 拆分）。
func _get_conditions() -> RefCounted:
	if _conditions == null:
		_conditions = load("res://src/core/school_system/school_conditions.gd").new()
	return _conditions


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
		if _get_conditions().check_all_conditions(school, state):
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
		var result: Dictionary = _get_conditions().evaluate_condition(cond, state, school_id)

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

## 检查流派的全部条件是否满足——委托给 _conditions 子模块。
func _check_all_conditions(school: Dictionary, state: Dictionary) -> bool:
	return _get_conditions().check_all_conditions(school, state)


## 评估单个检测条件——委托给 _conditions 子模块。
func _evaluate_condition(cond: Dictionary, state: Dictionary, _school_id: StringName) -> Dictionary:
	return _get_conditions().evaluate_condition(cond, state, _school_id)


# --- 条件评估器及辅助方法（已提取到 school_conditions.gd 子模块）---
