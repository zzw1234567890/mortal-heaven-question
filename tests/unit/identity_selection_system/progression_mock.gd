extends Node
## ProgressionSystem mock——测试 IdentitySelectionSystem 时替换 ProgressionSystem。[br]
## [br]模拟 get_talent_tree_state() 行为：返回可注入的 unlocked 列表。[br]
## [br]来源: ADR-0022 §get_available_identities 依赖 ProgressionSystem。

## 已解锁的轮回天赋列表——测试设置（非类型化，允许测试注入任意 Array）。
var _unlocked_talents: Array = []


func get_talent_tree_state() -> Dictionary:
	return {
		"unlocked": _unlocked_talents.duplicate(),
		"equipped": [],
	}
