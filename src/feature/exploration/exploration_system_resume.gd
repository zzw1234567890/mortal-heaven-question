extends RefCounted
## ExplorationSystemResume —— 「读档续玩」的地图缓存重建与快照重播子模块。[br]
## [br][b]为什么必须有它[/b]：读档发生在探索系统 [code]_ready()[/code] [b]之后[/b]
## ——Autoload 启动时 GSM 还是一份空档，[code]current_map[/code] 为空，缓存自然
## 没有可建的东西；玩家点「继续游戏」的那一刻起，系统手上是一份[b]过期缓存[/b]。
## 而进图的既有唯一入口 [code]enter_map[/code] 会[b]重新生成[/b]一张图
## （新 seed、visited 重置为入口、行动力回满）——直接拿它当「续玩」用，玩家的
## 进度会被悄悄抹掉：明明站在第三层、行动力只剩 2，进图后回到入口、行动力 10。[br]
## [br][b]职责[/b]：从存档快照（[code]map_states[map_id].graph/nodes[/code]，
## [code]enter_map[/code] 每次都写入）重建 DAG 缓存，再按 GSM 的[b]现读[/b]导航状态
## 广播 [signal ExplorationSystem.map_generated]——渲染侧收到的快照与存档一致。[br]
## [br][b]为什么不重新生成地图[/b]：程序化地图的 seed 来自进入次数，重生成必然
## 得到一张不同的 DAG；玩家存档里的路径、已采槽位、已弹事件都挂在旧节点 ID 上，
## 换了图等于全部作废。[br]
## [br][b]与 [code]_ready()[/code] 的关系[/b]：[method cache_from_storage] 就是
## 启动时那段「current_map 非空 → 从 map_states 重建」的逻辑，抽出来两处共用
## （启动重建 / 读档续玩）——否则同一件事写两遍，改一处必漂。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型（读档重建）、§决策 5 探索结束结算、
## GDD exploration-system.md §1/§8、design/gdd/save-load-system.md。
##
## 持有对 ExplorationSystem 父节点的引用（同 [ExplorationMapFlush] 形态）。

## 状态快照里参与重建的四个可选键（缺省值与原 [code]_ready()[/code] 逐字一致）。
## 纯文档用途——实际读取就近写在 [method cache_from_storage] 里，免得路径表与代码两处漂移。

## 指向 ExplorationSystem 父节点的引用。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 从存档快照重建某张图的 DAG 缓存——[b]不生成新图[/b]、不发信号。[br]
## [br][b]返回[/b]：重建用的 [code]map_data[/code]（含 graph/nodes/layers/
## boss_node_id/path_count）；拿不到快照时返回空字典（调用方据此判别「这张图没得
## 续玩」）。[br]
## [br][b]只碰内部缓存[/b]：GSM 一个字段都不写——读档续玩不该改变存档内容
## （ADR-0031 §2 同类取向：读操作不产生状态）。[br]
func cache_from_storage(p_map_id: StringName) -> Dictionary:
	if p_map_id == &"" or str(p_map_id).is_empty():
		return {}
	var gsm: Node = _get_gsm()
	if gsm == null:
		return {}
	var map_states: Dictionary = gsm.exploration.get("map_states", {})
	var state: Dictionary = map_states.get(p_map_id, {})
	if not (state.has("graph") and state.has("nodes")):
		return {}
	var map_data: Dictionary = {
		"graph": state["graph"],
		"nodes": state["nodes"],
		"layers": state.get("layers", []),
		"boss_node_id": state.get("boss_node_id", 0),
		"path_count": state.get("path_count", 0),
	}
	_parent.call(&"rebuild_dag_cache", p_map_id, map_data)
	return map_data


## 读档续玩入口——重建缓存 + 恢复地图配置 + 按 GSM 现读状态广播快照。[br]
## [br][b]顺序不可换[/b]：必须先重建缓存再广播——[code]map_generated[/code] 的
## 监听方（节点图）在回调里就会去查系统的可达性判定（[code]can_move_to_detail[/code]），
## 缓存没就位的话它拿到的是空图，六态会全画成「不可达」。[br]
## [br][b]为什么要补 [code]_map_config[/code][/b]：[method rebuild_dag_cache] 会把它
## 清空（生成期才填），清空后 [code]ap_cost_to[/code] 退回 GDD 默认开销 1——本图若把
## [code]ap_cost[/code] 配成 2，玩家读档后看到的可达性会与实际扣费不符。启动重建
## 路径没这个问题（那时还没有 UI 在画），续玩路径有。[br]
## [br][b]返回[/b]：广播出去的那份快照（空字典 = 没有可续玩的图，调用方停在选图界面）。[br]
func resume_map(p_map_id: StringName) -> Dictionary:
	var map_data: Dictionary = cache_from_storage(p_map_id)
	if map_data.is_empty():
		push_warning("ExplorationSystem.resume_map: %s 无存档快照，无法续玩" % p_map_id)
		return {}
	_restore_map_config(p_map_id)

	var gsm: Node = _get_gsm()
	map_data["map_id"] = p_map_id
	map_data["visited"] = _visited_of(gsm)
	map_data["current_node"] = _current_node_of(gsm)
	map_data["ap_remaining"] = _ap_of(gsm)

	_parent.call(&"_emit_safe", &"map_generated", [p_map_id, map_data])
	return map_data


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 恢复本图的地图配置快照（[code]_map_config[/code]）——配置缺失时保留清空态
## （[code]ap_cost_to[/code] 退回默认开销 1，与拆分前的读档行为一致）。
func _restore_map_config(p_map_id: StringName) -> void:
	var config: Variant = _parent.call(&"_get_map_config", p_map_id, _player_realm())
	if config is Dictionary and not (config as Dictionary).is_empty():
		_parent.set(&"_map_config", (config as Dictionary).duplicate(true))


## 玩家境界——GSM 只读；缺失时回退 1（新档炼气，与 [code]NodeGraphLoadSource[/code] 同口径）。[br]
## [b]不臆造[/b]：境界只影响配置兜底，读不到就按最低境界取配置，比传一个猜的数字安全。
func _player_realm() -> int:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return 1
	return maxi(int(gsm.player.get("realm", 1)), 1)


## 已访问节点——深拷贝（快照不与 GSM 共享引用：UI 侧 [method NodeGraphScreen._on_node_moved]
## 会就地把 visited 追加进快照，共享引用会让 GSM 的存档态被 UI 悄悄改写）。
func _visited_of(p_gsm: Node) -> Array:
	if p_gsm == null:
		return []
	return (p_gsm.exploration.get("visited_nodes", []) as Array).duplicate()


## 当前所在节点 ID——从 GSM 的层/位按既有编码 [code]layer * 100 + idx[/code] 反解。[br]
## 与 [code]ExplorationSystemForward._current_node_id[/code] 同一编码；越界存档值
## （负数）夹到入口（同 [code]move_to_node[/code] 对负 AP 先夹到 0 的取向）。
func _current_node_of(p_gsm: Node) -> int:
	if p_gsm == null:
		return 0
	var pos: Dictionary = p_gsm.exploration.get("node_position", {})
	var layer: int = maxi(int(pos.get("layer", 0)), 0)
	var idx: int = maxi(int(pos.get("idx", 0)), 0)
	return layer * 100 + idx


## 剩余行动力——负数夹到 0（越界存档值不进快照，否则 UI 会画出负的行动力）。
func _ap_of(p_gsm: Node) -> int:
	if p_gsm == null:
		return 0
	return maxi(int(p_gsm.exploration.get("action_points", 0)), 0)


## GSM——经父节点取（父节点已有注入点，测试可替换）。
func _get_gsm() -> Node:
	if _parent == null:
		return null
	return _parent.call(&"_get_gsm")
