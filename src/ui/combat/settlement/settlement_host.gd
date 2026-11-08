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
## 每次按注入依赖现读（[method _deck_counts]），面板内容按信号载荷重建。[br]
## [br][b]零轮询[/b]（ADR-0031 §3）：无 [code]_process()[/code]——信号与输入驱动。[br]
## [br][b]不自动关闭[/b]（AC-10）：三面板只由玩家点击关闭；本宿主不设自动关闭路径。[br]
## [br][b]持久写入归 interaction epic[/b]（Out of Scope）：本宿主只把面板的
## 确认/跳过/返回转发成同名信号，不调 loot 应用 / retreat 执行 API。[br]
##
## @experimental
## 来源: ADR-0031、design/gdd/combat-ui-system.md §9/§10、
## combat-ui-layout Story 008（AC-1~AC-10）。

const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")
const Retreat := preload("res://src/ui/combat/shared/retreat_rules.gd")
const PanelScript := preload("res://src/ui/combat/settlement/settlement_panel.gd")
const RetreatScript := preload("res://src/ui/combat/settlement/retreat_dialog.gd")
const WarningScript := preload("res://src/ui/combat/settlement/tribulation_warning_dialog.gd")

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

## 胜利/战败结算面板。
var settlement_panel: Control = null
## 撤退确认弹窗。
var retreat_dialog: Control = null
## 渡劫战前警示弹窗。
var tribulation_warning: Control = null

## 已接线信号源的战斗系统（换源时先断开旧源——防一次战斗开两次面板）。
var _bound_combat_system: Node = null
## 是否已在本场确认过渡劫战前警示（防重复拦）。
var _pre_battle_confirmed: bool = false
## 战败上下文（阵亡角色名与绑定卡张数——由场景挂载侧在战斗结束时注入，
## 或随 [code]battle_ended[/code] 载荷下发；本宿主不自行推算阵亡名单）。
var _dead_names: Array = []
var _dead_binding_card_count: int = 0


func _ready() -> void:
	name = "SettlementHost"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_panels()


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


# ═══════════════════════════════════════════════════════════════════════════════
# 触发入口（信号驱动——无轮询）
# ═══════════════════════════════════════════════════════════════════════════════

## 战斗结束信号处理——按结果开对应面板（AC-2）。[br]
## [param result]: [code]CombatSystem.CombatResult[/code] 取值。[br]
## [param rewards]: 胜利时为 [code]{lingshi, cultivation, cards}[/code]；
## 战败/撤退为 [code]{retain_ratio}[/code]。
func on_battle_ended(result: int, rewards: Dictionary = {}) -> void:
	var kind: StringName = Rules.panel_kind_for(result)
	if kind == Rules.KIND_VICTORY:
		var counts: Dictionary = _deck_counts()
		settlement_panel.show_victory(_victory_options(rewards),
				int(counts["count"]), int(counts["limit"]))
	elif kind == Rules.KIND_DEFEAT:
		settlement_panel.show_defeat(_defeat_summary(rewards))
	# RETREAT 由撤退确认流程自行收尾（interaction epic），此处不另开面板


## 撤退按钮点击（右上角常驻按钮的点击入口——AC-9）。[br]
## [br]打开撤退确认弹窗；渡劫战走红框 80% 变体（AC-7）。
func request_retreat() -> void:
	retreat_dialog.open(is_tribulation, _binding_card_count())


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
	tribulation_warning.open()
	return true


## 设置 reduce_motion（三面板统一——测试与设置变更时调用）。
func set_reduce_motion(value: bool) -> void:
	reduce_motion = value
	for panel: Control in [settlement_panel, retreat_dialog, tribulation_warning]:
		if panel != null:
			panel.reduce_motion = value


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：接线
# ═══════════════════════════════════════════════════════════════════════════════

## 构建三面板（隐藏——由触发入口打开）。
func _build_panels() -> void:
	settlement_panel = PanelScript.new()
	settlement_panel.name = "SettlementPanel"
	settlement_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settlement_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(settlement_panel)
	settlement_panel.loot_selected.connect(func(i: int) -> void: loot_selected.emit(i))
	settlement_panel.loot_confirmed.connect(func(i: int) -> void: loot_confirmed.emit(i))
	settlement_panel.loot_skipped.connect(func() -> void: loot_skipped.emit())
	settlement_panel.defeat_confirmed.connect(func() -> void: defeat_confirmed.emit())

	retreat_dialog = RetreatScript.new()
	retreat_dialog.name = "RetreatDialog"
	retreat_dialog.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	retreat_dialog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(retreat_dialog)
	retreat_dialog.retreat_confirmed.connect(func() -> void: retreat_confirmed.emit())
	retreat_dialog.retreat_cancelled.connect(func() -> void: retreat_cancelled.emit())

	tribulation_warning = WarningScript.new()
	tribulation_warning.name = "TribulationWarning"
	tribulation_warning.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tribulation_warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tribulation_warning)
	tribulation_warning.battle_confirmed.connect(func() -> void:
		_pre_battle_confirmed = true
		pre_battle_confirmed.emit())
	tribulation_warning.battle_cancelled.connect(func() -> void:
		pre_battle_cancelled.emit())

	# 构建后统一继承当前 reduce_motion（setup/入树前设置的值不被子面板默认值吞掉）
	set_reduce_motion(reduce_motion)


## 连接战斗系统信号（幂等——重复 setup 不重复连；换源时先断开旧源）。
func _connect_signals() -> void:
	var cs: Node = combat_system
	if _bound_combat_system != null and _bound_combat_system != cs:
		_disconnect_source(_bound_combat_system)
	_bound_combat_system = cs
	if cs == null:
		return
	if cs.has_signal(&"battle_ended") and not cs.battle_ended.is_connected(on_battle_ended):
		cs.battle_ended.connect(on_battle_ended)
	if cs.has_signal(&"retreat_requested") \
			and not cs.retreat_requested.is_connected(on_retreat_requested):
		cs.retreat_requested.connect(on_retreat_requested)


## 断开旧信号源（换源 / 销毁时调用——只断本宿主连过的两个信号，
## 不碰同一信号上的其他连接者）。[br]
## [param source]: 之前接线过的战斗系统。
func _disconnect_source(source: Node) -> void:
	if source == null or not is_instance_valid(source):
		return
	if source.has_signal(&"battle_ended") and source.battle_ended.is_connected(on_battle_ended):
		source.battle_ended.disconnect(on_battle_ended)
	if source.has_signal(&"retreat_requested") \
			and source.retreat_requested.is_connected(on_retreat_requested):
		source.retreat_requested.disconnect(on_retreat_requested)


# ═══════════════════════════════════════════════════════════════════════════════
# 内部：数据快照（现读——不缓存）与载荷构建
# ═══════════════════════════════════════════════════════════════════════════════

## 卡组张数/上限（[code]get_deck_summary()[/code] 现读；缺失时 0/0）。[br]
## [br][b]返回[/b]: [code]{count, limit}[/code]。
func _deck_counts() -> Dictionary:
	var ds: Node = deck_system
	if ds == null or not ds.has_method(&"get_deck_summary"):
		return {"count": 0, "limit": 0}
	var summary: Dictionary = ds.call(&"get_deck_summary") as Dictionary
	if summary == null:
		return {"count": 0, "limit": 0}
	return {
		"count": int(summary.get("total", 0)),
		"limit": int(summary.get("limit", 0)),
	}


## 胜利面板的战利品选项（GDD §9「卡牌正面 / 灵石图标+数值 / 消耗品」）。[br]
## [br][b]不做战利品生成逻辑[/b]（Out of Scope）：只把战斗系统已给出的
## [code]cards[/code] / [code]lingshi[/code] / [code]consumables[/code] 映射成选项；
## 不足 3 项时按实际数量展示（不伪造填充项）。[br]
## [br][b]上游缺口[/b]：`CombatSystem._settle_result()` 暂不产出 `consumables`——
## 映射已就位，战斗系统补字段后无需改 UI（DEBT-CUI-008-3）。
func _victory_options(rewards: Dictionary) -> Array:
	var options: Array = _map_entries(rewards.get("cards", []), Rules.OPTION_KIND_CARD)
	var lingshi: int = int(rewards.get("lingshi", 0))
	if lingshi > 0:
		options.append({"kind": Rules.OPTION_KIND_LINGSHI, "amount": lingshi})
	options.append_array(_map_entries(rewards.get("consumables", []),
			Rules.OPTION_KIND_CONSUMABLE))
	return options


## 把一类奖励列表映射成战利品选项（字典深拷贝后补 kind；字符串退化为只带 name）。[br]
## [param entries]: 奖励列表（字典或字符串）。[br]
## [param kind]: [constant SettlementRules.OPTION_KIND_*] 取值。
func _map_entries(entries: Variant, kind: String) -> Array:
	var result: Array = []
	if not (entries is Array):
		return result
	for item: Variant in entries:
		if item is Dictionary:
			var entry: Dictionary = (item as Dictionary).duplicate(true)
			entry["kind"] = kind
			result.append(entry)
		elif item is String or item is StringName:
			result.append({"kind": kind, "name": str(item)})
	return result


## 战败损失摘要（AC-5）——阵亡名单与绑定卡张数由注入/载荷提供。[br]
## [br][b]数据源优先级[/b]：[param rewards] 载荷字段 > [method set_defeat_context]
## 注入的上下文 > 0/空（[b]不自行推算阵亡名单[/b]——角色状态归战斗系统）。
func _defeat_summary(rewards: Dictionary) -> Dictionary:
	var dead_names: Array = []
	var source: Variant = rewards.get("dead_names", _dead_names)
	if source is Array:
		dead_names = (source as Array).duplicate()
	var binding: int = int(rewards.get("binding_card_count", _dead_binding_card_count))
	return {
		"cultivation_lost": int(rewards.get("cultivation_lost", 0)),
		"dead_names": dead_names,
		"binding_card_count": binding,
	}


## 注入战败上下文（阵亡角色名 / 绑定卡张数——单场战斗一次性下发）。[br]
## [br][b]时机[/b]：战斗结束前后由场景挂载侧调用（本宿主不轮询战斗状态）。
func set_defeat_context(dead_names: Array, binding_card_count: int) -> void:
	_dead_names = dead_names.duplicate()
	_dead_binding_card_count = maxi(binding_card_count, 0)


## 已阵亡角色的绑定卡张数（面板正文用——注入值）。
func _binding_card_count() -> int:
	return _dead_binding_card_count


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_disconnect_source(_bound_combat_system)
		_bound_combat_system = null
