extends Node
## Mock IM——SceneManager 依赖注入的最小 InputManager 替身（共享 fixture）。
##
## 契约对齐 InputManager 的 [code]push_lock(type, source)[/code] /
## [code]pop_lock(source)[/code]（锁栈配对）。带调用计数供测试断言
## 锁配对与释放（如 _cleanup_on_error 强制释放 TRANSITION 锁）。

## push_lock 调用计数（先例命名 push_calls——与 test_loading_screen.gd 断言对齐）。
var push_calls: int = 0

## pop_lock 调用计数（先例命名 pop_calls）。
var pop_calls: int = 0

## 调用日志（op/type/source——锁配对审查用）。
var _call_log: Array = []


func push_lock(type: int, source: StringName) -> void:
	push_calls += 1
	_call_log.append({"op": "push", "type": type, "source": source})


func pop_lock(source: StringName) -> void:
	pop_calls += 1
	_call_log.append({"op": "pop", "source": source})


## 重置计数与日志（迭代断言用——先例契约）。
func reset_counts() -> void:
	push_calls = 0
	pop_calls = 0
	_call_log.clear()
