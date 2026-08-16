## EffectTemplate —— 卡牌效果模板 Resource。
##
## 存储在 [code]assets/cards/effects/[/code] 目录下作为 [code].tres[/code] 文件。
## 策划在 Godot 编辑器中通过 Inspector 可视化编辑所有字段。
## 运行时由 [EffectFactory] 读取，生成轻量级 [EffectBase] RefCounted 运行时实例。
##
## [b]模板只读约定[/b]（ADR-0009）：运行时不得写入 EffectTemplate 字段——
## Resource 共享引用语义导致静默数据损坏。所有可变状态在 EffectBase 子类上。
##
## 来源: ADR-0009 §双层对象模型。
class_name EffectTemplate
extends Resource

# === 枚举 ========================================================================

## 效果类型——4 种之一。决定运行时实例的子类与结算路径（TR-effect-001）。
enum EffectType {
	INSTANT = 0,      ## 即时——立即结算（伤害/治疗/抽牌/弃牌/费用修改）
	PERSISTENT = 1,   ## 持续——持续生效（功法/法宝/阵法/buff/debuff）
	TRIGGERED = 2,    ## 触发——条件触发（回合开始/攻击/击杀/延迟触发）
	REPLACEMENT = 3,  ## 替代——拦截修改（替代阵亡/效果增幅/效果无效化）
}


# === @export 字段 =================================================================

## 模板唯一标识。命名约定：{类型前缀}_{名称}_{变体}。
@export var template_id: StringName = &""

## 效果类型——决定运行时实例子类。
@export var type: EffectType = EffectType.INSTANT

## 基础数值——结算前未乘本命加成的原始数值。
@export var base_value: int = 0

## 目标选择器——TargetSpec 的字符串标识（目标选择规则细节属后续 story）。
@export var target_selector: StringName = &""

## 生效条件列表——元素结构由条件判定 story 定义，本 Story 仅声明容器。
@export var conditions: Array = []

## 播放动画 ID——结算时播放的表现层动画标识。
@export var animation_id: StringName = &""

## 描述模板——支持占位符（如 [code]造成 {value} 点伤害[/code]）。
@export var description_tmpl: String = ""
