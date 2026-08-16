## EffectBase —— 卡牌效果运行时基类（抽象）。
##
## [b]@abstract[/b]（Godot 4.5+）：本类不可实例化——强制 4 个子类实现 [method _resolve]。
## 运行时轻量级 RefCounted 实例，由 [EffectFactory] 从 [EffectTemplate] 创建。
##
## [b]不持有 Resource 引用[/b]（ADR-0009 L98）：实例持有 [member template_id]
## StringName 引用，而非 Resource——避免共享引用污染
## （模式与 ADR-0006 Template/Instance 分离一致）。
##
## [b]字段无 @export[/b]——EffectBase 是纯运行时对象，非 Inspector 编辑的 .tres。
##
## 来源: ADR-0009 §双层对象模型。
@abstract
class_name EffectBase
extends RefCounted

# === 运行时最小字段集 ============================================================

## 指向 EffectTemplate.template_id——非 Resource 引用。
var template_id: StringName = &""

## 基础数值——从模板 base_value 复制。
var base_value: int = 0

## 目标规格——TargetSpec 字符串标识（目标选择规则细节属后续 story）。
var target_spec: StringName = &""

## 生效条件列表——从模板 conditions 深拷贝，实例可独立修改。
var conditions: Array = []

## 来源卡牌实例 ID——追溯效果来源。
var source_card_instance_id: int = 0

## 激活顺序——结算主排序键之一（5 级优先级内次级决胜）。
var activation_sequence: int = 0

## 结算优先级——同主排序层级内的次级决胜键（越大越先结算）。
var priority: int = 0


# === 抽象方法 ====================================================================

## 结算效果——子类必须 override。[br]
## [b]抽象方法无函数体[/b]——结算逻辑属 Story 002（ResolutionStack）。
@abstract
func _resolve() -> void


# === 公共方法 ====================================================================

## 计算有效值——[code]floor(base_value × binding_multiplier)[/code]。[br]
## [br][b]向下取整[/b]（ADR-0009 L57）：[code]floor(3 × 1.5) = floor(4.5) = 4[/code]。[br]
## [br][param binding_multiplier] 本命加成乘数——由 BindingSystem 在绑定时预计算锁定
## （1.0 或 1.5），效果引擎查询而非运行时重算。默认 1.0（非本命）。[br]
## [br][b]返回[/b]: 向下取整后的有效值 [code]int[/code]。
func get_effective_value(binding_multiplier: float = 1.0) -> int:
	return floori(base_value * binding_multiplier)
