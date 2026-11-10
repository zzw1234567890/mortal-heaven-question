class_name CombatPlayController
extends RefCounted
## CombatPlayController —— 出牌交互闭环（combat-ui-interaction 001）。
##
## [b]职责[/b]：把「选中态 + 目标 + 出牌请求 + 结果反馈」串成一条可测链路——[br]
##   [code]select_card() → set_targets() → confirm() → {ok, reason, message}[/code][br]
## 出牌成功后清选中并广播 [signal card_played]；被拒时[b]保留选中[/b]并广播
## [signal play_rejected]（玩家可改目标重试，不必重选卡）。[br]
## [br][b]为什么独立成类[/b]：这是本 epic 第一块闭环的 Logic 内核——手势（鼠标拖拽 /
## 数字键 / 手柄）只是它的不同触发方式，三条路径必须共用同一份「能不能出、出哪张、
## 打谁、被拒怎么说」的判定，否则三种输入会走出三种行为。类里没有 InputEvent、
## 没有节点，全部可由单元测试驱动。[br]
## [br][b]UI 不做数值操作[/b]（ADR-0008 / control-manifest）：费用扣减、效果结算、
## 手牌移除全在 [code]CombatSystem[/code] 侧；本类只转发请求与结果。[br]
## [br][b]依赖注入[/b]：[method setup] 注入出牌桥与选中模型（测试传桩，生产传真实实现）。[br]
##
## @experimental
## 来源: ADR-0008 §出牌结算流程、ADR-0004 §输入锁、ADR-0031、
## design/gdd/combat-ui-system.md §手牌交互 AC、
## production/epics/combat-ui-interaction/story-003-drag-play-flow.md（AC-4）、
## story-005-target-selection.md。

## 出牌结果与拒绝原因（UI 提示文本的唯一来源）。
const PlayResult := preload("res://src/feature/combat/combat_play_result.gd")
## 选中态模型（默认自建——测试可注入以预置状态）。
const SelectionModel := preload("res://src/ui/combat/shared/hand_selection_model.gd")
## 目标解析纯函数（源枚举取值）。
const TargetRules := preload("res://src/ui/combat/shared/combat_target_rules.gd")

## 出牌成功——[param result] 为带 [code]targets[/code] 的结果字典（UI 据此播放
## 「卡飞向目标」的表现）。[br]
## [b]签名对齐信号约定[/b]：单参数，载荷即结果字典。
signal card_played(result: Dictionary)

## 出牌被拒——[param result] 含 [code]reason[/code] 与 [code]message[/code]，
## UI 直接显示 [code]message[/code]（中文提示文本的唯一来源）。[br]
## [b]选中不被清空[/b]：玩家可改目标或等费用恢复后重试。
signal play_rejected(result: Dictionary)

## 选中态变更——[param card_instance_id] 为当前选中卡（无选中传 NO_CARD）。[br]
## UI 侧手牌区据此落「抬起」视觉（本类不碰节点）。
signal selection_changed(card_instance_id: int)

## 出牌桥（[code]CombatPlayBridge[/code] 或同形状桩）。
var _bridge: RefCounted = null
## 选中态模型。
var _selection: RefCounted = null


## 注入依赖。[br]
## [param p_bridge] 出牌桥（需实现 [code]play_card_detailed[/code]）。[br]
## [param p_selection] 选中模型（可空——缺省自建一个空的）。
func setup(p_bridge: RefCounted, p_selection: RefCounted = null) -> void:
	_bridge = p_bridge
	_selection = p_selection if p_selection != null else SelectionModel.new()


## 选中一张手牌。[br]
## [br][param p_card_instance_id] 卡实例 ID。[br]
## [param p_affordable] 费用是否充足（UI 现读 CostSystem）。[br]
## [param p_psychic] 是否灵能预览态（阶段 2 外——不可出牌）。[br]
## [b]返回[/b]: 选中后是否可以确认出牌（[code]can_confirm()[/code] 的即时值）——
## UI 据此决定确认手势是否接受（非法时不可确认）。[br]
## [br][b]不可出牌仍允许选中[/b]：费用不足的卡可以选起来看详情，只是按不动确认
## ——直接拒绝选中会让「为什么不让我点」无从得知。
func select_card(p_card_instance_id: int, p_affordable: bool = true,
		p_psychic: bool = false) -> bool:
	var confirmable: bool = _selection.call(&"select_card", p_card_instance_id,
			p_affordable, p_psychic)
	selection_changed.emit(_selection.call(&"get_card_instance_id"))
	return confirmable


## 指定目标（显式覆盖默认策略）。[br]
## [br][b]合法性现问桥[/b]：目标是否有效由 [code]CombatPlayBridge.resolve_targets[/code]
## 判定（存活与否在系统侧，UI 不自算）；全无效则在模型上标记，挡住确认。
## 桥未注入时不标记——不因缺数据把玩家的目标判成非法。
func set_targets(p_target_indices: Array) -> void:
	_selection.call(&"select_target", p_target_indices)
	if _bridge == null or not _bridge.has_method(&"resolve_targets"):
		return
	var resolution: Dictionary = _bridge.call(&"resolve_targets", p_target_indices)
	var source: int = int(resolution.get("source", TargetRules.SOURCE_UNRESOLVED))
	_selection.call(&"mark_targets_invalid", source == TargetRules.SOURCE_NONE)


## 刷新选中卡的可出牌性（费用变化 / 阶段切换时调用）。[br]
## [br][b]不清选中[/b]：费用被别处花掉时卡仍是选中的，只是不可确认；费用恢复后
## 直接可确认，玩家不必重选。
func refresh_playability(p_affordable: bool, p_psychic: bool = false) -> void:
	_selection.call(&"refresh_playability", p_affordable, p_psychic)


## 手牌变更后同步选中（被打出 / 弃掉的卡自动取消选中）。[br]
## [param p_hand_card_ids] 当前手牌里仍存在的卡实例 ID 列表。[br]
## [b]返回[/b]: 是否发生了自清（UI 据此刷新视觉）。
func sync_hand(p_hand_card_ids: Array) -> bool:
	var cleared: bool = bool(_selection.call(&"sync_hand", p_hand_card_ids))
	if cleared:
		selection_changed.emit(_selection.call(&"get_card_instance_id"))
	return cleared


## 取消选中（点空白 / ESC / 右键）。[br]
## [b]幂等[/b]：未选中时调用无副作用（不重复发信号——避免 UI 白刷一帧）。
func cancel() -> void:
	if not bool(_selection.call(&"has_selection")):
		return
	_selection.call(&"clear")
	selection_changed.emit(_selection.call(&"get_card_instance_id"))


## 确认出牌——[b]本类唯一的出牌入口[/b]。[br]
## [br][b]流程[/b]（任一前置不满足都[b]不发请求[/b]，直接返回本地拒绝）：[br]
##   1. 没选卡 → 拒（[constant CombatPlayResult.REASON_CARD_NOT_FOUND]）；[br]
##   2. [method can_confirm] 为 false（费用不足 / 灵能态 / 目标非法）→
##      拒并带上模型的原因；[br]
##   3. 否则交出牌桥（其内部完成施法者裁定 + 目标解析 + 系统侧结算）。[br]
## [br]成功 → 清选中 + 发 [signal card_played]；失败 → 保留选中 + 发
## [signal play_rejected]（带可显示的中文提示）。[br]
## [br][b]返回[/b]: [code]{ok, reason, message, context}[/code]。
func confirm() -> Dictionary:
	# 桥缺失先于选中检查：门面在装配台未装配时会给出空控制器，此时「选中」本身
	# 无意义（选中的卡无处可出），报「战斗系统未就绪」比报「找不到卡」准确。
	if _bridge == null:
		return _reject(PlayResult.fail(PlayResult.REASON_NO_COMBAT))
	var card_instance_id: int = int(_selection.call(&"get_card_instance_id"))
	if card_instance_id == SelectionModel.NO_CARD:
		return _reject(PlayResult.fail(PlayResult.REASON_CARD_NOT_FOUND))
	if not bool(_selection.call(&"can_confirm")):
		return _reject(_local_rejection())
	var result: Dictionary = _bridge.call(&"play_card_detailed", card_instance_id,
			_selection.call(&"get_target_indices"))
	if not PlayResult.is_ok(result):
		return _reject(result)
	_selection.call(&"confirm")
	selection_changed.emit(_selection.call(&"get_card_instance_id"))
	card_played.emit(result)
	return result


## 当前是否可以确认出牌（UI 的确认手势先问这里）。
func can_confirm() -> bool:
	return bool(_selection.call(&"can_confirm"))


## 当前选中的卡实例 ID（无选中为 [constant SelectionModel.NO_CARD]）。
func get_selected_card_id() -> int:
	return int(_selection.call(&"get_card_instance_id"))


## 选中模型引用（UI 读状态落视觉 / 测试直接断言）。
func get_selection() -> RefCounted:
	return _selection


# === 内部 =======================================================================

## 本地拒绝（请求未发到系统侧）——原因由模型给出，文案查 [CombatPlayResult]。[br]
## [br][b]为什么不复用系统侧的 REASON_COST_NOT_ENOUGH[/b]：UI 侧只知道「不可出」，
## 不知道具体缺多少费；费用差额由 [code]CombatSystem[/code] 在真正尝试时才算得出。
## 故本地拒绝带的是模型原因，[method _reject] 负责把它翻成提示文本。
func _local_rejection() -> Dictionary:
	var reason: StringName = _selection.call(&"get_reason")
	var context: Dictionary = {"selection_reason": reason}
	match reason:
		SelectionModel.REASON_UNAFFORDABLE:
			return PlayResult.fail(PlayResult.REASON_COST_NOT_ENOUGH, context)
		SelectionModel.REASON_TARGET_INVALID:
			return PlayResult.fail(PlayResult.REASON_BAD_TARGET, context)
		SelectionModel.REASON_PSYCHIC:
			return PlayResult.fail(PlayResult.REASON_WRONG_PHASE, context)
	return PlayResult.fail(PlayResult.REASON_CARD_NOT_FOUND, context)


## 统一拒绝出口——发信号并原样返回（调用方拿到的就是广播出去的同一份）。
func _reject(result: Dictionary) -> Dictionary:
	play_rejected.emit(result)
	return result
