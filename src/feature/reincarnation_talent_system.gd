class_name ReincarnationTalentSystem
extends RefCounted
## ReincarnationTalentSystem —— 轮回天赋系统（RefCounted 服务类，ADR-0012）。
##
## Feature 层 RefCounted（非 Autoload）。持有 20 个天赋节点的 const Dictionary
## 天赋树定义，初始化时注册到 ProgressionSystem。提供天赋查询 API 和
## 分支解锁规则校验。[br]
## [br]来源: GDD reincarnation-talent-system.md §3 + ADR-0012 §talents 领域。


# === 天赋树常量 =============================================================

## 天赋分支枚举。
enum Branch { CULTIVATION, RESOURCE, COMBAT, CARD, REINCARNATION }

## 20 个天赋节点——5 分支 × 4 层（GDD §3 天赋树结构）。
const TALENT_TREE: Dictionary = {
	# 【修为之道】—— 加速修为积累
	"cultivation_1": {"id": "cultivation_1", "name": "勤修苦练", "cost": 8, "branch": "cultivation", "layer": 1, "effect": {"type": "cultivation_boost", "value": 0.10}, "desc": "修为获取+10%"},
	"cultivation_2": {"id": "cultivation_2", "name": "厚积薄发", "cost": 12, "branch": "cultivation", "layer": 2, "effect": {"type": "breakthrough_modifier", "value": 0.90}, "desc": "突破所需修为-10%", "prerequisite": "cultivation_1"},
	"cultivation_3": {"id": "cultivation_3", "name": "道心通明", "cost": 18, "branch": "cultivation", "layer": 3, "effect": {"type": "overflow_conversion", "value": 1.50}, "desc": "溢出修为转化率+50%", "prerequisite": "cultivation_2"},
	"cultivation_4": {"id": "cultivation_4", "name": "天道酬勤", "cost": 28, "branch": "cultivation", "layer": 4, "effect": {"type": "start_bonus", "value": "peiyuan_dan"}, "desc": "每局开始赠送培元丹×1", "prerequisite": "cultivation_3", "unlock_condition": {"type": "highest_realm", "value": "金丹"}},

	# 【资源之道】—— 加速资源获取
	"resource_1": {"id": "resource_1", "name": "灵脉感应", "cost": 8, "branch": "resource", "layer": 1, "effect": {"type": "resource_boost", "value": 0.10}, "desc": "探索灵石掉落+10%"},
	"resource_2": {"id": "resource_2", "name": "坊市老客", "cost": 12, "branch": "resource", "layer": 2, "effect": {"type": "shop_discount", "value": 0.15}, "desc": "商店卡牌价格-15%", "prerequisite": "resource_1"},
	"resource_3": {"id": "resource_3", "name": "炼器余料", "cost": 18, "branch": "resource", "layer": 3, "effect": {"type": "craft_cost_reduce", "value": 1}, "desc": "炼丹/炼器灵材消耗-1", "prerequisite": "resource_2"},
	"resource_4": {"id": "resource_4", "name": "苍玄行者", "cost": 30, "branch": "resource", "layer": 4, "effect": {"type": "identity_unlock", "value": "array_master"}, "desc": "解锁隐藏身份「阵道双杰」", "prerequisite": "resource_3", "unlock_condition": {"type": "unique_cards", "value": 50}},

	# 【战意之道】—— 战斗属性加成
	"combat_1": {"id": "combat_1", "name": "锋芒初显", "cost": 8, "branch": "combat", "layer": 1, "effect": {"type": "start_cost", "value": 1}, "desc": "开局首回合费用+1"},
	"combat_2": {"id": "combat_2", "name": "血战不退", "cost": 12, "branch": "combat", "layer": 2, "effect": {"type": "max_hp", "value": 2}, "desc": "角色最大生命+2", "prerequisite": "combat_1"},
	"combat_3": {"id": "combat_3", "name": "会心一击", "cost": 18, "branch": "combat", "layer": 3, "effect": {"type": "crit_rate", "value": 0.05}, "desc": "暴击率+5%", "prerequisite": "combat_2"},
	"combat_4": {"id": "combat_4", "name": "破釜沉舟", "cost": 25, "branch": "combat", "layer": 4, "effect": {"type": "low_hp_attack", "value": 2}, "desc": "己方角色低于50%HP时攻击+2", "prerequisite": "combat_3", "unlock_condition": {"type": "elite_kills", "value": 30}},

	# 【卡牌之道】—— 卡组构筑优势
	"card_1": {"id": "card_1", "name": "博闻强记", "cost": 8, "branch": "card", "layer": 1, "effect": {"type": "extra_draw", "value": 1}, "desc": "开局额外多抽1张牌"},
	"card_2": {"id": "card_2", "name": "精挑细选", "cost": 12, "branch": "card", "layer": 2, "effect": {"type": "loot_options", "value": 4}, "desc": "战利品三选一变为四选一", "prerequisite": "card_1"},
	"card_3": {"id": "card_3", "name": "暗金天命", "cost": 18, "branch": "card", "layer": 3, "effect": {"type": "darkgold_limit", "value": 1}, "desc": "暗金卡上限+1", "prerequisite": "card_2"},
	"card_4": {"id": "card_4", "name": "万法归宗", "cost": 25, "branch": "card", "layer": 4, "effect": {"type": "deck_limit", "value": 5}, "desc": "卡组上限+5", "prerequisite": "card_3", "unlock_condition": {"type": "deck_max_reached", "value": 40}},

	# 【轮回之道】—— 特殊机制解锁
	"reincarnation_1": {"id": "reincarnation_1", "name": "轮回印记", "cost": 8, "branch": "reincarnation", "layer": 1, "effect": {"type": "start_random_card", "value": "blue"}, "desc": "每局开始随机获得1张蓝卡"},
	"reincarnation_2": {"id": "reincarnation_2", "name": "因果不灭", "cost": 14, "branch": "reincarnation", "layer": 2, "effect": {"type": "keep_card_on_death", "value": 1}, "desc": "死亡后可保留1张卡牌带入下一局", "prerequisite": "reincarnation_1"},
	"reincarnation_3": {"id": "reincarnation_3", "name": "万界穿梭", "cost": 20, "branch": "reincarnation", "layer": 3, "effect": {"type": "identity_choice", "value": 2}, "desc": "开局可从2个随机身份中选择", "prerequisite": "reincarnation_2"},
	"reincarnation_4": {"id": "reincarnation_4", "name": "超脱轮回", "cost": 35, "branch": "reincarnation", "layer": 4, "effect": {"type": "headstart", "value": 200}, "desc": "开局修为从200开始 + 轮回点+20%", "prerequisite": "reincarnation_3", "unlock_condition": {"type": "total_completions", "value": 1}},
}

## 天赋总成本（GDD §3——实际值因 reincarnation L2=14 L3=20 而非标准 12/18）。
const TOTAL_COST: int = 337

## ProgressionSystem 引用——测试注入优先。
static var _progression_override: Node = null


# === 初始化 =================================================================

## 初始化——将 20 个天赋定义注册到 ProgressionSystem。
static func initialize() -> void:
	var ps: Node = _get_progression_system()
	if ps == null:
		return
	for talent_id: String in TALENT_TREE:
		ps.register_talent(talent_id, TALENT_TREE[talent_id])


# === 查询 API ================================================================

## 获取单个天赋定义。
static func get_talent_def(talent_id: String) -> Dictionary:
	return TALENT_TREE.get(talent_id, {}).duplicate(true)

## 获取指定分支的全部天赋（4 个）。
static func get_branch_talents(branch: String) -> Array:
	var result: Array = []
	for talent_id: String in TALENT_TREE:
		var def: Dictionary = TALENT_TREE[talent_id]
		if str(def.get("branch", "")) == branch:
			result.append(def.duplicate(true))
	# 按 layer 排序
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("layer", 0)) < int(b.get("layer", 0))
	)
	return result

## 获取完整天赋树状态——从 ProgressionSystem 读取。
static func get_full_tree_state() -> Dictionary:
	var ps: Node = _get_progression_system()
	if ps == null:
		return {"branches": {}, "unlocked": [], "points": 0, "slots": 0}
	var tree_state: Dictionary = ps.get_talent_tree_state()
	# 补充分支层级信息
	var branches: Dictionary = {}
	for branch: String in ["cultivation", "resource", "combat", "card", "reincarnation"]:
		branches[branch] = _get_branch_max_layer(branch, tree_state["unlocked"])
	tree_state["branches"] = branches
	return tree_state

## 检查天赋是否可解锁——前置条件 + 软解锁条件。
static func can_unlock(talent_id: String, run_context: Dictionary = {}) -> bool:
	if not TALENT_TREE.has(talent_id):
		return false
	var def: Dictionary = TALENT_TREE[talent_id]
	var ps: Node = _get_progression_system()
	if ps == null:
		return false
	var unlocked: Array = ps.get_talent_tree_state().get("unlocked", [])
	# 检查前置天赋
	var prereq: String = str(def.get("prerequisite", ""))
	if not prereq.is_empty() and not unlocked.has(prereq):
		return false
	# 检查软解锁条件（L3/L4）
	if def.has("unlock_condition"):
		var cond: Dictionary = def["unlock_condition"]
		if not _check_unlock_condition(cond, run_context):
			return false
	return true


# === 内部辅助 =================================================================

## 获取指定分支已解锁的最高层级。
static func _get_branch_max_layer(branch: String, unlocked: Array) -> int:
	var max_layer: int = 0
	for talent_id: String in unlocked:
		var def: Dictionary = TALENT_TREE.get(talent_id, {})
		if str(def.get("branch", "")) == branch:
			max_layer = maxi(max_layer, int(def.get("layer", 0)))
	return max_layer

## 检查软解锁条件。
static func _check_unlock_condition(cond: Dictionary, run_context: Dictionary) -> bool:
	var cond_type: String = str(cond.get("type", ""))
	var cond_value: Variant = cond.get("value", null)
	match cond_type:
		"highest_realm":
			return str(run_context.get("highest_realm_ever", "")) == str(cond_value)
		"unique_cards":
			return int(run_context.get("unique_cards_collected", 0)) >= int(cond_value)
		"elite_kills":
			return int(run_context.get("total_elite_kills", 0)) >= int(cond_value)
		"deck_max_reached":
			return int(run_context.get("max_deck_size", 0)) >= int(cond_value)
		"total_completions":
			return int(run_context.get("total_completions", 0)) >= int(cond_value)
		_:
			return true


## 获取 ProgressionSystem 引用——注入优先，否则 Autoload。
static func _get_progression_system() -> Node:
	if _progression_override != null:
		return _progression_override
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var root: Window = tree.root
	if root == null:
		return null
	for i: int in range(root.get_child_count()):
		var child: Node = root.get_child(i)
		if child != null and child.name == &"ProgressionSystem":
			return child
	return null


# === 解锁编排（Story 7-7）====================================================

## 解锁天赋——前置校验 + 软解锁条件 + 委托 ProgressionSystem.purchase_talent。
static func unlock_talent(talent_id: String, run_context: Dictionary = {}) -> Dictionary:
	if not TALENT_TREE.has(talent_id):
		return {"success": false, "reason": "unknown_id"}
	var def: Dictionary = TALENT_TREE[talent_id]
	var ps: Node = _get_progression_system()
	if ps == null:
		return {"success": false, "reason": "progression_not_available"}
	var unlocked: Array = ps.get_talent_tree_state().get("unlocked", [])
	# 检查前置天赋
	var prereq: String = str(def.get("prerequisite", ""))
	if not prereq.is_empty() and not unlocked.has(prereq):
		return {"success": false, "reason": "prerequisite_locked"}
	# 检查软解锁条件（L3/L4）
	if def.has("unlock_condition"):
		var cond: Dictionary = def["unlock_condition"]
		if not _check_unlock_condition(cond, run_context):
			return {"success": false, "reason": "condition_not_met"}
	# 委托 ProgressionSystem.purchase_talent
	return ps.purchase_talent(talent_id)


## 获取当前装备的天赋完整定义列表。
static func get_equipped_talents() -> Array:
	var ps: Node = _get_progression_system()
	if ps == null:
		return []
	var equipped: Array = ps.get_talent_tree_state().get("equipped", [])
	var result: Array = []
	for talent_id: String in equipped:
		if TALENT_TREE.has(talent_id):
			result.append(TALENT_TREE[talent_id].duplicate(true))
	return result

## 获取装备天赋的 effect 列表——供下游系统应用。
static func get_active_talents() -> Array:
	var equipped: Array = get_equipped_talents()
	var effects: Array = []
	for def: Dictionary in equipped:
		if def.has("effect"):
			effects.append(def["effect"].duplicate(true))
	return effects

## 设置装备的天赋——委托 ProgressionSystem.set_equipped_talents。
static func set_equipped(ids: Array) -> Dictionary:
	var ps: Node = _get_progression_system()
	if ps == null:
		return {"success": false, "reason": "progression_not_available"}
	return ps.set_equipped_talents(ids)


# === 轮回结算（Story 7-8）=====================================================

## 境界击杀上限表（GDD §2）——[炼气, 筑基, 金丹, 元婴, 化神]。
const ELITES_CAP: Array = [3, 6, 10, 15, 20]
const BOSSES_CAP: Array = [1, 3, 5, 7, 10]

## 计算轮回点获取量（GDD §2 唯一权威版本）。
static func calculate_reincarnation_points(run_data: Dictionary, unlocked_talents: Array) -> int:
	var points: int = 0
	var realm: int = int(run_data.get("realm_reached", 1))

	# 境界奖励——平方增长
	points += realm * realm * 2

	# 通关奖励
	if str(run_data.get("result", "")) == "victory":
		points += 10

	# 击杀奖励（按境界梯度上限）
	var realm_idx: int = clampi(realm - 1, 0, 4)
	var elites_cap: int = int(ELITES_CAP[realm_idx])
	var bosses_cap: int = int(BOSSES_CAP[realm_idx])
	points += mini(int(run_data.get("elites_killed", 0)), elites_cap)
	points += mini(int(run_data.get("bosses_killed", 0)), bosses_cap) * 2

	# 收集奖励
	var unique_cards: int = int(run_data.get("unique_cards_collected", 0))
	points += mini(int(unique_cards / 10), 5)

	# 炼制奖励
	var craft_total: int = int(run_data.get("alchemy_count", 0)) + int(run_data.get("forge_count", 0))
	points += mini(int(craft_total / 5), 5)

	# 超脱轮回加成
	if unlocked_talents.has("reincarnation_4"):
		points = int(round(float(points) * 1.2))

	# 死亡保底
	if str(run_data.get("result", "")) == "death":
		points = maxi(3, points)

	return points

## 轮回结算——计算轮回点 + 更新 ProgressionSystem + 返回结算摘要。
static func settle_run(run_data: Dictionary, realm_name: String) -> Dictionary:
	var ps: Node = _get_progression_system()
	var unlocked: Array = []
	if ps != null:
		unlocked = ps.get_talent_tree_state().get("unlocked", [])

	var points: int = calculate_reincarnation_points(run_data, unlocked)

	if ps != null:
		# 添加轮回点
		ps.add_talent_points(points)

		# 递增 total_reincarnations
		var current_reincarnations: int = int(ps.get_meta_value("total_reincarnations"))
		ps.set_meta_value("total_reincarnations", current_reincarnations + 1)

		# 通关时递增 total_completions + 设置 highest_realm_ever
		if str(run_data.get("result", "")) == "victory":
			var current_completions: int = int(ps.get_meta_value("total_completions"))
			ps.set_meta_value("total_completions", current_completions + 1)
			ps.set_meta_value("highest_realm_ever", realm_name)

	return {
		"points_earned": points,
		"realm_reached": int(run_data.get("realm_reached", 1)),
		"result": str(run_data.get("result", "")),
		"total_reincarnations": int(ps.get_meta_value("total_reincarnations")) if ps != null else 0,
	}
