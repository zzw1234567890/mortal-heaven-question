extends Node
## SaveLoadSystem mock——测试 ProgressionSystem 时替换 SaveLoadSystem。[br]
## [br]模拟 load_progression() 行为：返回预设数据或空字典。[br]
## [br]来源: ADR-0012 §关键接口 initialize(data) 参数来源。

## 跨局数据变更信号——测试中 ProgressionSystem 发射、mock 监听。
signal progression_updated(domain: String)

## 预设 progression 数据——测试设置。
var _progression_data: Dictionary = {}

## load_progression() 调用计数——测试验证。
var load_call_count: int = 0

## 模拟 SaveLoadSystem 是否在 progression_updated 回调中检测到 dirty。
var _save_called: bool = false


func load_progression() -> Dictionary:
	load_call_count += 1
	return _progression_data.duplicate(true)
