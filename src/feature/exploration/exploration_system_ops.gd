extends "res://src/feature/exploration/exploration_system_helpers.gd"
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
# 拒绝原因词表（移动判定的对外契约——[b]字符串常量只此一处[/b]）
# ═══════════════════════════════════════════════════════════════════════════════

## [method move_to_node] / [method can_move_to_detail] 的失败原因。[br]
## [br][b]为什么提成常量[/b]：判定（[code]can_move_to_detail[/code]）与命令
## （[code]move_to_node[/code]）说的是同一件事，而 UI 的
## [code]NodeMoveInteractor.REASON_TEXTS[/code] 拿这些字符串当查表的键——字面量散在
## 三处时，改一处文案就会让 UI 悄悄落进兜底提示（玩家看到「无法移动」而不是
## 「行动力不足」）。常量集中后，「系统说得出」与「UI 认得」是同一份词表。[br]
## [br][b]UI 侧另有一份字面量副本[/b]（[code]NodeStateLogic.REASON_*[/code]——
## headless 下不加载 Feature 层），由单测锁定两者同源（同 [constant AP_EXEMPT_TYPES]
## 的处置）。[br]
## [br]来源: ADR-0014 §关键接口、GDD action-point-system.md §公式 2/3、本轮任务书第 3 条。
const REASON_NOT_READY: String = "DAG 缓存未就绪"
const REASON_UNREACHABLE: String = "不可达"
const REASON_NO_GSM: String = "GSM 不可用"
const REASON_VISITED: String = "已访问"
const REASON_AP_SHORT: String = "行动力不足"


# ═══════════════════════════════════════════════════════════════════════════════
# 只读查询（不修改任何状态）
# ═══════════════════════════════════════════════════════════════════════════════

## 可判别版移动判定——[b]把混叠的三态拆开[/b]。[br]
## [br][b]为什么需要它[/b]：[method can_move_to] 的布尔把三件不同的事压成同一个
## [code]false[/code]——「走不到」（拓扑）、「走过了」（进度）、「走不起」（资源）。
## 界面要画的是三种不同的东西（灰色锁标记 / 绿色勾 / 红色斜线），拿布尔去还原
## 只能靠重新推导一遍判定规则（[code]NodeStateLogic[/code] 此前正是如此），
## 而两处各推导一遍必然漂移。[br]
## [br][b]返回[/b]：[code]{ok: bool, reason: String}[/code]——[code]ok[/code] 为真时
## [code]reason[/code] 为空串；为假时 [code]reason[/code] 取自上面的
## [constant REASON_NOT_READY] 一族，与 [method move_to_node] 的 [code]reason[/code]
## [b]逐字一致[/b]（同一个玩家动作不该因为走的是查询还是命令而看到两套说法）。[br]
## [br][b]不改任何状态[/b]：与 [method move_to_node] 分离（查询 vs 命令，ADR-0014
## §关键接口）。[br]
## [br][b]与扣费同一口径[/b]：AP 判定读 [method ap_cost_to]（按地图配置解析，
## 豁免类型为 0）——判定与扣费若各写一套，会出现「查询说能走、移动扣不起」。[br]
## [br]来源: 本轮任务书第 3 条（三态混叠）、ADR-0014 §关键接口。
func can_move_to_detail(from_node: int, to_node: int) -> Dictionary:
	# _dag_ready 守卫（ADR-0014 R7）
	if not _dag_ready:
		return {"ok": false, "reason": REASON_NOT_READY}
	if not _is_reachable(from_node, to_node):
		return {"ok": false, "reason": REASON_UNREACHABLE}
	var gsm: Node = _get_gsm()
	if gsm == null:
		return {"ok": false, "reason": REASON_NO_GSM}
	var visited: Array = gsm.exploration.get("visited_nodes", [])
	if visited.has(to_node):
		return {"ok": false, "reason": REASON_VISITED}
	# 越界存档值（负数）按 0 处理——与 move_to_node 的夹取一致
	var ap: int = maxi(int(gsm.exploration.get("action_points", 0)), 0)
	if ap < ap_cost_to(to_node):
		return {"ok": false, "reason": REASON_AP_SHORT}
	return {"ok": true, "reason": ""}


## 只读查询——验证从 from_node 是否可移动到 to_node。[br]
## [br][b]不修改任何状态[/b]——与 move_to_node() 分离（查询 vs 命令，ADR-0014 §关键接口）。[br]
## [br][b]本方法只是 [method can_move_to_detail] 的布尔投影[/b]：旧调用点（既有测试与
## 键盘导航）继续用它，但判定规则只有一条——两处各写一遍必然出现
## 「查询说不能走、移动却走得了」。[br]
## [br][b]要区分为什么不能走[/b]（不可达 / 已访问 / 行动力不足）请用
## [method can_move_to_detail]——布尔把三态压成一个 [code]false[/code]。[br]
## [br][param from_node] 起始节点 ID。[br]
## [br][param to_node] 目标节点 ID。[br]
## [br][b]返回[/b]: [code]true[/code] 可移动，[code]false[/code] 不可移动。[br]
## [br]来源: ADR-0014 §关键接口 can_move_to、GDD action-point-system.md §公式 2 可移动判定。
func can_move_to(from_node: int, to_node: int) -> bool:
	return bool(can_move_to_detail(from_node, to_node)["ok"])


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


## 地图列表载荷——[MapSelectScreen] 的唯一数据源（探明表 × GSM → 卡片条目）。[br]
## [br][b]为什么不硬编码[/b]：地图清单来自探明表 [code]ExplorationMapCatalog.MAPS[/code]
## 的键、解锁门槛来自该表 [code]unlock_realm[/code]、重入费用来自
## [ExplorationEconomy] 的既有公式——本层只转发，组装见 [ExplorationMapList]。[br]
## [br][b]返回[/b]：条目数组（字段口径见该类文档「条目契约」）；探明表为空时空数组
## （调用方按空列表渲染，不臆造占位地图）。[br]
## [br][b]只读[/b]：不修改任何状态——UI 每信号周期现取（ADR-0031 §2）。[br]
## [br]来源: ADR-0014 §get_map_list 契约、GDD exploration-system.md §1/§8。
func get_map_list() -> Array:
	return _get_map_list().call(&"build")


## 行动力泉结算——行动力回复至上限（夹到上限），返回实际回复量。[br]
## [br][b]唯一入口[/b]：UI 侧 [code]NodePopupServices.use_spring[/code] 调本方法，
## 面板只显示返回值（UI 零数值计算）。实现见 [ExplorationActionSpring]。[br]
## [br][param p_node_id] 灵泉节点 ID（透传——实现侧只用于日志）。[br]
## [br][b]返回[/b]：实际回复量（已满 / GSM 写回入口缺失时为 0）。[br]
## [br]来源: GDD exploration-system.md §节点类型一览 + §8 边界、exploration-ui §4。
func use_action_spring(p_node_id: int) -> int:
	return int(_get_action_spring().call(&"use_action_spring", p_node_id))


## 传送可跳转层列表——[b]只读[/b]，不修改任何状态。[br]
## [br][param p_node_id] 当前传送节点 ID。[br]
## [br][b]返回[/b]：[code][{layer, node_ids}][/code] 按层升序；空数组表示传送节点
## 不可激活（GDD §8 边界：目标层均未解锁）。[br]
## [br]来源: GDD exploration-system.md §4 移动规则 + §8 边界、[ExplorationTeleport]。
func teleport_targets(p_node_id: int) -> Array:
	return _get_teleport().call(&"targets_from", p_node_id)


## 传送到目标节点——0 行动力跨层跳转。[br]
## [br][param p_node_id] 当前传送节点 ID。[br]
## [param p_target_id] 目标节点 ID（须在 [method teleport_targets] 的列表内）。[br]
## [br][b]返回[/b]：[code]{success, reason, ap_remaining}[/code]（与
## [method move_to_node] 同形——UI 失败反馈共用一套 reason 文案）。[br]
## [br]来源: GDD exploration-system.md §节点类型一览（传送 0 行动力）+ §8 边界。
func teleport_to_node(p_node_id: int, p_target_id: int) -> Dictionary:
	return _get_teleport().call(&"teleport_to_node", p_node_id, p_target_id)


## 按层传送——落在该层的首个可跳节点上（[param p_layer] 为 0 基层索引）。[br]
## [br][b]为什么有这个重载[/b]：传送面板让玩家选的是[b]层[/b]而不是节点，
## 「层内选哪个落点」是 Feature 层的口径（UI 零数值计算）——UI 报层号，本方法
## 落到节点再走 [method teleport_to_node] 的同一条执行链。[br]
## [br][b]返回[/b]：同 [method teleport_to_node]；该层不可跳时 reason 为
## 「目标层未解锁」（与逐节点路径同一套拒绝文案）。[br]
## [br]来源: GDD exploration-system.md §4 移动规则、[ExplorationTeleport]。
func teleport_to_layer(p_node_id: int, p_layer: int) -> Dictionary:
	var target_id: int = int(_get_teleport().call(
			&"target_node_of_layer", p_node_id, p_layer))
	if target_id < 0:
		var gsm: Node = _get_gsm()
		var ap: int = int(gsm.exploration.get("action_points", 0)) if gsm != null else 0
		return {"success": false, "reason": "目标层未解锁", "ap_remaining": ap}
	return teleport_to_node(p_node_id, target_id)


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
