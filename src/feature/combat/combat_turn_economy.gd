extends RefCounted
## CombatTurnEconomy —— 回合经济规则（抽牌 / 开局手牌 / 手牌上限——纯函数）。
##
## [b]职责[/b]：把 GDD 里「每回合抽几张、开局发几张、手牌超限弃几张」这三种
## 数字口径集中到一处——此前散落在 [code]combat_phase_manager.gd[/code] 的桩实现里
## （恒返 2），后手补偿与开局手牌根本没接。[br]
## [br][b]为什么独立成文件[/b]：这些规则是纯映射（输入回合上下文 → 输出张数），
## 与阶段编排无关；独立后单元测试零依赖，阶段侧只负责「在正确的时机调用」。[br]
## [br][b]纯函数[/b]（ADR-0031 Logic 内核模式）：无状态、无副作用、确定映射。[br]
##
## 来源: design/gdd/combat-system.md §2 抽牌规则 / §3 费用规则、
## design/gdd/card-system.md §手牌限制、combat-ui-interaction Story 002。

## 先手第 1 回合抽牌数——0（使用开局手牌）。
const DRAW_FIRST_PLAYER_TURN_1: int = 0
## 后手第 1 回合抽牌数——3（补偿后手劣势）。
const DRAW_SECOND_PLAYER_TURN_1: int = 3
## 每回合基础抽牌数（第 2 回合起，双方一致）。
const DRAW_BASE: int = 2

## 开局手牌张数——先手。
const OPENING_HAND_FIRST: int = 4
## 开局手牌张数——后手。
const OPENING_HAND_SECOND: int = 5

## 手牌上限（GDD card-system.md §手牌限制：超限需弃至 10 张）。
const HAND_LIMIT: int = 10


## 本回合抽牌数（GDD §2 抽牌规则表）。[br]
## [br]第 1 回合按先后手分岔，第 2 回合起一律 [constant DRAW_BASE]。[br]
## [param p_turn] 回合编号（从 1 开始；[code]<= 1[/code] 一律按第 1 回合处理——
## 桩环境里 turn 可能尚未落定，按第 1 回合从严比按基础值宽松更安全）。[br]
static func draw_count(p_is_first_player: bool, p_turn: int) -> int:
	if p_turn <= 1:
		return DRAW_FIRST_PLAYER_TURN_1 if p_is_first_player \
				else DRAW_SECOND_PLAYER_TURN_1
	return DRAW_BASE


## 开局手牌张数（GDD §2：先手 4 / 后手 5）。
static func opening_hand_size(p_is_first_player: bool) -> int:
	return OPENING_HAND_FIRST if p_is_first_player else OPENING_HAND_SECOND


## 回合结束时需弃置的张数（未超限为 0）。[br]
## [br][param p_hand_size] 当前手牌张数。[param p_limit] 上限（默认
## [constant HAND_LIMIT]——留参数只为测试能收紧边界，生产恒用默认）。[br]
static func hand_overflow(p_hand_size: int, p_limit: int = HAND_LIMIT) -> int:
	return maxi(p_hand_size - p_limit, 0)


## 从开战 config 读先手标志。[br]
## [br][b]缺省 true[/b]：既有调用方（渡劫 / 测试桩）不带该键，缺省先手意味着
## 「全额费用、第 1 回合不抽牌」——与改造前的硬编码口径逐位一致，不产生行为漂移。
## 后手方须显式声明 [code]is_first_player: false[/code]。[br]
## [br][b]非布尔值按先手处理[/b]：读到字符串 / null 时不猜「谁是后手」
## （猜错会让一方白拿 +1 费与 3 张牌）。
static func is_first_player(p_config: Dictionary) -> bool:
	var raw: Variant = p_config.get("is_first_player", true)
	return bool(raw) if raw is bool else true
