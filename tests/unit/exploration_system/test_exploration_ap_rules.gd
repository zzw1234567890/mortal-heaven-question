extends GutTest
## 探索行动力（AP）开销规则单元测试。[br]
## [br][b]覆盖[/b]：[br]
##   · 配置解析——[code]ap_cost[/code] 地图默认开销 / [code]ap_costs[/code] 按类型
##     覆盖 / 缺键回落 GDD 默认 1 / 非法值（负数）回落默认而不是「回血」；[br]
##   · 豁免优先——Boss/传送/灵泉恒为 0，配置里写非零也不生效；[br]
##   · 跨层同源——Feature 层 [code]ExplorationApRules.AP_EXEMPT_TYPES[/code]、
##     继承链 [code]ExplorationSystem.AP_EXEMPT_TYPES[/code]、UI 层
##     [code]NodeStateLogic.AP_EXEMPT_TYPES[/code] 三者逐项一致（UI 是数值副本，
##     headless 下不加载 Feature 层，只能靠本断言锁定）。[br]
## [br][b]隔离[/b]：全部为纯函数 / 常量断言——不读写 GSM、不实例化任何系统。[br]
##
## 来源: design/gdd/action-point-system.md §公式 3 移动后行动力 + §调优参数
## （每格消耗 1，安全范围 1-2）、design/gdd/exploration-system.md §节点类型一览。

const ApRules := preload("res://src/feature/exploration/exploration_ap_rules.gd")
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


# ═══════════════════════════════════════════════════════════════════════════════
# 配置解析
# ═══════════════════════════════════════════════════════════════════════════════

func test_empty_config_falls_back_to_gdd_default() -> void:
	## 空配置（读档重建后 _map_config 为空 / 地图表没写键）→ GDD 默认 1
	assert_eq(ApRules.cost_for({}, TYPE_COMBAT), 1, "缺键 → GDD 默认 1")
	assert_eq(ApRules.cost_for({}, TYPE_EVENT), 1, "非战斗类型同口径")
	assert_eq(ApRules.DEFAULT_COST, 1, "默认值本身即 GDD §调优参数 的出厂值")


func test_map_default_cost_is_read_from_config() -> void:
	## 「按地图配置扣」的核心：ap_cost 是地图级默认开销
	assert_eq(ApRules.cost_for({"ap_cost": 2}, TYPE_COMBAT), 2, "本图开销 2")
	assert_eq(ApRules.cost_for({"ap_cost": 3}, TYPE_MEDITATION), 3, "同图所有非豁免类型一致")


func test_per_type_override_beats_map_default() -> void:
	## ap_costs 按节点类型覆盖——覆盖命中时不看 ap_cost
	var cfg: Dictionary = {"ap_cost": 1, "ap_costs": {TYPE_ELITE: 2}}
	assert_eq(ApRules.cost_for(cfg, TYPE_ELITE), 2, "精英覆盖为 2")
	assert_eq(ApRules.cost_for(cfg, TYPE_COMBAT), 1, "未覆盖的类型回落 ap_cost")


func test_zero_cost_config_is_honored() -> void:
	## 显式写 0 = 本图该类型免费（合法的地图设计，不是缺键）
	assert_eq(ApRules.cost_for({"ap_cost": 0}, TYPE_COMBAT), 0, "ap_cost=0 → 免费")
	assert_eq(ApRules.cost_for({"ap_costs": {TYPE_COMBAT: 0}}, TYPE_COMBAT), 0,
			"类型覆盖 0 → 免费")


func test_negative_config_falls_back_to_default() -> void:
	## 负数开销会让移动「回血」（外部数据写坏 / 手改存档）——按默认值处理
	assert_eq(ApRules.cost_for({"ap_cost": -3}, TYPE_COMBAT), 1,
			"负 ap_cost → 回落默认 1（不按 0，免得被无声利用）")
	assert_eq(ApRules.cost_for({"ap_costs": {TYPE_COMBAT: -1}}, TYPE_COMBAT), 1,
			"负类型覆盖 → 回落默认 1")


func test_malformed_config_does_not_crash() -> void:
	## 配置是外部数据：ap_costs 不是字典时不崩溃，走 ap_cost 口径
	assert_eq(ApRules.cost_for({"ap_costs": "bad", "ap_cost": 2}, TYPE_COMBAT), 2,
			"ap_costs 类型不对 → 回落 ap_cost")
	assert_eq(ApRules.cost_for({"ap_costs": []}, TYPE_COMBAT), 1, "空数组 → 默认 1")


# ═══════════════════════════════════════════════════════════════════════════════
# 豁免优先（系统级不变量，不是地图可调项）
# ═══════════════════════════════════════════════════════════════════════════════

func test_exempt_types_always_cost_zero() -> void:
	assert_eq(ApRules.cost_for({"ap_cost": 5}, TYPE_BOSS), 0, "Boss 恒为 0")
	assert_eq(ApRules.cost_for({"ap_cost": 5}, TYPE_TELEPORT), 0, "传送恒为 0")
	assert_eq(ApRules.cost_for({"ap_cost": 5}, TYPE_ACTION_SPRING), 0, "灵泉恒为 0")


func test_exempt_wins_over_non_zero_override() -> void:
	## 配置给豁免类型写了非零值也不生效——豁免在解析里先判
	var cfg: Dictionary = {"ap_costs": {TYPE_BOSS: 4, TYPE_TELEPORT: 4, TYPE_ACTION_SPRING: 4}}
	assert_eq(ApRules.cost_for(cfg, TYPE_BOSS), 0, "Boss 覆盖被豁免压制")
	assert_eq(ApRules.cost_for(cfg, TYPE_TELEPORT), 0, "传送覆盖被豁免压制")
	assert_eq(ApRules.cost_for(cfg, TYPE_ACTION_SPRING), 0, "灵泉覆盖被豁免压制")


func test_non_exempt_neighbors_are_not_exempt() -> void:
	## 边界：与豁免类型相邻的枚举值不得被误判为豁免（原 8=REST / 0=ENTRY）
	assert_eq(ApRules.cost_for({"ap_cost": 1}, TYPE_ENTRY), 1, "入口非豁免")
	assert_eq(ApRules.cost_for({"ap_cost": 1}, 8), 1, "回复点(8)非豁免")
	assert_eq(ApRules.cost_for({"ap_cost": 1}, TYPE_ELITE), 1, "精英(2)非豁免")


# ═══════════════════════════════════════════════════════════════════════════════
# 跨层同源（豁免集合三份副本必须一致）
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
# 配置来源（探明表 / 难度档位兜底）
# ═══════════════════════════════════════════════════════════════════════════════

func test_catalog_config_carries_ap_cost() -> void:
	## 地图配置目录是生产路径的唯一配置来源——每张地图都必须带 ap_cost，
	## 否则 [method _get_map_config] 的返回值里缺键，扣费只能靠默认值兜
	for map_id: StringName in CatalogScript.MAPS.keys():
		var config: Dictionary = CatalogScript.config_for(map_id, 1)
		assert_true(config.has("ap_cost"), "地图 %s 的配置含 ap_cost" % map_id)
		assert_eq(int(config["ap_cost"]), 1, "地图 %s 出厂开销为 1" % map_id)


func test_catalog_difficulty_defaults_carry_ap_cost() -> void:
	## 未登记地图走难度档位兜底——档位默认值同样必须带 ap_cost
	for index: int in range(CatalogScript.DIFFICULTY_DEFAULTS.size()):
		var entry: Dictionary = CatalogScript.DIFFICULTY_DEFAULTS[index]
		assert_true(entry.has("ap_cost"), "难度档 %d 默认值含 ap_cost" % index)
		assert_eq(int(entry["ap_cost"]), ApRules.DEFAULT_COST,
				"难度档 %d 出厂开销与 GDD 默认值一致" % index)


func test_catalog_ap_cost_matches_difficulty_configs_table() -> void:
	## 两处难度表（探明表目录 vs 继承链常量）的 ap_cost 必须同源——
	## 改一处漏另一处会让「按地图扣」与「兜底扣」给出不同开销
	for index: int in range(CatalogScript.DIFFICULTY_DEFAULTS.size()):
		var catalog_entry: Dictionary = CatalogScript.DIFFICULTY_DEFAULTS[index]
		var helper_entry: Dictionary = ES_SCRIPT.DIFFICULTY_CONFIGS[index]
		assert_eq(int(catalog_entry["ap_cost"]), int(helper_entry["ap_cost"]),
				"难度档 %d 两处 ap_cost 一致" % index)
