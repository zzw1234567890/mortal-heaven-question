class_name EventDefEffect
extends Resource
## EventDefEffect —— 探索事件选项的单个效果。
##
## 结算时由 [ExplorationEventSystem] 掷骰（[member use_range] 时取
## [member min_amount]~[member max_amount] 随机值，否则取 [member amount]），
## 再按 [member kind] 落库 GSM。[br]
## [br][b]四种 kind[/b]：[br]
##   - [code]LING_SHI[/code]：灵石——[member amount] 可正可负，写 GSM player.resources.ling_shi[br]
##   - [code]CULTIVATION[/code]：修为——[member amount] 写 GSM player.cultivation[br]
##   - [code]HP[/code]：生命——[member amount] 写 GSM player 角色血量（[member character_id] 指定角色）[br]
##   - [code]CARD[/code]：卡片——[member card_id] 指定卡牌模板，入 GSM 收藏[br]
## [br]来源: 探索事件节点需求。

# === 效果类型 =================================================================

@export_group("效果类型")
## 效果种类——枚举 [enum Kind]。
## 字符串与 [enum Kind] 保持同步（值 0-3，顺序不得重排）。
@export_enum("灵石:0", "修为:1", "生命:2", "卡片:3")
var kind: int = 0

# === 数值 =====================================================================

@export_group("数值")
## 精确值——[member use_range] = false 时使用。灵石/修为/生命可正可负；卡片忽略。
@export var amount: int = 0

## 是否使用随机范围。[code]true[/code] → 在 [member min_amount]~[member max_amount] 间随机。
@export var use_range: bool = false

## 随机范围下限（含）。仅 [member use_range] = true 时生效。
@export var min_amount: int = 0

## 随机范围上限（含）。仅 [member use_range] = true 时生效。
@export var max_amount: int = 0

# === 目标 =====================================================================

@export_group("目标")
## 卡牌模板 ID——仅 [code]CARD[/code] 使用（如 [code]"basic_attack"[/code]）。
@export var card_id: String = ""

## 角色 ID——仅 [code]HP[/code] 使用。[code]0[/code] = 全体角色（遍历 GSM
## [code]player.character_hp[/code] 全部条目）；[code]> 0[/code] = 指定角色。
@export var character_id: int = 0


# === 枚举 =====================================================================

## 效果种类枚举——[member kind] 的权威来源。
enum Kind {
	LING_SHI = 0,    ## 灵石——写 player.resources.ling_shi
	CULTIVATION = 1, ## 修为——写 player.cultivation
	HP = 2,          ## 生命——写角色血量
	CARD = 3,        ## 卡片——入收藏
}
