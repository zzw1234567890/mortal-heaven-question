class_name CorruptSaveDialog
extends AcceptDialog
## CorruptSaveDialog —— 存档损坏提示组件（main-menu Story 003 前置拆分）。
##
## [b]拆分来源[/b]：story-002 记账项「main_menu.gd 308 行超 300 软限」——
## 将损坏对话框流程（[method show_corrupt] / confirmed 信号路由）从
## [MainMenu] 抽为本独立 Control 组件（约 -25 行回到安全线内）。[br]
## [br][b]重入守卫[/b]（story-001 code-review H-3 修复——[signal save_corrupted] +
## [code]load_game[/code] 返回值在同一调用栈内双触发）：[method show_corrupt]
## 内 [code]if visible: return[/code] 防双弹。[br]
## [br][b]弹出机制[/b]：[method popup_centered]（AcceptDialog 为 Window 子类——
## 禁用 [code]show()[/code] 不会正确弹出模态框）。[br]
## [br][b]confirmed 信号路由[/b]：.tscn [connection] 维持——由宿主 [MainMenu]
## 连接 [signal confirmed] 到 [method MainMenu._on_corrupt_dialog_confirmed]
## （刷新存档状态——此逻辑留在 MainMenu 因其需访问 SaveLoadSystem）。
##
## @experimental
## 来源: story-001 code-review H-3、story-003 Implementation Notes（前置拆分）。

## 固定 UI 词条（本地化豁免注记——先例 MainMenu.TEXT_CORRUPTED）。
const TEXT_CORRUPTED: String = "存档损坏，无法读取"

func _ready() -> void:
	dialog_text = TEXT_CORRUPTED

## 弹「存档损坏，无法读取」提示（GDD 边缘情况 + UX「存档读取失败」状态）。[br]
## [br][b]重入守卫[/b]：[code]if visible: return[/code] 防双弹
## （story-001 code-review H-3——save_corrupted 信号 + load_game 返回值
## 同栈双触发）。[br]
## [b]弹出机制[/b]：[method popup_centered]（AcceptDialog 模态正确弹出路径——
## 禁用 [code]show()[/code]）。
func show_corrupt() -> void:
	if visible:
		return  # H-3 重入守卫——防同栈双触发双弹
	dialog_text = TEXT_CORRUPTED
	popup_centered()