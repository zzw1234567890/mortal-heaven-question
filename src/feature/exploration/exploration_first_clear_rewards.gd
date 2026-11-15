extends RefCounted
## ExplorationFirstClearRewards —— 首通额外奖励表（按地图难度档）。[br]
## [br][b]为什么单独一处[/b]：[code]exploration_map_catalog.gd[/code] 已贴 300 行软
## 上限（.claude/docs/coding-standards.md），而 17 张地图各写一条
## [code]first_clear_reward[/code] 会再多出十几行。首通档位本来就只随难度变化
## （GDD exploration-system.md §5「通关奖励按地图难度档给」），故单独成表、
## 由 [code]config_for[/code] 按难度档注入——新增地图不必再抄一遍奖励。[br]
## [br][b]首通与重复通关的分界[/b]（GDD exploration-ui-system.md §7）：[br]
##   · [b]首通[/b]——基础奖励（[code]CLEAR_REWARDS[/code]）[b]加[/b]本表这一份，
##     含灵石 / 修为 / 卡牌；[br]
##   · [b]重复通关[/b]——只有基础奖励，[b]不发卡牌[/b]。稀有度是稀缺性来源，
##     重复刷图能无限取卡会让「首通」失去意义（故本表的 [code]cards[/code]
##     是首通专属，不是每次通关的固定产出）。[br]
## [br][b]卡牌 ID 的稀有度递进[/b]：白 → 蓝 → 紫 → 金（1→4 档），与
## [code]CLEAR_REWARDS[/code] 的档位顺序同向——难度越高，首通彩头越硬。[br]
## [br][b]不改写卡牌定义[/b]：本表只引用 [code]assets/cards/templates/[/code] 里
## 既有模板的 ID，稀有度与类型仍以模板为准（同一事实不出现两个来源）。[br]
##
## 来源: design/gdd/exploration-system.md §5 地图通关奖励、
## design/gdd/exploration-ui-system.md §7 地图通关结算、ADR-0014 §决策 5。

## 首通额外奖励——按 [code]ExplorationSystem.MapDifficulty[/code] 枚举索引
## （LOW / MEDIUM / HIGH / VERY_HIGH）。[br]
## [br]每条含 [code]ling_shi[/code] / [code]cultivation[/code] / [code]cards[/code]
## 三键；[code]cards[/code] 条目用发放器认的 [code]{card_id}[/code] 写法。
const BY_DIFFICULTY: Array = [
	{  # LOW——青云剑宗 / 苍玄正道盟
		"ling_shi": 50, "cultivation": 30,
		"cards": [{"card_id": "pei_yuan_dan"}],
	},
	{  # MEDIUM——血渊秘境 / 苍玄古战场
		"ling_shi": 100, "cultivation": 60,
		"cards": [{"card_id": "pill_hui_chun_dan"}],
	},
	{  # HIGH——云澜城 / 丹霞谷
		"ling_shi": 200, "cultivation": 100,
		"cards": [{"card_id": "pill_yu_ling_dan"}],
	},
	{  # VERY_HIGH——归墟一线
		"ling_shi": 300, "cultivation": 150,
		"cards": [{"card_id": "artifact_shang_pin_fa_qi"}],
	},
]


## 取某难度档的首通额外奖励（副本——调用方可能合并进别的字典）。[br]
## [br][param p_difficulty] [code]MapDifficulty[/code] 枚举值；越界按 MEDIUM 处理
## （与 [code]ExplorationMapCatalog._difficulty_defaults[/code] 的兜底同口径——
## 配置写错不该让地图生成崩掉）。[br]
## [br][b]返回[/b]：深拷贝的 [code]{ling_shi, cultivation, cards}[/code]。
static func for_difficulty(p_difficulty: int) -> Dictionary:
	var index: int = p_difficulty
	if index < 0 or index >= BY_DIFFICULTY.size():
		index = 1
	return (BY_DIFFICULTY[index] as Dictionary).duplicate(true)
