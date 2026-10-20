extends GutTest
## hud Story 006 跨域只读方法单测：ExplorationSystem.get_total_layers()
## （LP 跨域预协调 2026-10-20 APPROVED WITH CONDITIONS 条件④——三例：
## 空缓存返回 1 / generate_map 后返回配置层数 / rebuild 后返回快照层数）。
##
## 测试策略（先例 test_dag_cache_rebuild.gd）：ES_SCRIPT.new() 构造
## ExplorationSystem 实例（非 Autoload），注入回调保证确定性。
## get_total_layers 为纯只读方法——不触达 GSM，无需真实 Autoload。
##
## Story 来源：production/epics/hud/story-006-exploration-hud-info.md
## Implementation Notes 层数条目（LP 条件④ BLOCKING）。

const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")

## 测试用确定性地图配置——MEDIUM 5 层（与注入回调联动，见 before_each）。
const CONFIG_LAYERS: int = 5
## 测试用随机 seed（确定性 DAG 生成先例——test_dag_cache_rebuild.gd）。
const TEST_SEED: int = 42


func before_each() -> void:
	var es: Node = ES_SCRIPT.new()
	set_meta(&"es", es)
	es.call("set_rng_seed", TEST_SEED)
	es.set("get_map_config_cb", Callable(func(_mid, _r):
		return es.get("DIFFICULTY_CONFIGS")[1].duplicate(true)))
	es.set("generate_enemy_roster_cb", Callable(func(_mid, _r, _is_elite):
		return [{"enemy_id": 1}]))
	es.set("get_event_pool_cb", Callable(func(_mid, _r):
		return ["event_a", "event_b"]))
	es.set("generate_shop_inventory_cb", Callable(func(_r):
		return {"items": [1, 2, 3]}))


func after_each() -> void:
	var es: Node = get_meta(&"es", null)
	if es != null:
		es.free()
		remove_meta(&"es")


# ============================================================================
# LP 条件④ 例 1：空缓存（_dag_ready=true 但 _node_details 空）返回 1
# ============================================================================

func test_exploration_get_total_layers_empty_cache_returns_one() -> void:
	## LP 条件①空集防御 + ④例 1：_ready 有三条 _dag_ready=true 但缓存空的
	## 路径——空缓存须返回安全默认值 1 而非崩溃/0。
	# Arrange —— 构造即空缓存；显式设 _dag_ready=true 模拟「就绪但空」路径
	var es: Node = get_meta(&"es")
	es.set("_dag_ready", true)
	# Act
	var total: int = es.call("get_total_layers")
	# Assert
	assert_eq(total, 1, "空缓存应返回安全默认值 1")


func test_exploration_get_total_layers_not_ready_returns_one() -> void:
	## 守卫先例（move_to_node/can_move_to/resolve_node——ADR-0014 R7）：
	## _dag_ready=false 时返回安全默认值 1。
	# Arrange —— 构造后未生成地图，_dag_ready 初始 false
	var es: Node = get_meta(&"es")
	assert_eq(es.get("_dag_ready"), false, "前置：_dag_ready 应为 false")
	# Act
	var total: int = es.call("get_total_layers")
	# Assert
	assert_eq(total, 1, "未就绪应返回安全默认值 1")


# ============================================================================
# LP 条件④ 例 2：generate_map 后返回配置层数
# ============================================================================

func test_exploration_get_total_layers_after_generate_returns_config_layers() -> void:
	## 例 2：enter_map（内含 generate_map）后——节点 ID 编码 layer*100+idx，
	## 最大 ID 整除 100 + 1 应等于配置层数（MEDIUM=5）。
	# Arrange —— before_each 注入 MEDIUM 配置（layers=CONFIG_LAYERS）
	var es: Node = get_meta(&"es")
	# Act
	es.call("enter_map", &"test_map", 1, 10)
	var total: int = es.call("get_total_layers")
	# Assert
	assert_eq(total, CONFIG_LAYERS,
			"生成后应返回配置层数 %d（节点 ID 编码 layer*100+idx 推导）" % CONFIG_LAYERS)


func test_exploration_get_total_layers_matches_max_node_id() -> void:
	## 例 2 交叉验证：返回值与 _node_details 最大键的编码层一致——
	## max_id/100 + 1（推导公式逐字锁定，防实现漂移）。
	# Arrange
	var es: Node = get_meta(&"es")
	es.call("enter_map", &"test_map", 1, 10)
	var details: Dictionary = es.get("_node_details")
	var expected: int = int(details.keys().max()) / 100 + 1
	# Act
	var total: int = es.call("get_total_layers")
	# Assert
	assert_eq(total, expected,
			"应等于 max(_node_details.keys())/100+1 = %d" % expected)


# ============================================================================
# LP 条件④ 例 3：rebuild_dag_cache 后返回快照层数
# ============================================================================

func test_exploration_get_total_layers_after_rebuild_returns_snapshot_layers() -> void:
	## 例 3：读档路径 rebuild_dag_cache（快照 graph/nodes 直接填充）后——
	## 从快照 _node_details 推导层数（快照含 4 层节点 ID 编码：0/100/200/300）。
	# Arrange —— 构造 4 层快照（ID 编码 layer*100+idx）
	var es: Node = get_meta(&"es")
	var snapshot_nodes: Dictionary = {
		0: {"type": 0, "layer": 0, "idx": 0},
		100: {"type": 1, "layer": 1, "idx": 0},
		200: {"type": 1, "layer": 2, "idx": 0},
		300: {"type": 3, "layer": 3, "idx": 0},
	}
	var map_data: Dictionary = {
		"graph": {0: [100], 100: [200], 200: [300], 300: []},
		"nodes": snapshot_nodes,
		"layers": [1, 1, 1, 1],
		"boss_node_id": 300,
		"path_count": 1,
	}
	# Act
	es.call("rebuild_dag_cache", &"loaded_map", map_data)
	var total: int = es.call("get_total_layers")
	# Assert
	assert_eq(total, 4, "重建 4 层快照后应返回 4（max ID 300 → 3+1）")


func test_exploration_get_total_layers_rebuild_overrides_generate() -> void:
	## 例 3 补充：生成 5 层后重建 2 层快照——返回值跟随最新缓存（2），
	## 证明不缓存计算结果（LP 明示：每次调用现算，无失效逻辑需求）。
	# Arrange —— 先生成 5 层
	var es: Node = get_meta(&"es")
	es.call("enter_map", &"test_map", 1, 10)
	assert_eq(es.call("get_total_layers"), 5, "前置：生成后为 5 层")
	# Act —— 重建 2 层快照
	var map_data: Dictionary = {
		"graph": {0: [100], 100: []},
		"nodes": {0: {"type": 0, "layer": 0, "idx": 0}, 100: {"type": 3, "layer": 1, "idx": 0}},
		"layers": [1, 1],
		"boss_node_id": 100,
		"path_count": 1,
	}
	es.call("rebuild_dag_cache", &"small_map", map_data)
	# Assert
	assert_eq(es.call("get_total_layers"), 2, "重建 2 层快照后应立即返回 2（无缓存残留）")
