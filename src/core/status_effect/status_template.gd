## StatusTemplate —— 状态效果模板 Resource。
##
## 存储在 [code]assets/statuses/[/code] 目录下作为 [code].tres[/code] 文件。
## StatusEffectSystem._ready() 时批量加载到模板注册表。
## 策划在 Godot 编辑器中可通过 Inspector 可视化编辑所有字段。
##
## [b]模板只读约定[/b]（ADR-0011）：运行时不得写入 StatusTemplate 字段——
## Resource 共享引用语义导致静默数据损坏。所有可变状态在 StatusInstance 上。
##
## 来源: ADR-0011 §双层对象模型。
class_name StatusTemplate
extends Resource

# === 枚举 ========================================================================

## 状态类型——3 种之一。用于免疫判定（类型免疫）和 UI 分类显示。
enum StatusType {
	BUFF = 0,      ## 增益——正面状态
	DEBUFF = 1,    ## 减益——负面状态
	SPECIAL = 2,   ## 特殊——机制标记（如冰冻、眩晕）
}

## 叠加规则——3 种之一。决定同名状态施加时的行为。
enum StackRule {
	INDEPENDENT = 0,  ## 独立——每次施加创建独立实例
	REFRESH = 1,      ## 刷新——同名状态刷新 duration，取 max(旧, 新)
	CUMULATIVE = 2,   ## 叠加上限——层数+1 直至 max_stacks
}


# === @export 字段 =================================================================

## 模板唯一标识。命名约定：{name}_{value}，例如 [code]"poison_3"[/code]、[code]"freeze_1"[/code]。
@export var template_id: StringName = &""

## 状态类型——用于免疫判定和 UI 分类。
@export var type: StatusType = StatusType.DEBUFF

## 叠加规则——决定同名状态施加时的行为。
@export var stack_rule: StackRule = StackRule.REFRESH

## 叠加上限——仅 [member stack_rule = CUMULATIVE] 时生效。默认 0 表示不使用叠加。
@export var max_stacks: int = 0

## 基础持续回合数。-1 = 永久（持续到战斗结束或手动移除）。
@export var base_duration: int = 0

## 基础数值——单层的效果数值（如中毒每回合伤害、攻击力加成值）。
@export var base_value: float = 0.0

## UI 图标资源路径。空字符串表示暂无图标。
@export var icon_path: String = ""

## 描述模板——支持占位符（如 [code]{value} 回合中毒[/code]）。
@export var description_tmpl: String = ""

## 默认优先级——同机结算时的子优先级（越大越先结算）。默认 0。
@export var default_priority: int = 0

## 扩展数据。标准键：[code]"damage_type"[/code]（元素属性）、[code]"stat_affected"[/code]（受影响属性）。
@export var metadata: Dictionary = {}
