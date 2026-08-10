## StatusInstance —— 状态效果运行时实例。
##
## RefCounted 运行时可变实例，持有 [member template_id] 引用到 StatusTemplate。
## 通过 [code]StatusEffectSystem.get_status_template(inst.template_id)[/code] 查询模板。
##
## [b]字段无 @export[/b]——StatusInstance 是纯运行时对象，非 Inspector 编辑的 .tres。
## 由 [code]StatusEffectSystem.apply_status()[/code] 创建并注册到内部注册表。
##
## 来源: ADR-0011 §双层对象模型。
class_name StatusInstance
extends RefCounted

# === 实例标识 =====================================================================

## 全局唯一实例 ID——由 StatusEffectSystem 单调递增分配。
var id: int = 0

## 指向 StatusTemplate.template_id——非 Resource 引用。
var template_id: StringName = &""

## 目标角色 ID——状态施加到的角色实例 ID。
var target_id: int = 0


# === 持续时间 =====================================================================

## 剩余回合数。-1 = 永久（不参与倒计时）。0 = 已过期待移除。
var duration: int = 0

## 施加时的回合数——用于同回合不倒计时判定（AC-012）。-1 = 未追踪。
var applied_turn: int = -1


# === 数值与叠加 ===================================================================

## 效果数值——已计算后的有效值（可能被 overrides 覆盖）。
var value: float = 0.0

## 原始基础值——从模板复制，用于刷新时重新计算。
var base_value: float = 0.0

## 当前层数（≥1）。叠加规则为 CUMULATIVE 时递增。
var current_stacks: int = 1


# === 来源与结算 ===================================================================

## 来源卡牌实例 ID——用于追溯和 remove_statuses_by_source。
var source_card_instance_id: int = 0

## 结算优先级——同机结算时的子优先级（从模板 default_priority 复制）。
var priority: int = 0


# === 运行时标记 ===================================================================

## 是否隐藏——true = 不显示在角色头顶（用于内部标记状态）。
var is_hidden: bool = false

## 是否已过期——true = 已到期待移除（由 tick_all 标记，remove_expired 移除）。
var is_expired: bool = false

## 扩展数据——从模板 metadata 深拷贝，运行时可修改。
var metadata: Dictionary = {}
