class_name InscriptionSystem
extends RefCounted
## InscriptionSystem —— 法宝铭刻系统 RefCounted 工具类（ADR-0030）。
##
## Feature 层 RefCounted（非 Autoload）。持有 11 种副属性的 const Dictionary 权重表[br]
## 和候选生成算法（6 步权重变换管线）。[br]
## 通过 ResourceSystem.spend_resource() 消费灵材，[br]
## 通过 CardSystem 读写 CardInstance 的铭刻字段。[br]
## 自身不持有任何运行时持久状态。[br]
## [br][b]Story 6-8 范围[/b]：权重表 + generate_candidates + 加权不放回抽取。[br]
## [br]来源: ADR-0030 §关键接口 / GDD inscription-system.md §2-3。


# === 方向枚举 ================================================================

## 定向铭刻方向枚举——NONE=无偏向/ATTACK=攻击向/DEFENSE=防御向/TACTICAL=战术向。
enum Direction {
	NONE = 0,     ## 无偏向——保持原始权重
	ATTACK = 1,   ## 攻击向——攻击/暴击/暴伤权重×1.5
	DEFENSE = 2,  ## 防御向——防御/生命/回血权重×1.5
	TACTICAL = 3, ## 战术向——吸血/虚弱/破甲/灵力萃取权重×1.5
}

## 铭刻结果枚举——成功/灵材不足/非法宝/满需替换。
enum InscribeResult {
	SUCCESS = 0,                ## 铭刻成功
	INSUFFICIENT_MATERIALS = 1, ## 灵材不足
	NOT_ARTIFACT = 2,           ## 目标非法宝卡牌
	FULL_NEED_REPLACE = 3,     ## 已满 3 条需选择替换
}


# === 常量 =====================================================================

## 定向铭刻方向加权倍率（GDD §3）。
const DIRECTION_BONUS_MULTIPLIER: float = 1.5

## 已有属性权重减半倍率（GDD §3）。
const DUPLICATE_PENALTY_MULTIPLIER: float = 0.5

## 候选数量——每次铭刻展示 3 个候选（GDD §1）。
const CANDIDATE_COUNT: int = 3

## 递增成本软上限——第 6 次及以后固定 5 灵材/次（GDD §1）。
const COST_SOFT_CAP: int = 5

## 拆解返还比例——铭刻总消耗灵材的 50%（GDD §4）。
const DISMANTLE_REFUND_RATIO: float = 0.5

## 最大铭刻条数——每件法宝最多 3 条副属性（GDD §1）。
const MAX_INSCRIPTIONS: int = 3

## 中级灵材品质值（与 ResourceSystem.LingCaiQuality.MEDIUM 一致）。
const LING_CAI_MEDIUM: int = 2


# === 测试注入覆盖（static var——测试时注入 mock，运行时为 null 走 Autoload）===

## CardSystem 覆盖引用——测试注入 mock，运行时为 null。
static var _card_system_override: Node = null

## ResourceSystem 覆盖引用——测试注入 mock，运行时为 null。
static var _resource_system_override: Node = null


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


# === 铭刻费用与拆解返还（纯函数）==============================================

## 铭刻费用——第 N 次铭刻消耗 = min(N+1, 5) 中级灵材（GDD §1 递增成本）。[br]
## [br][param inscription_count] 当前法宝已铭刻次数（从 0 开始）。[br]
## [br][b]返回[/b]: 本次铭刻所需中级灵材数。[br]
## [br]来源: ADR-0030 §inscription_cost + GDD §1。
static func inscription_cost(inscription_count: int) -> int:
	return mini(inscription_count + 1, COST_SOFT_CAP)


## 拆解返还——铭刻总消耗灵材的 50%（向下取整，至少返 1）（GDD §4）。[br]
## [br][param total_materials_spent] 该法宝铭刻累计消耗中级灵材数。[br]
## [br][b]返回[/b]: 返还灵材数（0=从未铭刻，≥1=至少返 1）。[br]
## [br]来源: ADR-0030 §dismantle_inscription_refund + GDD §4。
static func dismantle_inscription_refund(total_materials_spent: int) -> int:
	if total_materials_spent == 0:
		return 0
	return maxi(1, floori(total_materials_spent * DISMANTLE_REFUND_RATIO))


# === 铭刻编排（Story 6-9）===================================================

## 执行铭刻——完整编排流程（ADR-0030 §inscribe）。[br]
## [br][param artifact_inst] 目标法宝实例（CardInstance 或兼容对象）。[br]
## [br][param direction] 定向铭刻方向（Direction 枚举）。[br]
## [br][param rng] 独立 RNG 实例。[br]
## [br][param to_replace_idx] 被替换属性索引，-1=无替换（新增模式）。[br]
## [br][b]返回[/b]: Dictionary——{result, candidates, cost, is_replace, to_replace_idx}。[br]
## [br][b]流程[/b]: 校验法宝→计算费用→校验灵材→扣减灵材→获取境界→生成候选→返回。[br]
## [br]来源: ADR-0030 §inscribe + GDD §1/§4。
static func inscribe(artifact_inst: Variant, direction: int, rng: RandomNumberGenerator, to_replace_idx: int = -1) -> Dictionary:
	# 1. 校验法宝类型——通过 template_id 查 CardSystem
	var template_id: String = _safe_get_str(artifact_inst, "template_id")
	var card_sys: Node = _get_card_system()
	if card_sys == null or not card_sys.has_method("get_template"):
		return {"result": InscribeResult.NOT_ARTIFACT}
	var template: Dictionary = card_sys.get_template(StringName(template_id))
	if template.is_empty():
		return {"result": InscribeResult.NOT_ARTIFACT}
	var card_type: String = str(template.get("type", ""))
	if card_type != "artifact":
		return {"result": InscribeResult.NOT_ARTIFACT}

	# 2. 计算费用并校验灵材
	var inscription_count: int = _safe_get_int(artifact_inst, "inscription_count")
	var cost: int = inscription_cost(inscription_count)
	var res_sys: Node = _get_resource_system()
	if res_sys == null:
		return {"result": InscribeResult.INSUFFICIENT_MATERIALS, "cost": cost}
	if not res_sys.can_spend(&"ling_cai", cost, LING_CAI_MEDIUM):
		return {"result": InscribeResult.INSUFFICIENT_MATERIALS, "cost": cost}

	# 3. 灵材扣减（确认即扣——与 GDD AC-3 一致）
	res_sys.spend_resource(&"ling_cai", cost, LING_CAI_MEDIUM)

	# 4. 获取境界层级
	var gsm: Node = _get_gsm()
	var realm_level: int = 1
	if gsm != null:
		realm_level = int(gsm.player.get("realm"))

	# 5. 读取已有铭刻
	var existing: Array = _safe_get_array(artifact_inst, "inscriptions")

	# 6. 生成候选
	var candidates: Array = generate_candidates(existing, realm_level, to_replace_idx, direction, rng)

	# 7. 标记是否为替换模式
	var is_replace: bool = to_replace_idx >= 0

	return {
		"result": InscribeResult.SUCCESS,
		"candidates": candidates,
		"cost": cost,
		"is_replace": is_replace,
		"to_replace_idx": to_replace_idx,
	}


## 应用玩家选择的候选——在 UI 回调玩家选择后调用（ADR-0030 §apply_inscription）。[br]
## [br][param artifact_inst] 目标法宝实例（CardInstance 或兼容对象）。[br]
## [br][param chosen_stat] 玩家选择的副属性键。[br]
## [br][param to_replace_idx] 被替换属性索引，-1=新增。[br]
## [br][param cost] 本次铭刻消耗灵材数。[br]
## [br]来源: ADR-0030 §apply_inscription + GDD §1/§4。
static func apply_inscription(artifact_inst: Variant, chosen_stat: String, to_replace_idx: int, cost: int) -> void:
	var entry: Dictionary = {"type": chosen_stat, "value": null}

	var inscriptions: Array = _safe_get_array(artifact_inst, "inscriptions")
	if to_replace_idx >= 0 and to_replace_idx < inscriptions.size():
		inscriptions[to_replace_idx] = entry
	else:
		inscriptions.append(entry)

	artifact_inst.set("inscriptions", inscriptions)
	artifact_inst.set("inscription_count", _safe_get_int(artifact_inst, "inscription_count") + 1)
	artifact_inst.set("total_materials_spent", _safe_get_int(artifact_inst, "total_materials_spent") + cost)


# === 系统引用辅助（static——通过 SceneTree Autoload 查找）===================

## 获取 GSM 引用——通过 SceneTree Autoload。
static func _get_gsm() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/GameStateManager")


## 获取 ResourceSystem 引用——测试注入优先，否则通过 SceneTree Autoload。
static func _get_resource_system() -> Node:
	if _resource_system_override != null and is_instance_valid(_resource_system_override):
		return _resource_system_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/ResourceSystem")


## 获取 CardSystem 引用——测试注入优先，否则通过 SceneTree Autoload。
static func _get_card_system() -> Node:
	if _card_system_override != null and is_instance_valid(_card_system_override):
		return _card_system_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("/root/CardSystem")


# === 安全属性访问辅助（兼容 RefCounted mock 和 CardInstance）==============

## 安全获取字符串属性——兼容 RefCounted（无默认值参数）和 Dictionary。
static func _safe_get_str(obj: Variant, prop: String) -> String:
	if obj is Dictionary:
		return str(obj.get(prop, ""))
	if obj.get(prop) != null:
		return str(obj.get(prop))
	return ""


## 安全获取整数属性——兼容 RefCounted（无默认值参数）和 Dictionary。
static func _safe_get_int(obj: Variant, prop: String) -> int:
	if obj is Dictionary:
		return int(obj.get(prop, 0))
	var val: Variant = obj.get(prop)
	if val == null:
		return 0
	return int(val)


## 安全获取数组属性——兼容 RefCounted（无默认值参数）和 Dictionary。
static func _safe_get_array(obj: Variant, prop: String) -> Array:
	if obj is Dictionary:
		return obj.get(prop, [])
	var val: Variant = obj.get(prop)
	if val == null:
		return []
	return val
