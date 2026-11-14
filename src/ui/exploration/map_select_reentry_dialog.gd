extends RefCounted
## MapSelectReentryDialog —— 重入确认弹窗的文案与启用态填充（从 MapSelectScreen 拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕脚本已超 300 行软上限，而「弹窗里放什么字、确认
## 按钮能不能点」与「列表怎么取、点击怎么分流」是两件事（同
## [code]map_select_data.gd[/code] / [code]map_select_animator.gd[/code] 拆分先例）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不持有条目、不算费用、不写 GSM
## ——[method show_for] 收到的 [param p_entry] 已含 [code]reentry_total[/code] /
## [code]reentry_base[/code] / [code]reentry_multiplier[/code]（Feature 层算好），
## 本模块只把它们填进标签。[br]
## [br][b]启用态判定不重复实现[/b]：走屏幕的 [code]can_confirm_reentry[/code]
## 静态纯函数（灵石够不够 + 是否可重入——UI 侧唯一判定口径，单测锁的是它）。[br]
## [br][b]文案本地化豁免[/b]：与 S16-1/S16-2 各 TEXT_* 同源口径（项目暂无本地化系统）。[br]
##
## 来源: exploration-ui Story S16-2 AC-4 / §6 重入确认弹窗、ADR-0031 §2、
## design/gdd/exploration-ui-system.md §1。

## 弹窗内文案（与屏幕标题类常量同源口径——只在需要它的地方定义）。
const TEXT_MAP_LINE: String = "地图：%s（已通关）"
const TEXT_COST_DETAIL: String = "传送费用：%d灵石（基础价 %d × 倍率 %d）"
const TEXT_CURRENT_BALANCE: String = "当前灵石：%d"
const TEXT_CONFIRM_WARN: String = "重入地图将消耗%d灵石并生成新的节点图"
const TEXT_CONFIRM: String = "确认传送"
const TEXT_INSUFFICIENT: String = "灵石不足"

## 弹窗控件引用（宿主屏幕注入——本模块不按控件路径查找）。
var _dialog: ConfirmationDialog = null
var _map_label: Label = null
var _cost_label: Label = null
var _balance_label: Label = null
var _warn_label: Label = null
var _ok_button: Button = null


## 绑定弹窗与其内部控件（宿主 [code]_ready[/code] 或首次使用时调用一次）。
func bind(p_dialog: ConfirmationDialog, p_map_label: Label, p_cost_label: Label,
		p_balance_label: Label, p_warn_label: Label, p_ok_button: Button) -> void:
	_dialog = p_dialog
	_map_label = p_map_label
	_cost_label = p_cost_label
	_balance_label = p_balance_label
	_warn_label = p_warn_label
	_ok_button = p_ok_button


## 弹出重入确认窗——地图名 + 明细（基础价 × 倍率）+ 当前灵石 + 确认/取消。[br]
## [br][param p_entry] 地图条目（[code]get_map_list()[/code] 的单条）。[br]
## [param p_ling_shi] 当前灵石余额（由宿主只读取得后传入——本模块不查资源系统）。[br]
## [param p_can_confirm] 确认按钮是否启用（宿主用 [code]can_confirm_reentry[/code] 判定）。[br]
## [br][b]灵石不足[/b]：确认按钮灰显 + 按钮文案追加「（灵石不足）」——不靠颜色单独
## 表达不可点（色盲可读，.claude/rules/ui-code.md）。[br]
## [br][b]未绑定控件时静默返回[/b]：宿主未完成接线不应变成崩溃。
func show_for(p_entry: Dictionary, p_ling_shi: int, p_can_confirm: bool) -> void:
	if _dialog == null or not is_instance_valid(_dialog):
		return
	if _map_label != null:
		_map_label.text = TEXT_MAP_LINE % str(p_entry.get(&"name", "—"))
	if _cost_label != null:
		_cost_label.text = TEXT_COST_DETAIL % [
			int(p_entry.get(&"reentry_total", 0)),
			int(p_entry.get(&"reentry_base", 0)),
			int(p_entry.get(&"reentry_multiplier", 1)),
		]
	if _balance_label != null:
		_balance_label.text = TEXT_CURRENT_BALANCE % p_ling_shi
	if _warn_label != null:
		_warn_label.text = TEXT_CONFIRM_WARN % int(p_entry.get(&"reentry_total", 0))
	if _ok_button != null:
		_ok_button.disabled = not p_can_confirm
		_ok_button.text = TEXT_CONFIRM if p_can_confirm \
				else "%s（%s）" % [TEXT_CONFIRM, TEXT_INSUFFICIENT]
	_dialog.popup_centered()


## 刷新弹窗内显示的余额（弹窗开着时灵石变化——GSM resource_changed 驱动）。[br]
## [br][b]弹窗未开时不做任何事[/b]：宿主把「要不要刷」的判断也一并交给本方法，
## 免得两处各写一遍 [code]dialog.visible[/code] 检查。
func refresh_balance(p_ling_shi: int) -> void:
	if _dialog == null or not is_instance_valid(_dialog) or not _dialog.visible:
		return
	if _balance_label != null:
		_balance_label.text = TEXT_CURRENT_BALANCE % p_ling_shi
