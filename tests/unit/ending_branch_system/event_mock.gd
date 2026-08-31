extends Node
## EventSystem mock——测试 EndingEvaluator 时替换 EventSystem。[br]
## [br]模拟 get_flag 行为：返回预设的 story_flags。[br]
## [br]来源: ADR-0029 §EndingEvaluator evaluate 参数 event_system。

## 预设 story_flags——测试设置。
var _flags: Dictionary = {}


func get_flag(flag: StringName, default_val: Variant = null) -> Variant:
	return _flags.get(flag, default_val)
