## AcquiredMethod —— 卡牌获得来源枚举。
##
## 独立文件理由：AcquiredMethod 是卡牌独有概念，不应塞入 CardTemplate
## （CardTemplate 持有 CardType/Rarity 枚举，是模板层属性）。
## 独立 class_name 使其可被 CardInstance、InscriptionSystem、DeckEditingSystem
## 等多个系统导入，避免循环依赖。
##
## [b]0-based 枚举[/b]（DROP=0）——与 CardInstance.acquired_method 默认值 0 对齐
## （ADR-0006 L155）。区别于 Rarity 的 1-based（ResourceSystem 公式契约要求）。
## 默认值 0 = DROP = 最常见的获得方式（战斗掉落）。
class_name AcquiredMethod
extends RefCounted

# === 枚举 ========================================================================

## 卡牌获得来源——5 种之一。决定卡牌的故事来源追踪和后续系统行为。
## 0-based：DROP=0 与 CardInstance.acquired_method 默认值 0 一致。
enum {
	DROP = 0,        ## 战斗掉落——最常见的获得方式（默认值）
	SHOP = 1,        ## 商店购买
	EVENT = 2,       ## 事件奖励
	CRAFT = 3,       ## 炼制（丹药/符箓/法宝）
	TRIBULATION = 4, ## 渡劫奖励
}
