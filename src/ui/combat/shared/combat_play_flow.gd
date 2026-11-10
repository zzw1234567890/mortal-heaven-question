class_name CombatPlayFlow
extends RefCounted
## CombatPlayFlow —— 出牌手势语义（combat-ui-interaction 001 / 本轮：真实输入路径）。
##
## [b]职责[/b]：把「点卡 / 拖卡 / 点目标 / 点空白」翻译成一次出牌尝试——[br]
##   - [b]点卡[/b]：选中；对同一张卡再点一次即确认（未知词 / 多选 / 自身 / 全体都这样）；[br]
##   - [b]点目标[/b]（已选单体卡）：目标入模并[b]立即确认[/b]（点完就出，GDD 单体）；[br]
##   - [b]点目标[/b]（已选多选卡）：目标累加 / 再点取消，仍等玩家点卡确认；[br]
##   - [b]拖拽释放到目标[/b]：同「点目标」但[b]必定确认[/b]（拖到谁身上就是要打谁）；[br]
##   - [b]拖拽释放到空白 / 空白点击[/b]：取消选中，不出牌、不扣费。[br]
## [br][b]与 CombatPlayController 的分工[/b]：控制器管「选中 + 目标 + 确认 + 提示」，
## 本类管[b]手势语义[/b]（点/拖、单/多、确认时机）——手势有多种，判定只此一份。
## [br][b]纯状态[/b]（ADR-0031 Logic 内核模式）：无节点、无输入事件；输入组件的
## [code]_input[/code] 只负责喂坐标与命中结果。
##
## @experimental
## 来源: ADR-0004、ADR-0031、design/gdd/combat-ui-system.md §手牌交互/§出牌目标选择、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md、
## story-005-target-selection.md。

## 手势处理结果的状态（[method click_card] 等返回值的 [code]status[/code] 键）。
const STATUS_IGNORED: StringName = &"ignored"
const STATUS_SELECTED: StringName = &"selected"
const STATUS_TARGET_PICKED: StringName = &"target_picked"
const STATUS_PLAYED: StringName = &"played"
const STATUS_REJECTED: StringName = &"rejected"

## 目标策略 / 点选规则 / 结果（全部单一来源，本类不重复常量）。
const Policy := preload("res://src/ui/combat/shared/combat_target_policy.gd")
const Picking := preload("res://src/ui/combat/shared/combat_target_picking.gd")
const PlayResult := preload("res://src/feature/combat/combat_play_result.gd")
const SelectionModel := preload("res://src/ui/combat/shared/hand_selection_model.gd")

## 出牌闭环控制器（[code]CombatPlayController[/code] 或同形状桩）。
var _controller: RefCounted = null
## 数据提供者——需实现 [code]target_type_of / can_afford / is_psychic /
## is_enemy_target / all_enemy_ids[/code]（测试注入桩）。
var _provider: RefCounted = null
## 当前选中卡的目标模式（选中时按卡面词一次性解析）。
var _mode: int = Policy.MODE_ANY
## 点选中的目标（多选卡持有；单体卡也经它落到控制器）。
var _picked: Array[int] = []


## 注入依赖。
func setup(p_controller: RefCounted, p_provider: RefCounted) -> void:
	_controller = p_controller
	_provider = p_provider


## 点一张卡：已选中同一张 → 确认出牌；否则选中它。[br]
## [b]返回[/b]: [code]{status, result}[/code]（[code]result[/code] 仅在出牌尝试时存在）。
func click_card(p_card_instance_id: int) -> Dictionary:
	if _controller == null:
		return _rejected(PlayResult.fail(PlayResult.REASON_NO_COMBAT))
	if _controller.call(&"get_selected_card_id") == p_card_instance_id:
		return _confirm()
	if not _select(p_card_instance_id):
		return _result(STATUS_IGNORED)
	# 自身 / 全体卡：目标由系统决定——选中后仍需再点一次（或拖拽）确认，
	# 避免「点一下看介绍」把卡打出去。
	return _result(STATUS_SELECTED)


## 点一个敌方目标（已选卡）。[br]
## [br][b]未选卡 / 非敌方 / 无此目标 → 忽略[/b]（不产生错误提示——玩家可能只是
## 点在了空处）。单体卡点完即确认；多选卡只累加。
func click_target(p_target_id: int) -> Dictionary:
	if _controller == null or _controller.call(&"get_selected_card_id") == SelectionModel.NO_CARD:
		return _result(STATUS_IGNORED)
	if not _is_enemy(p_target_id):
		return _result(STATUS_IGNORED)
	# 自身 / 全体：目标由系统决定——玩家的点选不参与（返回原值而非报错）。[br]
	# 注意这里比的是[b]模式[/b]（不是目标词——[code]needs_player_target[/code] 收的是词）。
	if _mode == Policy.MODE_SELF or _mode == Policy.MODE_AUTO_ALL:
		return _result(STATUS_IGNORED)
	_picked = Picking.apply(_picked, p_target_id, _mode)
	_push_targets()
	if Picking.confirms_immediately(_mode):
		return _confirm()
	return _result(STATUS_TARGET_PICKED)


## 拖拽释放：在目标上 → 记目标并[b]必定确认[/b]；空白处 → 取消选中。[br]
## [param p_card_instance_id] 被拖的卡；[param p_target_id] 释放位置的敌方目标（-1 = 空白）。
func drop(p_card_instance_id: int, p_target_id: int) -> Dictionary:
	if _controller == null:
		return _rejected(PlayResult.fail(PlayResult.REASON_NO_COMBAT))
	if p_target_id < 0 or not _is_enemy(p_target_id):
		cancel()
		return _result(STATUS_IGNORED)
	if not _is_selected(p_card_instance_id) and not _select(p_card_instance_id):
		return _result(STATUS_IGNORED)
	# 拖拽是明确的「打这个目标」——单体/多选都直接确认（多选也不再等第二下点击）。
	_picked = Picking.apply(_picked, p_target_id, _mode)
	_push_targets()
	return _confirm()


## 点空白 / 右键 / ESC：取消选中（幂等）。
func cancel() -> void:
	_picked.clear()
	_mode = Policy.MODE_ANY
	if _controller != null:
		_controller.call(&"cancel")


## 当前选中卡的目标模式（无选中为 [constant Policy.MODE_ANY]）。
func current_mode() -> int:
	return _mode


## 已点选的显式目标（副本）。
func picked_targets() -> Array[int]:
	return _picked.duplicate()


## 出牌闭环控制器引用（UI 落选中视觉 / 手牌自清时需要）。
func get_controller() -> RefCounted:
	return _controller


## 手牌变化后同步选中（卡被移除 → 自清）。[param p_hand_ids] 当前手牌 ID。
func sync_hand(p_hand_ids: Array) -> void:
	if _controller == null:
		return
	if bool(_controller.call(&"sync_hand", p_hand_ids)):
		_picked.clear()
		_mode = Policy.MODE_ANY


# === 内部 =====================================================================

## 选中一张卡（解析其目标模式并清空上一张的目标）。[br]
## [b]返回[/b]: 是否选中成功（控制器永远接受选中——费用不足也可选起来看详情）。
func _select(p_card_instance_id: int) -> bool:
	var target_type: StringName = _target_type_of(p_card_instance_id)
	_controller.call(&"select_card", p_card_instance_id,
			bool(_provider.call(&"can_afford", p_card_instance_id)),
			bool(_provider.call(&"is_psychic")))
	_mode = Policy.mode_of(target_type)
	_picked.clear()
	# 全体卡：目标由系统填满（UI 不需要玩家点）——但仍在玩家确认时才出。
	return true


## 确认出牌（把当前目标写进选中模型后交控制器）。
func _confirm() -> Dictionary:
	_push_targets()
	var result: Dictionary = _controller.call(&"confirm")
	if PlayResult.is_ok(result):
		_picked.clear()
		_mode = Policy.MODE_ANY
		return _played(result)
	return _rejected(result)


## 当前目标列表 → 选中模型。[br]
## 自身 / 全体模式的解析结果：自身为空（治疗落施法者），全体为全部存活敌人。
func _push_targets() -> void:
	if _controller == null:
		return
	_controller.call(&"set_targets", _resolved_targets())


## 按模式解析要交给控制器的显式目标。
func _resolved_targets() -> Array:
	if _mode == Policy.MODE_SELF:
		return []
	if _mode == Policy.MODE_AUTO_ALL:
		return _provider.call(&"all_enemy_ids")
	return _picked


func _target_type_of(p_card_instance_id: int) -> StringName:
	return StringName(str(_provider.call(&"target_type_of", p_card_instance_id)))


func _is_enemy(p_target_id: int) -> bool:
	return bool(_provider.call(&"is_enemy_target", p_target_id))


func _is_selected(p_card_instance_id: int) -> bool:
	return _controller != null \
			and int(_controller.call(&"get_selected_card_id")) == p_card_instance_id


func _result(p_status: StringName) -> Dictionary:
	return {"status": p_status, "result": {}}


func _played(p_result: Dictionary) -> Dictionary:
	return {"status": STATUS_PLAYED, "result": p_result}


func _rejected(p_result: Dictionary) -> Dictionary:
	return {"status": STATUS_REJECTED, "result": p_result}
