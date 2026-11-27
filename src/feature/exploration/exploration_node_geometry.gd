extends RefCounted
## ExplorationNodeGeometry —— 节点图的[b]布局几何唯一来源[/b]（纯函数，无状态）。[br]
## [br][b]★ 为什么它必须住在 Feature 层 ★[/b]（本轮迁移到「全连通 + 距离定价」的落点）：[br]
## 移动消耗现在按[b]两节点在布局坐标里的欧氏距离[/b]定价（老板 2026-11-27 18:40：
## 「每个节点之间都可达，只是消耗的行动力不一样」）。于是「节点画在哪」这件事同时被
## 两处读——UI 的绘制/命中，与系统的扣费 ——而两者如果各写一套间距常量，改一次
## [constant NODE_GAP] 就会出现「走过去花了 2 点，但看起来只有一格远」这种玩家能
## 看出、单测却抓不到的漂移（两套公式都自洽）。[br]
## [br][b]分层方向[/b]：本模块是无状态的纯数学（同 [code]exploration_ap_rules.gd[/code]
## 的处境），住在 Feature 层；UI 侧 [code]node_graph_style.gd[/code] 与
## [code]node_graph_layout.gd[/code] [b]逐条转发[/b]本模块的常量与坐标公式
## ——既有引用点（[code]Style.LAYER_GAP[/code] 一族）一个都不用改，而「间距到底是多少」
## 只有这一处定义。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不读 GSM、不写任何状态，输入 layer/idx/
## 层内节点数，输出坐标。[br]
## [br]来源: 本轮任务书追加规则（全连通 + 距离定价）、
## [code]node_graph_layout.gd[/code] 第一/二轮地图化的间距标定、ADR-0031 §2。

## 层间距（px）——纵向分量（GDD「节点间距（最小）80px」之上的实现值）。[br]
## [br][b]★ 数值的出处已移到本模块 ★[/b]：标定推导（第二轮 110 → 104、下限由
## 地名行与下一层节点上沿的余量决定）仍见 [code]node_graph_style.gd[/code] 的注记，
## 而[b]真值只有这一份[/b]——UI 与扣费读的是同一个数。[br]
## [br][b]为什么不由扣费侧另定一套「逻辑间距」[/b]：那样「一格」在画面上是 104px、
## 在扣费公式里是别的数，玩家按画面估的行动力永远对不上。
const LAYER_GAP: float = 104.0
## 同层节点间距（px）——横向分量（第二轮 104 → 200）。
const NODE_GAP: float = 200.0
## 层间水平错开量（px）——第 layer 层整体左右平移的幅度（蛇形）。
const LAYER_STAGGER: float = 70.0


## 第 [param p_layer] 层的水平错开量（px，右为正）。[br]
## [br][b]蛇形（左-右-左-右）[/b]：单调偏一侧会让整张图斜成一条对角线，包围盒还是
## 一根斜条；蛇形让相邻层反向走位，左右边界交替被撑开。[br]
## [br][b]第 0、1 层错开量为 0[/b]（硬约束）：[code]test_node_graph_pick_region.gd[/code]
## 的几何前提是开局那两格一左一右夹住原点，两层任一被平移都可能抹平该前提。[br]
## [br][b]为什么收在本模块[/b]：错开量进的是 [method position_of] 的 x——它既是
## 画面坐标也是扣费距离的一半来源，分出去写两遍必然分叉。
static func stagger_of(p_layer: int) -> float:
	if p_layer <= 1:
		return 0.0
	var direction: float = 1.0 if (p_layer % 2) == 0 else -1.0
	return direction * LAYER_STAGGER


## 节点中心坐标——同层横向居中 + 层间蛇形错开。[br]
## [br][param p_layer] 层索引（0 基）。[br]
## [param p_idx] 层内序号（0 基）。[br]
## [param p_layer_count] 该层节点总数（居中用——[b]必须传[/b]，见下）。[br]
## [br][b]为什么层内节点数是入参而不是内部推[/b]：没有它就算不出「同层居中」，
## 而两个节点之间的距离会因此差一个与层形状相关的量（层越宽、差得越多）。
## 调用方（渲染器 / 系统）都持有整张图的节点详情，现算一份层计数是 O(n)。[br]
## [br][b]返回[/b]：节点中心坐标（局部 px）。
static func position_of(p_layer: int, p_idx: int, p_layer_count: int) -> Vector2:
	var count: int = maxi(p_layer_count, 1)
	var row_width: float = (float(count) - 1.0) * NODE_GAP
	return Vector2(
			(row_width * 0.5) - (float(p_idx) * NODE_GAP) + stagger_of(p_layer),
			float(p_layer) * LAYER_GAP)


## 每层节点数 [code]{layer: count}[/code]——由节点详情现算。[br]
## [br][b]返回[/b]：层计数表；空输入返回空字典。
static func layer_counts(p_details: Dictionary) -> Dictionary:
	var counts: Dictionary = {}
	for node_id: int in p_details.keys():
		var layer: int = int((p_details[node_id] as Dictionary).get("layer", 0))
		counts[layer] = int(counts.get(layer, 0)) + 1
	return counts


## 全部节点坐标 [code]{node_id: Vector2}[/code]。[br]
## [br][b]为什么要有它[/b]：渲染器与系统各要一份完整坐标表（前者画、后者算距离），
## 两份都由本模块算才能保证「画出来的距离就是扣费的距离」。[br]
## [br][b]返回[/b]：空输入返回空字典。
static func positions_of(p_details: Dictionary) -> Dictionary:
	var positions: Dictionary = {}
	if p_details.is_empty():
		return positions
	var counts: Dictionary = layer_counts(p_details)
	for node_id: int in p_details.keys():
		var detail: Dictionary = p_details[node_id]
		positions[node_id] = position_of(int(detail.get("layer", 0)),
				int(detail.get("idx", 0)),
				int(counts.get(int(detail.get("layer", 0)), 1)))
	return positions


## 两节点中心的欧氏距离（px）。[br]
## [br][param p_from] / [param p_to] 节点详情（含 layer/idx）。[br]
## [param p_counts] 层计数表（[method layer_counts] 的结果）。[br]
## [br][b]返回[/b]：距离（px）；任一侧缺 layer/idx 时返回 0.0（按「同一格」处理
## ——缺字段是数据缺陷，按 0 处理只会让消耗取到下限 1，不会算出负消耗或天文数字）。[br]
## [br][b]为什么不用坐标表而用详情 + 层计数[/b]：系统侧只需要这一对节点的距离，
## 为此算全图坐标表是 O(n) 的无谓开销；层计数可以随地图缓存一次。
static func distance_between(p_from: Dictionary, p_to: Dictionary,
		p_counts: Dictionary) -> float:
	var a: Vector2 = position_of(int(p_from.get("layer", 0)), int(p_from.get("idx", 0)),
			int(p_counts.get(int(p_from.get("layer", 0)), 1)))
	var b: Vector2 = position_of(int(p_to.get("layer", 0)), int(p_to.get("idx", 0)),
			int(p_counts.get(int(p_to.get("layer", 0)), 1)))
	return a.distance_to(b)
