extends GutTest
## ExplorationMapCatalog / ExplorationEnemyPool 单测。[br]
## [br][b]覆盖[/b]：[br]
##   - 目录：登记地图带 [code]enemy_realm[/code]、未登记地图按难度兜底、
##     配置含生成器所需全部键；[br]
##   - 敌人池：按地图配置生成名册（数量范围 / 精英加成 / 模板缺失跳过告警 /
##     空池返回空名册）、同图同境界可复现。[br]
##
## 来源: GDD exploration-system.md §3 步骤⑥/§7、DEBT-EUI-006-3/-5。

const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")
const PoolScript := preload("res://src/feature/exploration/exploration_enemy_pool.gd")
const EnemyTemplateScript := preload("res://assets/enemies/enemy_template.gd")

## 生成器读取的配置键（缺一个就会静默退默认值）。
const REQUIRED_KEYS: Array = ["layers", "min_nodes", "max_nodes", "elite_count",
		"shop_count", "weights", "enemy_realm", "enemy_pool",
		"enemy_count_min", "enemy_count_max"]

var _templates: Dictionary = {}


func before_each() -> void:
	_templates = {
		&"san_xiu": _template(&"san_xiu", "散修", 1),
		&"mo_xiu": _template(&"mo_xiu", "魔修", 2),
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 地图配置目录
# ═══════════════════════════════════════════════════════════════════════════════

func test_registered_map_has_enemy_realm() -> void:
	var config: Dictionary = CatalogScript.config_for(&"qing_yun_jian_zong", 3)
	assert_eq(int(config.get("enemy_realm", 0)), 1,
			"青云剑宗是炼气地图——敌人境界 1（不随玩家境界 3 变）")


func test_registered_map_provides_all_generator_keys() -> void:
	for map_id: StringName in CatalogScript.MAPS.keys():
		var config: Dictionary = CatalogScript.config_for(map_id, 1)
		for key: String in REQUIRED_KEYS:
			assert_true(config.has(key), "地图 '%s' 缺配置键 %s" % [map_id, key])


func test_unregistered_map_falls_back_to_difficulty_defaults() -> void:
	# Arrange——未登记的地图
	# Act
	var config: Dictionary = CatalogScript.config_for(&"unknown_map", 3)
	# Assert——按玩家境界推难度档位（3 → HIGH），且仍带 enemy_realm
	assert_eq(int(config.get("layers", 0)), 5, "HIGH 档 5 层")
	assert_eq(int(config.get("min_nodes", 0)), 3, "HIGH 档每层 3-4 节点")
	assert_eq(int(config.get("enemy_realm", 0)), 3, "未登记地图按档位默认境界兜底")
	assert_false(bool(CatalogScript.has_map(&"unknown_map")), "未登记地图可被识别")


func test_enemy_realm_of_returns_map_value() -> void:
	assert_eq(CatalogScript.enemy_realm_of(&"dan_xia_gu"), 2, "丹霞谷敌人境界 2")
	assert_eq(CatalogScript.enemy_realm_of(&"gui_xu_fu_yun_lu"), 5, "归墟敌人境界 5")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 敌人池
# ═══════════════════════════════════════════════════════════════════════════════

func test_pool_generates_roster_within_configured_range() -> void:
	# Arrange
	var pool: RefCounted = PoolScript.new(_lookup)
	var config: Dictionary = CatalogScript.config_for(&"qing_yun_jian_zong", 1)
	# Act
	var roster: Array = pool.call(&"make_roster", &"qing_yun_jian_zong", 1, false, config)
	# Assert——数量落在 [min, max]，条目带模板 ID / 名称 / 境界
	assert_true(roster.size() >= int(config["enemy_count_min"]), "不少于配置下限")
	assert_true(roster.size() <= int(config["enemy_count_max"]), "不超过配置上限")
	for entry: Variant in roster:
		assert_true(_templates.has(StringName(str(entry["template_id"]))),
				"名册条目取自敌人池")
		assert_false(str(entry["name"]).is_empty(), "名称取模板 display_name")
		assert_true(int(entry["realm"]) >= 1, "境界取模板 realm")


func test_pool_elite_node_adds_bonus_enemies() -> void:
	# Arrange——同一地图同一境界，精英 vs 普通
	var pool: RefCounted = PoolScript.new(_lookup)
	var config: Dictionary = CatalogScript.config_for(&"xue_yuan_mi_jing", 1)
	# Act
	var normal: Array = pool.call(&"make_roster", &"xue_yuan_mi_jing", 1, false, config)
	var elite: Array = pool.call(&"make_roster", &"xue_yuan_mi_jing", 1, true, config)
	# Assert——精英加成生效（elite_bonus = 1）
	assert_eq(elite.size(), normal.size() + int(config.get("elite_bonus", 1)),
			"精英节点人数 = 普通人数 + elite_bonus")


func test_pool_is_reproducible_for_same_map_and_realm() -> void:
	# Arrange
	var config: Dictionary = CatalogScript.config_for(&"dan_xia_gu", 2)
	var pool: RefCounted = PoolScript.new(_lookup)
	# Act
	var first: Array = pool.call(&"make_roster", &"dan_xia_gu", 2, false, config)
	var second: Array = pool.call(&"make_roster", &"dan_xia_gu", 2, false, config)
	# Assert——同图同境界重入得到同一份名册（可复现）
	assert_eq(first, second, "同地图同境界的名册可复现")


func test_pool_skips_missing_template_and_warns_once() -> void:
	# Arrange——池里登记的模板在注册表中不存在
	var pool: RefCounted = PoolScript.new(_lookup)
	var config: Dictionary = {
		"enemy_pool": [{"template_id": &"ghost", "weight": 100}],
		"enemy_count_min": 2, "enemy_count_max": 2,
	}
	# Act
	var roster: Array = pool.call(&"make_roster", &"ghost_map", 1, false, config)
	# Assert——跳过缺失模板（不臆造敌人），且只告警一次、点名缺的模板 ID
	assert_eq(roster.size(), 0, "模板缺失时不臆造名册条目")
	var warnings: Array = _warnings_containing("ghost")
	assert_eq(warnings.size(), 1, "同一缺失模板只警告一次（不按节点刷屏）")


func test_pool_returns_empty_roster_for_empty_pool() -> void:
	# Arrange——地图未配敌人池
	var pool: RefCounted = PoolScript.new(_lookup)
	# Act
	var roster: Array = pool.call(&"make_roster", &"empty_map", 1, false, {"enemy_pool": []})
	# Assert——空名册（由开战校验给可读失败，不静默兜底）
	assert_eq(roster, [], "空池返回空名册")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 模板查询桩（缺失 ID 返回 null）。
func _lookup(p_template_id: StringName) -> Variant:
	return _templates.get(p_template_id)


## 收集本用例中「文本包含 [param p_text]」的 push_warning（[b]不消费[/b]——
## 计数与文案两条断言可并存，[method GutTest.assert_push_warning_count] 会消费）。
func _warnings_containing(p_text: String) -> Array:
	var found: Array = []
	for err: Variant in gut.error_tracker.get_errors_for_test():
		if err.is_push_warning() and err.contains_text(p_text):
			found.append(err)
	return found


## 造一个最小 EnemyTemplate。
func _template(p_id: StringName, p_name: String, p_realm: int) -> Resource:
	var template: Resource = EnemyTemplateScript.new()
	template.template_id = p_id
	template.display_name = p_name
	template.realm = p_realm
	return template
