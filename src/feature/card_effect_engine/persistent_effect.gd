## PersistentEffect —— 持续效果运行时实例。
##
## 持续生效（功法/法宝/阵法/buff/debuff）。
## 结算逻辑属 Story 002，本 Story 仅声明对象模型并 override [method _resolve]。
##
## 来源: ADR-0009 §4 个 RefCounted 子类。
class_name PersistentEffect
extends EffectBase

# === 持续效果专属字段 ============================================================

## 持续回合数。-1 = 永久。
var duration: int = 0

## 叠加规则标识——同名叠加逻辑属 binding-system（ADR-0013）职责。
var stacking_rule: StringName = &""

## 叠加上限——仅叠加规则为"叠加上限"时生效。0 表示不叠加。
var max_stacks: int = 0

## 冷却回合数。
var cooldown: int = 0

## 本命加成乘数——绑定时由 BindingSystem 预计算锁定（1.0 或 1.5）。
## 非本命默认 1.0（AC-004）。
var binding_multiplier: float = 1.0


## 结算效果——Story 002 实现。本 Story 占位空实现。
func _resolve() -> void:
	pass
