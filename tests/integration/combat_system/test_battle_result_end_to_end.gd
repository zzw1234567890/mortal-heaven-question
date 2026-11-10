extends GutTest
## Sprint 18 端到端：真战斗系统 → 真接线 → 结算对象 → 结算/战败场景 → HP 回读。[br]
## [br][b]为什么还要这一层[/b]：另外两个测试各锁一段（[code]test_battle_record_carryover.gd[/code]
## 锁战斗侧的记录与持久化；[code]test_combat_result_bridge.gd[/code] 锁展示侧折算与降级），
## 但真出问题的往往是[b]接缝[/b]——战斗系统发出的 [code]battle_ended[/code] 载荷形状，
## 与展示侧读的字段是否真的一致。[br]
## [br][b]本文件只做一件事[/b]：从 [code]battle_end[/code] 一路走到结算场景上的文本，
## 不对中间任何一环做桩，胜负两个方向各走一遍。[br]
## [br]本文件独占角色 ID 段 7901+。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const BridgeScript := preload("res://src/ui/combat/shared/combat_result_bridge.gd")
const CarryoverScript := preload("res://src/feature/combat/combat_hp_carryover.gd")
const ViewScript := preload("res://src/feature/combat/combat_result_view.gd")

const CHAR_HERO: int = 7901
const CHAR_ENEMY: int = 7902
const RESULT_SCREEN: String = "res://src/ui/result_screen/result_screen.tscn"
const DEFEAT_SCREEN: String = "res://src/ui/defeat_screen/defeat_screen.tscn"

var cs: Node = null
var bridge: RefCounted = null
var _release_ids: Array = []
var _hp_before: Dictionary = {}


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	_clear_gsm_battle()
	_hp_before = GameStateManager.player.get("character_hp", {}).duplicate(true)
	GameStateManager.player.character_hp = {}
	_release_ids.clear()
	ViewScript.clear()
	# 真接线——本文件要验证的正是它
	bridge = BridgeScript.new()
	bridge.call(&"bind", cs)


func after_each() -> void:
	if bridge != null:
		bridge.call(&"unbind")
		bridge = null
	if cs != null:
		cs.free()
		cs = null
	for cid: int in _release_ids:
		DeploymentSystem.remove_character(cid)
	_release_ids.clear()
	InputManager.clear_locks(&"combat_system")
	GameStateManager.player.character_hp = _hp_before
	_clear_gsm_battle()
	ViewScript.clear()


func _clear_gsm_battle() -> void:
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


## 开战——我方 1 人（显式 HP）+ 敌方 1 人。
func _start(hero_hp: int, enemy_hp: int) -> void:
	if DeploymentSystem.setup_field([CHAR_HERO], {}):
		_release_ids.append(CHAR_HERO)
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_ENEMY, "current_hp": enemy_hp,
				"max_hp": enemy_hp, "attack": 0, "is_alive": true}],
		"character_ids": [CHAR_HERO],
		"player_stats": {CHAR_HERO: {"current_hp": hero_hp, "max_hp": 10}},
	})


## 挂载结算场景（注入最小 SceneManager 桩）。
func _mount(path: String) -> Control:
	var packed: PackedScene = load(path)
	var screen: Control = packed.instantiate() as Control
	add_child_autofree(screen)
	return screen


func _hp_of(character_id: int) -> Dictionary:
	return CarryoverScript.new(cs).read_one(character_id)


# ═══════════════════════════════════════════════════════════════════════════════
# 胜利：真战斗 → 真接线 → 结算场景
# ═══════════════════════════════════════════════════════════════════════════════

func test_victory_end_to_end_shows_record_and_persists_hp() -> void:
	# Arrange——我方 8/10，敌方 5 HP；敌方被打空
	_start(8, 5)
	cs.call("_get_roster_state").call("apply_damage", CHAR_HERO, 3)   # 我方 8 → 5
	cs.call("_get_roster_state").call("apply_damage", CHAR_ENEMY, 5)  # 敌方 → 0
	# Act——真 battle_end（发射真载荷 → 接线发布 → 场景读回）
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	var screen: Control = _mount(RESULT_SCREEN)
	# Assert——场景渲染的是真战绩
	var title: Label = screen.get("title_label") as Label
	assert_eq(title.text, "战斗胜利", "结算场景标题应来自真载荷")
	var brief: String = (screen.get("brief_label") as Label).text
	assert_true(brief.contains("我方: 存活 1/1，剩余 HP 5"), "摘要应含真实剩余 HP")
	assert_true(brief.contains("敌方: 存活 0/1，剩余 HP 0"), "摘要应含敌方清零")
	# Assert——持久层同步落地
	assert_eq(int(_hp_of(CHAR_HERO).get("current_hp", -1)), 5, "我方残血应回写")
	assert_eq(_hp_of(CHAR_ENEMY), {}, "敌方不进持久层")


# ═══════════════════════════════════════════════════════════════════════════════
# 战败：真战斗 → 真接线 → 战败场景 → 下一场带伤开局
# ═══════════════════════════════════════════════════════════════════════════════

func test_defeat_end_to_end_then_next_battle_seeds_carryover() -> void:
	# Arrange——我方 6/10，被打空
	_start(6, 20)
	cs.call("_get_roster_state").call("apply_damage", CHAR_HERO, 6)
	# Act
	cs.call("battle_end", CS_SCRIPT.CombatResult.DEFEAT)
	var screen: Control = _mount(DEFEAT_SCREEN)
	# Assert——战败场景读到真载荷
	var title: Label = screen.get("title_label") as Label
	assert_eq(title.text, "战斗失败", "战败场景标题应来自真载荷")
	var brief: String = (screen.get("brief_label") as Label).text
	assert_true(brief.contains("我方: 存活 0/1，剩余 HP 0"), "摘要应含我方归零")
	assert_eq(int(_hp_of(CHAR_HERO).get("current_hp", -1)), 0, "阵亡照实持久化为 0")
	# Act——下一场：只带持久层，不给 player_stats
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_ENEMY, "current_hp": 20,
				"max_hp": 20, "is_alive": true}],
		"character_ids": [CHAR_HERO],
	})
	# Assert——带伤（此处为阵亡态）开局，而不是模板满血
	assert_eq(int(cs.call("get_character_hp", CHAR_HERO)["current"]), 0,
			"第二场应从持久层读回 0，而不是满血 10")
	assert_eq(int(cs.call("get_character_hp", CHAR_HERO)["max"]), 10,
			"上限同样来自持久层")


## 撤退也走 DEFEAT_SCREEN——同样要能看到战绩。
func test_retreat_end_to_end_shows_record() -> void:
	# Arrange
	_start(9, 14)
	cs.call("_get_roster_state").call("apply_damage", CHAR_HERO, 2)
	# Act
	cs.call("confirm_retreat")
	var screen: Control = _mount(DEFEAT_SCREEN)
	# Assert
	assert_eq((screen.get("title_label") as Label).text, "撤退", "撤退应显示撤退标题")
	var brief: String = (screen.get("brief_label") as Label).text
	assert_true(brief.contains("我方: 存活 1/1，剩余 HP 7"), "撤退时仍应看到剩余 HP")
	assert_eq(int(_hp_of(CHAR_HERO).get("current_hp", -1)), 7, "撤退同样回写残血")
