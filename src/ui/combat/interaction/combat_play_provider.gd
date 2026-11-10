class_name CombatPlayProvider
extends RefCounted
## CombatPlayProvider —— 出牌手势语义的数据供给（combat-ui-interaction 001 / 本轮）。
##
## [b]职责[/b]：为 [code]CombatPlayFlow[/code] 回答四类问题——[br]
##   - 这张卡的目标词是什么（卡面 [code]target_type[/code]，取自手牌快照）；[br]
##   - 这张卡现在付得起吗（现读 CostSystem + 快照费用）；[br]
##   - 现在是不是灵能预览态（阶段非 PLAY）；[br]
##   - 这个 ID 是不是可打的敌方目标（存活候选池）。[br]
## [br][b]为什么独立成类[/b]：手势语义（点/拖、单/多）必须与「数据从哪来」解耦——
## 纯函数只吃值，取数收敛在这里；测试可注入桩（不碰 Autoload）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：战斗名册、HP、手牌全部经装配台现读；
## 本类不缓存。费用经注入的数据源现读（缺失时按「付得起」——桩环境无费用系统时
## 不应把所有卡都判成不可出）。[br]
## [br][b]零轮询[/b]：无 [code]_process()[/code]。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §手牌交互/§出牌目标选择、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md。

## 阶段常量（CombatPhase.PLAY——同 hand_area 先例）。
const PLAY_PHASE: int = 2

## 装配台（手牌快照 / 敌方候选 / 阶段）。[b]类型宽松（Variant）[/b]：交互挂载模块
## 是 RefCounted 门面，测试也会传桩——鸭子类型调用避免 Node/RefCounted 的类型墙。
var _stage: Variant = null
## 费用数据源（需实现 [code]can_afford(cost)[/code]；可空）。
var _cost_source: Node = null


## 注入数据源（全部可空——缺失时对应能力退化为宽松默认，不抛错）。
func setup(p_stage: Variant, p_cost_source: Node = null) -> void:
	_stage = p_stage
	_cost_source = p_cost_source


## 卡面目标词（查不到返回空串——按未知词处理，允许自由选目标）。
func target_type_of(p_card_instance_id: int) -> StringName:
	for entry: Variant in _snapshot():
		if entry is Dictionary and int((entry as Dictionary).get("card_instance_id", -1)) \
				== p_card_instance_id:
			return StringName(str((entry as Dictionary).get("target_type", "")))
	return &""


## 当前是否付得起这张卡（快照费用 vs CostSystem 现值）。[br]
## [b]0 费始终可负担[/b]（同 [code]CostSystem.can_afford[/code] 语义）；
## 费用源缺失 → true（桩环境不把卡全判死）。
func can_afford(p_card_instance_id: int) -> bool:
	var cost: int = 0
	for entry: Variant in _snapshot():
		if entry is Dictionary and int((entry as Dictionary).get("card_instance_id", -1)) \
				== p_card_instance_id:
			cost = int((entry as Dictionary).get("cost", 0))
			break
	if cost <= 0:
		return true
	if _cost_source == null or not _cost_source.has_method(&"can_afford"):
		return true
	return bool(_cost_source.call(&"can_afford", cost))


## 是否处于灵能预览态（非 PLAY 阶段——可看不可出）。
func is_psychic() -> bool:
	if _stage == null or not (_stage as Object).has_method(&"current_phase"):
		return false
	return int(_stage.call(&"current_phase")) != PLAY_PHASE


## 是否可打的敌方目标（存活候选池里的 ID）。
func is_enemy_target(p_character_id: int) -> bool:
	if _stage == null or not (_stage as Object).has_method(&"enemy_candidates"):
		return false
	for entry: Variant in _stage.call(&"enemy_candidates"):
		if entry is Dictionary and int((entry as Dictionary).get("character_id", -1)) \
				== p_character_id and bool((entry as Dictionary).get("is_alive", true)):
			return true
	return false


## 全部存活敌方 ID（全体卡的自动目标）。
func all_enemy_ids() -> Array:
	var ids: Array = []
	if _stage == null or not (_stage as Object).has_method(&"enemy_candidates"):
		return ids
	for entry: Variant in _stage.call(&"enemy_candidates"):
		if not (entry is Dictionary):
			continue
		if not bool((entry as Dictionary).get("is_alive", true)):
			continue
		var character_id: int = int((entry as Dictionary).get("character_id", -1))
		if character_id >= 0:
			ids.append(character_id)
	return ids


## 手牌快照（装配台不可用时为空数组）。
func _snapshot() -> Array:
	if _stage == null or not (_stage as Object).has_method(&"hand_snapshot"):
		return []
	var snapshot: Variant = _stage.call(&"hand_snapshot")
	return snapshot if snapshot is Array else []
