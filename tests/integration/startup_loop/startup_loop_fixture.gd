extends GutTest
## StartupLoopFixture —— 「新开局 → 进图 → 打完 Boss → 存档 → 重启后继续」主线用例的共享夹具。[br]
## [br][b]为什么单独一处[/b]：用例文件要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「怎么开一局、怎么真的存一次读一次」与
## 「断言什么」是两件事（同 [code]save_round_trip_fixture.gd[/code] 先例）。[br]
## [br][b]用法[/b]：子类 [code]extends "res://…/startup_loop_fixture.gd"[/code]，
## 直接写 [code]test_*[/code] 方法；[code]before_each[/code] / [code]after_each[/code]
## 由本夹具提供。文件不以 [code]test_[/code] 开头（GUT 按前缀收集）。[br]
## [br][b]全链路真实[/b]：身份选择场景 → [code]apply_identity[/code] → 进入意图 →
## 探索薄容器 → [code]enter_map[/code] → Boss 胜利 → 通关结算 → [b]真实文件[/b]存读
## （仅把存档根换到专用测试目录）。桩只用在 SceneManager——导航仲裁者，真转场会
## 换掉测试进程的主场景。[br]
## [br][b]隔离[/b]：GSM 持久域、跨场景静态缓存、阵亡表在 [code]before_each[/code]
## 快照、[code]after_each[/code] 原样还原（Autoload 跨套件共享）。[br]
##
## 来源: main-menu-system.md（三条路径）、exploration-system.md §5 通关、
## ADR-0002、ADR-0005、ADR-0014 §决策 5、ADR-0031 §2。

const SLS := preload("res://src/foundation/save_load_system.gd")
const SM := preload("res://src/foundation/scene_manager.gd")
const BootstrapScript := preload("res://src/feature/exploration/exploration_bootstrap.gd")
const SceneScript := preload("res://src/feature/exploration/exploration_scene.gd")
const IntentScript := preload("res://src/feature/exploration/exploration_entry_intent.gd")
const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")
const LaunchScript := preload("res://src/feature/combat/combat_launch_context.gd")
const ClearView := preload("res://src/feature/exploration/map_clear_view.gd")
const ResultScreenScript := preload("res://src/ui/result_screen/result_screen.gd")
const Templates := preload("res://src/feature/identity/identity_templates.gd")
const MENU_SCENE: PackedScene = preload("res://src/ui/main_menu/MainMenu.tscn")
const IDENTITY_SCENE: PackedScene = preload("res://src/ui/identity_select/identity_select.tscn")
const PrimerScript := preload("res://tests/integration/exploration_ui/card_template_primer.gd")

## 用例存档根——专用子目录，不动真实槽位。
const TEST_ROOT: String = "user://test_startup_loop_saves/"
## 用例身份（青云剑宗·外门弟子——默认解锁，身份表首项 = 新开局的推荐落点）。
const IDENTITY: StringName = &"azure_sword_disciple"
## 首通彩头（[code]exploration_first_clear_rewards.gd[/code] LOW 档）。
const FIRST_CLEAR_CARD: StringName = &"pei_yuan_dan"
## 用例槽位（手动 1）。
const SLOT_ID: int = 1


## 存档根可覆盖的 SLS 子类（[code]_get_save_root[/code] 是既定的测试覆盖点）。
class TestSLS extends "res://src/foundation/save_load_system.gd":
	var root_path: String = "user://test_startup_loop_saves/"
	func _get_save_root() -> String:
		return root_path


## 记录转场请求的 SceneManager 桩——真转场会换掉测试进程的主场景。
class MockSceneManager:
	extends Node
	var change_calls: Array = []
	func get_current_scene_id() -> int:
		return SM.SceneID.MAIN_MENU
	func request_scene_change(from: int, to: int, type: int) -> bool:
		change_calls.append([from, to, type])
		return true


var gsm: Node = null
var es: Node = null
var isys: Node = null
var sls: Node = null
var sm: MockSceneManager = null
var _mounted: Array[Node] = []
var _domains_before: Dictionary = {}
var _unavailable_before: Dictionary = {}


func before_each() -> void:
	gsm = get_node_or_null(NodePath("/root/GameStateManager"))
	es = get_node_or_null(NodePath("/root/ExplorationSystem"))
	isys = get_node_or_null(NodePath("/root/IdentitySelectionSystem"))
	assert_not_null(gsm, "本夹具需要真实 GameStateManager Autoload")
	assert_not_null(es, "本夹具需要真实 ExplorationSystem Autoload")
	assert_not_null(isys, "本夹具需要真实 IdentitySelectionSystem Autoload")
	_domains_before.clear()
	for domain: String in gsm.PERSISTABLE_DOMAINS:
		_domains_before[domain] = (gsm.get(domain) as Dictionary).duplicate(true)
	_unavailable_before = (DeploymentSystem._unavailable_characters as Dictionary).duplicate(true)

	_clear_statics()
	_remove_test_root()
	sls = TestSLS.new()
	sls.set("root_path", TEST_ROOT)
	sls._ready()
	sm = MockSceneManager.new()
	_add(sm)
	_reset_gsm()
	_prepare_card_validation()
	# 生产装配（地图配置 + 敌人池 + 货架）——与 MainMenu._ready 同一条路径
	BootstrapScript.mount(es, get_node_or_null(NodePath("/root/AISystem")))
	es.call(&"set_rng_seed", 42)


func after_each() -> void:
	_clear_statics()
	for node: Node in _mounted:
		if is_instance_valid(node):
			node.free()
	_mounted.clear()
	for domain: String in _domains_before.keys():
		gsm.set(domain, (_domains_before[domain] as Dictionary).duplicate(true))
	DeploymentSystem.load_unavailable_from_gsm(_unavailable_before)
	es.call(&"clear_dag_cache")
	_remove_test_root()
	if sls != null:
		sls.free()
	sls = null
	sm = null


# ═══════════════════════════════════════════════════════════════════════════════
# 新开局 → 进图
# ═══════════════════════════════════════════════════════════════════════════════

## 走真实身份选择场景开一局：点卡 → 确认 → 叙事跳过 → 请求导航。[br]
## [br][b]返回[/b]：本次留下的进入意图（[enum ExplorationEntryIntent.EntryMode]）。[br]
## [br][b]为什么经场景而不是直调 [code]apply_identity[/code][/b]：本组用例验的是
## 「玩家从头玩到一张图通关」这条线——身份选择那一跳也在线上，绕过去就少了一段。
func start_new_run() -> int:
	var screen: Control = IDENTITY_SCENE.instantiate()
	screen.set(&"animate", false)
	screen.set(&"scene_manager", sm)
	screen.set(&"identity_system", isys)
	_add(screen)
	_click_card(screen, 0)
	screen.call(&"_on_confirm_dialog_confirmed")
	# 叙事层「任意键跳过」→ narrative_finished → 请求导航（含新开局意图）
	screen.call(&"_input", _key_event())
	# 意图是一次性的：take 只为把生产路径留下的模式读出来供断言，读到便原样放回
	# ——探索场景挂载时还要消费它一次（否则那条路会退化成「停在选图界面」）。
	var mode: int = IntentScript.take_entry_mode()
	if mode == IntentScript.EntryMode.FIRST_MAP:
		IntentScript.request_new_run()
	drop(screen)
	return mode


## 挂载探索薄容器（= 转场落地；意图由 [code]_ready[/code] 消费）。[br]
## [br][b]返回[/b]：容器实例（[code]node_graph_screen[/code] 为进图判据）。
func enter_exploration_scene() -> Control:
	var scene: Control = SceneScript.new()
	_add(scene)
	return scene


## 玩家在开局第一张图里走一步（真实 [code]move_to_node[/code]）——造出「玩过一阵」
## 的状态（已访问节点 + 已消耗行动力）。返回实际走到的节点（不可走为 -1）。
func walk_one_step() -> int:
	var children: Array = (es.get("_node_graph") as Dictionary).get(0, [])
	if children.is_empty():
		return -1
	var target: int = int(children[0])
	if not bool((es.call(&"move_to_node", 0, target) as Dictionary).get("success", false)):
		return -1
	return target


## 打完 Boss——走真实结算场景的收尾入口（与生产同一条路径）。返回结算场景实例。
func defeat_boss() -> Node:
	var boss: int = boss_node_id()
	assert_true(boss >= 0, "前置：本图应有一个 Boss 节点")
	var view: RefCounted = ViewScript.new()
	view.set("result", ViewScript.RESULT_VICTORY)
	ViewScript.publish(view)
	LaunchScript.publish({
		LaunchScript.KEY_NODE_ID: boss,
		LaunchScript.KEY_COMBAT_TYPE: LaunchScript.COMBAT_TYPE_BOSS,
	})
	var screen: Node = ResultScreenScript.new()
	screen.set(&"screen_id", SM.SceneID.RESULT_SCREEN)
	_add(screen)
	screen.call(&"_mark_battle_node_cleared_if_victory")
	return screen


## 当前地图的 Boss 节点 ID（从真实生成结果的节点详情里找——不硬编码层号）。
func boss_node_id() -> int:
	for node_id: Variant in (es.get("_node_details") as Dictionary).keys():
		var detail: Dictionary = (es.get("_node_details") as Dictionary)[node_id]
		if int(detail.get("type", -1)) == 3:  # NodeType.BOSS
			return int(node_id)
	return -1


# ═══════════════════════════════════════════════════════════════════════════════
# 存 / 读 / 重启 / 继续游戏
# ═══════════════════════════════════════════════════════════════════════════════

## 存一次档（真实写文件——只把存档根换到专用目录）。
func save_slot() -> int:
	return sls.save_game(SLS.SaveSlotType.MANUAL, SLOT_ID, gsm.serialize(),
			{"realm": "炼气期", "playtime_seconds": 120})


## 读一次档（真实读文件），返回 [enum SaveLoadSystem.LoadResult]。
func load_slot() -> int:
	var result: Dictionary = sls.load_game(SLS.SaveSlotType.MANUAL, SLOT_ID)
	return int(result.get("result", SLS.LoadResult.DESERIALIZE_ERROR))


## 模拟一次进程重启：内存清空 + 跨场景静态缓存清空 + DAG 缓存清空。[br]
## [br][b]为什么必须清静态缓存[/b]：真实重启后这些 [code]static var[/code] 全没了
## ——不清的话「重启后继续」会读上一段流程残留的意图与结算视图。
func simulate_restart() -> void:
	assert_true(bool(gsm.deserialize({"meta": {}})), "前置：内存状态已清空")
	es.call(&"clear_dag_cache")
	_clear_statics()


## 挂载主菜单（注入真实存档系统与 SceneManager 桩）。返回主菜单实例。
func mount_main_menu() -> Control:
	var menu: Control = MENU_SCENE.instantiate()
	menu.set(&"animate", false)
	menu.set(&"scene_manager", sm)
	menu.set(&"save_load", sls)
	_add(menu)
	return menu


## 点「继续游戏」——读最新档并请求转场探索。[br]
## [br][b]返回[/b]：本次留下的进入意图（[enum ExplorationEntryIntent.EntryMode]）。
## 同 [method start_new_run]，读到 RESUME 便原样放回供探索场景消费。
func press_continue(menu: Control) -> int:
	menu.call(&"_on_continue_pressed")
	var mode: int = IntentScript.take_entry_mode()
	if mode == IntentScript.EntryMode.RESUME:
		IntentScript.request_resume()
	return mode


# ═══════════════════════════════════════════════════════════════════════════════
# 断言辅助
# ═══════════════════════════════════════════════════════════════════════════════

## 某张地图在 [code]map_states[/code] 里的状态。
func map_state(p_map_id: StringName) -> Dictionary:
	var state: Variant = (gsm.exploration.get("map_states", {}) as Dictionary).get(p_map_id, {})
	return state if state is Dictionary else {}


## 收藏里的模板 ID 列表。
func owned_templates() -> Array:
	var out: Array = []
	for card: Variant in gsm.collection.owned_cards:
		out.append(str((card as Dictionary).get("template_id", "")))
	return out


func ling_shi() -> int:
	return int(gsm.player.resources.get("ling_shi", 0))


## 立即释放一个挂载节点（用例中途要拆掉旧场景再挂新的时用）。[br]
## [br][b]为什么必须拆[/b]：旧节点图仍连着探索系统的 [code]map_generated[/code]，
## 留着会让「重启后重进」这一跳收到两份广播。
func drop(node: Node) -> void:
	if node == null or not is_instance_valid(node):
		return
	_mounted.erase(node)
	node.free()


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

func _add(node: Node) -> void:
	add_child(node)
	_mounted.append(node)


func _key_event() -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = KEY_ENTER
	return event


## 卡片点击统一经 [code]gui_input[/code] 信号驱动（headless 下 push_input 不投递）。
func _click_card(screen: Control, index: int) -> void:
	var grid: GridContainer = screen.get_node("LayoutAnchor/GridContainer") as GridContainer
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	(grid.get_child(index) as Control).gui_input.emit(click)


## 清空跨场景静态缓存（意图 / 战斗上下文 / 结算视图 / 通关面板视图）。
func _clear_statics() -> void:
	IntentScript.clear()
	LaunchScript.clear()
	ViewScript.clear()
	ClearView.clear()


## 重置 GSM 到「全新空档」——每轮从零开始（同 [code]test_identity_start_flow[/code] 口径）。
func _reset_gsm() -> void:
	gsm.player.identity_id = ""
	gsm.player.realm = 1
	gsm.player.cultivation = 0
	gsm.player.resources.ling_shi = 0
	gsm.player.talents = []
	gsm.player["talent_map"] = {}
	gsm.deck.current_deck = []
	gsm.deck.slots = [null, null, null, null, null, null]
	gsm.collection.owned_cards = []
	gsm.collection.total_count = 0
	gsm.narrative.story_flags = {}
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


## 备好卡牌校验——身份模板 + 首通彩头进注册表，GSM 校验开启。[br]
## [br][b]为什么必须开[/b]：不开校验时 [code]apply_identity[/code] 与首通发卡都会
## 静默被拒——用例就分不出「没发」与「发了但被拒」。
func _prepare_card_validation() -> void:
	var ids: Array[StringName] = [FIRST_CLEAR_CARD]
	var deck: Dictionary = Templates.IDENTITY_TEMPLATES[IDENTITY]["initial_deck"]
	for entry: Dictionary in deck["cards"]:
		ids.append(StringName(str(entry["card_id"])))
	for entry: Dictionary in deck["character_slots"]:
		ids.append(StringName(str(entry["card_id"])))
	var database: Dictionary = gsm.get("_card_template_database")
	for id: StringName in ids:
		PrimerScript.prime(CardSystem, id)
		database[str(id)] = database.get(str(id), {})
	gsm.set("_card_template_database", database)
	gsm.validation_enabled = true


## 删除测试存档根目录（口径同 [code]save_round_trip_fixture.gd[/code]）。
func _remove_test_root() -> void:
	if not DirAccess.dir_exists_absolute(TEST_ROOT):
		return
	_remove_dir_recursive(TEST_ROOT)


func _remove_dir_recursive(p_dir: String) -> void:
	var dir: DirAccess = DirAccess.open(p_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if entry != "." and entry != "..":
			var full: String = p_dir + "/" + entry
			if dir.current_is_dir():
				_remove_dir_recursive(full)
			else:
				DirAccess.remove_absolute(full)
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(p_dir)
