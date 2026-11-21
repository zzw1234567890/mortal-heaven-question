extends GutTest
## 修炼室渡劫入口（[code]cultivation_scene.tscn[/code]）端到端 —— 真实场景 + 真实系统。[br]
## [br][b]本轮修的是什么[/b]：修炼室的第二动作行原先无论哪一境界都直调
## [code]RealmSystem.realm_up[/code]——[code]TribulationSystem.trigger_tribulation[/code]
## 在生产代码里一个调用者都没有，渡劫战打完了
## [code]TribulationCombat.on_battle_ended[/code] 因状态不是 [code]IN_COMBAT[/code]
## 直接 return，[b]赢了也不进境[/b]。本文件钉住修好之后的那条路。[br]
## [br][b]为什么是集成测试[/b]：这里要验的是「点下去玩家的数据与场景真的按渡劫走」——
## 触发走 [code]TribulationSystem.trigger_tribulation[/code]（真实状态机 + 真实 GSM）、
## 转场请求走 [code]SceneManager[/code]（用桩记请求，不真换场景）、成败回流走
## [code]TribulationSystem[/code] 的结算子模块（真实 [code]realm_up[/code] / 真实扣修为）。
## 替身这三段就等于把断言换成「我调了那个桩」。[br]
## [br][b]两个替身，各有各的必要[/b]：[br]
##   · 导航桩——真转场会换场景并释放本屏，测试就再也断言不到回调之后的画面；[br]
##   · 「不需要渡劫的境界」的注入表——真配置里一行都没标（GDD 只在故事线留了一处
##     例外：第 2 章苍玄古战场重新筑基），不注入就构造不出「仍是『突破』」那半边分支。[br]
## [br][b]存档隔离[/b]：player 域（修为 / 上限 / 境界 / 溢出 / 灵石 / 渡劫状态 / 失败计数）
## 在 [code]before_each[/code] 快照、[code]after_each[/code] 原样还原——本屏会触发渡劫
## 状态机，不还原就会漏进下一个用例。[br]
## [br][b]帧末到账[/b]：境界写入的 Cat 1 信号走 GSM 帧末缓冲，故「上限跟着变」必须在
## 动作后等帧（同 [code]test_cultivation_scene.gd[/code] 的口径）。[br]
##
## 来源: design/gdd/tribulation-system.md §1/§2/§4/§5/§7 + §「唯一例外」、
## design/gdd/cultivation-system.md §6、ADR-0021 §trigger_tribulation、ADR-0010、
## ADR-0005、ADR-0031 §2、先例 [code]test_cultivation_scene.gd[/code]。

const ScreenScene: PackedScene = preload("res://src/feature/cultivation/cultivation_scene.tscn")
const SceneManagerScript := preload("res://src/foundation/scene_manager.gd")
const GateScript := preload("res://src/ui/cultivation/cultivation_tribulation_gate.gd")
const RulesScript := preload("res://src/ui/cultivation/cultivation_view_rules.gd")
## 渡劫规则表（「炼气期不需要渡劫」那张覆盖表的底本——规则单点）。
const RealmRulesScript := preload("res://src/feature/tribulation/tribulation_realm_rules.gd")
## 配置读取面（期望的境界名从这里取——测试不自己硬编码等级名）。
const TableScript := preload("res://src/feature/exploration/exploration_breakthrough_table.gd")
## 渡劫系统枚举与常量真理来源（状态值 / 结算比例都不写死）。
const TS_SCRIPT := preload("res://src/feature/tribulation_system.gd")
## 结算子模块的失败损失比例——断言「扣了多少」时用它算期望值（同一处来源）。
const SettlementScript := preload("res://src/feature/tribulation/tribulation_settlement.gd")

## 炼气期的修为上限（境界表 §1——本文件的基准状态）。
const BASE_MAX: int = 1000
## 账上有钱的档位（本屏只读灵石、不花）。
const RICH: int = 500
## 渡劫失败用例的基准（筑基期 1500/1500——须修为满才触发得了渡劫，损失 225）。
const FAIL_REALM: int = 2
const FAIL_MAX: int = 1500
const FAIL_CURRENT: int = 1500


## 导航桩——记录转场请求，不真跳场景（[member accept] = false 时模拟并发守卫拒绝）。
class SceneManagerStub extends Node:
	var requests: Array = []
	var current_id: int = 10
	var accept: bool = true

	func get_current_scene_id() -> int:
		return current_id

	func request_scene_change(from: int, to: int, type: int) -> bool:
		requests.append({"from": from, "to": to, "type": type})
		return accept


## 桩渡劫系统——有对象但没方法（界面须按「不可用」处理，而不是点下去没反应）。
class BareTribulation extends Node:
	pass


var sm: SceneManagerStub = null
var screen: Control = null
var _player_before: Dictionary = {}


func before_each() -> void:
	_player_before = (GameStateManager.player as Dictionary).duplicate(true)
	_reset_player()
	sm = SceneManagerStub.new()
	add_child_autofree(sm)


func after_each() -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	screen = null
	GameStateManager.player = _player_before
	sm = null


# ═══════════════════════════════════════════════════════════════════════════════
# 装置
# ═══════════════════════════════════════════════════════════════════════════════

## 基准存档：炼气期、修为 0 / 1000、无溢出、未在渡劫流程中。[br]
## [br][b]直接写 player 域而不是走 API[/b]：修为写入口全是只增不减的，构造「修为恰好
## 差一点」这种边界只能置位（同 [code]test_cultivation_scene.gd[/code] 口径）。
func _reset_player() -> void:
	var player: Dictionary = GameStateManager.player
	player["realm"] = 1
	player["cultivation"] = 0
	player["max_cultivation"] = BASE_MAX
	player["cultivation_full"] = false
	player["overflow_pool"] = 0
	player["resources"]["ling_shi"] = RICH
	player["tribulation_state"] = TS_SCRIPT.TribulationState.NOT_READY
	player["consecutive_tribulation_failures"] = 0
	GameStateManager.set("_pending_changes", {})
	GameStateManager.set("_flush_scheduled", false)


## 挂载修炼室场景（注入导航桩；[param p_table] 非空时替换境界表判定源）。[br]
## [br][b]注入必须在进树前[/b]：[code]_ready[/code] 那一刻就会 [code]refresh()[/code]。
func _mount(p_table: Variant = null) -> Control:
	var instance: Control = ScreenScene.instantiate() as Control
	instance.set("scene_manager", sm)
	if p_table != null:
		instance.set("tribulation_table", p_table)
	add_child_autofree(instance)
	return instance


## 一张「炼气期不需要渡劫」的规则表副本（其余行全部走真配置——见类文档）。[br]
## [br][b]为什么复制而不是改真表[/b]：[code]TribulationRealmRules.TABLE[/code] 是全局
## 单例数据，改了会漏进别的用例。
func _table_without_tribulation_at_realm_one() -> Dictionary:
	var table: Dictionary = RealmRulesScript.TABLE.duplicate(true)
	(table[1] as Dictionary)[GateScript.KEY_REQUIRES_TRIBULATION] = false
	return table


func _cultivation() -> int:
	return int(GameStateManager.player.cultivation)


func _realm() -> int:
	return int(GameStateManager.player.realm)


func _trib_state() -> int:
	return int(GameStateManager.player.tribulation_state)


## 刷新 GSM 帧末缓冲（境界信号与上限重算在这一帧到账）。
func _flush() -> void:
	await get_tree().process_frame


## 投递一条真实按键（按下 + 抬起成对，且都带 [member InputEventKey.physical_keycode]——
## 只投「按下」不带 physical 时，焦点在 [Button] 上的回车不会被翻译成按钮按下）。
func _press(p_code: Key) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for is_pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = p_code
		event.physical_keycode = p_code
		event.pressed = is_pressed
		tree.root.push_input(event, true)


## 把玩家推进渡劫战斗（[code]PREPARING → IN_COMBAT[/code]——渡劫场景开战时的真实转换）。
func _enter_tribulation_combat() -> void:
	TribulationSystem.call("_set_state", TS_SCRIPT.TribulationState.IN_COMBAT)


# ═══════════════════════════════════════════════════════════════════════════════
# 需要渡劫的境界——按钮语义与去向
# ═══════════════════════════════════════════════════════════════════════════════

func test_cultivation_scene_needs_tribulation_button_says_tribulation() -> void:
	# Arrange + Act——炼气期修为攒满（该境界进阶按配置需要渡劫）
	CultivationSystem.call("gain_cultivation", BASE_MAX, "test")
	screen = _mount()
	# Assert——按钮不再叫「突破」，状态行也说明要先渡劫
	assert_eq(str(screen.breakthrough_text()), RulesScript.TEXT_TRIBULATION,
			"需渡劫的境界上按钮应写成「渡劫」")
	assert_eq(screen.action_kind(), GateScript.KIND_TRIBULATION,
			"第二动作行的语义应为渡劫")
	assert_true(screen.is_breakthrough_enabled(), "修为满且可渡劫时应可点")
	assert_true(str(screen.status_text()).contains("渡劫"),
			"状态行应说明需要渡劫：%s" % str(screen.status_text()))
	await _flush()


func test_cultivation_scene_tribulation_press_requests_tribulation_scene() -> void:
	# Arrange——修为满 + 导航桩
	CultivationSystem.call("gain_cultivation", BASE_MAX, "test")
	await _flush()
	screen = _mount()
	sm.requests.clear()
	# Act——按下「渡劫」
	screen.press_breakthrough()
	# Assert——发出一次转场请求，且目标就是渡劫场景（走 TRIBULATION 过渡类型）
	assert_eq(sm.requests.size(), 1, "按下渡劫应恰好发出一次转场请求")
	assert_eq(int(sm.requests[0]["from"]), SceneManagerScript.SceneID.CULTIVATION,
			"from 应为当前场景")
	assert_eq(int(sm.requests[0]["to"]), SceneManagerScript.SceneID.TRIBULATION,
			"目标应为渡劫场景")
	assert_eq(int(sm.requests[0]["type"]),
			SceneManagerScript.TransitionType.TRIBULATION, "应走渡劫的过渡类型")
	assert_true(str(screen.message_text()).contains("渡劫"),
			"提示行应说明已触发渡劫：%s" % str(screen.message_text()))


func test_cultivation_scene_tribulation_press_does_not_raise_realm_directly() -> void:
	# Arrange——修为满、炼气期（该境界需要渡劫）
	CultivationSystem.call("gain_cultivation", BASE_MAX, "test")
	await _flush()
	screen = _mount()
	# Act——按下「渡劫」
	screen.press_breakthrough()
	# Assert——境界纹丝不动、修为没被动、状态机进入准备阶段
	# （这是本文件存在的理由：绕过渡劫直接 realm_up 的那条路必须不存在）
	assert_eq(_realm(), 1, "触发渡劫不得直接改境界（那是渡劫战的胜负才决定的）")
	assert_eq(_cultivation(), BASE_MAX, "触发渡劫不得动修为（失败才会扣）")
	assert_eq(_trib_state(), TS_SCRIPT.TribulationState.PREPARING,
			"触发后状态机应进入 PREPARING（渡劫场景开战前会校验它）")
	await _flush()


func test_cultivation_scene_tribulation_rejected_transition_cancels_state() -> void:
	# Arrange——导航桩拒绝转场（模拟 SceneManager 的并发守卫）
	CultivationSystem.call("gain_cultivation", BASE_MAX, "test")
	await _flush()
	sm.accept = false
	screen = _mount()
	# Act
	screen.press_breakthrough()
	# Assert——状态退回 NOT_READY（不把玩家永久卡在「渡劫流程进行中」）+ 中文回执
	assert_eq(_trib_state(), TS_SCRIPT.TribulationState.NOT_READY,
			"转场被拒后渡劫状态应退回，否则玩家再也触发不了")
	assert_true(str(screen.message_text()).contains("转场"),
			"应给出可读的中文回执：%s" % str(screen.message_text()))
	await _flush()


# ═══════════════════════════════════════════════════════════════════════════════
# 不需要渡劫的境界——保持原「突破」语义
# ═══════════════════════════════════════════════════════════════════════════════

func test_cultivation_scene_without_tribulation_button_stays_breakthrough() -> void:
	# Arrange——注入一张「炼气期无需渡劫」的配置表 + 修为攒满
	CultivationSystem.call("gain_cultivation", BASE_MAX, "test")
	await _flush()
	screen = _mount(_table_without_tribulation_at_realm_one())
	# Assert——文案与语义都还是「突破」
	assert_eq(str(screen.breakthrough_text()), RulesScript.TEXT_BREAKTHROUGH,
			"不需渡劫的境界上按钮应仍是「突破」")
	assert_eq(screen.action_kind(), GateScript.KIND_BREAKTHROUGH,
			"第二动作行的语义应为直接突破")


func test_cultivation_scene_without_tribulation_press_raises_realm() -> void:
	# Arrange——同上，且导航桩不该收到任何请求
	CultivationSystem.call("gain_cultivation", BASE_MAX, "test")
	await _flush()
	screen = _mount(_table_without_tribulation_at_realm_one())
	sm.requests.clear()
	# Act
	screen.press_breakthrough()
	# Assert——真的进境，且没走渡劫那条路
	assert_eq(_realm(), 2, "不需渡劫的境界上「突破」应直接升境界")
	assert_eq(sm.requests.size(), 0, "直接突破不应请求任何转场")
	assert_eq(_trib_state(), TS_SCRIPT.TribulationState.NOT_READY,
			"直接突破不应把状态机推进渡劫流程")
	assert_true(str(screen.message_text()).contains(TableScript.realm_name(2)),
			"回执应写明突破到了哪个境界：%s" % str(screen.message_text()))
	await _flush()
	await _flush()


# ═══════════════════════════════════════════════════════════════════════════════
# 到顶——两行都关掉，各有各的说法
# ═══════════════════════════════════════════════════════════════════════════════

func test_cultivation_scene_at_max_realm_disables_both_rows_with_reasons() -> void:
	# Arrange——化神期（最高境界）且修为攒满
	var top: int = TableScript.max_realm()
	GameStateManager.player["realm"] = top
	GameStateManager.player["max_cultivation"] = TableScript.required_cultivation(top)
	GameStateManager.player["cultivation"] = TableScript.required_cultivation(top)
	screen = _mount()
	# Assert——两行都禁用
	assert_false(screen.is_breakthrough_enabled(), "到顶时第二行动作应不可点")
	assert_false(screen.is_meditate_enabled(), "到顶时打坐也应不可点（修为无处可用）")
	assert_true(str(screen.status_text()).contains("最高境界"),
			"状态行应写明已达最高境界：%s" % str(screen.status_text()))
	# Act——分别按两行（禁用行也要给得出原因）
	screen.press_breakthrough()
	var break_message: String = str(screen.message_text())
	screen.press_meditate()
	var meditate_message: String = str(screen.message_text())
	# Assert——各有各的中文原因，且都没有改变任何数据
	assert_true(break_message.contains("最高境界"),
			"「突破」行应给出已达最高境界的原因：%s" % break_message)
	assert_true(meditate_message.contains("无处可用"),
			"「打坐」行应给出修为无处可用的原因：%s" % meditate_message)
	assert_eq(_cultivation(), TableScript.required_cultivation(top),
			"到顶时点打坐不得再攒修为")
	assert_eq(_realm(), top, "到顶时点突破不得越界")


# ═══════════════════════════════════════════════════════════════════════════════
# 渡劫回来——成败都要刷新画面
# ═══════════════════════════════════════════════════════════════════════════════

func test_cultivation_scene_tribulation_success_shows_new_realm_and_cap() -> void:
	# Arrange——修为满 → 触发渡劫 → 进入渡劫战
	CultivationSystem.call("gain_cultivation", BASE_MAX, "test")
	await _flush()
	screen = _mount()
	screen.press_breakthrough()
	_enter_tribulation_combat()
	# Act——渡劫战打赢（走真实结算：realm_up + 失败计数重置 + 发信号）
	TribulationSystem.call("_handle_tribulation_success")
	await _flush()
	await _flush()
	# Assert——境界升到 2、界面显示新境界名、上限按配置重算、回执说明成败
	assert_eq(_realm(), 2, "渡劫成功后境界应 +1")
	assert_true(str(screen.realm_text()).contains(TableScript.realm_name(2)),
			"界面上应是新境界名：%s" % str(screen.realm_text()))
	assert_eq(int(GameStateManager.player.max_cultivation),
			TableScript.required_cultivation(2), "修为上限应按新境界重算")
	assert_eq(str(screen.progress_text()),
			"修为 %d / %d" % [BASE_MAX, TableScript.required_cultivation(2)],
			"界面上限应跟着刷新")
	assert_true(str(screen.message_text()).contains("渡劫成功"),
			"回执应说明渡劫成功：%s" % str(screen.message_text()))


func test_cultivation_scene_tribulation_failure_deducts_cultivation() -> void:
	# Arrange——筑基期修为 1200/1500 → 触发渡劫 → 进入渡劫战
	GameStateManager.player["realm"] = FAIL_REALM
	GameStateManager.player["max_cultivation"] = FAIL_MAX
	GameStateManager.player["cultivation"] = FAIL_CURRENT
	await _flush()
	screen = _mount()
	screen.press_breakthrough()
	_enter_tribulation_combat()
	# Act——渡劫战打输（走真实结算：按 max_cultivation × 比例扣）
	TribulationSystem.call("_handle_tribulation_failure")
	await _flush()
	# Assert——损失与结算口径一致、境界不变、界面与回执都跟上
	var penalty: int = int(floor(float(FAIL_MAX) * SettlementScript.FAILURE_PENALTY_RATIO))
	assert_eq(_cultivation(), FAIL_CURRENT - penalty,
			"失败应按 max_cultivation × %f 扣修为" % SettlementScript.FAILURE_PENALTY_RATIO)
	assert_eq(_realm(), FAIL_REALM, "渡劫失败境界不变")
	assert_eq(str(screen.progress_text()), "修为 %d / %d" % [FAIL_CURRENT - penalty, FAIL_MAX],
			"界面修为数字应刷新")
	assert_true(str(screen.message_text()).contains(str(penalty)),
			"回执应写明损失了多少修为：%s" % str(screen.message_text()))


# ═══════════════════════════════════════════════════════════════════════════════
# 键盘——第二行也能用键盘走到
# ═══════════════════════════════════════════════════════════════════════════════

func test_cultivation_scene_tribulation_keyboard_enter_works() -> void:
	# Arrange——修为攒满，默认焦点在「打坐」
	CultivationSystem.call("gain_cultivation", BASE_MAX, "test")
	await _flush()
	screen = _mount()
	sm.requests.clear()
	# Act——↓ 把游标移到第二行 → 回车
	_press(KEY_DOWN)
	assert_eq(screen.focused_index(), 1, "前置：↓ 应把游标移到「渡劫」")
	_press(KEY_ENTER)
	# Assert——键盘也走得到渡劫（不是只有鼠标能触发）
	assert_eq(sm.requests.size(), 1, "回车应触发渡劫的转场请求")
	assert_eq(int(sm.requests[0]["to"]), SceneManagerScript.SceneID.TRIBULATION,
			"回车触发的目标应是渡劫场景")
	assert_eq(_trib_state(), TS_SCRIPT.TribulationState.PREPARING,
			"回车应真的推进渡劫状态机")
	await _flush()


# ═══════════════════════════════════════════════════════════════════════════════
# 降级——渡劫系统缺失 / 不可用
# ═══════════════════════════════════════════════════════════════════════════════

func test_cultivation_scene_missing_tribulation_system_is_readable() -> void:
	# Arrange——注入一个「有对象但没方法」的桩渡劫系统 + 修为满
	CultivationSystem.call("gain_cultivation", BASE_MAX, "test")
	await _flush()
	var stub := BareTribulation.new()
	add_child_autofree(stub)
	screen = _mount()
	screen.set("tribulation_system", stub)
	screen.refresh()
	# Assert——按钮灰着并给出可读原因（不是「点了没反应」）
	assert_false(screen.is_breakthrough_enabled(), "渡劫系统不可用时第二行应禁用")
	assert_true(str(screen.status_text()).contains("不可用"),
			"状态行应给出可读原因：%s" % str(screen.status_text()))
	# Act——点那个灰按钮
	sm.requests.clear()
	screen.press_breakthrough()
	# Assert——给中文原因，且不发任何转场请求、不动境界
	assert_true(str(screen.message_text()).contains("不可用"),
			"点禁用行应给出可读原因：%s" % str(screen.message_text()))
	assert_eq(sm.requests.size(), 0, "系统不可用时不得请求转场")
	assert_eq(_realm(), 1, "系统不可用时不得改境界")
	await _flush()
