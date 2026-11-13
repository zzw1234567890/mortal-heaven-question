extends "res://src/feature/exploration/exploration_system_base.gd"
## ExplorationSystemOps —— 探索系统的[b]对外契约面[/b]：Cat 2b 信号表 / 子模块转发 /
## 只读查询 / DAG 缓存生命周期 / 测试桩。[br]
## [br][b]为什么单独一层[/b]：[code]exploration_system.gd[/code] 超 300 行软上限，
## 而「系统对外承诺什么」（信号、查询、转发）与「地图怎么生成、节点怎么走」（编排）
## 是两件事——后者才是链尾那份文件的职责（同
## [code]exploration_dag_builder.gd[/code] / [code]exploration_map_flush.gd[/code]
## 拆子模块的理由）。[br]
## [br][b]成员名逐字保留[/b]：信号名、方法名、参数名与拆分前一致——测试与 UI 连的
## 就是这些名字（[code]es.node_moved[/code] / [code]gsm._emit_signal_safe[/code]
## 的字符串路由 / [code]_parent.call("_get_map_config")[/code]）。[br]
## [br][b]信号声明只此一处[/b]：Cat 2b 信号全部在本文件声明。父层与链尾层都不再
## 重复声明同名信号——Godot 会把重复声明当成两个不同的信号，[code]_emit_safe[/code]
## 发的是本层的那个，而外部连的会是另一处，静默失联。[br]
## [br]来源: ADR-0014 §决策 3 信号表 + §决策 5 探索结束结算 + §GSM 写入契约、
## GDD exploration-system.md §信号定义。

## Cat 2b 信号——探索结束（ADR-0014 §决策 5）。
signal exploration_ended(reason: int, summary: Dictionary)

## Cat 2b 信号——DAG 生成完成（ADR-0014 §决策 3 信号表）。[br]
## [br][b]载荷[/b]：[code]map_data[/code] 为渲染快照——
## [code]{graph, nodes, visited, current_node, ap_remaining, layers, boss_node_id,
## path_count, map_id}[/code]。前五项与 [NodeGraphScreen] 的消费契约同构
## （[code]visited[/code] / [code]current_node[/code] / [code]ap_remaining[/code]
## 在 [method enter_map] 里按 GSM 实际写入值补齐——不是「推测值」）。[br]
## [br][b]何时发射[/b]：仅 [method enter_map]（含读档重建后的首次进入）——
## [method generate_map] 是纯生成、不写导航状态，不发信号（单测直调它不会
## 惊动 UI）。[br]
## [br][b]监听方[/b]：探索 UI（节点图主界面）、音频系统。[br]
## [br]来源: ADR-0014 §决策 3 信号表、GDD exploration-system.md §信号定义。
signal map_generated(map_id: StringName, map_data: Dictionary)

## Cat 2b 信号——节点移动完成（ADR-0007 / ADR-0014 §决策 3）。
signal node_moved(from_node: int, to_node: int, ap_remaining: int)

## Cat 2b 信号——到达事件节点，委托 EventSystem（ADR-0014 §决策 3）。
signal event_node_reached(map_pool: Array, player_realm: int)

## Cat 2b 信号——到达战斗/精英节点，委托 CombatSystem（ADR-0014 §决策 3）。
signal combat_node_reached(enemy_roster: Array, combat_type: StringName)

## Cat 2b 信号——到达 Boss 节点，委托 CombatSystem（ADR-0014 §决策 3）。
signal boss_node_reached(boss_data: Dictionary)

## Cat 2b 信号——到达商店/回复/灵泉/渡劫台/传送节点，UI 按 interaction_type 分发（ADR-0014 §决策 3）。
signal node_interaction_triggered(node_id: int, interaction_type: StringName, payload: Dictionary)

## Cat 2b 信号——节点被标记为已访问（统一入口 [method mark_node_visited] 的唯一出口）。[br]
## [br][b]载荷[/b]：[code]node_id[/code]；[code]is_new[/code] 是否首次标记
## ——[code]false[/code] 即幂等确认（到达已标记后再由战斗/事件确认）。[br]
## [br]来源: ADR-0014 §决策 3 信号表。
signal node_marked_visited(node_id: int, is_new: bool)


# ═══════════════════════════════════════════════════════════════════════════════
# 只读查询（不修改任何状态）
# ═══════════════════════════════════════════════════════════════════════════════

## 只读查询——验证从 from_node 是否可移动到 to_node。[br]
## [br][b]不修改任何状态[/b]——与 move_to_node() 分离（查询 vs 命令，ADR-0014 §关键接口）。[br]
## [br][param from_node] 起始节点 ID。[br]
## [br][param to_node] 目标节点 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 可移动，[code]false[/code] 不可移动。[br]
## [br]来源: ADR-0014 §关键接口 can_move_to。
func can_move_to(from_node: int, to_node: int) -> bool:
	# _dag_ready 守卫（ADR-0014 R7）
	if not _dag_ready:
		return false
	if not _is_reachable(from_node, to_node):
		return false
	var gsm: Node = _get_gsm()
	if gsm == null:
		return false
	var visited: Array = gsm.exploration.get("visited_nodes", [])
	if visited.has(to_node):
		return false
	var ap: int = int(gsm.exploration.get("action_points", 0))
	var to_type: int = _get_node_type(to_node)
	var is_exempt: bool = AP_EXEMPT_TYPES.has(to_type)
	if ap < 1 and not is_exempt:
		return false
	return true


## 只读查询——当前地图总层数，从 DAG 缓存推导（hud Story 006 LP 跨域
## 预协调 2026-10-20 APPROVED WITH CONDITIONS）。[br]
## [br][b]数据源[/b]：节点 ID 编码 [code]layer * 100 + idx[/code]
## （exploration_dag_builder.gd L46-50），故总层数 =
## [code]max(_node_details.keys()) / 100 + 1[/code]。每次调用现算不缓存——
## O(n) max() 无性能问题，勿加失效逻辑（LP 明示）。[br]
## [br][b]守卫链[/b]（先例 move_to_node / can_move_to / resolve_node——
## ADR-0014 R7；get_node_graph 为无守卫测试桩、非先例）:[br]
##   1. [code]_dag_ready[/code] 未就绪 → push_warning + 返回安全默认 1[br]
##   2. [code]_node_details[/code] 空集（_ready 有三条 _dag_ready=true 但缓存
##      空的路径——LP 条件①）→ push_warning + 返回安全默认 1[br]
## [br][b]只读[/b]：不修改任何状态——HUD 展示「层 x/总层数」的唯一许可入口
## （HUD 禁止调用 get_node_graph()/get_node_details() 测试桩取层数——LP 条件③）。[br]
## [br][b]返回[/b]: 总层数（≥1；空缓存/未就绪时返回 1——显示「层 x/1」的
## 占位语义，UI 侧不做额外分支）。[br]
## [br]来源: ADR-0014 R7 + hud Story 006（2026-10-20 QL 复核 GAP-1 + LP 条件②④⑤）。
func get_total_layers() -> int:
	# _dag_ready 守卫（ADR-0014 R7——先例 resolve_node L274）
	if not _dag_ready:
		push_warning("ExplorationSystem.get_total_layers: DAG 缓存未就绪，返回安全默认值 1")
		return 1
	# 空集防御（LP 条件①——_ready 有三条 _dag_ready=true 但缓存空的路径）
	if _node_details.is_empty():
		push_warning("ExplorationSystem.get_total_layers: 节点详情缓存为空，返回安全默认值 1")
		return 1
	# 节点 ID 编码 layer*100+idx → 最大 ID 整除 100 即最大层索引（0 基），+1 转 1 基
	return int(_node_details.keys().max()) / 100 + 1


# ═══════════════════════════════════════════════════════════════════════════════
# 统一标记入口
# ═══════════════════════════════════════════════════════════════════════════════

## 统一标记入口——把一个节点记为已访问，并发 [signal node_marked_visited]。[br]
## [br][b]三种节点共用[/b]：移动到达（资源/事件/战斗节点一致）、战斗胜利确认、
## 事件结算确认——口径只有这一处，别在别处直接调 gsm.add_visited_node。[br]
## [br][param node_id] 节点 ID。[br]
## [br][b]返回[/b]：[code]true[/code] 首次标记，[code]false[/code] 幂等重复。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型 + §决策 3 信号表。
func mark_node_visited(node_id: int) -> bool:
	if node_id < 0:
		return false
	var gsm: Node = _get_gsm()
	if gsm == null or not gsm.has_method(&"add_visited_node"):
		return false
	var visited: Array = gsm.get(&"exploration").get("visited_nodes", []) if gsm.get(&"exploration") != null else []
	var is_new: bool = not visited.has(node_id)
	gsm.call(&"add_visited_node", node_id)
	_emit_safe(&"node_marked_visited", [node_id, is_new])
	return is_new


## 通过 GSM._emit_signal_safe 路由 Cat 2b 信号（ADR-0007）。
func _emit_safe(signal_name: StringName, args: Array) -> void:
	var gsm: Node = _get_gsm()
	if gsm != null and gsm.has_method("_emit_signal_safe"):
		gsm._emit_signal_safe(self, signal_name, args)
		return
	push_warning("ExplorationSystem: GSM 不可用，%s 信号绕过 _emit_signal_safe 路由" % signal_name)
	var call_args: Array = [signal_name]
	call_args.append_array(args)
	callv("emit_signal", call_args)


# ═══════════════════════════════════════════════════════════════════════════════
# DAG 缓存生命周期（Story 004）
# ═══════════════════════════════════════════════════════════════════════════════

## 从已有数据重建 DAG 缓存——不重新生成，直接填充内部成员。[br]
## [br][param map_id] 地图 ID。[br]
## [br][param map_data] 含 graph/nodes/layers/boss_node_id/path_count 的 Dictionary。[br]
## [br][b]用途[/b]：读档后从 map_states 快照重建 + 探索→战斗→探索往返恢复。[br]
## [br]来源: ADR-0014 §决策 1 状态分层模型。
func rebuild_dag_cache(map_id: StringName, map_data: Dictionary) -> void:
	_node_graph = (map_data.get("graph", {}) as Dictionary).duplicate(true)
	_node_details = (map_data.get("nodes", {}) as Dictionary).duplicate(true)
	_map_config = {}
	_dag_ready = true


## 清理 DAG 缓存——重置所有内部状态。[br]
## [br][b]用途[/b]：end_exploration 后清理 + 测试清理。[br]
## [br]来源: ADR-0014 §决策 5 探索结束结算。
func clear_dag_cache() -> void:
	_node_graph.clear()
	_node_details.clear()
	_reachable_cache.clear()
	_map_config.clear()
	_dag_ready = false


# ═══════════════════════════════════════════════════════════════════════════════
# 测试桩 API
# ═══════════════════════════════════════════════════════════════════════════════

## 设置 RNG seed（确定性测试用）。
func set_rng_seed(seed_value: int) -> void:
	_rng.seed = seed_value

## 返回当前 DAG 图（测试桩）。
func get_node_graph() -> Dictionary:
	return _node_graph

## 返回当前节点详情（测试桩）。
func get_node_details() -> Dictionary:
	return _node_details


# ═══════════════════════════════════════════════════════════════════════════════
# 子模块转发（经济 / 结算刷新 / 回复点）
# ═══════════════════════════════════════════════════════════════════════════════

## 计算地图重入传送费——委托给 _economy 子模块。
func calculate_reentry_cost(map_id: StringName) -> int:
	return _get_economy().calculate_reentry_cost(map_id)


## 计算地图通关奖励——委托给 _economy 子模块。
func calculate_map_clear_rewards(map_id: StringName, is_first_clear: bool, player_realm: int, map_max_realm: int) -> Dictionary:
	return _get_economy().calculate_map_clear_rewards(map_id, is_first_clear, player_realm, map_max_realm)


## 境界差额惩罚系数——委托给 _economy 子模块。
func realm_gap_penalty(player_L: int, map_max_L: int) -> float:
	return _get_economy().realm_gap_penalty(player_L, map_max_L)


## 收集资源——委托给 _map_flush 子模块（Sprint 12 Story 011 拆分）。
func collect_resource(resource_type: StringName, amount: int) -> void:
	_get_map_flush().collect_resource(resource_type, amount)


## 回复点结算——全队回复 50% 已损失 HP（GDD §公式 7），返回实际回复量。[br]
## [br][b]唯一入口[/b]：UI 侧 [code]NodePopupServices.rest_party[/code] 调本方法，
## 面板只显示返回值（UI 零数值计算）。效果实现见 [ExplorationRest]。[br]
## [br][param p_node_id] 回复点节点 ID（透传——实现侧只用于日志）。[br]
## [br][b]返回[/b]：实际回复总量（全队满血 / 无角色登记 HP / GSM 写回入口缺失时为 0）。[br]
## [br]来源: GDD exploration-system.md §公式 7 + §8 边界、exploration-ui-system.md §4c。
func rest_at_node(p_node_id: int) -> int:
	return int(_get_rest().call(&"rest_at_node", p_node_id))


## 将 map_states[map_id] 中的 collected_* 转移到 GSM player.* 域——委托给 _map_flush 子模块。
func _flush_map_state(map_id: StringName) -> void:
	_get_map_flush()._flush_map_state(map_id)


## 战败结算——委托给 _map_flush 子模块。
func _flush_map_state_half_cultivation(map_id: StringName) -> void:
	_get_map_flush()._flush_map_state_half_cultivation(map_id)


## 探索结束结算——委托给 _map_flush 子模块（Sprint 12 Story 011 拆分）。
func end_exploration(reason: int) -> Dictionary:
	return _get_map_flush().end_exploration(reason)


## 检查地图是否已通关——委托给 _map_flush 子模块。
func _is_map_cleared(map_id: StringName) -> bool:
	return _get_map_flush()._is_map_cleared(map_id)


## 标记地图通关——委托给 _map_flush 子模块。
func _mark_map_cleared(map_id: StringName) -> void:
	_get_map_flush()._mark_map_cleared(map_id)


## 获取玩家境界——委托给 _map_flush 子模块。
func _get_player_realm() -> int:
	return _get_map_flush()._get_player_realm()


## 获取地图最高允许境界——委托给 _map_flush 子模块。
func _get_map_max_realm(map_id: StringName) -> int:
	return _get_map_flush()._get_map_max_realm(map_id)
