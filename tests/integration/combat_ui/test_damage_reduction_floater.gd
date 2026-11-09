extends GutTest
## 减伤飘字集成测试：减伤后的实际扣血「玩家看得见」（DEBT-CBT-018-8 表现层闭环）。
##
## [b]背景[/b]：减伤已在数据层生效（`damage_reduction_pcts` → `final_damage` →
## 落库），但表现层此前从未区分「原始伤害」与「实际扣血」。本文件锁定：[br]
##   1. 飘字显示的是落库后的实际扣血（减伤 15%：原始 10 → 实际 8），
##      不是减伤前的原始伤害；[br]
##   2. 被减伤时飘字带「减」角标 + 琥珀色（可辨识提示，不引入美术资源）；[br]
##   3. 无减伤时行为完全不变（红色「-10」、无角标）。[br]
##
## 链路：真实 `CombatSystem` + 真实 `BindingManager`（绑定 15% 减伤卡）
## → Attack 阶段 → `character_damaged` 载荷 → `CombatFeedbackCoordinator`
## → `FloaterPool` 飘字。测试策略同 `test_damage_reduction_wiring.gd`：
## `CS_SCRIPT.new()` 独立实例 + `set_auto_advance(false)` + `set_scene_change(false)`。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const CardTemplateClass := preload("res://src/core/card_system/card_template.gd")
const BRClass := preload("res://src/feature/binding/binding_record.gd")
const CardScript: GDScript = preload("res://src/ui/combat/layout/character_status_card.gd")
const CoordinatorScript: GDScript = preload("res://src/ui/combat/feedback/combat_feedback_coordinator.gd")
const PoolScript: GDScript = preload("res://src/ui/combat/feedback/floater_pool.gd")
const GONGFA: int = BRClass.BindingSlot.GONGFA

## 独立角色 ID 段——不与其它测试文件夹具冲突。
const CHAR_REDUCED: int = 7401
const CHAR_PLAIN: int = 7402
## 注入的减伤模板 ID。
const RED_TEMPLATE: StringName = &"test_red_15_ui"

var cs: Node = null
var coordinator: Control = null
var card: Control = null
var _binding_ids: Array = []
var _template_backup: Variant = null
var _next_card_id: int = 1


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	_binding_ids.clear()
	# 筑基期：每角色 2 个功法位
	BindingManager.cache_slot_limits(GameStateManager.RealmLevel.FOUNDATION)
	_inject_template()


func after_each() -> void:
	if coordinator != null and is_instance_valid(coordinator):
		coordinator.queue_free()
		coordinator = null
	card = null
	for binding_id: int in _binding_ids:
		BindingManager.remove_binding(binding_id)
	_binding_ids.clear()
	if _template_backup == null:
		CardSystem.templates.erase(RED_TEMPLATE)
	else:
		CardSystem.templates[RED_TEMPLATE] = _template_backup
	_template_backup = null
	if cs != null:
		cs.free()
		cs = null
	CostSystem.clear_for_battle_end()
	InputManager.clear_locks(&"combat_system")
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false


# ═══════════════════════════════════════════════════════════════════════════════
# 夹具
# ═══════════════════════════════════════════════════════════════════════════════

## 注入 15% 减伤模板（本命值 20%——本测试角色非本命，按 15% 结算）。
func _inject_template() -> void:
	_template_backup = CardSystem.templates.get(RED_TEMPLATE)
	var tpl := CardTemplateClass.new()
	tpl.card_id = RED_TEMPLATE
	tpl.type = CardTemplateClass.CardType.TECHNIQUE
	tpl.effect_type = &"damage_reduce"
	tpl.effect_value = 15
	tpl.native_effect_value = 20
	tpl.native_owner = &"xi_yin"
	CardSystem.templates[RED_TEMPLATE] = tpl


## 绑定一张 15% 减伤卡到角色（非本命——character_card_id 不匹配 native_owner）。
func _bind_reduction(character_id: int) -> void:
	var card_instance_id: int = 950000 + _next_card_id
	_next_card_id += 1
	var result: Dictionary = BindingManager.bind_card(
		card_instance_id, RED_TEMPLATE, character_id, GONGFA, &"", &"")
	# 先登记清理再断言——断言失败也不会把绑定泄漏给后续用例（跨用例污染）
	if bool(result.get("success", false)):
		_binding_ids.append(int(result["binding_id"]))
	assert_true(bool(result.get("success", false)),
		"前置：15%% 减伤卡应绑定成功（reason=%s）" % result.get("reason", ""))


## 开战 + 建卡 + 注册进协调器（链路完整装配）。
## 敌方 20 HP / 攻击力 10 / 防御 0 → 无减伤基准伤害 10。
func _setup_battle(target_id: int) -> void:
	cs.call("battle_start", {"enemy_roster": [{
		"character_id": target_id, "current_hp": 20, "max_hp": 20, "is_alive": true,
	}], "character_ids": []})
	var container: Control = Control.new()
	add_child_autofree(container)
	card = CardScript.new()
	container.add_child(card)
	card.size = Vector2(120.0, 168.0)
	coordinator = CoordinatorScript.new()
	add_child_autofree(coordinator)
	coordinator.setup([cs], null, Callable(cs, "get_character_hp"), false)
	coordinator.register_card(target_id, card)
	cs.call("set_attack_queue", [{
		"attacker_id": 1, "target_id": target_id,
		"attacker_atk": 10, "target_def": 0,
		"attacker_realm": 1, "defender_realm": 1, "target_hp": 20,
	}])


## 当前唯一可见飘字 Label。
func _visible_floater() -> Label:
	var pool: Control = coordinator.floater_pool
	for child: Node in pool.get_children():
		if child is Label and (child as Label).visible:
			return child as Label
	return null


func _wait_frames(frames: int) -> void:
	for i: int in frames:
		await get_tree().process_frame


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 减伤 15%：飘字 = 实际扣血 8（不是原始伤害 10）
# ═══════════════════════════════════════════════════════════════════════════════

func test_damage_reduced_floater_shows_actual_damage() -> void:
	# Arrange —— 15% 减伤：原始伤害 10 → floor(10 × 0.85) = 8
	_bind_reduction(CHAR_REDUCED)
	_setup_battle(CHAR_REDUCED)
	var payloads: Array = []
	cs.connect("character_damaged", func(data: Dictionary) -> void:
		payloads.append(data.duplicate(true)))
	# Act
	cs.call("_resolve_attack_queue")
	# Assert —— 载荷增量即实际扣血
	assert_eq(payloads.size(), 1, "一次攻击广播一次 character_damaged")
	assert_eq(int(payloads[0]["damage"]), 8, "载荷应为实际扣血 8（非原始伤害 10）")
	assert_true(bool(payloads[0]["damage_reduced"]), "载荷应标记本次伤害被减伤")
	# Assert —— 飘字数值 = 实际扣血
	var label: Label = _visible_floater()
	assert_not_null(label, "应发射一个伤害飘字")
	assert_eq(label.text, "-8 减", "飘字应显示实际扣血 8 并带「减」角标")
	assert_eq(label.get_theme_color("font_color"), PoolScript.REDUCED_DAMAGE_COLOR,
		"减伤飘字应为琥珀色（与纯红伤害可辨识）")


func test_damage_reduced_floater_matches_hp_drop_after_flush() -> void:
	# Arrange
	_bind_reduction(CHAR_REDUCED)
	_setup_battle(CHAR_REDUCED)
	# Act
	cs.call("_resolve_attack_queue")
	await _wait_frames(3)  # 结算帧（call_deferred）落地
	# Assert —— 飘字数字与 HP 条实际减少量一致（20 → 12，扣 8）
	assert_eq(card.current_hp, 12, "HP 条应反映实际扣血 8（20 → 12）")
	var label: Label = _visible_floater()
	assert_eq(label.text, "-8 减", "飘字数字应与 HP 条减少量一致")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 无减伤：行为完全不变（红色 -10、无角标）
# ═══════════════════════════════════════════════════════════════════════════════

func test_no_reduction_floater_behavior_unchanged() -> void:
	# Arrange —— 不绑任何减伤卡
	_setup_battle(CHAR_PLAIN)
	var payloads: Array = []
	cs.connect("character_damaged", func(data: Dictionary) -> void:
		payloads.append(data.duplicate(true)))
	# Act
	cs.call("_resolve_attack_queue")
	# Assert —— 载荷不带减伤标志
	assert_eq(int(payloads[0]["damage"]), 10, "无减伤时伤害为 10")
	assert_false(bool(payloads[0]["damage_reduced"]), "无减伤时不应标记被减伤")
	# Assert —— 飘字保持旧格式（红 + 无角标）
	var label: Label = _visible_floater()
	assert_not_null(label, "应发射一个伤害飘字")
	assert_eq(label.text, "-10", "无减伤飘字文本应保持 -10（无「减」角标）")
	assert_eq(label.get_theme_color("font_color"), PoolScript.DAMAGE_COLOR,
		"无减伤飘字应保持伤害红色")
