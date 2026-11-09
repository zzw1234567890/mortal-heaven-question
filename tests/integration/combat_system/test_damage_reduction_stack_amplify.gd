extends GutTest
## 减伤同名叠层放大集成测试（GDD binding-system.md §10 可叠加放大类）。[br]
## 单条记录贡献 = [code]pct × stack_multiplier^(stack_count-1)[/code]，多来源仍走
## [code]combine_damage_reduction[/code] 乘算叠加并保留 60% 封顶。[br]
## 测试策略同 test_damage_reduction_wiring.gd：真实 BindingManager / CardSystem Autoload，
## 模板注入 [code]CardSystem.templates[/code] 并在 after_each 还原。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const CardTemplateClass := preload("res://src/core/card_system/card_template.gd")
const BRClass := preload("res://src/feature/binding/binding_record.gd")
const GONGFA: int = BRClass.BindingSlot.GONGFA

## 本文件独立的角色 ID 段——不与其它测试文件夹具冲突。
const CHAR_STACK_2: int = 7401
const CHAR_STACK_3: int = 7402
const CHAR_MIXED: int = 7403
const CHAR_CAP: int = 7404

var cs: Node = null
var _binding_ids: Array = []
var _template_backup: Dictionary = {}
var _next_card_id: int = 1


func before_each() -> void:
	cs = CS_SCRIPT.new()
	cs.call("set_auto_advance", false)
	cs.call("set_scene_change", false)
	GameStateManager.battle = null
	GameStateManager._pending_changes.clear()
	GameStateManager._flush_scheduled = false
	_binding_ids.clear()
	_template_backup.clear()
	_inject_template(&"test_stack_10", 10, 15, &"")
	_inject_template(&"test_stack_15", 15, 20, &"")
	# 元婴期：每角色 3 个功法位（多层叠加 + 异名来源）
	BindingManager.cache_slot_limits(GameStateManager.RealmLevel.NASCENT_SOUL)


func after_each() -> void:
	for binding_id: int in _binding_ids:
		BindingManager.remove_binding(binding_id)
	_binding_ids.clear()
	for template_id: StringName in _template_backup.keys():
		var prior: Variant = _template_backup[template_id]
		if prior == null:
			CardSystem.templates.erase(template_id)
		else:
			CardSystem.templates[template_id] = prior
	_template_backup.clear()
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

## 注入减伤模板（stack_multiplier 沿用 CardTemplate 默认 1.5）。
func _inject_template(template_id: StringName, pct: int, native_pct: int,
		native_owner: StringName) -> void:
	_template_backup[template_id] = CardSystem.templates.get(template_id)
	var tpl := CardTemplateClass.new()
	tpl.card_id = template_id
	tpl.type = CardTemplateClass.CardType.TECHNIQUE
	tpl.effect_type = &"damage_reduce"
	tpl.effect_value = pct
	tpl.native_effect_value = native_pct
	tpl.native_owner = native_owner
	CardSystem.templates[template_id] = tpl


## 绑定一张减伤卡——返回 binding_id（失败时 assert 并返回 -1）。
func _bind(character_id: int, template_id: StringName) -> int:
	var card_instance_id: int = 960000 + _next_card_id
	_next_card_id += 1
	var result: Dictionary = BindingManager.bind_card(
			card_instance_id, template_id, character_id, GONGFA)
	assert_true(bool(result.get("success", false)),
			"前置：%s 应绑定成功（reason=%s）" % [template_id, result.get("reason", "")])
	if not bool(result.get("success", false)):
		return -1
	var binding_id: int = int(result["binding_id"])
	_binding_ids.append(binding_id)
	return binding_id


## 绑定并叠加到指定层数——bind 一次后连续 stack_card（共享同一 binding_id）。
func _bind_stacked(character_id: int, template_id: StringName, target_count: int) -> void:
	_bind(character_id, template_id)
	for i: int in range(target_count - 1):
		var card_instance_id: int = 960000 + _next_card_id
		_next_card_id += 1
		var result: Dictionary = BindingManager.stack_card(
				card_instance_id, template_id, character_id)
		assert_true(bool(result.get("stacked", false)),
				"前置：叠加第 %d 层应成功（reason=%s）" % [i + 2, result.get("reason", "")])


## 敌方 Dictionary 条目（HP 回写在原地可见）。
func _enemy(character_id: int, hp: int = 20) -> Dictionary:
	return {"character_id": character_id, "current_hp": hp, "max_hp": hp, "is_alive": true}


## 攻击队列条目——ATK 10 / DEF 0 / 同境界，基准伤害 10。
func _attack_entry(attacker_id: int, target_id: int, target_hp: int = 20) -> Dictionary:
	return {
		"attacker_id": attacker_id, "target_id": target_id,
		"attacker_atk": 10, "target_def": 0,
		"attacker_realm": 1, "defender_realm": 1, "target_hp": target_hp,
	}


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 单条记录贡献按叠层放大
# ═══════════════════════════════════════════════════════════════════════════════

## 1 层：10 × 1.5^0 = 10%。
func test_single_stack_contributes_base_pct() -> void:
	# Arrange
	_bind_stacked(CHAR_STACK_2, &"test_stack_10", 1)
	# Act
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_STACK_2)
	# Assert
	assert_eq(pcts, [10.0], "1 层贡献 10%（10 × 1.5^0）")


## 2 层：10 × 1.5^1 = 15%。
func test_two_stacks_amplify_to_fifteen_percent() -> void:
	# Arrange
	_bind_stacked(CHAR_STACK_2, &"test_stack_10", 2)
	# Act
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_STACK_2)
	# Assert
	assert_eq(pcts, [15.0], "2 层贡献 15%（10 × 1.5^1）")


## 3 层：10 × 1.5^2 = 22.5%。
func test_three_stacks_amplify_to_twenty_two_point_five_percent() -> void:
	# Arrange
	_bind_stacked(CHAR_STACK_3, &"test_stack_10", 3)
	# Act
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_STACK_3)
	# Assert
	assert_eq(pcts, [22.5], "3 层贡献 22.5%（10 × 1.5^2）")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 放大后的来源进入攻击队列并影响伤害
# ═══════════════════════════════════════════════════════════════════════════════

## 2 层 10% → 15% 来源 → 伤害 20 → 12（10 × 0.85 = 8.5 → floor 8）。
func test_two_stack_amplified_reduction_reaches_damage() -> void:
	# Arrange
	_bind_stacked(CHAR_STACK_2, &"test_stack_10", 2)
	var enemy := _enemy(CHAR_STACK_2)
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	var entry := _attack_entry(1, CHAR_STACK_2)
	cs.call("set_attack_queue", [entry])
	# Act
	cs.call("_resolve_attack_queue")
	# Assert
	assert_eq(entry.get("damage_reduction_pcts"), [15.0], "队列条目应写入放大后的 15%")
	assert_eq(int(enemy["current_hp"]), 12, "放大后扣 8 点（20 → 12）")


## 3 层 10% → 22.5% 来源 → 伤害 10 × 0.775 = 7.75 → floor 7；20 → 13。
func test_three_stack_amplified_reduction_reaches_damage() -> void:
	# Arrange
	_bind_stacked(CHAR_STACK_3, &"test_stack_10", 3)
	var enemy := _enemy(CHAR_STACK_3)
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	var entry := _attack_entry(1, CHAR_STACK_3)
	cs.call("set_attack_queue", [entry])
	# Act
	cs.call("_resolve_attack_queue")
	# Assert
	assert_eq(entry.get("damage_reduction_pcts"), [22.5], "队列条目应写入放大后的 22.5%")
	assert_eq(int(enemy["current_hp"]), 13, "扣 7 点（20 → 13）")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 叠层放大 + 异名来源的乘算合并 / 封顶
# ═══════════════════════════════════════════════════════════════════════════════

## 2 层 10%（→15%）+ 另一张 15%：0.85 × 0.85 = 0.7225 → 伤害 10 × 0.7225 = 7.225 → 7。
func test_stacked_source_combines_multiplicatively_with_other_card() -> void:
	# Arrange
	_bind_stacked(CHAR_MIXED, &"test_stack_10", 2)
	_bind(CHAR_MIXED, &"test_stack_15")
	var enemy := _enemy(CHAR_MIXED)
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	var entry := _attack_entry(1, CHAR_MIXED)
	cs.call("set_attack_queue", [entry])
	# Act
	cs.call("_resolve_attack_queue")
	# Assert——两条来源各 15%，乘算后等效 27.75%
	assert_eq(entry.get("damage_reduction_pcts"), [15.0, 15.0], "叠层放大后与异名来源按乘算合并")
	assert_eq(int(enemy["current_hp"]), 13, "0.7225 系数下扣 7 点（20 → 13）")


## 叠层放大后仍受 60% 封顶：30% × 1.5^2 = 67.5%，与另一端相乘后仍封顶 0.4。
func test_stacked_sources_still_capped_at_sixty_percent() -> void:
	# Arrange——三层 30% 各放大到 67.5%，乘算远超封顶
	_inject_template(&"test_stack_30", 30, 40, &"")
	_bind_stacked(CHAR_CAP, &"test_stack_30", 3)
	_bind(CHAR_CAP, &"test_stack_15")
	var enemy := _enemy(CHAR_CAP)
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	var entry := _attack_entry(1, CHAR_CAP)
	cs.call("set_attack_queue", [entry])
	# Act
	cs.call("_resolve_attack_queue")
	# Assert——封顶 60% → 系数 0.4 → 伤害 4
	assert_eq(entry.get("damage_reduction_pcts"), [67.5, 15.0],
			"30% 叠 3 层放大到 67.5%，异名 15% 原样（叠层放大只作用于同名记录）")
	assert_eq(int(enemy["current_hp"]), 16, "封顶 60% 后扣 4 点（20 → 16）")
