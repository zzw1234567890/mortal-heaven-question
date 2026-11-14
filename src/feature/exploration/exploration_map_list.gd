extends RefCounted
## ExplorationMapList —— 地图选择列表载荷的组装子模块（RefCounted）。[br]
## [br][b]职责[/b]：把「有哪些地图」（[code]ExplorationMapCatalog.MAPS[/code]，
## 即探明表）与「玩家玩到哪了」（GSM [code]exploration.map_states[/code] /
## [code]player.realm[/code] / [code]player.resources.ling_shi[/code]）合拢成
## [MapSelectScreen] 直接可渲染的条目数组。[br]
## [br][b]为什么单独一处[/b]：此前 [code]MapSelectScreen[/code] 拿不到真实载荷，
## 回退到 [code]map_data_stub.gd[/code] 的 8 条硬编码——地图清单、解锁门槛、重入
## 费用全是写死的，与探明表/境界系统/经济公式各说各话。本模块把「合拢」收进
## Feature 层，UI 只读渲染（ADR-0031 §2 零状态所有权）。[br]
## [br][b]为什么不硬编码[/b]：地图清单来自 [constant ExplorationMapCatalog.MAPS]
## 的键（新增地图只改探明表）；解锁门槛来自该表的 [code]unlock_realm[/code]；
## 重入费用来自 [ExplorationEconomy] 的既有公式（永久免费表 / 基价表 / 次数倍率
## 都在那里，本模块不重算一遍）。[br]
## [br][b]条目契约[/b]（[MapCard] / [MapSelectScreen] 消费，UI 零数值计算——
## [code]reentry_total[/code] 与 [code]can_reenter[/code] 都由本层算好）：[br]
##   · [code]map_id: StringName[/code] —— 规范写法的地图 ID；[br]
##   · [code]name: String[/code] —— 中文显示名；[br]
##   · [code]difficulty: int[/code] —— 1~4（低/中/高/极高，卡片 ⭐ 数）；[br]
##   · [code]realm_requirement: int[/code] —— 解锁所需境界（tooltip「需X境界」）；[br]
##   · [code]is_cleared: bool[/code] —— 是否已通关（GSM 的 [code]is_first_clear[/code]）；[br]
##   · [code]is_unlocked: bool[/code] —— 玩家境界是否达标；[br]
##   · [code]reentry_allowed: bool[/code] —— 是否允许重入（苍玄古战场为 false）；[br]
##   · [code]reentry_base / reentry_multiplier / reentry_total[/code] —— 费用明细
##     （基础价 / 次数倍率 / 实付总额）；[br]
##   · [code]can_reenter: bool[/code] —— 灵石是否够（预判，UI 仅据此灰显按钮）；[br]
##   · [code]is_permanent_free: bool[/code] —— 永久免费地图（重入 0 费）。[br]
## [br][b]缺省语义[/b]：GSM 不可用时按「玩家境界 1、灵石 0、全部未通关」组条目
## ——列表仍出全（不空白），只是解锁与重入态按最保守值给。[br]
##
## 来源: ADR-0014 §get_map_list 契约、GDD exploration-system.md §1/§8、
## design/gdd/exploration-ui-system.md §1、ADR-0031 §2。

## 地图配置目录（探明表——「有哪些地图」的唯一真理来源）。
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")

## GSM 不可用时的兜底玩家境界（炼气——最保守的解锁态）。
const FALLBACK_REALM: int = 1


## 父节点引用——ExplorationSystem 实例（取 GSM / 重入费用 / 永久免费表）。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 组装地图列表（探明表顺序 = 剧情顺序，卡片按此排列）。[br]
## [br][b]返回[/b]：[code]Array[/code]，逐条见类文档「条目契约」。
func build() -> Array:
	var gsm: Node = _gsm()
	var player_realm: int = FALLBACK_REALM
	var ling_shi: int = 0
	if gsm != null:
		player_realm = int(gsm.player.get("realm", FALLBACK_REALM))
		var resources: Variant = gsm.player.get("resources", {})
		if resources is Dictionary:
			ling_shi = int((resources as Dictionary).get("ling_shi", 0))

	var entries: Array = []
	for raw_id: Variant in CatalogScript.MAPS.keys():
		var map_id: StringName = StringName(str(raw_id))
		entries.append(_entry_for(map_id, player_realm, ling_shi, gsm))
	return entries


# ═══════════════════════════════════════════════════════════════════════════════
# 单条组装
# ═══════════════════════════════════════════════════════════════════════════════

## 组装单张地图的卡片条目（字段口径见类文档）。[br]
## [br][param p_map_id] 规范写法的地图 ID（调用方保证来自 [code]MAPS[/code] 的键）。[br]
## [param p_player_realm] 玩家当前境界（解锁判定的唯一依据）。[br]
## [param p_ling_shi] 当前灵石余额（[code]can_reenter[/code] 的预判依据）。[br]
## [param p_gsm] GSM 引用（可空——空时视作未通关）。
func _entry_for(p_map_id: StringName, p_player_realm: int, p_ling_shi: int,
		p_gsm: Node) -> Dictionary:
	var config: Dictionary = CatalogScript.MAPS.get(p_map_id, {})
	var unlock_realm: int = int(config.get("unlock_realm", FALLBACK_REALM))
	var cost: int = _reentry_total(p_map_id)
	return {
		"map_id": p_map_id,
		"name": str(config.get("name", str(p_map_id))),
		# 探明表的 difficulty 是 0 基枚举（0=LOW）；卡片要 1 基（⭐ 数）
		"difficulty": int(config.get("difficulty", 0)) + 1,
		"realm_requirement": unlock_realm,
		"is_cleared": _is_cleared(p_gsm, p_map_id),
		"is_unlocked": p_player_realm >= unlock_realm,
		"reentry_allowed": bool(config.get("reentry_allowed", true)),
		"reentry_base": _reentry_base(p_map_id),
		"reentry_multiplier": _reentry_multiplier(p_map_id),
		"reentry_total": cost,
		"can_reenter": p_ling_shi >= cost,
		"is_permanent_free": _is_permanent_free(p_map_id),
	}


## 重入总费用——委托 [code]ExplorationEconomy.calculate_reentry_cost[/code]
## （永久免费表 / 基价表 / 次数倍率都在那里，公式只在一处）。
func _reentry_total(p_map_id: StringName) -> int:
	if _parent == null:
		return 0
	return int(_parent.call("calculate_reentry_cost", p_map_id))


## 重入次数倍率——委托经济子模块（与费用同一公式来源）。[br]
## [br][b]返回[/b]：倍率（首次 1.0，此后 +0.5/次，上限 3.0）。
func _reentry_multiplier(p_map_id: StringName) -> float:
	if _parent == null:
		return 1.0
	return float(_parent.call("reentry_multiplier", p_map_id))


## 重入基础价——按地图难度查 [code]ExplorationSystem.REENTRY_BASE_COSTS[/code]。[br]
## [br][b]返回[/b]：基价（灵石）；永久免费地图也返回自己的档位基价（明细展示用，
## 实付由 [code]reentry_total[/code] 给 0）。
func _reentry_base(p_map_id: StringName) -> int:
	if _parent == null:
		return 0
	var bases: Variant = _parent.get("REENTRY_BASE_COSTS")
	if not (bases is Array) or (bases as Array).is_empty():
		return 0
	var map_config: Dictionary = CatalogScript.MAPS.get(p_map_id, {})
	var index: int = clampi(int(map_config.get("difficulty", 0)), 0,
			(bases as Array).size() - 1)
	return int((bases as Array)[index])


## 是否永久免费地图（每个境界一张——GDD §1 经济安全阀）。
func _is_permanent_free(p_map_id: StringName) -> bool:
	if _parent == null:
		return false
	var free_maps: Variant = _parent.get("PERMANENT_FREE_MAPS")
	return free_maps is Dictionary and (free_maps as Dictionary).has(p_map_id)


# ═══════════════════════════════════════════════════════════════════════════════
# GSM 读取（只读——本模块不写任何状态）
# ═══════════════════════════════════════════════════════════════════════════════

## 地图是否已通关——读 [code]map_states[map_id].is_first_clear[/code]
## （与 [code]ExplorationMapFlush._is_map_cleared[/code] 同一字段）。
static func _is_cleared(p_gsm: Node, p_map_id: StringName) -> bool:
	return bool(_map_state(p_gsm, p_map_id).get("is_first_clear", false))


## 地图状态子字典（GSM 缺失 / 无该图记录 → 空字典）。
static func _map_state(p_gsm: Node, p_map_id: StringName) -> Dictionary:
	if p_gsm == null:
		return {}
	var states: Variant = p_gsm.exploration.get("map_states", {})
	if not (states is Dictionary):
		return {}
	var state: Variant = (states as Dictionary).get(p_map_id, {})
	return state if state is Dictionary else {}


## GSM 引用——经父节点的 [code]_get_gsm[/code]（查找口径单一）。
func _gsm() -> Node:
	if _parent == null:
		return null
	return _parent.call("_get_gsm")
