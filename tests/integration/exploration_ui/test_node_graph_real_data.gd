extends GutTest
## 节点图 UI 读真实数据 —— 真实 enter_map → NodeGraphScreen 渲染系统节点。[br]
## [br][b]本文件补的断链[/b]：此前节点图由 [code]map_generated_stub[/code] 驱动
## （探索系统没有 [code]map_generated[/code] 信号），真实数据链虽已通、UI 仍画
## stub 样本——「点哪张图都看到同一张 12 节点图」。本文件让真实探索系统进入地图，
## 断言节点图渲染的就是系统生成的那张图。[br]
## [br][b]覆盖[/b]：[br]
##   1. 真实 [method ExplorationSystem.enter_map] 后，渲染节点数与系统一致；[br]
##   2. 渲染的节点 ID 集合与系统节点详情完全一致（不是 stub 样本）；[br]
##   3. [method NodeGraphScreen.is_using_stub_source] 为 false（无 stub 标记）；[br]
##   4. 换一张地图 → 节点图跟着换（地图差异可见）；[br]
##   5. 无系统时降级到 stub（保留路径 + 显式标记）。[br]
##
## 来源: ADR-0014 §决策 3、ADR-0031 §2、story-003 数据契约、本轮任务要求。

const NodeGraphScreenScene: PackedScene = preload("res://src/ui/exploration/node_graph_screen.tscn")
const ES_SCRIPT := preload("res://src/feature/exploration_system.gd")
const BootstrapScript := preload("res://src/feature/exploration/exploration_bootstrap.gd")
const DATA_STUB := preload("res://src/ui/exploration/node_graph_data_stub.gd")
const NODE_LOGIC := preload("res://src/ui/exploration/node_state_logic.gd")

var es: Node = null
var gsm: Node = null
## 用例前的玩家境界（after_each 还原——本文件会读它决定进图参数）。
var _realm_before: int = 1


func before_each() -> void:
	es = ES_SCRIPT.new()
	es.call("set_rng_seed", 42)
	BootstrapScript.mount(es, get_node_or_null(NodePath("/root/AISystem")))
	gsm = get_node_or_null(NodePath("/root/GameStateManager"))
	_realm_before = int(gsm.player.get("realm", 1)) if gsm != null else 1
	if gsm != null:
		gsm.player.realm = 1
	_reset_gsm()


func after_each() -> void:
	_reset_gsm()
	if gsm != null:
		gsm.player.realm = _realm_before
	if es != null:
		es.free()
		es = null


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 真实数据渲染（核心断言）
# ═══════════════════════════════════════════════════════════════════════════════

func test_real_enter_map_renders_system_node_count() -> void:
	# Arrange——注入真实系统，触发加载（屏幕调 enter_map，系统广播信号）
	var screen: Control = _mount_screen(es)
	screen.trigger_map_load(&"qing_yun_jian_zong")
	var renderer: Node = _renderer(screen)
	var system_nodes: int = (es.get("_node_details") as Dictionary).size()
	# Assert——渲染节点数 = 系统缓存节点数（非空且一致）
	assert_true(system_nodes > 0, "前置：系统应生成非空节点图")
	assert_eq((renderer.nodes as Dictionary).size(), system_nodes,
			"渲染节点数应与系统一致")
	assert_false(screen.is_using_stub_source(), "真实数据源下不应有 stub 标记")


func test_real_enter_map_renders_system_node_ids() -> void:
	# Arrange
	var screen: Control = _mount_screen(es)
	screen.trigger_map_load(&"qing_yun_jian_zong")
	var renderer: Node = _renderer(screen)
	var rendered: Array = (renderer.nodes as Dictionary).keys()
	rendered.sort()
	var expected: Array = (es.get("_node_details") as Dictionary).keys()
	expected.sort()
	# Assert——节点 ID 集合完全一致，且不是 stub 样本（防退化为 stub）
	assert_eq(rendered, expected, "渲染节点 ID 应与系统节点详情完全一致")
	assert_ne(renderer.nodes, DATA_STUB.stub_node_details(),
			"真实地图渲染的节点详情不应等于 stub 样本")


func test_real_enter_map_renders_edges_from_system() -> void:
	# Arrange
	var screen: Control = _mount_screen(es)
	screen.trigger_map_load(&"qing_yun_jian_zong")
	var renderer: Node = _renderer(screen)
	# Assert——邻接表与系统一致（连线不是 stub 的固定拓扑）
	assert_eq(renderer.graph, es.get("_node_graph"), "渲染邻接表应与系统图一致")


func test_real_enter_map_states_cover_every_node() -> void:
	# Arrange
	var screen: Control = _mount_screen(es)
	screen.trigger_map_load(&"qing_yun_jian_zong")
	var renderer: Node = _renderer(screen)
	var states: Dictionary = renderer.states
	var nodes: Dictionary = renderer.nodes
	# Assert——每个节点都注入了六态，且与纯函数判定一致
	assert_eq(states.size(), nodes.size(), "每个渲染节点都应注入六态")
	var ap: int = int(gsm.exploration.get("action_points", 0))
	for node_id: int in nodes.keys():
		var expected: int = NODE_LOGIC.classify_node_state(node_id, renderer.graph,
				renderer.visited, renderer.current_node, ap, nodes)
		assert_eq(int(states[node_id]), expected, "节点 %d 六态应与纯函数一致" % node_id)


func test_real_enter_map_marks_entry_current_and_visited() -> void:
	# Arrange
	var screen: Control = _mount_screen(es)
	screen.trigger_map_load(&"qing_yun_jian_zong")
	var renderer: Node = _renderer(screen)
	# Assert——入口为当前态（真实系统的 visited 从「仅入口」开始）
	assert_eq(int(renderer.states.get(0, -1)), NODE_LOGIC.NodeState.CURRENT,
			"入口应为当前态")
	assert_true((renderer.visited as Array).has(0), "入口应记为已访问")


func test_real_enter_map_ap_label_matches_system() -> void:
	# Arrange
	var screen: Control = _mount_screen(es)
	screen.trigger_map_load(&"qing_yun_jian_zong")
	var label: Label = screen.get_node_or_null("TopBar/APLabel") as Label
	# Assert——AP 标签取系统写入值（不是 stub 的固定 3）
	assert_eq(label.text, "AP: %d" % int(gsm.exploration.get("action_points", -1)),
			"行动力标签应反映系统写入的 AP")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 地图差异可见
# ═══════════════════════════════════════════════════════════════════════════════

func test_switching_map_changes_rendered_graph() -> void:
	# Arrange——先渲染第一张图
	var screen: Control = _mount_screen(es)
	screen.trigger_map_load(&"qing_yun_jian_zong")
	var first: Dictionary = (_renderer(screen).graph as Dictionary).duplicate(true)
	# Act——同一屏幕换图（真实系统重新生成 + 广播）
	screen.trigger_map_load(&"dan_xia_gu")
	var second: Dictionary = _renderer(screen).graph
	# Assert——图跟着换（不是永远画同一张）
	assert_ne(first, second, "换地图后渲染的图应不同")
	assert_eq(second, es.get("_node_graph"), "换图后渲染邻接表应与系统新图一致")


func test_different_maps_render_different_node_counts_or_shapes() -> void:
	# Arrange——低难度（4 层）与极高难度（6 层）两张图
	var screen: Control = _mount_screen(es)
	screen.trigger_map_load(&"qing_yun_jian_zong")
	var low_nodes: int = (_renderer(screen).nodes as Dictionary).size()
	# Act
	screen.trigger_map_load(&"gui_xu_fu_yun_lu")
	var high_nodes: int = (_renderer(screen).nodes as Dictionary).size()
	# Assert——层数不同的地图节点数不同（地图差异真的进了渲染）
	assert_ne(low_nodes, high_nodes, "低难度与极高难度地图的节点数应不同")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 敌人池接上出厂模板（地图差异的数据侧）
# ═══════════════════════════════════════════════════════════════════════════════

func test_ai_system_registers_four_enemy_templates() -> void:
	# Arrange——AISystem 启动时扫描 assets/enemies/
	var ai: Node = get_node_or_null(NodePath("/root/AISystem"))
	assert_not_null(ai, "集成测试需要真实 AISystem Autoload")
	# Assert——四类出厂模板都在注册表（.tres 解析失败会在这里暴露）
	for tid: StringName in [&"san_xiu", &"mo_xiu", &"yao_shou", &"gui_xiu"]:
		assert_true(bool(ai.call(&"has_template", tid)),
				"敌人模板 '%s' 应被 AISystem 加载" % tid)


func test_ghost_map_combat_nodes_use_ghost_pool() -> void:
	# Arrange——古战场的池只有鬼修/魔修/散修
	var screen: Control = _mount_screen(es)
	screen.trigger_map_load(&"cang_xuan_gu_zhan_chang")
	var allowed: Dictionary = {&"gui_xiu": true, &"mo_xiu": true, &"san_xiu": true}
	# Act——收集该系统生成的战斗/精英节点名册
	var seen: int = 0
	for node_id: int in (es.get("_node_details") as Dictionary).keys():
		var detail: Dictionary = (es.get("_node_details") as Dictionary)[node_id]
		if not [1, 2].has(int(detail.get("type", -1))):
			continue
		for entry: Variant in detail.get("enemy_roster", []):
			var tid: StringName = StringName(str((entry as Dictionary).get("template_id", "")))
			seen += 1
			# Assert——名册条目来自该图的敌人池
			assert_true(allowed.has(tid),
					"古战场的战斗节点不应刷出 '%s'（不在该图敌人池）" % tid)
	assert_true(seen > 0, "古战场应至少生成一个带名册的战斗节点")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 降级路径（无系统时保留 stub）
# ═══════════════════════════════════════════════════════════════════════════════

func test_stub_fallback_when_system_lacks_signal() -> void:
	# Arrange——无 map_generated 信号的最小桩（模拟 Feature 层缺失）
	var bare: Node = Node.new()
	bare.set_script(_bare_system_script())
	add_child_autofree(bare)
	var screen: Control = NodeGraphScreenScene.instantiate()
	screen.animate = false
	screen.exploration_system = bare
	add_child_autofree(screen)
	# Act
	screen.trigger_map_load(&"qing_yun_jian_zong")
	var renderer: Node = _renderer(screen)
	# Assert——降级到 stub 样本，且标记可见（测试可区分真实/降级）
	assert_true(screen.is_using_stub_source(), "无信号源时应标记为 stub 降级")
	assert_eq((renderer.nodes as Dictionary).size(),
			(DATA_STUB.stub_node_details() as Dictionary).size(),
			"降级路径应渲染 stub 样本")
	assert_eq(renderer.nodes, DATA_STUB.stub_node_details(), "降级渲染的就是 stub 数据")


func test_stub_fallback_preserves_rendering_path() -> void:
	# 降级路径与真实路径共用 _on_map_generated——六态照常注入
	var bare: Node = Node.new()
	bare.set_script(_bare_system_script())
	add_child_autofree(bare)
	var screen: Control = NodeGraphScreenScene.instantiate()
	screen.animate = false
	screen.exploration_system = bare
	add_child_autofree(screen)
	screen.trigger_map_load(&"qing_yun_jian_zong")
	var renderer: Node = _renderer(screen)
	assert_eq((renderer.states as Dictionary).size(),
			(renderer.nodes as Dictionary).size(), "降级路径也应注入全部六态")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 挂载节点图屏幕并注入探索系统（注入必须在 add_child 之前——_ready 据此选数据源）。
func _mount_screen(p_system: Node) -> Control:
	var screen: Control = NodeGraphScreenScene.instantiate()
	screen.animate = false
	screen.exploration_system = p_system
	add_child_autofree(screen)
	return screen


## 屏幕下的渲染器。
func _renderer(p_screen: Control) -> Node:
	return p_screen.get("viewport").renderer


## 无 map_generated 信号的最小探索系统桩（只用于验证降级分支）。[br]
## 每个实例独立编译——共享同一个 GDScript 会在第二次 set_script 时报
## 「已在使用中」。
func _bare_system_script() -> GDScript:
	var script: GDScript = GDScript.new()
	script.source_code = "extends Node\n"
	script.reload()
	return script


## 重置 GSM 探索域（enter_map 会写 current_map / visited / ap / map_states）。
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
