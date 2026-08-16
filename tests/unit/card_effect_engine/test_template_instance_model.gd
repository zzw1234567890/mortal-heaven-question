extends GutTest
## Story 001 验收测试：EffectTemplate/EffectInstance 双层对象模型。
##
## 覆盖 AC-001 到 AC-004 + QA Edge cases + @abstract 基类反射验证 + EffectFactory 分派。
## 对象模型层测试——不涉及端到端结算（ResolutionStack 属 Story 002）。
##
## [b]@abstract 反射验证[/b]（Godot 4.6）：
##   - [code]GDScript.is_abstract()[/code] 返回 bool——abstract 基类为 true，4 子类为 false。
##   - [code]GDScript.can_instantiate()[/code] 对 abstract 基类仍返回 true（实测）——
##     故"基类不可实例化"用 [code]is_abstract()[/code] 断言，而非 [code]can_instantiate()[/code]。
##   - 绝不对基类调用 [method .new()]——abstract 类实例化是编译期 parse error，
##     会使整个测试脚本无法解析。

# === preload 脚本引用 ==============================================================

const EffectBaseClass := preload("res://src/feature/card_effect_engine/effect_base.gd")
const EffectTemplateClass := preload("res://src/feature/card_effect_engine/effect_template.gd")
const InstantEffectClass := preload("res://src/feature/card_effect_engine/instant_effect.gd")
const PersistentEffectClass := preload("res://src/feature/card_effect_engine/persistent_effect.gd")
const TriggeredEffectClass := preload("res://src/feature/card_effect_engine/triggered_effect.gd")
const ReplacementEffectClass := preload("res://src/feature/card_effect_engine/replacement_effect.gd")
const EffectFactoryClass := preload("res://src/feature/card_effect_engine/effect_factory.gd")
const EventEnumsClass := preload("res://src/foundation/event_system/event_enums.gd")


# ============================================================================
# AC-001：InstantEffect base_value=3 → get_effective_value(1.0) == 3
# ============================================================================

func test_instant_effect_base_3_multiplier_1_0_returns_3() -> void:
	var effect: RefCounted = InstantEffectClass.new()
	effect.base_value = 3
	assert_eq(effect.get_effective_value(1.0), 3, "base_value=3 × 1.0 应为 3")


# ============================================================================
# AC-002：同实例 get_effective_value(1.5) == 4（floori(3×1.5)=4）
# ============================================================================

func test_instant_effect_base_3_multiplier_1_5_returns_4() -> void:
	var effect: RefCounted = InstantEffectClass.new()
	effect.base_value = 3
	assert_eq(effect.get_effective_value(1.5), 4, "floori(3×1.5)=floori(4.5)=4")


# ============================================================================
# AC-003：OutcomeType.MODIFY_STAT 存在且 == 13
# ============================================================================

func test_outcome_type_modify_stat_exists_equals_13() -> void:
	assert_eq(EventEnumsClass.OutcomeType.MODIFY_STAT, 13, "MODIFY_STAT 应为 13")


# ============================================================================
# AC-004：PersistentEffect.binding_multiplier 默认 1.0，可构造时锁定 1.5
# ============================================================================

func test_persistent_effect_binding_multiplier_default_is_1_0() -> void:
	var effect: RefCounted = PersistentEffectClass.new()
	assert_eq(effect.binding_multiplier, 1.0, "非本命绑定默认 1.0")


func test_persistent_effect_binding_multiplier_locks_1_5() -> void:
	var effect: RefCounted = PersistentEffectClass.new()
	effect.binding_multiplier = 1.5
	assert_eq(effect.binding_multiplier, 1.5, "本命绑定应锁定 1.5")


# ============================================================================
# QA Edge cases：base_value=0 / 偶数 floori(4×1.5)=6 / 非本命 1.0
# ============================================================================

func test_effective_value_base_0_returns_0() -> void:
	var effect: RefCounted = InstantEffectClass.new()
	effect.base_value = 0
	assert_eq(effect.get_effective_value(1.5), 0, "base_value=0 → 有效值 0（严格非负）")


func test_effective_value_even_base_4_multiplier_1_5_returns_6() -> void:
	var effect: RefCounted = InstantEffectClass.new()
	effect.base_value = 4
	assert_eq(effect.get_effective_value(1.5), 6, "floori(4×1.5)=6（整数无损失）")


func test_effective_value_non_native_multiplier_1_0_unchanged() -> void:
	var effect: RefCounted = InstantEffectClass.new()
	effect.base_value = 3
	assert_eq(effect.get_effective_value(1.0), 3, "非本命 1.0 不加成")


# ============================================================================
# EffectType 枚举：4 值，0-based
# ============================================================================

func test_effect_type_has_four_values() -> void:
	assert_eq(EffectTemplateClass.EffectType.size(), 4, "EffectType 应有 4 个值")
	assert_eq(EffectTemplateClass.EffectType.INSTANT, 0)
	assert_eq(EffectTemplateClass.EffectType.PERSISTENT, 1)
	assert_eq(EffectTemplateClass.EffectType.TRIGGERED, 2)
	assert_eq(EffectTemplateClass.EffectType.REPLACEMENT, 3)


# ============================================================================
# @abstract 基类反射验证（不调用 .new()）
# ============================================================================

func test_effect_base_is_abstract() -> void:
	var script: GDScript = EffectBaseClass
	assert_true(script.is_abstract(), "EffectBase 应为 abstract 类（不可实例化）")


func test_effect_base_extends_refcounted() -> void:
	var script: GDScript = EffectBaseClass
	assert_eq(script.get_instance_base_type(), "RefCounted", "EffectBase 应继承 RefCounted")


# ============================================================================
# 4 子类可实例化（非 abstract + can_instantiate + new() 成功）
# ============================================================================

func test_instant_effect_is_not_abstract_and_can_instantiate() -> void:
	var script: GDScript = InstantEffectClass
	assert_false(script.is_abstract(), "InstantEffect 不应是 abstract")
	assert_true(script.can_instantiate(), "InstantEffect 应可实例化")
	var inst: RefCounted = InstantEffectClass.new()
	assert_true(inst is EffectBase, "InstantEffect 实例应 is EffectBase")


func test_persistent_effect_is_not_abstract_and_can_instantiate() -> void:
	var script: GDScript = PersistentEffectClass
	assert_false(script.is_abstract(), "PersistentEffect 不应是 abstract")
	assert_true(script.can_instantiate(), "PersistentEffect 应可实例化")
	var inst: RefCounted = PersistentEffectClass.new()
	assert_true(inst is EffectBase, "PersistentEffect 实例应 is EffectBase")


func test_triggered_effect_is_not_abstract_and_can_instantiate() -> void:
	var script: GDScript = TriggeredEffectClass
	assert_false(script.is_abstract(), "TriggeredEffect 不应是 abstract")
	assert_true(script.can_instantiate(), "TriggeredEffect 应可实例化")
	var inst: RefCounted = TriggeredEffectClass.new()
	assert_true(inst is EffectBase, "TriggeredEffect 实例应 is EffectBase")


func test_replacement_effect_is_not_abstract_and_can_instantiate() -> void:
	var script: GDScript = ReplacementEffectClass
	assert_false(script.is_abstract(), "ReplacementEffect 不应是 abstract")
	assert_true(script.can_instantiate(), "ReplacementEffect 应可实例化")
	var inst: RefCounted = ReplacementEffectClass.new()
	assert_true(inst is EffectBase, "ReplacementEffect 实例应 is EffectBase")


# ============================================================================
# 4 子类 override _resolve()（非 abstract 化——抽象方法已实现）
# ============================================================================

func test_subclasses_override_resolve() -> void:
	## 若任一子类未实现 _resolve()，其 is_abstract() 仍为 true。
	## 此处断言 4 子类均非 abstract——间接验证 _resolve() 已 override。
	var scripts: Array = [InstantEffectClass, PersistentEffectClass, TriggeredEffectClass, ReplacementEffectClass]
	for script in scripts:
		assert_false(script.is_abstract(), "子类应 override _resolve() 使自身非 abstract")


# ============================================================================
# OutcomeType 扩展：ADR-0009 追加 5 值（非重排非删除）
# ============================================================================

func test_outcome_type_appended_five_values() -> void:
	assert_eq(EventEnumsClass.OutcomeType.size(), 17, "OutcomeType 应为 17 值（12 + 5 追加）")
	assert_eq(EventEnumsClass.OutcomeType.APPLY_STATUS, 12)
	assert_eq(EventEnumsClass.OutcomeType.MODIFY_STAT, 13)
	assert_eq(EventEnumsClass.OutcomeType.TRIGGER_CHAIN, 14)
	assert_eq(EventEnumsClass.OutcomeType.ACTIVATE_FORMATION, 15)
	assert_eq(EventEnumsClass.OutcomeType.MODIFY_COST, 16)


func test_outcome_type_original_twelve_values_unchanged() -> void:
	## 追加非重排——原 12 值保持稳定（避免破坏现有序列化数据）。
	assert_eq(EventEnumsClass.OutcomeType.ADD_RESOURCE, 0)
	assert_eq(EventEnumsClass.OutcomeType.ADD_CULTIVATION, 1)
	assert_eq(EventEnumsClass.OutcomeType.ADD_CARD, 2)
	assert_eq(EventEnumsClass.OutcomeType.REMOVE_CARD, 3)
	assert_eq(EventEnumsClass.OutcomeType.HEAL, 4)
	assert_eq(EventEnumsClass.OutcomeType.DAMAGE, 5)
	assert_eq(EventEnumsClass.OutcomeType.SET_FLAG, 6)
	assert_eq(EventEnumsClass.OutcomeType.GAIN_TALENT, 7)
	assert_eq(EventEnumsClass.OutcomeType.TRIGGER_BATTLE, 8)
	assert_eq(EventEnumsClass.OutcomeType.ADVANCE_CHAPTER, 9)
	assert_eq(EventEnumsClass.OutcomeType.RESTORE_AP, 10)
	assert_eq(EventEnumsClass.OutcomeType.NOTHING, 11)


# ============================================================================
# EffectFactory：按 template.type 分派 + 字段复制
# ============================================================================

func test_factory_dispatch_instant_effect() -> void:
	var factory: RefCounted = EffectFactoryClass.new()
	var tpl: Resource = EffectTemplateClass.new()
	tpl.type = EffectTemplateClass.EffectType.INSTANT
	var inst: EffectBase = factory.create_instance(tpl, 42)
	assert_true(inst is InstantEffect, "INSTANT 类型应分派为 InstantEffect")


func test_factory_dispatch_persistent_effect() -> void:
	var factory: RefCounted = EffectFactoryClass.new()
	var tpl: Resource = EffectTemplateClass.new()
	tpl.type = EffectTemplateClass.EffectType.PERSISTENT
	var inst: EffectBase = factory.create_instance(tpl, 42)
	assert_true(inst is PersistentEffect, "PERSISTENT 类型应分派为 PersistentEffect")


func test_factory_dispatch_triggered_effect() -> void:
	var factory: RefCounted = EffectFactoryClass.new()
	var tpl: Resource = EffectTemplateClass.new()
	tpl.type = EffectTemplateClass.EffectType.TRIGGERED
	var inst: EffectBase = factory.create_instance(tpl, 42)
	assert_true(inst is TriggeredEffect, "TRIGGERED 类型应分派为 TriggeredEffect")


func test_factory_dispatch_replacement_effect() -> void:
	var factory: RefCounted = EffectFactoryClass.new()
	var tpl: Resource = EffectTemplateClass.new()
	tpl.type = EffectTemplateClass.EffectType.REPLACEMENT
	var inst: EffectBase = factory.create_instance(tpl, 42)
	assert_true(inst is ReplacementEffect, "REPLACEMENT 类型应分派为 ReplacementEffect")


func test_factory_copies_base_fields_from_template() -> void:
	var factory: RefCounted = EffectFactoryClass.new()
	var tpl: Resource = EffectTemplateClass.new()
	tpl.template_id = &"effect_damage_3"
	tpl.base_value = 3
	tpl.target_selector = &"enemy_front"
	tpl.conditions = [&"realm_ge_2"]

	var inst: EffectBase = factory.create_instance(tpl, 42)
	assert_eq(inst.template_id, &"effect_damage_3", "template_id 应复制")
	assert_eq(inst.base_value, 3, "base_value 应复制")
	assert_eq(inst.target_spec, &"enemy_front", "target_selector 应映射到 target_spec")
	assert_eq(inst.source_card_instance_id, 42, "source_card_instance_id 应复制")


func test_factory_null_template_returns_null() -> void:
	var factory: RefCounted = EffectFactoryClass.new()
	var inst: EffectBase = factory.create_instance(null, 42)
	assert_eq(inst, null, "null 模板应返回 null")


func test_factory_unknown_type_returns_null() -> void:
	var factory: RefCounted = EffectFactoryClass.new()
	var tpl: Resource = EffectTemplateClass.new()
	tpl.type = 99  # 非法枚举值——GDScript int→enum 运行时不做范围检查
	var inst: EffectBase = factory.create_instance(tpl, 42)
	assert_eq(inst, null, "未知效果类型应返回 null")


func test_factory_conditions_deep_copy_isolated_from_template() -> void:
	## ADR-0009 模板只读约束的核心防护点——实例修改 conditions 不得污染模板。
	var factory: RefCounted = EffectFactoryClass.new()
	var tpl: Resource = EffectTemplateClass.new()
	tpl.conditions = [&"realm_ge_2"]

	var inst: EffectBase = factory.create_instance(tpl, 42)
	inst.conditions.append(&"realm_ge_3")

	assert_eq(tpl.conditions.size(), 1, "模板 conditions 不应被实例修改污染")
	assert_eq(inst.conditions.size(), 2, "实例 conditions 应独立深拷贝")


# ============================================================================
# 4 子类专属字段存在性（对象模型完成定义的一部分）
# ============================================================================

func test_persistent_effect_exclusive_fields_defaults() -> void:
	var effect: RefCounted = PersistentEffectClass.new()
	assert_eq(effect.duration, 0, "duration 默认 0")
	assert_eq(effect.stacking_rule, &"", "stacking_rule 默认空")
	assert_eq(effect.max_stacks, 0, "max_stacks 默认 0")
	assert_eq(effect.cooldown, 0, "cooldown 默认 0")
	assert_eq(effect.binding_multiplier, 1.0, "binding_multiplier 默认 1.0")


func test_triggered_effect_exclusive_fields_defaults() -> void:
	var effect: RefCounted = TriggeredEffectClass.new()
	assert_eq(effect.trigger_event, &"", "trigger_event 默认空")
	assert_eq(effect.delay_turns, 0, "delay_turns 默认 0")
	assert_eq(effect.trigger_once, false, "trigger_once 默认 false")
	assert_eq(effect.max_triggers_per_turn, 0, "max_triggers_per_turn 默认 0")


func test_replacement_effect_exclusive_fields_defaults() -> void:
	var effect: RefCounted = ReplacementEffectClass.new()
	assert_eq(effect.replacement_priority, 0, "replacement_priority 默认 0")
