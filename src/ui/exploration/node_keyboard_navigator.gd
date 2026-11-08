class_name NodeKeyboardNavigator
extends RefCounted
## NodeKeyboardNavigator —— 键盘焦点空间跳转（exploration-ui S17-005 A3）。[br]
##
## [b]职责[/b]：纯函数式方向键寻路——输入 DAG 快照 + 可达判定，返回应聚焦的
## 节点 ID。不持有状态、不发信号、不读输入设备（[b]可独立单测[/b]）。[br]
## [br][b]跳转规则[/b]：↑/↓ 跨层（取层差最小者）；←/→ 同层（取索引差最小者）；
## 仅在可达节点间跳转（键盘 Enter 可确认的目标）。[br]
## [br][b]距离度量[/b]：层差权重 1.0、索引差权重 0.5——斜向候选劣于同向候选。
##
## 来源: story-005-node-move-interaction.md AC-9（A3 键盘路径）、
## ADR-0031 §4 双焦点双视觉、S17-005 代码审查 H3/M9（组件拆分）。

## 层差距离权重（↑/↓ 候选）。
const LAYER_DIST_WEIGHT: float = 1.0
## 索引差距离权重（←/→ 候选的次要分量）。
const INDEX_DIST_WEIGHT: float = 0.5


## 按方向找目标节点。[br]
## [param dir]: 方向向量（↑ = (0,-1) / ↓ = (0,1) / ← = (-1,0) / → = (1,0)）。[br]
## [param origin]: 起点节点 ID（当前键盘游标或当前节点）。[br]
## [param nodes]: 节点详情 {node_id: {layer, idx, ...}}。[br]
## [param reachable]: 可达判定 Callable（node_id → bool）——可注入，便于单测。[br]
## [b]返回[/b]: 目标节点 ID；无候选返回 -1。
static func find_target(dir: Vector2i, origin: int, nodes: Dictionary,
		reachable: Callable) -> int:
	if origin < 0 or not nodes.has(origin):
		return -1
	var origin_layer: int = int(nodes[origin].get("layer", 0))
	var origin_idx: int = int(nodes[origin].get("idx", 0))
	var best: int = -1
	var best_dist: float = INF
	for node_id: int in nodes.keys():
		if not reachable.call(node_id):
			continue
		var layer: int = int(nodes[node_id].get("layer", 0))
		var idx: int = int(nodes[node_id].get("idx", 0))
		if not _matches_direction(dir, layer - origin_layer, idx - origin_idx):
			continue
		var dist: float = absf(float(layer - origin_layer)) * LAYER_DIST_WEIGHT \
				+ absf(float(idx - origin_idx)) * INDEX_DIST_WEIGHT
		if dist < best_dist:
			best_dist = dist
			best = node_id
	return best


## 方向匹配判定——↑/↓ 看层差，←/→ 看同层索引差。
static func _matches_direction(dir: Vector2i, layer_delta: int, idx_delta: int) -> bool:
	if dir.y < 0:
		return layer_delta < 0
	if dir.y > 0:
		return layer_delta > 0
	if dir.x < 0:
		return layer_delta == 0 and idx_delta < 0
	if dir.x > 0:
		return layer_delta == 0 and idx_delta > 0
	return false
