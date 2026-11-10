class_name CombatTargetPolicy
extends RefCounted
## CombatTargetPolicy —— 卡面 [code]target_type[/code] → 目标选择策略的纯映射
## （combat-ui-interaction 001 / 本轮：多目标词表接卡面）。
##
## [b]职责[/b]：把卡牌模板里的 [code]target_type[/code] 字符串翻译成交互层能执行
## 的策略——[br]
##   - [b]单体[/b]（[code]single_enemy[/code] / [code]single_ally[/code]）：玩家点一个
##     目标即出牌，再点另一个会[b]替换[/b]上一个（不是累加）；[br]
##   - [b]全体[/b]（[code]all_enemy[/code] / [code]all_ally[/code]）：目标由系统自动
##     填满，玩家不必点（GDD card-effect-engine §目标选择「全体自动选择」）；[br]
##   - [b]自身[/b]（[code]self[/code]）：无目标可选，出牌即生效（治疗/护盾类）；[br]
##   - [b]多选[/b]（[code]multi_enemy[/code] / [code]multi_ally[/code]）：玩家依次点选，
##     再点同一目标取消，点卡牌确认；[br]
##   - [b]未知[/b]（空串 / 未收录词）：保持旧行为——允许任意目标列表，由默认策略
##     或玩家显式选择决定，[b]不因词表没收录就把卡锁死[/b]。
## [br][b]为什么独立成纯函数[/b]：[code]target_type[/code] 是资产数据，交互层不能把
## 词表写死在控制器里；数据新增一个词只需在本文件补一行映射（有测试锁白名单）。
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、确定映射。
##
## @experimental
## 来源: ADR-0031、design/gdd/card-effect-engine.md §5 目标选择规则、
## design/gdd/combat-ui-system.md §出牌目标选择、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md。

## 选择模式——交互层只看模式，不看具体词。
const MODE_ANY: int = 0    ## 未知词——旧行为（允许任意目标列表）
const MODE_SELF: int = 1   ## 自身——无目标，出牌即生效
const MODE_AUTO_ALL: int = 2 ## 全体——系统自动填满目标
const MODE_SINGLE: int = 3 ## 单体——点一个目标即确认
const MODE_MULTI: int = 4  ## 多选——依次点选，点卡牌确认

## 已收录词表——单一真理来源（测试锁「新词必须归类」）。
const TYPE_SELF: StringName = &"self"
const TYPE_SINGLE_ENEMY: StringName = &"single_enemy"
const TYPE_SINGLE_ALLY: StringName = &"single_ally"
const TYPE_ALL_ENEMY: StringName = &"all_enemy"
const TYPE_ALL_ALLY: StringName = &"all_ally"
const TYPE_MULTI_ENEMY: StringName = &"multi_enemy"
const TYPE_MULTI_ALLY: StringName = &"multi_ally"

## 词表映射——同义词收敛到标准词（资产里历史写法不统一，收敛只在本处做一次）。
const _ALIASES: Dictionary = {
	&"enemy": TYPE_SINGLE_ENEMY,
	&"single_target": TYPE_SINGLE_ENEMY,
	&"ally": TYPE_SINGLE_ALLY,
	&"all_enemies": TYPE_ALL_ENEMY,
	&"aoe_enemy": TYPE_ALL_ENEMY,
	&"all_allies": TYPE_ALL_ALLY,
	&"aoe_ally": TYPE_ALL_ALLY,
	&"multi_target": TYPE_MULTI_ENEMY,
	&"random_enemy": &"",       # 系统随机——UI 不选，落回未知（默认策略）
	&"lowest_hp_enemy": &"",    # 条件选择——系统侧决定
	&"highest_atk_enemy": &"",
}

## 词语 → 模式（未收录一律 MODE_ANY）。
const _MODES: Dictionary = {
	TYPE_SELF: MODE_SELF,
	TYPE_ALL_ENEMY: MODE_AUTO_ALL,
	TYPE_ALL_ALLY: MODE_AUTO_ALL,
	TYPE_SINGLE_ENEMY: MODE_SINGLE,
	TYPE_SINGLE_ALLY: MODE_SINGLE,
	TYPE_MULTI_ENEMY: MODE_MULTI,
	TYPE_MULTI_ALLY: MODE_MULTI,
}


## 规范化目标类型——去空白、同义词收敛；未知保持原样（便于日志定位）。
static func normalize(p_target_type: Variant) -> StringName:
	var raw: StringName = StringName(str(p_target_type).strip_edges())
	return _ALIASES.get(raw, raw)


## 目标类型 → 选择模式。
static func mode_of(p_target_type: Variant) -> int:
	var key: StringName = normalize(p_target_type)
	if key == &"":
		return MODE_ANY
	return int(_MODES.get(key, MODE_ANY))


## 是否需要玩家亲手点目标（单体 + 多选；全体/自身/未知都不强制）。
static func needs_player_target(p_target_type: Variant) -> bool:
	var mode: int = mode_of(p_target_type)
	return mode == MODE_SINGLE or mode == MODE_MULTI


## 允许持有多个目标（多选 + 未知词——未知词保持旧行为）。
static func allows_multiple(p_target_type: Variant) -> bool:
	var mode: int = mode_of(p_target_type)
	return mode == MODE_MULTI or mode == MODE_ANY


## 未指定目标时是否由系统填满（全体敌方 / 全体己方）。
static func fills_all(p_target_type: Variant) -> bool:
	return mode_of(p_target_type) == MODE_AUTO_ALL


## 面向玩家的策略提示（空串 = 无提示——避免无意义文案）。
static func describe(p_target_type: Variant) -> String:
	match mode_of(p_target_type):
		MODE_SELF:
			return "自身"
		MODE_AUTO_ALL:
			return "全体"
		MODE_SINGLE:
			return "单体"
		MODE_MULTI:
			return "多选"
	return ""
