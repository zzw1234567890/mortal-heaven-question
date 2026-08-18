## BindingRecord —— 功法/法宝绑定运行时实例。
##
## RefCounted 运行时可变实例，持有绑定关系的全部字段。
## 通过 [code]BindingManager.get_binding(binding_id)[/code] 查询单条记录。
##
## [b]字段无 @export[/b]——BindingRecord 是纯运行时对象，非 Inspector 编辑的 .tres。
## 由 BindingManager 在 bind_card / stack_card / overwrite_binding 时创建并注册
## （Story 002 实现分配逻辑）。
##
## [b]非 Resource 引用[/b]（ADR-0013 L47）：实例持有 [member card_template_id] StringName
## 引用，而非 Resource——对齐 ADR-0006 CardInstance / ADR-0009 EffectInstance /
## ADR-0011 StatusInstance 的 Template/Instance 分离模式。
##
## 来源: ADR-0013 §对象模型 / GDD binding-system.md §1 绑定数据结构。
class_name BindingRecord
extends RefCounted

# === 枚举 ========================================================================

## 绑定位类型——功法（GONGFA）/ 法宝（FABAO）。
enum BindingSlot {
	GONGFA = 0,  ## 功法位
	FABAO = 1,   ## 法宝位
}


# === 实例标识 =====================================================================

## 绑定唯一标识——由 BindingManager 分配（Story 002 实现分配逻辑）。
var binding_id: int = 0

## 卡牌实例 ID——区分同名卡的不同副本。
var card_instance_id: int = 0

## 卡牌模板 ID——用于同名判定（StringName，非 Resource 引用）。
var card_template_id: StringName = &""

## 卡牌显示名称。
var card_name: String = ""

## 稀有度——[code]CardTemplate.Rarity[/code] 枚举值（1=白 2=蓝 3=紫 4=金 5=暗金）。
## 使用字面量 [code]int[/code] 而非 [code]CardTemplate.Rarity[/code] 引用——避免
## BindingRecord 类定义时依赖全局 class_name 注册时序（同 CardInstance.acquired_method
## 先例，ADR-0006 L155）。默认 0 表示未设置。
var card_rarity: int = 0

## 绑定位类型——功法/法宝。
var slot_type: BindingSlot = BindingSlot.GONGFA

## 绑定位索引——在角色绑定位数组中的索引。
var slot_index: int = 0

## 绑定的角色 ID。
var bound_character_id: int = 0


# === 本命加成 =====================================================================

## 是否激活本命加成——绑定时判定并锁定，运行时不变。
var is_native: bool = false

## 本命乘数——1.0 或 1.5（绑定时预计算，不运行时重查）。
var native_multiplier: float = 1.0


# === 生命周期 =====================================================================

## 绑定回合数——用于效果排序。
var activated_turn: int = 0

## 是否暂挂——角色离场时为 true，重新上场恢复。
var is_suspended: bool = false


# === 同名叠加 =====================================================================

## 同名卡叠层实例 ID 列表（含自身）。[code]stack_slots[0][/code] = 本实例，后续为叠加副本。
var stack_slots: Array[int] = []

## 同名卡已叠加张数（含本实例，≥1）。
var stack_count: int = 1
