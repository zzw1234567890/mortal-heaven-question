extends GutTest
## UI 出牌链路集成测试：施法者接线 + 治疗按实际增量广播（DEBT-CBT-018-10 第四阶段）。[br]
## [br][b]背景[/b]：`CombatSystem.play_card()` 的 `caster_id` 此前无人传入，倍率伤害与
## 出牌治疗在真实对局里从不结算；治疗广播又带的是「申请量」的取负，满血时会飘出
## 不存在的回血数字。[br]
## [br][b]本文件锁定四条语义[/b]：[br]
##   1. 经 UI 链路（装配台 → 出牌桥）出牌时，施法者由阵位裁定并生效——倍率伤害
##      按施法者 ATK 结算、治疗落施法者；[br]
##   2. 不传施法者（-1 口径）时倍率伤害与治疗[b]仍不结算[/b]（不猜谁出的牌）；[br]
##   3. 满血治疗[b]不广播[/b]（零增量）；[br]
##   4. 部分溢出只广播[b]实际回血量[/b]。[br]
## [br]测试策略（同 test_on_play_effects.gd）：[code]CS_SCRIPT.new()[/code] 独立实例 +
## 真实 DeploymentSystem 阵位；卡牌效果注入在卡实例字典里，不依赖 CardEffectEngine。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const StageScript: GDScript = preload("res://src/ui/combat/layout/combat_actor_stage.gd")
const EntryClass: GDScript = preload("res://src/core/card_system/effect_entry.gd")

## 本文件独立的角色 ID 段——不与其它测试文件夹具冲突。
const CHAR_CASTER: int = 7701
const CHAR_ENEMY: int = 7702
const CARD_ID: int = 77

var cs: Node = null
var stage: Node = null
var _release_ids: Array = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	cs.set("resolve_cb", Callable(func(_card, _targets) -> Array:
		return []))
	stage = StageScript.new()
	add_child_autofree(stage)
	stage.call(&"setup", cs, DeploymentSystem, null, null)
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

## 施法者上场 + 开战（默认 8/10 HP、攻击力 3），敌方 20 HP。
func _start_battle(caster_hp: int = 8, caster_atk: int = 3) -> void:
	_start_battle_with_enemy_hp(20, caster_hp, caster_atk)


## 同上，但指定敌方初始 HP（击杀用例要一刀打死）。
func _start_battle_with_enemy_hp(enemy_hp: int, caster_hp: int, caster_atk: int) -> void:
	var ok: bool = DeploymentSystem.setup_field([CHAR_CASTER], {})
	assert_true(ok, "前置：施法者上场成功")
	if ok:
		_release_ids.append(CHAR_CASTER)
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_ENEMY, "current_hp": enemy_hp,
				"max_hp": enemy_hp, "attack": 4, "is_alive": true}],
		"character_ids": [CHAR_CASTER],
		"player_stats": {CHAR_CASTER: {"current_hp": caster_hp, "max_hp": 10,
				"atk": caster_atk}},
	})
	cs.call("advance_phase")  # PREPARATION → DRAW
	cs.call("advance_phase")  # DRAW → PLAY


## 效果条目（[code]target[/code] 空 = 未声明）。
func _entry(effect_type: StringName, value: int, target: StringName = &"") -> Resource:
	var entry: Resource = EntryClass.new()
	entry.effect_type = effect_type
	entry.value = value
	entry.target = target
	entry.trigger = EntryClass.TRIGGER_ON_PLAY
	return entry


## 击杀触发条目（[code]trigger = kill[/code]）。
func _kill_entry(effect_type: StringName, value: int,
		target: StringName = &"") -> Resource:
	var entry: Resource = _entry(effect_type, value, target)
	entry.trigger = EntryClass.TRIGGER_KILL
	return entry


## 注入手牌——卡实例带着 [code]effects[/code] 列表。
func _setup_card(entries: Array) -> void:
	var card: Dictionary = {
		"card_instance_id": CARD_ID, "cost": 0, "template_id": "test_ui_play_card",
		"effects": entries,
	}
	cs.call("set_card_instances", {CARD_ID: card})
	cs.call("set_hand", [card.duplicate()])


func _hp(character_id: int) -> int:
	return int(cs.call("get_character_hp", character_id)["current"])


## 收集 character_damaged 载荷。
func _collect_payloads() -> Array:
	var payloads: Array = []
	cs.connect("character_damaged", func(data: Dictionary) -> void:
		payloads.append(data.duplicate(true)))
	return payloads


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 施法者接线：经 UI 链路出牌，倍率伤害与治疗才真正生效
# ═══════════════════════════════════════════════════════════════════════════════

## 阵位里有施法者 → 装配台出牌时把该 ID 传进去：ATK 3 × 150% = 4 落敌方。
func test_ui_play_resolves_caster_and_deals_multiplier_damage() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([_entry(&"damage_multiplier", 150, &"single_enemy")])
	assert_eq(int(stage.call(&"current_caster_id")), CHAR_CASTER, "前置：阵位施法者已裁定")
	# Act
	assert_true(bool(stage.call(&"play_card", CARD_ID, [CHAR_ENEMY])), "出牌成功")
	# Assert
	assert_eq(_hp(CHAR_ENEMY), 16, "倍率伤害按施法者 ATK 结算（20 → 16）")
	assert_eq(_hp(CHAR_CASTER), 8, "施法者 HP 不受伤害条目影响")

## 阵位里有施法者 → 打出的 self 治疗落到施法者。
func test_ui_play_resolves_caster_and_heals_caster() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([_entry(&"heal", 3, &"self")])
	# Act
	stage.call(&"play_card", CARD_ID, [CHAR_ENEMY])
	# Assert
	assert_eq(_hp(CHAR_CASTER), 10, "治疗落施法者并夹到上限（8 + 3 → 10）")

## 无阵位（施法者判不出）→ 传 -1，倍率伤害与治疗都不结算（不猜谁出的牌）。
func test_ui_play_without_caster_settles_nothing() -> void:
	# Arrange——不开战布阵，直接开战（阵位为空）
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_ENEMY, "current_hp": 20,
				"max_hp": 20, "attack": 4, "is_alive": true}],
		"character_ids": [],
	})
	cs.call("advance_phase")
	cs.call("advance_phase")
	_setup_card([_entry(&"damage_multiplier", 150, &"single_enemy"),
		_entry(&"heal", 3, &"self")])
	var payloads: Array = _collect_payloads()
	# Act
	assert_true(bool(stage.call(&"play_card", CARD_ID, [CHAR_ENEMY])), "出牌本身成功")
	# Assert
	assert_eq(_hp(CHAR_ENEMY), 20, "拿不到施法者 → 倍率伤害不结算")
	assert_eq(payloads.size(), 0, "无效果落库 → 零广播")

## 直接调系统 API 且不传施法者 → 同样不结算（缺省 -1 的既有口径不被桥绕过）。
func test_direct_play_without_caster_settles_nothing() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([_entry(&"damage_multiplier", 150, &"single_enemy"),
		_entry(&"heal", 3, &"self")])
	# Act——不传 caster_id
	cs.call("play_card", CARD_ID, [CHAR_ENEMY])
	# Assert
	assert_eq(_hp(CHAR_ENEMY), 20, "缺省 -1 → 倍率伤害不结算")
	assert_eq(_hp(CHAR_CASTER), 8, "缺省 -1 → 治疗不结算")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 治疗广播按实际增量
# ═══════════════════════════════════════════════════════════════════════════════

## 8/10 申请 3 点 → 只回 2 点，广播的负增量必须是 2。
func test_partial_overflow_broadcasts_actual_heal() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([_entry(&"heal", 3, &"self")])
	var payloads: Array = _collect_payloads()
	# Act
	stage.call(&"play_card", CARD_ID, [CHAR_ENEMY])
	# Assert
	assert_eq(payloads.size(), 1, "治疗广播一次")
	assert_eq(int(payloads[0]["character_id"]), CHAR_CASTER, "载荷属于施法者")
	assert_eq(int(payloads[0]["damage"]), -2, "只广播实际回血 2（8 → 10，申请 3）")

## 满血 10/10 申请 3 点 → HP 不变且不广播（不飘不存在的回血数字）。
func test_full_hp_heal_broadcasts_nothing() -> void:
	# Arrange
	_start_battle(10, 3)
	_setup_card([_entry(&"heal", 3, &"self")])
	var payloads: Array = _collect_payloads()
	# Act
	stage.call(&"play_card", CARD_ID, [CHAR_ENEMY])
	# Assert
	assert_eq(_hp(CHAR_CASTER), 10, "满血保持 10")
	assert_eq(payloads.size(), 0, "零增量 → 不广播 character_damaged")

## 一次出牌同时有伤害与治疗 → 先掉血后回血，两条载荷的增量都是实际值。
func test_damage_then_heal_payload_order_and_values() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([
		_entry(&"damage_multiplier", 150, &"single_enemy"),
		_entry(&"heal", 3, &"self"),
	])
	var payloads: Array = _collect_payloads()
	# Act
	stage.call(&"play_card", CARD_ID, [CHAR_ENEMY])
	# Assert
	assert_eq(payloads.size(), 2, "伤害 + 治疗各广播一次")
	assert_eq(int(payloads[0]["character_id"]), CHAR_ENEMY, "先广播敌方掉血")
	assert_eq(int(payloads[0]["damage"]), 4, "伤害增量为实际扣血 4")
	assert_eq(int(payloads[1]["character_id"]), CHAR_CASTER, "后广播施法者回血")
	assert_eq(int(payloads[1]["damage"]), -2, "治疗增量为实际回血 2")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 击杀回血走同一条 apply_heal——满血时同样零增量不广播
# ═══════════════════════════════════════════════════════════════════════════════

## 击杀真的发生、但施法者满血 → 击杀回血零增量，只广播敌方掉血那一条。[br]
## 锁定「击杀触发」与「出牌治疗」共用同一个按实际增量广播的落库入口。
func test_kill_heal_at_full_hp_broadcasts_only_damage() -> void:
	# Arrange——4 HP 敌方必被 ATK 3 × 150% = 4 打死；施法者满血 10/10
	_start_battle_with_enemy_hp(4, 10, 3)
	_setup_card([
		_entry(&"damage_multiplier", 150, &"single_enemy"),
		_kill_entry(&"heal", 2, &"self"),
	])
	var payloads: Array = _collect_payloads()
	# Act
	stage.call(&"play_card", CARD_ID, [CHAR_ENEMY])
	# Assert
	assert_eq(_hp(CHAR_ENEMY), 0, "目标被击杀（前置成立）")
	assert_eq(_hp(CHAR_CASTER), 10, "满血施法者回血不改变 HP")
	assert_eq(payloads.size(), 1, "零增量治疗不广播——只剩敌方掉血那一条")
	assert_eq(int(payloads[0]["character_id"]), CHAR_ENEMY, "唯一载荷属于敌方")
