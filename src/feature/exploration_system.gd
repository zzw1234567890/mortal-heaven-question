extends "res://src/feature/exploration/exploration_system_forward.gd"
## ExplorationSystem —— 探索系统 Autoload（ADR-0014 #19）——[b]编排面[/b]。[br]
## [br]Feature 层 Autoload。程序化 DAG 地图生成 + 节点导航 + 子系统委托调度。[br]
## DAG 生成算法委托给 [ExplorationDAGBuilder]（RefCounted 子模块），[br]
## 经济计算委托给 [ExplorationEconomy]（RefCounted 子模块）。[br]
## [br][b]已注册进 project.godot[/b]——Autoload #19（ExplorationSystem）。[br]
## [br][b]本文件的职责[/b]：地图生成与进入（[method generate_map] /
## [method enter_map]）、节点导航（[method move_to_node]）、节点交互分发
## （[method resolve_node]）、Autoload 生命周期钩子（[method _ready]）——
## 也就是「编排」这一件事。[br]
## [br][b]继承链[/b]（`exploration_system.gd` 686 行 → 四段各守 300 行内，
## 成员名与访问路径逐字不变——机械拆分、行为零改动）：[br]
##   1. [code]exploration_system_base.gd[/code]——枚举 / 常量 / 状态 / 注入点 /
##      子模块句柄 / 通用助手；[br]
##   2. [code]exploration_system_ops.gd[/code]——Cat 2b 信号表 / 只读查询 /
##      DAG 缓存生命周期 / 统一标记入口 / 测试桩；[br]
##   3. [code]exploration_system_forward.gd[/code]——子模块转发（经济 / 结算刷新 /
##      回复点 / 灵泉）；[br]
##   4. 本文件——编排面（也是 project.godot 注册的那份脚本）。[br]
## [br][b]为什么钩子在这一层[/b]：Godot 只调最派生类的 [code]_ready[/code]
## （实测父类的不会自动链式执行），故生命周期钩子统一放链尾，只此一份。[br]
## [br]来源: ADR-0014 §决策 2 程序化 DAG 生成 / GDD exploration-system.md §2-3。[br]
## [br]Sprint 8 Story 8-9：DAG 生成 + 经济计算拆分到子模块。


# ═══════════════════════════════════════════════════════════════════════════════
# DAG 生成（委托给 ExplorationDAGBuilder）
# ═══════════════════════════════════════════════════════════════════════════════

## 程序化生成 DAG 地图——委托给 _dag_builder 子模块。[br]
## [br][param map_id] 地图 ID。[br]
## [br][param player_realm] 玩家境界等级。[br]
## [br][param entry_count] 本局该地图进入次数。[br]
## [br][b]返回[/b]: [code]{graph, nodes, layers, boss_node_id, path_count}[/code] Dictionary。
func generate_map(map_id: StringName, player_realm: int = 1, entry_count: int = 1) -> Dictionary:
	return _get_dag_builder().generate_map(map_id, player_realm, entry_count)


# ═══════════════════════════════════════════════════════════════════════════════
# 节点导航与交互分发
# ═══════════════════════════════════════════════════════════════════════════════

## 节点导航——从 from_node 移动到 to_node。[br]
## [br][b]验证链路[/b]（短路求值）：DAG 就绪 → 目标存在 → GSM 可用 → 行动力。[br]
## [br][b]★ 本轮起「任一节点 → 任一节点」都可达 ★[/b]（老板 2026-11-27 18:40：
## 「每个节点之间都可达，只是消耗的行动力不一样」）：[br]
## [br]   · [b]取消邻接门槛[/b]——不再要求「从当前节点沿边一步」。DAG 的边表仍在
##     （节点生成、Boss 最短路、旧存档的图快照都靠它），但它[b]不再决定可达性[/b]；
##     判定只剩一条：AP 够不够这一次的消耗。[br]
##   · [b]取消已访问拒绝[/b]——已访问节点仍可重复进入，消耗照算。奖励不重复发由
##     各子系统的既有幂等逻辑负责（[method mark_node_visited] 返回 [code]is_new[/code]，
##     采集点/事件等的「已领过」判定各自持有），本方法不再额外挡一道。[br]
##   · [b]距离定价[/b]：[code]cost = clamp(round(distance / UNIT), 1, MAX)[/code]
##     ——距离由 [code]exploration_node_geometry.gd[/code] 算（与 UI 画出来的位置
##     同源），UNIT/MAX 是 [code]exploration_ap_rules.gd[/code] 里的可配常量。[br]
## [br][b]拒绝不扣费[/b]：AP 不足时直接返回，[b]不写任何导航状态[/b]——
## reason 为「行动力不足」，UI 据此给中文提示（不静默失败）。[br]
## [br][b]成功后[/b]：更新 GSM 导航状态 → 消耗 AP → 发射 node_moved → 调用 resolve_node。[br]
## [br][param from_node] 起始节点 ID（只用于算距离；它是不是「当前节点」不影响判定）。[br]
## [br][param to_node] 目标节点 ID。[br]
## [br][b]返回[/b]: [code]{success: bool, reason: String, ap_remaining: int}[/code] Dictionary。[br]
## [br]来源: ADR-0014 §关键接口 + GDD §4 节点导航、GDD action-point-system.md §公式 3、
## 本轮任务书追加规则（全连通 + 距离定价 + 已访问可重入）。
func move_to_node(from_node: int, to_node: int) -> Dictionary:
	var result: Dictionary = {"success": false, "reason": "", "ap_remaining": 0}

	# _dag_ready 守卫（ADR-0014 R7）
	if not _dag_ready:
		result["reason"] = REASON_NOT_READY
		return result

	# 验证 1：目标存在——本图确实有这一格（拓扑门槛废除后唯一的「不可达」）
	if not _node_exists(to_node):
		result["reason"] = REASON_UNREACHABLE
		return result

	# 验证 2：GSM 可用（导航状态与行动力都从它读写）
	var gsm: Node = _get_gsm()
	if gsm == null:
		result["reason"] = REASON_NO_GSM
		return result

	# 验证 3：行动力——按两节点距离算开销，不足时拒绝（不写任何状态、不扣费）
	# 越界存档值（负数）先夹到 0：豁免节点仍可移入，且 AP 永不落负。
	var ap: int = maxi(int(gsm.exploration.get("action_points", 0)), 0)
	var ap_cost: int = ap_cost_between(from_node, to_node)
	if ap < ap_cost:
		result["reason"] = REASON_AP_SHORT
		return result

	# 验证通过——执行移动（AP 永不落负：越界存档值先夹到 0 再扣）
	var new_ap: int = maxi(ap - ap_cost, 0)

	# 更新 GSM 导航状态（通过第二层方法——ADR-0014 §GSM 写入契约）
	var to_layer: int = to_node / 100
	var to_idx: int = to_node % 100
	gsm.set_exploration_position(to_layer, to_idx)
	mark_node_visited(to_node)
	gsm.set_exploration_ap(new_ap, int(gsm.exploration.get("max_action_points", 0)))

	result["success"] = true
	result["ap_remaining"] = new_ap

	# 发射 node_moved Cat 2b 信号
	_emit_safe(&"node_moved", [from_node, to_node, new_ap])

	# 自动调用 resolve_node 触发节点交互
	resolve_node(to_node)

	return result


## 节点交互分发——按节点类型发射 Cat 2b 委托信号。[br]
## [br][param node_id] 节点 ID。[br]
## [br][b]分发规则[/b]（ADR-0014 §决策 3）:[br]
## [br]EVENT → event_node_reached(map_pool, player_realm)[br]
## [br]COMBAT/ELITE → combat_node_reached(enemy_roster, combat_type)[br]
## [br]BOSS → boss_node_reached(boss_data)[br]
## [br]SHOP/REST/ACTION_SPRING/TELEPORT/TRIBULATION → node_interaction_triggered(node_id, type, payload)[br]
## [br][b]TELEPORT 载荷[/b]：多带一个 [code]targets[/code] 键（可跳转层列表，见
## [method ExplorationTeleport.targets_from]）——传送节点不出弹窗（B5 裁决），
## 但它需要一份「能跳到哪」的数据，随本次到达一次性下发比 UI 再查一次更省事。[br]
## [br]来源: ADR-0014 §决策 3 信号驱动子系统委托。
func resolve_node(node_id: int) -> void:
	# _dag_ready 守卫（ADR-0014 R7）
	if not _dag_ready:
		push_warning("ExplorationSystem.resolve_node: DAG 缓存未就绪，跳过节点交互")
		return
	var ntype: int = _get_node_type(node_id)
	var detail: Dictionary = _node_details.get(node_id, {})
	var gsm: Node = _get_gsm()
	var player_realm: int = 1
	if gsm != null:
		player_realm = int(gsm.player.get("realm", 1))

	match ntype:
		NodeType.EVENT:
			var map_pool: Array = detail.get("event_pool", [])
			_emit_safe(&"event_node_reached", [map_pool, player_realm])
		NodeType.COMBAT:
			var roster: Array = detail.get("enemy_roster", [])
			_emit_safe(&"combat_node_reached", [roster, &"combat"])
		NodeType.ELITE:
			var roster_elite: Array = detail.get("enemy_roster", [])
			_emit_safe(&"combat_node_reached", [roster_elite, &"elite"])
		NodeType.BOSS:
			var boss_data: Dictionary = {"node_id": node_id, "enemy_roster": detail.get("enemy_roster", [])}
			_emit_safe(&"boss_node_reached", [boss_data])
		NodeType.SHOP:
			var payload: Dictionary = {"inventory": detail.get("inventory", {})}
			_emit_safe(&"node_interaction_triggered", [node_id, &"shop", payload])
		NodeType.REST:
			_emit_safe(&"node_interaction_triggered", [node_id, &"rest", {}])
		NodeType.HARVEST:
			# 可采列表随载荷下发——已采状态由系统按当前地图的 map_states 判定，
			# UI 不必再调一次查询同一件事（同 TELEPORT 的 targets 口径）。
			var entries: Array = _get_harvest().call(&"entries_at", node_id)
			_emit_safe(&"node_interaction_triggered",
					[node_id, &"harvest", {"entries": entries}])
		NodeType.ALCHEMY, NodeType.FORGE:
			# 炼丹台/炼器台——载荷带可炼清单（同采集点口径：到达即上架，
			# 面板不必再查一次）。清单由配方资源现算，不进 DAG 快照。
			var kind: StringName = &"forge" if ntype == NodeType.FORGE else &"alchemy"
			_emit_safe(&"node_interaction_triggered",
					[node_id, kind, {"entries": _get_craft().call(&"entries", kind)}])
		NodeType.ACTION_SPRING:
			_emit_safe(&"node_interaction_triggered", [node_id, &"action_spring", {}])
		NodeType.TELEPORT:
			# 可跳转层列表随载荷下发——UI 不必再调系统查询同一件事
			# （GDD §8 边界：目标层均未解锁时列表为空 = 传送节点不可激活）。
			var targets: Array = _get_teleport().call(&"targets_from", node_id)
			_emit_safe(&"node_interaction_triggered",
					[node_id, &"teleport", {"targets": targets}])
		NodeType.TRIBULATION:
			_emit_safe(&"node_interaction_triggered", [node_id, &"tribulation", {}])
		NodeType.MEDITATION:
			# 打坐/洞府——载荷带当前突破状态（能否突破 / 所需修为 / 成功率 /
			# 失败代价），由境界配置表现算；面板不必再查一次同一件事
			# （同采集点/传送的载荷口径）。
			_emit_safe(&"node_interaction_triggered",
					[node_id, &"meditation",
					{"status": _get_breakthrough().call(&"status")}])
		NodeType.ENTRY:
			pass  # 入口无交互


# ═══════════════════════════════════════════════════════════════════════════════
# 进入地图（导航状态 GSM 主存储——Story 002）
# ═══════════════════════════════════════════════════════════════════════════════

## 进入地图——生成 DAG + 初始化 GSM exploration.* 导航状态 + 广播 map_generated。[br]
## [br][param map_id] 地图 ID。[br]
## [br][param player_realm] 玩家境界等级。[br]
## [br][param max_ap] 行动力上限（由 RealmSystem 查询，此处由调用方传入）。[br]
## [br][b]流程[/b]：generate_map → set_exploration_map → reset_exploration_visited
## → set_exploration_ap → update_exploration_map_state(entry_count++) →
## 发射 [signal map_generated]。[br]
## [br][b]已访问重置[/b]：进入地图即把入口节点记为已访问（GDD §4「入口 + 已访问
## 节点 → 绿色」），并[b]清掉上一张图残留的 visited[/b]——[method
## GameStateManager.set_exploration_map] 只重置位置、不重置已访问；不重置会让
## 节点图把上一张图的路径画成本图的绿色路径。[br]
## [br][b]信号载荷[/b]：渲染键取 GSM 写入后的实际值（[code]visited[/code] /
## [code]current_node[/code] / [code]ap_remaining[/code]）——UI 不必再自行推断，
## 也不会出现「信号说 AP=10、GSM 里是 5」的口径分裂。[br]
## [br][b]返回[/b]: generate_map 返回的图结构 Dictionary（附加 map_id / visited /
## current_node / ap_remaining 四个渲染键）。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型 + §决策 3 信号表 + §GSM 写入契约。
func enter_map(map_id: StringName, player_realm: int = 1, max_ap: int = 10) -> Dictionary:
	var map_data: Dictionary = generate_map(map_id, player_realm, _get_entry_count(map_id))

	# generate_map 已填充 _node_graph / _node_details / _map_config——缓存就绪
	_dag_ready = true

	var visited: Array = [ENTRY_NODE_ID]
	var gsm: Node = _get_gsm()
	if gsm == null:
		push_warning("ExplorationSystem.enter_map: GSM 不可用，导航状态未写入")
	else:
		# 写入导航状态——通过 GSM 第二层原子方法（ADR-0014 §GSM 写入契约）
		gsm.set_exploration_map(map_id)
		gsm.reset_exploration_visited(visited)
		gsm.set_exploration_ap(max_ap, max_ap)

		# 递增 entry_count + 缓存 DAG 快照到 map_states（供读档后重建）
		var entry_count: int = _get_entry_count(map_id) + 1
		gsm.update_exploration_map_state(map_id, {
			"entry_count": entry_count,
			"graph": map_data["graph"],
			"nodes": map_data["nodes"],
		})

	# 渲染快照——前五项与 NodeGraphScreen 的消费契约同构
	map_data["map_id"] = map_id
	map_data["visited"] = visited
	map_data["current_node"] = ENTRY_NODE_ID
	map_data["ap_remaining"] = max_ap

	# DAG 生成完成——广播 Cat 2b 信号（ADR-0014 §决策 3）
	_emit_safe(&"map_generated", [map_id, map_data])

	return map_data


# ═══════════════════════════════════════════════════════════════════════════════
# Autoload 生命周期
# ═══════════════════════════════════════════════════════════════════════════════

## Autoload 就绪——检测读档后是否有活跃地图，重建 DAG 缓存。[br]
## [br][b]流程[/b]（ADR-0014 §决策 1 状态分层模型 + R7）:[br]
## [br]1. 检测 GSM.exploration.current_map 非空[br]
## [br]2. 非空 → 从 map_states 读取 graph/nodes 快照 → rebuild_dag_cache[br]
## [br]3. 为空 → 跳过重建[br]
## [br]4. 末尾设 _dag_ready = true（保护 UI 早期调用）[br]
## [br][b]为什么在本层[/b]：Godot 只调最派生类的 [code]_ready[/code]（实测父类的
## 不会自动链式执行）——钩子分散在两处会出现「一半没跑」的静默故障。[br]
## [br]来源: ADR-0014 §决策 1 + R7。
func _ready() -> void:
	var gsm: Node = _get_gsm()
	if gsm == null:
		_dag_ready = true
		return

	var current_map: StringName = gsm.exploration.get("current_map", &"")
	if current_map != &"" and not str(current_map).is_empty():
		# 读档后重建——从 map_states 读取 graph/nodes 快照
		# （重建逻辑与「读档续玩」共用一处，见 ExplorationSystemResume）
		if rebuild_cache_from_storage(current_map).is_empty():
			push_warning("ExplorationSystem._ready: current_map=%s 但 map_states 无 graph/nodes 快照" % current_map)

	_dag_ready = true
