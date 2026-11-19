extends GutTest
## 缺口三（可玩性收尾）集成测试：伤害与击杀真的记进了战绩记录。
##
## [b]为什么单测这两个数[/b]：战报上的「造成伤害 / 击杀数」是玩家用来判断
## 「这局打得怎么样」的两个数——记错阵营（把挨打当成打人）、把治疗算成伤害、
## 把同一具尸体数两遍，界面照样显示得漂漂亮亮，只有数字是错的。[br]
## [br][b]记账口在唯一写 HP 的地方[/b]（[code]combat_damage_settlement._apply[/code]）：
## 本文件走真实出牌路径，落库侧自己记账，不靠信号反推阵营。[br]
## [br][b]纪律[/b]：计数只进 [code]record[/code]，不新开数据链。
##
## 来源: 本轮任务书缺口三、ADR-0008 §信号分类、GDD combat-system.md §9。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const EntryClass: GDScript = preload("res://src/core/card_system/effect_entry.gd")

## 本文件独占角色 ID 段 7901+。
const CHAR_CASTER: int = 7901
const CHAR_ENEMY: int = 7902
const CARD_ID: int = 31

var cs: Node = null
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


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null
	for cid: int in _release_ids:
		DeploymentSystem.remove_character(cid)
	_release_ids.clear()
	InputManager.clear_locks(&"combat_system")
	GameStateManager.player.character_hp = _hp_before
	_clear_gsm_battle()


func _clear_gsm_battle() -> void:
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


## 开战并推进到 PLAY；双方血量可控。[br]
## [br][b]我方 ATK 固定 30[/b]：卡上 [code]damage_multiplier = 100[/code] 即打出
## 30 点——用例里所有伤害预期都从这一个数推出来，改这里就改全部。
func _start_battle(enemy_hp: int = 20, enemy_atk: int = 0) -> void:
	if DeploymentSystem.setup_field([CHAR_CASTER], {}):
		_release_ids.append(CHAR_CASTER)
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_ENEMY, "current_hp": enemy_hp,
				"max_hp": enemy_hp, "attack": enemy_atk, "is_alive": true}],
		"character_ids": [CHAR_CASTER],
		"player_stats": {CHAR_CASTER: {"current_hp": 10, "max_hp": 10, "atk": 30}},
	})
	cs.call("advance_phase")  # PREPARATION → DRAW
	cs.call("advance_phase")  # DRAW → PLAY


## 注入一张带效果的牌。
func _setup_card(entries: Array) -> void:
	var card: Dictionary = {"card_instance_id": CARD_ID, "cost": 0,
			"template_id": "test_report_card", "effects": entries}
	cs.call("set_card_instances", {CARD_ID: card})
	cs.call("set_hand", [card.duplicate()])


## 一条固定伤害条目。
func _damage_entry(value: int) -> Resource:
	var entry: Resource = EntryClass.new()
	entry.effect_type = &"damage_multiplier"
	entry.value = value
	entry.trigger = EntryClass.TRIGGER_ON_PLAY
	entry.target = &"single_enemy"
	return entry


## 一条治疗条目。
func _heal_entry(value: int) -> Resource:
	var entry: Resource = EntryClass.new()
	entry.effect_type = &"heal"
	entry.value = value
	entry.trigger = EntryClass.TRIGGER_ON_PLAY
	entry.target = &"self"
	return entry


## 结束并取回战绩（[code]battle_end[/code] 的一手载荷）。
func _finish(result: int = CS_SCRIPT.CombatResult.VICTORY) -> Dictionary:
	var sig: Dictionary = {}
	cs.connect("battle_ended", func(_r: int, rewards: Dictionary) -> void:
		sig["rewards"] = rewards)
	cs.call("battle_end", result)
	return sig.get("rewards", {}).get("record", {})


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 伤害记在施加方头上
# ═══════════════════════════════════════════════════════════════════════════════

## 我方打出的伤害记进 [code]damage_dealt.player[/code]，不是敌人那一格。[br]
## [br][b]伤害 = ATK × multiplier/100[/b] = 30 × 1.0 = 30（公式见 combat-system.md）。
func test_player_damage_is_recorded_on_player_side() -> void:
	# Arrange
	_start_battle(40)
	_setup_card([_damage_entry(100)])
	# Act
	assert_true(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER), "出牌成功")
	var record: Dictionary = _finish()
	# Assert
	var dealt: Dictionary = record.get("damage_dealt", {})
	assert_eq(int(dealt.get("player", -1)), 30,
			"玩家打掉敌人 30 HP 应记在 player 头上")
	assert_eq(int(dealt.get("enemy", -1)), 0, "敌人这一格不该被记上")


## 治疗不算伤害（负数增量由记账口过滤）。[br]
## [br][b]掉血用真实攻击路径制造[/b]：直接调结算模块的 [code]settle_attack[/code]
## ——与 Phase 4 打进敌人是同一条落库口，不由用例直接写 HP。[br]
## [br][b]为什么敌方那一格是 4[/b]：落库侧只知道「谁挨了打」（这里是我方），记账口
## 据此把施加方翻成敌方——这正是真实敌人攻击我方时的口径，本用例借它顺带锁住这个
## 方向；要断言的是[b]治疗一分伤害都不产生[/b]。
func test_heal_is_not_counted_as_damage() -> void:
	# Arrange —— 先让我方掉血（同一条落库口），再审治回来
	_start_battle(40)
	cs.call("get_damage_settlement").call("settle_attack", {"target_id": CHAR_CASTER},
			{"damage": 4})
	assert_eq(int(cs.call("get_character_hp", CHAR_CASTER).get("current", -1)), 6,
			"前置：我方 10 → 6")
	_setup_card([_heal_entry(3)])
	# Act
	cs.call("play_card", CARD_ID, [], CHAR_CASTER)
	var record: Dictionary = _finish()
	# Assert
	var dealt: Dictionary = record.get("damage_dealt", {})
	assert_eq(int(dealt.get("player", -1)), 0,
			"回复 3 点不该被记成「我方造成 3 点伤害」")
	assert_eq(int(dealt.get("enemy", -1)), 4,
			"这一段伤害只有一个来源：安排好的那 4 点（被记为敌方施加）——"
			+ "治疗没有多记一笔")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 击杀记在击杀者头上，且只记一次
# ═══════════════════════════════════════════════════════════════════════════════

## 打死敌人 → [code]kills.player[/code] 计 1，[code]kills.enemy[/code] 不计。
func test_kill_is_recorded_on_killer_side() -> void:
	# Arrange
	_start_battle(5)
	_setup_card([_damage_entry(100)])
	# Act
	assert_true(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER), "出牌成功")
	var record: Dictionary = _finish()
	# Assert
	var kills: Dictionary = record.get("kills", {})
	assert_eq(int(kills.get("player", -1)), 1, "我方击杀 1 人")
	assert_eq(int(kills.get("enemy", -1)), 0, "敌人一个也没杀")


## 击杀只计一次——同一具尸体被重复击打不会数成两杀。
func test_kill_counted_once_per_victim() -> void:
	# Arrange —— 敌人 5 HP，第一次打死
	_start_battle(5)
	_setup_card([_damage_entry(100)])
	cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER)
	# Act —— 再打一次（已经死了）
	var reprised: bool = bool(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER))
	var record: Dictionary = _finish()
	# Assert
	var kills: Dictionary = record.get("kills", {})
	assert_eq(int(kills.get("player", -1)), 1,
			"同一具尸体不能被数成两杀（补刀 %s）" % str(reprised))


## 没打死时击杀数为 0（伤害照记）。
func test_no_kill_records_zero_kills() -> void:
	# Arrange —— 敌人 40 HP，30 点一次打不死
	_start_battle(40)
	_setup_card([_damage_entry(100)])
	# Act
	cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER)
	var record: Dictionary = _finish()
	# Assert
	var kills: Dictionary = record.get("kills", {})
	assert_eq(int(kills.get("player", -1)), 0, "敌人还活着，击杀应为 0")
	assert_eq(int(record.get("damage_dealt", {}).get("player", -1)), 30,
			"伤害照记（这一条与击杀分开）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 归零：上一场的数字不串到这一场
# ═══════════════════════════════════════════════════════════════════════════════

## 新一场开战把伤害与击杀一起清零。
func test_new_battle_resets_damage_and_kills() -> void:
	# Arrange —— 第一场打死一个
	_start_battle(5)
	_setup_card([_damage_entry(100)])
	cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER)
	assert_eq(int(cs.call("_get_battle_record").call("build", 1, 1, []).get(
			"kills", {}).get("player", -1)), 1, "前置：第一场已记 1 杀")
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	# Act —— 第二场
	_start_battle(20)
	var record: Dictionary = _finish()
	# Assert
	assert_eq(int(record.get("damage_dealt", {}).get("player", -1)), 0,
			"第二场的伤害应从 0 起算")
	assert_eq(int(record.get("kills", {}).get("player", -1)), 0,
			"第二场的击杀应从 0 起算")
