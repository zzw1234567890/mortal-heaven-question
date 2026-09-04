extends RefCounted
## InscriptionCandidates —— 铭刻候选生成子模块（从 inscription_system.gd 拆分）。
##
## 纯函数 RefCounted 类——不持有运行时状态，所有方法为 static。[br]
## 包含 6 步权重变换管线 + 加权不放回抽取 + 中间结果查询。
##
## [br]来源: ADR-0030 §generate_candidates + GDD inscription-system.md §3。
## [br]Sprint 10 Story 4：从 inscription_system.gd 拆分。


# === 方向枚举（与 InscriptionSystem.Direction 同值——子模块内独立声明）=============

## 定向铭刻方向枚举——NONE=无偏向/ATTACK=攻击向/DEFENSE=防御向/TACTICAL=战术向。
enum Direction {
	NONE = 0,     ## 无偏向——保持原始权重
	ATTACK = 1,   ## 攻击向——攻击/暴击/暴伤权重×1.5
	DEFENSE = 2,  ## 防御向——防御/生命/回血权重×1.5
	TACTICAL = 3, ## 战术向——吸血/虚弱/破甲/灵力萃取权重×1.5
}


# === 常量 =====================================================================

## 定向铭刻方向加权倍率（GDD §3）。
const DIRECTION_BONUS_MULTIPLIER: float = 1.5

## 已有属性权重减半倍率（GDD §3）。
const DUPLICATE_PENALTY_MULTIPLIER: float = 0.5

## 候选数量——每次铭刻展示 3 个候选（GDD §1）。
const CANDIDATE_COUNT: int = 3


# === 副属性权重表（const Dictionary——编译时常量，运行时只读）==================

## 11 种副属性权重表（GDD §2 副属性池）。[br]
## 键 = 副属性 ID（String），值 = 权重数据 Dictionary。[br]
## [br]每个条目含：weight（初始权重）、tier（品质梯级 1-4）、direction（定向方向）。[br]
## [br]来源: GDD inscription-system.md §2。
const SUBSTAT_WEIGHTS: Dictionary = {
	# T1——最常见的基础数值
	"atk+1":       {"weight": 22, "tier": 1, "direction": Direction.ATTACK},
	"def+1":       {"weight": 18, "tier": 1, "direction": Direction.DEFENSE},
	# T2——中频概率属性
	"crit+3":      {"weight": 15, "tier": 2, "direction": Direction.ATTACK},
	"crit_dmg+5":  {"weight": 12, "tier": 2, "direction": Direction.ATTACK},
	# T3——较稀有，偏战术效果
	"hp+2":        {"weight": 10, "tier": 3, "direction": Direction.DEFENSE},
	"lifesteal+2": {"weight": 8,  "tier": 3, "direction": Direction.TACTICAL},
	"weakness":    {"weight": 6,  "tier": 3, "direction": Direction.TACTICAL},
	# T4——极其稀有，改变战斗节奏，仅境界 L≥2（筑基期+）可获取
	"cost-1":      {"weight": 4,  "tier": 4, "direction": -1},
	"regen+1":     {"weight": 3,  "tier": 4, "direction": Direction.DEFENSE},
	"armor_break": {"weight": 3,  "tier": 4, "direction": Direction.TACTICAL},
	"mana_extract":{"weight": 2,  "tier": 4, "direction": Direction.TACTICAL},
}


# === 候选生成（纯函数——不修改状态，不发射信号）================================

## 生成铭刻候选副属性——6 步权重变换管线（GDD §3 候选生成规则）。[br]
## [br][param existing] 当前法宝已有铭刻数组（Array[Dictionary]，每项含 type 字段）。[br]
## [br][param realm_level] 当前境界层级 [1, 5]（1=炼气, 2=筑基, ...）。[br]
## [br][param to_replace_idx] 被替换属性索引，-1 表示无替换（新增模式）。[br]
## [br][param direction] 定向铭刻方向（Direction 枚举）。[br]
## [br][param rng] 独立 RNG 实例。[br]
## [br][b]返回[/b]: Array[String]——3 个互不相同的候选副属性键。[br]
## [br][b]流程[/b]: 有效已有列表→基础权重→定向加权→境界加成/T4移除→费用-1特殊处理→已有属性减半→不放回抽取。[br]
## [br]来源: ADR-0030 §generate_candidates + GDD §3。
static func generate_candidates(existing: Array, realm_level: int, to_replace_idx: int, direction: int, rng: RandomNumberGenerator) -> Array:
	# Step 1: 构建有效已有列表（排除被替换属性）
	var effective: Array = []
	for i: int in range(existing.size()):
		if i != to_replace_idx:
			var entry: Dictionary = existing[i]
			effective.append(str(entry.get("type", "")))

	# Step 2: 从权重表复制基础权重
	var weights: Dictionary = {}
	for key: String in SUBSTAT_WEIGHTS:
		weights[key] = int(SUBSTAT_WEIGHTS[key]["weight"])

	# Step 2.5: 定向铭刻方向加权（在境界加成前应用）
	if direction == Direction.ATTACK:
		for key: String in ["atk+1", "crit+3", "crit_dmg+5"]:
			if weights.has(key):
				weights[key] = floori(weights[key] * DIRECTION_BONUS_MULTIPLIER)
	elif direction == Direction.DEFENSE:
		for key: String in ["def+1", "hp+2"]:
			if weights.has(key):
				weights[key] = floori(weights[key] * DIRECTION_BONUS_MULTIPLIER)
		if realm_level >= 2 and weights.has("regen+1"):
			weights["regen+1"] = floori(weights["regen+1"] * DIRECTION_BONUS_MULTIPLIER)
	elif direction == Direction.TACTICAL:
		for key: String in ["lifesteal+2", "weakness"]:
			if weights.has(key):
				weights[key] = floori(weights[key] * DIRECTION_BONUS_MULTIPLIER)
		if realm_level >= 2:
			if weights.has("armor_break"):
				weights["armor_break"] = floori(weights["armor_break"] * DIRECTION_BONUS_MULTIPLIER)
			if weights.has("mana_extract"):
				weights["mana_extract"] = floori(weights["mana_extract"] * DIRECTION_BONUS_MULTIPLIER)

	# Step 3: 境界加成或 T4 移除
	if realm_level >= 2:
		var bonus: int = floori(realm_level * 2)
		for key: String in ["cost-1", "regen+1", "armor_break", "mana_extract"]:
			if weights.has(key):
				weights[key] += bonus
	else:
		# 炼气期：移除 T4 属性
		for key: String in ["cost-1", "regen+1", "armor_break", "mana_extract"]:
			weights.erase(key)

	# Step 3.5: 费用-1 已存在时完全移除（不叠加→死抽候选不应出现）
	if effective.has("cost-1"):
		weights.erase("cost-1")

	# Step 4: 已有相同属性权重减半（作用于已含加成后的权重，max(1,...) 防归零）
	for stat: String in effective:
		if weights.has(stat) and int(weights[stat]) > 0:
			weights[stat] = maxi(1, floori(int(weights[stat]) * DUPLICATE_PENALTY_MULTIPLIER))

	# Step 5: 不放回抽取 3 个互不相同的候选
	return _weighted_sample_without_replacement(weights, CANDIDATE_COUNT, rng)


## 加权不放回抽取——从权重字典中抽取 N 个互不相同的键（ADR-0030）。[br]
## [br][param weights] 权重字典——键=属性名，值=权重值。[br]
## [br][param count] 要抽取的候选数量。[br]
## [br][param rng] 独立 RNG 实例。[br]
## [br][b]返回[/b]: Array[String]——互不相同的候选键列表（最多 min(pool_size, count) 个）。[br]
## [br]来源: ADR-0030 §_weighted_sample_without_replacement。
static func _weighted_sample_without_replacement(weights: Dictionary, count: int, rng: RandomNumberGenerator) -> Array:
	var pool: Array = weights.keys()
	var result: Array = []
	var take: int = mini(count, pool.size())

	for _i: int in range(take):
		if pool.is_empty():
			break

		# 计算总权重
		var total_weight: float = 0.0
		for key: String in pool:
			total_weight += int(weights[key])

		if total_weight <= 0.0:
			# 所有权重为 0——直接取第一个
			result.append(pool[0])
			pool.pop_at(0)
			continue

		# 加权抽取
		var roll: float = rng.randf() * total_weight
		var accumulated: float = 0.0
		var chosen_idx: int = -1
		for j: int in range(pool.size()):
			accumulated += int(weights[pool[j]])
			if roll < accumulated:
				chosen_idx = j
				break

		if chosen_idx < 0:
				chosen_idx = pool.size() - 1

		result.append(pool[chosen_idx])
		pool.pop_at(chosen_idx)

	return result


# === 候选生成中间结果查询（测试用——返回计算后的权重字典）=====================

## 获取候选生成的中间权重字典——供单元测试验证权重变换（AC-6~AC-8c）。[br]
## [br][param existing] 已有铭刻数组。[br]
## [br][param realm_level] 境界层级。[br]
## [br][param to_replace_idx] 被替换索引（-1=无）。[br]
## [br][param direction] 定向方向。[br]
## [br][b]返回[/b]: Dictionary——变换后的权重字典（键=属性名，值=权重值）。[br]
## [br]来源: ADR-0030 §generate_candidates 测试辅助。
static func get_candidate_weights(existing: Array, realm_level: int, to_replace_idx: int, direction: int) -> Dictionary:
	# Step 1: 构建有效已有列表
	var effective: Array = []
	for i: int in range(existing.size()):
		if i != to_replace_idx:
			var entry: Dictionary = existing[i]
			effective.append(str(entry.get("type", "")))

	# Step 2: 复制基础权重
	var weights: Dictionary = {}
	for key: String in SUBSTAT_WEIGHTS:
		weights[key] = int(SUBSTAT_WEIGHTS[key]["weight"])

	# Step 2.5: 定向加权
	if direction == Direction.ATTACK:
		for key: String in ["atk+1", "crit+3", "crit_dmg+5"]:
			if weights.has(key):
				weights[key] = floori(weights[key] * DIRECTION_BONUS_MULTIPLIER)
	elif direction == Direction.DEFENSE:
		for key: String in ["def+1", "hp+2"]:
			if weights.has(key):
				weights[key] = floori(weights[key] * DIRECTION_BONUS_MULTIPLIER)
		if realm_level >= 2 and weights.has("regen+1"):
			weights["regen+1"] = floori(weights["regen+1"] * DIRECTION_BONUS_MULTIPLIER)
	elif direction == Direction.TACTICAL:
		for key: String in ["lifesteal+2", "weakness"]:
			if weights.has(key):
				weights[key] = floori(weights[key] * DIRECTION_BONUS_MULTIPLIER)
		if realm_level >= 2:
			if weights.has("armor_break"):
				weights["armor_break"] = floori(weights["armor_break"] * DIRECTION_BONUS_MULTIPLIER)
			if weights.has("mana_extract"):
				weights["mana_extract"] = floori(weights["mana_extract"] * DIRECTION_BONUS_MULTIPLIER)

	# Step 3: 境界加成或 T4 移除
	if realm_level >= 2:
		var bonus: int = floori(realm_level * 2)
		for key: String in ["cost-1", "regen+1", "armor_break", "mana_extract"]:
			if weights.has(key):
				weights[key] += bonus
	else:
		for key: String in ["cost-1", "regen+1", "armor_break", "mana_extract"]:
			weights.erase(key)

	# Step 3.5: 费用-1 已存在时完全移除
	if effective.has("cost-1"):
		weights.erase("cost-1")

	# Step 4: 已有属性权重减半
	for stat: String in effective:
		if weights.has(stat) and int(weights[stat]) > 0:
			weights[stat] = maxi(1, floori(int(weights[stat]) * DUPLICATE_PENALTY_MULTIPLIER))

	return weights
