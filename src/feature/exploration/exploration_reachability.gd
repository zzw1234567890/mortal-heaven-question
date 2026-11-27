extends RefCounted
## ExplorationReachability —— 「还走不走得到某种节点」的[b]最少行动力[/b]（纯算法）。[br]
##
## [b]为什么需要它[/b]：系统里必须有个地方回答得了「从当前节点还走不走得到 Boss」
## ——[method ExplorationSystem.end_exploration] 只看入参，UI 的状态栏要据此决定
## 「此刻离开会丢掉什么」（GDD exploration-system.md §5「行动力归零且无法到达Boss
## → 立即结算」、§8「退出按钮始终可用」）。[br]
##
## [br][b]★ 本轮核心变更：不再沿边搜索，改为「直达距离」★[/b]（老板 2026-11-27
## 18:40：「每个节点之间都可达，只是消耗的行动力不一样」）：[br]
## [br]旧口径是「在邻接表上跑 Dijkstra，已访问节点当墙」。本轮取消 DAG 路径限制后，
## 那套口径有两个问题：[br]
##   · [b]算出来的答案不是玩家实际要付的[/b]——图上绕三步花费 2，而玩家直接点目标
##     只需付一次直达距离；[br]
##   · [b]「已访问当墙」与移动规则矛盾[/b]——已访问节点现在可以重入，把它算成障碍
##     会给出一个「玩家其实做得到」的假拒绝。[br]
## 于是本模块改为：在目标类型的节点里取[b]直达花费最小[/b]的那一个，花费由
## [ExplorationApRules.cost_for_move] 按布局距离算出（与 [code]move_to_node[/code]
## 的扣费同一份解析）。[br]
##
## [br][b]为什么不再需要 p_blocked[/b]：它表达的「不可经过的节点」在新规则下是空集
## ——任何节点都可进入（消耗照算、奖励不重复发）。留着它会成为一个永远传空数组的
## 参数，而「永远为空」的输入口比没有更危险（下一个人会以为它有意义）。[br]
##
## [br][b]为什么保留 p_graph[/b]：它仍是「本图有哪些节点」的权威定义（节点存在性
## 以边表的键为准），且 [method ExplorationSystem._is_reachable] 一族仍需要邻接查询。
## [br][br][b]纯函数[/b]：不读 GSM、不碰 Autoload、不改任何状态（先例
## [code]exploration_ap_rules.gd[/code]）——GUT 直调可测。[br]
##
## 来源: design/gdd/action-point-system.md §公式 2/3 + §调优参数、
## design/gdd/exploration-system.md §4 移动规则 / §5 结束条件 / §8 边界、
## 本轮任务书追加规则（全连通 + 距离定价）、ADR-0014 §关键接口。

## 行动力开销规则——与扣费同一份解析（见类文档「直达距离」）。
const ApRules := preload("res://src/feature/exploration/exploration_ap_rules.gd")
## 布局几何——距离的来源（与 UI 画出来的位置同源）。
const Geometry := preload("res://src/feature/exploration/exploration_node_geometry.gd")

## 不可达哨兵——图里没有任何一个目标类型的节点。[br]
## [b]为什么用 -1[/b]：开销恒非负，-1 在整数域里不与任何合法结果冲突，
## 调用方判 [code]== UNREACHABLE[/code] 即可。[br]
## [br][b]取值与旧口径一致[/b]（旧口径里它表示「没有合法路径」）——语义收窄了
## （「目标根本不存在」），但调用方的判法不用改。
const UNREACHABLE: int = -1

## 详情缺 [code]type[/code] 键时的节点类型兜底——[code]NodeType.COMBAT[/code]。[br]
## [b]为什么是战斗[/b]：战斗与入口都不在豁免集合里（取哪个都不影响豁免判定），
## 与 [code]ExplorationSystem._get_node_type[/code] 的既有兜底逐字一致。
const FALLBACK_TYPE: int = 1


## 从 [param p_from] 走到任一 [param p_target_types] 类型节点的最少行动力花费。[br]
## [br][param p_graph] 邻接表 [code]{node_id: [child_ids]}[/code]——本图节点集合的
## 权威定义（[param p_from] 不在其中即无法作答）。[br]
## [param p_details] 节点详情 [code]{node_id: {type, layer, idx}}[/code]。[br]
## [param p_map_config] 本图配置（UNIT / MAX 解析用；空字典按默认）。[br]
## [param p_from] 出发节点。[br]
## [param p_target_types] 目标节点类型集合（如 [code][BOSS][/code]）。[br]
## [br][b]出发点自身即目标时返回 0[/b]——「已经站在 Boss 节点上」的花费是零
## （GDD §8「行动力归零但已在Boss节点 → 可挑战Boss」，无需再花行动力）。[br]
## [br][b]返回[/b]：最少花费（≥0）；[constant UNREACHABLE] = 图里没有该类型的节点
## （或 [param p_from] 不在图里 / 目标类型集为空）。[br]
## [br][b]为什么「最少」仍有意义[/b]：同一类型的节点可能有多个（多张图里 Boss 与
## 渡劫台都可能不止一个），玩家会挑最近的那个去；不取最小会把花费报高。
static func min_ap_to_any(p_graph: Dictionary, p_details: Dictionary,
		p_map_config: Dictionary, p_from: int, p_target_types: Array) -> int:
	if p_target_types.is_empty() or not p_graph.has(p_from):
		return UNREACHABLE
	var counts: Dictionary = Geometry.layer_counts(p_details)
	var from_detail: Dictionary = p_details.get(p_from, {})
	var best: int = UNREACHABLE
	for raw_id: Variant in p_graph.keys():
		var node_id: int = int(raw_id)
		if not p_target_types.has(_type_of(p_details, node_id)):
			continue
		if node_id == p_from:
			return 0  # 已经站在目标上——比任何一次移动都便宜
		var cost: int = ApRules.cost_for_move(p_map_config, from_detail,
				p_details.get(node_id, {}), counts)
		if best == UNREACHABLE or cost < best:
			best = cost
	return best


## 节点类型——详情缺 [code]type[/code] 键时按 [constant FALLBACK_TYPE]（与
## [code]ExplorationSystem._get_node_type[/code] 同口径）。
static func _type_of(p_details: Dictionary, p_node_id: int) -> int:
	var detail: Variant = p_details.get(p_node_id, {})
	if detail is Dictionary:
		return int((detail as Dictionary).get("type", FALLBACK_TYPE))
	return FALLBACK_TYPE
