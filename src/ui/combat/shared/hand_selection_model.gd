class_name HandSelectionModel
extends RefCounted
## HandSelectionModel —— 手牌选中态状态机（combat-ui-interaction 001）。
##
## [b]职责[/b]：管理「玩家选中的是哪张手牌 + 准备了哪些目标」，并回答
## [b]「现在能不能确认出牌」[/b]——把原本只存在于视觉层的选中概念变成可测接口。[br]
## [br][b]为什么需要独立模型[/b]：选中态此前只由 [code]HandCard[/code] 的
## 抬起/缩放暗示，没有任何代码持有「选了哪张」——于是「非法时不可确认」这条
## 规则无处可写，只能靠手势代码自己判，也无法写测试。抽出纯类后，
## 「选中 / 取消 / 失效自清 / 可否确认」四条语义都能零 UI 依赖断言。[br]
## [br][b]状态机[/b]：[br]
##   [code]CLEAR → (select_card) → CARD_SELECTED[/code][br]
##   [code]CARD_SELECTED → (select_target / 保持默认) → TARGET_READY[/code][br]
##   [code]任意 → (confirm 成功) → CLEAR[/code]（出牌后不再持有选中）[br]
##   [code]任意 → (clear / 卡被移除 / 不可出牌) → CLEAR[/code][br]
## [br][b]目标为空时的语义[/b]：选中卡牌但没点目标[b]不代表非法[/b]——出牌链路的
## 默认策略会打首个存活敌人（[code]CombatTargetRules[/code]）。故
## [method can_confirm] 只要求「选中的卡可出牌」，目标是可选的；显式点了但
## 判为无效的目标才会挡住确认。[br]
## [br][b]纯状态（ADR-0031 Logic 内核模式）[/b]：不持有节点、不发信号、无副作用；
## 节点渲染由调用方读 [method get_state] 自行落定。[br]
##
## @experimental
## 来源: ADR-0031、ADR-0008 §出牌结算流程、
## design/gdd/combat-ui-system.md §2 手牌区/§手牌区状态、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md、
## story-005-target-selection.md。

## 无选中。
const STATE_CLEAR: int = 0
## 选中的卡不可出牌（费用不足 / 灵能预览态）——不可确认。
const STATE_BLOCKED: int = 1
## 已选卡、可出牌（目标走默认或已显式指定）。
const STATE_READY: int = 2
## 已选卡，但显式指定的目标全部无效——不可确认。
const STATE_TARGET_INVALID: int = 3

## 非法原因（[code]reason[/code] 字段——提示文本由 UI 层查表，本类不带文案）。
const REASON_NONE: StringName = &""
const REASON_NO_CARD: StringName = &"no_card"
const REASON_UNAFFORDABLE: StringName = &"unaffordable"
const REASON_PSYCHIC: StringName = &"psychic"
const REASON_TARGET_INVALID: StringName = &"target_invalid"

## 当前选中的卡实例 ID（[constant NO_CARD] = 无）。
var _card_instance_id: int = -1
## 已准备的目标 ID 列表（空 = 走默认策略）。
var _target_indices: Array[int] = []
## 选中卡是否费用充足（由调用方按 CostSystem 现读写入）。
var _affordable: bool = true
## 是否灵能预览态（阶段 2 外——不可出牌）。
var _psychic: bool = false
## 显式目标是否全部无效（[method mark_targets_invalid] 写入）。
var _targets_invalid: bool = false


## 无选中哨兵（同 [code]CombatCasterRules.NO_CASTER[/code] 的 -1 口径）。
const NO_CARD: int = -1


# === 查询 =======================================================================

## 当前状态（[constant STATE_CLEAR] / [constant STATE_READY] /
## [constant STATE_TARGET_INVALID]）。
func get_state() -> int:
	if _card_instance_id == NO_CARD:
		return STATE_CLEAR
	if _psychic or not _affordable:
		return STATE_BLOCKED
	if _targets_invalid:
		return STATE_TARGET_INVALID
	return STATE_READY


## 不可确认的原因（可确认时返回 [constant REASON_NONE]）。[br]
## [br]顺序即优先级：先看选没选卡，再看卡本身能不能出，最后看目标。
## UI 只显示第一条——「没选卡」时不该提示「灵力不足」。
func get_reason() -> StringName:
	if _card_instance_id == NO_CARD:
		return REASON_NO_CARD
	if _psychic:
		return REASON_PSYCHIC
	if not _affordable:
		return REASON_UNAFFORDABLE
	if _targets_invalid:
		return REASON_TARGET_INVALID
	return REASON_NONE


## 当前是否可以确认出牌——[b]「非法时不可确认」的唯一判据[/b]。[br]
## [br]UI 的确认手势必须先问这里；返回 false 时手势不得触发出牌。
func can_confirm() -> bool:
	return get_state() == STATE_READY


## 选中的卡实例 ID（无选中为 [constant NO_CARD]）。
func get_card_instance_id() -> int:
	return _card_instance_id


## 已准备的目标 ID 列表（副本——调用方改它不会污染模型）。
func get_target_indices() -> Array[int]:
	return _target_indices.duplicate()


## 是否有选中（供 UI 决定是否落「抬起」视觉）。
func has_selection() -> bool:
	return _card_instance_id != NO_CARD


## 某张卡是否处于选中态（[HandCard] 逐个询问用——避免 UI 自己比对两个字段）。
func is_selected(card_instance_id: int) -> bool:
	return card_instance_id != NO_CARD and card_instance_id == _card_instance_id


# === 变更 =======================================================================

## 选中一张卡。[br]
## [br][b]副作用（有意）[/b]：切换卡牌时[b]清空已准备的目标[/b]——目标是为上一张卡
## 选的，带到新卡上是错的（不同卡打不同人）。重复选中同一张卡则保留目标（幂等，
## 玩家点第二下不该把选好的目标弄丢）。[br]
## [param p_card_instance_id] 卡实例 ID。[br]
## [param p_affordable] 费用是否充足（调用方现读 CostSystem）。[br]
## [param p_psychic] 是否灵能预览态（阶段 2 外）。[br]
## [b]返回[/b]: 选中后是否可以确认（[method can_confirm] 的即时值）。
func select_card(p_card_instance_id: int, p_affordable: bool = true,
		p_psychic: bool = false) -> bool:
	if not is_selected(p_card_instance_id):
		_target_indices.clear()
		_targets_invalid = false
	_card_instance_id = p_card_instance_id
	_affordable = p_affordable
	_psychic = p_psychic
	return can_confirm()


## 指定目标（显式覆盖默认策略）。[br]
## [br][b]不清空选中[/b]：目标与选中是同一动作的两半，调用方决定何时清。
## 负值与重复项跳过（宽松兼容 UI 传入的 Variant 数组）。
func select_target(p_target_indices: Array) -> void:
	_target_indices.clear()
	for raw: Variant in p_target_indices:
		var target_id: int = int(raw)
		if target_id < 0 or _target_indices.has(target_id):
			continue
		_target_indices.append(target_id)
	# 目标换了就不该沿用上一次的「无效」判定——由调用方重新标记。
	_targets_invalid = false


## 标记「显式指定的目标全部无效」——挡住确认（[method can_confirm] 转 false）。[br]
## [br][b]无显式目标时不生效[/b]：空目标走默认策略，不是无效。
func mark_targets_invalid(p_invalid: bool) -> void:
	_targets_invalid = p_invalid and not _target_indices.is_empty()


## 刷新选中卡的可出牌性（费用变化 / 阶段切换时调用）。[br]
## [br][b]不改选中本身[/b]：费用被别处花掉时，卡仍处于选中态但不可确认——
## 直接清选中会让玩家的手停在半空，且费用恢复后还得重选。
func refresh_playability(p_affordable: bool, p_psychic: bool) -> void:
	_affordable = p_affordable
	_psychic = p_psychic


## 确认出牌成功后调用——回到无选中（目标一并清）。
func confirm() -> void:
	clear()


## 清空选中（点空白 / ESC / 出牌被拒后重置 / 卡被移除）。[br]
## [br][b]幂等[/b]：重复调用无副作用。
func clear() -> void:
	_card_instance_id = NO_CARD
	_target_indices.clear()
	_affordable = true
	_psychic = false
	_targets_invalid = false


## 卡离开手牌（被打出 / 弃掉）时的自清——选中已不存在的卡正是「幽灵选中」的
## 来源（UI 上什么都没有，确认却仍可点）。[br]
## [param p_hand_card_ids] 当前手牌里仍存在的卡实例 ID 列表。[br]
## [b]返回[/b]: 是否发生了自清（供调用方决定要不要刷新视觉）。
func sync_hand(p_hand_card_ids: Array) -> bool:
	if _card_instance_id == NO_CARD:
		return false
	for raw: Variant in p_hand_card_ids:
		if int(raw) == _card_instance_id:
			return false
	clear()
	return true
