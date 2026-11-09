extends GutTest
## 减伤链路集成测试：绑定卡 damage_reduce → 攻击队列 damage_reduction_pcts → 伤害。
##
## 覆盖 DEBT-CBT-018-8 的残留闭环（本轮接线）：[br]
##   1. Attack 阶段（[code]_resolve_attack_queue[/code]）为每条攻击的[b]防御方[/b]
##      汇总在场角色的绑定减伤，写入条目 [code]damage_reduction_pcts[/code]；[br]
##   2. 汇总只给来源，乘算叠加与 60% 封顶走 [code]combine_damage_reduction[/code]；[br]
##   3. 本命减伤取 [code]native_effect_value[/code] 原值（10% → 15%，不做 ×1.5）；[br]
##   4. 无来源时条目不带该键、伤害不变（不臆造 0%）。
## [br]测试策略（同 test_damage_settlement_wiring.gd）：[code]CS_SCRIPT.new()[/code] 独立实例
## + [code]set_auto_advance(false)[/code]；真实 BindingManager / CardSystem Autoload 参与，
## 模板注入 [code]CardSystem.templates[/code] 并在 after_each 还原。

const CS_SCRIPT := preload("res://src/feature/combat_system.gd")
const CardTemplateClass := preload("res://src/core/card_system/card_template.gd")
const BRClass := preload("res://src/feature/binding/binding_record.gd")
const GONGFA: int = BRClass.BindingSlot.GONGFA

## 各用例独立的角色 ID 段——不与其它测试文件的夹具冲突。
const CHAR_PLAIN: int = 7301
const CHAR_NATIVE: int = 7302
const CHAR_STACK: int = 7303
const CHAR_DEF_A: int = 7304
const CHAR_DEF_B: int = 7305
const CHAR_SUSPENDED: int = 7306

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
	_inject_template(&"test_red_10", 10, 15, &"lin_yuan")
	_inject_template(&"test_red_15", 15, 20, &"xi_yin")
	_inject_template(&"test_red_30", 30, 40, &"")
	# 筑基期：每角色 2 个功法位（叠两张减伤卡的前提）
	BindingManager.cache_slot_limits(GameStateManager.RealmLevel.FOUNDATION)


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

## 注入减伤模板到真实 CardSystem（记原值以便还原）。
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


## 绑定一张减伤卡到角色——返回 binding_id（失败时 assert 并返回 -1）。
func _bind(character_id: int, template_id: StringName,
		native_owner: StringName = &"", character_card_id: StringName = &"") -> int:
	var card_instance_id: int = 900000 + _next_card_id
	_next_card_id += 1
	var result: Dictionary = BindingManager.bind_card(
			card_instance_id, template_id, character_id, GONGFA, native_owner, character_card_id)
	assert_true(bool(result.get("success", false)),
			"前置：%s 应绑定成功（reason=%s）" % [template_id, result.get("reason", "")])
	if not bool(result.get("success", false)):
		return -1
	var binding_id: int = int(result["binding_id"])
	_binding_ids.append(binding_id)
	return binding_id


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
# 1. 单角色单一减伤（绑定卡 → 队列 → 伤害）
# ═══════════════════════════════════════════════════════════════════════════════

func test_single_bound_reduction_reduces_damage_by_ten_percent() -> void:
	# Arrange——非本命绑 10% 减伤（角色卡 ID 不匹配 native_owner）
	_bind(CHAR_PLAIN, &"test_red_10")
	var enemy := _enemy(CHAR_PLAIN)
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	var entry := _attack_entry(1, CHAR_PLAIN)
	cs.call("set_attack_queue", [entry])
	# Act
	cs.call("_resolve_attack_queue")
	# Assert——10 × 0.9 = 9（floor），20 → 11
	assert_eq(BindingManager.get_damage_reduction_pcts(CHAR_PLAIN), [10.0],
			"减伤来源应为单条 10%")
	assert_eq(entry.get("damage_reduction_pcts"), [10.0], "队列条目应写入来源列表")
	assert_eq(int(enemy["current_hp"]), 11, "减伤 10% 后应扣 9 点（20 → 11）")


## 本命触发——10% 卡走 native_effect_value=15，不做 ×1.5（那会得 15 但口径错误）。
func test_native_reduction_uses_native_effect_value() -> void:
	# Arrange——native_owner 与角色卡 ID 匹配 → is_native
	_bind(CHAR_NATIVE, &"test_red_10", &"lin_yuan", &"lin_yuan")
	var enemy := _enemy(CHAR_NATIVE)
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	var entry := _attack_entry(1, CHAR_NATIVE)
	cs.call("set_attack_queue", [entry])
	# Act
	cs.call("_resolve_attack_queue")
	# Assert——10 × 0.85 = 8.5 → floor 8；20 → 12
	assert_eq(entry.get("damage_reduction_pcts"), [15.0], "本命应取 native_effect_value=15")
	assert_eq(int(enemy["current_hp"]), 12, "减伤 15% 后应扣 8 点（20 → 12）")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 多来源乘算叠加 / 封顶
# ═══════════════════════════════════════════════════════════════════════════════

## 同一防御方两张减伤卡（10% + 15%）：GDD §公式乘算 0.9 × 0.85 = 0.765 → 23.5%。
func test_two_reduction_sources_stack_multiplicatively() -> void:
	# Arrange
	_bind(CHAR_STACK, &"test_red_10")
	_bind(CHAR_STACK, &"test_red_15")
	var enemy := _enemy(CHAR_STACK)
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	var entry := _attack_entry(1, CHAR_STACK)
	cs.call("set_attack_queue", [entry])
	# Act
	cs.call("_resolve_attack_queue")
	# Assert——10 × 0.765 = 7.65 → floor 7；20 → 13
	assert_eq(entry.get("damage_reduction_pcts"), [10.0, 15.0], "两条来源都应写入")
	assert_eq(int(enemy["current_hp"]), 13, "乘算叠加后应扣 7 点（20 → 13）")


## 三个 30% 来源：0.7³ = 0.343 → 封顶 60%（×0.4）→ 伤害 4。
func test_reduction_sources_cap_at_sixty_percent() -> void:
	# Arrange——元婴期 3 个功法位
	BindingManager.cache_slot_limits(GameStateManager.RealmLevel.NASCENT_SOUL)
	for i: int in range(3):
		_bind(CHAR_STACK, &"test_red_30")
	var enemy := _enemy(CHAR_STACK)
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	var entry := _attack_entry(1, CHAR_STACK)
	cs.call("set_attack_queue", [entry])
	# Act
	cs.call("_resolve_attack_queue")
	# Assert——10 × 0.4 = 4
	assert_eq(entry.get("damage_reduction_pcts"), [30.0, 30.0, 30.0], "三条 30% 来源都应写入")
	assert_eq(int(enemy["current_hp"]), 16, "封顶 60% 后应扣 4 点（20 → 16）")


## 两个防御方各自带不同减伤——互不合并，各条目取自己的来源。
func test_two_defenders_keep_independent_reduction() -> void:
	# Arrange
	_bind(CHAR_DEF_A, &"test_red_10")
	_bind(CHAR_DEF_B, &"test_red_15")
	var enemy_a := _enemy(CHAR_DEF_A)
	var enemy_b := _enemy(CHAR_DEF_B)
	cs.call("battle_start", {"enemy_roster": [enemy_a, enemy_b], "character_ids": []})
	var entry_a := _attack_entry(1, CHAR_DEF_A)
	var entry_b := _attack_entry(2, CHAR_DEF_B)
	cs.call("set_attack_queue", [entry_a, entry_b])
	# Act
	cs.call("_resolve_attack_queue")
	# Assert——各自 10% / 15%，不叠加成 23.5%
	assert_eq(entry_a.get("damage_reduction_pcts"), [10.0], "A 只有自己的 10%")
	assert_eq(entry_b.get("damage_reduction_pcts"), [15.0], "B 只有自己的 15%")
	assert_eq(int(enemy_a["current_hp"]), 11, "A 扣 9 点")
	assert_eq(int(enemy_b["current_hp"]), 12, "B 扣 8 点")


# ═══════════════════════════════════════════════════════════════════════════════
# 3. 无来源 / 显式值 / 暂挂
# ═══════════════════════════════════════════════════════════════════════════════

## 防御方没有减伤来源——不写键、不写空占位，伤害与旧口径完全一致。
func test_no_reduction_leaves_array_empty_and_damage_unchanged() -> void:
	# Arrange——无任何绑定
	var enemy := _enemy(CHAR_DEF_A)
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	var entry := _attack_entry(1, CHAR_DEF_A)
	cs.call("set_attack_queue", [entry])
	# Act
	cs.call("_resolve_attack_queue")
	# Assert
	assert_eq(BindingManager.get_damage_reduction_pcts(CHAR_DEF_A), [], "无绑定应返回空数组")
	assert_false(entry.has("damage_reduction_pcts"), "取不到来源时不写该键（缺省即无减伤）")
	assert_eq(int(enemy["current_hp"]), 10, "伤害不变：10 - 10 = 0 → 10 点全扣")


## 调用方显式给定的减伤不被绑定汇总覆盖（一次性格挡等非常驻来源）。
func test_explicit_queue_reduction_is_not_overwritten() -> void:
	# Arrange——角色本身也绑了 10%，但条目显式给 20%
	_bind(CHAR_PLAIN, &"test_red_10")
	var enemy := _enemy(CHAR_PLAIN)
	cs.call("battle_start", {"enemy_roster": [enemy], "character_ids": []})
	var entry := _attack_entry(1, CHAR_PLAIN)
	entry["damage_reduction_pcts"] = [20]
	cs.call("set_attack_queue", [entry])
	# Act
	cs.call("_resolve_attack_queue")
	# Assert——10 × 0.8 = 8
	assert_eq(entry.get("damage_reduction_pcts"), [20], "显式值原样保留")
	assert_eq(int(enemy["current_hp"]), 12, "按显式 20% 结算（20 → 12）")


## 暂挂绑定（角色离场）不参与减伤汇总。
func test_suspended_binding_is_not_counted() -> void:
	# Arrange
	_bind(CHAR_SUSPENDED, &"test_red_10")
	BindingManager.suspend_bindings(CHAR_SUSPENDED)
	# Act
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_SUSPENDED)
	# Assert
	assert_eq(pcts, [], "暂挂中的绑定不应贡献减伤")
