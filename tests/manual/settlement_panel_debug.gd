extends Control
## settlement_panel_debug —— 结算/撤退/渡劫警示面板视觉手动验证宿主（Story 008）。
##
## F6 运行本场景：以桩依赖挂载 [SettlementHost]，按 1-5 打开五类面板、
## 按 0 关闭、按 T 切换渡劫标识、按 M 切换 reduce_motion，
## 供人工截图与走查——生产代码零改动。
##
## 验证剧本（对应 `production/qa/evidence/settlement-retreat-evidence.md` §2 五场景）：
##   [1] 胜利面板（三选一，0.5s 后可变可点）
##   [2] 胜利面板·卡组已满（卡牌选项灰显「卡组已满」）
##   [3] 战败面板（50% 修为 + 阵亡角色 + 绑定卡）
##   [4] 撤退确认·普通变体（淡墨边框）
##   [5] 撤退确认·渡劫变体（朱砂红边框 +「畏劫而退，修为散尽」+ 80%）
##   [6] 渡劫战前警示（「天劫在前，退路将断。确认进战？」）
##   [0] 关闭  [T] 切换渡劫标识  [M] 切换 reduce_motion
##
## 来源: combat-ui-layout Story 008 Test Evidence（UI 证据文档 §2）、
## tests/manual/node_popup_debug.gd 先例（S17-3）。

const HostScript := preload("res://src/ui/combat/settlement/settlement_host.gd")
const Rules := preload("res://src/ui/combat/shared/settlement_rules.gd")
const CombatSystemScript := preload("res://src/feature/combat_system.gd")

## 结算宿主。
var host: Control = null
## 是否渡劫战（T 切换）。
var is_tribulation: bool = false
## reduce_motion（M 切换）。
var reduce_motion: bool = false


func _ready() -> void:
	name = "SettlementPanelDebug"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	host = HostScript.new()
	add_child(host)
	host.setup(_make_combat(), _make_deck(5, 20), is_tribulation)
	host.set_reduce_motion(reduce_motion)
	host.set_defeat_context(["林渊", "白芷"], 2)
	host.settlement_panel.reduce_motion = reduce_motion
	host.retreat_dialog.reduce_motion = reduce_motion
	host.tribulation_warning.reduce_motion = reduce_motion
	host.loot_confirmed.connect(func(i: int) -> void:
		print("[settlement_debug] 确认战利品下标 %d" % i))
	host.loot_skipped.connect(func() -> void:
		print("[settlement_debug] 跳过全部奖励"))
	host.defeat_confirmed.connect(func() -> void:
		print("[settlement_debug] 战败返回探索"))
	host.retreat_confirmed.connect(func() -> void:
		print("[settlement_debug] 确认撤退（渡劫=%s）" % str(is_tribulation)))
	host.pre_battle_confirmed.connect(func() -> void:
		print("[settlement_debug] 渡劫战前确认进战"))
	_print_instructions()


## 胜利面板桩战利品（GDD §9 线框三例：卡牌 / 灵石 / 消耗品）。
func _victory_options() -> Array:
	return [
		{"kind": Rules.OPTION_KIND_CARD, "name": "青云剑诀",
				"rarity": "蓝", "school": "功法"},
		{"kind": Rules.OPTION_KIND_LINGSHI, "amount": 25},
		{"kind": Rules.OPTION_KIND_CONSUMABLE, "name": "回血丹"},
	]


## 战斗系统桩——只发信号（不真实结算）。
func _make_combat() -> Node:
	var stub: Node = Node.new()
	stub.name = "CombatStub"
	stub.set_script(_combat_stub_script())
	add_child(stub)
	return stub


func _combat_stub_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = """
extends Node
signal battle_ended(result: int, rewards: Dictionary)
signal retreat_requested()
"""
	script.reload()
	return script


## 卡组系统桩——手数/上限可调（卡组满场景用）。
var _deck: Node = null


func _make_deck(total: int, limit: int) -> Node:
	_deck = Node.new()
	_deck.name = "DeckStub"
	_deck.set_script(_deck_stub_script())
	add_child(_deck)
	_deck.set("total", total)
	_deck.set("limit", limit)
	return _deck


func _deck_stub_script() -> GDScript:
	var script := GDScript.new()
	script.source_code = """
extends Node
var total: int = 5
var limit: int = 20
func get_deck_summary() -> Dictionary:
	return {"total": total, "limit": limit, "is_full": total >= limit}
"""
	script.reload()
	return script


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1: _show_victory(5, 20)
		KEY_2: _show_victory(20, 20)
		KEY_3: host.on_battle_ended(CombatSystemScript.CombatResult.DEFEAT, {})
		KEY_4: _open_retreat(false)
		KEY_5: _open_retreat(true)
		KEY_6: host.show_pre_battle_warning()
		KEY_0: _close_all()
		KEY_T: _toggle_tribulation()
		KEY_M: _toggle_reduce_motion()


func _show_victory(deck_count: int, deck_limit: int) -> void:
	_deck.set("total", deck_count)
	_deck.set("limit", deck_limit)
	host.settlement_panel.show_victory(_victory_options(), deck_count, deck_limit)


## 撤退变体——面板自身按 is_tribulation 切换（不依赖宿主的渡劫标识，
## 便于连续对比两变体）。
func _open_retreat(tribulation: bool) -> void:
	host.retreat_dialog.open(tribulation, 2)


func _close_all() -> void:
	host.settlement_panel.close_panel()
	host.retreat_dialog.close_dialog()
	host.tribulation_warning.close_dialog()


func _toggle_tribulation() -> void:
	is_tribulation = not is_tribulation
	host.is_tribulation = is_tribulation
	print("[settlement_debug] 渡劫标识 = %s" % str(is_tribulation))


func _toggle_reduce_motion() -> void:
	reduce_motion = not reduce_motion
	host.set_reduce_motion(reduce_motion)
	print("[settlement_debug] reduce_motion = %s" % str(reduce_motion))


func _print_instructions() -> void:
	print("=== settlement_panel_debug ===")
	print("1 胜利  2 胜利·卡组已满  3 战败  4 撤退(普通)  5 撤退(渡劫)  6 渡劫战前警示")
	print("0 关闭全部  T 切换渡劫标识  M 切换 reduce_motion")
	print("走查清单见 production/qa/evidence/settlement-retreat-evidence.md §2（五场景）")
	print("战利品 0.5s 延迟：打开后立刻点击应无反应，约半秒后可高亮选中")
