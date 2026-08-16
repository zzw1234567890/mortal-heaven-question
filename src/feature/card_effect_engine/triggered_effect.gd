## TriggeredEffect —— 触发式效果运行时实例。
##
## 条件触发（回合开始/攻击/击杀/延迟触发）。
## 结算逻辑属 Story 002/003，本 Story 仅声明对象模型并 override [method _resolve]。
##
## 来源: ADR-0009 §4 个 RefCounted 子类。
class_name TriggeredEffect
extends EffectBase

# === 触发式效果专属字段 ==========================================================

## 触发事件标识——回合开始/攻击/击杀/延迟触发等。
var trigger_event: StringName = &""

## 延迟回合数——触发条件满足后延迟 N 回合生效。
var delay_turns: int = 0

## 是否仅触发一次。
var trigger_once: bool = false

## 每回合最大触发次数。0 表示无限制。
var max_triggers_per_turn: int = 0


## 结算效果——Story 002 实现。本 Story 占位空实现。
func _resolve() -> void:
	pass
