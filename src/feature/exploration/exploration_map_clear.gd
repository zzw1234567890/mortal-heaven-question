extends RefCounted
## ExplorationMapClear —— 地图通关的[b]状态标记[/b]与[b]卡牌发放[/b]（RefCounted 子模块）。[br]
## [br][b]为什么单独一处[/b]：[code]exploration_map_flush.gd[/code] 的
## [code]BOSS_DEFEATED[/code] 分支本轮要补三件事（通关次数 / 首通卡牌 / 结算视图），
## 而「通关这件事写进存档长什么样」与「卡牌怎么发到玩家手上」是两件事——后者要接
## 卡牌系统与收藏校验，是 [code]ExplorationCraft[/code] 那一类知识。[br]
## [br][b]通关状态的两个键[/b]（同一次写入，不各写一半）：[br]
##   · [code]is_first_clear[/code]——是否[b]已经[/b]通关过（地图卡片与首通判定读它）；[br]
##   · [code]clear_count[/code]——通关次数（GDD §1「地图通关后标记为已通关」的量化面；
##     首通 = 次数从 0 变 1，此后每次 +1）。[br]
## [br][b]卡牌走既有发放器[/b]：一律经 [code]CombatRewardRoller.apply[/code] 入收藏
## （先查模板 → 建实例 → 序列化 → [code]GSM.add_card_to_collection[/code]）——探索侧
## 不另开一条建卡通路，否则「收藏里的卡长什么样」会有两套口径。[br]
## [br][b]为什么按批发放而不是合并成一批[/b]：基础通关卡与首通额外卡在结算面板上是
## [b]两段[/b]（GDD exploration-ui-system.md §7「首次通关奖励」独立高亮），合并后
## 面板无从区分哪张卡是首通彩头。分批的顺序即配置顺序（基础在前、首通在后），
## [code]cards_failed[/code] 的次序不会漂。[br]
## [br][b]失败可见[/b]：模板缺失 / 收藏写入被拒不进静默——逐条记进
## [code]cards_failed[/code] 并在结算面板上原样显示（同战斗结算口径）。[br]
## [br][b]只读入参[/b]：本模块不改传入的配置字典（调用方自己决定是否把发放结果
## 折回结算摘要）。[br]
##
## 来源: design/gdd/exploration-system.md §5 地图通关奖励 / §6 Boss节点与地图通关、
## design/gdd/exploration-ui-system.md §7 地图通关结算、ADR-0014 §决策 5 探索结束结算、
## ADR-0006（卡牌实例 + 收藏入库）。

## 卡牌发放器（唯一实现——掷骰与入收藏口径同战斗结算）。
const Roller := preload("res://src/feature/combat/combat_reward_roller.gd")


## 父节点引用——ExplorationSystem 实例（取 GSM / Autoload）。
var _parent: Node = null

## 卡牌系统（测试注入用桩；null 时按 Autoload 查找，同 [code]ExplorationCraft[/code]）。
var card_system: Node = null


## 构造——传入父节点引用。
func _init(parent: Node = null) -> void:
	_parent = parent


## 标记地图通关——写 [code]is_first_clear[/code] + [code]clear_count[/code]。[br]
## [br][param p_map_id] 地图 ID。[br]
## [param p_gsm] GSM（缺失时只回读不写——不臆造写入成功的假象）。[br]
## [br][b]返回[/b]：[code]{is_first_clear, clear_count}[/code]——[code]is_first_clear[/code]
## 是[b]本次是否为首次[/b]（读的是写入前的状态），[code]clear_count[/code] 是本次通关后的
## 累计次数。调用方据此决定发不发首通额外奖励，不必自己再读一次存档。[br]
## [br][b]幂等边界[/b]：本方法[b]不幂等[/b]——每次调用都会把次数 +1（通关就是一次，
## 没有「重复标记」语义）。防重复由调用方保证（一次探索只结束一次）。[br]
## [br][b]非字典/缺记录一律按 0 次起算[/b]：首通判定不能因为存档里少个键就永远为假
## （那会让玩家永远拿不到首通奖励）。[br]
func mark_cleared(p_map_id: StringName, p_gsm: Node) -> Dictionary:
	var state: Dictionary = _state_of(p_gsm, p_map_id)
	var is_first: bool = not bool(state.get("is_first_clear", false))
	var count: int = int(state.get("clear_count", 0)) + 1
	if p_gsm != null and p_gsm.has_method(&"update_exploration_map_state"):
		p_gsm.call(&"update_exploration_map_state", p_map_id, {
			"is_first_clear": true,
			"clear_count": count,
		})
	return {"is_first_clear": is_first, "clear_count": count}


## 发放[b]一批[/b]卡牌（基础通关卡与首通额外卡各调一次）。[br]
## [br][param p_cards] 卡牌条目数组（[code]{card_id}[/code] 或裸 ID 字符串）。[br]
## [param p_gsm] 收藏写入入口。[br]
## [br][b]返回[/b]：[code]{cards, cards_failed}[/code]——[code]cards[/code] 为到手卡牌
## （含 [code]name / rarity / school[/code] 等展示字段），[code]cards_failed[/code] 为
## [code]{card_id, reason}[/code] 列表。无卡可发时两者皆空（不是 nil）。[br]
## [br][b]非数组入参按空处理[/b]：配置写错不至于开图就崩（发放器同样对脏条目宽容）。[br]
func grant_cards(p_cards: Variant, p_gsm: Node) -> Dictionary:
	var batch: Array = as_list(p_cards)
	if batch.is_empty():
		return {"cards": [], "cards_failed": []}
	var report: Dictionary = Roller.apply({"cards": batch}, null, null,
			_card_system(), p_gsm)
	return {
		"cards": report.get("cards", []),
		"cards_failed": report.get("cards_failed", []),
	}


## 累计通关次数——读 [code]map_states[map_id].clear_count[/code]（无记录为 0）。[br]
## [br][b]用途[/b]：地图卡片/结算界面展示「第 N 次通关」，不必自己翻存档结构。
func clear_count_of(p_map_id: StringName, p_gsm: Node) -> int:
	return int(_state_of(p_gsm, p_map_id).get("clear_count", 0))


## 取某个配置字典里的卡牌清单（缺键 / 非数组 → 空数组）。[br]
## [br][b]为什么不裸写 [code].get("cards", [])[/code][/b]：值可能是任何类型，
## 直接当数组用会在脏配置上炸；调用方（结算分支）要两次（基础 + 首通），
## 归一处保证两次口径一致。
static func cards_of(p_source: Dictionary) -> Array:
	if p_source == null:
		return []
	return as_list(p_source.get("cards", []))


## 非数组入参 → 空数组；数组原样返回（不拷贝——调用方只读）。[br]
## [b]为什么单独暴露[/b]：[code]cards_of[/code] 与 [method grant_cards] 都要这一层
## 兜底，两处各判一次必然漂移。
static func as_list(p_value: Variant) -> Array:
	return p_value if p_value is Array else []


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 地图状态子字典（GSM 缺失 / 无该图记录 → 空字典）。
static func _state_of(p_gsm: Node, p_map_id: StringName) -> Dictionary:
	if p_gsm == null:
		return {}
	var states: Variant = p_gsm.get(&"exploration")
	if not (states is Dictionary):
		return {}
	var map_states: Variant = (states as Dictionary).get("map_states", {})
	if not (map_states is Dictionary):
		return {}
	var state: Variant = (map_states as Dictionary).get(p_map_id, {})
	return state if state is Dictionary else {}


## 卡牌系统——注入优先，否则 Autoload（缺失时发放器记为「卡牌系统不可用」）。
func _card_system() -> Node:
	if card_system != null:
		return card_system
	return _autoload(&"CardSystem")


## Autoload 动态查找（测试环境缺 Autoload 时返回 null——同 [code]ExplorationCraft[/code] 先例）。
static func _autoload(p_node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	return tree.root.get_node_or_null(NodePath(String(p_node_name)))
