## InstantEffect —— 即时效果运行时实例。
##
## 立即结算（伤害/治疗/抽牌/弃牌/费用修改/移除状态/临时属性）。
## 无额外字段——结算逻辑属 Story 002，本 Story 仅声明对象模型并 override [method _resolve]。
##
## 来源: ADR-0009 §4 个 RefCounted 子类。
class_name InstantEffect
extends EffectBase


## 结算效果——Story 002 实现。本 Story 占位空实现。
func _resolve() -> void:
	pass
