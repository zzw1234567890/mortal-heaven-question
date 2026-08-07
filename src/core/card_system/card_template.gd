## CardTemplate —— 卡牌模板 Resource。
##
## 存储在 [code]assets/cards/templates/[/code] 目录下作为 [code].tres[/code] 文件。
## CardSystem._ready() 时通过 ResourceLoader 批量加载到模板注册表。
## 策划在 Godot 编辑器中可通过 Inspector 可视化编辑所有字段。
##
## [b]模板只读约定[/b]（ADR-0006）：运行时不得写入 CardTemplate 字段——
## Resource 共享引用语义导致静默数据损坏。所有可变状态在 CardInstance 上。
## 运行时写入保护由 Story 003 实现。
##
## [b]类型专属字段[/b]：所有类型专属字段声明在同一类中——
## 按 [member type] 条件可空，非该类型的字段保持默认值。
class_name CardTemplate
extends Resource

# === 枚举 ========================================================================

## 卡牌类型——6 种之一。决定此模板的字段语义和下游系统行为。
enum CardType {
	CHARACTER = 0,   ## 角色卡——上场战斗单位
	TECHNIQUE = 1,   ## 功法卡——绑定到角色提供效果
	ARTIFACT = 2,    ## 法宝卡——装备到角色提供效果
	FORMATION = 3,   ## 阵法卡——场上部署提供光环
	PILL = 4,        ## 丹药卡——一次性消耗品
	TALISMAN = 5,    ## 符箓卡——一次性消耗品
}

## 稀有度——5 级之一。决定升级上限、拆解产出、掉落权重。
## [b]1-based 枚举[/b]——与 ResourceSystem 公式契约一致：
## [code]dismantle_value(rarity, level)[/code] 使用 [code]DISMANTLE_BASE[rarity - 1][/code] 索引。
## GDD resource-system.md §公式 1: rarity=1=白, 2=蓝, 3=紫, 4=金, 5=暗金。
enum Rarity {
	WHITE = 1,       ## 白色·凡器
	BLUE = 2,        ## 蓝色·法器
	PURPLE = 3,      ## 紫色·灵器
	GOLD = 4,        ## 金色·法宝
	DARK_GOLD = 5,   ## 暗金·通天灵宝
}


# === 共有字段 ====================================================================

@export_group("共有字段")
## 模板唯一标识。命名约定：{type_prefix}_{name}_{variant}，例如 [code]"char_lin_yuan_base_01"[/code]。
@export var card_id: StringName = &""

## 卡牌名称——显示在卡牌顶部。
@export var name: String = ""

## 卡牌类型——决定此模板使用哪些类型专属字段。
@export var type: CardType = CardType.CHARACTER

## 稀有度——决定升级上限、拆解产出、掉落权重。
@export var rarity: Rarity = Rarity.WHITE

## 灵力消耗——打出此卡的费用。
@export var cost: int = 0

## 阵营标签——最多 3 个。用于阵法触发判定和流派检测。
## 上限校验由 CardSystem 注册表负责（Story 003）。
@export var faction_tags: Array[StringName] = []

## 规则描述文本——显示在卡牌正文。
@export var description: String = ""

## 背景叙述文本——世界观层描述。
@export var flavor_text: String = ""

## 插画资源路径。空字符串表示暂无插画——运行时使用类型默认占位图。
@export var illustration_path: String = ""


# === 角色卡专属字段 ===============================================================

@export_group("角色卡专属")
## 基础生命值。
@export var base_hp: int = 0

## 基础攻击力。
@export var base_attack: int = 0

## 原生天赋效果 ID——引用 card-effect-engine 的效果类型。
@export var innate_skill: StringName = &""

## 功法槽位数——默认 3。
@export var technique_slots: int = 3

## 法宝槽位数——默认 3。
@export var artifact_slots: int = 3


# === 功法/法宝卡专属字段 ==========================================================

@export_group("功法/法宝卡专属")
## 效果类型——引用 card-effect-engine 的效果类型。
@export var effect_type: StringName = &""

## 效果数值。
@export var effect_value: int = 0

## 本命角色 card_id 前缀——匹配时触发本命加成 ×1.5。
@export var native_owner: StringName = &""

## 同名叠加张数上限——默认 3。
@export var stack_limit: int = 3

## 每层叠加乘数——默认 1.5。
@export var stack_multiplier: float = 1.5

## 触发条件（法宝卡专属）。
@export var trigger_condition: StringName = &""

## 冷却回合数（法宝卡专属）。
@export var cooldown: int = 0


# === 阵法卡专属字段 ===============================================================

@export_group("阵法卡专属")
## 所需阵营——阵法激活的阵营条件。
@export var faction_requirement: StringName = &""

## 所需阵营角色数。
@export var required_count: int = 0

## 光环效果 ID——引用 card-effect-engine 的效果类型。
@export var aura_effect: StringName = &""


# === 丹药/符箓卡专属字段 ==========================================================

@export_group("丹药/符箓卡专属")
## 持续回合数（丹药卡专属）。
@export var duration_turns: int = 0

## 目标类型（符箓卡专属）。
@export var target_type: StringName = &""

## 基础失败率（符箓卡专属）。
@export var base_fail_chance: float = 0.0
