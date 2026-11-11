extends GutTest
## 出牌执行端集成测试：damage_multiplier 与 heal 真正落库（DEBT-CBT-018-10 执行端）。[br]
## [br][b]背景[/b]：这两类效果此前只在评估层算出数值——[code]play_card[/code] 的效果结算走
## [code]CardEffectEngine.resolve[/code]，而该 Autoload 上根本没有这个方法（回退空数组），
## 于是「ATK × 倍率」的伤害从未落库、出牌治疗只有击杀触发那条支路会落。[br]
## [br][b]本文件锁定四条语义[/b]：[br]
##   1. 倍率伤害按「攻击力 × 倍率」结算并[b]向下取整[/b]（ATK 3 × 150% → 4）；[br]
##   2. 治疗落在施法者身上，且[b]不超过上限[/b]（8/10 + 3 → 10），广播的是
##      [b]实际回血量[/b]（-2）而非申请量；满血零增量 → 不广播；[br]
##   3. [code]target = self[/code] 的效果[b]只作用于施法者[/b]，绝不误伤目标；[br]
##   4. 无倍率无治疗的卡[b]行为逐位不变[/b]（不落库、不广播）。[br]
## [br]测试策略（同 test_kill_trigger_settlement.gd）：[code]CS_SCRIPT.new()[/code] 独立实例
## + [code]set_auto_advance(false)[/code]／[code]set_scene_change(false)[/code]；
## 卡牌效果直接注入在卡牌实例字典里，不依赖 CardEffectEngine Autoload。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const EntryClass: GDScript = preload("res://src/core/card_system/effect_entry.gd")
const DebuffManagerScript := preload("res://src/feature/combat/combat_debuff_manager.gd")

## 本文件独立的角色 ID 段——不与其它测试文件夹具冲突。
const CHAR_CASTER: int = 7601
const CHAR_ENEMY: int = 7602
## 手牌卡实例 ID。
const CARD_ID: int = 9

var cs: Node = null
var _release_ids: Array = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	# 默认无回调注入——本文件验证的是执行端本身，不是注入接缝。
	cs.set("resolve_cb", Callable(func(_card, _targets) -> Array:
		return []))
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
	var ok: bool = DeploymentSystem.setup_field([CHAR_CASTER], {})
	assert_true(ok, "前置：施法者上场成功")
	if ok:
		_release_ids.append(CHAR_CASTER)
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_ENEMY, "current_hp": 20,
				"max_hp": 20, "attack": 4, "is_alive": true}],
		"character_ids": [CHAR_CASTER],
		"player_stats": {CHAR_CASTER: {"current_hp": caster_hp, "max_hp": 10,
				"atk": caster_atk}},
	})
	cs.call("advance_phase")  # PREPARATION → DRAW
	cs.call("advance_phase")  # DRAW → PLAY


## 效果条目——[code]target[/code] 空 = 未声明（按非 self 处理）。
func _entry(effect_type: StringName, value: int, target: StringName = &"") -> Resource:
	var entry: Resource = EntryClass.new()
	entry.effect_type = effect_type
	entry.value = value
	entry.target = target
	entry.trigger = EntryClass.TRIGGER_ON_PLAY
	return entry


## 注入手牌——卡实例带着 [code]effects[/code] 列表（出牌执行端的唯一数据来源）。
func _setup_card(entries: Array) -> void:
	var card: Dictionary = {
		"card_instance_id": CARD_ID, "cost": 0, "template_id": "test_on_play_card",
		"effects": entries,
	}
	cs.call("set_card_instances", {CARD_ID: card})
	cs.call("set_hand", [card.duplicate()])


func _hp(character_id: int) -> int:
	return int(cs.call("get_character_hp", character_id)["current"])


func _enemy_hp() -> int:
	return _hp(CHAR_ENEMY)


func _caster_hp() -> int:
	return _hp(CHAR_CASTER)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 倍率伤害：ATK × 倍率，向下取整
# ═══════════════════════════════════════════════════════════════════════════════

## ATK 3 × 150% = 4.5 → 4（floori），敌方 20 → 16。
func test_multiplier_damage_uses_caster_atk_and_floors() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([_entry(&"damage_multiplier", 150, &"single_enemy")])
	# Act
	assert_true(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER), "出牌成功")
	# Assert
	assert_eq(_enemy_hp(), 16, "ATK 3 × 1.5 = 4.5 → 向下取整 4（20 → 16）")


## 100% 倍率即「伤害 = 攻击力」——旧卡（ATK×1.0）口径逐位不变。
func test_full_multiplier_equals_atk() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([_entry(&"damage_multiplier", 100, &"single_enemy")])
	# Act
	cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER)
	# Assert
	assert_eq(_enemy_hp(), 17, "ATK 3 × 1.0 = 3（20 → 17）")


## 伤害走统一落库链路——广播的增量与实际扣血一致（表现层据此飘字）。
func test_multiplier_damage_emits_actual_damage() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([_entry(&"damage_multiplier", 150, &"single_enemy")])
	var payloads: Array = []
	cs.connect("character_damaged", func(data: Dictionary) -> void:
		payloads.append(data.duplicate(true)))
	# Act
	cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER)
	# Assert
	assert_eq(payloads.size(), 1, "一次伤害广播一次 character_damaged")
	assert_eq(int(payloads[0]["character_id"]), CHAR_ENEMY, "载荷属于敌方")
	assert_eq(int(payloads[0]["damage"]), 4, "增量 = 落库后的实际扣血 4")


## 拿不到施法者攻击力（无 player_stats.atk、无模板）→ 不落伤害，也不拿敌方 ATK 顶替。
func test_multiplier_without_caster_atk_deals_no_damage() -> void:
	# Arrange——战斗状态表里施法者 ATK 为 0（未声明）
	_start_battle(8, 0)
	_setup_card([_entry(&"damage_multiplier", 150, &"single_enemy")])
	# Act
	cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER)
	# Assert——敌方 ATK 是 4，若被当成本次攻击力会扣 6；信息不足时不臆造
	assert_eq(_enemy_hp(), 20, "施法者攻击力未知 → 不落伤害")
	assert_eq(_caster_hp(), 8, "施法者 HP 不受影响")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 治疗：落在施法者、不超上限
# ═══════════════════════════════════════════════════════════════════════════════

## 8/10 + 3 → 10（夹到上限），治疗以[b]实际回血量[/b]（2）的取负广播。
func test_self_heal_lands_on_caster_and_caps_at_max() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([_entry(&"heal", 3, &"self")])
	var payloads: Array = []
	cs.connect("character_damaged", func(data: Dictionary) -> void:
		payloads.append(data.duplicate(true)))
	# Act
	assert_true(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER), "出牌成功")
	# Assert
	assert_eq(_caster_hp(), 10, "治疗不超上限：8 + 3 → 10")
	assert_eq(payloads.size(), 1, "治疗广播一次")
	assert_eq(int(payloads[0]["character_id"]), CHAR_CASTER, "载荷属于施法者")
	# 广播的是夹取前后的 HP 差（10 - 8 = 2），不是申请量 3——
	# 否则表现层会飘出一个并不存在的回血量。
	assert_eq(int(payloads[0]["damage"]), -2, "部分溢出只广播实际回血 2")


## 满血时治疗不改变 HP，且[b]不广播[/b]（零增量无信息量，不飘不存在的回血数字）。
func test_heal_at_full_hp_changes_nothing() -> void:
	# Arrange——施法者满血 10/10
	_start_battle(10, 3)
	_setup_card([_entry(&"heal", 3, &"self")])
	var payloads: Array = []
	cs.connect("character_damaged", func(data: Dictionary) -> void:
		payloads.append(data.duplicate(true)))
	# Act
	cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER)
	# Assert
	assert_eq(_caster_hp(), 10, "满血仍为 10（夹取不越界）")
	assert_eq(payloads.size(), 0, "满血治疗零增量 → 不广播 character_damaged")


## 未知角色（不在战斗状态表）→ 未落库、不广播，且返回的 [code]damage[/code] 为 0。[br]
## [br][b]为什么锁这条[/b]：「按实际增量」的口径必须对未知角色同样成立——否则
## 调用方会把「一分血都没回」的申请量当成实际回血算进总数（返回值虚高），
## 而广播侧又因 [code]known=false[/code] 一条都不发，两边对不上。
func test_heal_on_unknown_character_reports_zero() -> void:
	# Arrange——开战但治疗对象不在战斗状态表里
	_start_battle(8, 3)
	var payloads: Array = []
	cs.connect("character_damaged", func(data: Dictionary) -> void:
		payloads.append(data.duplicate(true)))
	# Act
	var outcome: Dictionary = cs.call("_get_damage_settlement").call(
			"apply_heal", 7699, 3)
	# Assert
	assert_false(bool(outcome.get("known", true)), "未知角色未落库")
	assert_eq(int(outcome["damage"]), 0, "实际回血为 0——不虚报申请量 3")
	assert_eq(payloads.size(), 0, "未落库 → 零广播")


## 未声明 target 的治疗（旧扁平卡只写 [code]effect_type[/code]）→ 落施法者，不漏结算。
func test_heal_without_declared_target_lands_on_caster() -> void:
	# Arrange——target 留空
	_start_battle(8, 3)
	_setup_card([_entry(&"heal", 2)])
	# Act
	assert_true(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER), "出牌成功")
	# Assert
	assert_eq(_caster_hp(), 10, "未声明目标的治疗落施法者（8 + 2 → 10）")
	assert_eq(_enemy_hp(), 20, "绝不落到目标身上")


## 显式指向他人的治疗（[code]single_ally[/code]）→ 无模型，跳过并不写错对象。
func test_heal_targeting_ally_is_skipped() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([_entry(&"heal", 2, &"single_ally")])
	# Act
	cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER)
	# Assert
	assert_eq(_caster_hp(), 8, "他人目标的治疗当前无模型 → 不落库")
	assert_eq(_enemy_hp(), 20, "也不会落到敌方身上")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. target = self：只作用于施法者，不误伤目标
# ═══════════════════════════════════════════════════════════════════════════════

## 伤害条目声明 self → 无自伤模型，整条跳过：敌方不掉血，施法者也不掉血。
func test_self_targeted_damage_does_not_hit_enemy() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([_entry(&"damage_multiplier", 150, &"self")])
	# Act
	cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER)
	# Assert
	assert_eq(_enemy_hp(), 20, "self 目标不误伤敌方")
	assert_eq(_caster_hp(), 8, "也不臆造自我伤害")


## 同一条卡上的 self 治疗与非 self 伤害并存时，治疗只回施法者、伤害只打敌方。
func test_self_heal_and_enemy_damage_are_routed_separately() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([
		_entry(&"damage_multiplier", 100, &"single_enemy"),
		_entry(&"heal", 2, &"self"),
	])
	# Act
	cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER)
	# Assert
	assert_eq(_enemy_hp(), 17, "敌方只挨 3 点伤害（20 → 17）")
	assert_eq(_caster_hp(), 10, "施法者只回 2 点（8 → 10）")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 无倍率无治疗：行为逐位不变
# ═══════════════════════════════════════════════════════════════════════════════

## 无效果数据的卡（旧桩口径）→ 双方 HP 不变、无广播，出牌仍成功。
func test_card_without_effects_keeps_behaviour_unchanged() -> void:
	# Arrange——只给 template_id 的卡（CardSystem 查不到 → 落 UNEVALUABLE）
	_start_battle(8, 3)
	cs.call("set_card_instances", {CARD_ID: {
		"card_instance_id": CARD_ID, "cost": 0, "template_id": "test_card"}})
	cs.call("set_hand", [{"card_instance_id": CARD_ID, "cost": 0,
			"template_id": "test_card"}])
	var payloads: Array = []
	cs.connect("character_damaged", func(data: Dictionary) -> void:
		payloads.append(data))
	# Act
	var ok: bool = cs.call("play_card", CARD_ID, [], CHAR_CASTER)
	# Assert
	assert_true(ok, "出牌成功")
	assert_eq(_enemy_hp(), 20, "敌方 HP 不变")
	assert_eq(_caster_hp(), 8, "施法者 HP 不变")
	assert_eq(payloads.size(), 0, "无效果 → 无伤害/治疗广播")


## 无施法者（caster_id 缺省 -1）→ 执行端不结算（不猜「谁出的牌」），旧路径照常。
func test_missing_caster_sets_nothing() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([_entry(&"damage_multiplier", 150, &"single_enemy"),
		_entry(&"heal", 2, &"self")])
	# Act——不传 caster_id
	cs.call("play_card", CARD_ID, [CHAR_ENEMY])
	# Assert
	assert_eq(_enemy_hp(), 20, "拿不到施法者 → 倍率伤害不结算")
	assert_eq(_caster_hp(), 8, "拿不到施法者 → 治疗也不结算")


# ═══════════════════════════════════════════════════════════════════════════════
# 5. 生产路径：真实模板资产（只给 template_id 的卡实例）
# ═══════════════════════════════════════════════════════════════════════════════

## 真实资产「培元丹」（[code]heal 3 / target_type=self[/code]，扁平字段）→ 施法者回血。
## [br]锁定 [code]_effect_source[/code] 的模板现查通道：卡实例只带 template_id 时，
## 效果数据取自 CardSystem 模板，而非卡实例字典（后者没有效果字段）。
func test_real_heal_template_lands_on_caster() -> void:
	# Arrange——真实模板资产，卡实例只给 template_id
	_start_battle(8, 3)
	cs.call("set_card_instances", {CARD_ID: {"card_instance_id": CARD_ID,
			"cost": 0, "template_id": "pei_yuan_dan"}})
	cs.call("set_hand", [{"card_instance_id": CARD_ID, "cost": 0,
			"template_id": "pei_yuan_dan"}])
	# Act
	assert_true(cs.call("play_card", CARD_ID, [], CHAR_CASTER), "出牌成功")
	# Assert——GDD §②培元丹「回复3点生命」；8 + 3 → 10（夹到上限）
	assert_eq(_caster_hp(), 10, "真实模板的治疗落库到施法者（8 + 3 → 10）")


## 真实资产「寒玉轮回功」（[code]effect_type=heal[/code] 但[b]未写 target[/b]）→ 落施法者。
## [br]锁定「未声明目标 = 施法者」的裁定在真实资产上成立——漏认会让这类卡静默失效。
func test_real_heal_template_without_target_lands_on_caster() -> void:
	# Arrange
	_start_battle(8, 3)
	cs.call("set_card_instances", {CARD_ID: {"card_instance_id": CARD_ID,
			"cost": 0, "template_id": "han_yu_lun_hui_gong"}})
	cs.call("set_hand", [{"card_instance_id": CARD_ID, "cost": 0,
			"template_id": "han_yu_lun_hui_gong"}])
	# Act
	assert_true(cs.call("play_card", CARD_ID, [], CHAR_CASTER), "出牌成功")
	# Assert——扁平 effect_value=1（§本命加成不在此层展开）
	assert_eq(_caster_hp(), 9, "未声明目标的真实资产治疗仍落施法者（8 + 1 → 9）")


## 真实资产「血杀掌」（[code]damage_multiplier 100[/code] + [code]trigger=kill 的 heal 2[/code]）
## → 未击杀时只结算倍率伤害，击杀回血不外流（触发时机分离在真实资产上同样成立）。
func test_real_kill_card_does_not_heal_before_kill() -> void:
	# Arrange
	_start_battle(8, 3)
	cs.call("set_card_instances", {CARD_ID: {"card_instance_id": CARD_ID,
			"cost": 0, "template_id": "xue_sha_zhang"}})
	cs.call("set_hand", [{"card_instance_id": CARD_ID, "cost": 0,
			"template_id": "xue_sha_zhang"}])
	# Act
	assert_true(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER), "出牌成功")
	# Assert
	assert_eq(_enemy_hp(), 17, "ATK 3 × 1.0 = 3（20 → 17，未击杀）")
	assert_eq(_caster_hp(), 8, "未击杀 → 击杀回血不落库（打出结算不含 kill 条目）")


# ═══════════════════════════════════════════════════════════════════════════════
# 6. Debuff：出牌给敌人上 debuff（降攻/降防）
# ═══════════════════════════════════════════════════════════════════════════════

## 打出 debuff 效果的卡——敌方被施加降攻 debuff，后续攻击力降低。
func test_debuff_effect_applies_to_enemy() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([_entry(&"debuff_atk", 1, &"single_enemy")])
	var roster: Variant = cs.call("_get_roster_state")
	# Act
	assert_true(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER), "出牌成功")
	# Assert——敌方基础 ATK 4，降攻 1 后应为 3
	var debuff_mgr: RefCounted = roster.call(&"get_debuff_manager")
	assert_eq(debuff_mgr.call(&"get_stacks", CHAR_ENEMY, DebuffManagerScript.TYPE_ATK), 1, "应施加 1 层降攻 debuff")
	assert_eq(int(roster.call(&"get_atk", CHAR_ENEMY)), 3, "敌方 ATK 应从 4 降至 3")


## 降防 debuff 使敌方防御力降低。
func test_debuff_def_reduces_enemy_defense() -> void:
	# Arrange——给敌方更高的基础防御
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_ENEMY, "current_hp": 20,
				"max_hp": 20, "attack": 4, "defense": 3, "is_alive": true}],
		"character_ids": [CHAR_CASTER],
		"player_stats": {CHAR_CASTER: {"current_hp": 8, "max_hp": 10, "atk": 3}},
	})
	cs.call("advance_phase")
	cs.call("advance_phase")
	_setup_card([_entry(&"debuff_def", 1, &"single_enemy")])
	var roster: Variant = cs.call("_get_roster_state")
	# Act
	assert_true(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER), "出牌成功")
	# Assert——敌方基础 DEF 3，降防 1 后应为 2
	var debuff_mgr: RefCounted = roster.call(&"get_debuff_manager")
	assert_eq(debuff_mgr.call(&"get_stacks", CHAR_ENEMY, DebuffManagerScript.TYPE_DEF), 1, "应施加 1 层降防 debuff")
	assert_eq(int(roster.call(&"get_defense", CHAR_ENEMY)), 2, "敌方 DEF 应从 3 降至 2")


## debuff 持续回合数按 duration_turns 设置。
func test_debuff_duration_respects_duration_turns() -> void:
	# Arrange
	_start_battle(8, 3)
	var entry: Resource = EntryClass.new()
	entry.effect_type = &"debuff_atk"
	entry.value = 1
	entry.duration_turns = 3
	entry.target = &"single_enemy"
	entry.trigger = EntryClass.TRIGGER_ON_PLAY
	_setup_card([entry])
	var roster: Variant = cs.call("_get_roster_state")
	# Act
	assert_true(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER), "出牌成功")
	# Assert
	var debuff_mgr: RefCounted = roster.call(&"get_debuff_manager")
	assert_eq(debuff_mgr.call(&"get_duration", CHAR_ENEMY, DebuffManagerScript.TYPE_ATK), 3, "持续回合数应为 3")


## debuff 效果声明 self → 无自施 debuff 模型，跳过。
func test_self_targeted_debuff_is_skipped() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([_entry(&"debuff_atk", 1, &"self")])
	var roster: Variant = cs.call("_get_roster_state")
	# Act
	cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER)
	# Assert——不应施加任何 debuff
	var debuff_mgr: RefCounted = roster.call(&"get_debuff_manager")
	assert_eq(debuff_mgr.call(&"get_stacks", CHAR_ENEMY, DebuffManagerScript.TYPE_ATK), 0, "self 目标应跳过")


## 无 debuff 效果的卡——无副作用，敌方 ATK 不变。
func test_card_without_debuff_has_no_side_effect() -> void:
	# Arrange
	_start_battle(8, 3)
	_setup_card([_entry(&"damage_multiplier", 100, &"single_enemy")])
	var roster: Variant = cs.call("_get_roster_state")
	# Act
	assert_true(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER), "出牌成功")
	# Assert——敌方 HP 变化但无 debuff
	assert_eq(_enemy_hp(), 17, "敌方受到伤害")
	var debuff_mgr: RefCounted = roster.call(&"get_debuff_manager")
	assert_eq(debuff_mgr.call(&"get_stacks", CHAR_ENEMY, DebuffManagerScript.TYPE_ATK), 0, "无 debuff")


## 真实资产「煞气斩」——带降攻 debuff 效果。
func test_real_sha_qi_zhan_applies_debuff() -> void:
	# Arrange——使用真实资产 sha_qi_zhan（damage_multiplier + debuff_atk）
	_start_battle(8, 3)
	cs.call("set_card_instances", {CARD_ID: {"card_instance_id": CARD_ID,
			"cost": 0, "template_id": "sha_qi_zhan"}})
	cs.call("set_hand", [{"card_instance_id": CARD_ID, "cost": 0,
			"template_id": "sha_qi_zhan"}])
	var roster: Variant = cs.call("_get_roster_state")
	# Act
	assert_true(cs.call("play_card", CARD_ID, [CHAR_ENEMY], CHAR_CASTER), "出牌成功")
	# Assert——敌方受到伤害（ATK 3 × 1.5 = 4.5 → 4）+ 降攻 debuff
	assert_eq(_enemy_hp(), 16, "倍率伤害生效（20 → 16）")
	var debuff_mgr: RefCounted = roster.call(&"get_debuff_manager")
	assert_eq(debuff_mgr.call(&"get_stacks", CHAR_ENEMY, DebuffManagerScript.TYPE_ATK), 1, "降攻 debuff 施加成功")
	assert_eq(int(roster.call(&"get_atk", CHAR_ENEMY)), 3, "敌方 ATK 从 4 降至 3")
