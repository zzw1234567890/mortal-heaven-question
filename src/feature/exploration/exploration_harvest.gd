extends RefCounted
## ExplorationHarvest —— 采集节点（灵草 / 矿脉）的结算子模块。[br]
## [br][b]职责[/b]：把「到达采集节点拿到的材料载荷」变成一份[b]可采列表[/b]，
## 并执行采集——校验未采过 → 夹到背包上限 → 走 GSM 原子写入口入背包 →
## 记下「这个节点的这个槽位已采」。[br]
## [br][b]为什么在 Feature 层而不是 UI 里[/b]：写背包是玩法状态变更
## （control-manifest：UI 只发起请求、显示系统返回的文案，不碰 GSM）。
## 面板只调 [method entries_for] / [method harvest_at_node]，
## 并把返回的 [code]message[/code] 原样显示——中文提示只有一处措辞。[br]
## [br][b]复用的既有设施（不另开第二条通路）[/b]：[br]
##   · 背包写入口——[code]ResourceSystem.add_resource(&"ling_cai", 数量, 品质)[/code]
##     → GSM [code]_set_resource_ling_cai[/code]（ADR-0019 §关键接口）。
##     灵材四档品质（low/medium/high/top）就是既有背包，不新建「材料域」；[br]
##   · 已采状态——[code]gsm.update_exploration_map_state[/code] 写进
##     [code]exploration.map_states[map_id]["harvested"][/code]，
##     随探索域一起持久化（PERSISTABLE_DOMAINS 含 exploration）。[br]
## [br][b]为什么不走 [method ExplorationMapFlush.collect_resource][/b]：那条路只把数量
## 累积到 [code]collected_*[/code]，[b]要等 [code]end_exploration[/code] 才转进背包[/b]
## （GDD §公式 11 的结算节奏）。采集节点要求「采了就到手」，故直接走 ResourceSystem
## ——延迟入包会让「采集成功」的提示与实际背包不符。[br]
## [br][b]同节点同类只能采一次[/b]：已采槽位按 [code]node_id → [slot][/code] 记录，
## 重复采集返回 [code]false[/code] + 「此处已采集过」——幂等拒绝而非静默跳过，
## 与商店「售罄」同一口径（两份状态必然漂移，故状态只有 map_states 一份）。[br]
## [br][b]背包上限夹紧[/b]：[constant LING_CAI_CAP] 是单档灵材的背包容量。
## GDD resource-system.md §边界写作「灵材无硬上限，超过 99 时 UI 显示 99+」，
## 本轮把 99 定为[b]采集入库的容量[/b]（超额部分不入包并给出「背包已满」提示），
## 与实际数值在详情中可查的展示口径并存——设计歧义见类末「已知边界」。
##
## 来源: design/gdd/resource-system.md §资源表（灵材）/ §边界 / AC-19、
## design/gdd/exploration-system.md §节点类型一览、ADR-0019 §关键接口、
## 先例 [code]exploration_shop.gd[/code]（结算）/ [code]exploration_rest.gd[/code]（公式单一来源）。

## 材料载荷表（条目形态与按境界分层的唯一来源）。
const TableScript := preload("res://src/feature/exploration/exploration_harvest_table.gd")

## 节点详情里材料载荷的键（DAG 生成器写入 / 本模块读取的同一口径）。
const KEY_MATERIALS: String = "materials"

## 已采状态在 [code]map_states[map_id][/code] 下的键。
## [br]形态：[code]{node_id(int): [已采 slot(int), ...]}[/code]——整块写入，
## 因为 [code]update_exploration_map_state[/code] 在顶层键上做合并覆盖。
const KEY_HARVESTED: String = "harvested"

## 单档灵材的背包容量（见类文档「背包上限夹紧」）。
const LING_CAI_CAP: int = 99

## 采集成功提示（[code]%s[/code] 材料名、[code]%d[/code] 数量）。
const TEXT_HARVESTED: String = "采集：获得 %s ×%d"
## 重复采集提示（同节点同槽位只此一次）。
const TEXT_ALREADY: String = "此处已采集过"
## 背包已满提示（该品质档位已到上限）。
const TEXT_FULL: String = "背包已满，无法采集"
## 槽位越界提示。
const TEXT_NO_SLOT: String = "此处无可采集的材料"
## 空载荷提示（节点没有配置材料——不该出现，但要有可读形态）。
const TEXT_EMPTY: String = "此处灵脉枯竭，无物可采"

## 依赖注入（测试用桩；null 时按 Autoload 查找）。
var resource_system: Node = null

## 父节点引用——ExplorationSystem 实例（节点详情与 GSM 的入口）。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# ═══════════════════════════════════════════════════════════════════════════════
# 纯函数（不读不写任何状态，GUT 直调可测）
# ═══════════════════════════════════════════════════════════════════════════════

## 该品质档位的背包剩余容量（0 = 已满）。[br]
## [br][param p_current] 当前数量（负数按 0 参与，越界存档值不放大容量）。[br]
## [param p_cap] 容量上限（默认 [constant LING_CAI_CAP]）。
static func remaining(p_current: int, p_cap: int = LING_CAI_CAP) -> int:
	return maxi(p_cap - maxi(p_current, 0), 0)


## 可入库数量——本次想入的量与剩余容量取小。[br]
## [br][param p_current] 该品质档位当前数量。[br]
## [param p_amount] 本次想入库的数量（负数归零）。[br]
## [br][b]返回[/b]：实际可入库量（0 = 已满）。
static func room_for(p_current: int, p_amount: int,
		p_cap: int = LING_CAI_CAP) -> int:
	if p_amount <= 0:
		return 0
	return mini(remaining(p_current, p_cap), p_amount)


## 该节点的已采槽位表（无从记录时空数组）。
static func harvested_slots(p_state: Dictionary, p_node_id: int) -> Array:
	var all: Dictionary = p_state.get(KEY_HARVESTED, {})
	var slots: Variant = all.get(p_node_id, [])
	return (slots as Array).duplicate() if slots is Array else []


## 槽位是否已采（幂等判定的唯一实现——[method harvest_at_node] 与面板都用它）。
static func is_harvested(p_state: Dictionary, p_node_id: int, p_slot: int) -> bool:
	return harvested_slots(p_state, p_node_id).has(p_slot)


# ═══════════════════════════════════════════════════════════════════════════════
# 可采列表（面板的唯一数据源）
# ═══════════════════════════════════════════════════════════════════════════════

## 本节点可采列表。[br]
## [br][param p_node_id] 采集节点 ID。[br]
## [param p_state] 当前 [code]map_states[map_id][/code]（已采判定来源）。[br]
## [br][b]返回[/b]：条目数组，每条 [code]{slot, name, kind, kind_name, quality,
## quality_name, amount, harvested, room}[/code]——[code]room[/code] 为该品质档位的
## [b]背包剩余容量[/b]（0 = 已满，面板据此禁用该行；实际入库量由
## [method harvest_at_node] 取 [code]min(room, amount)[/code]）。[br]
## [br][b]只读[/b]：不写任何状态——面板每次现取（ADR-0031 §2）。[br]
## [br][b]载荷为空[/b]：返回空数组（面板显示「无物可采」而非空白面板）。
func entries_for(p_node_id: int, p_state: Dictionary) -> Array:
	var materials: Array = materials_at(p_node_id)
	var out: Array = []
	for raw: Variant in materials:
		var entry: Dictionary = raw
		var quality: int = int(entry.get(TableScript.KEY_QUALITY, 1))
		var slot: int = int(entry.get(TableScript.KEY_SLOT, -1))
		out.append({
			TableScript.KEY_SLOT: slot,
			TableScript.KEY_NAME: str(entry.get(TableScript.KEY_NAME, "")),
			TableScript.KEY_KIND: StringName(entry.get(TableScript.KEY_KIND,
					TableScript.KIND_HERB)),
			"kind_name": TableScript.kind_name(StringName(
					entry.get(TableScript.KEY_KIND, TableScript.KIND_HERB))),
			TableScript.KEY_QUALITY: quality,
			"quality_name": TableScript.quality_name(quality),
			TableScript.KEY_AMOUNT: int(entry.get(TableScript.KEY_AMOUNT, 0)),
			"harvested": is_harvested(p_state, p_node_id, slot),
			"room": remaining(_bag_count(quality)),
		})
	return out


## 本节点可采列表——[b]当前地图[/b]的已采状态由本方法自取（UI/系统调用的默认入口）。[br]
## [br][param p_node_id] 采集节点 ID。[br]
## [br][b]返回[/b]：同 [method entries_for]。
func entries_at(p_node_id: int) -> Array:
	return entries_for(p_node_id, _map_state())


## 本节点的材料载荷（规范化后；节点无载荷时空数组）。
func materials_at(p_node_id: int) -> Array:
	if _parent == null:
		return []
	var details: Dictionary = _parent.get("_node_details")
	if not (details is Dictionary):
		return []
	var detail: Dictionary = (details as Dictionary).get(p_node_id, {})
	if not (detail is Dictionary):
		return []
	return TableScript.normalize((detail as Dictionary).get(KEY_MATERIALS, []))


# ═══════════════════════════════════════════════════════════════════════════════
# 采集结算（读 → 校验 → 夹上限 → 入库 → 记状态）
# ═══════════════════════════════════════════════════════════════════════════════

## 采集一个槽位。[br]
## [br][param p_node_id] 采集节点 ID。[br]
## [param p_slot] 材料槽位（[code]ExplorationHarvestTable[/code] 的条目下标）。[br]
## [br][b]返回[/b]：[code]{success: bool, reason: String, message: String,
## gained: int, quality: int}[/code]——[code]message[/code] 为面向玩家的中文提示
## （面板原样显示，UI 不另写措辞）。[br]
## [br][b]拒绝路径全在写包之前[/b]：槽位越界 / 重复采集 / 背包已满 → 不改任何状态
## （与商店「拒绝路径在扣费之前」同一口径）。[br]
## [br][b]部分入库[/b]：剩余容量小于该槽位数量时只入可容量（[code]gained[/code]
## 为实际入库量），不静默丢弃——提示里的数量就是真实到手数量。[br]
## [br]来源: GDD resource-system.md §资源表 / §边界、ADR-0019 §关键接口。
func harvest_at_node(p_node_id: int, p_slot: int) -> Dictionary:
	var failure := func(p_reason: String, p_text: String) -> Dictionary:
		return {"success": false, "reason": p_reason, "message": p_text,
				"gained": 0, "quality": 0}

	var state: Dictionary = _map_state()
	var entries: Array = entries_for(p_node_id, state)
	var target: Dictionary = {}
	for raw: Variant in entries:
		if int((raw as Dictionary).get(TableScript.KEY_SLOT, -1)) == p_slot:
			target = raw
			break
	if target.is_empty():
		return failure.call("no_slot", TEXT_NO_SLOT)
	if bool(target.get("harvested", false)):
		return failure.call("already", TEXT_ALREADY)

	var quality: int = int(target.get(TableScript.KEY_QUALITY, 1))
	var amount: int = int(target.get(TableScript.KEY_AMOUNT, 0))
	var gain: int = room_for(_bag_count(quality), amount)
	if gain <= 0:
		return failure.call("bag_full", TEXT_FULL)

	var rs: Node = _resolve_resource_system()
	if rs == null or not rs.has_method(&"add_resource"):
		push_warning("ExplorationHarvest: ResourceSystem 不可用，采集未入库（node=%d）" % p_node_id)
		return failure.call("system_unavailable", TEXT_FULL)
	if not bool(rs.call(&"add_resource", &"ling_cai", gain, quality)):
		push_warning("ExplorationHarvest: 灵材入库被拒（quality=%d amount=%d）" % [quality, gain])
		return failure.call("write_rejected", TEXT_FULL)

	_mark_harvested(p_node_id, p_slot)
	return {
		"success": true,
		"reason": "",
		"message": TEXT_HARVESTED % [str(target.get(TableScript.KEY_NAME, "")), gain],
		"gained": gain,
		"quality": quality,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 内部（GSM / ResourceSystem 接入）
# ═══════════════════════════════════════════════════════════════════════════════

## 当前地图的 [code]map_states[/code] 条目（无活跃地图时返回空字典——判定退化为
## 「都没采过」，写入侧会拒绝并告警）。
func _map_state() -> Dictionary:
	var gsm: Node = _gsm()
	if gsm == null:
		return {}
	var current_map: StringName = gsm.exploration.get("current_map", &"")
	if current_map == &"" or str(current_map).is_empty():
		return {}
	var map_states: Dictionary = gsm.exploration.get("map_states", {})
	return map_states.get(current_map, {})


## 该品质档位的背包当前数量（ResourceSystem 缺失时按 0——不阻断采集判定，
## 真正写包时另有可用性守卫）。
func _bag_count(p_quality: int) -> int:
	var rs: Node = _resolve_resource_system()
	if rs == null or not rs.has_method(&"get_resource"):
		return 0
	return int(rs.call(&"get_resource", &"ling_cai", p_quality))


## 记下「这个节点的这个槽位已采」——整块写 [constant KEY_HARVESTED]，随探索域持久化。
func _mark_harvested(p_node_id: int, p_slot: int) -> void:
	var gsm: Node = _gsm()
	if gsm == null:
		return
	var current_map: StringName = gsm.exploration.get("current_map", &"")
	if current_map == &"" or str(current_map).is_empty():
		push_warning("ExplorationHarvest: 无活跃地图，已采状态未持久化（node=%d）" % p_node_id)
		return
	var state: Dictionary = _map_state()
	var all: Dictionary = (state.get(KEY_HARVESTED, {}) as Dictionary).duplicate(true)
	var slots: Array = (all.get(p_node_id, []) as Array).duplicate()
	if not slots.has(p_slot):
		slots.append(p_slot)
	all[p_node_id] = slots
	gsm.call(&"update_exploration_map_state", current_map, {KEY_HARVESTED: all})


## 资源系统——注入优先，其次 Autoload。
func _resolve_resource_system() -> Node:
	if resource_system != null and is_instance_valid(resource_system):
		return resource_system
	return _autoload(&"ResourceSystem")


## GSM 引用——经父节点（保持与其它子模块同一查找口径）。
func _gsm() -> Node:
	if _parent != null and _parent.has_method(&"_get_gsm"):
		return _parent.call(&"_get_gsm")
	return _autoload(&"GameStateManager")


## Autoload 动态查找（测试环境缺 Autoload 时返回 null）。
func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
