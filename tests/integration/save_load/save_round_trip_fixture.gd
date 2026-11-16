extends GutTest
## SaveRoundTripFixture —— 「存 → 读 → 状态等价」用例的共享夹具。[br]
## [br][b]为什么单独一处[/b]：用例文件要守在 300 行软上限内
## （.claude/docs/coding-standards.md），而「怎么铺一份玩过一阵的状态、怎么真的存一次读一次」
## 与「断言什么等价」是两件事（同 [code]exploration_exit_fixture.gd[/code] 先例）。[br]
## [br][b]用法[/b]：子类 [code]extends "res://…/save_round_trip_fixture.gd"[/code]，
## 直接写 [code]test_*[/code] 方法即可；[code]before_each[/code] /
## [code]after_each[/code] 由本夹具提供，子类若要扩展需先 [code]super()[/code]。[br]
## [br][b]文件前缀[/b]：本文件不以 [code]test_[/code] 开头——GUT 按前缀收集，
## 因此它只作为基类被继承，不会被当作用例文件单独执行。[br]
## [br][b]走真实链路[/b]：真实 [code]GameStateManager[/code] Autoload + 真实
## [code]SaveLoadSystem[/code]（仅把存档根换到专用测试目录）+ 真实文件读写——
## 被测的正是「JSON 存盘再读回来」这条路，不注入桩。[br]
## [br][b]隔离[/b]：GSM 的 6 个持久域与 DeploymentSystem 的阵亡表在
## [code]before_each[/code] 快照、[code]after_each[/code] 原样还原
## （Autoload 跨套件共享，不还原会污染后续用例）。
##
## 来源: design/gdd/game-state-manager.md §存档、ADR-0002 §JSON + 迁移链、
## ADR-0014 §决策 1 状态分层模型、ADR-0016 §不可用角色生命周期。

const SLS := preload("res://src/foundation/save_load_system.gd")
const HarvestScript := preload("res://src/feature/exploration/exploration_harvest.gd")
const SpringScript := preload("res://src/feature/exploration/exploration_action_spring.gd")
const ShownScript := preload("res://src/feature/exploration/exploration_event_shown.gd")
const ClearScript := preload("res://src/feature/exploration/exploration_map_clear.gd")

## 用例存档根目录——专用子目录，避免动到真实槽位。
const TEST_ROOT: String = "user://test_round_trip_saves/"

## 用例地图（青云剑宗为炼气期地图；通关记录按地图 ID 分记）。
const MAP_A: StringName = &"qing_yun_jian_zong"
const MAP_B: StringName = &"cang_xuan_gu_zhan_chang"

## 用例角色 ID 段（远离其它套件，防串场）。
const CHAR_DEAD: int = 8801
const CHAR_HURT: int = 8802

## 存档根可覆盖的子类——[code]_get_save_root[/code] 是既定的测试覆盖点。[br]
## [br]根目录由 [member root_path] 给出（子类换目录只需覆写那一个方法，
## 不必再复制一份子类）。[br]
class TestSLS extends "res://src/foundation/save_load_system.gd":
	var root_path: String = "user://test_round_trip_saves/"
	func _get_save_root() -> String:
		return root_path

var sls: Node = null
var gsm: Node = null
var _domains_before: Dictionary = {}
var _unavailable_before: Dictionary = {}


## 本用例组的存档根目录——子类覆写即可换到自己的目录。
func root_path() -> String:
	return TEST_ROOT


func before_each() -> void:
	gsm = get_node_or_null(NodePath("/root/GameStateManager"))
	assert_not_null(gsm, "本夹具需要真实 GameStateManager Autoload")
	_domains_before.clear()
	for domain: String in gsm.PERSISTABLE_DOMAINS:
		_domains_before[domain] = (gsm.get(domain) as Dictionary).duplicate(true)
	_unavailable_before = (DeploymentSystem._unavailable_characters as Dictionary).duplicate(true)
	_remove_test_root()
	sls = TestSLS.new()
	sls.set("root_path", root_path())
	sls._ready()


func after_each() -> void:
	for domain: String in _domains_before.keys():
		gsm.set(domain, (_domains_before[domain] as Dictionary).duplicate(true))
	DeploymentSystem.load_unavailable_from_gsm(_unavailable_before)
	_remove_test_root()
	if sls != null:
		sls.free()
		sls = null


# ═══════════════════════════════════════════════════════════════════════════════
# 夹具动作
# ═══════════════════════════════════════════════════════════════════════════════

## 铺一份覆盖审计清单全部条目的「玩过一阵」状态。
func seed_progress() -> void:
	# 地图 A：已通关（首通 + 3 次）、进过 4 次、已访问 3 个节点
	gsm.set_exploration_map(MAP_A)
	gsm.reset_exploration_visited([0])
	gsm.add_visited_node(101)
	gsm.add_visited_node(203)
	gsm.set_exploration_ap(2, 5)
	gsm.update_exploration_map_state(MAP_A, {
		"is_first_clear": true,
		"clear_count": 3,
		"entry_count": 4,
		SpringScript.KEY_SPRING_USES: 2,
		HarvestScript.KEY_HARVESTED: {203: [0, 2]},
		ShownScript.KEY_EVENTS_SHOWN: [101, 203],
		"graph": {0: [101], 101: [203], 203: []},
		"nodes": {101: {"type": "battle"}, 203: {"type": "harvest"}},
	})
	# 地图 B：从未通关（自动解锁的前置判定依赖「没通关」这个事实）
	gsm.update_exploration_map_state(MAP_B, {"entry_count": 1, "is_first_clear": false})
	# 阵亡 + 残血
	gsm._set_player_unavailable_characters({
		CHAR_DEAD: {"death_turn": 3, "death_battle_id": "battle_9", "revival_methods": []},
	})
	gsm._set_player_character_hp(CHAR_DEAD, {"current_hp": 0, "max_hp": 12})
	gsm._set_player_character_hp(CHAR_HURT, {"current_hp": 5, "max_hp": 9})
	# 收藏与卡组
	gsm.collection.owned_cards = [
		{"card_instance_id": 11, "template_id": "card_fire_001", "level": 1,
			"breakthrough_layers": 0, "acquired_chapter": 1, "acquired_method": 0,
			"binding_target_id": "", "acquired_event_id": "", "inscriptions": []},
		{"card_instance_id": 12, "template_id": "card_water_002", "level": 2,
			"breakthrough_layers": 1, "acquired_chapter": 2, "acquired_method": 1,
			"binding_target_id": "", "acquired_event_id": "", "inscriptions": []},
	]
	gsm.collection.total_count = 2
	gsm.deck.current_deck = [11, 12]
	gsm.deck.slots = [11, "char_1", null, null, null, null]
	# 剧情标记（自动解锁的另一半条件）
	gsm.set_narrative_flag(&"met_master", true)


## 存档——真实写文件，返回 [enum SaveLoadSystem.SaveResult]。
func save_slot() -> int:
	return sls.save_game(SLS.SaveSlotType.MANUAL, 1, gsm.serialize(), {})


## 读档——真实读文件，返回 [enum SaveLoadSystem.LoadResult]。
func load_slot() -> int:
	var result: Dictionary = sls.load_game(SLS.SaveSlotType.MANUAL, 1)
	return int(result.get("result", SLS.LoadResult.DESERIALIZE_ERROR))


## 清空内存状态——只留一个空 meta 域，其余域按默认值重建。
func wipe_memory() -> void:
	assert_true(bool(gsm.deserialize({"meta": {}})), "前置条件：内存清空成功")


## 「存一次 → 清空 → 读回来」——本组用例的主序，返回读档结果码。
func save_wipe_load() -> int:
	assert_eq(save_slot(), SLS.SaveResult.SUCCESS,
			"真实载荷必须写得进存档（修复前恒 VALIDATION_ERROR）")
	wipe_memory()
	return load_slot()


## 地图 A 当前的 [code]map_states[/code] 条目（断言焦点）。
func state_of_a() -> Dictionary:
	return gsm.exploration.map_states.get(MAP_A, {})


## 删除测试存档根目录（含子目录）。
func _remove_test_root() -> void:
	var root: String = root_path()
	if not DirAccess.dir_exists_absolute(root):
		return
	_remove_dir_recursive(root)


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
