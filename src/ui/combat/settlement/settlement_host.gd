class_name SettlementHost
extends Control
## SettlementHost —— 结算/撤退/渡劫警示三面板的宿主接线（combat-ui-layout Story 008）。
##
## [b]职责[/b]：把三类面板挂到战斗场景，并把信号源接到面板上——
## [signal CombatSystem.battle_ended]（VICTORY → 战利品面板 / DEFEAT → 战败摘要）、
## [signal CombatSystem.retreat_requested]（→ 撤退确认弹窗）、撤退按钮点击
## （→ 撤退确认弹窗）、渡劫战前的战前警示（→ warning 弹窗）。判定与文案全部
## 委托 [SettlementRules] / [RetreatRules]（Logic 内核，BLOCKING 单测）。[br]
## [br][b]零状态所有权[/b]（ADR-0031 §2）：不缓存战斗/卡组/角色状态——卡组张数
## 每次按注入依赖现读（[code]SettlementHostData[/code]），面板内容按信号载荷重建。[br]
## [br][b]零轮询[/b]（ADR-0031 §3）：无 [code]_process()[/code]——信号与输入驱动。[br]
## [br][b]不自动关闭[/b]（AC-10）：三面板只由玩家点击关闭；本宿主不设自动关闭路径。[br]
## [br][b]持久写入归 interaction epic[/b]（Out of Scope）：本宿主只把面板的
## 确认/跳过/返回转发成同名信号，不调 loot 应用 / retreat 执行 API。[br]
## [br][b]各件各有其家[/b]：面板的建与信号回流归 [SettlementHostPanels]、奖励中文行与
## 掷骰缓存归 [SettlementGrantLines]、战斗系统信号接线归 [SettlementHostSignals]、
## 面板开合的焦点记忆归 [SettlementFocusRestore]、纯数据整形归
## [SettlementHostData]。本类只管「信号进来 → 该谁开面板 → 该发什么信号出去」。[br]
## [br][b]为什么面板句柄仍写在本类属性上[/b]：它们是场景挂载侧与测试的既有读窗口
## （[code]host.settlement_panel[/code] / [code]retreat_dialog[/code] /
## [code]tribulation_warning[/code]）——建造方是面板件，所有权仍在本类这一处。[br]
## [br][b]为什么 [_lines] 在字段处就建好[/b]：它不碰场景树、构造即可用——未入树就被
## 直调的路径（headless 用例、手动调试脚本）因此不会撞上 null。
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §9/§10、
## combat-ui-layout Story 008（AC-1~AC-10）。

const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")
const Retreat := preload("res://src/ui/combat/shared/retreat_rules.gd")
## 数据快照与载荷构建工具（拆分自宿主——行数预算）。
const Data := preload("res://src/ui/combat/settlement/settlement_host_data.gd")
## 奖励中文行与掷骰缓存（拆分自宿主——行数预算）。
const Lines := preload("res://src/ui/combat/settlement/settlement_grant_lines.gd")
## 三面板的构建与信号回流（拆分自宿主——行数预算）。
const Panels := preload("res://src/ui/combat/settlement/settlement_host_panels.gd")
## 战斗系统信号接线（拆分自宿主——行数预算）。
const Signals := preload("res://src/ui/combat/settlement/settlement_host_signals.gd")
## 面板开合的焦点记忆（拆分自宿主——行数预算）。
const FocusRestore := preload(
		"res://src/ui/combat/settlement/settlement_focus_restore.gd")

## === 信号（对外出口——持久写入/转场归 interaction epic）====================

## 战利品已选中（高亮，非确认）。
signal loot_selected(option_index: int)
## 战利品确认选择（interaction epic 据此写卡组）。
signal loot_confirmed(option_index: int)
## 战利品全部跳过。
signal loot_skipped()
## 战败面板确认返回探索。
signal defeat_confirmed()
## 撤退确认（interaction epic 据此调 CombatSystem.confirm_retreat）。
signal retreat_confirmed()
## 撤退取消（继续战斗）。
signal retreat_cancelled()
## 渡劫战前确认进战。
signal pre_battle_confirmed()
## 渡劫战前返回（停留备战界面）。
signal pre_battle_cancelled()

## === 依赖注入（全部可空——缺失时面板仍可渲染，仅数据退化）=================

## 战斗系统（battle_ended / retreat_requested 信号源）。
var combat_system: Node = null
## 卡组系统（张数/上限读取——[code]get_deck_summary()[/code]）。
var deck_system: Node = null
## 是否渡劫战（由战斗进入参数注入——AC-7 变体切换的唯一开关）。
var is_tribulation: bool = false
## 减少动态偏好（三面板统一）。
var reduce_motion: bool = false

## === 子面板 ===============================================================

## 胜利/战败结算面板（由 [member _panels] 建并写回）。
var settlement_panel: Control = null
## 撤退确认弹窗（同上）。
var retreat_dialog: Control = null
## 渡劫战前警示弹窗（同上）。
var tribulation_warning: Control = null

## 战斗系统信号接线（[method setup] 建——持「连过谁」的换源账）。
var _signals: RefCounted = null
## 面板开合的焦点记忆窗口（不碰场景树——字段处建好，未入树被直调也不撞 null）。
var _focus: RefCounted = FocusRestore.new()
## 是否已在本场确认过渡劫战前警示（防重复拦）。
var _pre_battle_confirmed: bool = false
## 战败上下文（阵亡角色名与绑定卡张数——由场景挂载侧在战斗结束时注入，
## 或随 [code]battle_ended[/code] 载荷下发；本宿主不自行推算阵亡名单）。
var _dead_names: Array = []
var _dead_binding_card_count: int = 0
## 奖励中文行与掷骰缓存（本类只转发——见 [SettlementGrantLines]）。[br]
## [br][b]在字段处就建好[/b]：它不碰场景树，构造即可用——这样未入树就被直调的
## 路径（headless 用例、手动调试脚本）不会撞上 null。
var _lines: RefCounted = Lines.new()
## 三面板的构建与信号回流（[method _ready] 建——建面板要宿主已入树）。
var _panels: RefCounted = null


func _ready() -> void:
	name = "SettlementHost"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panels = Panels.new(self, Callable(self, &"_on_loot_confirmed"),
		Callable(self, &"_on_loot_skipped"), Callable(_focus, &"restore"),
		Callable(self, &"_on_pre_battle_confirmed"))
	_panels.call(&"build", reduce_motion)


## 注入依赖并接线信号（场景挂载侧调用；可重复调用——幂等，[b]含换源[/b]：
## 重新 setup 到另一战斗系统时会先断开旧源，避免一次战斗开两次面板）。[br]
## [param p_combat_system]: 战斗系统（含 [code]battle_ended[/code] /
## [code]retreat_requested[/code] 信号）。[br]
## [param p_deck_system]: 卡组系统（含 [code]get_deck_summary()[/code]）。[br]
## [param p_is_tribulation]: 是否渡劫战。
func setup(p_combat_system: Node, p_deck_system: Node = null,
		p_is_tribulation: bool = false) -> void:
	combat_system = p_combat_system
	deck_system = p_deck_system
	is_tribulation = p_is_tribulation
	_connect_signals()


## 依赖是否已注入（生产路径守卫）。
func has_sources() -> bool:
	return combat_system != null


## 设置 reduce_motion（三面板统一——测试与设置变更时调用）。
func set_reduce_motion(value: bool) -> void:
	reduce_motion = value
	if _panels != null:
		_panels.call(&"apply_reduce_motion", value)


# ═══════════════════════════════════════════════════════════════════════════════
# 触发入口（信号驱动——无轮询）
# ═══════════════════════════════════════════════════════════════════════════════

## 战斗结束信号处理——按结果开对应面板（AC-2）。[br]
## [param result]: [code]CombatSystem.CombatResult[/code] 取值。[br]
## [param rewards]: 胜利时为掷骰奖励 [code]{lingshi, lingshi_min, lingshi_max,
## cultivation, cards, cards_missed, cards_failed, ...}[/code]（尚未发放）；
## 战败/撤退为 [code]{retain_ratio}[/code]。[br]
## [br][b]战利品 vs 奖励汇总[/b]：[code]cards[/code] / [code]lingshi[/code] 尚未到账，
## 面板把它们列成「本次奖励：N 选 1」供玩家选择（N 即实际候选数，见
## [code]SettlementSectionText.loot_pick_title[/code]）；「实得/未抽到/未入库」
## 的全文由 [code]CombatRewardLines[/code] 以汇总行呈现——两处读同一份载荷，
## 且面板里后者排在网格[b]之后[/b]（玩家先挑，再看到手了什么）。
func on_battle_ended(result: int, rewards: Dictionary = {}) -> void:
	var kind: StringName = Rules.panel_kind_for(result)
	if kind != Rules.KIND_NONE:
		# 开面板前记下焦点（关闭时还给原处——见 [SettlementFocusRestore]）
		_focus.call(&"remember")
	if kind == Rules.KIND_VICTORY:
		_lines.call(&"remember_rolled", rewards)
		var counts: Dictionary = Data.deck_counts(deck_system)
		var options: Array = Data.victory_options(rewards)
		# 候选为空时直接显示汇总（不建三选一格子）
		if options.is_empty():
			var lines: Array = _lines.call(&"empty_option_lines", rewards)
			settlement_panel.show_victory(options, int(counts["count"]),
					int(counts["limit"]), lines)
			# 直接切换到汇总视图
			settlement_panel.show_grant_summary(lines)
		else:
			var lines: Array = _lines.call(&"victory_lines", rewards)
			settlement_panel.show_victory(options, int(counts["count"]),
					int(counts["limit"]), lines)
	elif kind == Rules.KIND_DEFEAT:
		settlement_panel.show_defeat(Data.defeat_summary(rewards, _dead_names,
				_dead_binding_card_count))
	# RETREAT 由撤退确认流程自行收尾（interaction epic），此处不另开面板


## 撤退按钮点击（右上角常驻按钮的点击入口——AC-9）。[br]
## [br]打开撤退确认弹窗；渡劫战走红框 80% 变体（AC-7）。
func request_retreat() -> void:
	_focus.call(&"remember")
	retreat_dialog.open(is_tribulation, _dead_binding_card_count)


## 撤退请求信号（[signal CombatSystem.retreat_requested]）处理——
## 与按钮点击同源，同样打开确认弹窗。
func on_retreat_requested() -> void:
	request_retreat()


## 渡劫战前警示（备战界面之上——AC-8）。[br]
## [br]仅在渡劫战且本场未确认过时弹出（[method RetreatRules.should_show_pre_battle_warning]）。[br]
## [br][b]返回[/b]: 是否真的弹出了弹窗。
func show_pre_battle_warning() -> bool:
	if not Retreat.should_show_pre_battle_warning(is_tribulation, _pre_battle_confirmed):
		return false
	_focus.call(&"remember")
	tribulation_warning.open()
	return true


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：焦点记忆（转发 [SettlementFocusRestore]——为什么记在宿主见该类文档）
# ═══════════════════════════════════════════════════════════════════════════════

## 注入共享的焦点记忆（场景挂载侧在建完焦点链后调用一次）。
func set_focus_memory(p_memory: RefCounted) -> void:
	_focus.call(&"set_memory", p_memory)


## 焦点记忆实例（未注入为 null——测试探针）。
func focus_memory() -> RefCounted:
	return _focus.call(&"memory")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：接线
# ═══════════════════════════════════════════════════════════════════════════════

## 连接战斗系统信号（转发接线件——幂等与换源见 [SettlementHostSignals]）。
func _connect_signals() -> void:
	if _signals == null:
		_signals = Signals.new(Callable(self, &"on_battle_ended"),
			Callable(self, &"on_retreat_requested"))
	_signals.call(&"bind", combat_system)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：战败上下文注入
# ═══════════════════════════════════════════════════════════════════════════════

## 注入战败上下文（阵亡角色名 / 绑定卡张数——单场战斗一次性下发）。[br]
## [br][b]时机[/b]：战斗结束前后由场景挂载侧调用（本宿主不轮询战斗状态）。
func set_defeat_context(dead_names: Array, binding_card_count: int) -> void:
	_dead_names = dead_names.duplicate()
	_dead_binding_card_count = maxi(binding_card_count, 0)


## 已阵亡角色的绑定卡张数（面板正文用——注入值）。
func _binding_card_count() -> int:
	return _dead_binding_card_count


## 销毁时断开信号源（战斗系统是共享信号源——不摘会对着已释放的宿主开火）。[br]
## [br][b]顺序无关[/b]：接线件自己记着「连过谁」，故这里不必先判 null。
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _signals != null:
		_signals.call(&"release")


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：面板回调（全部由 [member _panels] 在构建时接上）
# ═══════════════════════════════════════════════════════════════════════════════

## 战利品确认——调用 CombatSystem.grant_reward_selection 发放奖励。[br]
## [param index] 玩家选择的卡牌索引（-1 表示跳过卡牌）。
func _on_loot_confirmed(index: int) -> void:
	if combat_system == null or not combat_system.has_method(&"grant_reward_selection"):
		loot_confirmed.emit(index)
		return
	var result: Dictionary = combat_system.call(&"grant_reward_selection", index)
	# 发放后刷新为「已到账汇总」视图
	_show_grant_summary(result)
	loot_confirmed.emit(index)


## 战利品跳过——调用 CombatSystem.grant_reward_selection(-1) 只发灵石+修为。
func _on_loot_skipped() -> void:
	if combat_system == null or not combat_system.has_method(&"grant_reward_selection"):
		loot_skipped.emit()
		return
	var result: Dictionary = combat_system.call(&"grant_reward_selection", -1)
	_show_grant_summary(result)
	loot_skipped.emit()


## 渡劫战前警示确认——钉「本场已确认」位后转发（[member _panels] 接在
## [signal TribulationWarningDialog.battle_confirmed] 上）。
func _on_pre_battle_confirmed() -> void:
	_pre_battle_confirmed = true
	pre_battle_confirmed.emit()


## 显示「已到账汇总」视图——战利品网格隐藏，只显示奖励汇总行。[br]
## [param result] grant_reward_selection 的返回值。
func show_grant_summary(result: Dictionary) -> void:
	_show_grant_summary(result)


## 内部实现——生成汇总行并调用面板。
func _show_grant_summary(result: Dictionary) -> void:
	settlement_panel.show_grant_summary(_lines.call(&"granted_lines", result))


## 渡劫金卡奖励行（对外窗口——[method SettlementGrantLines.tribulation_lines] 的转发）。[br]
## [br][b]为什么留一个同名方法[/b]：它是既有的对外读窗口（渡劫结算屏与测试都走它），
## 实现整体搬进了 [SettlementGrantLines]——这里只把问题转过去，不另写一份口径。
func tribulation_reward_lines(p_rewards: Dictionary) -> Array:
	return _lines.call(&"tribulation_lines", p_rewards)
