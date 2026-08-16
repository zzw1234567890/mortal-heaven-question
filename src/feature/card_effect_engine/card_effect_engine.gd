extends Node
# class_name CardEffectEngine —— 不声明：Autoload 全局单例，
# 声明 class_name 会与全局名冲突（同 GSM/StatusEffectSystem/ResourceSystem 先例）。

## CardEffectEngine —— 卡牌效果解析引擎 Autoload（#10）。
##
## Feature 层 Autoload。采用双层对象模型——EffectTemplate（Resource, .tres, 只读）+
## EffectBase 运行时实例（RefCounted 子类层级）。
## 本 Story 仅声明 5 个 Cat 2b 生命周期信号——发射细节属 Story 002/003。
##
## [b]本 Story 不注册进 project.godot[/b]——待结算引擎（002）就绪后再注册。
## [b]信号路由[/b]（ADR-0007 合规）：Cat 2b 信号发射时经 GSM._emit_signal_safe 路由
## （本 Story 仅声明，不发射）。
##
## 来源: ADR-0009 §信号路由。

# === 信号声明（Cat 2b）============================================================

## 效果注册到角色时发射（Story 002/003 发射）。[br]
## [br][b]payload 结构[/b]: [code]{card_instance_id: int, effect_ids: Array[int], target_id: int}[/code]
signal effect_registered(payload: Dictionary)

## 效果从角色移除时发射。[br]
## [br][b]payload 结构[/b]: [code]{card_instance_id: int, effect_ids: Array[int], target_id: int, reason: String}[/code]
signal effect_removed(payload: Dictionary)

## 效果暂挂时发射（角色离场）。[br]
## [br][b]payload 结构[/b]: [code]{card_instance_id: int, effect_ids: Array[int], reason: String}[/code]
signal effect_suspended(payload: Dictionary)

## 效果恢复时发射（角色重新上场）。[br]
## [br][b]payload 结构[/b]: [code]{card_instance_id: int, effect_ids: Array[int]}[/code]
signal effect_restored(payload: Dictionary)

## 触发链栈溢出警告时发射（深度超限）。[br]
## [br][b]payload 结构[/b]: [code]{root_card_id: int, depth: int, chain: Array[int]}[/code]
signal stack_overflow_warning(payload: Dictionary)
