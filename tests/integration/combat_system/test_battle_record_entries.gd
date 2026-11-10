extends GutTest
## Sprint 18 集成测试：效果条目计数口径（[code]combat_battle_record.gd[/code]）。[br]
## [br][b]为什么单测这个数字[/b]：战绩里的「效果条目数」是策划用来核对
## 「本场到底触发了多少条卡效果」的口径，一旦把普通攻击、被拒绝的出牌、
## 尚未建模的条目算进去，这个数字就没有解释力。[br]
## [br][b]本文件锁定三条[/b]：[br]
##   1. 打出即生效的条目[b]逐条计数[/b]（含尚无执行端的增益/控制——它们同样被触发）；[br]
##   2. 击杀触发的条目[b]在击杀成立时[/b]再计一条；[br]
##   3. 被拒绝的出牌 / 无效果卡[b]不计数[/b]。[br]
## [br]测试策略同 test_on_play_effects.gd：独立 [code]CS_SCRIPT.new()[/code]，
## 效果经卡实例的 [code]effects[/code] 注入，不依赖 CardEffectEngine。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const EntryClass: GDScript = preload("res://src/core/card_system/effect_entry.gd")

## 本文件独占角色 ID 段 7801+。
const CHAR_CASTER: int = 7801
const CHAR_ENEMY: int = 7802
const CARD_ID: int = 21

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


## 开战并推进到 PLAY；敌方 HP 可控（击杀用例给低血量）。
func _start_battle(enemy_hp: int = 20) -> void:
	if DeploymentSystem.setup_field([CHAR_CASTER], {}):
		_release_ids.append(CHAR_CASTER)
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_ENEMY, "current_hp": enemy_hp,
				"max_hp": enemy_hp, "attack": 0, "is_alive": true}],
		"character_ids": [CHAR_CASTER],
		"player_stats": {CHAR_CASTER: {"current_hp": 10, "max_hp": 10, "atk": 10}},
	})
	cs.call("advance_phase")  # PREPARATION → DRAW
	cs.call("advance_phase")  # DRAW → PLAY


## 条目工厂——目标缺省空（= 未声明，按非 self 处理）。
func _entry(effect_type: StringName, value: int, trigger: StringName = EntryClass.TRIGGER_ON_PLAY,
		target: StringName = &"") -> Resource:
	var entry: Resource = EntryClass.new()
	entry.effect_type = effect_type
	entry.value = value
	entry.trigger = trigger
	entry.target = target
	return entry


## 注入手牌（带 [code]effects[/code] 列表）。
func _setup_card(entries: Array) -> void:
	var card: Dictionary = {"card_instance_id": CARD_ID, "cost": 0,
			"template_id": "test_record_card", "effects": entries}
	cs.call("set_card_instances", {CARD_ID: card})
	cs.call("set_hand", [card.duplicate()])


## 当前累计条目数（战绩累积器的只读口径）。
func _count() -> int:
	return int(cs.call("_get_battle_record").call("effect_entry_count"))


## 结束并取回战绩（[code]battle_end[/code] 的一手载荷）。
func _finish(result: int = CS_SCRIPT.CombatResult.VICTORY) -> Dictionary:
	var sig: Dictionary = {}
	cs.connect("battle_ended", func(_r: int, rewards: Dictionary) -> void:
		sig["rewards"] = rewards)
	cs.call("battle_end", result)
	return sig.get("rewards", {}).get("record", {})


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 打出即生效的条目逐条计数
# ═══════════════════════════════════════════════════════════════════════════════

## 一条伤害 + 一条治疗 → 计 2 条。
func test_counts_each_on_play_entry() -> void:
	# Arrange
	_start_battle()
	_setup_card([
		_entry(&"damage_multiplier", 100, EntryClass.TRIGGER_ON_PLAY, &"single_enemy"),
		_entry(&"heal", 2, EntryClass.TRIGGER_ON_PLAY, &"self"),
	])
	# Act
	assert_true(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER), "出牌成功")
	# Assert
	assert_eq(_count(), 2, "两条 ON_PLAY 条目各计一条")


## 尚无执行端的条目（增益）同样计入——它们确实被这张卡触发了。
func test_counts_unimplemented_on_play_entries() -> void:
	# Arrange
	_start_battle()
	_setup_card([_entry(&"attack_buff", 3, EntryClass.TRIGGER_ON_PLAY, &"self")])
	# Act
	cs.call("play_card", CARD_ID, [], CHAR_CASTER)
	# Assert
	assert_eq(_count(), 1, "增益条目虽无执行端，但已进入执行端并计数")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 击杀触发在击杀成立时再计一条
# ═══════════════════════════════════════════════════════════════════════════════

## 伤害条目击杀 5 HP 敌人 + 击杀条目回血 → 2 条。
func test_counts_kill_entry_when_kill_happens() -> void:
	# Arrange
	_start_battle(5)
	_setup_card([
		_entry(&"damage_multiplier", 100, EntryClass.TRIGGER_ON_PLAY, &"single_enemy"),
		_entry(&"heal", 2, EntryClass.TRIGGER_KILL, &"self"),
	])
	# Act
	assert_true(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER), "出牌成功")
	# Assert
	assert_eq(int(cs.call("get_character_hp", CHAR_ENEMY)["current"]), 0, "前置：敌人已死")
	assert_eq(_count(), 2, "ON_PLAY 一条 + 击杀成立后 KILL 一条")


## 未击杀时击杀条目不计数（它没被触发）。
func test_kill_entry_not_counted_without_kill() -> void:
	# Arrange——敌人 20 HP，打不死
	_start_battle(20)
	_setup_card([
		_entry(&"damage_multiplier", 100, EntryClass.TRIGGER_ON_PLAY, &"single_enemy"),
		_entry(&"heal", 2, EntryClass.TRIGGER_KILL, &"self"),
	])
	# Act
	cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER)
	# Assert
	assert_eq(_count(), 1, "只有 ON_PLAY 那一条计入")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 不计数的情况
# ═══════════════════════════════════════════════════════════════════════════════

## 阶段不对被拒绝的出牌——一条都不计。
func test_rejected_card_counts_nothing() -> void:
	# Arrange——停在 DRAW，不出牌阶段
	cs.call("battle_start", {"enemy_roster": [{"character_id": CHAR_ENEMY,
			"current_hp": 20, "max_hp": 20, "is_alive": true}],
			"character_ids": [CHAR_CASTER]})
	cs.call("advance_phase")  # PREPARATION → DRAW
	_setup_card([_entry(&"damage_multiplier", 100, EntryClass.TRIGGER_ON_PLAY, &"single_enemy")])
	# Act
	assert_false(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER), "非 PLAY 阶段应被拒绝")
	# Assert
	assert_eq(_count(), 0, "被拒绝的出牌不计数")


## 无效果卡（测试桩）——不计数，但出牌本身照常成功。
func test_card_without_effects_counts_nothing() -> void:
	# Arrange
	_start_battle()
	cs.call("set_card_instances", {CARD_ID: {"card_instance_id": CARD_ID,
			"cost": 0, "template_id": "plain_test_card"}})
	cs.call("set_hand", [{"card_instance_id": CARD_ID, "cost": 0,
			"template_id": "plain_test_card"}])
	# Act
	assert_true(cs.call("play_card", CARD_ID, [], CHAR_CASTER), "无效果卡仍可出")
	# Assert
	assert_eq(_count(), 0, "无条目 → 不计数")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 计数进战绩并随开战归零
# ═══════════════════════════════════════════════════════════════════════════════

## 计数定格进 [code]record.effect_entries[/code]。
func test_record_carries_effect_entry_count() -> void:
	# Arrange
	_start_battle()
	_setup_card([
		_entry(&"damage_multiplier", 100, EntryClass.TRIGGER_ON_PLAY, &"single_enemy"),
		_entry(&"heal", 2, EntryClass.TRIGGER_ON_PLAY, &"self"),
	])
	cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER)
	# Act
	var record: Dictionary = _finish()
	# Assert
	assert_eq(int(record.get("effect_entries", -1)), 2, "record.effect_entries 应定格为 2")


## 下一场开战归零——上一场的计数不能串场。
func test_new_battle_resets_entry_count() -> void:
	# Arrange——第一场计 1 条后结束
	_start_battle()
	_setup_card([_entry(&"heal", 2, EntryClass.TRIGGER_ON_PLAY, &"self")])
	cs.call("play_card", CARD_ID, [], CHAR_CASTER)
	assert_eq(_count(), 1, "前置：第一场已计 1 条")
	cs.call("battle_end", CS_SCRIPT.CombatResult.VICTORY)
	# Act——第二场
	_start_battle()
	# Assert
	assert_eq(_count(), 0, "新一场开战应归零")
