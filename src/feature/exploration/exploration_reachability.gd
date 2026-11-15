extends RefCounted
## ExplorationReachability —— 节点图上的[b]行动力最短路[/b]（纯算法）。[br]
##
## [b]为什么需要它[/b]：系统里此前没有任何地方回答得了「从当前节点还走不走得到
## Boss」——[code]move_to_node[/code] 只看一步邻接，结算只看 [code]end_exploration[/code]
## 的入参。于是「行动力不足以走到 Boss」这条路径上，玩家既没有提示也没有出口
## （GDD exploration-system.md §5「行动力归零且无法到达Boss → 立即结算」与
## §8「退出按钮在探索HUD中始终可用」两条都无处落地）。[br]
##
## [b]边权 = 目标节点的行动力开销[/b]：与 [code]move_to_node[/code] 的扣费走同一份
## [ExplorationApRules.cost_for]（按地图配置解析、豁免类型恒为 0）——判定与扣费
## 若各算一套，就会出现「提示说走得到、真走却扣不起」（同
## [code]NodeGraphRevealAnimator[/code] 把可达性判定交还给系统的理由）。[br]
##
## [b]为什么不数步数[/b]：步数在出厂配置（[code]ap_cost[/code] = 1）下与开销等价，
## 但某张图把开销调成 2（GDD §调优参数「安全范围 1-2」）时两者就分家了；而豁免
## 节点（Boss / 传送 / 灵泉 0 消耗）让「步数少但花费多」成为常态。[br]
##
## [b]纯函数[/b]：不读 GSM、不碰 Autoload、不改任何状态（先例
## [code]exploration_ap_rules.gd[/code]）——GUT 直调可测。[br]
##
## 来源: design/gdd/action-point-system.md §公式 2/3 + §调优参数、
## design/gdd/exploration-system.md §4 移动规则 / §5 结束条件 / §8 边界、
## ADR-0014 §关键接口。

## 行动力开销规则——与扣费同一份解析（见类文档「边权」）。
const ApRules := preload("res://src/feature/exploration/exploration_ap_rules.gd")

## 不可达哨兵——没有合法路径能到任何目标节点。[br]
## [b]为什么用 -1[/b]：开销恒非负，-1 在整数域里不与任何合法结果冲突，
## 调用方判 [code]== UNREACHABLE[/code] 即可。
const UNREACHABLE: int = -1

## 详情缺 [code]type[/code] 键时的节点类型兜底——[code]NodeType.COMBAT[/code]。[br]
## [b]为什么是战斗[/b]：战斗与入口都不在豁免集合里（取哪个都不影响豁免判定），
## 与 [code]ExplorationSystem._get_node_type[/code] 的既有兜底逐字一致。
const FALLBACK_TYPE: int = 1


## 从 [param p_from] 走到任一 [param p_target_types] 类型节点的最少行动力花费。[br]
## [br][param p_graph] 邻接表 [code]{node_id: [child_ids]}[/code]。[br]
## [param p_details] 节点详情 [code]{node_id: {type, ...}}[/code]。[br]
## [param p_map_config] 本图配置（开销解析用；空字典按 GDD 默认 1）。[br]
## [param p_from] 出发节点。[br]
## [param p_blocked] 不可经过的节点（已访问——[code]move_to_node[/code] 拒绝进入
## 已访问节点，把它们算进路径会给出一个玩家做不到的答案）。[br]
## [param p_target_types] 目标节点类型集合（如 [code][BOSS][/code]）。[br]
## [br][b]出发点自身即目标时返回 0[/b]——「已经站在 Boss 节点上」的花费是零
## （GDD §8「行动力归零但已在Boss节点 → 可挑战Boss」，无需再花行动力）。[br]
## [br][b]返回[/b]：最少花费（≥0）；[constant UNREACHABLE] = 走不到。[br]
static func min_ap_to_any(p_graph: Dictionary, p_details: Dictionary,
		p_map_config: Dictionary, p_from: int, p_blocked: Array,
		p_target_types: Array) -> int:
	if p_target_types.is_empty() or not p_graph.has(p_from):
		return UNREACHABLE
	# Dijkstra（非负边权——开销解析保证 ≥ 0）
	var dist: Dictionary = {p_from: 0}
	var settled: Dictionary = {}
	while true:
		var current: int = _cheapest_unsettled(dist, settled)
		if current == UNREACHABLE:
			break
		settled[current] = true
		if p_target_types.has(_type_of(p_details, current)):
			return int(dist[current])
		for raw_child: Variant in p_graph.get(current, []):
			var child: int = int(raw_child)
			if settled.has(child) or p_blocked.has(child):
				continue
			var cost: int = int(dist[current]) + ApRules.cost_for(
					p_map_config, _type_of(p_details, child))
			if not dist.has(child) or cost < int(dist[child]):
				dist[child] = cost
	return UNREACHABLE


## 节点类型——详情缺 [code]type[/code] 键时按 [constant FALLBACK_TYPE]（与
## [code]ExplorationSystem._get_node_type[/code] 同口径）。
static func _type_of(p_details: Dictionary, p_node_id: int) -> int:
	var detail: Variant = p_details.get(p_node_id, {})
	if detail is Dictionary:
		return int((detail as Dictionary).get("type", FALLBACK_TYPE))
	return FALLBACK_TYPE


## 取未定型节点里当前距离最小的一个。[br]
## [br][b]为什么线性扫描[/b]：一张图的节点数 ≤ 24（6 层 × 最多 4 节点），
## 二叉堆的常数开销比扫描更大——性能预算（16.6ms/帧）下面这层完全不是瓶颈。[br]
## [br][b]返回[/b]：节点 ID；全部定型时返回 [constant UNREACHABLE]。
static func _cheapest_unsettled(p_dist: Dictionary, p_settled: Dictionary) -> int:
	var best: int = UNREACHABLE
	var best_cost: int = 0
	for raw_id: Variant in p_dist.keys():
		var node_id: int = int(raw_id)
		if p_settled.has(node_id):
			continue
		var cost: int = int(p_dist[raw_id])
		if best == UNREACHABLE or cost < best_cost:
			best = node_id
			best_cost = cost
	return best
