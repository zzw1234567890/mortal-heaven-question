extends Node
## EventSystem mock——用于 DialoguePlayer 测试注入。
##
## 记录 set_flag 调用以验证 outcomes 委托。

## story flags 存储
var _flags: Dictionary = {}
## set_flag 调用记录
var _set_flag_calls: Array = []


## 设置 story flag
func set_flag(flag: String, value: Variant) -> void:
	_flags[flag] = value
	_set_flag_calls.append({"flag": flag, "value": value})


## 获取 story flag
func get_flag(flag: String) -> Variant:
	return _flags.get(flag, null)


## 检查 story flag 是否存在
func has_flag(flag: String) -> bool:
	return _flags.has(flag)
