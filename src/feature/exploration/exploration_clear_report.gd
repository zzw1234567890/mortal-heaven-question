extends RefCounted
## ExplorationClearReport —— 通关结算的[b]展示载荷组装[/b]（含「下一张去哪」）。[br]
## [br][b]为什么从 map_flush 拆出来[/b]：[code]exploration_map_flush.gd[/code] 已贴
## 300 行软上限（.claude/docs/coding-standards.md），而本轮要在结算里多算一件事
## ——[b]通关之后推荐哪张图[/b]（读探明表 × 玩家境界 × 已通关集合，是
## [code]ExplorationMapGate[/code] 的求值，不是奖励结算）。「发了什么奖」与
## 「接下来去哪」是两件事，各归一处。[br]
## [br][b]算好再存[/b]：推荐态是（境界 × 已通关集合）的函数——面板与选图界面都
## 不该自己去推解锁条件（UI 零状态所有权），故在这里折成展示字段随
## [code]MapClearView[/code] 一起发布。[br]
## [br][b]全图通关时不臆造[/b]：没有下一张可推荐时四个键留空，面板据此不出推荐行。[br]
## [br][b]只读[/b]：本模块不改任何玩法状态、不发奖励——奖励在
## [code]ExplorationMapFlush._settle_boss_defeated[/code] 里已发放完毕，本模块只把
## 结果与推荐折成一份视图。[br]
##
## 来源: design/gdd/exploration-ui-system.md §1 地图选择界面 / §7 地图通关结算、
## design/gdd/exploration-system.md §8 地图初始解锁顺序、ADR-0014 §决策 5、ADR-0031 §2。

## 结算视图的键名真理来源（发布方与面板都不裸写字符串）。
const ClearView := preload("res://src/feature/exploration/map_clear_view.gd")
## 解锁门槛判定与「下一张」求值（纯函数模块）。
const GateScript := preload("res://src/feature/exploration/exploration_map_gate.gd")
## 已通关集合的读取面（与选图列表同一份口径——两处各读一遍必然出现读法分歧）。
const MapListScript := preload("res://src/feature/exploration/exploration_map_list.gd")

## 玩家境界缺省值（GSM 不可用时按炼气——最保守的推荐口径）。
const FALLBACK_REALM: int = 1


## 备好结算面板的视图并写进跨场景缓存（面板在场景切换之后才挂载——见 ClearView）。[br]
## [br][param p_gsm] GSM（非空——调用方已守卫）。[br]
## [param p_map_id] 刚通关的地图。[br]
## [param p_is_first] 本次是否为首次通关。[br]
## [param p_clear_count] 本次通关后的累计次数。[br]
## [param p_rewards] 基础奖励（[code]calculate_map_clear_rewards[/code] 的产物）。[br]
## [param p_first_rewards] 首通额外奖励（重复通关时为空字典）。[br]
## [param p_base_cards] 基础卡牌发放结果 [code]{cards, cards_failed}[/code]。[br]
## [param p_first_cards] 首通卡牌发放结果（同上）。[br]
## [br][b]返回[/b]：发布的视图字典（测试断言用——与 [method MapClearView.peek] 同内容）。
static func publish(p_gsm: Node, p_map_id: StringName, p_is_first: bool,
		p_clear_count: int, p_rewards: Dictionary, p_first_rewards: Dictionary,
		p_base_cards: Dictionary, p_first_cards: Dictionary) -> Dictionary:
	var first_ling_shi: int = int(p_first_rewards.get("ling_shi", 0))
	var first_cultivation: int = int(p_first_rewards.get("cultivation", 0))
	var view: Dictionary = {
		ClearView.KEY_MAP_ID: p_map_id,
		ClearView.KEY_MAP_NAME: GateScript.map_display_name(p_map_id),
		ClearView.KEY_IS_FIRST_CLEAR: p_is_first,
		ClearView.KEY_CLEAR_COUNT: p_clear_count,
		ClearView.KEY_LING_SHI: int(p_rewards.get("ling_shi", 0)),
		ClearView.KEY_CULTIVATION: int(p_rewards.get("cultivation", 0)),
		ClearView.KEY_FIRST_LING_SHI: first_ling_shi,
		ClearView.KEY_FIRST_CULTIVATION: first_cultivation,
		ClearView.KEY_CARDS: p_base_cards.get("cards", []),
		ClearView.KEY_FIRST_CARDS: p_first_cards.get("cards", []),
		ClearView.KEY_CARDS_FAILED: (p_base_cards.get("cards_failed", []) as Array)
				+ (p_first_cards.get("cards_failed", []) as Array),
	}
	# 「下一张去哪」——刚通关的那张不进候选（否则推荐回原地），全图通关时四键皆空
	var next: Dictionary = GateScript.next_playable(p_map_id, player_realm(p_gsm),
			cleared_maps(p_gsm))
	if not next.is_empty():
		view[ClearView.KEY_NEXT_MAP_ID] = next.get("map_id", &"")
		view[ClearView.KEY_NEXT_MAP_NAME] = str(next.get("name", ""))
		view[ClearView.KEY_NEXT_IS_UNLOCKED] = bool(next.get("is_unlocked", false))
		view[ClearView.KEY_NEXT_LOCKED_HINT] = str(next.get("locked_hint", ""))
	ClearView.publish(view)
	return view


## 玩家当前境界——GSM 缺失时回退 [constant FALLBACK_REALM]（不臆造高境界）。
static func player_realm(p_gsm: Node) -> int:
	if p_gsm == null:
		return FALLBACK_REALM
	return int(p_gsm.player.get("realm", FALLBACK_REALM))


## 各图通关态集合——借 [code]ExplorationMapList.cleared_maps[/code] 的读取口径
## （同一份 [code]map_states[/code] 解析，选图列表与本模块不会各读一套）。[br]
## [br][b]父引用传 null[/b]：本方法只用到与 GSM 有关的那一半（父引用服务于重入
## 费用计算），本模块不碰经济。[br]
static func cleared_maps(p_gsm: Node) -> Dictionary:
	return MapListScript.new(null).cleared_maps(p_gsm)
