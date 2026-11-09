extends GutTest
## 击杀触发执行端集成测试（DEBT-CBT-018-10 第二阶段）。[br]
## [br][b]背景[/b]：多效果承载落地后，[code]trigger="kill"[/code] 条目（血杀掌击杀回血）
## 只是「可评估不可执行」——出牌结算路径不消费它。本文件锁住执行端的四条语义：[br]
##   1. [b]击杀回血生效[/b]：目标由存活转为阵亡时，治疗真正落库到施法者 HP，
##      且经 [code]character_damaged[/code] 广播负增量（表现层按既有约定飘治疗数字）；[br]
##   2. [b]同一次击杀只触发一次[/b]：同一目标在一条出牌结算里被多条结果项打（或重复命中）
##      也只回一次血；[br]
##   3. [b]未击杀不触发[/b]：目标残血未死 → 治疗不外流（这就是「击杀类条目不进打出结算」的运行时兑现）；[br]
##   4. [b]信息不足不臆造[/b]：结果项没带卡牌数据 / 施法者时静默跳过，不猜治疗量也不猜施法者。[br]
## [br]测试策略（同 test_damage_settlement_wiring.gd）：[code]CS_SCRIPT.new()[/code] 独立实例
## + [code]set_auto_advance(false)[/code]／[code]set_scene_change(false)[/code]；
## 效果数据由 [code]resolve_cb[/code] 桩注入，不依赖 CardEffectEngine Autoload。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const EntryClass: GDScript = preload("res://src/core/card_system/effect_entry.gd")

## 本文件独立的角色 ID 段——不与其它测试文件夹具冲突。
const CHAR_CASTER: int = 7501
const CHAR_VICTIM: int = 7502
const CHAR_SPARE: int = 7503

var cs: Node = null
var _release_ids: Array = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	_release_ids.clear()


func after_each() -> void:
	if cs != null:
		cs.free()
		cs = null
	for cid: int in _release_ids:
		DeploymentSystem.remove_character(cid)
	_release_ids.clear()
	CostSystem.clear_for_battle_end()
	InputManager.clear_locks(&"combat_system")
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


# ═══════════════════════════════════════════════════════════════════════════════
# 夹具
# ═══════════════════════════════════════════════════════════════════════════════

## 施法者上场 + 开战（10/20 HP）；敌方血杀掌目标 5/5。
func _start_with_caster(victim_hp: int = 5) -> void:
	var ok: bool = DeploymentSystem.setup_field([CHAR_CASTER], {})
	assert_true(ok, "前置：施法者上场成功")
	if ok:
		_release_ids.append(CHAR_CASTER)
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_VICTIM, "current_hp": victim_hp,
				"max_hp": victim_hp, "is_alive": true}],
		"character_ids": [CHAR_CASTER],
		"player_stats": {CHAR_CASTER: {"current_hp": 10, "max_hp": 20}},
	})
	cs.call("set_card_instances", {1: {
		"card_instance_id": 1, "cost": 0, "template_id": "test_kill_card"}})
	cs.call("set_hand", [{"card_instance_id": 1, "cost": 0,
			"template_id": "test_kill_card"}])
	cs.call("advance_phase")  # PREPARATION → DRAW
	cs.call("advance_phase")  # DRAW → PLAY


## 效果条目——血杀掌口径的两条：ATK×1.0 伤害（打出即生效）+ 击杀回 2 HP。
func _entry(effect_type: StringName, value: int, trigger: StringName) -> Resource:
	var entry: Resource = EntryClass.new()
	entry.effect_type = effect_type
	entry.value = value
	entry.trigger = trigger
	return entry


## 卡牌效果数据——[code]effects[/code] 列表（字典形态，与 composer 的读取路径同源）。
func _kill_card_data() -> Dictionary:
	return {
		"card_id": &"test_kill_card",
		"effects": [
			_entry(&"damage_multiplier", 100, EntryClass.TRIGGER_ON_PLAY),
			_entry(&"heal", 2, EntryClass.TRIGGER_KILL),
		],
	}


## 注入结算结果项——[code]resolve_cb[/code] 桩。
func _stub_results(results: Array) -> void:
	cs.set("resolve_cb", Callable(func(_card, _targets) -> Array:
		return results))


## 带上下文的击杀结果项（卡牌数据 + 施法者）。
func _kill_item(damage: int) -> Dictionary:
	return {
		"target_id": CHAR_VICTIM, "damage": damage, "side": 1,
		"caster_id": CHAR_CASTER, "card_data": _kill_card_data(),
	}


func _caster_hp() -> int:
	return int(cs.call("get_character_hp", CHAR_CASTER)["current"])


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 击杀回血真正落库（复用现有落库路径，不另开写 HP）
# ═══════════════════════════════════════════════════════════════════════════════

## 一刀打死 5 HP 目标 → 施法者 10 → 12（GDD §②「击杀后回复 2 HP」）。
func test_kill_heals_caster_and_writes_hp() -> void:
	# Arrange
	_start_with_caster(5)
	_stub_results([_kill_item(5)])
	# Act
	assert_true(cs.call("play_card", 1, []), "出牌成功")
	# Assert
	assert_eq(_caster_hp(), 12, "击杀后施法者应回 2 HP（10 → 12）")
	assert_eq(int(cs.call("get_character_hp", CHAR_VICTIM)["current"]), 0, "目标应落库为 0")


## 治疗经 character_damaged 以负增量广播（表现层无需为治疗另开信号）。
func test_kill_heal_emits_negative_damage_payload() -> void:
	# Arrange
	_start_with_caster(5)
	_stub_results([_kill_item(5)])
	var payloads: Array = []
	cs.connect("character_damaged", func(data: Dictionary) -> void:
		payloads.append(data.duplicate(true)))
	# Act
	cs.call("play_card", 1, [])
	# Assert——第 1 条是目标的重伤，第 2 条是施法者的治疗（负值）
	assert_eq(payloads.size(), 2, "伤害 + 治疗各广播一次")
	assert_eq(int(payloads[1]["character_id"]), CHAR_CASTER, "第二条载荷属于施法者")
	assert_eq(int(payloads[1]["damage"]), -2, "治疗以负增量广播（与 UI 符号约定同源）")
	assert_false(bool(payloads[1]["is_kill"]), "治疗不判死")


## 击杀回血只在存在击杀类条目时发生——只有伤害的卡不回血。
func test_card_without_kill_entry_heals_nothing() -> void:
	# Arrange——卡上只有打出即生效的伤害条目
	_start_with_caster(5)
	var plain: Dictionary = {"card_id": &"plain_card", "effects": [
		_entry(&"damage_multiplier", 100, EntryClass.TRIGGER_ON_PLAY)]}
	_stub_results([{"target_id": CHAR_VICTIM, "damage": 5, "side": 1,
			"caster_id": CHAR_CASTER, "card_data": plain}])
	# Act
	cs.call("play_card", 1, [])
	# Assert——目标照样死，施法者不回血（击杀条目不进打出结算的运行时兑现）
	assert_eq(int(cs.call("get_character_hp", CHAR_VICTIM)["current"]), 0, "目标应死亡")
	assert_eq(_caster_hp(), 10, "无击杀类条目 → 不回血")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 同一次击杀只触发一次
# ═══════════════════════════════════════════════════════════════════════════════

## 同一次出牌把同一目标打死两次（两条结果项）→ 只回一次血。
func test_kill_trigger_fires_once_per_kill() -> void:
	# Arrange
	_start_with_caster(5)
	_stub_results([_kill_item(5), _kill_item(5)])
	# Act
	cs.call("play_card", 1, [])
	# Assert——第二条命中时目标已阵亡（died=false），不得再回一次血
	assert_eq(_caster_hp(), 12, "同一次击杀只回 2 HP（10 → 12，而非 14）")


## 重复调用结算（同一批结果项再走一次）不回血——已阵亡的目标不再产生 died 转换。
func test_settle_same_results_twice_heals_once() -> void:
	# Arrange
	_start_with_caster(5)
	var results: Array = [_kill_item(5)]
	# Act——直接调两次落库（第二次目标已死）
	cs.call("_get_damage_settlement").settle_effect(results)
	cs.call("_get_damage_settlement").settle_effect(results)
	# Assert
	assert_eq(_caster_hp(), 12, "重复结算同一批结果仍只回一次血")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 未击杀不触发
# ═══════════════════════════════════════════════════════════════════════════════

## 目标残血未死 → 击杀条目不生效（干跑不知道会不会击杀，执行端只认事实）。
func test_non_fatal_damage_does_not_trigger_heal() -> void:
	# Arrange——20 HP 目标只挨 5 点
	_start_with_caster(20)
	_stub_results([_kill_item(5)])
	# Act
	cs.call("play_card", 1, [])
	# Assert
	assert_eq(int(cs.call("get_character_hp", CHAR_VICTIM)["current"]), 15, "目标应存活（20 → 15）")
	assert_eq(_caster_hp(), 10, "未击杀 → 不回血")


## 击杀的是无关目标时，回血仍落给施法者本身（不会把治疗写错对象）。
func test_heal_targets_caster_not_victim() -> void:
	# Arrange——第二只敌人被打死
	_start_with_caster(5)
	_stub_results([{"target_id": CHAR_VICTIM, "damage": 5, "side": 1,
			"caster_id": CHAR_CASTER, "card_data": _kill_card_data()}])
	# Act
	cs.call("play_card", 1, [])
	# Assert——施法者回血，敌方（已阵亡）HP 不因治疗变化
	assert_eq(_caster_hp(), 12, "施法者回血")
	assert_eq(int(cs.call("get_character_hp", CHAR_VICTIM)["current"]), 0, "敌方 HP 不被治疗波及")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 信息不足不臆造
# ═══════════════════════════════════════════════════════════════════════════════

## 结果项没带卡牌数据（旧 resolve 桩口径）→ 击杀不回血，也不崩。
func test_missing_card_data_does_not_heal() -> void:
	# Arrange
	_start_with_caster(5)
	_stub_results([{"target_id": CHAR_VICTIM, "damage": 5, "side": 1,
			"caster_id": CHAR_CASTER}])
	# Act
	cs.call("play_card", 1, [])
	# Assert
	assert_eq(int(cs.call("get_character_hp", CHAR_VICTIM)["current"]), 0, "击杀判定照常成立")
	assert_eq(_caster_hp(), 10, "拿不到卡牌数据 → 不臆造治疗量")


## 结果项没带施法者 → 击杀不回血（不猜「谁打的」）。
func test_missing_caster_id_does_not_heal() -> void:
	# Arrange
	_start_with_caster(5)
	_stub_results([{"target_id": CHAR_VICTIM, "damage": 5, "side": 1,
			"card_data": _kill_card_data()}])
	# Act
	cs.call("play_card", 1, [])
	# Assert
	assert_eq(_caster_hp(), 10, "拿不到施法者 → 不臆造落库对象")


## 施法者无可信 HP（未种子）→ 不落库、不广播，但不影响击杀判定本身。
func test_unknown_caster_does_not_fabricate_hp() -> void:
	# Arrange——开战后才把施法者加入结算结果（角色不在名册里）
	_start_with_caster(5)
	_stub_results([{"target_id": CHAR_VICTIM, "damage": 5, "side": 1,
			"caster_id": CHAR_SPARE, "card_data": _kill_card_data()}])
	# Act
	cs.call("play_card", 1, [])
	# Assert——未知角色读到 0/0，不冒出一条凭空 HP
	assert_eq(int(cs.call("get_character_hp", CHAR_SPARE)["current"]), 0, "未知角色 HP 保持 0")
	assert_eq(int(cs.call("get_character_hp", CHAR_VICTIM)["current"]), 0, "击杀判定不受影响")
