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
		&"yao_shou": _template(&"yao_shou", "妖兽", 1),
		&"gui_xiu": _template(&"gui_xiu", "鬼修", 2),
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
# 3. 地图差异（敌人池至少 4 个模板，不同地图不同池）
# ═══════════════════════════════════════════════════════════════════════════════

func test_catalog_registers_at_least_four_enemy_templates() -> void:
	# Arrange——收集全部地图池里出现过的模板 ID
	var ids: Dictionary = {}
	for map_id: StringName in CatalogScript.MAPS.keys():
		for item: Variant in (CatalogScript.MAPS[map_id] as Dictionary).get("enemy_pool", []):
			ids[StringName(str((item as Dictionary)["template_id"]))] = true
	# Assert——至少四类敌人（不同地图才有可感知差异）
	assert_true(ids.size() >= 4, "地图池应至少覆盖 4 个敌人模板（实际 %d）" % ids.size())
	for tid: StringName in ids.keys():
		assert_true(_templates.has(tid), "池里的模板 '%s' 应有出厂模板" % tid)


func test_different_maps_use_different_pools() -> void:
	# Arrange——三张主题不同的地图
	var forest: Dictionary = CatalogScript.config_for(&"qing_yun_jian_zong")
	var blood: Dictionary = CatalogScript.config_for(&"xue_yuan_mi_jing")
	var ghost: Dictionary = CatalogScript.config_for(&"cang_xuan_gu_zhan_chang")
	# Assert——配比不同（不是所有图共用一份权重表）
	assert_ne(forest["enemy_pool"], blood["enemy_pool"], "青云剑宗与血渊秘境的敌人池应不同")
	assert_ne(blood["enemy_pool"], ghost["enemy_pool"], "血渊秘境与苍玄古战场的敌人池应不同")
	# 主题可断言：血渊以魔修为主、古战场以鬼修为主
	assert_eq(_top_template(blood["enemy_pool"]), &"mo_xiu", "血渊秘境主刷魔修")
	assert_eq(_top_template(ghost["enemy_pool"]), &"gui_xiu", "苍玄古战场主刷鬼修")


func test_pool_roster_entries_come_from_that_map_pool() -> void:
	# Arrange——古战场的池只含鬼修/魔修/散修
	var pool: RefCounted = PoolScript.new(_lookup)
	var config: Dictionary = CatalogScript.config_for(&"cang_xuan_gu_zhan_chang", 2)
	var allowed: Dictionary = {}
	for item: Variant in (config["enemy_pool"] as Array):
		allowed[StringName(str((item as Dictionary)["template_id"]))] = true
	# Act
	var roster: Array = pool.call(&"make_roster", &"cang_xuan_gu_zhan_chang", 2, false, config)
	# Assert——名册条目全部来自该图的池
	assert_true(roster.size() > 0, "古战场应生成非空名册")
	for entry: Variant in roster:
		var tid: StringName = StringName(str((entry as Dictionary)["template_id"]))
		assert_true(allowed.has(tid), "名册条目 '%s' 应来自古战场的敌人池" % tid)


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 地图 ID 命名统一（防回归）
# ═══════════════════════════════════════════════════════════════════════════════

func test_legacy_map_id_resolves_to_registered_config() -> void:
	# Arrange——章节表早期写法
	# Act
	var legacy: Dictionary = CatalogScript.config_for(&"cang_xuan_zhengdao_meng", 2)
	var canonical: Dictionary = CatalogScript.config_for(&"cang_xuan_zheng_dao_meng", 2)
	# Assert——历史写法解析到同一份配置（不掉进难度兜底）
	assert_eq(legacy, canonical, "历史写法与规范写法应得到同一份配置")
	assert_eq(CatalogScript.canonical_id(&"cang_xuan_zhengdao_meng"),
			&"cang_xuan_zheng_dao_meng", "别名表应把历史写法转成规范写法")
	assert_true(CatalogScript.has_map(&"cang_xuan_zhengdao_meng"),
			"历史写法应算已登记（同一张地图）")
	assert_false(CatalogScript.is_legacy_id(&"cang_xuan_zheng_dao_meng"),
			"规范写法不应被标记为历史写法")


func test_chapter_map_ids_are_registered_or_known_legacy() -> void:
	# Arrange——章节表里所有「已在地图选择界面出现」的地图 ID
	var story: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/StorySystem")
	assert_not_null(story, "防回归需要真实 StorySystem Autoload")
	var chapter_ids: Array = story.get_all_chapter_ids()
	var map_ids: Array = []
	for chapter_id: StringName in chapter_ids:
		var chapter: Dictionary = story.get_chapter_data(chapter_id)
		map_ids.append_array(chapter.get("maps", []))
		map_ids.append_array(chapter.get("completion", {}).get("unlock_maps", []))
	# Act——只挑「地图选择界面里有」的那批做严格校验（其余是尚未落地的新图）
	var selectable: Array = []
	for raw: Variant in map_ids:
		var map_id: StringName = StringName(str(raw))
		if CatalogScript.has_map(map_id):
			selectable.append(map_id)
	var unknown: Array = CatalogScript.unknown_map_ids(selectable)
	# Assert——章节表引用的可进入地图必须能被目录解析（拼错会静默掉进难度兜底）
	assert_true(selectable.size() > 0, "章节表应引用到至少一张已登记地图")
	assert_eq(unknown, [], "章节表里已登记地图的 ID 不应有拼写不一致：%s" % [unknown])


func test_chapter_legacy_spellings_no_longer_used() -> void:
	# Arrange——章节表已统一为规范写法
	var story: Node = (Engine.get_main_loop() as SceneTree).root.get_node_or_null("/root/StorySystem")
	assert_not_null(story, "防回归需要真实 StorySystem Autoload")
	var used_legacy: Array = []
	for chapter_id: StringName in story.get_all_chapter_ids():
		var chapter: Dictionary = story.get_chapter_data(chapter_id)
		var refs: Array = []
		refs.append_array(chapter.get("maps", []))
		refs.append_array(chapter.get("completion", {}).get("unlock_maps", []))
		for raw: Variant in refs:
			if CatalogScript.is_legacy_id(StringName(str(raw))):
				used_legacy.append(raw)
	# Assert——章节表不再写历史拼法（别名表只留作存档/外部数据兼容）
	assert_eq(used_legacy, [], "章节表不应再引用历史拼法：%s" % [used_legacy])


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 模板查询桩（缺失 ID 返回 null）。
func _lookup(p_template_id: StringName) -> Variant:
	return _templates.get(p_template_id)


## 池里权重最高的模板 ID（主题断言用）。
func _top_template(p_pool: Array) -> StringName:
	var best: StringName = &""
	var best_weight: int = -1
	for item: Variant in p_pool:
		var weight: int = int((item as Dictionary).get("weight", 0))
		if weight > best_weight:
			best_weight = weight
			best = StringName(str((item as Dictionary)["template_id"]))
	return best


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
