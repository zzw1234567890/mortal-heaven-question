extends GutTest
## 探索行动力（AP）开销规则单元测试——[b]按距离定价[/b]。[br]
## [br][b]★ 本轮语义变更（有意改动，报告单列）★[/b]：移动开销从「按格定价」
## （[code]ap_cost[/code] / [code]ap_costs[/code] 两个配置键）改为
## 「按两节点在布局坐标里的距离定价」（老板 2026-11-27 18:40：「每个节点之间都可达，
## 只是消耗的行动力不一样」）。公式 [code]clamp(round(distance / UNIT), 1, MAX)[/code]。[br]
## [br][b]为什么本文件必须跟着重写[/b]：旧断言逐条钉的是「读哪个配置键」，而那两个键
## 本轮[b]已不参与移动定价[/b]（保留只为旧存档/旧地图表不报错）。断言留着会变成
## 「测一个已经被忽略的键」——绿着，但什么都没守住。[br]
## [br][b]数据层的边表 / 邻接图测试一条未动[/b]（任务书硬约束）：本文件不碰
## [code]exploration_dag_*[/code]。[br]
##
## [br][b]覆盖[/b]：[br]
##   · 距离定价——同距同价（稳定）/ 距离翻倍消耗单调不减 / 下限 1 / 上限 MAX；[br]
##   · 配置解析——[code]ap_distance_unit[/code] / [code]ap_move_max[/code]，
##     缺键与非法值回落出厂默认；[br]
##   · 豁免优先——Boss/传送/灵泉恒为 0，配置里写什么也不生效；[br]
##   · 跨层同源——Feature / 继承链 / UI 三份 [code]AP_EXEMPT_TYPES[/code] 逐项一致
##     （UI 是数值副本，headless 下不加载 Feature 层，只能靠本断言锁定）；[br]
##   · 遗留键——[code]ap_cost[/code] / [code]ap_costs[/code] 仍在配置表里（旧存档兼容），
##     但[b]改动它们不影响任何消耗[/b]。[br]
## [br][b]隔离[/b]：纯函数 / 常量断言——不读写 GSM、不实例化任何系统。[br]
##
## 来源: 本轮任务书追加规则（全连通 + 距离定价 + 纯函数单测三条）、
## design/gdd/action-point-system.md §公式 3 移动后行动力、
## design/gdd/exploration-system.md §节点类型一览。

const ApRules := preload("res://src/feature/exploration/exploration_ap_rules.gd")
const Geometry := preload("res://src/feature/exploration/exploration_node_geometry.gd")
const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const NodeStateLogic := preload("res://src/ui/exploration/node_state_logic.gd")
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")

## NodeType 枚举值（与 exploration_system_base.gd 的 NodeType 逐项同源）。
const TYPE_ENTRY: int = 0
const TYPE_COMBAT: int = 1
const TYPE_ELITE: int = 2
const TYPE_BOSS: int = 3
const TYPE_EVENT: int = 4
const TYPE_TELEPORT: int = 6
const TYPE_ACTION_SPRING: int = 7
const TYPE_MEDITATION: int = 13

## 单层间距（px）——距离定价的标定基准（[constant Geometry.LAYER_GAP]）。
## [br][b]为什么从几何模块取而不是抄一个数[/b]：抄来的数会在间距调整后失效，
## 而这条断言要守的正是「几何与定价同源」。
const LAYER_GAP: float = Geometry.LAYER_GAP


# ═══════════════════════════════════════════════════════════════════════════════
# 一、距离定价（本轮核心——三条硬性质）
# ═══════════════════════════════════════════════════════════════════════════════

func test_same_distance_always_costs_the_same() -> void:
	## ★ 硬性质一：同一对节点 → 消耗稳定（纯函数，无随机、无隐藏状态）
	var first: int = ApRules.cost_by_distance({}, TYPE_COMBAT, 300.0)
	var second: int = ApRules.cost_by_distance({}, TYPE_COMBAT, 300.0)
	assert_eq(first, second, "同一距离重复求值应给同一消耗")
	## 同一对[b]真实节点[/b]也稳定（走 cost_for_move 全链——层计数表参与的那条路）
	var counts: Dictionary = Geometry.layer_counts(_pair_details())
	assert_eq(ApRules.cost_for_move({}, _detail(0, 0), _detail(2, 1), counts),
			ApRules.cost_for_move({}, _detail(0, 0), _detail(2, 1), counts),
			"同一对节点重复求值应给同一消耗（全链）")


func test_doubling_distance_never_lowers_the_cost() -> void:
	## ★ 硬性质二：距离翻倍 → 消耗单调不减（不是「恰好翻倍」——上限会夹住）
	var unit: float = ApRules.DEFAULT_DISTANCE_UNIT
	for step: int in range(1, 6):
		var near: int = ApRules.cost_by_distance({}, TYPE_COMBAT,
				unit * 0.5 * float(step))
		var far: int = ApRules.cost_by_distance({}, TYPE_COMBAT,
				unit * 1.0 * float(step))
		assert_true(far >= near,
				"距离翻倍（%.0f → %.0f px）消耗不得下降：%d → %d"
				% [unit * 0.5 * float(step), unit * float(step), near, far])


func test_cost_is_monotonic_across_the_whole_scale() -> void:
	## 单调性的连续形式：沿距离轴逐点扫，消耗永不下降（上限之内）
	var previous: int = 0
	for step: int in range(0, 40):
		var cost: int = ApRules.cost_by_distance({}, TYPE_COMBAT, float(step) * LAYER_GAP)
		assert_true(cost >= previous,
				"距离 %.0fpx 处消耗 %d 低于前一档 %d" % [float(step) * LAYER_GAP,
						cost, previous])
		previous = cost


func test_cost_has_a_floor_of_one() -> void:
	## 下限 1：0 消耗意味着「白走」——玩家会找 0 消耗的落点反复横跳刷访问状态
	assert_eq(ApRules.cost_by_distance({}, TYPE_COMBAT, 0.0), 1, "距离 0 → 1")
	assert_eq(ApRules.cost_by_distance({}, TYPE_COMBAT, 1.0), 1, "极近 → 1")
	assert_eq(ApRules.cost_by_distance({}, TYPE_COMBAT, -500.0), 1,
			"负距离（数据缺陷）按 0 处理 → 1，不得回血")


func test_cost_has_a_ceiling_per_move() -> void:
	## 上限 MAX：全连通之后「从第一层跳到最后一层」在几何上是一次移动，
	## 纯按距离算可以一次吃掉十几点——点一下就没行动力了，而画面上那只是一次点击
	assert_eq(ApRules.cost_by_distance({}, TYPE_COMBAT, 100000.0),
			ApRules.DEFAULT_MOVE_MAX, "超远距离夹到单次上限")
	assert_eq(ApRules.DEFAULT_MOVE_MAX, 4, "出厂上限（见常量的标定注记）")


func test_one_layer_apart_is_the_cheapest_paid_move() -> void:
	## 标定口径：出厂单位距离 120px 落在层间距（104）与同层间距（200）之间——
	## 「挪一层」≈ 0.87 → 1 点，「同层隔一格」≈ 1.67 → 2 点
	assert_eq(ApRules.cost_by_distance({}, TYPE_COMBAT, LAYER_GAP), 1,
			"相邻一层（%.0fpx）应是最便宜的一档" % LAYER_GAP)
	assert_eq(ApRules.cost_by_distance({}, TYPE_COMBAT, Geometry.NODE_GAP), 2,
			"同层隔一格（%.0fpx）应比挪一层贵" % Geometry.NODE_GAP)


# ═══════════════════════════════════════════════════════════════════════════════
# 二、全链口径（cost_for_move —— 从节点详情算距离）
# ═══════════════════════════════════════════════════════════════════════════════

func test_cost_for_move_reads_layout_distance() -> void:
	## 全链：详情 → 布局坐标 → 距离 → 消耗。用同一层相邻两格（距离 = NODE_GAP）
	var counts: Dictionary = Geometry.layer_counts(_pair_details())
	assert_eq(ApRules.cost_for_move({}, _detail(0, 0), _detail(0, 1), counts),
			ApRules.cost_by_distance({}, TYPE_COMBAT, Geometry.NODE_GAP),
			"cost_for_move 应与「距离 → 消耗」逐值一致（同一条公式，不是两份实现）")


func test_cost_for_move_across_layers_is_stable() -> void:
	## 跨层：距离由 layer 差与 idx 差共同决定——同一对节点永远同一价
	var counts: Dictionary = Geometry.layer_counts(_pair_details())
	var a: int = ApRules.cost_for_move({}, _detail(0, 0), _detail(2, 1), counts)
	var b: int = ApRules.cost_for_move({}, _detail(0, 0), _detail(2, 1), counts)
	assert_eq(a, b, "跨层移动的消耗应稳定")
	assert_true(a >= 1, "跨层移动至少 1 点")


# ═══════════════════════════════════════════════════════════════════════════════
# 三、配置解析（ap_distance_unit / ap_move_max）
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_config_falls_back_to_factory_defaults() -> void:
	## 空配置（读档重建后 _map_config 为空 / 地图表没写键）→ 出厂默认
	assert_eq(ApRules.distance_unit_of({}), ApRules.DEFAULT_DISTANCE_UNIT,
			"缺键 → 出厂单位距离")
	assert_eq(ApRules.move_max_of({}), ApRules.DEFAULT_MOVE_MAX, "缺键 → 出厂单次上限")
	assert_eq(ApRules.DEFAULT_DISTANCE_UNIT, 120.0, "出厂单位距离（见常量的标定注记）")


func test_distance_unit_is_read_from_config() -> void:
	## 「按地图配置扣」的核心：调小单位距离 = 整图涨价
	assert_true(ApRules.cost_by_distance({"ap_distance_unit": 60.0}, TYPE_COMBAT, 300.0)
			> ApRules.cost_by_distance({}, TYPE_COMBAT, 300.0),
			"单位距离减半 → 同距离更贵")
	assert_eq(ApRules.distance_unit_of({"ap_distance_unit": 240.0}), 240.0, "读取配置值")


func test_move_max_is_read_from_config() -> void:
	## 单次上限可配（某张图想更贵）——但仍不得低于 1
	assert_eq(ApRules.cost_by_distance({"ap_move_max": 2}, TYPE_COMBAT, 100000.0), 2,
			"上限配成 2 → 超远距离只收 2")
	assert_eq(ApRules.move_max_of({"ap_move_max": 7}), 7, "读取配置值")


func test_illegal_config_falls_back_to_defaults() -> void:
	## 配置是外部数据（地图表 / 存档 / 手改）：unit ≤ 0 会让除法爆炸，
	## max < 1 会让 clamp 出 0 或负数——按默认值处理比按 0 处理更不容易被无声利用
	assert_eq(ApRules.distance_unit_of({"ap_distance_unit": 0.0}),
			ApRules.DEFAULT_DISTANCE_UNIT, "unit = 0 → 默认（避免除零）")
	assert_eq(ApRules.distance_unit_of({"ap_distance_unit": -120.0}),
			ApRules.DEFAULT_DISTANCE_UNIT, "unit < 0 → 默认（负距离会算出负消耗）")
	assert_eq(ApRules.move_max_of({"ap_move_max": 0}), ApRules.DEFAULT_MOVE_MAX,
			"max = 0 → 默认（clamp 到 0 等于白走）")
	assert_eq(ApRules.move_max_of({"ap_move_max": -3}), ApRules.DEFAULT_MOVE_MAX,
			"max < 0 → 默认")


func test_malformed_config_does_not_crash() -> void:
	## 配置是外部数据：类型不对时不崩溃，回落默认
	assert_eq(ApRules.distance_unit_of({"ap_distance_unit": "bad"}),
			ApRules.DEFAULT_DISTANCE_UNIT, "非数 → 默认")
	assert_eq(ApRules.move_max_of({"ap_move_max": []}), ApRules.DEFAULT_MOVE_MAX,
			"数组 → 默认")


# ═══════════════════════════════════════════════════════════════════════════════
# 四、豁免优先（系统级不变量，不是地图可调项）
# ═══════════════════════════════════════════════════════════════════════════════

func test_exempt_types_always_cost_zero() -> void:
	assert_eq(ApRules.cost_by_distance({"ap_distance_unit": 1.0}, TYPE_BOSS, 9999.0), 0,
			"Boss 恒为 0（连距离都不算）")
	assert_eq(ApRules.cost_by_distance({}, TYPE_TELEPORT, 9999.0), 0, "传送恒为 0")
	assert_eq(ApRules.cost_by_distance({}, TYPE_ACTION_SPRING, 9999.0), 0, "灵泉恒为 0")


func test_exempt_wins_over_any_config() -> void:
	## 配置是自由数据，但豁免压得住它——豁免是系统级不变量
	## （GDD §节点类型一览「传送——不消耗行动力」「行动力泉——0」）
	var cfg: Dictionary = {"ap_distance_unit": 1.0, "ap_move_max": 99,
			"ap_cost": 5, "ap_costs": {TYPE_BOSS: 4, TYPE_TELEPORT: 4}}
	for type_id: int in [TYPE_BOSS, TYPE_TELEPORT, TYPE_ACTION_SPRING]:
		assert_eq(ApRules.cost_by_distance(cfg, type_id, 100000.0), 0,
				"豁免类型 %d 压得住任何配置" % type_id)


func test_non_exempt_neighbors_are_not_exempt() -> void:
	## 边界：与豁免类型相邻的枚举值不得被误判为豁免（原 8=REST / 0=ENTRY）
	for type_id: int in [TYPE_ENTRY, 8, TYPE_ELITE, TYPE_MEDITATION]:
		assert_true(ApRules.cost_by_distance({}, type_id, LAYER_GAP) >= 1,
				"非豁免类型 %d 应至少消耗 1" % type_id)


func test_exempt_cost_for_move_skips_geometry() -> void:
	## 全链路径上豁免同样恒 0——即使出发节点详情是空的（豁免先判，连距离都不算）
	assert_eq(ApRules.cost_for_move({}, {}, {"type": TYPE_BOSS}, {}), 0,
			"豁免类型在全链上恒 0")


# ═══════════════════════════════════════════════════════════════════════════════
# 五、遗留键（本轮有意改动——报告单列）
# ═══════════════════════════════════════════════════════════════════════════════

func test_legacy_ap_cost_key_no_longer_affects_movement() -> void:
	## ★ 有意改动：ap_cost / ap_costs 不再参与移动定价 ★
	## [br][b]为什么保留这两个键[/b]：旧存档与旧地图表里带着它们，删键会让读取报错；
	## 而「读它不改变任何行为」这件事必须有断言守着——否则将来有人顺手把它接回扣费，
	## 就会出现「同一张图两套定价」而没有任何测试会红。
	var base: int = ApRules.cost_by_distance({}, TYPE_COMBAT, 300.0)
	assert_eq(ApRules.cost_by_distance({"ap_cost": 9}, TYPE_COMBAT, 300.0), base,
			"改 ap_cost 不该影响消耗")
	assert_eq(ApRules.cost_by_distance({"ap_costs": {TYPE_COMBAT: 9}}, TYPE_COMBAT, 300.0),
			base, "改 ap_costs 不该影响消耗")


# ═══════════════════════════════════════════════════════════════════════════════
# 六、跨层同源（豁免集合三份副本必须一致）
# ═══════════════════════════════════════════════════════════════════════════════

func test_exempt_set_shared_across_layers() -> void:
	var expected: Array = [3, 6, 7]
	assert_eq(ApRules.AP_EXEMPT_TYPES, expected, "Feature 层规范副本")
	assert_eq(ES_SCRIPT.AP_EXEMPT_TYPES, expected, "继承链副本（判定与扣费共用）")
	assert_eq(NodeStateLogic.AP_EXEMPT_TYPES, expected, "UI 数值副本（headless 下独立加载）")


func test_exempt_set_sources_are_linked_not_copied() -> void:
	## 继承链那份从 ApRules 派生——改一处不会只改一半
	assert_eq(ES_SCRIPT.AP_EXEMPT_TYPES, ApRules.AP_EXEMPT_TYPES,
			"继承链常量与 ApRules 同源")


# ═══════════════════════════════════════════════════════════════════════════════
# 七、配置来源（探明表 / 难度档位兜底）
# ═══════════════════════════════════════════════════════════════════════════════

func test_catalog_config_keeps_legacy_ap_cost_for_old_saves() -> void:
	## 地图配置目录里的 [code]ap_cost[/code] 是本轮的[b]遗留键[/b]：移动定价不再读它，
	## 但它必须继续存在于表里——旧存档与旧地图表按它读，删键会让读取路径报错。
	## 这条断言守的是「兼容性」，不是「开销口径」（后者见上面第一节）。
	for map_id: StringName in CatalogScript.MAPS.keys():
		var config: Dictionary = CatalogScript.config_for(map_id, 1)
		assert_true(config.has("ap_cost"), "地图 %s 的配置仍带遗留键 ap_cost" % map_id)


func test_catalog_legacy_ap_cost_matches_difficulty_table() -> void:
	## 两处难度表（探明表目录 vs 继承链常量）的遗留键值必须一致——改一处漏另一处
	## 会让旧存档在两处读到不同的数
	for index: int in range(CatalogScript.DIFFICULTY_DEFAULTS.size()):
		var catalog_entry: Dictionary = CatalogScript.DIFFICULTY_DEFAULTS[index]
		var helper_entry: Dictionary = ES_SCRIPT.DIFFICULTY_CONFIGS[index]
		assert_true(catalog_entry.has("ap_cost"), "难度档 %d 目录侧含遗留键" % index)
		assert_eq(int(catalog_entry["ap_cost"]), int(helper_entry["ap_cost"]),
				"难度档 %d 两处遗留键一致" % index)


# ═══════════════════════════════════════════════════════════════════════════════
# 夹具：节点详情（含 layer / idx —— 距离定价的输入）
# ═══════════════════════════════════════════════════════════════════════════════

## 一对节点详情（层 0 的第 0 格 与 层 2 的第 1 格）——用于「同一对节点消耗稳定」。
func _pair_details() -> Dictionary:
	return {100: _detail(0, 0), 201: _detail(2, 1)}


## 节点详情（[param p_layer] 层、[param p_idx] 层内序号）。
func _detail(p_layer: int, p_idx: int) -> Dictionary:
	return {"type": TYPE_COMBAT, "layer": p_layer, "idx": p_idx}
