class_name SettlementHostPanels
extends RefCounted
## SettlementHostPanels —— 结算宿主的三面板构建与信号回流（拆分自 settlement_host）。[br]
##
## [b]职责[/b]：建三块面板（战利品 / 战败结算、撤退确认、渡劫战前警示），把它们挂进
## 宿主，并把面板自己的信号接回宿主——[br]
##   · 出口类（可直接转发）：[code]loot_selected[/code] / [code]defeat_confirmed[/code] /
##     [code]retreat_confirmed[/code] / [code]retreat_cancelled[/code] /
##     [code]pre_battle_confirmed[/code] / [code]pre_battle_cancelled[/code]；[br]
##   · 回调类（宿主还要做事）：战利品确认 / 跳过（要调发放 API）、三条关闭路径
##     （要还焦点）、渡劫战前确认（要钉「本场已确认」位）。[br]
## [b]不管什么[/b]：不判定胜负、不组装文案、不调发放 API、不知道焦点该还给谁
## ——回调全部由宿主注入。[br]
## [br][b]为什么单独成文件[/b]：三面板的建与接是一整块「UI 装配」职责，
## 与宿主的信号注入 / 焦点记忆 / 文案组装是不同的事；[code]settlement_host.gd[/code]
## 挤在一起时超出 300 行软上限（编码标准）。[br]
## [br][b]为什么面板句柄写回宿主[/b]：面板是宿主的对外可见成员
## （[code]host.settlement_panel[/code] 等，场景挂载侧与测试都在读），故本件建好后
## 用 [method Object.set] 写回宿主自己的属性——所有权仍只有一处（宿主），
## 本件只是建造与接线的执行方。[br]
## [br][b]不自动关闭[/b]（AC-10）：三面板只由玩家点击关闭；本件不设任何自动关闭路径。
##
## 来源: combat-ui-layout Story 008（AC-1~AC-10）、design/gdd/combat-ui-system.md §9/§10、
## 拆分自 settlement_host（行数预算）。

const PanelScript := preload("res://src/ui/combat/settlement/settlement_panel.gd")
const RetreatScript := preload("res://src/ui/combat/settlement/retreat_dialog.gd")
const WarningScript := preload("res://src/ui/combat/settlement/tribulation_warning_dialog.gd")

## 宿主（[code]SettlementHost[/code]——面板挂进它，句柄写回它的属性）。[br]
## [br][b]为什么不标注类型[/b]：宿主 preload 本件，本件若反过来 preload 宿主就成环；
## 用 [Object] + [method Object.call] 走既有的「按方法名问」口径（同
## [code]CombatFocusLogLink[/code] 对顶栏的做法）。
var _host: Object = null
## 战利品确认回调（宿主注入——要调 [code]grant_reward_selection[/code]）。
var _on_loot_confirmed: Callable = Callable()
## 战利品跳过回调（同上）。
var _on_loot_skipped: Callable = Callable()
## 三条关闭路径的共用出口（宿主注入——关闭后还焦点）。
var _on_closed: Callable = Callable()
## 渡劫战前确认回调（宿主注入——钉「本场已确认」位）。
var _on_pre_battle_confirmed: Callable = Callable()


## 构造——注入宿主与四个回调（宿主在 [method Node._ready] 里建，回调指向自己的方法）。
func _init(p_host: Object, p_on_loot_confirmed: Callable, p_on_loot_skipped: Callable,
		p_on_closed: Callable, p_on_pre_battle_confirmed: Callable) -> void:
	_host = p_host
	_on_loot_confirmed = p_on_loot_confirmed
	_on_loot_skipped = p_on_loot_skipped
	_on_closed = p_on_closed
	_on_pre_battle_confirmed = p_on_pre_battle_confirmed


## === 构建 =====================================================================

## 构建三面板、挂进宿主、接线并写回句柄。[br]
## [br][param p_reduce_motion] 构建后统一下发（setup / 入树前设置的值不被子面板
## 默认值吞掉——故这一步必须排在句柄写回之后）。
func build(p_reduce_motion: bool) -> void:
	_build_settlement(p_reduce_motion)
	_build_retreat(p_reduce_motion)
	_build_warning(p_reduce_motion)


## 三面板各自的 [member Control.reduce_motion]（统一下发——测试与设置变更时用）。
func apply_reduce_motion(p_value: bool) -> void:
	for panel: Variant in [panel(), retreat(), warning()]:
		if panel != null:
			(panel as Object).set(&"reduce_motion", p_value)


## 战利品/战败结算面板（未建为 null——测试探针）。
func panel() -> Control:
	return _host.get(&"settlement_panel") as Control


## 撤退确认弹窗（未建为 null——测试探针）。
func retreat() -> Control:
	return _host.get(&"retreat_dialog") as Control


## 渡劫战前警示弹窗（未建为 null——测试探针）。
func warning() -> Control:
	return _host.get(&"tribulation_warning") as Control


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：逐面板
# ═══════════════════════════════════════════════════════════════════════════════

## 战利品 / 战败结算面板。[br]
## [br][b]四条关闭路径共用 [code]closed[/code] 一个出口[/b]（见
## [signal SettlementPanel.closed]）：把还焦点接在出口上，就不必在每块面板里各写一遍。
func _build_settlement(p_reduce_motion: bool) -> void:
	var node: Control = PanelScript.new()
	node.name = "SettlementPanel"
	node.call(&"set_anchors_and_offsets_preset", Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.call(&"add_child", node)
	node.set(&"reduce_motion", p_reduce_motion)
	node.connect(&"loot_selected", func(i: int) -> void:
		_host.emit_signal(&"loot_selected", i))
	node.connect(&"loot_confirmed", _on_loot_confirmed)
	node.connect(&"loot_skipped", _on_loot_skipped)
	node.connect(&"defeat_confirmed", func() -> void:
		_host.emit_signal(&"defeat_confirmed"))
	node.connect(&"closed", _on_closed)
	_host.set(&"settlement_panel", node)


## 撤退确认弹窗。[br]
## [br][b]确认路径走宿主的方法而不是直调 [code]close_dialog[/code][/b]：直调只关面板
## 不发信号，上层（场景容器）就收不到「玩家放弃撤退」——同一件事留两条路径，
## 迟早只走通一条（Esc 路由那头有同一条注释）。
func _build_retreat(p_reduce_motion: bool) -> void:
	var node: Control = RetreatScript.new()
	node.name = "RetreatDialog"
	node.call(&"set_anchors_and_offsets_preset", Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.call(&"add_child", node)
	node.set(&"reduce_motion", p_reduce_motion)
	node.connect(&"retreat_confirmed", func() -> void:
		_host.emit_signal(&"retreat_confirmed"))
	node.connect(&"retreat_cancelled", func() -> void:
		_host.emit_signal(&"retreat_cancelled"))
	node.connect(&"dialog_closed", _on_closed)
	_host.set(&"retreat_dialog", node)


## 渡劫战前警示弹窗。[br]
## [br][b]「已确认」位归宿主[/b]：它是宿主的本场状态（防重复拦），故在这里回调
## 宿主去钉——本件不认识这个位的语义。
func _build_warning(p_reduce_motion: bool) -> void:
	var node: Control = WarningScript.new()
	node.name = "TribulationWarning"
	node.call(&"set_anchors_and_offsets_preset", Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.call(&"add_child", node)
	node.set(&"reduce_motion", p_reduce_motion)
	node.connect(&"battle_confirmed", _on_pre_battle_confirmed)
	node.connect(&"battle_cancelled", func() -> void:
		_host.emit_signal(&"pre_battle_cancelled"))
	node.connect(&"dialog_closed", _on_closed)
	_host.set(&"tribulation_warning", node)
