extends GutTest
## 事件选取验收——pick_for_node「按玩家境界筛选 + 可注入 rng 随机」。
##
## 覆盖：境界筛选（min_realm 高于玩家的事件不进候选）、境界下限兜底（载荷异常
## 按炼气期，不把候选池筛空）、无 rng 的按节点取模（可复现）、有 rng 的同种子
## 复现、候选为空返回 null、全境界下与 pick_by_index 的等价交叉验证。

const EventSystemScript := preload("res://src/feature/exploration_event_system.gd")
const SelectorScript := preload("res://src/feature/exploration_event_selector.gd")

## 生产数据里 min_realm = 2 的事件（境界筛选的实证样本）。
const HIGH_REALM_EVENTS: Array = ["chain_001", "xie_yue_san_xing_001"]
const REALM_LIANQI: int = 1
const REALM_ZHUJI: int = 2
const REALM_HUASHEN: int = 5
const EXPECTED_TOTAL: int = 7

var _system: RefCounted = null


func before_each() -> void:
	_system = EventSystemScript.new()
	_system.call(&"load_events")


func _eligible(p_realm: int) -> Array:
	return SelectorScript.eligible_ids(_system, p_realm)


func _pick(p_node_id: int, p_realm: int,
		p_rng: RandomNumberGenerator = null) -> Variant:
	return _system.call(&"pick_for_node", p_node_id, p_realm, p_rng)


# === 境界筛选 ==================================================================

func test_lianqi_excludes_high_realm_events() -> void:
	var ids: Array = _eligible(REALM_LIANQI)
	for high: String in HIGH_REALM_EVENTS:
		assert_false(ids.has(high), "炼气期不应遇到高境界事件：%s" % high)
	assert_eq(ids.size(), EXPECTED_TOTAL - HIGH_REALM_EVENTS.size(),
			"炼气期候选数应为 7 - 2 = 5")


func test_zhuji_includes_all_events() -> void:
	assert_eq(_eligible(REALM_ZHUJI).size(), EXPECTED_TOTAL,
			"筑基期应解锁全部事件")


func test_realm_below_floor_falls_back_to_lianqi() -> void:
	assert_eq(_eligible(0).size(), _eligible(REALM_LIANQI).size(),
			"realm=0（载荷异常）应按炼气期兜底")
	assert_eq(_eligible(-3).size(), _eligible(REALM_LIANQI).size(),
			"负境界应按炼气期兜底")


# === 选取 ======================================================================

func test_pick_without_rng_is_deterministic_by_node() -> void:
	var first: Variant = _pick(0, REALM_LIANQI)
	var again: Variant = _pick(0, REALM_LIANQI)
	assert_eq(str(first.get(&"event_id")), str(again.get(&"event_id")),
			"无 rng 时同一节点应取同一事件")


func test_pick_without_rng_wraps_by_candidate_count() -> void:
	var count: int = _eligible(REALM_LIANQI).size()
	var base: Variant = _pick(0, REALM_LIANQI)
	var wrapped: Variant = _pick(count, REALM_LIANQI)
	assert_eq(str(base.get(&"event_id")), str(wrapped.get(&"event_id")),
			"节点 id 应按候选数取模回绕")


func test_pick_without_rng_stays_in_eligible_set() -> void:
	var eligible: Array = _eligible(REALM_LIANQI)
	for node_id: int in range(eligible.size() * 3):
		var def: Variant = _pick(node_id, REALM_LIANQI)
		assert_true(eligible.has(str(def.get(&"event_id"))),
				"炼气期取事件不得越出候选：node=%d" % node_id)


func test_pick_with_seeded_rng_is_reproducible() -> void:
	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 20261112
	var pick_a: Variant = _pick(42, REALM_LIANQI, rng_a)
	var rng_b := RandomNumberGenerator.new()
	rng_b.seed = 20261112
	var pick_b: Variant = _pick(42, REALM_LIANQI, rng_b)
	assert_eq(str(pick_a.get(&"event_id")), str(pick_b.get(&"event_id")),
			"同种子应取同一事件")


func test_pick_with_rng_stays_in_eligible_set() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var eligible: Array = _eligible(REALM_LIANQI)
	for i in range(20):
		var def: Variant = _pick(i, REALM_LIANQI, rng)
		assert_true(eligible.has(str(def.get(&"event_id"))),
				"随机选取不得越出候选：第 %d 次" % i)


# === 边界 ======================================================================

func test_empty_registry_returns_null() -> void:
	# 未装载事件的系统——候选为空返回 null（调用方不弹面板、不报错）。
	var empty: RefCounted = EventSystemScript.new()
	assert_null(empty.call(&"pick_for_node", 0, REALM_HUASHEN, null),
			"空注册表应返回 null")


func test_full_realm_pick_matches_pick_by_index() -> void:
	# 交叉验证：化神期（全事件可见）无 rng 选取与既有 pick_by_index 同序同结果。
	for index: int in range(EXPECTED_TOTAL):
		var by_node: Variant = _pick(index, REALM_HUASHEN)
		var by_index: Variant = _system.call(&"pick_by_index", index)
		assert_eq(str(by_node.get(&"event_id")), str(by_index.get(&"event_id")),
				"全境界下两条取法应一致：index=%d" % index)
