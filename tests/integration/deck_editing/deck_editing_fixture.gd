extends GutTest
## DeckEditingFixture —— 卡组编辑界面用例的共享装置（真实 Autoload + 真实存档）。[br]
## [br][b]为什么用真实系统而不是桩[/b]：这个界面要证明的正是「改完之后 GSM 里的卡组
## 真的变了、落盘之后真的读得回来」——用桩断言等于断言自己造的假数据。收藏写入走
## 真实 [code]CardSystem.create_instance[/code] + [code]GSM.add_card_to_collection[/code]，
## 增删走真实 [code]DeckEditingSystem[/code]，落盘走真实 [code]SaveLoadSystem[/code]
## （写进本用例组自己的 [code]user://test_deck_editing_saves/[/code] 目录）。[br]
## [br][b]原名不符 [code]test_[/code] 前缀[/b]：GUT 不把它当用例收集，只作基类
## （先例 [code]inventory_screens_fixture.gd[/code] /
## [code]save_round_trip_fixture.gd[/code]）。[br]
## [br][b]快照还原[/b]：GSM 是全进程单例——[code]player[/code] / [code]collection[/code] /
## [code]deck[/code] 三个域在 [method before_each] 深拷贝、[method after_each] 原样
## 写回，不还原会让后续用例互相污染。[br]
## [br][b]异步模板就位[/b]：[code]CardSystem._ready[/code] 用
## [code]load_threaded_request[/code] 分批加载模板，GUT 下的帧驱动不保证——用
## [code]card_template_primer.gd[/code] 同步推进（商店 / 炼制 / 背包各用例共用）。
## 模板没就位时界面会静默少几行，断言随之失真。[br]
##
## 来源: 先例 [code]inventory_screens_fixture.gd[/code] /
## [code]save_round_trip_fixture.gd[/code]。

const ScreenScript := preload("res://src/ui/deck_editing/deck_editing_screen.gd")
const ActionsScript := preload("res://src/ui/deck_editing/deck_editing_actions.gd")
const CollectionRows := preload("res://src/ui/deck_editing/deck_collection_rows.gd")
const DeckRows := preload("res://src/ui/hud/deck_view_rows.gd")
const EntryScript := preload("res://src/ui/deck_editing/deck_editing_entry.gd")
## 栏下标常量（两栏的编号——用例与界面必须用同一份）。
const NavScript := preload("res://src/ui/deck_editing/deck_editing_navigator.gd")
## SceneManager 脚本常量（SceneID / TransitionType 枚举真理来源）。
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
const PrimerScript := preload("res://tests/integration/exploration_ui/card_template_primer.gd")
const SLS := preload("res://src/foundation/save_load_system.gd")

## 具名模板（[code]assets/cards/templates/[/code] 里已落盘的几张）——用真实模板而非
## 临时造资源：界面读的正是真实注册表。[br]
## 前三张的 [code]stack_limit[/code] 都是 3（丹药 / 法宝写在 .tres 里，符箓走字段默认）；
## [constant CHARACTER_ID] 是角色卡（[code]type = 0[/code]），用来验证它[b]不[/b]进左栏。
const PILL_ID: StringName = &"pill_yu_ling_dan"           # 丹药 · 紫
const ARTIFACT_ID: StringName = &"artifact_zhong_pin_fa_qi"  # 法宝 · 紫
const TALISMAN_ID: StringName = &"basic_attack"           # 符箓 · 基础攻击
const CHARACTER_ID: StringName = &"lin_yuan"              # 角色 · 生命 10

## 本用例组的存档根目录（真实写盘——但写进测试专属目录，不碰玩家档）。
const TEST_ROOT: String = "user://test_deck_editing_saves/"


## 存档系统替身——只改存档根目录，其余行为一律继承真实实现。[br]
## [br][b]为什么不另写一个假 [code]auto_save[/code][/b]：本轮的验收之一就是「保存后
## 重新读回来内容一致」，假实现会让这条断言失去意义。改根目录是唯一必要的偏离。
class TestSLS extends "res://src/foundation/save_load_system.gd":
	var root_path: String = "user://test_deck_editing_saves/"
	func _get_save_root() -> String:
		return root_path


## 场景管理器桩——记录导航请求，不触发真实转场（ADR-0005 的唯一入口仍然被调用）。
class SceneManagerStub extends Node:
	var requests: Array = []
	var current_id: int = 0

	func get_current_scene_id() -> int:
		return current_id

	func request_scene_change(from: int, to: int, type: int) -> bool:
		requests.append({"from": from, "to": to, "type": type})
		return true


var screen: Control = null
var sls: Node = null
var sm: SceneManagerStub = null
var actions: RefCounted = null
## 收藏里各模板的实例 ID（[method seed_collection] 的产出——用例据它断言具体某一
## 张卡的去向，而不是只数张数）。
var pills: Array = []
var artifacts: Array = []
var talismans: Array = []

var _player_before: Dictionary = {}
var _collection_before: Dictionary = {}
var _deck_before: Dictionary = {}
var _db_before: Dictionary = {}
var _validation_before: bool = false


func before_each() -> void:
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	_collection_before = (GameStateManager.collection as Dictionary).duplicate(true)
	_deck_before = (GameStateManager.deck as Dictionary).duplicate(true)
	_db_before = (GameStateManager.get("_card_template_database") as Dictionary).duplicate(true)
	_validation_before = bool(GameStateManager.validation_enabled)
	_reset_domains()
	_prepare_card_validation()
	_remove_test_root()
	sls = TestSLS.new()
	sls.set("root_path", TEST_ROOT)
	sls._ready()
	sm = SceneManagerStub.new()
	add_child_autofree(sm)
	actions = ActionsScript.new(DeckEditingSystem, CardSystem, GameStateManager, sls)
	EntryScript.clear()


func after_each() -> void:
	if screen != null and is_instance_valid(screen):
		screen.free()
	screen = null
	# 行控件由 [code]clear_box[/code] 逐个 [code]queue_free[/code]（延迟到帧末释放）——
	# 不等一帧的话它们会在下一次刷新前一直挂着，GUT 把它们报成 orphan。
	# 本用例组每次操作都重建两栏，orphan 会成倍累积，故在这里把队列放空。
	await get_tree().process_frame
	actions = null
	EntryScript.clear()
	_remove_test_root()
	if sls != null:
		sls.free()
		sls = null
	sm = null
	GameStateManager.set("player", _player_before.duplicate(true))
	GameStateManager.set("collection", _collection_before.duplicate(true))
	GameStateManager.set("deck", _deck_before.duplicate(true))
	GameStateManager.set("_card_template_database", _db_before.duplicate(true))
	GameStateManager.validation_enabled = _validation_before


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 挂载界面（依赖注入在进树前完成——[code]_ready[/code] 会现读它们）。[br]
## [br][param p_origin_scene_id] 来路场景 ID（[code]DeckEditingEntry[/code] 记它，
## 「保存并返回」据此回地方；默认主菜单）。
func mount_screen(p_origin_scene_id: int = 0) -> Control:
	EntryScript.request_edit(p_origin_scene_id)
	screen = ScreenScript.new()
	screen.deck_system = DeckEditingSystem
	screen.card_system = CardSystem
	screen.gsm = GameStateManager
	screen.save_load = sls
	screen.scene_manager = sm
	add_child_autofree(screen)
	return screen


## 铺一份收藏：5 丹药 + 2 法宝 + 4 符箓。[br]
## [br][b]丹药给 5 张而不是 3 张[/b]：同名上限是 3，多出的两张是「超出同名上限」那条
## 用例的素材——若只给 3 张，加满之后行会被置灰（没有可加入的副本），那条用例就退化成
## 测「行被禁用」而不是测拒绝原因。[br]
## [br][b]返回[/b]：是否全部造出来了——用例据此断言装置确实到位，而不是在收藏为空的
## 情况下跑出一条假的通过路径。
func seed_collection() -> bool:
	pills = _give_many(PILL_ID, 5)
	artifacts = _give_many(ARTIFACT_ID, 2)
	talismans = _give_many(TALISMAN_ID, 4)
	return pills.size() == 5 and artifacts.size() == 2 and talismans.size() == 4


## 一份「已经打了一阵」的卡组：3 丹药 + 2 法宝 + 1 符箓 = 6 张。[br]
## [br][b]为什么是 6 张[/b]：卡组最低 5 张——6 张才既有可删的余量（删一张仍合法），
## 也能在删到 5 张之后触发最低张数保护。
func seed_deck() -> Array:
	var ids: Array = []
	ids.append_array(pills.slice(0, 3))
	ids.append_array(artifacts)
	ids.append(talismans[0])
	set_deck(ids)
	return ids


## 把卡组摆成给定的实例 ID 列表（走真实 GSM 第二层写入）。
func set_deck(p_ids: Array) -> void:
	GameStateManager._set_deck_cards(p_ids.duplicate())


## 当前卡组（GSM 里那份——所有「同步」断言的唯一真相来源）。
func deck_ids() -> Array:
	return (GameStateManager.deck.get("current_deck", []) as Array).duplicate()


## 清空收藏（空态用例的起点——[method before_each] 默认不铺收藏，但上一个用例若
## 留下过痕迹，这里给一个显式的清空口，不靠「恰好是空的」）。
func clear_collection() -> void:
	GameStateManager.collection.owned_cards = []
	GameStateManager.collection.total_count = 0


## 铺一份默认卡组之后的张数（[method seed_deck] 的固定产出：3 丹药 + 2 法宝 + 1 符箓）。
func seed_deck_size() -> int:
	return 6


## 左栏某模板的行下标（找不到 -1）。
func collection_index_of(p_template_id: StringName) -> int:
	for index: int in range(screen.collection_count()):
		var payload: Dictionary = screen.payload_at(0, index)
		if StringName(str(payload.get(CollectionRows.KEY_TEMPLATE_ID, ""))) == p_template_id:
			return index
	return -1


## 右栏某实例的行下标（找不到 -1）。
func deck_index_of(p_instance_id: int) -> int:
	for index: int in range(screen.deck_count()):
		var payload: Dictionary = screen.payload_at(1, index)
		if int(payload.get(DeckRows.KEY_INSTANCE_ID, 0)) == p_instance_id:
			return index
	return -1


## 把某张收藏卡加入卡组（走真实动作层：判定 → 统一写入入口）。[br]
## [br][b]返回[/b]：[code]{ok, message}[/code]——被拒时 [code]message[/code] 是中文原因。
func add_card_at(p_column_index: int) -> Dictionary:
	return actions.call(&"add_card", screen.payload_at(0, p_column_index),
			_deck_from_system(), _limit_from_system())


## 把卡组里某一张移出（走真实动作层）。
func remove_card_at(p_column_index: int) -> Dictionary:
	return actions.call(&"remove_card", screen.payload_at(1, p_column_index),
			_deck_from_system())


## 按当前场景 ID 造一个转场请求（与界面内 [code]_leave[/code] 同口径）。
func last_request() -> Dictionary:
	return sm.requests[sm.requests.size() - 1] if not sm.requests.is_empty() else {}


## 造一个「按下某动作」的输入事件（界面走 [code]_input[/code]，直调即复现引擎同一次
## 派发——先例 [code]test_shop_panel_navigation.gd[/code]）。[br]
## [br][b]用 [InputEventAction] 而不是 [InputEventKey][/b]：界面判的是
## [code]is_action_pressed[/code]（动作名），用键码造事件还要经过 InputMap 映射，
## 与界面实际读的东西隔了一层。
func action_event(p_action: StringName, p_pressed: bool = true) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = p_action
	event.pressed = p_pressed
	return event


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

func _limit_from_system() -> int:
	return int(DeckEditingSystem.call(&"get_deck_limit"))


func _deck_from_system() -> Array:
	return (DeckEditingSystem.call(&"get_deck_cards") as Array).duplicate()


## 造同一模板的 [param p_count] 张并放进收藏（走真实入口）。返回实例 ID 数组。
func _give_many(p_template_id: StringName, p_count: int) -> Array:
	var out: Array = []
	for _i: int in range(p_count):
		var id: int = give_card(p_template_id)
		if id <= 0:
			return []
		out.append(id)
	return out


## 造一张收藏卡（真实 [code]CardSystem.create_instance[/code] +
## [code]GSM.add_card_to_collection[/code]）。返回实例 ID；失败 -1。
func give_card(p_template_id: StringName) -> int:
	if not PrimerScript.prime(CardSystem, p_template_id):
		return -1
	var instance: Variant = CardSystem.create_instance(p_template_id)
	if instance == null:
		return -1
	var entry: Dictionary = CardSystem.serialize_instance(instance)
	entry["template_id"] = p_template_id
	if not GameStateManager.add_card_to_collection(entry):
		return -1
	return int(entry.get("card_instance_id", -1))


## 重置三个域为干净初值（每用例从确定的起点开始——测试不得依赖执行顺序）。
func _reset_domains() -> void:
	GameStateManager.player = {
		"realm": 1, "cultivation": 0, "max_cultivation": 1000,
		"cultivation_full": false, "is_fallen": false, "overflow_pool": 0,
		"resources": {"ling_shi": 0,
			"ling_cai": {"low": 0, "medium": 0, "high": 0, "top": 0},
			"dan_yao_sui_pian": 0},
		"identity_id": "test_identity_deck_edit", "talents": [], "talent_map": {},
		"unavailable_characters": {}, "character_hp": {},
		"tribulation_state": 0, "consecutive_tribulation_failures": 0,
	}
	GameStateManager.collection = {"owned_cards": [], "total_count": 0}
	GameStateManager.deck = {"current_deck": [], "slots": [null, null, null,
			null, null, null], "change_log": [], "session_remove_count": 0,
			"deck_limit_modifier": 0}
	DeploymentSystem.load_unavailable_from_gsm({})


## 让卡牌引用校验可用（[code]add_card_to_collection[/code] 的前置）。
func _prepare_card_validation() -> void:
	var ids: Array = [PILL_ID, ARTIFACT_ID, TALISMAN_ID, CHARACTER_ID]
	for id: StringName in ids:
		PrimerScript.prime(CardSystem, id)
	var database: Dictionary = GameStateManager.get("_card_template_database")
	for id: StringName in ids:
		database[str(id)] = database.get(str(id), {})
	GameStateManager.set("_card_template_database", database)
	GameStateManager.validation_enabled = true


## 清掉本用例的存档目录（真实写盘——每条用例从空目录开始，互不污染）。
func _remove_test_root() -> void:
	if not DirAccess.dir_exists_absolute(TEST_ROOT):
		return
	_remove_dir_recursive(TEST_ROOT)


func _remove_dir_recursive(p_dir: String) -> void:
	var dir: DirAccess = DirAccess.open(p_dir)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)
	for sub_name: String in dir.get_directories():
		_remove_dir_recursive(p_dir.path_join(sub_name))
	DirAccess.remove_absolute(p_dir)
