extends RefCounted
## ExplorationActionSpring —— 行动力泉（灵泉）节点的效果执行子模块。[br]
## [br][b]职责[/b]：把 GDD §节点类型一览「行动力泉——回复全部行动力」落到
## [code]GameStateManager.exploration.action_points[/code] 上，并执行「每图限次」。[br]
## [br][b]为什么要单独一处[/b]：与 [ExplorationRest] / [ExplorationEconomy] 同层——
## [code]ExplorationSystem[/code] 只做节点导航与委托分发，数值结算放进它会让
## 「地图怎么长」与「行动力怎么回」耦在一处；宿主只留一个转发方法。[br]
## [br][b]读写都走既有设施[/b]：[br]
##   · 读——GSM [code]exploration.action_points[/code] / [code]max_action_points[/code]；[br]
##   · 写——GSM 第二层原子方法 [code]set_exploration_ap[/code]（与
##     [code]move_to_node[/code] 的扣费写入口同一个，不另开第二条 AP 通路）；[br]
##   · 次数——GSM [code]update_exploration_map_state[/code] 写进
##     [code]exploration.map_states[map_id][/code] 的 [constant KEY_SPRING_USES]，
##     随探索域一起持久化（先例 [code]exploration_harvest.gd[/code] 的
##     [code]harvested[/code]——整块单键写入，因为那个方法是顶层键合并覆盖）。[br]
## [br][b]夹到上限[/b]：回复量 = [code]max(上限 - 当前, 0)[/code]——满行动力时回复 0，
## 绝不越过 [code]max_action_points[/code]。存档里越界的 [code]action_points[/code]
## （负数 / 大于上限）先按 [code][0, 上限][/code] 夹一次再算缺口，不放大也不倒扣。[br]
## [br][b]公式只有一个来源[/b]：[method restore_for] 是「回复量 = 上限 - 当前」的
## 唯一实现——UI 侧 [code]NodeInteractionRules.spring_restore_all[/code] 转发到这里，
## 两侧不会各算一套。[br]
## [br][b]返回实际回复量[/b]：写回不可用时返回 0（宁可提示「回复 0 点」也不虚报
## ——UI 展示的是系统返回值，不自行计算）。[br]
## [br][b]「每图限次」落在 map_states[/b]（GDD §节点表「每个地图限1次」+ §8 边界
## 「使用后该节点变为普通节点」）：次数是[b]按地图[/b]累计的，不是按节点——同一张图
## 重新生成时灵泉会落在别的节点 ID 上，只记节点 ID 等于换个位置就能再刷一次。
## 次数上限读地图配置的 [code]action_spring_count[/code]（GDD §调优参数
## 「行动力泉每图限次 1次（范围 1-2）」），缺键回退 [constant DEFAULT_MAP_LIMIT]。
## 生成侧（[code]exploration_dag_builder.gd[/code]）读的也是这份状态，用满后不再刷出
## 灵泉节点——否则玩家会走到一个注定回复 0 的节点上。[br]
## [br][b]次数只在真回复时累加[/b]：满行动力时不写状态（既有口径），也不占次数
## ——「用掉一次机会」与「白跑一趟」不是一回事。[br]
##
## 来源: design/gdd/exploration-system.md §节点类型一览 / §4 节点导航 / §8 边界、
## design/gdd/action-point-system.md §3 行动力回复 / §调优参数、
## design/gdd/exploration-ui-system.md §4 灵泉弹窗（AC-4）、
## 先例 [code]exploration_rest.gd[/code] / [code]exploration_harvest.gd[/code]。

## 每图使用次数上限的配置键（本模块是它的读取侧，生成侧读同一份）。
const KEY_SPRING_COUNT: String = "action_spring_count"

## 已用次数在 [code]map_states[map_id][/code] 下的键（整块写入，见类文档）。
const KEY_SPRING_USES: String = "action_spring_uses"

## 每图限次出厂值——GDD §调优参数「行动力泉每图限次 1次（范围 1-2）」。
const DEFAULT_MAP_LIMIT: int = 1

## 父节点引用——ExplorationSystem 实例（仅用于表明归属，查找走 SceneTree）。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# ═══════════════════════════════════════════════════════════════════════════════
# 公式（纯函数——不读不写任何状态，GUT 直调可测）
# ═══════════════════════════════════════════════════════════════════════════════

## 回复量——[code]max(上限 - 当前, 0)[/code]（夹到上限的算术形式）。[br]
## [b]单一来源[/b]：UI 的 [code]NodeInteractionRules.spring_restore_all[/code]
## 转发到本方法（交叉校验系统返回值时用同一份公式，不重复实现）。[br]
## [param p_current_ap] 当前行动力（≤0 视为已耗尽）。[br]
## [param p_max_ap] 行动力上限（≤0 视为无上限可回——不臆造）。
static func restore_for(p_current_ap: int, p_max_ap: int) -> int:
	if p_max_ap <= 0:
		return 0
	return maxi(p_max_ap - clampi(p_current_ap, 0, p_max_ap), 0)


## 本图的灵泉限次——地图配置 [constant KEY_SPRING_COUNT] 优先，缺键回退出厂值。[br]
## [br][b]负数按 0[/b]：外部配置写坏时「一次都不给」比「给到上限」安全
## （同 [code]ExplorationApRules[/code] 对负开销回落默认值的取向——不静默放大）。[br]
## [param p_config] 本图配置（可为空字典——缺键即出厂值）。[br]
## [br][b]返回[/b]：非负整数限次（0 = 本图不刷灵泉）。
static func limit_of(p_config: Dictionary) -> int:
	return maxi(int(p_config.get(KEY_SPRING_COUNT, DEFAULT_MAP_LIMIT)), 0)


## 本图已用掉的灵泉次数（[param p_state] 为该图的 [code]map_states[/code] 条目）。[br]
## 缺键 / 脏数据（负数）一律按 0——「没记录」不是「已用满」。
static func uses_of(p_state: Dictionary) -> int:
	return maxi(int(p_state.get(KEY_SPRING_USES, 0)), 0)


## 本图的灵泉是否已用尽。[br]
## [br][b]生成侧与结算侧共用这一个判据[/b]：生成侧据此不刷灵泉节点，结算侧据此拒绝
## 第二次回复——两处各判一遍必然出现「刷得出来但回不了」的死节点。[br]
## [param p_state] 该图的 [code]map_states[/code] 条目。[br]
## [param p_config] 该图的配置（限次来源）。[br]
## [br][b]返回[/b]：[code]true[/code] 表示本图灵泉已无余量。
static func is_exhausted(p_state: Dictionary, p_config: Dictionary) -> bool:
	var limit: int = limit_of(p_config)
	return limit <= 0 or uses_of(p_state) >= limit


# ═══════════════════════════════════════════════════════════════════════════════
# 结算（读 → 计划 → 写回 → 记次数）
# ═══════════════════════════════════════════════════════════════════════════════

## 行动力泉结算——行动力回复至上限，返回[b]实际写入[/b]的回复量。[br]
## [br][param p_node_id] 节点 ID（仅用于告警文案；次数按[b]地图[/b]记，见类文档）。[br]
## [br][b]返回[/b]：实际回复量（已满 / 本图用尽 / GSM 不可用 / 写回入口缺失时为 0）。[br]
## [br][b]满行动力不写状态[/b]：回复量为 0 时直接返回，不做无意义写回，也不占次数
## （避免污染变更记录）。
## [br][b]先写 AP、再记次数[/b]：反过来的顺序一旦写回失败，玩家就会白白少掉一次
## 本图机会（同 [code]inventory_pill_use.gd[/code]「失败不半完成」的取向）。
func use_action_spring(p_node_id: int) -> int:
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("ExplorationActionSpring: GSM 不可用，灵泉未结算（node=%d）" % p_node_id)
		return 0
	if not gsm.has_method(&"set_exploration_ap"):
		push_warning("ExplorationActionSpring: GSM 缺少 set_exploration_ap，灵泉未结算")
		return 0

	var state: Dictionary = _map_state(gsm)
	var config: Dictionary = _map_config()
	if is_exhausted(state, config):
		push_warning("ExplorationActionSpring: 本图灵泉已用尽（限 %d 次），未回复（node=%d）"
				% [limit_of(config), p_node_id])
		return 0

	var max_ap: int = int(gsm.exploration.get("max_action_points", 0))
	var current: int = int(gsm.exploration.get("action_points", 0))
	var restored: int = restore_for(current, max_ap)
	if restored <= 0:
		return 0

	var clamped: int = clampi(current, 0, maxi(max_ap, 0))
	gsm.call(&"set_exploration_ap", clamped + restored, max_ap)
	_mark_used(gsm, p_node_id, uses_of(state) + 1)
	return restored


# ═══════════════════════════════════════════════════════════════════════════════
# 内部（GSM 接入）
# ═══════════════════════════════════════════════════════════════════════════════

## 当前地图的 [code]map_states[/code] 条目（无活跃地图时空字典——判据退化为
## 「都没用过」，写入侧会拒绝并告警）。
func _map_state(p_gsm: Node) -> Dictionary:
	var current_map: StringName = p_gsm.exploration.get("current_map", &"")
	if current_map == &"" or str(current_map).is_empty():
		return {}
	var map_states: Dictionary = p_gsm.exploration.get("map_states", {})
	return map_states.get(current_map, {})


## 本图配置——[b]按存档里的当前地图 ID 重新解析[/b]，不依赖宿主的 [member _map_config]
## 快照。[br]
## [br][b]为什么不能只读宿主字段[/b]：那个字段由 [ExplorationDAGBuilder] 在[b]生成期[/b]
## 写入，而读档重建走的是 [code]ExplorationSystem.rebuild_dag_cache[/code]——它置空该字段
## （[code]map_states[/code] 只存 graph/nodes，没有配置这一项）。于是「读档后进图用一次
## 灵泉」会拿着空配置去问 [method limit_of]，回退出厂值 1：地图表里写着限 2 次的图，
## 读档后只给 1 次——失败形态是「静默变严」，玩家只会觉得这眼泉坏了。[br]
## [br][b]解析顺序[/b]：[br]
##   1. 有存档地图 ID 且宿主能给配置 → [code]_parent._get_map_config(map_id, realm)[/code]
##      （注入回调 [code]ExplorationMapCatalog.config_for[/code] → 难度档位兜底）——
##      这条路上「配置」与「生成期用的那份」同源（都是同一张探明表），故重解析不会
##      与本次进入的图打架；[br]
##   2. 没有地图 ID（未进入任何地图）或宿主给不出配置 → 回落到宿主快照
##      （直调 [code]generate_map[/code] 的单测路径——那时存档不记地图）；[br]
##   3. 两者都没有 → 空字典（限次退化为出厂值，不臆造地图设定）。[br]
## [br][b]境界从哪来[/b]：复用既有只读口径 [code]GSM.player.realm[/code]
## （与 [code]ExplorationMapFlush._get_player_realm[/code] 同源），不自行臆造。
func _map_config() -> Dictionary:
	var resolved: Dictionary = _resolved_config()
	return resolved if not resolved.is_empty() else _host_config()


## 按存档地图 ID 重解析配置——无地图 ID / 宿主无解析能力 / 解析为空时返回空字典。
func _resolved_config() -> Dictionary:
	if _parent == null or not _parent.has_method(&"_get_map_config"):
		return {}
	var gsm: Node = _get_gsm()
	if gsm == null:
		return {}
	var map_id: StringName = gsm.exploration.get("current_map", &"")
	if map_id == &"" or str(map_id).is_empty():
		return {}
	var resolved: Variant = _parent.call(&"_get_map_config", map_id, _player_realm(gsm))
	if not (resolved is Dictionary) or (resolved as Dictionary).is_empty():
		return {}
	return resolved


## 宿主 [code]_map_config[/code] 快照——[b]兜底[/b]路径（存档不记地图时的直调场景）。
func _host_config() -> Dictionary:
	if _parent == null:
		return {}
	var config: Variant = _parent.get("_map_config")
	return config if config is Dictionary else {}


## 玩家当前境界——[code]GSM.player.realm[/code]（只读；缺失回退 1，与进图口径一致）。
func _player_realm(p_gsm: Node) -> int:
	return maxi(int(p_gsm.get(&"player").get("realm", 1)), 1)


## 记下本图已用掉一次——整块单键写入，随探索域持久化。
## [br][b]无活跃地图时不写[/b]：单测与桩环境下 [code]current_map[/code] 为空是常态，
## 此时告警但不算失败（回复本身已经落盘）。
func _mark_used(p_gsm: Node, p_node_id: int, p_uses: int) -> void:
	if not p_gsm.has_method(&"update_exploration_map_state"):
		return
	var current_map: StringName = p_gsm.exploration.get("current_map", &"")
	if current_map == &"" or str(current_map).is_empty():
		push_warning("ExplorationActionSpring: 无活跃地图，灵泉使用次数未持久化（node=%d）" % p_node_id)
		return
	p_gsm.call(&"update_exploration_map_state", current_map, {KEY_SPRING_USES: p_uses})


## GSM 引用——经父节点的 [code]_get_gsm[/code]（查找口径单一）。
func _get_gsm() -> Node:
	if _parent == null:
		return null
	return _parent.call("_get_gsm")
