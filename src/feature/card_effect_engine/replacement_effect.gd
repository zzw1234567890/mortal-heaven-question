## ReplacementEffect —— 替代效果运行时实例。
##
## 拦截修改（替代阵亡/效果增幅/效果无效化）。
## 结算逻辑属 Story 002，本 Story 仅声明对象模型并 override [method _resolve]。
##
## 来源: ADR-0009 §4 个 RefCounted 子类。
class_name ReplacementEffect
extends EffectBase

# === 替代效果专属字段 ============================================================

## 替代优先级——拦截修改时的决胜键（越大越先拦截）。
var replacement_priority: int = 0


## 结算效果——Story 002 实现。本 Story 占位空实现。
func _resolve() -> void:
	pass
