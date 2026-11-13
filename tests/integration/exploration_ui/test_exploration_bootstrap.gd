extends GutTest
## 探索系统生产装配 —— 真实 enter_map 的敌人池与地图境界。[br]
## [br][b]本文件补的断链[/b]：此前 [code]get_map_config_cb[/code] /
## [code]generate_enemy_roster_cb[/code] 在生产路径没有任何注入点——真实
## [code]enter_map[/code] 生成的战斗节点名册恒为空（弹窗「未知 ×0」、开战校验
## 直接失败），节点等级也只能拿玩家境界兜底（DEBT-EUI-006-3 / -5）。[br]
## [br][b]覆盖[/b]：[br]
##   1. 装配后真实 [code]enter_map[/code] 产出的战斗节点名册非空，条目可读；[br]
##   2. 节点等级取地图配置的 [code]enemy_realm[/code]，不随玩家境界上涨；[br]
##   3. 地图配置缺 [code]enemy_realm[/code] 时回退玩家境界且告警可观测；[br]
##   4. 生成器产出的节点能直接过开战校验（模板 ID / 等级 / 掉落齐备）；[br]
##   5. 装配后商店节点有真实货架（[code]generate_shop_inventory_cb[/code] 的生产注入）。[br]
##
## 来源: GDD exploration-system.md §3 步骤⑥/⑦、§4 节点交互表、ADR-0014 §决策 2/3、
## DEBT-EUI-006-3、DEBT-EUI-006-5。

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const BootstrapScript := preload("res://src/feature/exploration/exploration_bootstrap.gd")
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")
const ContextScript := preload("res://src/feature/combat/combat_launch_context.gd")
const ShopInventoryScript := preload(
		"res://src/feature/exploration/exploration_shop_inventory.gd")
## 卡牌模板就位助手（异步加载的同步推进）。
const PrimerScript := preload("res://tests/integration/exploration_ui/card_template_primer.gd")

## 玩家出战阵容（测试注入——避开 GSM 角色位）。
const PLAYER_ROSTER: Array = [3, 5]

## 炼气（境界 1）货架候选池的首件——模板就位的判定锚点（价格档 10）。
const SHELF_CARD_ID: StringName = &"pei_yuan_dan"
## 找商店节点的最大进入次数（商店权重 15/100，12 次几乎必然命中）。
const SHOP_SCAN_LIMIT: int = 12

var es: Node = null
var ai: Node = null
var gsm: Node = null


func before_each() -> void:
	ContextScript.clear()
	es = ES_SCRIPT.new()
	es.call("set_rng_seed", 42)
	ai = get_node_or_null(NodePath("/root/AISystem"))
	gsm = get_node_or_null(NodePath("/root/GameStateManager"))
	_reset_gsm()


func after_each() -> void:
	ContextScript.clear()
	_reset_gsm()
	if es != null:
		es.free()
		es = null


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 真实 enter_map → 名册非空
# ═══════════════════════════════════════════════════════════════════════════════

func test_real_enter_map_produces_non_empty_roster() -> void:
	# Arrange——生产装配（地图目录 + 敌人池 + 真实 AISystem 模板）
	assert_true(BootstrapScript.mount(es, ai), "装配应成功")
	# Act——真实进入地图（青云剑宗，玩家炼气）
	var result: Dictionary = es.call("enter_map", &"qing_yun_jian_zong", 1, 5)
	# Assert——战斗/精英节点的名册非空，条目带模板 ID 与名称
	var combat_details: Array = _combat_details(result)
	assert_true(combat_details.size() > 0, "地图应至少产出一个战斗类节点")
	for detail: Dictionary in combat_details:
		var roster: Array = detail.get("enemy_roster", [])
		assert_true(roster.size() > 0, "真实 enter_map 的战斗节点名册不得为空")
		for entry: Variant in roster:
			assert_false(str((entry as Dictionary).get("template_id", "")).is_empty(),
					"名册条目应带模板 ID")
			assert_false(str((entry as Dictionary).get("name", "")).is_empty(),
					"名册条目应带可读名称（弹窗据此渲染）")


func test_real_enter_map_roster_templates_exist_in_ai_system() -> void:
	# Arrange
	assert_not_null(ai, "集成测试需要真实 AISystem Autoload")
	BootstrapScript.mount(es, ai)
	# Act
	var result: Dictionary = es.call("enter_map", &"xue_yuan_mi_jing", 1, 5)
	# Assert——名册里的模板都能在 AISystem 注册表查到（否则开战会拿不到敌人）
	var seen: int = 0
	for detail: Dictionary in _combat_details(result):
		for entry: Variant in detail.get("enemy_roster", []):
			var tid: StringName = StringName(str((entry as Dictionary).get("template_id", "")))
			assert_true(bool(ai.call(&"has_template", tid)),
					"名册模板 '%s' 应在 AISystem 注册表中" % tid)
			seen += 1
	assert_true(seen > 0, "应至少检查到一个名册条目")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 等级取地图配置（不随玩家境界上涨）
# ═══════════════════════════════════════════════════════════════════════════════

func test_node_level_follows_map_enemy_realm_not_player_realm() -> void:
	# Arrange——玩家金丹（3），回炼气地图（地图 enemy_realm = 1）
	BootstrapScript.mount(es, ai)
	# Act
	var result: Dictionary = es.call("enter_map", &"qing_yun_jian_zong", 3, 5)
	# Assert——节点等级仍是地图境界 1（GDD §7「敌人强度按地图本身境界」）
	for detail: Dictionary in _combat_details(result):
		assert_eq(int(detail.get("enemy_level", -1)), 1,
				"高境界玩家回低境界地图，节点等级仍取地图 enemy_realm")
		assert_eq(int((detail["encounter"] as Dictionary)["enemy_level"]), 1,
				"子字典等级与顶层同值")


func test_node_level_differs_by_map() -> void:
	# Arrange——同境界玩家进两张不同境界的地图
	BootstrapScript.mount(es, ai)
	# Act
	var low: Dictionary = es.call("enter_map", &"qing_yun_jian_zong", 2, 5)
	var high: Dictionary = es.call("enter_map", &"dan_xia_gu", 2, 5)
	# Assert——地图境界不同 → 节点等级不同（地图配置真的被读到）
	assert_eq(_first_level(low), 1, "青云剑宗（炼气图）节点等级 1")
	assert_eq(_first_level(high), 2, "丹霞谷（筑基图）节点等级 2")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 缺 enemy_realm → 回退玩家境界且告警可观测
# ═══════════════════════════════════════════════════════════════════════════════

func test_missing_enemy_realm_falls_back_to_player_realm_with_warning() -> void:
	# Arrange——旧配置：装配套上后把地图配置换成缺键版本
	BootstrapScript.mount(es, ai)
	var legacy: Dictionary = CatalogScript.config_for(&"qing_yun_jian_zong", 3)
	legacy.erase("enemy_realm")
	es.set("get_map_config_cb", Callable(func(_mid, _r): return legacy.duplicate(true)))
	# Act
	var result: Dictionary = es.call("enter_map", &"qing_yun_jian_zong", 3, 5)
	# Assert——回退玩家境界 3，且只告警一次、文案点名缺的键
	assert_eq(_first_level(result), 3, "缺 enemy_realm 时回退玩家境界（旧配置兼容）")
	var warnings: Array = _warnings_containing("enemy_realm")
	assert_eq(warnings.size(), 1, "缺键只警告一次（不按节点刷屏），且文案点名该键")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 生成器节点 → 开战上下文直通
# ═══════════════════════════════════════════════════════════════════════════════

func test_generated_node_passes_launch_validation() -> void:
	# Arrange
	BootstrapScript.mount(es, ai)
	var result: Dictionary = es.call("enter_map", &"qing_yun_jian_zong", 1, 5)
	var detail: Dictionary = _combat_details(result)[0]
	# Act——生成器写出的节点直接喂给开战上下文
	var context: Dictionary = ContextScript.build(101, &"combat",
			detail.get("enemy_roster", []), PLAYER_ROSTER, detail)
	# Assert——真实生产数据可开战（模板 ID / 等级 / 掉落齐备）
	assert_eq(ContextScript.validate(context), "", "生产装配产出的节点应能直接开战")
	assert_true((context[ContextScript.KEY_TEMPLATE_IDS] as Array).size() > 0,
			"模板 ID 非空")
	assert_eq(int(context[ContextScript.KEY_ENEMY_LEVEL]), 1, "等级取地图境界")
	assert_true((context[ContextScript.KEY_REWARDS] as Dictionary).size() > 0,
			"掉落由出厂模板 reward_config 聚合（不恒为空）")


func test_mount_is_idempotent_and_survives_missing_ai() -> void:
	# Arrange——重复装配 + AISystem 缺失（模板查询退化，不崩溃）
	assert_true(BootstrapScript.mount(es, ai), "首次装配成功")
	assert_true(BootstrapScript.mount(es, null), "重复装配（无 AI 注入）仍成功")
	# Act
	var result: Dictionary = es.call("enter_map", &"qing_yun_jian_zong", 1, 5)
	# Assert——名册仍由敌人池生成（模板查询在调用时才解析 Autoload）
	assert_true(_combat_details(result).size() > 0, "地图仍能生成战斗节点")
	assert_true(BootstrapScript.mount(null, ai) == false, "探索系统缺失时装配返回 false")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 商店货架 —— generate_shop_inventory_cb 的生产注入
# ═══════════════════════════════════════════════════════════════════════════════

func test_real_enter_map_shop_nodes_carry_non_empty_inventory() -> void:
	# Arrange——生产装配（此前该回调没有注入点，商店节点恒为空货架）+ 模板就位
	assert_true(BootstrapScript.mount(es, ai), "装配应成功")
	_prepare_card_templates()
	# Act——真实进入地图（商店节点是加权随机分配的结果，按 entry_count 扫描到第一张
	# 含商店节点的图；seed 固定 → 扫到的是哪一张图也是确定的）
	var shops: Array = _scan_for_shop_nodes()
	# Assert——货架非空，条目带卡牌 ID 与正价格（面板据此上架）
	assert_true(shops.size() > 0, "连续进入该地图应至少产出一个商店节点")
	for detail: Dictionary in shops:
		var inventory: Dictionary = detail.get("inventory", {})
		var items: Array = inventory.get("items", [])
		assert_true(items.size() > 0, "真实 enter_map 的商店节点货架不得为空")
		for entry: Variant in items:
			var item: Dictionary = entry
			assert_false(str(item.get("card_id", "")).is_empty(), "货架条目应带卡牌 ID")
			assert_true(int(item.get("price", 0)) > 0, "货架条目应带正价格")
			assert_true(int(item.get("stock", 0)) > 0, "货架条目应有库存")


func test_generated_shop_inventory_items_are_real_card_templates() -> void:
	# 货架上的卡必须是真模板——否则面板点下去建不出实例（买不成）
	_prepare_card_templates()
	var inventory: Dictionary = ShopInventoryScript.make_for_realm(1)
	var items: Array = inventory.get("items", [])
	assert_true(items.size() >= 2, "低境界货架至少 2 件（ITEM_COUNT_LOW）")
	for entry: Variant in items:
		var card_id: StringName = StringName(str((entry as Dictionary).get("card_id", "")))
		assert_true(CardSystem.has_template(card_id),
				"货架卡牌 '%s' 应在 CardSystem 注册表中" % card_id)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 收集本用例中「文本包含 [param p_text]」的 push_warning（不消费——计数与
## 文案两条断言可并存，[method GutTest.assert_push_warning_count] 会消费）。
func _warnings_containing(p_text: String) -> Array:
	var found: Array = []
	for err: Variant in gut.error_tracker.get_errors_for_test():
		if err.is_push_warning() and err.contains_text(p_text):
			found.append(err)
	return found


## 地图结果里的战斗/精英节点详情（按节点 ID 升序，便于取「第一个」）。
func _combat_details(p_result: Dictionary) -> Array:
	var nodes: Dictionary = p_result.get("nodes", {})
	var ids: Array = nodes.keys()
	ids.sort()
	var details: Array = []
	for node_id: int in ids:
		var detail: Dictionary = nodes[node_id]
		var ntype: int = int(detail.get("type", -1))
		if ntype == 1 or ntype == 2:  # COMBAT / ELITE
			details.append(detail)
	return details


## 地图结果里的商店节点详情（按节点 ID 升序）。
func _shop_details(p_result: Dictionary) -> Array:
	var nodes: Dictionary = p_result.get("nodes", {})
	var ids: Array = nodes.keys()
	ids.sort()
	var details: Array = []
	for node_id: int in ids:
		var detail: Dictionary = nodes[node_id]
		if int(detail.get("type", -1)) == 5:  # NodeType.SHOP
			details.append(detail)
	return details


## 反复进入地图直到某一张图产出商店节点，返回那一张图的商店详情。[br]
## [br][b]为什么要扫[/b]：商店节点是加权随机的产物（权重 15/100），单张图不保证
## 有商店——而 [code]enter_map[/code] 每次都会把 [code]entry_count[/code] 递增并写入
## GSM，seed 随之加扰，连进多次自然遍历不同图。seed 固定 → 扫到哪一张是确定的，
## 用例可复现。[br]
## [br]扫描上限 [constant SHOP_SCAN_LIMIT] 次；一次都没扫到时返回空数组（断言失败
## 而非静默通过）。
func _scan_for_shop_nodes() -> Array:
	for _attempt: int in range(SHOP_SCAN_LIMIT):
		var result: Dictionary = es.call("enter_map", &"qing_yun_jian_zong", 1, 5)
		var shops: Array = _shop_details(result)
		if not shops.is_empty():
			return shops
	return []


## 推进 CardSystem 的异步模板加载，直到货架候选池的首件可查（驱动逻辑见
## [CardTemplatePrimer]——多个用例文件共用）。[br]
## [br][b]为什么必须在 enter_map 之前[/b]：货架的 [code]price[/code] 由模板稀有度
## 定档，生成期查不到模板的候选会被剔除——模板没就位时货架是空的（这正是被断言
## 的行为，所以不能让它假通过）。
func _prepare_card_templates() -> void:
	assert_true(PrimerScript.prime(CardSystem, SHELF_CARD_ID),
			"卡牌模板 %s 应能就位（否则货架必然为空，断言无意义）" % SHELF_CARD_ID)


## 第一个战斗节点的等级（无战斗节点时返回 -1）。
func _first_level(p_result: Dictionary) -> int:
	var details: Array = _combat_details(p_result)
	if details.is_empty():
		return -1
	return int((details[0] as Dictionary).get("enemy_level", -1))


## 重置 GSM 探索域（enter_map 会写 current_map / ap / map_states）。
func _reset_gsm() -> void:
	if gsm == null:
		return
	gsm.exploration = {
		"current_map": &"",
		"node_position": {"layer": 0, "idx": 0},
		"visited_nodes": [],
		"action_points": 0,
		"max_action_points": 0,
		"map_states": {},
	}
	gsm.set("_signal_chain_depth", 0)
	var router: Variant = gsm.get("_signal_router")
	if router != null:
		router.set("_pending_changes", [])
