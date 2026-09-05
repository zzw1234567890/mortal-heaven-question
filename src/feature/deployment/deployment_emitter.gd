extends RefCounted
## DeploymentEmitter —— 信号发射包装子模块（从 deployment_system.gd 拆分）。
##
## RefCounted 子模块——持有 `_parent: Node` 引用（DeploymentSystem Autoload）。
## 包含 6 个 Cat 2b 信号的安全发射包装（ADR-0007 _emit_signal_safe 路由）。
##
## [br]来源: ADR-0016 §信号 / ADR-0007 §_emit_signal_safe。
## [br]Sprint 12 Story 018：从 deployment_system.gd 拆分。


var _parent: Node = null


func _init(parent: Node = null) -> void:
	_parent = parent


## 发射 [signal character_deployed]——经 GSM._emit_signal_safe 路由（Cat 2b）。[br]
## GSM 不可用时（测试 mock）回退直接 emit。
func emit_character_deployed(character_id: int, slot_index: int, is_front: bool, deploy_turn: int) -> void:
	if GameStateManager != null and GameStateManager.get_script().has_method("_emit_signal_safe"):
		GameStateManager.get_script()._emit_signal_safe(_parent, &"character_deployed", [character_id, slot_index, is_front, deploy_turn])
	else:
		_parent.get("character_deployed").emit(character_id, slot_index, is_front, deploy_turn)


## 发射 [signal character_removed]——经 GSM._emit_signal_safe 路由。
func emit_character_removed(character_id: int, slot_index: int, reason: String) -> void:
	if GameStateManager != null and GameStateManager.get_script().has_method("_emit_signal_safe"):
		GameStateManager.get_script()._emit_signal_safe(_parent, &"character_removed", [character_id, slot_index, reason])
	else:
		_parent.get("character_removed").emit(character_id, slot_index, reason)


## 发射 [signal front_line_breached]——经 GSM._emit_signal_safe 路由。
func emit_front_line_breached() -> void:
	if GameStateManager != null and GameStateManager.get_script().has_method("_emit_signal_safe"):
		GameStateManager.get_script()._emit_signal_safe(_parent, &"front_line_breached", [])
	else:
		_parent.get("front_line_breached").emit()


## 发射 [signal standby_cleared]——经 GSM._emit_signal_safe 路由。
func emit_standby_cleared(character_ids: Array) -> void:
	if GameStateManager != null and GameStateManager.get_script().has_method("_emit_signal_safe"):
		GameStateManager.get_script()._emit_signal_safe(_parent, &"standby_cleared", [character_ids])
	else:
		_parent.get("standby_cleared").emit(character_ids)


## 发射 [signal character_unavailable]——经 GSM._emit_signal_safe 路由。
func emit_character_unavailable(character_id: int) -> void:
	if GameStateManager != null and GameStateManager.get_script().has_method("_emit_signal_safe"):
		GameStateManager.get_script()._emit_signal_safe(_parent, &"character_unavailable", [character_id])
	else:
		_parent.get("character_unavailable").emit(character_id)


## 发射 [signal character_revived]——经 GSM._emit_signal_safe 路由。
func emit_character_revived(character_id: int) -> void:
	if GameStateManager != null and GameStateManager.get_script().has_method("_emit_signal_safe"):
		GameStateManager.get_script()._emit_signal_safe(_parent, &"character_revived", [character_id])
	else:
		_parent.get("character_revived").emit(character_id)
