extends SceneTree
## InputMap API 最小验证脚本（一次性——story 004 实现前置查证）。
## 验证 action_set_event 是否存在于 Godot 4.6.3（story/GDD 文本提到，
## 引擎参考无记录——LLM 知识截止后可能新增/不存在）。

func _init() -> void:
	print("action_set_event exists: ", InputMap.has_method("action_set_event"))
	print("action_add_event exists: ", InputMap.has_method("action_add_event"))
	print("action_erase_events exists: ", InputMap.has_method("action_erase_events"))
	print("has_action exists: ", InputMap.has_method("has_action"))
	print("get_actions exists: ", InputMap.has_method("get_actions"))
	# 序列化往返辅助验证：InputEventKey as_text 不崩溃
	var e := InputEventKey.new()
	e.physical_keycode = KEY_F1
	print("as_text: ", e.as_text())
	quit()
