## EventEnums —— 事件系统共享枚举定义。
##
## 此文件是以下枚举的权威来源：
## - EventType: 6 种事件类型（灵脉采掘/坊市交易/洞府奇遇/杀人夺宝/炼丹炼器/斜月三星洞）
## - ConditionType: 6 种条件类型（realm/faction/resource/card_owned/flag_set/flag_not_set）
## - ConditionOperator: 3 种比较运算符（GE/EQ/LT）
## - OutcomeType: 12 种结果类型——ADR-0003 决策，为 ADR-0009 卡牌效果引擎的共享词汇表权威来源。
##
## [b]用法[/b]：其他文件通过 [code]EventEnums.EventType.LING_MAI_CAIJUE[/code] 引用枚举值。
## @export 类型提示使用 [code]EventEnums.EventType[/code] 在 Inspector 中显示下拉菜单。
class_name EventEnums
extends Object


# === EventType：6 种事件类型 ======================================================

enum EventType {
	LING_MAI_CAIJUE = 0,   ## 灵脉采掘——安全 vs 贪婪
	FANG_SHI_JIAOYI = 1,   ## 坊市交易——消耗灵石购买物品
	DONG_FU_QIYU = 2,      ## 洞府奇遇——免费但互斥的宝物选择
	SHA_REN_DUO_BAO = 3,   ## 杀人夺宝——道德 vs 利益
	LIAN_DAN_LIAN_QI = 4,  ## 炼丹/炼器台——消耗资源炼制 vs 放弃
	XIE_YUE_SAN_XING = 5,  ## 斜月三星洞——隐藏奇遇（每图仅 1 次）
}


# === ConditionType：6 种条件类型 ==================================================

enum ConditionType {
	REALM = 0,        ## 境界 ≥/==/< value_int
	FACTION = 1,      ## 阵营 == value_str
	RESOURCE = 2,     ## 资源 ≥/==/< value_int
	CARD_OWNED = 3,   ## 拥有卡牌（按 template_id 匹配 value_str）
	FLAG_SET = 4,     ## story_flag key == value_str
	FLAG_NOT_SET = 5, ## story_flag key != value_str
}


# === ConditionOperator：3 种比较运算符 ============================================

enum ConditionOperator {
	GE = 0,  ## 大于等于 (>=)
	EQ = 1,  ## 等于 (==)
	LT = 2,  ## 小于 (<)
}


# === OutcomeType：12 种结果类型 ====================================================
##
## [b]⚠️ 权威来源[/b]：此枚举是 ADR-0003 决策的权威来源。
## ADR-0009（卡牌效果引擎）必须 [b]扩展[/b]（非复制）此枚举——在本文档中添加新值，
## 而非在 ADR-0009 中定义独立的枚举。
enum OutcomeType {
	ADD_RESOURCE = 0,    ## 添加资源——target=资源类型, value_int=数量
	ADD_CULTIVATION = 1, ## 添加修为——value_int=修为量
	ADD_CARD = 2,        ## 添加卡牌——通过 card_reward_requested 信号委托给 CardSystem
	REMOVE_CARD = 3,     ## 移除卡牌——target=卡牌实例 ID
	HEAL = 4,            ## 治疗——value_int=治疗量（战斗中）
	DAMAGE = 5,          ## 伤害——value_int=伤害量（战斗陷阱）
	SET_FLAG = 6,        ## 设置 story_flag——target=flag 键, value_str=flag 值
	GAIN_TALENT = 7,     ## 获得天赋——target=天赋 ID → GSM.progression
	TRIGGER_BATTLE = 8,  ## 触发战斗——target=敌方阵容 ID
	ADVANCE_CHAPTER = 9, ## 推进章节——target=章节 ID
	RESTORE_AP = 10,     ## 恢复行动力——value_int=行动力恢复量
	NOTHING = 11,        ## 无效果——纯叙事文本
}