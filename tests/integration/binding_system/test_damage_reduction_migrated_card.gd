extends GutTest
## 减伤卡迁移安全底线测试（DEBT-CBT-018-10 第二阶段）。[br]
## [br][b]背景[/b]：绑定减伤此前直接读模板[b]扁平[/b]字段，减伤卡一旦迁到
## [member CardTemplate.effects] 并清空扁平字段，会[b]静默读出 0%[/b]（不报错、不崩溃，
## 玩家侧只表现为减伤消失）。本文件锁住三件事：[br]
##   1. [b]迁移后不丢减伤[/b]：只挂 [code]effects[/code] 的减伤卡仍贡献正确 pct，
##      且与等值扁平卡的数值逐位一致（旧卡零漂移）；[br]
##   2. [b]本命口径不变[/b]：本命 15% 仍取 [code]native_value[/code] 原值（不走 ×1.5）；[br]
##   3. [b]叠层放大作用在汇总 pct 之上[/b]：一张卡挂多条减伤时先汇总（乘算 + 封顶），
##      再乘 [code]stack_multiplier^(count-1)[/code]——与 [code]get_binding_context[/code] 同口径。[br]
## [br]测试策略同 test_damage_reduction_wiring.gd：真实 BindingManager / CardSystem Autoload，
## 模板注入 [code]CardSystem.templates[/code] 并在 after_each 还原。

const CardTemplateClass := preload("res://src/core/card_system/card_template.gd")
const EntryClass: GDScript = preload("res://src/core/card_system/effect_entry.gd")
const BRClass := preload("res://src/feature/binding/binding_record.gd")
const GONGFA: int = BRClass.BindingSlot.GONGFA

## 本文件独立的角色 ID 段——不与其它测试文件夹具冲突。
const CHAR_FLAT: int = 7601
const CHAR_MIGRATED: int = 7602
const CHAR_MIGRATED_NATIVE: int = 7603
const CHAR_MULTI: int = 7604
const CHAR_STACK: int = 7605

var _binding_ids: Array = []
var _template_backup: Dictionary = {}
var _next_card_id: int = 1


func before_each() -> void:
	_binding_ids.clear()
	_template_backup.clear()
	# 筑基期：每角色 2 个功法位（叠两层的前提）
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


# ═══════════════════════════════════════════════════════════════════════════════
# 夹具
# ═══════════════════════════════════════════════════════════════════════════════

## 减伤条目（[code]value[/code] 为百分比整数，[code]native_value[/code] 为本命覆盖）。
func _entry(pct: int, native_pct: int = 0) -> Resource:
	var entry: Resource = EntryClass.new()
	entry.effect_type = &"damage_reduce"
	entry.value = pct
	entry.native_value = native_pct
	return entry


## 注册模板（记原值以便还原）——[code]flat_pct < 0[/code] 表示不写扁平字段（已迁移口径）。
func _register(template_id: StringName, flat_pct: int, native_pct: int,
		entries: Array, native_owner: StringName = &"") -> void:
	_template_backup[template_id] = CardSystem.templates.get(template_id)
	var tpl := CardTemplateClass.new()
	tpl.card_id = template_id
	tpl.type = CardTemplateClass.CardType.TECHNIQUE
	tpl.native_owner = native_owner
	tpl.native_effect_value = native_pct
	if flat_pct >= 0:
		tpl.effect_type = &"damage_reduce"
		tpl.effect_value = flat_pct
	if not entries.is_empty():
		tpl.effects.assign(entries)
	CardSystem.templates[template_id] = tpl


## 绑定一张卡——返回 binding_id（失败时 assert 并返回 -1）。
func _bind(character_id: int, template_id: StringName,
		native_owner: StringName = &"") -> int:
	var card_instance_id: int = 970000 + _next_card_id
	_next_card_id += 1
	var result: Dictionary = BindingManager.bind_card(
			card_instance_id, template_id, character_id, GONGFA, native_owner, native_owner)
	assert_true(bool(result.get("success", false)),
			"前置：%s 应绑定成功（reason=%s）" % [template_id, result.get("reason", "")])
	if not bool(result.get("success", false)):
		return -1
	var binding_id: int = int(result["binding_id"])
	_binding_ids.append(binding_id)
	return binding_id


## 叠加同名卡到指定层数（共享同一 binding_id）。
func _stack(character_id: int, template_id: StringName, target_count: int) -> void:
	for _i: int in range(target_count - 1):
		var card_instance_id: int = 970000 + _next_card_id
		_next_card_id += 1
		var result: Dictionary = BindingManager.stack_card(
				card_instance_id, template_id, character_id)
		assert_true(bool(result.get("stacked", false)),
				"前置：叠加第 %d 层应成功（reason=%s）" % [_i + 2, result.get("reason", "")])


# ═══════════════════════════════════════════════════════════════════════════════
# 1. 迁移后不丢减伤（与等值扁平卡逐位一致）
# ═══════════════════════════════════════════════════════════════════════════════

## 旧扁平卡（effects 为空）——行为不变：10% → [10.0]。
func test_flat_card_still_contributes_base_pct() -> void:
	# Arrange
	_register(&"test_flat_10", 10, 0, [])
	_bind(CHAR_FLAT, &"test_flat_10")
	# Act
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_FLAT)
	# Assert
	assert_eq(pcts, [10.0], "旧扁平通道行为不变（10%）")


## 已迁移卡（只有 effects、扁平字段清空）——仍贡献 10%，不静默归零。
func test_migrated_card_keeps_reduction() -> void:
	# Arrange——模拟迁移后的减伤卡：effect_type/effect_value 留空，效果只在 effects 里
	_register(&"test_migrated_10", -1, 0, [_entry(10)])
	_bind(CHAR_MIGRATED, &"test_migrated_10")
	# Act
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_MIGRATED)
	# Assert
	assert_eq(pcts, [10.0], "迁移后减伤不应消失（10%）")


## 迁移卡与等值扁平卡逐位一致（0.9 这类浮点不可精确表示，不能有尾差）。
func test_migrated_matches_flat_contribution_exactly() -> void:
	# Arrange
	_register(&"test_flat_15", 15, 0, [])
	_register(&"test_migrated_15", -1, 0, [_entry(15)])
	_bind(CHAR_FLAT, &"test_flat_15")
	_bind(CHAR_MIGRATED, &"test_migrated_15")
	# Act
	var flat: Array = BindingManager.get_damage_reduction_pcts(CHAR_FLAT)
	var migrated: Array = BindingManager.get_damage_reduction_pcts(CHAR_MIGRATED)
	# Assert
	assert_eq(migrated, flat, "迁移口径与旧扁平口径逐位一致")
	assert_eq(migrated, [15.0], "15% 来源不变")


## 本命口径不变——扁平卡的 native_effect_value 仍按原值采用（10% → 15%，非 ×1.5）。
func test_flat_native_override_unchanged() -> void:
	# Arrange
	_register(&"test_flat_native", 10, 15, [], &"lin_yuan")
	_bind(CHAR_FLAT, &"test_flat_native", &"lin_yuan")
	# Act
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_FLAT)
	# Assert
	assert_eq(pcts, [15.0], "本命仍取 native_effect_value=15")


## 迁移卡的本命覆盖同样生效（绑定记录的 is_native 经汇总器上下文传入）。
func test_migrated_native_override_keeps_non_linear_value() -> void:
	# Arrange
	_register(&"test_migrated_native", -1, 0, [_entry(10, 15)], &"lin_yuan")
	_bind(CHAR_MIGRATED_NATIVE, &"test_migrated_native", &"lin_yuan")
	# Act
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_MIGRATED_NATIVE)
	# Assert
	assert_eq(pcts, [15.0], "迁移卡本命仍取 native_value=15（不走 ×1.5）")


# ═══════════════════════════════════════════════════════════════════════════════
# 2. 叠层放大作用在汇总 pct 之上
# ═══════════════════════════════════════════════════════════════════════════════

## 迁移卡叠 2 层：10% × 1.5 = 15%。
func test_migrated_card_stack_amplifies_aggregate() -> void:
	# Arrange
	_register(&"test_migrated_stack", -1, 0, [_entry(10)])
	_bind(CHAR_STACK, &"test_migrated_stack")
	_stack(CHAR_STACK, &"test_migrated_stack", 2)
	# Act
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_STACK)
	# Assert
	assert_eq(pcts, [15.0], "迁移卡叠 2 层仍按 10 × 1.5^1 放大")


## 一张卡两条减伤条目 = 一份来源：先汇总（0.9 × 0.8 = 0.72 → 28%），再乘叠层系数。
## 若改成「逐条放大再汇总」会得到 0.85 × 0.7 = 0.595 → 40.5%——两个口径可区分。
func test_amplification_applies_after_entry_aggregation() -> void:
	# Arrange
	_register(&"test_migrated_multi", -1, 0, [_entry(10), _entry(20)])
	_bind(CHAR_MULTI, &"test_migrated_multi")
	_stack(CHAR_MULTI, &"test_migrated_multi", 2)
	# Act
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_MULTI)
	# Assert
	assert_eq(pcts.size(), 1, "同一 binding 只产出一份来源（不按条目拆成两条）")
	assert_almost_eq(float(pcts[0]), 42.0, 0.0001,
			"汇总 28% 再 × 1.5 = 42%（不是逐条放大后的 40.5%）")


## 一张卡的多条减伤参与乘算与 60% 封顶——单来源也走同一条合成公式。
func test_multi_entry_aggregate_respects_sixty_percent_cap() -> void:
	# Arrange——50% + 50% → 0.25 → 75% 超出封顶 → 60%
	_register(&"test_migrated_cap", -1, 0, [_entry(50), _entry(50)])
	_bind(CHAR_MULTI, &"test_migrated_cap")
	# Act
	var pcts: Array = BindingManager.get_damage_reduction_pcts(CHAR_MULTI)
	# Assert
	assert_almost_eq(float(pcts[0]), 60.0, 0.0001, "多条来源乘算后封顶 60%")
