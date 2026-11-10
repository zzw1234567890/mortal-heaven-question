extends GutTest
## 角色切换后施法者正确（combat-ui-interaction 001 / 本轮）。[br]
## [br][b]背景[/b]：施法者此前按阵位顺序临时裁定——多角色阵容里玩家点谁都没用，
## 出牌一律记在阵位首位。本文件锁定「当前操作角色」成为显式状态后的四条语义： [br]
##   1. 默认取阵位首个可行动角色；[br]
##   2. 切换角色后出牌的施法者随之改变（倍率伤害按新角色 ATK 结算）；[br]
##   3. 当前角色阵亡 → 自动顺位到下一名，出牌不再记在阵亡者身上；[br]
##   4. 点我方角色卡（真实鼠标路径）= 切换施法者。[br]
## [br]测试策略（同 test_play_flow_cost_and_target.gd）：真实 CombatSystem 实例 +
## 真实 DeploymentSystem 阵位 + 真实 CostSystem + 真实 CombatRoot 门面。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const CombatRootScene: PackedScene = preload("res://src/ui/combat/layout/CombatRoot.tscn")
const EntryClass: GDScript = preload("res://src/core/card_system/effect_entry.gd")
const CasterRules: GDScript = preload("res://src/ui/combat/shared/combat_caster_rules.gd")

## 本文件独立的角色 ID 段——不与其它测试文件夹具冲突。
const CHAR_A: int = 8201
const CHAR_B: int = 8202
const CHAR_ENEMY: int = 8203
const CARD_ID: int = 82
const COST_CAP: int = 5

var cs: Node = null
var layout: Control = null
var _release_ids: Array = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	cs.set("resolve_cb", Callable(func(_card, _targets) -> Array: return []))
	layout = CombatRootScene.instantiate()
	add_child_autofree(layout)
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

## 双角色阵容上场 + 开战 + 建卡（A 攻击力 3 / B 攻击力 5）。[br]
## [br][b]为什么攻击力不同[/b]：倍率伤害 = 施法者 ATK × 倍率，只有 ATK 不同才分得出
## 「这一刀是谁打的」。
func _start(p_entries: Array = []) -> void:
	var ok: bool = DeploymentSystem.setup_field([CHAR_A, CHAR_B], {})
	assert_true(ok, "前置：两名角色上场成功")
	if ok:
		_release_ids.append_array([CHAR_A, CHAR_B])
	cs.call("battle_start", {
		"enemy_roster": [{"character_id": CHAR_ENEMY, "current_hp": 40,
			"max_hp": 40, "attack": 4, "is_alive": true}],
		"character_ids": [CHAR_A, CHAR_B],
		"player_stats": {
			CHAR_A: {"current_hp": 8, "max_hp": 10, "atk": 3},
			CHAR_B: {"current_hp": 8, "max_hp": 10, "atk": 5},
		},
	})
	CostSystem.init_for_battle(COST_CAP)
	cs.call("advance_phase")  # PREPARATION → DRAW
	cs.call("advance_phase")  # DRAW → PLAY
	cs.call("set_card_instances", {CARD_ID: {
		"card_instance_id": CARD_ID, "cost": 0, "template_id": "test_actor_switch",
		"target_type": &"single_enemy",
		"effects": p_entries if not p_entries.is_empty()
				else [_entry(&"damage_multiplier", 100, &"single_enemy")],
	}})
	cs.call("set_hand", [{"card_instance_id": CARD_ID, "cost": 0,
		"target_type": &"single_enemy", "name": "测试卡"}])
	layout.call(&"setup_feedback", cs, DeploymentSystem, Callable(), null, null, true)
	layout.call(&"build_battle_roster", [CHAR_A, CHAR_B])
	layout.call(&"setup_interaction", true)
	layout.call(&"interaction").call(&"set_input_enabled", true)


func _entry(effect_type: StringName, value: int, target: StringName) -> Resource:
	var entry: Resource = EntryClass.new()
	entry.effect_type = effect_type
	entry.value = value
	entry.target = target
	entry.trigger = EntryClass.TRIGGER_ON_PLAY
	return entry


func _hp(character_id: int) -> int:
	return int(cs.call("get_character_hp", character_id)["current"])


func _input_node() -> Node:
	return layout.call(&"interaction").call(&"get_input_layer")


func _actor_pos(character_id: int) -> Vector2:
	var card: Control = layout.get(&"actor_stage").call(&"get_card", character_id)
	return card.get_global_rect().get_center()


func _click(p_global_pos: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.global_position = p_global_pos
	_input_node().call(&"_handle_button", press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.global_position = p_global_pos
	_input_node().call(&"_handle_button", release)


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 默认施法者 = 阵位首个可行动角色
# ═══════════════════════════════════════════════════════════════════════════════

## 开战后当前操作角色为阵位首位（A），出牌施法者与之一致。
func test_default_actor_is_first_slot() -> void:
	_start()
	assert_eq(int(layout.call(&"interaction").call(&"current_actor_id")), CHAR_A, "默认取阵位首位")
	assert_eq(int(layout.call(&"current_caster_id")), CHAR_A, "施法者与操作角色一致")
	assert_eq(layout.call(&"interaction").call(&"actor_candidates"), [CHAR_A, CHAR_B], "两名候选")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 切换后施法者改变（倍率伤害按新角色 ATK）
# ═══════════════════════════════════════════════════════════════════════════════

## 切到 B（ATK 5）后出牌 → 敌人掉 5 血（不是 A 的 3）。[br]
## [br][b]这是本轮的核心断言[/b]：旧口径下无论点谁，伤害都按阵位首位算。
func test_switch_actor_changes_caster_damage() -> void:
	# Arrange
	_start()
	assert_true(bool(layout.call(&"interaction").call(&"select_actor", CHAR_B)), "切到 B")
	assert_eq(int(layout.call(&"current_caster_id")), CHAR_B, "施法者换成 B")
	# Act
	var out: Dictionary = layout.call(&"play_card_detailed", CARD_ID, [CHAR_ENEMY])
	# Assert
	assert_true(bool(out["ok"]), "出牌成功")
	assert_eq(_hp(CHAR_ENEMY), 35, "伤害按 B 的 ATK 5 结算（40 → 35）")
	assert_eq(int(out.get("caster_id", -1)), CHAR_B, "结果里的施法者是 B")


## 不切换时按 A（ATK 3）结算——对照组，证明上一条的差异来自切换。
func test_without_switch_caster_stays_first() -> void:
	_start()
	var out: Dictionary = layout.call(&"play_card_detailed", CARD_ID, [CHAR_ENEMY])
	assert_true(bool(out["ok"]), "出牌成功")
	assert_eq(_hp(CHAR_ENEMY), 37, "伤害按 A 的 ATK 3 结算（40 → 37）")


## 切换后治疗也落新角色（self 治疗跟随施法者）。
func test_switch_actor_changes_heal_target() -> void:
	# Arrange——B 先掉 2 血（8/10 → 6/10），治疗 2 才能看出落点
	_start([_entry(&"heal", 2, &"self")])
	cs.call("_get_damage_settlement").call(&"_apply", CHAR_B, 2, 0, false, [])
	assert_eq(_hp(CHAR_B), 6, "前置：B 已受伤")
	assert_true(bool(layout.call(&"interaction").call(&"select_actor", CHAR_B)), "切到 B")
	# Act
	layout.call(&"play_card_detailed", CARD_ID, [])
	# Assert
	assert_eq(_hp(CHAR_B), 8, "治疗落 B（6 + 2）")
	assert_eq(_hp(CHAR_A), 8, "A 未被治疗")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 阵亡自动顺位
# ═══════════════════════════════════════════════════════════════════════════════

## 当前角色（A）阵亡 → 当前操作角色自动顺位到 B，出牌不再记在阵亡者身上。
func test_dead_actor_falls_through_to_next() -> void:
	# Arrange
	_start()
	assert_eq(int(layout.call(&"interaction").call(&"current_actor_id")), CHAR_A, "前置：A 在行动")
	# Act——A 阵亡（战斗侧发 character_died，装配台订阅）
	cs.emit_signal("character_died", CHAR_A, 0, [])
	# Assert
	assert_eq(int(layout.call(&"interaction").call(&"current_actor_id")), CHAR_B, "自动顺位到 B")
	assert_eq(int(layout.call(&"current_caster_id")), CHAR_B, "施法者同步顺位")
	var out: Dictionary = layout.call(&"play_card_detailed", CARD_ID, [CHAR_ENEMY])
	assert_eq(int(out.get("caster_id", -1)), CHAR_B, "出牌记在 B 身上")
	assert_eq(_hp(CHAR_ENEMY), 35, "伤害按 B 的 ATK 结算")


## 全阵亡 → 当前角色为 -1（不猜施法者）。
func test_no_actor_when_all_dead() -> void:
	_start()
	cs.emit_signal("character_died", CHAR_A, 0, [])
	cs.emit_signal("character_died", CHAR_B, 0, [])
	assert_eq(int(layout.call(&"interaction").call(&"current_actor_id")), CasterRules.NO_CASTER, "无当前角色")
	assert_eq(int(layout.call(&"current_caster_id")), CasterRules.NO_CASTER, "不猜施法者")


# ═══════════════════════════════════════════════════════════════════════════════
# 4. 真实鼠标路径：点我方角色卡 = 切换施法者
# ═══════════════════════════════════════════════════════════════════════════════

## 点 B 的角色卡 → 当前操作角色换成 B（无需额外 UI）。
func test_click_ally_card_switches_actor() -> void:
	# Arrange——开战建卡 + 交互层就绪（点卡路径的前提）
	_start()
	assert_not_null(layout.get(&"actor_stage").call(&"get_card", CHAR_B),
			"前置：B 的角色卡已建")
	# Act
	_click(_actor_pos(CHAR_B))
	# Assert
	assert_eq(int(layout.call(&"interaction").call(&"current_actor_id")), CHAR_B, "点卡即切换")
	assert_eq(int(layout.call(&"current_caster_id")), CHAR_B, "施法者同步")


## 点阵亡角色的卡（已无卡节点）→ 当前角色不变（不把「点空」变成「没人行动」）。
func test_click_without_card_keeps_actor() -> void:
	_start()
	_click(Vector2(5.0, 5.0))
	assert_eq(int(layout.call(&"interaction").call(&"current_actor_id")), CHAR_A, "当前角色不变")
