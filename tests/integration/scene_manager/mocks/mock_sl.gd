extends Node
## Mock SL——SceneManager 依赖注入的最小 SaveLoadSystem 替身（共享 fixture）。
##
## 契约对齐 SaveLoadSystem 的 [code]auto_save()[/code]
## （Phase 2 fire-and-forget 自动存档）。带调用计数供断言。

## auto_save 是否被调用过（先例命名 auto_save_called）。
var auto_save_called: bool = false

## auto_save 调用计数（先例命名 auto_save_call_count）。
var auto_save_call_count: int = 0


func auto_save() -> void:
	auto_save_called = true
	auto_save_call_count += 1
