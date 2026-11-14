extends RefCounted
## ExplorationTeleport —— 传送节点子模块：可跳转层列表 + 跨层跳转执行。[br]
## [br][b]为什么单独一处[/b]：与 [ExplorationRest] / [ExplorationActionSpring] /
## [ExplorationEconomy] 同层——[code]ExplorationSystem[/code] 只做导航编排，
## 「哪些层可跳、跳过去要写什么状态」是另一类知识；宿主只留转发方法。[br]
## [br][b]为什么不能复用 [code]move_to_node[/code][/b]：后者的第一道校验是
## 邻接（[code]graph[from][/code] 含 to），而传送的目标层与当前层[b]没有边[/b]
## （GDD §4「传送节点允许跨层移动到指定节点」）——走 [code]move_to_node[/code]
## 必然被判「不可达」。故本模块自己做「写位置 → 标记已访问 → 发 node_moved →
## resolve_node」这一条链，与 [code]move_to_node[/code] 的后半段同口径
## （同一个 GSM 写入口、同一个统一标记入口、同一个 Cat 2b 信号）。[br]
## [br][b]消耗 0 行动力[/b]（GDD §节点类型一览「传送——不消耗行动力」、
## [code]AP_EXEMPT_TYPES[/code]）；AP=0 时同样可传送。[br]
## [br][b]目标层解锁规则[/b]（GDD §8 边界「传送节点连通到未解锁层：传送节点的
## 目标层必须已解锁（如本局尚未到达过），否则传送节点不可激活」）：[br]
##   · 已解锁 = 层索引 ≤ 本局已到达过的最深层（[code]visited_nodes[/code] 推得）；[br]
##   · 可跳转 = 已解锁层中的[b]未访问[/b]节点；[br]
##   · 排除当前层——同层横向移动为 GDD §4 所禁（「不可在同一层内横向移动」），
##     传送只做跨层；[br]
##   · 列表为空 → 传送节点不可激活（UI 侧显示为灰显，与本条 GDD 边界一致）。[br]
## [br][b]方向问题（GDD 待解决问题 #5 未裁决）[/b]：GDD 倾向「单向」，但单向的
## 起点/终点定义在本轮仍是开放的（详见 [code]exploration-ui-system.md[/code]
## §传送「机制未闭合」）。本实现取[b]不设方向偏好的中性口径[/b]——凡是「已解锁
## 且未访问」的跨层节点都可跳，把方向裁决留给后续 story；裁决落地后只需改
## [method targets_from] 的过滤条件，执行链与 UI 不受影响。[br]
## [br][b]为什么「已解锁」按最深层推导[/b]：本局每前进一步都要经过一个节点，
## 因此「到达过的最深层」等价于「已探明的推进深度」——比它更深的层玩家从未
## 见过，跳过去等于跳过整段未见内容（GDD §4「不可跳过未探索的中间层」）。[br]
##
## 来源: design/gdd/exploration-system.md §4 移动规则 / §节点类型一览 / §8 边界 /
## §待解决问题 #5、ADR-0014 §决策 3（node_moved 信号）、
## 先例 [code]exploration_rest.gd[/code] / [code]exploration_economy.gd[/code]。

## 节点 ID 编码——[code]layer * 100 + idx[/code]（与 DAG 生成器同源）。
const NODE_ID_LAYER_FACTOR: int = 100


## 父节点引用——ExplorationSystem 实例（取 DAG 缓存 / GSM / 发信号）。
var _parent: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


# ═══════════════════════════════════════════════════════════════════════════════
# 可跳转层列表（只读——不修改任何状态）
# ═══════════════════════════════════════════════════════════════════════════════

## 可跳转层列表——按层升序，每层给出该层内可跳的节点 ID。[br]
## [br][param p_node_id] 当前所在的传送节点 ID。[br]
## [br][b]返回[/b]：[code][{layer: int, node_ids: Array}][/code]；无可跳层时为空数组
## （调用方据此判定「传送节点不可激活」）。[br]
func targets_from(p_node_id: int) -> Array:
	var details: Dictionary = _details()
	if details.is_empty():
		return []
	var current_layer: int = p_node_id / NODE_ID_LAYER_FACTOR
	var max_reached: int = max_reached_layer()
	if max_reached < 0:
		return []

	var by_layer: Dictionary = {}
	for raw_id: Variant in details.keys():
		var node_id: int = int(raw_id)
		var layer: int = node_id / NODE_ID_LAYER_FACTOR
		if layer == current_layer:
			continue  # 同层横向移动为 GDD §4 所禁
		if layer > max_reached:
			continue  # 未解锁层——目标层未到达过，不可激活
		if _is_visited(node_id):
			continue  # 已访问节点不可作为落点（与 move_to_node 同一约束）
		var bucket: Variant = by_layer.get(layer)
		if bucket == null:
			by_layer[layer] = [node_id]
		else:
			(bucket as Array).append(node_id)

	var layers: Array = by_layer.keys()
	layers.sort()
	var out: Array = []
	for layer: int in layers:
		var ids: Array = by_layer[layer]
		ids.sort()
		out.append({"layer": layer, "node_ids": ids})
	return out


## 本局已到达过的最深层索引（无已访问节点时 -1）。[br]
## [br][b]「已解锁」的判定依据[/b]：本局推进深度——比它更深的层玩家从未见过。[br]
func max_reached_layer() -> int:
	var deepest: int = -1
	for raw: Variant in _visited():
		deepest = maxi(deepest, int(raw) / NODE_ID_LAYER_FACTOR)
	return deepest


## 目标节点是否可跳（列表的成员判定——UI 与执行链共用同一份判定）。[br]
## [br][param p_node_id] 当前传送节点。[br]
## [param p_target_id] 候选目标节点。[br]
## [br][b]返回[/b]：可跳 → [code]{layer: int}[/code]；不可跳 → 空字典。
func target_layer_of(p_node_id: int, p_target_id: int) -> Dictionary:
	for raw: Variant in targets_from(p_node_id):
		var entry: Dictionary = raw
		if (entry.get("node_ids", []) as Array).has(p_target_id):
			return {"layer": int(entry.get("layer", -1))}
	return {}


## 某层内的落点节点——层内[b]首个[/b]可跳节点（按节点 ID 升序）。[br]
## [br][param p_node_id] 当前传送节点。[br]
## [param p_layer] 目标层索引（0 基）。[br]
## [br][b]返回[/b]：落点节点 ID；该层不可跳时 -1。[br]
## [br][b]为什么由 Feature 层定落点[/b]：UI 只报「选了哪一层」（UI 零数值计算，
## control-manifest）——层内多落点时的取舍口径留在这里，将来要改成「取最靠近
## Boss 的那个」也只动本方法。[br]
func target_node_of_layer(p_node_id: int, p_layer: int) -> int:
	for raw: Variant in targets_from(p_node_id):
		var entry: Dictionary = raw
		if int(entry.get("layer", -1)) != p_layer:
			continue
		var ids: Array = entry.get("node_ids", [])
		return int(ids[0]) if not ids.is_empty() else -1
	return -1


# ═══════════════════════════════════════════════════════════════════════════════
# 跳转执行（写 GSM → 标记 → 发信号 → 分发节点交互）
# ═══════════════════════════════════════════════════════════════════════════════

## 传送到目标节点——0 行动力，落点必须在本模块给出的可跳列表内。[br]
## [br][param p_node_id] 当前传送节点 ID。[br]
## [param p_target_id] 目标节点 ID。[br]
## [br][b]返回[/b]：[code]{success: bool, reason: String, ap_remaining: int}[/code]
## ——与 [code]move_to_node[/code] 同形（UI 侧失败反馈共用一套 reason 文案）。[br]
## [br][b]顺序与 [code]move_to_node[/code] 一致[/b]：写位置 → 统一标记入口 →
## 发 [code]node_moved[/code] → [code]resolve_node[/code]（到达即触发节点交互）。[br]
## [br][b]AP 原样不动[/b]：传送不消耗行动力，也不回填——[code]ap_remaining[/code]
## 是当前值（不写 GSM，避免无意义的变更记录）。
func teleport_to_node(p_node_id: int, p_target_id: int) -> Dictionary:
	var result: Dictionary = {"success": false, "reason": "", "ap_remaining": 0}
	var gsm: Node = _get_gsm()
	if gsm == null:
		result["reason"] = "GSM 不可用"
		return result
	if _details().is_empty():
		result["reason"] = "DAG 缓存未就绪"
		return result

	var target: Dictionary = target_layer_of(p_node_id, p_target_id)
	if target.is_empty():
		# 目标层未解锁 / 已访问 / 同层——三种拒绝共用一句可读原因
		result["reason"] = "目标层未解锁"
		return result

	var ap: int = int(gsm.exploration.get("action_points", 0))
	result["ap_remaining"] = ap

	# 更新导航状态（第二层原子方法——ADR-0014 §GSM 写入契约）
	gsm.set_exploration_position(int(target["layer"]),
			p_target_id % NODE_ID_LAYER_FACTOR)
	_parent.call("mark_node_visited", p_target_id)

	result["success"] = true
	_parent.call("_emit_safe", &"node_moved", [p_node_id, p_target_id, ap])
	_parent.call("resolve_node", p_target_id)
	return result


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 节点详情缓存（宿主 _node_details——只读副本不必要，本模块不改写）。
func _details() -> Dictionary:
	if _parent == null:
		return {}
	var details: Variant = _parent.get("_node_details")
	return details if details is Dictionary else {}


## 已访问节点集合（GSM；不可用时为空——不臆造）。
func _visited() -> Array:
	var gsm: Node = _get_gsm()
	if gsm == null:
		return []
	var visited: Variant = gsm.exploration.get("visited_nodes", [])
	return visited if visited is Array else []


## 某节点是否已访问。
func _is_visited(p_node_id: int) -> bool:
	return _visited().has(p_node_id)


## GSM 引用——经父节点的 [code]_get_gsm[/code]（查找口径单一）。
func _get_gsm() -> Node:
	if _parent == null:
		return null
	return _parent.call("_get_gsm")
