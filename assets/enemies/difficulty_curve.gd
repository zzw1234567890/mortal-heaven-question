class_name DifficultyCurve
extends RefCounted
## DifficultyCurve —— 敌方属性难度系数表（纯函数；全库唯一的缩放系数来源）。[br]
## [br][b]为什么需要[/b]：此前敌方 HP/ATK 只有一条「追赶」公式
## （[code]1 + (玩家境界 − 模板境界) × 0.3[/code]），而四个出厂敌人模板的境界恒为
## 1~2——[b]地图的 [code]enemy_realm[/code] 对战斗数值零影响[/b]。结果是
## 「炼气玩家打归墟」与「炼气玩家打青云剑宗」面对同样强度的散修，地图境界档
## 只体现在敌人数量与掉落上（DEBT-EQT-001）。[br]
## [br][b]两条轴[/b]（都只在本文件里写系数）：[br]
##   · [b]追赶轴[/b][method catch_up_of]——玩家境界高于模板基准时敌人按档追平
##     （GDD ai-system.md §9，保留既有 1.3/级 的口径与数值，出厂测试锁定）；[br]
##   · [b]档位轴[/b][method tier_of]——[code]地图境界档 − 玩家境界[/code] 给
##     HP/ATK 乘系数：玩家落后一档明显吃力、追平为基线、压级轻松。[br]
## [br][b]同时只用一条轴[/b]（[method multipliers_of]）：给了地图档就只走档位轴，
## 没给（渡劫 / 无探索上下文）才走追赶轴。[b]不叠加[/b]——地图档本身就是「这张图
## 该有多强」的基准，玩家相对它的位置已由 [code]gap[/code] 表达（玩家练得越高
## gap 越负）。两条都乘会重复计算：元婴玩家进元婴图时追赶轴按模板境界再加 ×1.6，
## 而档位轴说 gap=0——变成「玩家越接近这张图的境界，敌人被堆得越厚」，
## 与「追平后 3~5 回合能赢」正好相反（本轮实测发现并修掉）。[br]
## [br][b]档位表的锚点[/b]：[code]gap == 0 → ×1.0[/code] 是[b]必须是 1.0[/b] 的
## 基线——既有端到端用例按模板原值断言第一张图的敌方 HP（san_xiu 16），改动它会
## 让「同境界」这条锚点失去参照。追平后的战斗节奏（3~5 回合）由测试实测锁定，
## 不靠调基线实现。[br]
## [br][b]夹下限[/b]：属性是整数，缩放在乘完之后取整并夹到
## [constant MIN_ENEMY_HP] / [constant MIN_ENEMY_ATK]——压级系数再低也不产出
## 「0 血敌人」（那会让战斗永不结束）。[br]
## [br][b]未定档不缩放[/b]：[code]map_realm <= 0[/code]（渡劫 / 无探索上下文的
## 开战路径）时档位系数恒 1.0，只有追赶轴生效——与改造前的行为逐位一致。[br]
##
## 来源: GDD ai-system.md §9 难度缩放 / §调优参数「难度缩放系数/级」、
## GDD exploration-system.md §7 回旧地图、DEBT-EQT-001。

## 追赶系数——玩家每高出模板基准一档，敌人属性 +30%（GDD §9 既有口径）。[br]
## 出厂敌人模板境界恒为 1~2，故这条轴承担「玩家练到哪里，敌人跟到哪里」。
const CATCH_UP_PER_REALM: float = 0.3

## 档位系数表——键为 [code]地图境界档 − 玩家境界[/code]（夹到
## [constant TIER_MIN_GAP] ~ [constant TIER_MAX_GAP]）。[br]
## [br][code]hp[/code] / [code]atk[/code] 是乘数；[code]label[/code] 是该档的
## 中文档位名（调试 / 战报文案与测试断言共用，不另立词表）。[br]
## [br][b]为什么防御跟着 HP 走[/b]：出厂模板的 [code]base_defense[/code] 多为 0~2，
## 单列一列系数只会在 0 上乘出 0；防御强度随「这张图多硬」同向变化即可，
## 避免再引入一条没人验证的系数。[br]
## [br][b]夹取范围[b]：超出 ±2 档按端点取值——境界差 3 档以上与 2 档的体验差异
## 由数量/技能池承担，继续放大系数只会让压级变成「无收益」、越级变成「必败」。
const TIER_TABLE: Dictionary = {
	-2: {"hp": 0.60, "atk": 0.70, "label": "碾压"},
	-1: {"hp": 0.80, "atk": 0.90, "label": "轻松"},
	0: {"hp": 1.00, "atk": 1.00, "label": "均势"},
	1: {"hp": 1.30, "atk": 1.25, "label": "吃力"},
	2: {"hp": 1.60, "atk": 1.50, "label": "苦战"},
}

## 档位键下界（更低的 gap 按本档取值）。
const TIER_MIN_GAP: int = -2
## 档位键上界（更高的 gap 按本档取值）。
const TIER_MAX_GAP: int = 2

## 属性下限——夹取后敌人的 HP / ATK 不低于此值（0 血敌人会让战斗无法结束）。
const MIN_ENEMY_HP: int = 1
const MIN_ENEMY_ATK: int = 1


## 追赶系数——玩家境界高于模板基准时按 [constant CATCH_UP_PER_REALM] 逐档追平；
## 不高于时恒 1.0（境界压制由 [code]RealmSystem.realm_penalty[/code] 负责，不在这里重复）。[br]
## [br][param p_template_realm] 敌人模板自带境界（[code]EnemyTemplate.realm[/code]）。[br]
## [param p_player_realm] 玩家当前境界。
static func catch_up_of(p_template_realm: int, p_player_realm: int) -> float:
	var gap: int = int(p_player_realm) - int(p_template_realm)
	if gap <= 0:
		return 1.0
	return 1.0 + float(gap) * CATCH_UP_PER_REALM


## 档位键——[code]地图境界档 − 玩家境界[/code] 夹到表内范围。[br]
## [br][b]返回 0（均势）[/b]的条件：[code]map_realm <= 0[/code]（未定档）或玩家境界
## 缺省——「读不到档位」不臆造难度，按基线处理（同 [code]EncounterFields[/code]
## 的「未指定不是第 0 境界」口径）。
static func tier_key_of(p_map_realm: int, p_player_realm: int) -> int:
	if p_map_realm <= 0 or p_player_realm <= 0:
		return 0
	return clampi(p_map_realm - p_player_realm, TIER_MIN_GAP, TIER_MAX_GAP)


## 档位行——[code]{gap, hp, atk, label}[/code]（表内 Dictionary 的浅拷贝）。[br]
## [br][param p_map_realm] 地图的敌人基准境界（节点的 [code]enemy_level[/code]）。[br]
## [param p_player_realm] 玩家当前境界。
static func tier_of(p_map_realm: int, p_player_realm: int) -> Dictionary:
	var key: int = tier_key_of(p_map_realm, p_player_realm)
	var row: Dictionary = (TIER_TABLE[key] as Dictionary).duplicate()
	row["gap"] = key
	return row


## 档位中文名（调试面板 / 战报 / 测试断言共用的唯一词表）。
static func tier_label_of(p_map_realm: int, p_player_realm: int) -> String:
	return str(tier_of(p_map_realm, p_player_realm).get("label", ""))


## 三轴乘数——[code]{hp, atk, defense, gap, label}[/code]。[br]
## [br][b]给了地图档就只走档位轴[/b]（[param p_map_realm] > 0）：地图自身的境界
## 就是「这张图该有多强」的基准，玩家相对它的位置由 gap 表达——[b]玩家练到什么
## 程度，gap 就负多少[/b]，追赶已含在其中。两条轴都乘会重复计算：一个元婴玩家进
## 元婴图，追赶轴按「模板境界 2」再加 ×1.6，而档位轴说 gap=0（正合适）——
## 结果是「玩家越接近这张图的境界，敌人被堆得越厚」，与「追平后 3~5 回合能赢」
## 的验收目标正好相反。[br]
## [br][b]没给地图档才走追赶轴[/b]（渡劫 / 未定档的注入路径）：那时没有任何
## 「地图基准」可参照，只能按模板境界追赶——与改造前的两参调用逐位一致。[br]
## [br][param p_template_realm] 敌人模板境界（仅在未定档时参与）。[br]
## [param p_player_realm] 玩家境界。[br]
## [param p_map_realm] 地图境界档（≤0 = 未定档）。
static func multipliers_of(p_template_realm: int, p_player_realm: int,
		p_map_realm: int = 0) -> Dictionary:
	var catch_up: float = catch_up_of(p_template_realm, p_player_realm) \
			if p_map_realm <= 0 else 1.0
	var tier: Dictionary = tier_of(p_map_realm, p_player_realm)
	var hp_mult: float = catch_up * float(tier["hp"])
	return {
		"hp": hp_mult,
		"atk": catch_up * float(tier["atk"]),
		"defense": hp_mult,
		"gap": int(tier["gap"]),
		"label": str(tier["label"]),
	}


## 套用系数——返回 [code]{max_hp, attack, defense}[/code]（取整 + 夹下限）。[br]
## [br][b]取整口径[/b]：四舍五入（[method @GlobalScope.roundi]）——与既有
## [code]ai_roster_factory[/code] 的 [code]int(round(...))[/code] 逐位一致，
## 系数为 1.0 时结果恒等于模板原值（出厂端到端用例按原值断言敌方 HP）。[br]
## [br][b]夹下限[/b]：HP / ATK 不低于 [constant MIN_ENEMY_HP] / [constant MIN_ENEMY_ATK]；
## 防御可以为 0（模板本来就是 0 的敌人不该被凭空加防御）。[br]
## [br][param p_base_hp] 模板基础生命。[br]
## [param p_base_atk] 模板基础攻击。[br]
## [param p_base_def] 模板基础防御。[br]
static func apply(p_base_hp: int, p_base_atk: int, p_base_def: int,
		p_template_realm: int, p_player_realm: int, p_map_realm: int = 0) -> Dictionary:
	var mult: Dictionary = multipliers_of(p_template_realm, p_player_realm, p_map_realm)
	return {
		"max_hp": maxi(roundi(float(p_base_hp) * float(mult["hp"])), MIN_ENEMY_HP),
		"attack": maxi(roundi(float(p_base_atk) * float(mult["atk"])), MIN_ENEMY_ATK),
		"defense": maxi(roundi(float(p_base_def) * float(mult["defense"])), 0),
	}
