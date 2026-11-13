extends RefCounted
## ExplorationRest —— 回复点（歇脚处）的效果执行子模块。[br]
## [br][b]职责[/b]：把 GDD §公式 7「队伍回复已损失 HP 总量的 50%」落到
## [code]GameStateManager.player.character_hp[/code] 上。[br]
## [br][b]为什么要单独一处[/b]：[code]ExplorationSystem[/code] 只做节点导航与委托
## 分发，数值结算放进它会让「地图怎么长」与「血怎么回」耦在一处；本模块与
## [ExplorationEconomy] / [ExplorationMapFlush] 同层，宿主只留一个转发方法。[br]
## [br][b]读写都走既有设施（不另开第二条 HP 通路）[/b]：[br]
##   · 读——[CombatHpCarryover.read_all]（该模块自述为 [code]player.character_hp[/code]
##     的唯一读侧）；[br]
##   · 写——[CombatHpCarryover.write_back]（经 GSM 第二层原子方法
##     [code]_set_player_character_hp[/code]，带同值去重；GSM 缺入口时返回 -1）。[br]
## [br][b]公式只有一个来源[/b]：[method heal_for] 是「回复量 = floor(已损失 × 0.5)」
## 的唯一实现——UI 侧 [code]NodeInteractionRules.rest_heal_amount[/code] 转发到这里，
## 两侧不会各算一套。[br]
## [br][b]阵亡角色不参与[/b]：[code]current_hp == 0[/code] 的角色既不计入已损失总量，
## 也不会被「回复」复活（GDD 公式 7「仅在角色存活时计算；阵亡角色不计入」——
## 复活是 [code]DeploymentSystem.revive_character[/code] 的职责）。[br]
## [br][b]夹到上限[/b]：分配后每名角色的 HP 不超过其 [code]max_hp[/code]；存档里
## 越界的 [code]current_hp[/code]（大于 max_hp）按上限参与计算，不放大缺口。[br]
## [br][b]返回实际回复量[/b]：写回不可用时返回 0（宁可提示「回复 0 点」也不虚报
## ——UI 展示的是系统返回值，不自行计算）。[br]
##
## 来源: design/gdd/exploration-system.md §公式 7 / §8 边界用例、
## design/gdd/exploration-ui-system.md §4c（回复点确认走系统 API）、
## 先例 [code]exploration_economy.gd[/code] / [code]exploration_map_flush.gd[/code]。

## 跨战斗 HP 持久化的读写口（读 [code]read_all[/code] / 写 [code]write_back[/code]）。
const CarryoverScript := preload("res://src/feature/combat/combat_hp_carryover.gd")

## 回复比例——GDD §公式 7：50% 已损失 HP。
const HEAL_RATIO: float = 0.5

## 父节点引用——ExplorationSystem 实例（仅用于表明归属，查找走 SceneTree）。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# ═══════════════════════════════════════════════════════════════════════════════
# 公式与计划（纯函数——不读不写任何状态，GUT 直调可测）
# ═══════════════════════════════════════════════════════════════════════════════

## 回复量——GDD §公式 7：[code]floor(lost_hp_total × 0.5)[/code]。[br]
## [b]单一来源[/b]：UI 的 [code]NodeInteractionRules.rest_heal_amount[/code] 转发到
## 本方法（交叉校验系统返回值时用同一份公式，不重复实现）。[br]
## [param p_lost_total] 已损失 HP 总量（仅存活角色；≤0 视为无缺口）。
static func heal_for(p_lost_total: int) -> int:
	if p_lost_total <= 0:
		return 0
	return int(floor(float(p_lost_total) * HEAL_RATIO))


## 回复计划（纯函数）。[br]
## [br][b]输入[/b]：HP 表 [code]{character_id(int|String): {current_hp, max_hp}}[/code]
## （[CombatHpCarryover.read_all] 的产出形态）。[br]
## [br][b]为什么先算总量再逐个分配[/b]：GDD 公式的回复量是「总量的一半」——若逐
## 角色各算 [code]floor(lost_i × 0.5)[/code]，多个角色的向下取整会各掉一点，
## 实际回复量与 UI 交叉校验用的 [method heal_for] 对不上。本实现按角色 ID 升序
## 依次取 [code]min(该角色缺口, 剩余额度)[/code]，总额度恰好用尽（额度 ≤ 总缺口），
## 因此 [code]total_heal == heal_for(total_lost)[/code] 恒成立。[br]
## [br][b]返回[/b]：[code]{total_lost: int, total_heal: int, plan: {int: int}}[/code]
## ——[code]plan[/code] 为 [code]{角色 ID: 回复量}[/code]（满血/阵亡角色不出现）。
static func plan(p_hp_table: Dictionary) -> Dictionary:
	var entries: Array = []
	var lost_total: int = 0
	for key: Variant in p_hp_table.keys():
		var character_id: int = _id_of(key)
		if character_id < 0:
			continue
		var entry: Variant = p_hp_table[key]
		if not (entry is Dictionary):
			continue
		var hp: Dictionary = entry
		var max_hp: int = maxi(int(hp.get("max_hp", 0)), 0)
		# 越界存档值按上限参与（不放大缺口），负数归零
		var current_hp: int = clampi(int(hp.get("current_hp", 0)), 0, max_hp)
		if current_hp <= 0:
			continue  # 阵亡不计入（GDD 公式 7）
		var lost: int = max_hp - current_hp
		if lost <= 0:
			continue  # 满血无缺口
		entries.append({
			"character_id": character_id,
			"current_hp": current_hp,
			"max_hp": max_hp,
			"lost": lost,
		})
		lost_total += lost

	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["character_id"]) < int(b["character_id"]))

	var budget: int = heal_for(lost_total)
	var allocation: Dictionary = {}
	var healed: int = 0
	for raw: Variant in entries:
		if budget <= 0:
			break
		var item: Dictionary = raw
		var delta: int = mini(int(item["lost"]), budget)
		if delta <= 0:
			continue
		allocation[int(item["character_id"])] = delta
		budget -= delta
		healed += delta

	return {"total_lost": lost_total, "total_heal": healed, "plan": allocation}


# ═══════════════════════════════════════════════════════════════════════════════
# 结算（读 → 计划 → 写回）
# ═══════════════════════════════════════════════════════════════════════════════

## 回复点结算——全队回复 50% 已损失 HP，返回[b]实际写入[/b]的回复总量。[br]
## [br][param p_node_id] 节点 ID（本模块不使用；由调用方在「到达回复点」后触发，
## 保留形参以对齐探索系统的节点 API 口径）。[br]
## [br][b]返回[/b]：实际回复总量（无缺口 / GSM 不可用 / 写回入口缺失时为 0）。
func rest_at_node(p_node_id: int) -> int:
	var carryover: RefCounted = CarryoverScript.new(_parent)
	var table: Dictionary = carryover.call(&"read_all")
	var planned: Dictionary = plan(table)
	var allocation: Dictionary = planned.get("plan", {})
	if allocation.is_empty():
		return 0  # 全队满血或无人登记 HP——无缺口，无提示（不写任何状态）

	var entries: Array = []
	for raw_id: Variant in allocation.keys():
		var character_id: int = int(raw_id)
		var before: Dictionary = table.get(character_id, {})
		var max_hp: int = maxi(int(before.get("max_hp", 0)), 0)
		var current: int = clampi(int(before.get("current_hp", 0)), 0, max_hp)
		entries.append({
			"side": CarryoverScript.SIDE_PLAYER,
			"known": true,
			"character_id": character_id,
			# 分配额度 ≤ 该角色缺口（plan 保证），故此处不会超过 max_hp
			"current_hp": current + int(allocation[raw_id]),
			"max_hp": max_hp,
		})
	var written: int = int(carryover.call(&"write_back", entries))
	if written < 0:
		push_warning("ExplorationRest: HP 回写入口缺失，回复点未结算（node=%d）" % p_node_id)
		return 0
	return int(planned.get("total_heal", 0))


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 存储键 → 角色 ID（兼容整数键与数字字符串键；非数字键返回 -1）。
static func _id_of(key: Variant) -> int:
	if key is int:
		return key if key >= 0 else -1
	var text: String = str(key).strip_edges()
	if not text.is_valid_int():
		return -1
	var parsed: int = text.to_int()
	return parsed if parsed >= 0 else -1
