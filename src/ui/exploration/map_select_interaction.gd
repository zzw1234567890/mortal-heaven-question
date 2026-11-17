extends RefCounted
## MapSelectInteraction —— 卡片点击的[b]落地效果[/b]：进图 / 重入确认 / 条件提示
## （从 [MapSelectScreen] 拆出）。[br]
## [br][b]为什么单独一处[/b]：屏幕脚本已贴 300 行软上限
## （.claude/docs/coding-standards.md），而「分流决策算出之后该发生什么」与「列表怎么取、
## 卡片怎么建」是两件事（同 [code]map_select_data.gd[/code] /
## [code]map_select_reentry_dialog.gd[/code] 拆分先例）。[br]
## [br][b]决策不在这里[/b]：点哪张卡走哪条路是屏幕的 static 纯函数
## （[code]MapSelectScreen.entry_action[/code]——单测锁的就是它），本模块只消费它的
## 结果。于是「路由判错」与「路由对了但什么都没发生」是两处各自可测的缺陷。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：本模块不扣灵石、不写 GSM、不生成地图
## ——重入的扣费与拒绝归 Feature 层（[code]ExplorationReentry[/code]），进图归探索
## 系统。这里发出的仍然只是[b]意图[/b]。[br]
## [br][b]重入弹窗的待办 ID 落在这里[/b]：它是「弹窗打开期间」的瞬态状态
## （ADR-0031 §2.1），与弹窗同生共死——放在屏幕字段上会让「谁负责清理」变得含糊。[br]
## [br][b]文案本地化豁免[/b]：与各 [code]TEXT_*[/code] 同源口径（项目暂无本地化系统）。[br]
##
## 来源: design/gdd/exploration-ui-system.md §1 地图选择界面 / §6 重入确认弹窗、
## ADR-0031 §2/§2.1、ADR-0004（改变状态的点击过输入锁栈）、
## .claude/rules/ui-code.md。

## 数据读取面（灵石余额与输入锁栈判定——只读，见 [MapSelectData]）。
const DataScript := preload("res://src/ui/exploration/map_select_data.gd")
## 重入确认弹窗的文案填充（见 [MapSelectReentryDialog]）。
const DialogScript := preload("res://src/ui/exploration/map_select_reentry_dialog.gd")
## 未解锁卡的中文提示出口（见 [MapSelectNotice]）。
const NoticeScript := preload("res://src/ui/exploration/map_select_notice.gd")

## 分流决策的取值镜像——[code]MapSelectScreen.EntryAction[/code] 是真理来源，
## 两处不互相引用以免 preload 循环（同 [code]MapCard.is_unlocked_card[/code] 与
## [code]should_show_lock[/code] 的豁免注记口径）。
const ACT_IGNORE: int = 0   ## 无操作（锁定卡 / 已通关不可重入）
const ACT_REENTER: int = 1  ## 弹重入确认窗（已通关可重入）
const ACT_ENTER: int = 2    ## 直接进入（未通关 + 境界达标）

## 宿主屏幕（[code]notify_cb[/code] / 注入系统的读取锚点，也是弹窗控件的来源）。
var _host: Node = null
## 进图意图出口 [code]func(map_id: StringName) -> void[/code]。
var _enter: Callable = Callable()
## 重入意图出口 [code]func(map_id: StringName) -> void[/code]。
var _reentry: Callable = Callable()
## 重入确认弹窗与其控件（由宿主注入——本模块不按控件路径查找）。
var _dialog: ConfirmationDialog = null
var _map_label: Label = null
var _cost_label: Label = null
var _balance_label: Label = null
var _warn_label: Label = null
var _ok_button: Button = null
## 待重入地图 ID（弹窗打开期间——确认或取消后清空）。
var _pending_id: StringName = &""
## 数据读取面（惰性构建——绑定宿主之前建不了）。
var _data: RefCounted = null
## 弹窗文案填充器（惰性构建——首次弹窗时绑定控件）。
var _filler: RefCounted = null


## 接线——注入宿主、弹窗控件与两个意图出口（宿主 [code]_ready[/code] 后调一次）。[br]
## [br][b]出口用 Callable 而不是直接引用屏幕[/b]：本模块不必知道屏幕有哪些信号，
## 只负责「该发哪个意图」——换一个宿主（别的选图界面）时不必改这里。
func bind(p_host: Node, p_dialog: ConfirmationDialog, p_map_label: Label,
		p_cost_label: Label, p_balance_label: Label, p_warn_label: Label,
		p_ok_button: Button, p_enter: Callable, p_reentry: Callable) -> void:
	_host = p_host
	_dialog = p_dialog
	_map_label = p_map_label
	_cost_label = p_cost_label
	_balance_label = p_balance_label
	_warn_label = p_warn_label
	_ok_button = p_ok_button
	_enter = p_enter
	_reentry = p_reentry


## 消费一次卡片点击。[br]
## [br][param p_action] 屏幕的分流决策（[code]MapSelectScreen.entry_action[/code]）。[br]
## [param p_entry] 被点击的地图条目。[br]
## [param p_can_confirm] 重入确认按钮是否启用（屏幕的
## [code]can_confirm_reentry[/code] 判定结果——灵石够不够）。[br]
## [br][b]改变游戏状态的分支先过输入锁栈[/b]（ADR-0004）：进入与重入都会改变玩法
## 状态，被锁时静默不放行；条件提示是纯展示，不受锁影响。[br]
## [br][b]返回[/b]：实际走了哪条路（[constant ACT_IGNORE] / [constant ACT_REENTER] /
## [constant ACT_ENTER] 之一；被输入锁拦下时为 [constant ACT_IGNORE]——测试断言用）。
func activate(p_action: int, p_entry: Dictionary, p_can_confirm: bool) -> int:
	match p_action:
		ACT_REENTER:
			if not _is_input_allowed():
				return ACT_IGNORE
			_show_dialog(p_entry, p_can_confirm)
			return ACT_REENTER
		ACT_ENTER:
			if not _is_input_allowed():
				return ACT_IGNORE
			_emit(_enter, StringName(str(p_entry.get(&"map_id", ""))))
			return ACT_ENTER
		_:
			# 锁定卡给中文条件提示；已通关不可重入（苍玄古战场）是设计而非缺陷，
			# [method MapSelectNotice.notify_locked] 对它不出声。
			NoticeScript.notify_locked(_host, p_entry)
			return ACT_IGNORE


## 确认重入——发出重入意图（扣费与进图归 Feature 层）。[br]
## [br][b]返回[/b]：是否真的发出了意图（没有待办 ID / 已过输入锁栈时为 false）。[br]
## [br][b]待办 ID 一律清空[/b]：无论放不放行，这次确认都算消费掉了——留着会让下一次
## 弹窗在未被点击时就能确认。
func confirm() -> bool:
	var map_id: StringName = _pending_id
	_pending_id = &""
	if map_id.is_empty() or not _is_input_allowed():
		return false
	_emit(_reentry, map_id)
	return true


## 取消重入——丢弃待办 ID（弹窗取消按钮 / 关闭时走这里）。[br]
## [br][b]返回[/b]：被丢弃的地图 ID（空串 = 本来就没有待办——测试断言用）。
func cancel() -> StringName:
	var map_id: StringName = _pending_id
	_pending_id = &""
	return map_id


## 当前待重入的地图 ID（空串 = 弹窗未开或已确认/取消——测试与宿主查询用）。
func pending_id() -> StringName:
	return _pending_id


## 刷新弹窗内显示的余额（弹窗开着时灵石变化——GSM resource_changed 驱动）。[br]
## [br][b]弹窗未开时什么都不做[/b]：判断也交给填充器，免得两处各写一遍
## [code]dialog.visible[/code] 检查。
func refresh_balance(p_ling_shi: int) -> void:
	_filler_ref().call(&"refresh_balance", p_ling_shi)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部
# ═══════════════════════════════════════════════════════════════════════════════

## 弹出重入确认窗（记下待办 ID 再填文案——顺序反了会让「确认」读到一个空 ID）。[br]
## [br][b]灵石余额现取[/b]：弹窗上的「当前灵石」与费用对比必须与玩家此刻身上的一致，
## 不缓存屏幕上一次刷新时的值。
func _show_dialog(p_entry: Dictionary, p_can_confirm: bool) -> void:
	_pending_id = StringName(str(p_entry.get(&"map_id", "")))
	_filler_ref().call(&"show_for", p_entry, int(_data_ref().call(&"ling_shi")),
			p_can_confirm)


## 弹窗文案填充器（惰性构建 + 绑定弹窗控件）。
func _filler_ref() -> RefCounted:
	if _filler == null:
		_filler = DialogScript.new()
		_filler.call(&"bind", _dialog, _map_label, _cost_label, _balance_label,
				_warn_label, _ok_button)
	return _filler


## 数据读取面（惰性构建——宿主为本模块的注入锚点）。
func _data_ref() -> RefCounted:
	if _data == null:
		_data = DataScript.new(_host)
	return _data


## 输入锁栈判定——改变游戏状态的点击必须过 InputManager（ADR-0004）。
func _is_input_allowed() -> bool:
	return bool(_data_ref().call(&"input_allowed"))


## 发一个意图（出口未接线时静默跳过——缺一条接线不该变成崩溃）。
func _emit(p_sink: Callable, p_map_id: StringName) -> void:
	if p_sink.is_valid():
		p_sink.call(p_map_id)
