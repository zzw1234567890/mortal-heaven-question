extends GutTest
## Sprint 18 集成测试：战斗结束 → 战绩定格 → 我方 HP 跨场回写/回读。[br]
## [br][b]覆盖三条链路[/b]：[br]
##   1. [code]battle_end(VICTORY)[/code] → [code]rewards["record"][/code] 携带
##      胜负 / 回合数 / 双方剩余 HP / 效果条目数；[br]
##   2. [code]battle_end(DEFEAT)[/code] 同样定格（战败方向不能缺数据）；[br]
##   3. 我方残血经 GSM [code]player.character_hp[/code] 持久化，下一场
##      [code]battle_start[/code] 读回（DEBT-CBT-018-3 的「带伤进下一场」）。[br]
## [br][b]测试策略[/b]（先例 test_damage_settlement_wiring.gd）：[code]CS_SCRIPT.new()[/code]
## + [code]set_auto_advance(false)[/code] / [code]set_scene_change(false)[/code]；
## 真实 GSM / DeploymentSystem 参与——被测的正是这条持久化链路本身。[br]
## [br]本文件独占角色 ID 段 7701+（不与其它套件串场）。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const CarryoverScript := preload("res://src/feature/combat/combat_hp_carryover.gd")
const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")

const CHAR_HERO: int = 7701
const CHAR_SPARE: int = 7702
const CHAR_ENEMY: int = 7703

var cs: Node = null
var _release_ids: Array = []
var _hp_before: Dictionary = {}
var _ai_roster_before: Array = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	_clear_gsm_battle()
	# 快照持久 HP——套件结束原样还原（Autoload 跨套件共享）
	_hp_before = GameStateManager.player.get("character_hp", {}).duplicate(true)
	GameStateManager.player.character_hp = {}
	_ai_roster_before = AISystem.get_enemy_roster().duplicate()
	_release_ids.clear()
	ViewScript.clear()


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null
	for cid: int in _release_ids:
		DeploymentSystem.remove_character(cid)
	_release_ids.clear()
	InputManager.clear_locks(&"combat_system")
	AISystem.set_enemy_roster(_ai_roster_before)
	GameStateManager.player.character_hp = _hp_before
	_clear_gsm_battle()
	ViewScript.clear()


## 清理 GSM 战斗域——不调 _do_flush（避免 batch_updated 干扰信号断言）。
func _clear_gsm_battle() -> void:
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


## 上场一名角色并登记清理。
func _deploy(character_id: int) -> void:
	if DeploymentSystem.setup_field([character_id], {}):
		_release_ids.append(character_id)


## 开战——我方 1 人（显式 HP）+ 敌方 1 人。
func _start_with(hero_hp: int, hero_max: int = 10) -> void:
	_deploy(CHAR_HERO)
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_ENEMY, "current_hp": 20,
				"max_hp": 20, "attack": 4, "is_alive": true}],
		"character_ids": [CHAR_HERO],
		"player_stats": {CHAR_HERO: {"current_hp": hero_hp, "max_hp": hero_max}},
	})


## 持久层里该角色的记录（回读接口，不直接摸 GSM 内部结构）。
func _persisted(character_id: int) -> Dictionary:
	return CarryoverScript.new(cs).read_one(character_id)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 胜利方向的战绩 + HP 回写
# ═══════════════════════════════════════════════════════════════════════════════

func test_victory_records_outcome_and_both_sides_hp() -> void:
	# Arrange
	_start_with(6, 10)
	cs.call("_get_roster_state").call("apply_damage", CHAR_HERO, 2)   # 我方 6 → 4
	cs.call("_get_roster_state").call("apply_damage", CHAR_ENEMY, 20)  # 敌方全灭
	var sig: Dictionary = {}
	cs.connect("battle_ended", func(_r: int, rewards: Dictionary) -> void:
		sig["rewards"] = rewards)
	# Act
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	# Assert——战绩定格
	var record: Dictionary = sig["rewards"].get("record", {})
	assert_false(record.is_empty(), "battle_ended 载荷应带 record")
	assert_eq(String(record.get("outcome")), "victory", "outcome=victory")
	assert_eq(int(record.get("turn_count")), 1, "回合数应为结束时的回合")
	assert_eq(int(record.get("player", {}).get("remaining_hp")), 4, "我方剩余 HP 应为 4")
	assert_eq(int(record.get("enemy", {}).get("remaining_hp")), 0, "敌方剩余 HP 应为 0")
	assert_eq(int(record.get("player", {}).get("alive_count")), 1, "我方存活 1 人")
	assert_eq(int(record.get("enemy", {}).get("alive_count")), 0, "敌方存活 0 人")


func test_victory_writes_back_player_hp() -> void:
	# Arrange
	_start_with(10, 10)
	cs.call("_get_roster_state").call("apply_damage", CHAR_HERO, 3)
	# Act
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	# Assert——持久层落库 current/max
	var saved: Dictionary = _persisted(CHAR_HERO)
	assert_eq(int(saved.get("current_hp", -1)), 7, "残血应回写为 7")
	assert_eq(int(saved.get("max_hp", -1)), 10, "上限应一并保存")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 战败方向
# ═══════════════════════════════════════════════════════════════════════════════

func test_defeat_records_outcome_and_zero_hero_hp() -> void:
	# Arrange——我方阵亡、敌方存活
	_start_with(6, 10)
	cs.call("_get_roster_state").call("apply_damage", CHAR_HERO, 6)
	var sig: Dictionary = {}
	cs.connect("battle_ended", func(_r: int, rewards: Dictionary) -> void:
		sig["rewards"] = rewards)
	# Act
	cs.call("battle_end", CS_SCRIPT.CombatResult.DEFEAT)
	# Assert
	var record: Dictionary = sig["rewards"].get("record", {})
	assert_eq(String(record.get("outcome")), "defeat", "outcome=defeat")
	assert_eq(int(record.get("player", {}).get("remaining_hp")), 0, "我方剩余 HP 为 0")
	assert_eq(int(record.get("player", {}).get("alive_count")), 0, "我方存活 0 人")
	assert_eq(int(record.get("enemy", {}).get("remaining_hp")), 20, "敌方应保持 20")


## 阵亡照实写 0——不夹到 1 冒充存活（GDD §7 跨战斗死亡持久性）。
func test_defeat_persists_zero_hp_for_fallen_hero() -> void:
	# Arrange
	_start_with(6, 10)
	cs.call("_get_roster_state").call("apply_damage", CHAR_HERO, 6)
	# Act
	cs.call("battle_end", CS_SCRIPT.CombatResult.DEFEAT)
	# Assert
	assert_eq(int(_persisted(CHAR_HERO).get("current_hp", -1)), 0, "阵亡应持久化为 0")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 跨场回读（带伤进下一场）
# ═══════════════════════════════════════════════════════════════════════════════

## 上一场结束时 7/10 → 下一场开战种子读回 7/10（不是模板满血）。
func test_next_battle_seeds_from_persisted_hp() -> void:
	# Arrange——第一场：打掉 3 点后结束
	_start_with(10, 10)
	cs.call("_get_roster_state").call("apply_damage", CHAR_HERO, 3)
	cs.call("battle_end", CS_SCRIPT.CombatResult.DEFEAT)
	assert_eq(int(_persisted(CHAR_HERO).get("current_hp", -1)), 7, "前置：残血已落库")
	# Act——第二场：不带 player_stats，只靠持久层
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_ENEMY, "current_hp": 20,
				"max_hp": 20, "is_alive": true}],
		"character_ids": [CHAR_HERO],
	})
	# Assert
	var hp: Dictionary = cs.call("get_character_hp", CHAR_HERO)
	assert_eq(int(hp["current"]), 7, "第二场应按持久残血开局")
	assert_eq(int(hp["max"]), 10, "上限同样来自持久层")


## 显式 player_stats 优先于持久层（上游已裁定时不覆盖其口径）。
func test_explicit_player_stats_override_persisted_hp() -> void:
	# Arrange——持久层先放一个「残血」
	GameStateManager.player.character_hp = {str(CHAR_HERO): {"current_hp": 2, "max_hp": 10}}
	_deploy(CHAR_HERO)
	# Act——开战时显式给满血
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_ENEMY, "current_hp": 20,
				"max_hp": 20, "is_alive": true}],
		"character_ids": [CHAR_HERO],
		"player_stats": {CHAR_HERO: {"current_hp": 10, "max_hp": 10}},
	})
	# Assert
	assert_eq(int(cs.call("get_character_hp", CHAR_HERO)["current"]), 10,
			"显式 player_stats 应覆盖持久残血")


## 未上场角色不受影响——逐键写入，不整体替换。
func test_write_back_keeps_off_field_characters() -> void:
	# Arrange——持久层先有另一名角色
	GameStateManager.player.character_hp = {str(CHAR_SPARE): {"current_hp": 5, "max_hp": 9}}
	_start_with(10, 10)
	cs.call("_get_roster_state").call("apply_damage", CHAR_HERO, 4)
	# Act
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	# Assert
	assert_eq(int(_persisted(CHAR_SPARE).get("current_hp", -1)), 5,
			"未上场角色的残血应保持")
	assert_eq(int(_persisted(CHAR_HERO).get("current_hp", -1)), 6, "上场角色照常回写")


## 敌我双方都只剩 1 人时，敌方 HP 绝不写进我方持久层。
func test_enemy_hp_is_not_persisted() -> void:
	# Arrange
	_start_with(10, 10)
	cs.call("_get_roster_state").call("apply_damage", CHAR_ENEMY, 5)
	# Act
	cs.call("battle_end", CS_SCRIPT.CombatResult.RETREAT)
	# Assert
	assert_eq(_persisted(CHAR_ENEMY), {}, "敌方条目不得进入 player.character_hp")
