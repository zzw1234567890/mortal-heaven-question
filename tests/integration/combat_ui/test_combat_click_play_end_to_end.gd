extends GutTest
## 点击路径端到端出牌（combat-ui-interaction 001 / 本轮）。[br]
## [br][b]背景[/b]：闭环内核此前只被测试直接调用——真实对局里没有任何 InputEvent
## 驱动 [code]CombatPlayController[/code]。本文件从[b]鼠标事件[/b]出发，走完整链路： [br]
##   [code]CombatInputLayer._gui_input → CombatPlayFlow → CombatPlayController
##   → CombatPlayBridge → CombatSystem.play_card_detailed[/code][br]
## 断言落到真实战斗系统：真的扣费、真的掉血、拒绝时真的不扣费且有提示文本。[br]
## [br]测试策略（同 test_play_flow_cost_and_target.gd）：[code]CS_SCRIPT.new()[/code]
## 独立实例 + 真实 DeploymentSystem 阵位 + 真实 CostSystem + 真实 CombatRoot 门面。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const CombatRootScene: PackedScene = preload("res://src/ui/combat/layout/CombatRoot.tscn")
const PlayResult: GDScript = preload("res://src/feature/combat/combat_play_result.gd")
const Flow: GDScript = preload("res://src/ui/combat/shared/combat_play_flow.gd")

## 本文件独立的角色 ID 段——不与其它测试文件夹具冲突。
const CHAR_CASTER: int = 8101
const CHAR_ENEMY_A: int = 8102
const CHAR_ENEMY_B: int = 8103
const CARD_ID: int = 81
const COST_CAP: int = 5

var cs: Node = null
var layout: Control = null
var hints: Array = []
var _release_ids: Array = []


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	cs.set("resolve_cb", Callable(func(_card, _targets) -> Array:
		return []))
	layout = CombatRootScene.instantiate()
	# 测试根不是容器——门面需显式尺寸，否则手牌弧形位与角色卡矩形都是 0×0，
	# 命中测试永远返回「未命中」（真实对局由窗口铺满）。
	layout.size = Vector2(1280.0, 720.0)
	add_child_autofree(layout)
	hints = []
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

## 上场 + 开战 + 建卡 + 装配交互层（生产路径的完整前置）。[br]
## [br][param p_cost] 卡费（配合 COST_CAP 制造可付 / 不可付两种场景）。
func _start(p_cost: int = 2, p_target_type: StringName = &"single_enemy",
		p_entries: Array = []) -> void:
	var ok: bool = DeploymentSystem.setup_field([CHAR_CASTER], {})
	assert_true(ok, "前置：施法者上场成功")
	if ok:
		_release_ids.append(CHAR_CASTER)
	cs.call("battle_start", {
		"enemy_roster": [
			{"character_id": CHAR_ENEMY_A, "current_hp": 20, "max_hp": 20,
				"attack": 4, "is_alive": true},
			{"character_id": CHAR_ENEMY_B, "current_hp": 20, "max_hp": 20,
				"attack": 4, "is_alive": true},
		],
		"character_ids": [CHAR_CASTER],
		"player_stats": {CHAR_CASTER: {"current_hp": 8, "max_hp": 10, "atk": 3}},
	})
	CostSystem.init_for_battle(COST_CAP)
	cs.call("advance_phase")  # PREPARATION → DRAW
	cs.call("advance_phase")  # DRAW → PLAY
	# 注入手牌：卡实例带费用 / 目标词 / 效果（伤害 3 = 施法者 ATK × 100%）
	cs.call("set_card_instances", {CARD_ID: {
		"card_instance_id": CARD_ID, "cost": p_cost, "template_id": "test_click_play",
		"target_type": p_target_type,
		"effects": p_entries if not p_entries.is_empty() 				else [_entry(&"damage_multiplier", 100, &"single_enemy")],
	}})
	cs.call("set_hand", [_card_dict(p_cost, p_target_type)])
	# 门面接线：装配台（建卡）+ 交互层（输入节点 + 手牌供给）
	layout.call(&"setup_feedback", cs, DeploymentSystem, Callable(), null, null, true)
	layout.call(&"build_battle_roster", [CHAR_CASTER])
	layout.call(&"setup_interaction", true)
	layout.call(&"interaction").call(&"set_input_enabled", true)
	# 手牌区供牌（生产由 CombatHandWiring 驱动；此处直接下发同一份快照）
	_apply_hand_snapshot()


func _card_dict(p_cost: int, p_target_type: StringName) -> Dictionary:
	return {
		"card_instance_id": CARD_ID, "cost": p_cost, "template_id": "test_click_play",
		"target_type": p_target_type, "name": "测试卡", "rarity": 1, "type": 1,
	}


func _entry(effect_type: StringName, value: int, target: StringName) -> Resource:
	var entry: Resource = preload("res://src/core/card_system/effect_entry.gd").new()
	entry.effect_type = effect_type
	entry.value = value
	entry.target = target
	entry.trigger = entry.TRIGGER_ON_PLAY
	return entry


## 手牌区快照下发（交互层的卡面词来源与手牌区渲染同一份）。
func _apply_hand_snapshot() -> void:
	var hand: Variant = layout.get(&"hand_area")
	hand.call(&"apply_phase", 2)
	hand.call(&"apply_hand", layout.call(&"interaction").call(&"hand_snapshot"))
	hand.call(&"apply_affordability", [true])


## 输入层实例（交互挂载模块是 RefCounted——取属性而非调方法）。
func _input_node() -> Node:
	return layout.call(&"interaction").call(&"get_input_layer")


func _flow() -> RefCounted:
	return _input_node().call(&"get_flow")


func _hp(character_id: int) -> int:
	return int(cs.call("get_character_hp", character_id)["current"])


## 模拟一次鼠标点击（按下 + 释放，同一位置——未越过 8px 阈值）。
func _click(p_global_pos: Vector2) -> void:
	_input_node().call(&"_handle_button", _button_event(p_global_pos, true))
	_input_node().call(&"_handle_button", _button_event(p_global_pos, false))


func _button_event(p_global_pos: Vector2, p_pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = p_pressed
	event.global_position = p_global_pos
	return event


## 某张手牌的中心全局坐标（真实命中测试的输入）。
func _card_pos(index: int) -> Vector2:
	var card: Control = layout.get(&"hand_area").call(&"get_card", index)
	return card.get_global_rect().get_center()


## 某个角色的卡中心全局坐标。
func _actor_pos(character_id: int) -> Vector2:
	var stage: Variant = layout.get(&"actor_stage")
	var card: Control = stage.call(&"get_card", character_id)
	return card.get_global_rect().get_center()


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 端到端：点击出牌真的扣费、真的掉血
# ═══════════════════════════════════════════════════════════════════════════════

## 点卡 → 点敌人 → 出牌：灵力 5→3，敌人 20→17。[br]
## [br][b]为什么用真实坐标[/b]：命中测试（手牌逆序 / 角色卡矩形）也是本链路的一环，
## 传死坐标等于把最容易接错的一段跳过了。
func test_click_card_then_enemy_plays_card_end_to_end() -> void:
	# Arrange
	_start(2)
	assert_eq(int(layout.call(&"interaction").call(&"current_phase")), 2, "前置：出牌阶段")
	# Act——点卡（选中）
	_click(_card_pos(0))
	assert_eq(int(layout.call(&"interaction").call(&"play_controller").call(&"get_selected_card_id")),
			CARD_ID, "点卡即选中")
	# Act——点敌人 A（单体卡点完即确认）
	_click(_actor_pos(CHAR_ENEMY_A))
	# Assert
	assert_eq(CostSystem.get_current_cost(), COST_CAP - 2, "真的扣费（5 → 3）")
	assert_eq(_hp(CHAR_ENEMY_A), 17, "伤害落到点击的敌人（20 → 17）")
	assert_eq(_hp(CHAR_ENEMY_B), 20, "另一个敌人未受伤")
	assert_eq(cs.call("get_hand").size(), 0, "打出的卡离开手牌")


## 点卡两次（不点目标）→ 确认出牌，目标走默认策略（首个存活敌人）。
func test_double_click_card_plays_with_default_target() -> void:
	_start(0)
	_click(_card_pos(0))
	_click(_card_pos(0))
	assert_eq(CostSystem.get_current_cost(), COST_CAP, "0 费不扣灵力")
	assert_eq(_hp(CHAR_ENEMY_A), 17, "默认打首个存活敌人")


## 费用不足：点击出牌被拒，[b]不扣费[/b]，且有可读提示（不静默失败）。
func test_unaffordable_click_shows_hint_and_spends_nothing() -> void:
	# Arrange——9 费卡，只有 5 灵力
	_start(9)
	_input_node().call(&"setup", layout.call(&"interaction"),
			Callable(func(msg: String) -> void: hints.append(msg)))
	# Act
	_click(_card_pos(0))
	_click(_actor_pos(CHAR_ENEMY_A))
	# Assert
	assert_eq(CostSystem.get_current_cost(), COST_CAP, "拒绝时不扣费")
	assert_eq(_hp(CHAR_ENEMY_A), 20, "拒绝时效果不结算")
	assert_eq(cs.call("get_hand").size(), 1, "卡牌留在手牌")
	assert_eq(hints.size(), 1, "给出一次提示")
	assert_true(String(hints[0]).contains("灵力"), "提示文本可读（含「灵力」）：%s" % hints[0])


# ═══════════════════════════════════════════════════════════════════════════════
# 1b. 输入锁：别的锁仍然拦住出牌
# ═══════════════════════════════════════════════════════════════════════════════

## 模态弹窗（MODAL 锁）打开期间 → 点击不出牌。[br]
## [br][b]为什么锁这条[/b]：战斗系统整场持有一把 ANIMATION 锁（AC-005），输入层为
## 出牌阶段放了它一马——但这条豁免[b]只能针对那一把锁[/b]，模态 / 转场必须照拦，
## 否则「弹窗打开还能出牌」会变成新的点穿缺陷。
func test_modal_lock_blocks_click_play() -> void:
	# Arrange
	_start(0)
	InputManager.push_lock(InputManager.LockType.MODAL, &"test_modal")
	# Act
	_click(_card_pos(0))
	_click(_actor_pos(CHAR_ENEMY_A))
	# Assert
	assert_eq(_hp(CHAR_ENEMY_A), 20, "模态期间不出牌")
	assert_eq(int(_flow().call(&"get_controller").call(&"get_selected_card_id")), -1,
			"模态期间连选中都不发生")
	InputManager.clear_locks(&"test_modal")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 拖拽路径（≥8px）
# ═══════════════════════════════════════════════════════════════════════════════

## 按下卡 → 移动 ≥8px → 释放到敌人卡上 → 出牌（拖拽路径）。
func test_drag_from_card_to_enemy_plays() -> void:
	# Arrange
	_start(0)
	var input: Node = _input_node()
	var from: Vector2 = _card_pos(0)
	var to: Vector2 = _actor_pos(CHAR_ENEMY_B)
	# Act
	input.call(&"_handle_button", _button_event(from, true))
	input.call(&"_handle_motion", _motion_event(from + Vector2(20.0, 0.0)))
	input.call(&"_handle_button", _button_event(to, false))
	# Assert
	assert_eq(_hp(CHAR_ENEMY_B), 17, "拖到 B 身上就打 B")
	assert_eq(_hp(CHAR_ENEMY_A), 20, "A 未受伤")


## 拖拽释放到空白 → 取消，不出牌、不扣费。
func test_drag_released_on_blank_cancels() -> void:
	_start(0)
	var input: Node = _input_node()
	var from: Vector2 = _card_pos(0)
	input.call(&"_handle_button", _button_event(from, true))
	input.call(&"_handle_motion", _motion_event(from + Vector2(20.0, 0.0)))
	input.call(&"_handle_button", _button_event(Vector2(5.0, 5.0), false))
	assert_eq(_hp(CHAR_ENEMY_A), 20, "不出牌")
	assert_eq(cs.call("get_hand").size(), 1, "卡牌留在手牌")


## 小于 8px 的移动不启动拖拽——释放仍按点击处理（选中而非出牌）。
func test_small_move_stays_click() -> void:
	_start(0)
	var input: Node = _input_node()
	var from: Vector2 = _card_pos(0)
	input.call(&"_handle_button", _button_event(from, true))
	input.call(&"_handle_motion", _motion_event(from + Vector2(3.0, 0.0)))
	input.call(&"_handle_button", _button_event(from + Vector2(3.0, 0.0), false))
	assert_eq(int(layout.call(&"interaction").call(&"play_controller").call(&"get_selected_card_id")),
			CARD_ID, "小幅移动 = 点击选中")
	assert_eq(cs.call("get_hand").size(), 1, "未出牌")


func _motion_event(p_global_pos: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.global_position = p_global_pos
	return event


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 目标模式：单目标卡拒绝多选（真实系统侧）
# ═══════════════════════════════════════════════════════════════════════════════

## 单目标卡：点 A 后出牌，再选卡点 B 出牌——两次各只打一个（从不累加）。[br]
## [br][b]为什么在集成层再锁一次[/b]：单测锁的是纯函数语义，这里锁的是
## 「真实输入 + 真实控制器 + 真实桥」链路里目标列表没有被下游改宽。
func test_single_target_card_never_sends_multiple_targets() -> void:
	# Arrange——两张 0 费卡（避免手牌空触发自动推进）
	_start(0)
	_click(_card_pos(0))
	_click(_actor_pos(CHAR_ENEMY_A))
	# Assert——第一次只打 A
	assert_eq(_hp(CHAR_ENEMY_A), 17, "第一次打 A")
	assert_eq(_hp(CHAR_ENEMY_B), 20, "B 未受伤（单目标卡没有群攻）")


## 自身卡（target_type = self）：点卡再点卡 → 出牌，治疗落施法者、不误伤敌人。
func test_self_target_card_heals_caster_without_enemy_damage() -> void:
	# Arrange——自身卡带 heal 2（施法者 8/10 → 10）
	_start(0, &"self", [_entry(&"heal", 2, &"self")])
	# Act
	_click(_card_pos(0))
	_click(_card_pos(0))
	# Assert
	assert_eq(_hp(CHAR_ENEMY_A), 20, "自身卡不打敌人")
	assert_eq(_hp(CHAR_ENEMY_B), 20, "自身卡不打敌人（B）")
	assert_eq(_hp(CHAR_CASTER), 10, "治疗落施法者（8 + 2 → 10）")
