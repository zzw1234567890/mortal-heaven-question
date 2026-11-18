extends GutTest
## 读档侧的导航分岔验收：「这份档在战斗中」→ 进战斗场景，否则照旧进探索。[br]
## [br][b]补的断链[/b]：本轮之前战斗中存的档，读回来一律送进探索地图——那场仗连同
## 残血静默消失（[code]battle[/code] 域不可持久化，ADR-0008）。存的那半在
## [code]battle_resume_payload.gd[/code] 里，本文件钉住[b]读的那半[/b]：
## [code]main_menu_launch.load_and_resume[/code] 认不认这段、认了去哪。[br]
## [br][b]为什么单独一份文件[/b]：断的是导航（[enum SceneManager.SceneID] 选错一个
## 值，玩家就落到一张地图上），而 [code]test_startup_paths.gd[/code] 已 297 行
## ——三条开局路径与「第四种去向」是两件事，混在一起两边都读不清。[br]
## [br][b]覆盖[/b]：[br]
##   1. 带可续战斗段的档 → 转场 COMBAT，且[b]不留[/b]探索意图；[br]
##   2. 老档（没有战斗段）→ 照旧转场 EXPLORATION + 留续玩意图；[br]
##   3. 残载荷（有标记但名册空）→ 退回探索（不许把玩家带进一场判不出胜负的仗）；[br]
##   4. 意图一次性：取走即清，不会让下一场全新的仗带着上一场的残血开打；[br]
##   5. 依赖不可用时中止导航且不登记意图。[br]
## [br][b]装置[/b]：真实 [code]MainMenuLaunch[/code] + mock 的场景管理器 / 存档系统 /
## GSM——被测的是「读到什么 → 去哪」，不碰真实存档文件（那半边见
## [code]tests/integration/save_load/test_battle_resume_round_trip.gd[/code]）。[br]
## [br]来源: ADR-0005（导航唯一仲裁）、ADR-0008 §GSM 边界、ADR-0031 §2、
## 本轮「战斗中存档 → 读档回到战斗」（B 项）。

const LaunchScript := preload("res://src/ui/main_menu/main_menu_launch.gd")
const SM := preload("res://src/foundation/scene_manager.gd")
const SLS := preload("res://src/foundation/save_load_system.gd")
const ResumeIntentScript := preload("res://src/feature/combat/battle_resume_intent.gd")
const EntryIntentScript := preload("res://src/feature/exploration/exploration_entry_intent.gd")

const CHAR_A: int = 8831
const CHAR_B: int = 8832


## mock 场景管理器——记录每次转场请求（先例 [code]test_startup_paths.gd[/code]）。
class MockSceneManager:
	extends Node

	var change_calls: Array = []

	func get_current_scene_id() -> int:
		return SM.SceneID.MAIN_MENU

	func request_scene_change(from: int, to: int, type: int) -> bool:
		change_calls.append([from, to, type])
		return true


## mock 存档系统——只答「读到了什么」，不碰磁盘。
class MockSaveLoad:
	extends Node

	var payload: Dictionary = {}
	var load_calls: Array = []

	func load_game(slot_type: int, slot_id: int) -> Dictionary:
		load_calls.append([slot_type, slot_id])
		return {"result": SLS.LoadResult.SUCCESS, "data": payload}


## mock GSM——续战段的唯一读点（[code]node.get(&"battle_resume")[/code]）。
class MockGsm:
	extends Node

	var battle_resume: Dictionary = {}


var launch: RefCounted = null
var mock_sm: MockSceneManager = null
var mock_sl: MockSaveLoad = null
var mock_gsm: MockGsm = null


func before_each() -> void:
	ResumeIntentScript.clear()
	EntryIntentScript.clear()
	mock_sm = MockSceneManager.new()
	mock_sl = MockSaveLoad.new()
	mock_gsm = MockGsm.new()
	launch = LaunchScript.new()
	launch.scene_manager = mock_sm
	launch.save_load = mock_sl
	launch.gsm = mock_gsm


func after_each() -> void:
	ResumeIntentScript.clear()
	EntryIntentScript.clear()
	launch = null
	for node: Node in [mock_sm, mock_sl, mock_gsm]:
		if node != null and is_instance_valid(node):
			node.free()
	mock_sm = null
	mock_sl = null
	mock_gsm = null


# ═══════════════════════════════════════════════════════════════════════════════
# 分岔：有战斗段 → 战斗场景
# ═══════════════════════════════════════════════════════════════════════════════

func test_continue_with_battle_save_navigates_to_combat() -> void:
	# Arrange——一份「打到一半」的档（GSM 里已有 load_game 落下的续战段）
	_arrange_battle_save()
	# Act
	assert_eq(launch.call(&"load_and_resume", SLS.SaveSlotType.MANUAL, 1),
			SLS.LoadResult.SUCCESS, "读档成功")
	# Assert——目标是战斗场景而不是探索
	assert_eq(mock_sm.change_calls.size(), 1, "应发出一次转场请求")
	if mock_sm.change_calls.size() == 1:
		assert_eq(mock_sm.change_calls[0][1], SM.SceneID.COMBAT,
				"带战斗段的档应进战斗场景（继续游戏不再把玩家丢回地图）")
		assert_eq(mock_sm.change_calls[0][2], SM.TransitionType.EXPLORE_TO_COMBAT,
				"转场类型应走战斗那条（时长与 BGM 过渡按它算）")


## 战斗场景取走的是[code]BattleResumeIntent[/code]——没留下它就等于进了一场空仗
## （场景无从知道自己是来接着打的）。
func test_battle_save_leaves_resume_intent_with_payload() -> void:
	# Arrange
	var payload: Dictionary = _arrange_battle_save()
	# Act
	launch.call(&"load_and_resume", SLS.SaveSlotType.MANUAL, 1)
	# Assert
	assert_true(ResumeIntentScript.has_pending(), "导航前应留下待消费的续战意图")
	assert_eq(int(ResumeIntentScript.peek().get("turn", -1)), int(payload["turn"]),
			"留下的就是存档里那份状态（回合是关键判据之一）")
	assert_false(EntryIntentScript.has_pending(),
			"去战斗就不该再留探索意图（两条路径互斥，留下会让探索侧空等）")


# ═══════════════════════════════════════════════════════════════════════════════
# 老档：没有战斗段 → 照旧进探索
# ═══════════════════════════════════════════════════════════════════════════════

func test_continue_without_battle_section_navigates_to_exploration() -> void:
	# Arrange——老档：GSM 里这一段是出厂值（空字典）
	mock_sl.payload = {"game_state": {"meta": {}}}
	assert_eq(mock_gsm.battle_resume, {}, "前置：没有进行中的战斗")
	# Act
	launch.call(&"load_and_resume", SLS.SaveSlotType.MANUAL, 1)
	# Assert
	assert_eq(mock_sm.change_calls.size(), 1, "老档同样要导航")
	if mock_sm.change_calls.size() == 1:
		assert_eq(mock_sm.change_calls[0][1], SM.SceneID.EXPLORATION,
				"老档照旧进探索（兼容半边——改动不得碰坏这条路）")
	assert_eq(EntryIntentScript.take_entry_mode(), EntryIntentScript.EntryMode.RESUME,
			"老档留下的仍是探索侧的续玩意图")
	assert_false(ResumeIntentScript.has_pending(), "老档不该留下续战意图")


## 残载荷（有 [code]is_active[/code] 标记但名册空）：按「没有战斗段」处理。[br]
## [br][b]为什么退回探索而不是硬进[/b]：重建不出名册的仗判不出胜负，玩家会卡在一场
## 打不完的战斗里；退回地图最多是重新点一次那个节点。
func test_crippled_battle_payload_falls_back_to_exploration() -> void:
	# Arrange——带标记但两道名册都空
	mock_sl.payload = {"game_state": {"meta": {}}}
	mock_gsm.battle_resume = {"is_active": true, "player_roster": [], "enemy_roster": []}
	# Act
	launch.call(&"load_and_resume", SLS.SaveSlotType.MANUAL, 1)
	# Assert
	assert_false(ResumeIntentScript.has_pending(), "残载荷不得留下续战意图")
	if mock_sm.change_calls.size() == 1:
		assert_eq(mock_sm.change_calls[0][1], SM.SceneID.EXPLORATION,
				"残载荷应退回探索（不许把玩家带进一场判不出胜负的仗）")
	assert_eq(mock_sm.change_calls.size(), 1, "仍然只导航一次")


# ═══════════════════════════════════════════════════════════════════════════════
# 意图一次性 + 依赖守卫
# ═══════════════════════════════════════════════════════════════════════════════

func test_taken_intent_is_consumed_once() -> void:
	## 取走即清——否则下一场[b]全新[/b]的仗会带着上一场的残血开打。
	# Arrange
	_arrange_battle_save()
	launch.call(&"load_and_resume", SLS.SaveSlotType.MANUAL, 1)
	# Act
	var first: Dictionary = ResumeIntentScript.take()
	# Assert
	assert_false(first.is_empty(), "第一次应取到载荷")
	assert_false(ResumeIntentScript.has_pending(), "取走后不应再有待消费意图")
	assert_eq(ResumeIntentScript.take(), {}, "第二次取到空（不会重复续同一场）")


func test_request_battle_resume_without_payload_returns_false() -> void:
	## 没有战斗段时这一步是「什么都没发生」——调用方据此走探索那条老路。
	# Arrange——GSM 空段
	# Act + Assert
	assert_false(bool(launch.call(&"request_battle_resume")),
			"空段不该认作可续战")
	assert_eq(mock_sm.change_calls.size(), 0, "不认作可续战就不得导航到战斗场景")


# ═══════════════════════════════════════════════════════════════════════════════
# 夹具
# ═══════════════════════════════════════════════════════════════════════════════

## 铺一份可续战的档并返回那份载荷（GSM 侧与存档容器侧保持一致）。[br]
## [br][b]为什么 [code]data[/code] 也要给[/b]：[method
## MainMenuLaunch.load_and_resume] 先用它判「成功但空载荷」——空字典会在认战斗段
## 之前就被挡回主菜单，用例就测不到导航分岔了。
func _arrange_battle_save() -> Dictionary:
	var payload: Dictionary = {
		"is_active": true,
		"scene_id": SM.SceneID.COMBAT,
		"phase": 3,
		"turn": 5,
		"current_cost": 1,
		"max_cost": 4,
		"origin_node_id": 771,
		"origin_combat_type": "boss",
		"player_roster": [{"character_id": CHAR_A, "current_hp": 4, "max_hp": 12,
			"is_alive": true, "slot_index": 0, "is_front": true}],
		"enemy_roster": [{"character_id": 100000, "template_id": "san_xiu",
			"current_hp": 6, "max_hp": 16, "is_alive": true, "slot_index": 0,
			"is_front": true}],
		"config": {"character_ids": [CHAR_A, CHAR_B],
			"enemy_template_ids": ["san_xiu"], "enemy_level": 2,
			"rewards": {"lingshi": 30}},
	}
	mock_sl.payload = {"game_state": {"battle_resume": payload}}
	mock_gsm.battle_resume = payload.duplicate(true)
	return payload
