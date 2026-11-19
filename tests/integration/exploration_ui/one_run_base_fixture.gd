extends GutTest
## OneRunBaseFixture —— 「一周目端到端冒烟」各段的[b]公共底座[/b]。[br]
## [br][b]为什么再分一层[/b]：底座（真实 Autoload + 场景管理器桩 + 存档隔离）与
## 「怎么把三条路径串起来」是两件事，各段用例都要前者、只有部分要后者。
## 底座单独一处后，各段装置只装自己那几步的编排，逐个守在 300 行软上限内
## （.claude/docs/coding-standards.md）。[br]
## [br][b]文件前缀[/b]：不以 [code]test_[/code] 开头——GUT 按前缀收集，
## 因此它只作为基类被继承，不会被当作用例文件单独执行。[br]
## [br][b]用真实 Autoload[/b]：本组用例验证的正是生产接线（主菜单 → 身份选择 →
## 探索 → 节点图 → 战斗 → 结算 → 回选图），而各场景都按 [code]/root/[/code] 查
## Autoload，没有注入点。[br]
## [br][b]场景管理器用桩[/b]：[code]SceneManager.request_scene_change[/code] 会真的
## 换场景、拆掉 GUT 的测试树（ADR-0005 唯一导航入口带来的副作用）。本装置注入一个
## 只记录调用的桩，断言「导航目标对不对」，转场本身归 [code]test_scene_manager[/code]。[br]
## [br][b]存档隔离[/b]：player / deck / collection / 校验库 / exploration 域 /
## 跨场景静态缓存在 [code]before_each[/code] 快照、[code]after_each[/code] 原样还原
## （同 [code]map_clear_settlement_fixture.gd[/code] 口径）。[br]
##
## 来源: design/gdd/main-menu-system.md（三条路径）、design/gdd/exploration-system.md、
## ADR-0005（导航唯一入口）、ADR-0014、ADR-0031 §2。

const BootstrapScript := preload("res://src/feature/exploration/exploration_bootstrap.gd")
const IntentScript := preload("res://src/feature/exploration/exploration_entry_intent.gd")
const CatalogScript := preload("res://src/feature/exploration/exploration_map_catalog.gd")
const TemplatesScript := preload("res://src/feature/identity/identity_templates.gd")
const SMScript := preload("res://src/foundation/scene_manager.gd")
const SLS := preload("res://src/foundation/save_load_system.gd")
const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")
const LaunchScript := preload("res://src/feature/combat/combat_launch_context.gd")
## 卡牌模板就位助手（异步加载的同步推进——与商店/通关用例共用）。
const PrimerScript := preload("res://tests/integration/exploration_ui/card_template_primer.gd")

## 探索入口节点 ID（与 [code]ExplorationSystem.ENTRY_NODE_ID[/code] 同值）。
const ENTRY_NODE: int = 0
## 用例存档根目录——专用子目录，不动真实槽位（同 [code]save_round_trip_fixture.gd[/code]）。
const TEST_SAVE_ROOT: String = "user://test_one_run_saves/"

var gsm: Node = null
var es: Node = null
var mock_sm: Node = null
var mock_sl: Node = null
## 用例存档系统（真实 [code]SaveLoadSystem[/code]，仅换存档根——见 [class TestSLS]）。
var sls: Node = null

var _player_before: Dictionary = {}
var _deck_before: Dictionary = {}
var _collection_before: Dictionary = {}
var _db_before: Dictionary = {}
var _validation_before: bool = false
var _exploration_before: Dictionary = {}
var _next_card_id_before: int = 1


## 存档根可覆盖的 [code]SaveLoadSystem[/code]（既定测试覆盖点——同
## [code]save_round_trip_fixture.gd[/code]）。走真实写盘读盘，只把目录换到测试专用处。
class TestSLS:
	extends "res://src/foundation/save_load_system.gd"

	var root_path: String = "user://test_one_run_saves/"

	func _get_save_root() -> String:
		return root_path


## 只记录调用的场景管理器桩——转场不真的发生（见文件头「场景管理器用桩」）。[br]
## [br][b]返回 true 即「请求被受理」[/b]：生产实现返回 bool，调用方据此判成败，
## 桩必须给同样的答案，否则「导航失败」分支会在测试里静默走成另一条路。
class MockSceneManager:
	extends Node

	## 形如 [code][from, to, type][/code] 的调用流水。
	var change_calls: Array = []

	func get_current_scene_id() -> int:
		return SMScript.SceneID.MAIN_MENU

	func request_scene_change(from: int, to: int, type: int) -> bool:
		change_calls.append([from, to, type])
		return true

	## 最近一次导航的目标场景 ID（无调用时 -1）。
	func last_target() -> int:
		if change_calls.is_empty():
			return -1
		return int(change_calls[-1][1])

	## 目标场景的注册路径（未注册 / 无调用时为空串）。[br]
	## [br][b]为什么桩来查注册表[/b]：转场本身被桩拦下了，但「转场目标在不在
	## 生产注册表里、资源文件在不在」仍可验——生产 [code]request_scene_change[/code]
	## 正是拿这张表做校验的，这里用同一个判据。
	func target_path() -> String:
		var target: int = last_target()
		if not SMScript.SCENE_PATHS.has(target):
			return ""
		return str(SMScript.SCENE_PATHS[target])


## 读档桩——新游戏路径不读档，但主菜单 [code]_ready[/code] 会列槽位。[br]
## 空列表即「无档」，与玩家第一次进游戏时的处境一致。
class MockSaveLoad:
	extends Node

	signal save_corrupted(slot_type: int, slot_id: int, reason: String)
	signal load_completed(success: bool)

	func list_slots() -> Array:
		return []

	func load_game(_slot_type: int, _slot_id: int) -> Dictionary:
		load_completed.emit(false)
		return {"result": 0, "data": {}}


func before_each() -> void:
	gsm = get_node_or_null(NodePath("/root/GameStateManager"))
	es = get_node_or_null(NodePath("/root/ExplorationSystem"))
	assert_not_null(gsm, "本文件需要真实 GameStateManager Autoload")
	assert_not_null(es, "本文件需要真实 ExplorationSystem Autoload")
	_player_before = (gsm.player as Dictionary).duplicate(true)
	_deck_before = (gsm.deck as Dictionary).duplicate(true)
	_collection_before = (gsm.collection as Dictionary).duplicate(true)
	_db_before = (gsm.get("_card_template_database") as Dictionary).duplicate(true)
	_validation_before = bool(gsm.validation_enabled)
	_exploration_before = (gsm.exploration as Dictionary).duplicate(true)
	_next_card_id_before = int(gsm.get("_next_card_instance_id"))
	IntentScript.clear()
	ViewScript.clear()
	LaunchScript.clear()
	_prepare_card_validation()
	_reset_gsm()
	BootstrapScript.mount(es, get_node_or_null(NodePath("/root/AISystem")))
	if es.has_method(&"set_rng_seed"):
		es.call("set_rng_seed", 42)
	mock_sm = MockSceneManager.new()
	mock_sl = MockSaveLoad.new()
	add_child_autofree(mock_sm)
	add_child_autofree(mock_sl)


func after_each() -> void:
	# 叙事 Timer 走 [code]remove_child + queue_free[/code]（identity_select_presenter
	# 的收尾口径）——放一帧让释放真正发生，否则 GUT 把它记成孤儿。
	await get_tree().process_frame
	IntentScript.clear()
	ViewScript.clear()
	LaunchScript.clear()
	if gsm != null:
		gsm.player = _player_before
		gsm.deck = _deck_before
		gsm.collection = _collection_before
		gsm.set("_card_template_database", _db_before)
		gsm.validation_enabled = _validation_before
		gsm.exploration = _exploration_before
		gsm.set("_next_card_instance_id", _next_card_id_before)
		gsm.set("_signal_chain_depth", 0)
		var router: Variant = gsm.get("_signal_router")
		if router != null:
			router.set("_pending_changes", [])
	if es != null and es.has_method(&"clear_dag_cache"):
		es.call("clear_dag_cache")
	_remove_test_save_root()
	if sls != null:
		sls.free()
		sls = null
	mock_sm = null
	mock_sl = null


## 重置 GSM 探索域与相关静态缓存（enter_map 会写 current_map / visited / ap）。
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


## 备好卡牌环境——先让六身份引用的模板全部就位，再开 GSM 校验。[br]
## [br][b]为什么按身份表点名 prime[/b]：CardSystem 的模板是
## [code]load_threaded_request[/code] 异步加载的，挂载那一刻 [code]templates[/code]
## 还是空的——「遍历现有模板」什么也推不动。[code]apply_identity[/code] 的就绪度
## 判定按名字查模板，查不到就判「暂未开放」并拒绝开局（同
## [code]test_identity_start_flow.gd[/code] 口径）。[br]
## [br][b]为什么要开校验[/b]：不开启时卡牌入库被拒，用例分不出「没发」与「发了但被拒」
## （同 [code]test_battle_reward_grant[/code] 口径）。
func _prepare_card_validation() -> void:
	for id: StringName in TemplatesScript.IDENTITY_TEMPLATES:
		for card_id: StringName in _referenced_ids(TemplatesScript.IDENTITY_TEMPLATES[id]):
			PrimerScript.prime(CardSystem, card_id)
	var database: Dictionary = {}
	for id: StringName in CardSystem.templates.keys():
		database[str(id)] = {}
	gsm.set("_card_template_database", database)
	gsm.validation_enabled = true


## 一条身份模板引用到的全部卡牌模板 ID（卡组 + 角色位）。
func _referenced_ids(p_tmpl: Dictionary) -> Array[StringName]:
	var ids: Array[StringName] = []
	var deck: Dictionary = p_tmpl.get("initial_deck", {})
	for entry: Dictionary in deck.get("cards", []):
		ids.append(StringName(str(entry.get("card_id", ""))))
	for entry: Dictionary in deck.get("character_slots", []):
		ids.append(StringName(str(entry.get("card_id", ""))))
	return ids


# ═══════════════════════════════════════════════════════════════════════════════
# 存档往返（链路第 8 步）
# ═══════════════════════════════════════════════════════════════════════════════

## 起一个走真实文件读写的存档系统（根目录换到测试专用处）。
func open_save_system() -> void:
	_remove_test_save_root()
	sls = TestSLS.new()
	sls.set(&"root_path", TEST_SAVE_ROOT)
	sls.call(&"_ready")


## 存一次盘——真实 [code]save_game[/code]，返回 [enum SaveLoadSystem.SaveResult]。
func save_progress() -> int:
	assert_not_null(sls, "前置：存档系统已起（见 [method open_save_system]）")
	return int(sls.call(&"save_game", SLS.SaveSlotType.MANUAL, 1,
			gsm.call(&"serialize"), {}))


## 读一次盘——真实 [code]load_game[/code]，返回 [enum SaveLoadSystem.LoadResult]。
func load_progress() -> int:
	var raw: Dictionary = sls.call(&"load_game", SLS.SaveSlotType.MANUAL, 1)
	return int(raw.get(&"result", SLS.LoadResult.DESERIALIZE_ERROR))


## 清空内存状态（只留空 meta 域）——读档前把「内存里的」抹掉，
## 之后读回来的每一项都只可能来自存档。
func wipe_memory() -> void:
	assert_true(bool(gsm.call(&"deserialize", {"meta": {}})), "前置：内存清空成功")


func _remove_test_save_root() -> void:
	if not DirAccess.dir_exists_absolute(TEST_SAVE_ROOT):
		return
	_remove_dir_recursive(TEST_SAVE_ROOT)


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
