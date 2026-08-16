## EffectFactory —— EffectTemplate → EffectBase 运行时实例工厂。
##
## 本 Story 工厂接受 [EffectTemplate] 直接构造对应子类实例，
## 不依赖 CardSystem 模板注册表（软依赖——见 Story 001 §Dependencies）。
## 工厂是模板（Resource）与运行时实例（RefCounted）之间的唯一桥梁（ADR-0009 L55）。
##
## 来源: ADR-0009 §双层对象模型 / Implementation Notes #5。
class_name EffectFactory
extends RefCounted


## 从模板创建运行时效果实例。[br]
## [br][b]分派[/b]：按 [member EffectTemplate.type] 构造对应子类。[br]
## [br][param template] 效果模板（只读）。[br]
## [br][param source_card_instance_id] 来源卡牌实例 ID（追溯用）。[br]
## [br][b]返回[/b]: [EffectBase] 子类实例；null 模板或未知 type 返回 [code]null[/code] + push_error。
func create_instance(template: EffectTemplate, source_card_instance_id: int) -> EffectBase:
	if template == null:
		push_error("EffectFactory.create_instance: template 不能为 null")
		return null

	var instance: EffectBase = null
	match template.type:
		EffectTemplate.EffectType.INSTANT:
			instance = InstantEffect.new()
		EffectTemplate.EffectType.PERSISTENT:
			instance = PersistentEffect.new()
		EffectTemplate.EffectType.TRIGGERED:
			instance = TriggeredEffect.new()
		EffectTemplate.EffectType.REPLACEMENT:
			instance = ReplacementEffect.new()
		_:
			push_error("EffectFactory.create_instance: 未知效果类型 %d" % template.type)
			return null

	_populate_base(instance, template, source_card_instance_id)
	return instance


## 填充基类字段——从模板复制到实例（不持有 Resource 引用）。[br]
## [br]子类专属字段（duration/stacking_rule/trigger_event 等）不在本 Story 从模板复制——
## 由 BindingSystem（ADR-0013）或后续 story 填充。
func _populate_base(instance: EffectBase, template: EffectTemplate, source_card_instance_id: int) -> void:
	instance.template_id = template.template_id
	instance.base_value = template.base_value
	instance.target_spec = template.target_selector
	instance.conditions = template.conditions.duplicate(true)
	instance.source_card_instance_id = source_card_instance_id
