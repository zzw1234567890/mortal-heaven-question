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


## 流派库纯数据子模块（Sprint 12 Story 014 拆分）。
const _Library := preload("res://src/core/school_system/school_library.gd")

## 5 流派完整定义——委托给 _Library 子模块（保留 const 引用兼容测试直接访问 SCHOOL_LIBRARY）。
const SCHOOL_LIBRARY: Dictionary = _Library.SCHOOL_LIBRARY



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
